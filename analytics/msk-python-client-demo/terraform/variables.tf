variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"  # Singapore region
}

variable "vpc_id" {
  description = "VPC ID for MSK cluster"
  type        = string
  default     = "vpc-052b2576f1eee33cd"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.50.0.0/16"
}

variable "subnet_ids" {
  description = "Subnet IDs for MSK cluster (private subnets in different AZs)"
  type        = list(string)
  default     = [
    "subnet-0162a9fb4a38db8f8",  # sec-subnet-private1-ap-southeast-1a
    "subnet-078870f2a63d65ef9"   # sec-subnet-private2-ap-southeast-1b
  ]
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for EC2 client (if needed)"
  type        = list(string)
  default     = [
    "subnet-06994c036e5bbed5b",  # sec-subnet-public1-ap-southeast-1a
    "subnet-0fbc5423440ac5392"   # sec-subnet-public2-ap-southeast-1b
  ]
}

variable "kafka_version" {
  description = "Kafka version for MSK cluster"
  type        = string
  default     = "2.8.1"
}

variable "instance_type" {
  description = "Instance type for MSK brokers"
  type        = string
  default     = "kafka.t3.small"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for client"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name (optional, using SSM)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "msk-poc"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "scram_username" {
  description = "SCRAM username for Kafka authentication"
  type        = string
  default     = "msk_user"
}

variable "scram_password" {
  description = "SCRAM password for Kafka authentication"
  type        = string
  default     = "MyStrongPassword123!"
  sensitive   = true
}
