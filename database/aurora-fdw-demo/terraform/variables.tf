variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_id" {
  description = "Existing VPC ID where resources will be created"
  type        = string
  # Remove default value - users must provide their own VPC ID
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (minimum 2 subnets in different AZs)"
  type        = list(string)
  # Remove default values - users must provide their own subnet IDs
  
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnet IDs must be provided for Aurora cluster deployment."
  }
}

variable "db_master_username" {
  description = "Master username for Aurora clusters"
  type        = string
  default     = "postgres"
}

variable "db_master_password" {
  description = "Master password for Aurora clusters (minimum 8 characters)"
  type        = string
  sensitive   = true
  # Remove default password - users must provide their own
  
  validation {
    condition     = length(var.db_master_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.r6g.large"
}

variable "project_name" {
  description = "Project name for resource naming (will be used as prefix)"
  type        = string
  default     = "aurora-fdw-demo"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only letters, numbers, and hyphens."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Aurora clusters (defaults to VPC CIDR)"
  type        = list(string)
  default     = []
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights for Aurora instances"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 1 and 35 days."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
