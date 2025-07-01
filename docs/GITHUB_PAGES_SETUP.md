# GitHub Pages 部署配置指南

## 🚀 项目GitHub Pages部署

**访问地址**: `https://cncoder.github.io/aws-field-guide-book/`

### ✅ 启用步骤

1. **访问仓库设置**
   - 打开：https://github.com/cncoder/aws-field-guide-book/settings/pages

2. **配置Pages源**
   - 在 "Source" 下拉菜单中选择 **"GitHub Actions"**
   - 点击 "Save" 保存设置

3. **自动部署**
   - 工作流会自动运行
   - 查看 Actions 标签页确认构建状态
   - 几分钟后即可访问你的GitBook

### 🔍 验证部署

部署完成后：
- ✅ 访问：`https://cncoder.github.io/aws-field-guide-book/`
- ✅ 检查导航是否正常工作
- ✅ 验证Aurora FDW demo页面是否显示完整

## 🛠️ 工作流说明

当前使用的工作流文件：`.github/workflows/deploy-project-pages.yml`

**触发条件**：
- 推送到 `main` 分支时自动构建和部署

**构建过程**：
1. 使用HonKit构建GitBook
2. 生成静态HTML文件
3. 自动部署到GitHub Pages

## 🔧 本地开发

如需本地预览：
```bash
# 使用现代构建脚本
./scripts/build-gitbook-modern.sh

# 或手动构建
npm install -g honkit
honkit serve . --port 4000
```
