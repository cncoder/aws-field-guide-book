# AWS MSK Python 客户端连接解决方案

> 🎯 **开源项目**: 这是一个完整的AWS MSK (Managed Streaming for Apache Kafka) Python客户端连接演示项目，支持SASL/SCRAM和IAM两种认证方式。
> 
> 📚 **快速开始**: 请参阅 [QUICKSTART.md](QUICKSTART.md) 快速部署和测试。
> 
> ⚠️ **注意**: 使用前请复制配置模板文件并填入您的实际AWS资源信息。


## 📋 目录

1. [解决方案概述](#解决方案概述)
2. [架构设计](#架构设计)
3. [认证方式详解](#认证方式详解)
4. [IAM权限配置](#iam权限配置)
5. [故障排除](#故障排除)
6. [附录](#附录)

---

## 解决方案概述

本解决方案提供了一个完整的AWS MSK (Managed Streaming for Apache Kafka) Python客户端连接实现，支持两种主要认证方式：

### ✅ 支持的认证方式
1. **SASL/SCRAM认证** - 用户名密码认证
2. **IAM认证** - AWS身份认证（企业级）

---

## 架构设计

### 网络架构图
```
┌─────────────────────────────────────────────────────────────────┐
│                    VPC: 10.50.0.0/16                           │
│                                                                 │
│  ┌─────────────────────┐         ┌─────────────────────────────┐ │
│  │   Private Subnet    │         │        MSK Cluster         │ │
│  │   10.50.128.0/20    │         │    (Multi-AZ Deployment)   │ │
│  │                     │         │                             │ │
│  │  ┌───────────────┐  │         │  ┌─────────────────────────┐ │ │
│  │  │      EC2      │  │◄───────►│  │  Broker 1 (AZ-1a)      │ │ │
│  │  │   t3.micro    │  │         │  │  Port 9096 (SCRAM)     │ │ │
│  │  │  Python 3.8   │  │         │  │  Port 9098 (IAM)       │ │ │
│  │  │               │  │         │  └─────────────────────────┘ │ │
│  │  └───────────────┘  │         │                             │ │
│  └─────────────────────┘         │  ┌─────────────────────────┐ │ │
│                                  │  │  Broker 2 (AZ-1b)      │ │ │
│  ┌─────────────────────┐         │  │  Port 9096 (SCRAM)     │ │ │
│  │   Secrets Manager   │         │  │  Port 9098 (IAM)       │ │ │
│  │   SCRAM Credentials │         │  └─────────────────────────┘ │ │
│  └─────────────────────┘         └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 组件说明
- **MSK集群**: 2个kafka.t3.small实例，跨AZ部署
- **EC2客户端**: t3.micro实例，Python 3.8环境
- **Secrets Manager**: 存储SCRAM认证凭据
- **IAM角色**: 提供必要的AWS服务访问权限

---

## 认证方式详解

### 🔐 方式一：SASL/SCRAM认证

**适用场景**: 传统用户名密码认证方式

#### 认证流程
1. EC2实例通过IAM角色访问Secrets Manager
2. 从Secrets Manager获取SCRAM凭据（用户名/密码）
3. 使用SCRAM-SHA-512机制连接MSK集群
4. 建立TLS加密连接

#### 配置信息
```bash
# 连接端点
Bootstrap Servers: broker1:9096,broker2:9096

# 认证配置
SASL Mechanism: SCRAM-SHA-512
Security Protocol: SASL_SSL
Username: msk_user (存储在Secrets Manager)
Password: [自动生成] (存储在Secrets Manager)

# Secret名称
Secret Name: AmazonMSK_msk-poc-msk-scram-credentials
```

#### Python环境要求

**系统要求**
```bash
# Python版本
Python >= 3.7

# 必需的系统包
# Amazon Linux 2
sudo yum install -y gcc python3-devel librdkafka-devel

# Ubuntu/Debian
sudo apt-get install -y gcc python3-dev librdkafka-dev

# CentOS/RHEL
sudo yum install -y gcc python3-devel librdkafka-devel
```

**Python库依赖**
```bash
# 核心库及版本
confluent-kafka==1.9.2      # Kafka客户端库
boto3>=1.28.0               # AWS SDK
requests>=2.25.0            # HTTP请求库

# 安装命令
python3 -m pip install --user confluent-kafka==1.9.2 boto3 requests
```

**requirements.txt文件**
```txt
confluent-kafka==1.9.2
boto3>=1.28.0
requests>=2.25.0
botocore>=1.31.0
urllib3<2.0
```

#### AWS官方文档参考

**MSK SASL/SCRAM认证设置**
- [Amazon MSK SASL/SCRAM身份验证](https://docs.aws.amazon.com/msk/latest/developerguide/msk-password.html)
- [使用AWS Secrets Manager管理MSK凭据](https://docs.aws.amazon.com/msk/latest/developerguide/msk-password.html#msk-password-tutorial)
- [MSK集群安全配置](https://docs.aws.amazon.com/msk/latest/developerguide/security.html)


#### 环境准备

**1. 连接到EC2实例**

方法1: SSH连接
```bash
# 使用SSH密钥连接
ssh -i your-key.pem ec2-user@your-ec2-ip

# 使用SSH代理转发
ssh -A ec2-user@your-ec2-ip
```

方法2: Session Manager连接
```bash
# 获取实例ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=msk-poc-ec2" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text --region ap-southeast-1)

# 通过Session Manager连接
aws ssm start-session --target $INSTANCE_ID --region ap-southeast-1
```

**2. 环境变量设置**
```bash
# 进入工作目录
cd /home/ec2-user/msk-poc

# 加载环境变量
source msk_config.env

# 验证环境变量
echo "SCRAM Bootstrap: $MSK_BOOTSTRAP_SERVERS_SCRAM"
echo "IAM Bootstrap: $MSK_BOOTSTRAP_SERVERS_IAM"
echo "Secret Name: $MSK_SCRAM_SECRET_NAME"
```

#### SCRAM生产者代码 (producer_scram.py)
```python
#!/usr/bin/env python3
"""
AWS MSK SASL/SCRAM 认证生产者
支持从 Secrets Manager 获取认证凭据
"""

import os
import json
import time
import logging
from datetime import datetime
from confluent_kafka import Producer
import boto3
from botocore.exceptions import ClientError

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_secret_value(secret_name, region_name):
    """从 AWS Secrets Manager 获取密钥值"""
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        secret = get_secret_value_response['SecretString']
        return json.loads(secret)
    except ClientError as e:
        logger.error(f"获取密钥失败: {e}")
        raise e

def delivery_report(err, msg):
    """消息传递回调函数"""
    if err is not None:
        logger.error(f'消息传递失败: {err}')
    else:
        logger.info(f'消息 {msg.key().decode("utf-8")} 已发送到 {msg.topic()} [{msg.partition()}] offset {msg.offset()}')

def create_producer():
    """创建 SASL/SCRAM 认证的 Kafka 生产者"""
    # 环境变量
    bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_SCRAM')
    secret_name = os.getenv('MSK_SCRAM_SECRET_NAME', 'AmazonMSK_msk-poc-msk-scram-credentials')
    region = os.getenv('AWS_DEFAULT_REGION', 'ap-southeast-1')
    
    if not bootstrap_servers:
        raise ValueError("MSK_BOOTSTRAP_SERVERS_SCRAM 环境变量未设置")
    
    logger.info("启动带有SASL/SCRAM认证的MSK生产者")
    
    # 获取SCRAM凭据
    try:
        credentials = get_secret_value(secret_name, region)
        username = credentials['username']
        password = credentials['password']
        logger.info(f"用户名: {username}")
    except Exception as e:
        logger.error(f"获取SCRAM凭据失败: {e}")
        raise
    
    # 生产者配置
    producer_config = {
        'bootstrap.servers': bootstrap_servers,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'SCRAM-SHA-512',
        'sasl.username': username,
        'sasl.password': password,
        'client.id': 'msk-scram-producer',
        'acks': 'all',
        'retries': 3,
        'retry.backoff.ms': 1000,
        'request.timeout.ms': 30000,
        'delivery.timeout.ms': 60000
    }
    
    try:
        producer = Producer(producer_config)
        logger.info("使用SASL/SCRAM认证成功创建生产者")
        return producer
    except Exception as e:
        logger.error(f"创建生产者失败: {e}")
        raise

def main():
    """主函数"""
    try:
        # 创建生产者
        producer = create_producer()
        
        # 配置参数
        topic = os.getenv('MSK_TOPIC', 'msk-poc-topic')
        num_messages = int(os.getenv('NUM_MESSAGES', '5'))
        message_interval = int(os.getenv('MESSAGE_INTERVAL', '1'))
        
        logger.info(f"开始发送 {num_messages} 条消息到主题 '{topic}'")
        
        # 发送消息
        for i in range(1, num_messages + 1):
            message_key = str(i)
            message_value = {
                'message_id': i,
                'timestamp': datetime.now().isoformat(),
                'content': f'SCRAM认证测试消息 {i}',
                'producer': 'msk-scram-producer'
            }
            
            producer.produce(
                topic=topic,
                key=message_key,
                value=json.dumps(message_value, ensure_ascii=False),
                callback=delivery_report
            )
            
            # 等待消息发送
            producer.poll(0)
            
            if i < num_messages:
                time.sleep(message_interval)
        
        # 等待所有消息发送完成
        logger.info("等待所有消息发送完成...")
        producer.flush(timeout=30)
        
        logger.info("所有消息发送完成")
        
    except KeyboardInterrupt:
        logger.info("用户中断程序")
    except Exception as e:
        logger.error(f"程序执行失败: {e}")
        raise
    finally:
        if 'producer' in locals():
            producer.flush()

if __name__ == "__main__":
    main()
```

#### SCRAM消费者代码 (consumer_scram.py)
```python
#!/usr/bin/env python3
"""
AWS MSK SASL/SCRAM 认证消费者
支持从 Secrets Manager 获取认证凭据
"""

import os
import json
import logging
from confluent_kafka import Consumer, KafkaError
import boto3
from botocore.exceptions import ClientError

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_secret_value(secret_name, region_name):
    """从 AWS Secrets Manager 获取密钥值"""
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    
    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        secret = get_secret_value_response['SecretString']
        return json.loads(secret)
    except ClientError as e:
        logger.error(f"获取密钥失败: {e}")
        raise e

def create_consumer():
    """创建 SASL/SCRAM 认证的 Kafka 消费者"""
    # 环境变量
    bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_SCRAM')
    secret_name = os.getenv('MSK_SCRAM_SECRET_NAME', 'AmazonMSK_msk-poc-msk-scram-credentials')
    region = os.getenv('AWS_DEFAULT_REGION', 'ap-southeast-1')
    consumer_group = os.getenv('MSK_CONSUMER_GROUP', 'msk-scram-consumer-group')
    
    if not bootstrap_servers:
        raise ValueError("MSK_BOOTSTRAP_SERVERS_SCRAM 环境变量未设置")
    
    logger.info("启动带有SASL/SCRAM认证的MSK消费者")
    
    # 获取SCRAM凭据
    try:
        credentials = get_secret_value(secret_name, region)
        username = credentials['username']
        password = credentials['password']
        logger.info(f"用户名: {username}")
    except Exception as e:
        logger.error(f"获取SCRAM凭据失败: {e}")
        raise
    
    # 消费者配置
    consumer_config = {
        'bootstrap.servers': bootstrap_servers,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'SCRAM-SHA-512',
        'sasl.username': username,
        'sasl.password': password,
        'group.id': consumer_group,
        'client.id': 'msk-scram-consumer',
        'auto.offset.reset': 'earliest',
        'enable.auto.commit': True,
        'auto.commit.interval.ms': 5000,
        'session.timeout.ms': 30000,
        'heartbeat.interval.ms': 10000
    }
    
    try:
        consumer = Consumer(consumer_config)
        logger.info(f"使用SASL/SCRAM认证成功创建消费者，消费者组: {consumer_group}")
        return consumer
    except Exception as e:
        logger.error(f"创建消费者失败: {e}")
        raise

def main():
    """主函数"""
    consumer = None
    try:
        # 创建消费者
        consumer = create_consumer()
        
        # 配置参数
        topic = os.getenv('MSK_TOPIC', 'msk-poc-topic')
        consume_timeout = int(os.getenv('CONSUME_TIMEOUT', '30'))
        
        # 订阅主题
        consumer.subscribe([topic])
        logger.info(f"已订阅主题: {topic}")
        logger.info(f"开始消费消息，超时时间: {consume_timeout}秒")
        
        message_count = 0
        
        # 消费消息
        while True:
            msg = consumer.poll(timeout=consume_timeout)
            
            if msg is None:
                logger.info(f"在 {consume_timeout} 秒内未收到消息，退出消费")
                break
            
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    logger.info(f"到达分区末尾: {msg.topic()} [{msg.partition()}] offset {msg.offset()}")
                else:
                    logger.error(f"消费者错误: {msg.error()}")
                continue
            
            # 处理消息
            message_count += 1
            try:
                key = msg.key().decode('utf-8') if msg.key() else None
                value = json.loads(msg.value().decode('utf-8'))
                
                logger.info(f"收到消息 {message_count}:")
                logger.info(f"  主题: {msg.topic()}")
                logger.info(f"  分区: {msg.partition()}")
                logger.info(f"  偏移量: {msg.offset()}")
                logger.info(f"  键: {key}")
                logger.info(f"  内容: {value}")
                logger.info("-" * 50)
                
            except json.JSONDecodeError:
                logger.warning(f"消息不是有效的JSON格式: {msg.value()}")
            except Exception as e:
                logger.error(f"处理消息时出错: {e}")
        
        logger.info(f"消费完成，总共处理了 {message_count} 条消息")
        
    except KeyboardInterrupt:
        logger.info("用户中断程序")
    except Exception as e:
        logger.error(f"程序执行失败: {e}")
        raise
    finally:
        if consumer:
            consumer.close()
            logger.info("消费者已关闭")

if __name__ == "__main__":
    main()
```

#### 使用方法
```bash
# 基本使用
python3 producer_scram.py
python3 consumer_scram.py

# 自定义参数
export NUM_MESSAGES=10
export MESSAGE_INTERVAL=2
export CONSUME_TIMEOUT=60
export MSK_CONSUMER_GROUP=my-consumer-group
python3 producer_scram.py
python3 consumer_scram.py
```

### 🔑 方式二：IAM认证（企业级）

**适用场景**: 企业环境，需要AWS身份集成和细粒度权限控制

#### 认证流程详解
1. **获取AWS凭据**: 支持多种方式获取AWS凭据
2. **生成认证令牌**: 使用AWS MSK IAM SASL Signer生成OAuth令牌
3. **建立连接**: 使用SASL_OAUTHBEARER机制连接MSK集群
4. **TLS加密**: 建立安全的TLS加密连接

#### Python环境要求

**系统要求**
```bash
# Python版本要求
Python >= 3.8  # aws-msk-iam-sasl-signer-python要求

# 必需的系统包
# Amazon Linux 2
sudo yum install -y gcc python38-devel librdkafka-devel

# Ubuntu/Debian
sudo apt-get install -y gcc python3.8-dev librdkafka-dev

# CentOS/RHEL
sudo yum install -y gcc python38-devel librdkafka-devel
```

**Python库依赖**
```bash
# 核心库及版本
confluent-kafka==1.9.2                    # Kafka客户端库
boto3>=1.28.0                             # AWS SDK
aws-msk-iam-sasl-signer-python>=1.0.2     # MSK IAM认证库
requests>=2.25.0                          # HTTP请求库

# 安装命令
python3.8 -m pip install --user confluent-kafka==1.9.2 boto3 aws-msk-iam-sasl-signer-python requests
```

**requirements.txt文件**
```txt
confluent-kafka==1.9.2
boto3>=1.28.0
aws-msk-iam-sasl-signer-python>=1.0.2
requests>=2.25.0
botocore>=1.31.0
urllib3<2.0
```

#### AWS官方文档参考

**MSK IAM认证设置**
- [Amazon MSK IAM身份验证和授权](https://docs.aws.amazon.com/msk/latest/developerguide/iam-access-control.html)
- [MSK IAM认证现在支持所有编程语言](https://aws.amazon.com/cn/blogs/big-data/amazon-msk-iam-authentication-now-supports-all-programming-languages/)

**IAM策略和权限**
- [MSK集群策略示例](https://docs.aws.amazon.com/msk/latest/developerguide/iam-access-control.html#kafka-actions)

**库兼容性说明**
- **confluent-kafka 1.9.2**: 稳定版本，与librdkafka 0.11.4兼容
- **aws-msk-iam-sasl-signer-python**: 需要Python 3.8+，提供MSK IAM认证令牌生成功能

#### AWS凭据获取方式

**方法1: IAM角色（推荐生产环境）**
```bash
# EC2实例自动使用附加的IAM角色
# 无需额外配置，自动获取临时凭据
```

**方法2: 环境变量（开发测试）**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"
```

**方法3: AWS CLI配置**
```bash
aws configure set aws_access_key_id your-access-key
aws configure set aws_secret_access_key your-secret-key
aws configure set default.region ap-southeast-1
```

**方法4: 代码中配置（不推荐生产环境）**
```python
import boto3
session = boto3.Session(
    aws_access_key_id='your-access-key',
    aws_secret_access_key='your-secret-key',
    region_name='ap-southeast-1'
)
```

#### Python库实现原理
IAM认证使用`aws-msk-iam-sasl-signer-python`库实现OAuth令牌生成：

```python
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

def oauth_cb(oauth_config):
    # 创建MSK认证令牌提供者
    auth_token_provider = MSKAuthTokenProvider(region='ap-southeast-1')
    
    # 生成认证令牌
    token, expiry_ms = auth_token_provider.generate_auth_token(bootstrap_servers)
    
    # 设置OAuth配置
    oauth_config.token = token
    oauth_config.principal = "msk-iam-user"
```

#### 配置信息
```bash
# 连接端点
Bootstrap Servers: broker1:9098,broker2:9098

# 认证配置
SASL Mechanism: OAUTHBEARER
Security Protocol: SASL_SSL
OAuth Provider: AWS MSK IAM
```

#### 环境准备

**1. 连接到EC2实例**

方法1: SSH连接
```bash
# 使用SSH密钥连接
ssh -i your-key.pem ec2-user@your-ec2-ip

# 使用SSH代理转发
ssh -A ec2-user@your-ec2-ip
```

方法2: Session Manager连接
```bash
# 获取实例ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=msk-poc-ec2" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text --region ap-southeast-1)

# 通过Session Manager连接
aws ssm start-session --target $INSTANCE_ID --region ap-southeast-1
```

**2. 环境变量设置**
```bash
# 进入工作目录
cd /home/ec2-user/msk-poc

# 加载环境变量
source msk_config.env

# 验证环境变量
echo "SCRAM Bootstrap: $MSK_BOOTSTRAP_SERVERS_SCRAM"
echo "IAM Bootstrap: $MSK_BOOTSTRAP_SERVERS_IAM"
echo "Secret Name: $MSK_SCRAM_SECRET_NAME"
```

#### IAM生产者代码 (producer_iam_production_fixed.py)
```python
#!/usr/bin/env python3
"""
AWS MSK IAM 认证生产者 - 生产版本
使用 aws-msk-iam-sasl-signer-python 库进行 IAM 认证
"""

import os
import json
import time
import logging
from datetime import datetime
from confluent_kafka import Producer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def oauth_cb(oauth_config):
    """OAuth回调函数，用于生成MSK IAM认证令牌"""
    try:
        # 获取环境变量
        region = os.getenv('AWS_DEFAULT_REGION', 'ap-southeast-1')
        bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_IAM')
        
        if not bootstrap_servers:
            raise ValueError("MSK_BOOTSTRAP_SERVERS_IAM 环境变量未设置")
        
        logger.info(f"生成IAM认证令牌，区域: {region}")
        
        # 创建MSK认证令牌提供者
        auth_token_provider = MSKAuthTokenProvider(region=region)
        
        # 生成认证令牌
        token, expiry_ms = auth_token_provider.generate_auth_token(bootstrap_servers)
        
        # 设置OAuth配置
        oauth_config.token = token
        oauth_config.principal = "msk-iam-user"
        
        logger.info("IAM认证令牌生成成功")
        
    except Exception as e:
        logger.error(f"OAuth回调失败: {e}")
        raise

def delivery_report(err, msg):
    """消息传递回调函数"""
    if err is not None:
        logger.error(f'消息传递失败: {err}')
    else:
        logger.info(f'消息 {msg.key().decode("utf-8")} 已发送到 {msg.topic()} [{msg.partition()}] offset {msg.offset()}')

def create_producer():
    """创建 IAM 认证的 Kafka 生产者"""
    # 环境变量
    bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_IAM')
    
    if not bootstrap_servers:
        raise ValueError("MSK_BOOTSTRAP_SERVERS_IAM 环境变量未设置")
    
    logger.info("启动带有IAM认证的MSK生产者")
    
    # 生产者配置
    producer_config = {
        'bootstrap.servers': bootstrap_servers,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'OAUTHBEARER',
        'oauth_cb': oauth_cb,
        'client.id': 'msk-iam-producer',
        'acks': 'all',
        'retries': 3,
        'retry.backoff.ms': 1000,
        'request.timeout.ms': 30000,
        'delivery.timeout.ms': 60000
    }
    
    try:
        producer = Producer(producer_config)
        logger.info("使用IAM认证成功创建生产者")
        return producer
    except Exception as e:
        logger.error(f"创建生产者失败: {e}")
        raise

def main():
    """主函数"""
    try:
        # 创建生产者
        producer = create_producer()
        
        # 配置参数
        topic = os.getenv('MSK_TOPIC', 'msk-poc-topic')
        num_messages = int(os.getenv('NUM_MESSAGES', '5'))
        message_interval = int(os.getenv('MESSAGE_INTERVAL', '1'))
        
        logger.info(f"开始发送 {num_messages} 条消息到主题 '{topic}'")
        
        # 发送消息
        for i in range(1, num_messages + 1):
            message_key = str(i)
            message_value = {
                'message_id': i,
                'timestamp': datetime.now().isoformat(),
                'content': f'IAM认证测试消息 {i}',
                'producer': 'msk-iam-producer'
            }
            
            producer.produce(
                topic=topic,
                key=message_key,
                value=json.dumps(message_value, ensure_ascii=False),
                callback=delivery_report
            )
            
            # 等待消息发送
            producer.poll(0)
            
            if i < num_messages:
                time.sleep(message_interval)
        
        # 等待所有消息发送完成
        logger.info("等待所有消息发送完成...")
        producer.flush(timeout=30)
        
        logger.info("所有消息发送完成")
        
    except KeyboardInterrupt:
        logger.info("用户中断程序")
    except Exception as e:
        logger.error(f"程序执行失败: {e}")
        raise
    finally:
        if 'producer' in locals():
            producer.flush()

if __name__ == "__main__":
    main()
```

#### IAM消费者代码 (consumer_iam_production.py)
```python
#!/usr/bin/env python3
"""
AWS MSK IAM 认证消费者 - 生产版本
使用 aws-msk-iam-sasl-signer-python 库进行 IAM 认证
"""

import os
import json
import logging
from confluent_kafka import Consumer, KafkaError
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def oauth_cb(oauth_config):
    """OAuth回调函数，用于生成MSK IAM认证令牌"""
    try:
        # 获取环境变量
        region = os.getenv('AWS_DEFAULT_REGION', 'ap-southeast-1')
        bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_IAM')
        
        if not bootstrap_servers:
            raise ValueError("MSK_BOOTSTRAP_SERVERS_IAM 环境变量未设置")
        
        logger.info(f"生成IAM认证令牌，区域: {region}")
        
        # 创建MSK认证令牌提供者
        auth_token_provider = MSKAuthTokenProvider(region=region)
        
        # 生成认证令牌
        token, expiry_ms = auth_token_provider.generate_auth_token(bootstrap_servers)
        
        # 设置OAuth配置
        oauth_config.token = token
        oauth_config.principal = "msk-iam-user"
        
        logger.info("IAM认证令牌生成成功")
        
    except Exception as e:
        logger.error(f"OAuth回调失败: {e}")
        raise

def create_consumer():
    """创建 IAM 认证的 Kafka 消费者"""
    # 环境变量
    bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_IAM')
    consumer_group = os.getenv('MSK_CONSUMER_GROUP', 'msk-iam-consumer-group')
    
    if not bootstrap_servers:
        raise ValueError("MSK_BOOTSTRAP_SERVERS_IAM 环境变量未设置")
    
    logger.info("启动带有IAM认证的MSK消费者")
    
    # 消费者配置
    consumer_config = {
        'bootstrap.servers': bootstrap_servers,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'OAUTHBEARER',
        'oauth_cb': oauth_cb,
        'group.id': consumer_group,
        'client.id': 'msk-iam-consumer',
        'auto.offset.reset': 'earliest',
        'enable.auto.commit': True,
        'auto.commit.interval.ms': 5000,
        'session.timeout.ms': 30000,
        'heartbeat.interval.ms': 10000
    }
    
    try:
        consumer = Consumer(consumer_config)
        logger.info(f"使用IAM认证成功创建消费者，消费者组: {consumer_group}")
        return consumer
    except Exception as e:
        logger.error(f"创建消费者失败: {e}")
        raise

def main():
    """主函数"""
    consumer = None
    try:
        # 创建消费者
        consumer = create_consumer()
        
        # 配置参数
        topic = os.getenv('MSK_TOPIC', 'msk-poc-topic')
        consume_timeout = int(os.getenv('CONSUME_TIMEOUT', '30'))
        
        # 订阅主题
        consumer.subscribe([topic])
        logger.info(f"已订阅主题: {topic}")
        logger.info(f"开始消费消息，超时时间: {consume_timeout}秒")
        
        message_count = 0
        
        # 消费消息
        while True:
            msg = consumer.poll(timeout=consume_timeout)
            
            if msg is None:
                logger.info(f"在 {consume_timeout} 秒内未收到消息，退出消费")
                break
            
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    logger.info(f"到达分区末尾: {msg.topic()} [{msg.partition()}] offset {msg.offset()}")
                else:
                    logger.error(f"消费者错误: {msg.error()}")
                continue
            
            # 处理消息
            message_count += 1
            try:
                key = msg.key().decode('utf-8') if msg.key() else None
                value = json.loads(msg.value().decode('utf-8'))
                
                logger.info(f"收到消息 {message_count}:")
                logger.info(f"  主题: {msg.topic()}")
                logger.info(f"  分区: {msg.partition()}")
                logger.info(f"  偏移量: {msg.offset()}")
                logger.info(f"  键: {key}")
                logger.info(f"  内容: {value}")
                logger.info("-" * 50)
                
            except json.JSONDecodeError:
                logger.warning(f"消息不是有效的JSON格式: {msg.value()}")
            except Exception as e:
                logger.error(f"处理消息时出错: {e}")
        
        logger.info(f"消费完成，总共处理了 {message_count} 条消息")
        
    except KeyboardInterrupt:
        logger.info("用户中断程序")
    except Exception as e:
        logger.error(f"程序执行失败: {e}")
        raise
    finally:
        if consumer:
            consumer.close()
            logger.info("消费者已关闭")

if __name__ == "__main__":
    main()
```

#### 使用方法
```bash
# 设置环境变量
export MSK_BOOTSTRAP_SERVERS_IAM="broker1:9098,broker2:9098"
export AWS_DEFAULT_REGION="ap-southeast-1"
export MSK_TOPIC="msk-poc-topic"

# 基本使用
python3.8 producer_iam_production_fixed.py
python3.8 consumer_iam_production.py

# 自定义配置
export NUM_MESSAGES=5
export MESSAGE_INTERVAL=1
export CONSUME_TIMEOUT=30
python3.8 producer_iam_production_fixed.py
python3.8 consumer_iam_production.py
```

## IAM权限配置

### EC2实例IAM角色权限

#### 必需的IAM策略
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kafka-cluster:Connect",
                "kafka-cluster:AlterCluster",
                "kafka-cluster:DescribeCluster"
            ],
            "Resource": "arn:aws:kafka:ap-southeast-1:*:cluster/msk-poc-cluster/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kafka-cluster:*Topic*",
                "kafka-cluster:WriteData",
                "kafka-cluster:ReadData"
            ],
            "Resource": "arn:aws:kafka:ap-southeast-1:*:topic/msk-poc-cluster/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kafka-cluster:AlterGroup",
                "kafka-cluster:DescribeGroup"
            ],
            "Resource": "arn:aws:kafka:ap-southeast-1:*:group/msk-poc-cluster/*"
        }
    ]
}
```

#### Secrets Manager访问权限
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:ap-southeast-1:*:secret:AmazonMSK_*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "arn:aws:kms:ap-southeast-1:*:key/*",
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "secretsmanager.ap-southeast-1.amazonaws.com"
                }
            }
        }
    ]
}
```

