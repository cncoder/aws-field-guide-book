# 获取现有VPC信息
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# 获取现有子网信息
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "subnet-id"
    values = var.private_subnet_ids
  }
}

# 获取可用区信息
data "aws_availability_zones" "available" {
  state = "available"
}

# 生成随机密码
resource "random_password" "db_password" {
  length  = 16
  special = true
}
