# Aurora 子网组
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-subnet-group"
  })
}

# Aurora 安全组
resource "aws_security_group" "aurora_sg" {
  name_prefix = "${var.project_name}-aurora-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : [data.aws_vpc.existing.cidr_block]
    description = "PostgreSQL access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-sg"
  })
}

# 数据库A集群 (用户数据库)
resource "aws_rds_cluster" "database_a" {
  cluster_identifier     = "${var.project_name}-users-cluster"
  engine                = "aurora-postgresql"
  engine_version        = "15.4"
  database_name         = "usersdb"
  master_username       = var.db_master_username
  master_password       = var.db_master_password
  
  db_subnet_group_name   = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids = [aws_security_group.aurora_sg.id]
  
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  # Enable encryption at rest
  storage_encrypted = true
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-users-cluster"
    DatabaseType = "Users"
  })
}

# 数据库A写实例
resource "aws_rds_cluster_instance" "database_a_writer" {
  identifier         = "${var.project_name}-users-writer"
  cluster_identifier = aws_rds_cluster.database_a.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.database_a.engine
  engine_version     = aws_rds_cluster.database_a.engine_version
  
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = var.enable_performance_insights ? 60 : 0
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-users-writer"
    Role = "Writer"
  })
}

# 数据库A只读实例
resource "aws_rds_cluster_instance" "database_a_reader" {
  identifier         = "${var.project_name}-users-reader"
  cluster_identifier = aws_rds_cluster.database_a.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.database_a.engine
  engine_version     = aws_rds_cluster.database_a.engine_version
  
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = var.enable_performance_insights ? 60 : 0
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-users-reader"
    Role = "Reader"
  })
}

# 数据库B集群 (订单数据库)
resource "aws_rds_cluster" "database_b" {
  cluster_identifier     = "${var.project_name}-orders-cluster"
  engine                = "aurora-postgresql"
  engine_version        = "15.4"
  database_name         = "ordersdb"
  master_username       = var.db_master_username
  master_password       = var.db_master_password
  
  db_subnet_group_name   = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids = [aws_security_group.aurora_sg.id]
  
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  # Enable encryption at rest
  storage_encrypted = true
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-orders-cluster"
    DatabaseType = "Orders"
  })
}

# 数据库B写实例
resource "aws_rds_cluster_instance" "database_b_writer" {
  identifier         = "${var.project_name}-orders-writer"
  cluster_identifier = aws_rds_cluster.database_b.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.database_b.engine
  engine_version     = aws_rds_cluster.database_b.engine_version
  
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = var.enable_performance_insights ? 60 : 0
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-orders-writer"
    Role = "Writer"
  })
}

# IAM角色用于EC2 SSM访问
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ec2-ssm-role"

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

  tags = var.tags
}

# 附加SSM管理策略
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2实例配置文件
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = var.tags
}

# EC2安全组
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.project_name}-ec2-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-sg"
  })
}

# 获取最新的Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2实例
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-bastion"
    Role = "Bastion"
  })
}