### Access Key权限配置

#### 最小权限原则
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kafka-cluster:Connect",
                "kafka-cluster:WriteData",
                "kafka-cluster:ReadData",
                "kafka-cluster:CreateTopic",
                "kafka-cluster:DescribeTopic"
            ],
            "Resource": [
                "arn:aws:kafka:ap-southeast-1:*:cluster/msk-poc-cluster/*",
                "arn:aws:kafka:ap-southeast-1:*:topic/msk-poc-cluster/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:ap-southeast-1:*:secret:AmazonMSK_*"
        }
    ]
}
```

---

## 故障排除

### 常见问题及解决方案

#### 1. 连接超时问题
**症状**: `Connection timeout` 或 `Network unreachable`
```bash
# 检查安全组配置
aws ec2 describe-security-groups --group-ids sg-xxx --region ap-southeast-1

# 检查MSK集群状态
aws kafka describe-cluster --cluster-arn arn:aws:kafka:... --region ap-southeast-1

# 检查网络连通性
telnet broker-host 9096
```

#### 2. SCRAM认证失败
**症状**: `Authentication failed` 或 `Invalid credentials`
```bash
# 检查密钥状态
aws secretsmanager describe-secret \
  --secret-id AmazonMSK_msk-poc-msk-scram-credentials \
  --region ap-southeast-1

