#!/bin/bash

# Aurora PostgreSQL FDW Demo 清理脚本

set -e

echo "=== Aurora PostgreSQL FDW Demo 资源清理 ==="

# 检查是否在正确的目录
if [ ! -f "terraform/main.tf" ]; then
    echo "错误: 请在项目根目录运行此脚本"
    exit 1
fi

# 进入terraform目录
cd terraform

# 检查terraform状态
if [ ! -f "terraform.tfstate" ]; then
    echo "警告: 未找到terraform状态文件，可能资源已被清理"
    exit 0
fi

echo "正在销毁所有Terraform管理的资源..."

# 执行销毁
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo "✅ 所有资源已成功清理"
    echo ""
    echo "已清理的资源包括:"
    echo "- Aurora PostgreSQL 集群和实例"
    echo "- EC2 跳板机实例"
    echo "- 安全组"
    echo "- IAM 角色和策略"
    echo "- 数据库子网组"
    echo ""
    echo "注意: VPC和子网未被删除（因为它们是预存在的）"
else
    echo "❌ 资源清理失败，请检查错误信息"
    echo "你可以手动运行: terraform destroy"
    exit 1
fi

echo "=== 清理完成 ==="
