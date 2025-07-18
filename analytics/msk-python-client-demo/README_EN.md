# AWS MSK Python Client Connection Solution

> 🎯 **Open Source Project**: This is a complete AWS MSK (Managed Streaming for Apache Kafka) Python client connection demonstration project, supporting both SASL/SCRAM and IAM authentication methods.
> 
> 📚 **Quick Start**: Please refer to [QUICKSTART_EN.md](QUICKSTART_EN.md) for rapid deployment and testing.
> 
> 🌐 **中文版本**: [README.md](README.md) | [QUICKSTART.md](QUICKSTART.md) | [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
> 
> ⚠️ **Note**: Before use, please copy the configuration template files and fill in your actual AWS resource information.

## 📋 Table of Contents

1. [Solution Overview](#solution-overview)
2. [Architecture Design](#architecture-design)
3. [Authentication Methods](#authentication-methods)
4. [IAM Permissions Configuration](#iam-permissions-configuration)
5. [Troubleshooting](#troubleshooting)
6. [Appendix](#appendix)

---

## Solution Overview

This solution provides a complete AWS MSK (Managed Streaming for Apache Kafka) Python client connection implementation, supporting two main authentication methods:

### ✅ Supported Authentication Methods
1. **SASL/SCRAM Authentication** - Username/password authentication
2. **IAM Authentication** - AWS identity authentication (enterprise-grade)

---

## Architecture Design

### Network Architecture Diagram
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

### Component Description
- **MSK Cluster**: 2 kafka.t3.small instances, cross-AZ deployment
- **EC2 Client**: t3.micro instance, Python 3.8 environment
- **Secrets Manager**: Stores SCRAM authentication credentials
- **IAM Role**: Provides necessary AWS service access permissions

---

## Authentication Methods

### 🔐 Method 1: SASL/SCRAM Authentication

**Use Case**: Traditional username/password authentication method

#### Authentication Flow
1. EC2 instance accesses Secrets Manager through IAM role
2. Retrieves SCRAM credentials (username/password) from Secrets Manager
3. Connects to MSK cluster using SCRAM-SHA-512 mechanism
4. Establishes TLS encrypted connection

#### Configuration Information
```bash
# Connection Endpoints
Bootstrap Servers: broker1:9096,broker2:9096

# Authentication Configuration
SASL Mechanism: SCRAM-SHA-512
Security Protocol: SASL_SSL
Username: msk_user (stored in Secrets Manager)
Password: [auto-generated] (stored in Secrets Manager)

# Secret Name
Secret Name: AmazonMSK_msk-poc-msk-scram-credentials
```

#### Python Environment Requirements

**System Requirements**
```bash
# Python Version
Python >= 3.7

# Required System Packages
# Amazon Linux 2
sudo yum install -y gcc python3-devel librdkafka-devel

# Ubuntu/Debian
sudo apt-get install -y gcc python3-dev librdkafka-dev

# CentOS/RHEL
sudo yum install -y gcc python3-devel librdkafka-devel
```

**Python Library Dependencies**
```bash
# Core libraries and versions
confluent-kafka==1.9.2      # Kafka client library
boto3>=1.28.0               # AWS SDK
requests>=2.25.0            # HTTP request library

# Installation command
python3 -m pip install --user confluent-kafka==1.9.2 boto3 requests
```

#### Usage
```bash
# Basic usage
python3 python-clients/producer_scram.py
python3 python-clients/consumer_scram.py

# Custom parameters
export NUM_MESSAGES=10
export MESSAGE_INTERVAL=2
export CONSUME_TIMEOUT=60
export MSK_CONSUMER_GROUP=my-consumer-group
python3 python-clients/producer_scram.py
python3 python-clients/consumer_scram.py
```

### 🔑 Method 2: IAM Authentication (Enterprise-grade)

**Use Case**: Enterprise environment requiring AWS identity integration and fine-grained permission control

#### Authentication Flow Details
1. **Obtain AWS Credentials**: Supports multiple ways to obtain AWS credentials
2. **Generate Authentication Token**: Uses AWS MSK IAM SASL Signer to generate OAuth token
3. **Establish Connection**: Connects to MSK cluster using SASL_OAUTHBEARER mechanism
4. **TLS Encryption**: Establishes secure TLS encrypted connection

#### Python Environment Requirements

**System Requirements**
```bash
# Python version requirement
Python >= 3.8  # Required by aws-msk-iam-sasl-signer-python

# Required system packages
# Amazon Linux 2
sudo yum install -y gcc python38-devel librdkafka-devel

# Ubuntu/Debian
sudo apt-get install -y gcc python3.8-dev librdkafka-dev

# CentOS/RHEL
sudo yum install -y gcc python38-devel librdkafka-devel
```

**Python Library Dependencies**
```bash
# Core libraries and versions
confluent-kafka==1.9.2                    # Kafka client library
boto3>=1.28.0                             # AWS SDK
aws-msk-iam-sasl-signer-python>=1.0.2     # MSK IAM authentication library
requests>=2.25.0                          # HTTP request library

# Installation command
python3.8 -m pip install --user confluent-kafka==1.9.2 boto3 aws-msk-iam-sasl-signer-python requests
```

#### Configuration Information
```bash
# Connection Endpoints
Bootstrap Servers: broker1:9098,broker2:9098

# Authentication Configuration
SASL Mechanism: OAUTHBEARER
Security Protocol: SASL_SSL
OAuth Provider: AWS MSK IAM
```

#### Usage
```bash
# Set environment variables
export MSK_BOOTSTRAP_SERVERS_IAM="broker1:9098,broker2:9098"
export AWS_DEFAULT_REGION="ap-southeast-1"
export MSK_TOPIC="msk-poc-topic"

# Basic usage
python3.8 python-clients/producer_iam_production_fixed.py
python3.8 python-clients/consumer_iam_production.py

# Custom configuration
export NUM_MESSAGES=5
export MESSAGE_INTERVAL=1
export CONSUME_TIMEOUT=30
python3.8 python-clients/producer_iam_production_fixed.py
python3.8 python-clients/consumer_iam_production.py
```

## IAM Permissions Configuration

### EC2 Instance IAM Role Permissions

#### Required IAM Policy
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

#### Secrets Manager Access Permissions
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

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Connection Timeout Issues
**Symptoms**: `Connection timeout` or `Network unreachable`
```bash
# Check security group configuration
aws ec2 describe-security-groups --group-ids sg-xxx --region ap-southeast-1

# Check MSK cluster status
aws kafka describe-cluster --cluster-arn arn:aws:kafka:... --region ap-southeast-1

# Check network connectivity
telnet broker-host 9096
```

#### 2. SCRAM Authentication Failure
**Symptoms**: `Authentication failed` or `Invalid credentials`
```bash
# Check secret status
aws secretsmanager describe-secret \
  --secret-id AmazonMSK_msk-poc-msk-scram-credentials \
  --region ap-southeast-1

# Check secret association status
aws kafka describe-cluster --cluster-arn arn:aws:kafka:... \
  --region ap-southeast-1 | grep -i scram

# Verify IAM permissions
aws sts get-caller-identity
```

#### 3. IAM Authentication Issues
**Symptoms**: `Token generation failed` or `OAuth callback failed`
```bash
# Check IAM role
aws sts assume-role --role-arn arn:aws:iam::...:role/msk-poc-ec2-msk-role \
  --role-session-name test

# Check Python library version
python3.8 -c "from aws_msk_iam_sasl_signer import MSKAuthTokenProvider; print('OK')"

# Check network time synchronization
sudo chrony sources -v
```

#### 4. Python Package Issues
**Symptoms**: `ModuleNotFoundError` or `Import Error`
```bash
# Reinstall packages
python3.8 -m pip install --user --upgrade confluent-kafka boto3 aws-msk-iam-sasl-signer-python

# Check package versions
python3.8 -m pip list --user | grep -E "(confluent|boto3|aws-msk)"

# Check Python path
python3.8 -c "import sys; print(sys.path)"
```

---

## Appendix

### A. EC2 Instance Configuration Details

#### Instance Specifications
```yaml
Instance Type: t3.micro
vCPU: 2
Memory: 1 GiB
Network Performance: Up to 5 Gigabit
EBS Optimized: Enabled by default
Storage: 20 GB gp3
```

#### Operating System Configuration
```bash
Operating System: Amazon Linux 2
Kernel Version: 5.10.x
Python Version: 3.7.16 (default), 3.8.20 (installed)
Package Manager: yum, pip3
```

### B. MSK Cluster Configuration Details

#### Cluster Specifications
```yaml
Cluster Name: msk-poc-cluster
Kafka Version: 2.8.1
Instance Type: kafka.t3.small
Instance Count: 2
Availability Zones: ap-southeast-1a, ap-southeast-1b
```

#### Storage Configuration
```yaml
Storage Type: EBS gp3
Storage per Broker: 100 GB
Encryption: Enabled (AWS KMS)
```

#### Authentication Configuration
```yaml
TLS Encryption: Enabled
SASL/SCRAM: Enabled
  - Username: msk_user
  - Password: Stored in Secrets Manager
IAM Authentication: Enabled
  - Port: 9098
  - Mechanism: SASL_OAUTHBEARER
```

### C. Network Port Description

#### MSK Cluster Ports
```
9092: PLAINTEXT (not enabled)
9094: TLS (client to broker)
9096: SASL_SSL (SCRAM authentication)
9098: SASL_SSL (IAM authentication)
2181: Zookeeper (internal use)
```

### D. Complete Environment Variables List

#### MSK Connection Configuration
```bash
MSK_CLUSTER_ARN="arn:aws:kafka:ap-southeast-1:xxx:cluster/msk-poc-cluster/xxx"
MSK_CLUSTER_NAME="msk-poc-cluster"
MSK_BOOTSTRAP_SERVERS_IAM="broker1:9098,broker2:9098"
MSK_BOOTSTRAP_SERVERS_SCRAM="broker1:9096,broker2:9096"
MSK_BOOTSTRAP_SERVERS_TLS="broker1:9094,broker2:9094"
MSK_ZOOKEEPER_CONNECT="zk1:2181,zk2:2181,zk3:2181"
```

#### Authentication Configuration
```bash
MSK_SCRAM_SECRET_ARN="arn:aws:secretsmanager:ap-southeast-1:xxx:secret:xxx"
MSK_SCRAM_SECRET_NAME="AmazonMSK_msk-poc-msk-scram-credentials"
```

#### AWS Configuration
```bash
AWS_DEFAULT_REGION="ap-southeast-1"
AWS_REGION="ap-southeast-1"
```

### E. Terraform Deployment Guide

#### Prerequisites
Ensure the deployment account has the following permissions:
- EC2: Create instances, security groups, key pairs
- MSK: Create clusters, configure authentication
- IAM: Create roles, policies, instance profiles
- Secrets Manager: Create and manage secrets
- KMS: Create and use encryption keys
- CloudWatch: Create log groups
- SSM: Session Manager access

#### Deployment Steps
```bash
cd terraform

# Initialize Terraform
terraform init

# View deployment plan
terraform plan

# Execute deployment (approximately 30-40 minutes)
terraform apply

# Confirm deployment
# Enter 'yes' to confirm
```

#### Verify Deployment
```bash
# Check MSK cluster status
aws kafka describe-cluster --cluster-arn $(terraform output -raw msk_cluster_arn) --region ap-southeast-1

# Check EC2 instance status
aws ec2 describe-instances --instance-ids $(terraform output -raw ec2_instance_id) --region ap-southeast-1

# Check Secrets Manager secret
aws secretsmanager describe-secret --secret-id $(terraform output -raw scram_secret_name) --region ap-southeast-1
```

#### Automatic Configuration Generation
After deployment, use scripts to automatically generate configuration files:

```bash
# Return to project root directory
cd ..

# Automatically generate configuration file (recommended)
./scripts/generate_config.sh

# Or generate from JSON output
cd terraform
terraform output -json > ../terraform_outputs.json
cd ..
./scripts/parse_terraform_outputs.sh

# Verify generated configuration
./verify_config.sh

# Load configuration and test
source msk_config.env
python3 python-clients/producer_scram.py
```

---

**Note**: Before using this project, please ensure you have appropriate AWS permissions and understand the associated costs.