# 检查密钥关联状态
aws kafka describe-cluster --cluster-arn arn:aws:kafka:... \
  --region ap-southeast-1 | grep -i scram

# 验证IAM权限
aws sts get-caller-identity
```

#### 3. IAM认证问题
**症状**: `Token generation failed` 或 `OAuth callback failed`
```bash
# 检查IAM角色
aws sts assume-role --role-arn arn:aws:iam::...:role/msk-poc-ec2-msk-role \
  --role-session-name test

# 检查Python库版本
python3.8 -c "from aws_msk_iam_sasl_signer import MSKAuthTokenProvider; print('OK')"

# 检查网络时间同步
sudo chrony sources -v
```

#### 4. Python包问题
**症状**: `ModuleNotFoundError` 或 `Import Error`
```bash
# 重新安装包
python3.8 -m pip install --user --upgrade confluent-kafka boto3 aws-msk-iam-sasl-signer-python

# 检查包版本
python3.8 -m pip list --user | grep -E "(confluent|boto3|aws-msk)"

# 检查Python路径
python3.8 -c "import sys; print(sys.path)"
```

### 日志查看

#### 应用日志
```bash
# Python脚本日志输出到stderr
python3 producer_scram.py 2>&1 | tee producer.log

# 查看详细错误信息
export PYTHONPATH=/home/ec2-user/.local/lib/python3.8/site-packages
python3.8 -v producer_iam_production_fixed.py
```

#### MSK集群日志
```bash
# 查看CloudWatch日志组
aws logs describe-log-groups --log-group-name-prefix "/aws/msk" --region ap-southeast-1

