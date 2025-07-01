#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️ $1${NC}"
}

print_step() {
    echo -e "${PURPLE}🔸 $1${NC}"
}

# 检查命令是否存在
check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查文件是否存在
check_file() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# 用户输入函数
get_user_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        echo -e "${CYAN}$prompt (默认: $default): ${NC}"
    else
        echo -e "${CYAN}$prompt: ${NC}"
    fi
    
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        input="$default"
    fi
    
    eval "$var_name='$input'"
}

# 确认函数
confirm() {
    local prompt="$1"
    echo -e "${YELLOW}$prompt (y/N): ${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# 主函数
main() {
    print_header "🚀 Loki Chunk 到 AWS Macie 分析管道"
    
    echo -e "${CYAN}欢迎使用 Loki 敏感数据分析工具！${NC}"
    echo -e "${CYAN}本工具将引导您完成所有必要的设置和配置。${NC}"
    echo ""
    
    # 步骤1: 环境检查
    print_step "步骤1: 环境依赖检查"
    
    # 检查Python
    if check_command python3; then
        python_version=$(python3 --version 2>&1)
        print_success "Python环境: $python_version"
    else
        print_error "Python3未安装，请先安装Python3"
        exit 1
    fi
    
    # 检查pip和boto3
    if python3 -c "import boto3" 2>/dev/null; then
        print_success "boto3已安装"
    else
        print_warning "boto3未安装"
        if confirm "是否现在安装boto3?"; then
            pip3 install boto3
            if [ $? -eq 0 ]; then
                print_success "boto3安装成功"
            else
                print_error "boto3安装失败"
                exit 1
            fi
        else
            print_error "boto3是必需的依赖"
            exit 1
        fi
    fi
    
    # 检查AWS CLI
    if check_command aws; then
        aws_version=$(aws --version 2>&1)
        print_success "AWS CLI: $aws_version"
    else
        print_error "AWS CLI未安装，请先安装AWS CLI"
        exit 1
    fi
    
    # 检查AWS凭证
    if aws sts get-caller-identity >/dev/null 2>&1; then
        aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        aws_region=$(aws configure get region 2>/dev/null || echo "未设置")
        print_success "AWS凭证已配置 (账户: $aws_account, 区域: $aws_region)"
    else
        print_error "AWS凭证未配置"
        if confirm "是否现在配置AWS凭证?"; then
            aws configure
            if aws sts get-caller-identity >/dev/null 2>&1; then
                print_success "AWS凭证配置成功"
            else
                print_error "AWS凭证配置失败"
                exit 1
            fi
        else
            print_error "AWS凭证是必需的"
            exit 1
        fi
    fi
    
    # 检查Go环境（用于编译chunks-inspect）
    if check_command go; then
        go_version=$(go version 2>&1)
        print_success "Go环境: $go_version"
        GO_AVAILABLE=true
    else
        print_warning "Go环境未安装，无法自动编译chunks-inspect"
        GO_AVAILABLE=false
    fi
    
    echo ""
    
    # 步骤2: chunks-inspect工具检查
    print_step "步骤2: chunks-inspect工具检查"
    
    if check_file "./chunks-inspect"; then
        print_success "chunks-inspect工具已存在"
        if confirm "是否重新编译chunks-inspect工具?"; then
            NEED_COMPILE=true
        else
            NEED_COMPILE=false
        fi
    else
        print_warning "chunks-inspect工具不存在"
        NEED_COMPILE=true
    fi
    
    if [ "$NEED_COMPILE" = true ]; then
        if [ "$GO_AVAILABLE" = true ]; then
            print_info "开始编译chunks-inspect工具..."
            if check_file "./install_chunks_inspect.sh"; then
                ./install_chunks_inspect.sh
                if [ $? -eq 0 ]; then
                    print_success "chunks-inspect编译成功"
                else
                    print_error "chunks-inspect编译失败"
                    exit 1
                fi
            else
                print_error "install_chunks_inspect.sh脚本不存在"
                exit 1
            fi
        else
            print_error "需要Go环境来编译chunks-inspect工具"
            print_info "请安装Go: https://golang.org/dl/"
            print_info "或手动编译chunks-inspect: https://github.com/grafana/loki/tree/main/cmd/chunks-inspect"
            exit 1
        fi
    fi
    
    echo ""
    
    # 步骤3: Loki chunk文件检查
    print_step "步骤3: Loki chunk文件检查"
    
    if [ -d "./lokichunk" ]; then
        chunk_count=$(find ./lokichunk -type f | wc -l)
        if [ "$chunk_count" -gt 0 ]; then
            print_success "找到 $chunk_count 个chunk文件"
            
            # 测试文件解析
            print_info "测试chunk文件解析..."
            python3 test_chunk_extraction.py > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                print_success "chunk文件解析测试通过"
            else
                print_warning "chunk文件解析测试失败，但将继续执行"
            fi
        else
            print_error "lokichunk目录为空"
            print_info "请将Loki chunk文件放入lokichunk目录"
            exit 1
        fi
    else
        print_error "lokichunk目录不存在"
        print_info "请创建lokichunk目录并放入Loki chunk文件"
        exit 1
    fi
    
    echo ""
    
    # 步骤4: 配置文件设置
    print_step "步骤4: 配置文件设置"
    
    NEED_CONFIG=false
    CONFIG_ISSUES=()
    
    if check_file "./config.json"; then
        print_info "发现现有配置文件，正在检查..."
        
        # 读取现有配置
        current_scan_bucket=$(python3 -c "import json; print(json.load(open('config.json'))['s3']['scan_bucket'])" 2>/dev/null || echo "")
        current_results_bucket=$(python3 -c "import json; print(json.load(open('config.json'))['s3']['results_bucket'])" 2>/dev/null || echo "")
        current_region=$(python3 -c "import json; print(json.load(open('config.json'))['aws']['region'])" 2>/dev/null || echo "")
        
        # 严格检查默认值和问题配置
        if [ "$current_scan_bucket" = "your-macie-scan-bucket" ]; then
            NEED_CONFIG=true
            CONFIG_ISSUES+=("扫描存储桶使用默认值")
        fi
        
        if [ "$current_results_bucket" = "your-macie-results-bucket" ]; then
            NEED_CONFIG=true
            CONFIG_ISSUES+=("结果存储桶使用默认值")
        fi
        
        if [ -z "$current_region" ] || [ "$current_region" = "your-region" ]; then
            NEED_CONFIG=true
            CONFIG_ISSUES+=("AWS区域未设置或使用默认值")
        fi
        
        # 检查是否包含测试字符串
        if [[ "$current_scan_bucket" == *"test"* ]] || [[ "$current_scan_bucket" == *"example"* ]]; then
            NEED_CONFIG=true
            CONFIG_ISSUES+=("扫描存储桶名称看起来像测试值")
        fi
        
        if [[ "$current_results_bucket" == *"test"* ]] || [[ "$current_results_bucket" == *"example"* ]]; then
            NEED_CONFIG=true
            CONFIG_ISSUES+=("结果存储桶名称看起来像测试值")
        fi
        
        if [ "$NEED_CONFIG" = false ]; then
            print_success "配置文件检查通过"
            print_info "扫描存储桶: $current_scan_bucket"
            print_info "结果存储桶: $current_results_bucket"
            print_info "AWS区域: $current_region"
            
            if confirm "配置看起来正确，是否重新配置?"; then
                NEED_CONFIG=true
            fi
        else
            print_warning "配置文件存在问题:"
            for issue in "${CONFIG_ISSUES[@]}"; do
                echo "  ❌ $issue"
            done
            print_warning "必须重新配置"
        fi
    else
        print_warning "配置文件不存在"
        NEED_CONFIG=true
    fi
    
    if [ "$NEED_CONFIG" = true ]; then
        echo ""
        print_info "🔧 开始配置设置 (所有标记为[必填]的项目都必须填写)"
        
        # 强制输入AWS区域
        while true; do
            get_user_input "[必填] AWS区域 (如: us-east-1, ap-northeast-1)" "" "aws_region"
            if [ -n "$aws_region" ] && [ ${#aws_region} -gt 5 ]; then
                break
            else
                print_error "AWS区域不能为空且格式要正确"
            fi
        done
        
        # 强制输入扫描存储桶
        while true; do
            get_user_input "[必填] 扫描存储桶名称 (用于存储待分析的文件)" "" "scan_bucket"
            if [ -n "$scan_bucket" ] && [ ${#scan_bucket} -ge 3 ] && [ "$scan_bucket" != "your-macie-scan-bucket" ]; then
                # 基本格式验证
                if [[ "$scan_bucket" =~ ^[a-z0-9.-]+$ ]] && [[ ! "$scan_bucket" =~ ^- ]] && [[ ! "$scan_bucket" =~ -$ ]]; then
                    break
                else
                    print_error "存储桶名称格式不正确 (只能包含小写字母、数字、点和连字符，不能以连字符开头或结尾)"
                fi
            else
                print_error "扫描存储桶名称不能为空、太短或使用默认值"
            fi
        done
        
        # 强制输入结果存储桶
        while true; do
            get_user_input "[必填] 结果存储桶名称 (用于存储分析结果)" "" "results_bucket"
            if [ -n "$results_bucket" ] && [ ${#results_bucket} -ge 3 ] && [ "$results_bucket" != "your-macie-results-bucket" ]; then
                if [ "$results_bucket" != "$scan_bucket" ]; then
                    # 基本格式验证
                    if [[ "$results_bucket" =~ ^[a-z0-9.-]+$ ]] && [[ ! "$results_bucket" =~ ^- ]] && [[ ! "$results_bucket" =~ -$ ]]; then
                        break
                    else
                        print_error "存储桶名称格式不正确 (只能包含小写字母、数字、点和连字符，不能以连字符开头或结尾)"
                    fi
                else
                    print_error "结果存储桶不能与扫描存储桶相同"
                fi
            else
                print_error "结果存储桶名称不能为空、太短或使用默认值"
            fi
        done
        
        # 可选：最大等待时间
        get_user_input "[可选] 最大等待时间(分钟)" "60" "max_wait"
        
        # 显示配置摘要并要求确认
        echo ""
        print_info "📋 请确认您的配置:"
        echo "  AWS区域: $aws_region"
        echo "  扫描存储桶: $scan_bucket"
        echo "  结果存储桶: $results_bucket"
        echo "  最大等待时间: $max_wait 分钟"
        echo ""
        
        # 强制确认
        while true; do
            echo -e "${YELLOW}确认以上配置正确吗? 输入 'yes' 继续，'no' 重新配置: ${NC}"
            read -r confirm_response
            if [ "$confirm_response" = "yes" ]; then
                break
            elif [ "$confirm_response" = "no" ]; then
                print_info "重新开始配置..."
                continue 2  # 重新开始配置循环
            else
                print_error "请输入 'yes' 或 'no'"
            fi
        done
        
        # 验证存储桶
        print_info "验证S3存储桶..."
        
        if aws s3 ls "s3://$scan_bucket" --region "$aws_region" >/dev/null 2>&1; then
            print_success "扫描存储桶可访问: $scan_bucket"
        else
            print_warning "扫描存储桶不可访问: $scan_bucket"
            if confirm "是否创建存储桶?"; then
                aws s3 mb "s3://$scan_bucket" --region "$aws_region"
                if [ $? -eq 0 ]; then
                    print_success "扫描存储桶创建成功"
                else
                    print_error "扫描存储桶创建失败"
                    exit 1
                fi
            else
                print_error "需要可访问的扫描存储桶"
                exit 1
            fi
        fi
        
        if aws s3 ls "s3://$results_bucket" --region "$aws_region" >/dev/null 2>&1; then
            print_success "结果存储桶可访问: $results_bucket"
        else
            print_warning "结果存储桶不可访问: $results_bucket"
            if confirm "是否创建存储桶?"; then
                aws s3 mb "s3://$results_bucket" --region "$aws_region"
                if [ $? -eq 0 ]; then
                    print_success "结果存储桶创建成功"
                else
                    print_error "结果存储桶创建失败"
                    exit 1
                fi
            else
                print_error "需要可访问的结果存储桶"
                exit 1
            fi
        fi
        
        # 其他配置
        get_user_input "最大等待时间(分钟)" "60" "max_wait"
        
        # 生成配置文件
        cat > config.json << EOF
{
  "aws": {
    "region": "$aws_region",
    "profile": null
  },
  "s3": {
    "scan_bucket": "$scan_bucket",
    "results_bucket": "$results_bucket",
    "scan_prefix": "loki-complete",
    "results_prefix": "loki-analysis"
  },
  "macie": {
    "finding_publishing_frequency": "FIFTEEN_MINUTES",
    "sampling_percentage": 100,
    "max_wait_minutes": $max_wait
  },
  "processing": {
    "chunk_directory": "./lokichunk",
    "output_directory": "./extracted_texts",
    "temp_directory": "./temp"
  },
  "logging": {
    "level": "INFO",
    "file_pattern": "loki_analysis_{timestamp}.log"
  }
}
EOF
        
        print_success "配置文件已更新"
    fi
    
    echo ""
    
    # 步骤5: Macie服务检查
    print_step "步骤5: AWS Macie服务检查"
    
    macie_region=$(python3 -c "import json; print(json.load(open('config.json'))['aws']['region'])" 2>/dev/null)
    
    if aws macie2 get-macie-session --region "$macie_region" >/dev/null 2>&1; then
        print_success "Macie服务已启用"
    else
        print_warning "Macie服务未启用"
        print_info "管道将自动尝试启用Macie服务"
        print_info "注意: 启用Macie可能产生费用"
    fi
    
    echo ""
    
    # 步骤6: 最终确认
    print_step "步骤6: 执行确认"
    
    echo -e "${CYAN}配置摘要:${NC}"
    echo -e "  AWS区域: $(python3 -c "import json; print(json.load(open('config.json'))['aws']['region'])" 2>/dev/null)"
    echo -e "  扫描存储桶: $(python3 -c "import json; print(json.load(open('config.json'))['s3']['scan_bucket'])" 2>/dev/null)"
    echo -e "  结果存储桶: $(python3 -c "import json; print(json.load(open('config.json'))['s3']['results_bucket'])" 2>/dev/null)"
    echo -e "  Chunk文件数: $chunk_count"
    echo -e "  最大等待时间: $(python3 -c "import json; print(json.load(open('config.json'))['macie']['max_wait_minutes'])" 2>/dev/null) 分钟"
    echo ""
    
    if confirm "是否开始执行分析管道?"; then
        echo ""
        print_header "🚀 开始执行分析管道"
        
        # 生成日志文件名
        timestamp=$(date +"%Y%m%d_%H%M%S")
        log_file="loki_analysis_${timestamp}.log"
        
        print_info "日志文件: $log_file"
        print_info "执行命令: python3 loki_macie_pipeline.py --config config.json"
        echo ""
        
        # 执行管道
        python3 loki_macie_pipeline.py --config config.json 2>&1 | tee "$log_file"
        
        # 检查执行结果
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo ""
            print_success "分析管道执行完成！"
            print_info "详细日志: $log_file"
            print_info "查看结果: ls -la *analysis*.json"
            
            # 显示结果文件
            result_files=$(ls -1 *analysis*.json 2>/dev/null | head -3)
            if [ -n "$result_files" ]; then
                print_info "生成的结果文件:"
                echo "$result_files" | while read -r file; do
                    echo "  📄 $file"
                done
            fi
            
            echo ""
            print_info "S3结果位置:"
            s3_results_bucket=$(python3 -c "import json; print(json.load(open('config.json'))['s3']['results_bucket'])" 2>/dev/null)
            echo "  ☁️ s3://$s3_results_bucket/loki-analysis/"
            
        else
            echo ""
            print_error "分析管道执行失败"
            print_info "请查看日志文件: $log_file"
            print_info "常见问题排查:"
            echo "  1. 检查AWS权限是否充足"
            echo "  2. 检查S3存储桶是否可访问"
            echo "  3. 检查Macie服务是否可用"
            echo "  4. 检查网络连接是否正常"
            exit 1
        fi
    else
        print_info "用户取消执行"
        print_info "您可以稍后手动运行: python3 loki_macie_pipeline.py --config config.json"
        exit 0
    fi
}

# 脚本入口
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
