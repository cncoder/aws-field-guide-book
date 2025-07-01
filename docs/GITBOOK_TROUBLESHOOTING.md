# GitBook 故障排除指南

## 🚨 GitHub Actions 构建失败

### 问题描述
GitHub Actions中的GitBook构建失败，错误信息：
```
TypeError: cb.apply is not a function
at /opt/hostedtoolcache/node/18.20.8/x64/lib/node_modules/gitbook-cli/node_modules/npm/node_modules/graceful-fs/polyfills.js:287:18
```

### 根本原因
- GitBook CLI与Node.js 18+版本不兼容
- `graceful-fs` 包的版本冲突问题
- GitBook CLI已经停止维护，不支持新版本Node.js

## 🔧 解决方案

### 方案1: 使用HonKit（推荐）
HonKit是GitBook的现代替代品，完全兼容GitBook格式：

```bash
# 安装HonKit
npm install -g honkit

# 构建书籍
honkit build . _book

# 本地预览
honkit serve . --port 4000
```

**优势**：
- ✅ 完全兼容GitBook格式
- ✅ 支持最新Node.js版本
- ✅ 持续维护和更新
- ✅ 更好的性能

### 方案2: 使用旧版Node.js
如果必须使用GitBook CLI：

```yaml
# .github/workflows/gitbook.yml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '16'  # 使用Node.js 16

- name: Fix graceful-fs issue
  run: npm install -g graceful-fs@4.2.10
```

### 方案3: 简单的GitHub Pages部署
直接部署静态HTML页面，不依赖GitBook：

- 使用 `pages-simple.yml` 工作流
- 自动转换Markdown为HTML
- 创建简单的导航页面

## 📁 当前项目状态

### 可用的构建脚本
1. `scripts/build-gitbook.sh` - 原始GitBook CLI（可能有兼容性问题）
2. `scripts/build-gitbook-modern.sh` - 使用HonKit的现代版本

### GitHub Actions工作流
1. `gitbook.yml.disabled` - 原始工作流（已禁用）
2. `gitbook-alternative.yml` - 使用HonKit的工作流
3. `pages-simple.yml` - 简单的静态页面部署

## 🚀 推荐的工作流程

### 本地开发
```bash
# 使用现代构建脚本
./scripts/build-gitbook-modern.sh

# 或手动使用HonKit
npm install -g honkit
honkit serve . --port 4000
```

### 生产部署
1. **GitBook.com**（最推荐）
   - 直接从GitHub导入
   - 无需本地构建
   - 专业的托管和协作功能

2. **GitHub Pages + HonKit**
   - 使用 `gitbook-alternative.yml` 工作流
   - 自动构建和部署

3. **简单静态页面**
   - 使用 `pages-simple.yml` 工作流
   - 快速部署，无依赖问题

## 🔍 调试步骤

### 检查Node.js版本兼容性
```bash
node --version
npm --version
gitbook --version  # 或 honkit --version
```

### 清理和重新安装
```bash
# 清理npm缓存
npm cache clean --force

# 重新安装GitBook/HonKit
npm uninstall -g gitbook-cli
npm install -g honkit

# 重新安装插件
honkit install
```

### 验证book.json配置
```json
{
  "title": "AWS Field Guide Book",
  "description": "A practical collection of AWS architecture solutions from the field",
  "plugins": [
    "github",
    "anchors",
    "include-codeblock",
    "ace",
    "emphasize",
    "mermaid-gb3",
    "expandable-chapters-small",
    "anchor-navigation-ex"
  ]
}
```

## 📞 获取帮助

### 相关资源
- **HonKit文档**: https://github.com/honkit/honkit
- **GitBook Legacy文档**: https://github.com/GitbookIO/gitbook
- **GitHub Pages文档**: https://docs.github.com/en/pages

### 常见问题
1. **插件不兼容**: 某些GitBook插件可能不支持HonKit
2. **主题问题**: 需要使用兼容的主题
3. **构建缓存**: 清理 `_book/` 和 `node_modules/` 目录

---

**建议**: 优先使用GitBook.com进行在线托管，或使用HonKit进行本地构建。避免使用已停止维护的GitBook CLI。