# 查看具体日志流
aws logs describe-log-streams --log-group-name "/aws/msk/msk-poc-cluster" --region ap-southeast-1
```

---



---

## 附录

### A. EC2实例配置详情

#### 实例规格
```yaml
实例类型: t3.micro
vCPU: 2
内存: 1 GiB
网络性能: 最高5 Gigabit
EBS优化: 默认启用
存储: 20 GB gp3
```

#### 操作系统配置
```bash
操作系统: Amazon Linux 2
内核版本: 5.10.x
Python版本: 3.7.16 (默认), 3.8.20 (已安装)
包管理器: yum, pip3
```

#### 安装的软件包
```bash
# 系统包
gcc-7.3.1
python38-3.8.20
python38-devel-3.8.20
librdkafka-devel-0.11.4

# Python包
confluent-kafka==1.9.2
boto3==1.37.38
aws-msk-iam-sasl-signer-python==1.0.2
requests==2.32.4
```

#### 网络配置
```yaml
VPC: vpc-052b2576f1eee33cd
子网: 私有子网 (10.50.128.0/20)
安全组: 
  - 出站: 全部允许
  - 入站: 仅SSM Session Manager
弹性IP: 无（私有实例）
```

### B. MSK集群配置详情

#### 集群规格
```yaml
集群名称: msk-poc-cluster
Kafka版本: 2.8.1
实例类型: kafka.t3.small
实例数量: 2
可用区: ap-southeast-1a, ap-southeast-1b
```

#### 存储配置
```yaml
存储类型: EBS gp3
每个代理存储: 100 GB
加密: 启用 (AWS KMS)
```

#### 网络配置
```yaml
VPC: vpc-052b2576f1eee33cd
子网: 
  - subnet-xxx (ap-southeast-1a)
  - subnet-yyy (ap-southeast-1b)
