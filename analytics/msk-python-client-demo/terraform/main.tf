terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Groups
resource "aws_security_group" "msk_cluster" {
  name_prefix = "${var.project_name}-msk-"
  vpc_id      = var.vpc_id
  description = "Security group for MSK cluster"

  ingress {
    description = "Kafka TLS from VPC"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Kafka SASL_SSL from VPC"
    from_port   = 9096
    to_port     = 9096
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Zookeeper from VPC"
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-msk-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "ec2_client" {
  name_prefix = "${var.project_name}-ec2-"
  vpc_id      = var.vpc_id
  description = "Security group for EC2 Kafka client"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-client-sg"
    Environment = var.environment
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_msk_role" {
  name = "${var.project_name}-ec2-msk-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-msk-role"
    Environment = var.environment
  }
}

# IAM Policy for MSK access
resource "aws_iam_policy" "msk_access" {
  name        = "${var.project_name}-msk-access"
  description = "Policy for MSK access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData",
          "kafka-cluster:CreateGroup",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DeleteGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-msk-access-policy"
    Environment = var.environment
  }
}

# Attach policies to role
resource "aws_iam_role_policy_attachment" "msk_access" {
  role       = aws_iam_role.ec2_msk_role.name
  policy_arn = aws_iam_policy.msk_access.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_msk_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "ec2_msk_profile" {
  name = "${var.project_name}-ec2-msk-profile"
  role = aws_iam_role.ec2_msk_role.name

  tags = {
    Name        = "${var.project_name}-ec2-msk-profile"
    Environment = var.environment
  }
}

# Secrets Manager for SCRAM credentials
resource "aws_secretsmanager_secret" "msk_scram" {
  name        = "AmazonMSK_${var.project_name}-msk-scram-credentials"
  description = "SCRAM credentials for MSK cluster"

  tags = {
    Name        = "AmazonMSK_${var.project_name}-msk-scram-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "msk_scram" {
  secret_id = aws_secretsmanager_secret.msk_scram.id
  secret_string = jsonencode({
    username = var.scram_username
    password = var.scram_password
  })
}

# MSK Configuration
resource "aws_msk_configuration" "msk_config" {
  kafka_versions = [var.kafka_version]
  name           = "${var.project_name}-msk-config"
  description    = "MSK configuration for ${var.project_name}"

  server_properties = <<PROPERTIES
auto.create.topics.enable=true
default.replication.factor=2
min.insync.replicas=1
num.partitions=3
log.retention.hours=168
PROPERTIES
}

# MSK Cluster
resource "aws_msk_cluster" "msk_cluster" {
  cluster_name           = "${var.project_name}-cluster"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = length(var.subnet_ids)

  broker_node_group_info {
    instance_type   = var.instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk_cluster.id]
    
    storage_info {
      ebs_storage_info {
        volume_size = 20
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.msk_config.arn
    revision = aws_msk_configuration.msk_config.latest_revision
  }

  client_authentication {
    sasl {
      scram = true
      iam   = true
    }
    tls {}
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_logs.name
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-msk-cluster"
    Environment = var.environment
  }
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk_logs" {
  name              = "/aws/msk/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-msk-logs"
    Environment = var.environment
  }
}

# MSK SCRAM Secret Association
resource "aws_msk_scram_secret_association" "msk_scram_association" {
  cluster_arn     = aws_msk_cluster.msk_cluster.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_scram.arn]

  depends_on = [aws_secretsmanager_secret_version.msk_scram]
}

# EC2 Instance for Kafka client
resource "aws_instance" "kafka_client" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.subnet_ids[0]  # Use first private subnet
  vpc_security_group_ids = [aws_security_group.ec2_client.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_msk_profile.name

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    region = var.aws_region
  }))

  tags = {
    Name        = "${var.project_name}-kafka-client"
    Environment = var.environment
  }
}
