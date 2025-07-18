# AWS MSK Python Client - Quick Start

> 🌐 **中文版本**: [QUICKSTART.md](QUICKSTART.md)

## 🚀 One-Click Deployment (Recommended)

The simplest deployment method:

```bash
# Clone the project
git clone https://github.com/cncoder/aws-field-guide-book.git
cd aws-field-guide-book/analytics/msk-python-client-demo

# Configure Terraform variables
cp terraform/terraform.tfvars.template terraform/terraform.tfvars
vim terraform/terraform.tfvars  # Fill in your actual values

# One-click deployment
./one_click_deploy.sh
```

## 🔧 Manual Deployment

### 1. Environment Setup

```bash
# Clone the project
git clone https://github.com/cncoder/aws-field-guide-book.git
cd aws-field-guide-book/analytics/msk-python-client-demo

# Install dependencies
pip3 install -r requirements.txt
```

### 2. Deploy Infrastructure

```bash
cd terraform

# Copy variable template
cp terraform.tfvars.template terraform.tfvars

# Edit variable file, fill in your actual values
vim terraform.tfvars

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

### 3. Automatic Configuration Generation

After deployment, use Terraform output to automatically generate configuration:

```bash
# Return to project root directory
cd ..

# Use script to automatically generate configuration file
./scripts/generate_config.sh

# Or manually generate configuration from Terraform output
cd terraform
terraform output -json > ../terraform_outputs.json
cd ..
./scripts/parse_terraform_outputs.sh
```

### 4. Verify Configuration

```bash
# Verify environment variable configuration
./verify_config.sh

# Load environment variables
source msk_config.env
```

### 5. Run Tests

```bash
# Test SCRAM authentication
python3 python-clients/producer_scram.py
python3 python-clients/consumer_scram.py

# Test IAM authentication (requires Python 3.8+)
python3.8 python-clients/producer_iam_production_fixed.py
python3.8 python-clients/consumer_iam_production.py
```

## 🔄 Using Existing MSK Cluster

If you already have an MSK cluster, you can configure manually:

```bash
# Copy configuration template
cp msk_config.env.template msk_config.env

# Edit configuration file, fill in your actual values
vim msk_config.env

# Verify configuration
./verify_config.sh
```

## 📚 Detailed Documentation

Please refer to [README_EN.md](README_EN.md) for complete configuration and usage instructions.

## 🔧 Troubleshooting

### Common Issues

1. **Connection Timeout**: Check security group and network configuration
2. **Authentication Failure**: Verify IAM permissions and Secrets Manager configuration
3. **Package Import Error**: Confirm Python version and dependency package installation

### Getting Help

- Check detailed log output
- Check AWS CloudWatch logs
- Refer to the troubleshooting section in README_EN.md