安全组: msk-poc-msk-sg
```

#### 认证配置
```yaml
TLS加密: 启用
SASL/SCRAM: 启用
  - 用户名: msk_user
  - 密码: 存储在Secrets Manager
IAM认证: 启用
  - 端口: 9098
  - 机制: SASL_OAUTHBEARER
```

#### 监控配置
```yaml
CloudWatch监控: 基础监控
JMX导出器: 启用
Prometheus监控: 可选
日志传输: CloudWatch Logs
```

### C. 网络端口说明

#### MSK集群端口
```
9092: PLAINTEXT (未启用)
9094: TLS (客户端到代理)
9096: SASL_SSL (SCRAM认证)
9098: SASL_SSL (IAM认证)
2181: Zookeeper (内部使用)
```

#### 安全组规则
```yaml
MSK安全组 (入站):
  - 端口 9094: 来源 EC2安全组
  - 端口 9096: 来源 EC2安全组  
  - 端口 9098: 来源 EC2安全组
  - 端口 2181: 来源 EC2安全组

EC2安全组 (出站):
  - 全部端口: 目标 0.0.0.0/0
```

### D. 环境变量完整列表

#### MSK连接配置
```bash
MSK_CLUSTER_ARN="arn:aws:kafka:ap-southeast-1:xxx:cluster/msk-poc-cluster/xxx"
MSK_CLUSTER_NAME="msk-poc-cluster"
MSK_BOOTSTRAP_SERVERS_IAM="broker1:9098,broker2:9098"
MSK_BOOTSTRAP_SERVERS_SCRAM="broker1:9096,broker2:9096"
MSK_BOOTSTRAP_SERVERS_TLS="broker1:9094,broker2:9094"
MSK_ZOOKEEPER_CONNECT="zk1:2181,zk2:2181,zk3:2181"
```

#### 认证配置
```bash
MSK_SCRAM_SECRET_ARN="arn:aws:secretsmanager:ap-southeast-1:xxx:secret:xxx"
MSK_SCRAM_SECRET_NAME="AmazonMSK_msk-poc-msk-scram-credentials"
```

#### EC2配置
```bash
EC2_INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"
EC2_PRIVATE_IP="10.x.x.x"
```

#### AWS配置
```bash
AWS_DEFAULT_REGION="ap-southeast-1"
AWS_REGION="ap-southeast-1"
```

### E. Terraform部署指南

#### 前置要求
确保部署账户具有以下权限：
- EC2: 创建实例、安全组、密钥对
- MSK: 创建集群、配置认证
- IAM: 创建角色、策略、实例配置文件
- Secrets Manager: 创建和管理密钥
- KMS: 创建和使用加密密钥
- CloudWatch: 创建日志组
- SSM: Session Manager访问

#### 部署步骤
```bash
cd terraform

# 初始化Terraform
terraform init

# 查看部署计划
terraform plan

# 执行部署（约30-40分钟）
terraform apply

# 确认部署
# 输入 'yes' 确认
```

#### 验证部署
```bash
# 检查MSK集群状态
aws kafka describe-cluster --cluster-arn $(terraform output -raw msk_cluster_arn) --region ap-southeast-1

# 检查EC2实例状态
aws ec2 describe-instances --instance-ids $(terraform output -raw ec2_instance_id) --region ap-southeast-1

# 检查Secrets Manager密钥
aws secretsmanager describe-secret --secret-id $(terraform output -raw scram_secret_name) --region ap-southeast-1
```

#### 自动生成配置文件
部署完成后，使用脚本自动生成配置文件：

```bash
# 返回项目根目录
cd ..

# 自动生成配置文件（推荐）
./scripts/generate_config.sh

# 或者从JSON输出生成
cd terraform
terraform output -json > ../terraform_outputs.json
cd ..
./scripts/parse_terraform_outputs.sh

# 验证生成的配置
./verify_config.sh

# 加载配置并测试
source msk_config.env
python3 python-clients/producer_scram.py
```
