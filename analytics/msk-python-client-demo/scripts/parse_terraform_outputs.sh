#!/bin/bash
# 从Terraform JSON输出解析并生成配置文件

set -e

echo "🔧 从Terraform JSON输出生成配置..."

# 检查JSON文件是否存在
if [ ! -f "terraform_outputs.json" ]; then
    echo "❌ 未找到terraform_outputs.json文件"
    echo "请先运行: cd terraform && terraform output -json > ../terraform_outputs.json"
    exit 1
fi

# 检查是否安装了jq
if ! command -v jq &> /dev/null; then
    echo "❌ 需要安装jq来解析JSON"
    echo "macOS: brew install jq"
    echo "Ubuntu: sudo apt-get install jq"
    echo "CentOS: sudo yum install jq"
    exit 1
fi

echo "📋 解析Terraform输出..."

# 从JSON文件提取值
MSK_CLUSTER_ARN=$(jq -r '.msk_cluster_arn.value // ""' terraform_outputs.json)
MSK_CLUSTER_NAME=$(jq -r '.msk_cluster_name.value // ""' terraform_outputs.json)
MSK_BOOTSTRAP_SERVERS_SCRAM=$(jq -r '.msk_bootstrap_servers_scram.value // ""' terraform_outputs.json)
MSK_BOOTSTRAP_SERVERS_IAM=$(jq -r '.msk_bootstrap_servers_iam.value // ""' terraform_outputs.json)
MSK_BOOTSTRAP_SERVERS_TLS=$(jq -r '.msk_bootstrap_servers_tls.value // ""' terraform_outputs.json)
MSK_ZOOKEEPER_CONNECT=$(jq -r '.msk_zookeeper_connect.value // ""' terraform_outputs.json)
EC2_INSTANCE_ID=$(jq -r '.ec2_instance_id.value // ""' terraform_outputs.json)
EC2_PRIVATE_IP=$(jq -r '.ec2_private_ip.value // ""' terraform_outputs.json)
MSK_SCRAM_SECRET_ARN=$(jq -r '.scram_secret_arn.value // ""' terraform_outputs.json)
MSK_SCRAM_SECRET_NAME=$(jq -r '.scram_secret_name.value // ""' terraform_outputs.json)
AWS_REGION=$(jq -r '.aws_region.value // "ap-southeast-1"' terraform_outputs.json)

# 检查必需的值
if [ -z "$MSK_CLUSTER_ARN" ] || [ "$MSK_CLUSTER_ARN" = "null" ]; then
    echo "❌ 无法从JSON输出获取MSK集群ARN"
    exit 1
fi

echo "✅ 成功解析Terraform输出"

# 生成配置文件
echo "📝 生成msk_config.env文件..."

cat > msk_config.env << EOF
# MSK Configuration - Auto-generated from Terraform JSON
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

# 清理JSON文件
rm -f terraform_outputs.json

echo "✅ 配置文件生成完成: msk_config.env"
echo
echo "📋 生成的配置摘要:"
echo "  集群名称: $MSK_CLUSTER_NAME"
echo "  AWS区域: $AWS_REGION"
echo "  EC2实例: $EC2_INSTANCE_ID"
echo
echo "🔍 验证配置:"
echo "  ./verify_config.sh"
