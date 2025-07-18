#!/bin/bash
# 自动从Terraform输出生成MSK配置文件

set -e

echo "🔧 自动生成MSK配置文件..."

# 检查是否在项目根目录
if [ ! -f "msk_config.env.template" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

# 检查Terraform目录
if [ ! -d "terraform" ]; then
    echo "❌ 未找到terraform目录"
    exit 1
fi

cd terraform

# 检查Terraform状态
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ 未找到terraform.tfstate文件，请先运行 terraform apply"
    exit 1
fi

echo "📋 获取Terraform输出..."

# 获取Terraform输出
MSK_CLUSTER_ARN=$(terraform output -raw msk_cluster_arn 2>/dev/null || echo "")
MSK_CLUSTER_NAME=$(terraform output -raw msk_cluster_name 2>/dev/null || echo "")
MSK_BOOTSTRAP_SERVERS_SCRAM=$(terraform output -raw msk_bootstrap_servers_scram 2>/dev/null || echo "")
MSK_BOOTSTRAP_SERVERS_IAM=$(terraform output -raw msk_bootstrap_servers_iam 2>/dev/null || echo "")
MSK_BOOTSTRAP_SERVERS_TLS=$(terraform output -raw msk_bootstrap_servers_tls 2>/dev/null || echo "")
MSK_ZOOKEEPER_CONNECT=$(terraform output -raw msk_zookeeper_connect 2>/dev/null || echo "")
EC2_INSTANCE_ID=$(terraform output -raw ec2_instance_id 2>/dev/null || echo "")
EC2_PRIVATE_IP=$(terraform output -raw ec2_private_ip 2>/dev/null || echo "")
MSK_SCRAM_SECRET_ARN=$(terraform output -raw scram_secret_arn 2>/dev/null || echo "")
MSK_SCRAM_SECRET_NAME=$(terraform output -raw scram_secret_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-southeast-1")

cd ..

# 检查必需的输出
if [ -z "$MSK_CLUSTER_ARN" ] || [ -z "$MSK_BOOTSTRAP_SERVERS_SCRAM" ]; then
    echo "❌ 无法获取必需的Terraform输出，请检查部署状态"
    exit 1
fi

echo "✅ 成功获取Terraform输出"

# 生成配置文件
echo "📝 生成msk_config.env文件..."

cat > msk_config.env << EOF
# MSK Configuration - Auto-generated from Terraform
export MSK_CLUSTER_ARN="$MSK_CLUSTER_ARN"
export MSK_CLUSTER_NAME="$MSK_CLUSTER_NAME"
export MSK_BOOTSTRAP_SERVERS_IAM="$MSK_BOOTSTRAP_SERVERS_IAM"
export MSK_BOOTSTRAP_SERVERS_SCRAM="$MSK_BOOTSTRAP_SERVERS_SCRAM"
export MSK_BOOTSTRAP_SERVERS_TLS="$MSK_BOOTSTRAP_SERVERS_TLS"
export MSK_ZOOKEEPER_CONNECT="$MSK_ZOOKEEPER_CONNECT"

# EC2 Configuration
export EC2_INSTANCE_ID="$EC2_INSTANCE_ID"
export EC2_PRIVATE_IP="$EC2_PRIVATE_IP"

# Secrets Manager Configuration
export MSK_SCRAM_SECRET_ARN="$MSK_SCRAM_SECRET_ARN"
export MSK_SCRAM_SECRET_NAME="$MSK_SCRAM_SECRET_NAME"

# AWS Configuration
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_REGION="$AWS_REGION"

# Application Configuration
export MSK_TOPIC="msk-poc-topic"
export MSK_CONSUMER_GROUP="msk-scram-consumer-group"
export NUM_MESSAGES="5"
export MESSAGE_INTERVAL="1"
export CONSUME_TIMEOUT="30"
EOF

echo "✅ 配置文件生成完成: msk_config.env"
echo
echo "📋 生成的配置摘要:"
echo "  集群名称: $MSK_CLUSTER_NAME"
echo "  AWS区域: $AWS_REGION"
echo "  EC2实例: $EC2_INSTANCE_ID"
echo "  Secret名称: $MSK_SCRAM_SECRET_NAME"
echo
echo "🔍 验证配置:"
echo "  ./verify_config.sh"
echo
echo "🚀 加载配置并测试:"
echo "  source msk_config.env"
echo "  python3 python-clients/producer_scram.py"
