#!/bin/bash
# AWS MSK Python客户端环境设置脚本
# 根据README.md文档要求配置Python环境

set -e  # 遇到错误时退出

# 更新系统
yum update -y

# 安装Python 3.8+ (IAM认证要求) 和开发工具
# 根据文档: IAM认证需要Python >= 3.8, SCRAM认证需要Python >= 3.7
yum install -y python38 python38-pip python38-devel
yum install -y gcc git

# 安装librdkafka开发库 (confluent-kafka依赖)
yum install -y librdkafka-devel

# 创建Python 3.8的符号链接，方便使用
ln -sf /usr/bin/python3.8 /usr/local/bin/python3
ln -sf /usr/bin/pip3.8 /usr/local/bin/pip3

# 安装Java (Kafka工具需要)
yum install -y java-11-amazon-corretto-headless

# 安装AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# 安装Python包 (根据文档requirements.txt)
echo "安装Python依赖库..."
python3.8 -m pip install --user --upgrade pip

# 核心库及版本 (与文档保持一致)
python3.8 -m pip install --user confluent-kafka==1.9.2
python3.8 -m pip install --user boto3>=1.28.0
python3.8 -m pip install --user aws-msk-iam-sasl-signer-python>=1.0.2
python3.8 -m pip install --user requests>=2.25.0
python3.8 -m pip install --user botocore>=1.31.0
python3.8 -m pip install --user 'urllib3<2.0'

# 验证安装
echo "验证Python环境..."
python3.8 --version
python3.8 -c "import confluent_kafka; print(f'confluent-kafka: {confluent_kafka.__version__}')"
python3.8 -c "import boto3; print(f'boto3: {boto3.__version__}')"
python3.8 -c "from aws_msk_iam_sasl_signer import MSKAuthTokenProvider; print('aws-msk-iam-sasl-signer-python: OK')"

# 创建Kafka工具目录
mkdir -p /opt/kafka
cd /opt/kafka

# 下载Kafka工具 (与MSK版本匹配)
echo "下载Kafka工具..."
wget -q https://archive.apache.org/dist/kafka/2.8.1/kafka_2.13-2.8.1.tgz
tar -xzf kafka_2.13-2.8.1.tgz
ln -s kafka_2.13-2.8.1 current
rm kafka_2.13-2.8.1.tgz

# 创建工作目录
mkdir -p /home/ec2-user/msk-poc
chown ec2-user:ec2-user /home/ec2-user/msk-poc

# 安装和启动SSM Agent
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# 创建环境配置文件
cat > /home/ec2-user/msk-poc/msk_config.env << 'EOF'
# AWS MSK Python客户端环境配置
# 根据实际部署更新以下变量

# AWS配置
export AWS_DEFAULT_REGION=${region}

# MSK集群配置 (部署后需要更新)
export MSK_CLUSTER_ARN=""
export MSK_CLUSTER_NAME="msk-poc-cluster"
export MSK_BOOTSTRAP_SERVERS_SCRAM=""  # 端口9096
export MSK_BOOTSTRAP_SERVERS_IAM=""    # 端口9098
export MSK_TOPIC="msk-poc-topic"

# SCRAM认证配置
export MSK_SCRAM_SECRET_NAME="AmazonMSK_msk-poc-msk-scram-credentials"

# 应用配置
export NUM_MESSAGES=5
export MESSAGE_INTERVAL=1
export CONSUME_TIMEOUT=30
export MSK_CONSUMER_GROUP="msk-poc-consumer-group"

# Kafka工具路径
export KAFKA_HOME=/opt/kafka/current
export PATH=$PATH:$KAFKA_HOME/bin
EOF

# 更新用户环境
cat >> /home/ec2-user/.bashrc << 'EOF'

# AWS MSK环境配置
if [ -f ~/msk-poc/msk_config.env ]; then
    source ~/msk-poc/msk_config.env
fi

# Python路径
export PATH=/home/ec2-user/.local/bin:$PATH
EOF

# 创建requirements.txt文件 (与文档保持一致)
cat > /home/ec2-user/msk-poc/requirements.txt << 'EOF'
confluent-kafka==1.9.2
boto3>=1.28.0
aws-msk-iam-sasl-signer-python>=1.0.2
requests>=2.25.0
botocore>=1.31.0
urllib3<2.0
EOF

# 设置文件权限
chown -R ec2-user:ec2-user /home/ec2-user/msk-poc
chown ec2-user:ec2-user /home/ec2-user/.bashrc

# 创建安装验证脚本
cat > /home/ec2-user/msk-poc/verify_installation.py << 'EOF'
#!/usr/bin/env python3.8
"""
验证MSK Python客户端环境安装
"""
import sys
import subprocess

def check_python_version():
    """检查Python版本"""
    version = sys.version_info
    print(f"Python版本: {version.major}.{version.minor}.{version.micro}")
    
    if version.major == 3 and version.minor >= 8:
        print("✅ Python版本符合IAM认证要求 (>= 3.8)")
        return True
    elif version.major == 3 and version.minor >= 7:
        print("⚠️  Python版本仅支持SCRAM认证 (>= 3.7, < 3.8)")
        return True
    else:
        print("❌ Python版本不符合要求")
        return False

def check_packages():
    """检查Python包"""
    packages = [
        'confluent_kafka',
        'boto3',
        'aws_msk_iam_sasl_signer',
        'requests'
    ]
    
    all_ok = True
    for package in packages:
        try:
            __import__(package)
            print(f"✅ {package}: 已安装")
        except ImportError:
            print(f"❌ {package}: 未安装")
            all_ok = False
    
    return all_ok

def main():
    print("=== AWS MSK Python客户端环境验证 ===")
    
    python_ok = check_python_version()
    packages_ok = check_packages()
    
    if python_ok and packages_ok:
        print("\n🎉 环境配置完成，可以运行MSK Python客户端！")
        return 0
    else:
        print("\n❌ 环境配置有问题，请检查安装")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x /home/ec2-user/msk-poc/verify_installation.py
chown ec2-user:ec2-user /home/ec2-user/msk-poc/verify_installation.py

echo "=== EC2实例配置完成 ==="
echo "Python 3.8环境已安装"
echo "MSK Python客户端依赖库已安装"
echo "工作目录: /home/ec2-user/msk-poc"
echo "运行验证: python3.8 ~/msk-poc/verify_installation.py"
