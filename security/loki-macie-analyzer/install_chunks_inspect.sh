#!/bin/bash

echo "🔧 chunks-inspect 工具安装脚本"
echo "================================"

# 检查Go环境
if ! command -v go &> /dev/null; then
    echo "❌ Go语言环境未安装"
    echo "请先安装Go: https://golang.org/dl/"
    exit 1
fi

echo "✅ Go版本: $(go version)"

# 检查是否已存在chunks-inspect
if [ -f "./chunks-inspect" ]; then
    echo "⚠️ chunks-inspect已存在，是否重新编译? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "跳过安装"
        exit 0
    fi
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "📁 临时目录: $TEMP_DIR"

# 克隆Loki仓库
echo "📥 克隆Loki仓库..."
git clone --depth 1 https://github.com/grafana/loki.git "$TEMP_DIR/loki"

if [ $? -ne 0 ]; then
    echo "❌ 克隆仓库失败"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 编译chunks-inspect
echo "🔨 编译chunks-inspect工具..."
cd "$TEMP_DIR/loki/cmd/chunks-inspect"

go build

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 复制到项目目录
echo "📋 复制工具到项目目录..."
cp chunks-inspect "$OLDPWD/"
chmod +x "$OLDPWD/chunks-inspect"

# 清理临时目录
echo "🧹 清理临时文件..."
rm -rf "$TEMP_DIR"

# 验证安装
cd "$OLDPWD"
if [ -f "./chunks-inspect" ]; then
    echo "✅ chunks-inspect安装成功"
    echo "📊 工具信息:"
    ./chunks-inspect -h 2>&1 | head -5
    echo ""
    echo "💡 使用示例:"
    echo "   ./chunks-inspect -l lokichunk/your-chunk-file"
else
    echo "❌ 安装失败"
    exit 1
fi
