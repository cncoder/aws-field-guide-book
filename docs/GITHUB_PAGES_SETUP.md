# GitHub Pages 部署配置指南

由于你已经有一个主GitHub Pages站点 (`cncoder.github.io`)，这里提供几种部署AWS Field Guide的方案。

## 🎯 部署方案对比

| 方案 | 访问地址 | 优势 | 劣势 |
|------|----------|------|------|
| **项目Pages** | `cncoder.github.io/aws-field-guide-book/` | 简单独立，自动部署 | 需要单独管理 |
| **主站子目录** | `cncoder.github.io/aws-field-guide/` | 统一域名，集中管理 | 需要配置跨仓库部署 |
| **手动同步** | `cncoder.github.io/aws-field-guide/` | 完全控制，灵活性高 | 需要手动操作 |

## 🚀 推荐方案：项目GitHub Pages

### 1. 启用项目Pages
1. 进入 `aws-field-guide-book` 仓库设置
2. 找到 "Pages" 部分
3. 选择 "GitHub Actions" 作为源

### 2. 启用自动部署工作流
```bash
# 启用项目Pages工作流
mv .github/workflows/deploy-project-pages.yml.disabled .github/workflows/deploy-project-pages.yml
```

### 3. 推送更改
```bash
git add .
git commit -m "Enable project GitHub Pages deployment"
git push origin main
```

### 4. 访问你的GitBook
几分钟后，访问：`https://cncoder.github.io/aws-field-guide-book/`

## 🔄 方案2：同步到主站点

如果你希望将AWS Field Guide集成到主站点：

### 自动同步（推荐）
1. 创建GitHub Personal Access Token
2. 在 `aws-field-guide-book` 仓库中添加 Secret：`MAIN_SITE_TOKEN`
3. 启用自动同步工作流：
```bash
mv .github/workflows/deploy-to-main-site.yml.disabled .github/workflows/deploy-to-main-site.yml
```

### 手动同步
```bash
# 使用同步脚本
./scripts/sync-to-main-site.sh
```

## 🛠️ 配置步骤详解

### 启用项目GitHub Pages（推荐）

1. **仓库设置**
   - 访问：https://github.com/cncoder/aws-field-guide-book/settings/pages
   - Source: "GitHub Actions"
   - 保存设置

2. **启用工作流**
```bash
cd /path/to/aws-field-guide-book
mv .github/workflows/deploy-project-pages.yml.disabled .github/workflows/deploy-project-pages.yml
git add .
git commit -m "Enable GitHub Pages deployment"
git push origin main
```

3. **验证部署**
   - 查看 Actions 标签页确认构建成功
   - 访问 `https://cncoder.github.io/aws-field-guide-book/`

### 配置主站点集成

如果选择集成到主站点：

1. **创建Personal Access Token**
   - 访问：https://github.com/settings/tokens
   - 创建新token，权限：`repo`
   - 复制token

2. **添加Repository Secret**
   - 访问：https://github.com/cncoder/aws-field-guide-book/settings/secrets/actions
   - 添加新secret：
     - Name: `MAIN_SITE_TOKEN`
     - Value: 你的Personal Access Token

3. **更新工作流**
```bash
# 编辑 .github/workflows/deploy-to-main-site.yml
# 将 ${{ secrets.GITHUB_TOKEN }} 替换为 ${{ secrets.MAIN_SITE_TOKEN }}
```

4. **启用工作流**
```bash
mv .github/workflows/deploy-to-main-site.yml.disabled .github/workflows/deploy-to-main-site.yml
```

## 📁 当前文件状态

### 可用的工作流
- `deploy-project-pages.yml` - 项目Pages部署（推荐）
- `deploy-to-main-site.yml` - 主站点集成部署

### 已禁用的工作流
- `pages-simple.yml.disabled` - 简单静态页面
- `gitbook-alternative.yml.disabled` - HonKit构建
- `gitbook.yml.disabled` - 原始GitBook CLI

### 脚本工具
- `scripts/sync-to-main-site.sh` - 手动同步到主站点
- `scripts/build-gitbook-modern.sh` - 本地构建

## 🎯 推荐的操作步骤

1. **立即可用**：启用项目GitHub Pages
```bash
# 在仓库设置中启用GitHub Pages (Source: GitHub Actions)
# 然后运行：
mv .github/workflows/deploy-project-pages.yml.disabled .github/workflows/deploy-project-pages.yml
git add .
git commit -m "Enable project GitHub Pages"
git push origin main
```

2. **集成到主站点**（可选）：
   - 配置Personal Access Token
   - 启用主站点同步工作流
   - 或使用手动同步脚本

3. **本地开发**：
```bash
./scripts/build-gitbook-modern.sh
```

## 🌐 最终访问地址

根据你选择的方案：
- **项目Pages**: `https://cncoder.github.io/aws-field-guide-book/`
- **主站点集成**: `https://cncoder.github.io/aws-field-guide/`
- **GitBook.com**: `https://your-space.gitbook.io/aws-field-guide-book`

---

**建议**: 先使用项目GitHub Pages方案，简单快速。如果后续需要集成到主站点，可以随时切换。
