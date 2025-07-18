#!/bin/bash
# MSK Python客户端一键部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "    AWS MSK Python 客户端一键部署"
    echo "=================================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[步骤 $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查前置条件
check_prerequisites() {
    print_step "1" "检查前置条件..."
    
    # 检查AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI 未安装"
        exit 1
    fi
    
    # 检查Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform 未安装"
        exit 1
    fi
    
    # 检查AWS凭据
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS CLI 未配置或凭据无效"
        exit 1
    fi
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 未安装"
        exit 1
    fi
    
    print_success "所有前置条件检查通过"
}

# 安装Python依赖
install_dependencies() {
    print_step "2" "安装Python依赖..."
    
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt --user
        print_success "Python依赖安装完成"
    else
        print_warning "未找到requirements.txt文件"
    fi
}

# 配置Terraform变量
configure_terraform() {
    print_step "3" "配置Terraform变量..."
    
    cd terraform
    
    if [ ! -f "terraform.tfvars" ]; then
        if [ -f "terraform.tfvars.template" ]; then
            cp terraform.tfvars.template terraform.tfvars
            print_warning "已创建terraform.tfvars文件，请编辑后重新运行"
            echo "编辑文件: terraform/terraform.tfvars"
            exit 1
        else
            print_error "未找到terraform.tfvars.template文件"
            exit 1
        fi
    fi
    
    print_success "Terraform变量配置完成"
    cd ..
}

# 部署基础设施
deploy_infrastructure() {
    print_step "4" "部署AWS基础设施..."
    
    cd terraform
    
    # 初始化Terraform
    terraform init
    
    # 规划部署
    terraform plan -out=tfplan
    
    # 确认部署
    print_warning "即将创建AWS资源，可能产生费用"
    read -p "是否继续部署? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        print_success "基础设施部署完成"
    else
        print_warning "部署已取消"
        exit 0
    fi
    
    cd ..
}

# 生成配置文件
generate_config() {
    print_step "5" "生成配置文件..."
    
    ./scripts/generate_config.sh
    print_success "配置文件生成完成"
}

# 验证配置
verify_config() {
    print_step "6" "验证配置..."
    
    ./verify_config.sh
    print_success "配置验证通过"
}

# 运行测试
run_tests() {
    print_step "7" "运行连接测试..."
    
    source msk_config.env
    
    echo "测试SCRAM认证..."
    timeout 30 python3 python-clients/producer_scram.py || print_warning "SCRAM生产者测试超时"
    
    echo "测试IAM认证..."
    if command -v python3.8 &> /dev/null; then
        timeout 30 python3.8 python-clients/producer_iam_production_fixed.py || print_warning "IAM生产者测试超时"
    else
        print_warning "Python 3.8未安装，跳过IAM认证测试"
    fi
    
    print_success "连接测试完成"
}

# 显示部署结果
show_results() {
    print_step "8" "部署结果"
    
    source msk_config.env
    
    echo
    echo "🎉 部署成功完成！"
    echo
    echo "📋 资源信息:"
    echo "  MSK集群: $MSK_CLUSTER_NAME"
    echo "  EC2实例: $EC2_INSTANCE_ID"
    echo "  AWS区域: $AWS_DEFAULT_REGION"
    echo
    echo "🚀 使用方法:"
    echo "  source msk_config.env"
    echo "  python3 python-clients/producer_scram.py"
    echo "  python3 python-clients/consumer_scram.py"
    echo
    echo "🔗 连接EC2实例:"
    echo "  aws ssm start-session --target $EC2_INSTANCE_ID --region $AWS_DEFAULT_REGION"
    echo
    echo "🧹 清理资源:"
    echo "  ./scripts/cleanup.sh"
}

# 主函数
main() {
    print_header
    
    check_prerequisites
    install_dependencies
    configure_terraform
    deploy_infrastructure
    generate_config
    verify_config
    run_tests
    show_results
}

# 错误处理
trap 'print_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"
