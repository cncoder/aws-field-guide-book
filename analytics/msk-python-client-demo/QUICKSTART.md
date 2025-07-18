# AWS MSK Python 客户端 - 快速开始

> 🌐 **English Version**: [QUICKSTART_EN.md](QUICKSTART_EN.md)

## 🚀 一键部署（推荐）

最简单的部署方式：

```bash
# 克隆项目
git clone https://github.com/cncoder/aws-field-guide-book.git
cd aws-field-guide-book/analytics/msk-python-client-demo

# 配置Terraform变量
cp terraform/terraform.tfvars.template terraform/terraform.tfvars
vim terraform/terraform.tfvars  # 填入您的实际值

# 一键部署
./one_click_deploy.sh
```

## 🔧 手动部署

### 1. 环境准备

```bash
# 克隆项目
git clone https://github.com/cncoder/aws-field-guide-book.git
cd aws-field-guide-book/analytics/msk-python-client-demo

# 安装依赖
pip3 install -r requirements.txt
```

### 2. 部署基础设施

```bash
cd terraform

# 复制变量模板
cp terraform.tfvars.template terraform.tfvars

# 编辑变量文件，填入您的实际值
vim terraform.tfvars

# 部署基础设施
terraform init
terraform plan
terraform apply
```

### 3. 自动配置环境变量

部署完成后，使用Terraform输出自动生成配置：

```bash
# 返回项目根目录
cd ..

# 使用脚本自动生成配置文件
./scripts/generate_config.sh

# 或者手动从Terraform输出生成配置
cd terraform
terraform output -json > ../terraform_outputs.json
cd ..
./scripts/parse_terraform_outputs.sh
```

### 4. 验证配置

```bash
# 验证环境变量配置
./verify_config.sh

# 加载环境变量
source msk_config.env
```

### 5. 运行测试

```bash
# 测试 SCRAM 认证
python3 python-clients/producer_scram.py
python3 python-clients/consumer_scram.py

# 测试 IAM 认证 (需要 Python 3.8+)
python3.8 python-clients/producer_iam_production_fixed.py
python3.8 python-clients/consumer_iam_production.py
```

## 🔄 使用现有MSK集群

如果您已有MSK集群，可以手动配置：

```bash
# 复制配置模板
cp msk_config.env.template msk_config.env

# 编辑配置文件，填入您的实际值
vim msk_config.env

# 验证配置
./verify_config.sh
```

## 📚 详细文档

请参阅 [README.md](README.md) 获取完整的配置和使用说明。

## 🔧 故障排除

### 常见问题

1. **连接超时**: 检查安全组和网络配置
2. **认证失败**: 验证IAM权限和Secrets Manager配置
3. **包导入错误**: 确认Python版本和依赖包安装

### 获取帮助

- 查看详细日志输出
- 检查AWS CloudWatch日志
- 参考README中的故障排除章节
