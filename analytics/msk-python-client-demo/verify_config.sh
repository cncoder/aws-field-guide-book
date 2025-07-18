#!/bin/bash
# 环境变量验证脚本

echo "=== MSK 环境变量验证 ==="
echo

# 检查配置文件是否存在
if [ ! -f "msk_config.env" ]; then
    echo "❌ 配置文件 msk_config.env 不存在"
    echo "请复制 msk_config.env.template 为 msk_config.env 并填入实际值"
    exit 1
fi

# 加载环境变量
source msk_config.env

echo "📋 MSK 集群配置:"
echo "  集群名称: ${MSK_CLUSTER_NAME:-'未设置'}"
echo "  集群ARN: ${MSK_CLUSTER_ARN:-'未设置'}"
echo "  SCRAM Bootstrap: ${MSK_BOOTSTRAP_SERVERS_SCRAM:-'未设置'}"
echo "  IAM Bootstrap: ${MSK_BOOTSTRAP_SERVERS_IAM:-'未设置'}"
echo "  TLS Bootstrap: ${MSK_BOOTSTRAP_SERVERS_TLS:-'未设置'}"
echo

echo "🔐 认证配置:"
echo "  Secret名称: ${MSK_SCRAM_SECRET_NAME:-'未设置'}"
echo "  Secret ARN: ${MSK_SCRAM_SECRET_ARN:-'未设置'}"
echo

echo "💻 EC2 配置:"
echo "  实例ID: ${EC2_INSTANCE_ID:-'未设置'}"
echo "  私有IP: ${EC2_PRIVATE_IP:-'未设置'}"
echo

echo "🌍 AWS 配置:"
echo "  默认区域: ${AWS_DEFAULT_REGION:-'未设置'}"
echo "  区域: ${AWS_REGION:-'未设置'}"
echo

echo "⚙️ 应用配置:"
echo "  主题名称: ${MSK_TOPIC:-'未设置'}"
echo "  消费者组: ${MSK_CONSUMER_GROUP:-'未设置'}"
echo "  消息数量: ${NUM_MESSAGES:-'未设置'}"
echo "  消息间隔: ${MESSAGE_INTERVAL:-'未设置'}秒"
echo "  消费超时: ${CONSUME_TIMEOUT:-'未设置'}秒"
echo

# 检查必需的环境变量
missing_vars=()
required_vars=("MSK_CLUSTER_NAME" "MSK_BOOTSTRAP_SERVERS_SCRAM" "MSK_BOOTSTRAP_SERVERS_IAM" "AWS_DEFAULT_REGION" "MSK_TOPIC")

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -eq 0 ]; then
    echo "✅ 所有必需的环境变量已设置！"
else
    echo "❌ 以下必需的环境变量未设置:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo
    echo "请编辑 msk_config.env 文件并设置这些变量"
    exit 1
fi

echo
echo "💡 使用方法:"
echo "  source msk_config.env  # 加载环境变量"
echo "  python3 python-clients/producer_scram.py  # 运行SCRAM生产者"
echo "  python3 python-clients/consumer_scram.py  # 运行SCRAM消费者"
echo "  python3.8 python-clients/producer_iam_production_fixed.py  # 运行IAM生产者"
echo "  python3.8 python-clients/consumer_iam_production.py  # 运行IAM消费者"
