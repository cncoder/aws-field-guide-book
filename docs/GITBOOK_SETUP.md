# GitBook Setup Guide

This document explains how to set up and use GitBook for the AWS Field Guide Book.

## 🚀 Quick Start

### Option 1: GitBook.com (Recommended)

1. **Create a GitBook account**: Visit [gitbook.com](https://www.gitbook.com)
2. **Connect GitHub repository**: 
   - Click "Import" → "GitHub"
   - Select `cncoder/aws-field-guide-book`
   - GitBook will automatically sync with your repository
3. **Configure settings**:
   - Set main branch to `main`
   - Enable auto-sync on push
4. **Publish**: Your book will be available at `https://your-space.gitbook.io/aws-field-guide-book`

### Option 2: Local Development

#### Prerequisites
- Node.js (v18 or higher)
- npm or yarn

#### Setup
```bash
# Clone the repository
git clone https://github.com/cncoder/aws-field-guide-book.git
cd aws-field-guide-book

# Install GitBook CLI
npm install -g gitbook-cli

# Install plugins
gitbook install

# Build the book
gitbook build

# Serve locally
gitbook serve --port 4000
```

#### Using the Build Script
```bash
# Make the script executable (if not already)
chmod +x scripts/build-gitbook.sh

# Run the build script
./scripts/build-gitbook.sh
```

## 📚 GitBook Structure

### Key Files
- `SUMMARY.md`: Table of contents and navigation structure
- `book.json`: GitBook configuration and plugins
- `README.md`: Introduction page
- `.github/workflows/gitbook.yml`: Automated deployment to GitHub Pages

### Adding New Content
1. Create your markdown files in the appropriate directory
2. Update `SUMMARY.md` to include the new content
3. Commit and push changes
4. GitBook will automatically rebuild and deploy

## 🔌 Plugins

The book uses several GitBook plugins for enhanced functionality:

- **github**: Adds GitHub repository link
- **anchors**: Adds anchor links to headings
- **include-codeblock**: Includes external code files
- **ace**: Code editor with syntax highlighting
- **emphasize**: Text highlighting
- **mermaid-gb3**: Diagram support
- **expandable-chapters-small**: Collapsible navigation
- **anchor-navigation-ex**: Enhanced navigation

## 🌐 Deployment Options

### GitHub Pages (Automated)
- Configured via `.github/workflows/gitbook.yml`
- Automatically deploys on push to `main` branch
- Available at: `https://cncoder.github.io/aws-field-guide-book`

### GitBook.com
- Real-time collaboration
- Custom domain support
- Analytics and insights
- Professional hosting

### Custom Hosting
```bash
# Build static files
gitbook build

# Deploy _book/ directory to your hosting provider
rsync -av _book/ user@server:/path/to/webroot/
```

## 🛠️ Customization

### Themes
Edit `book.json` to change themes:
```json
{
  "plugins": ["theme-custom"],
  "pluginsConfig": {
    "theme-custom": {
      "color": "#2196F3"
    }
  }
}
```

### Custom CSS
Create `styles/website.css` for custom styling.

### Variables
Use GitBook variables in `book.json`:
```json
{
  "variables": {
    "version": "1.0.0",
    "author": "cncoder"
  }
}
```

## 📖 Best Practices

1. **Keep SUMMARY.md updated**: Always reflect your content structure
2. **Use relative links**: Ensure portability across different hosting options
3. **Optimize images**: Use appropriate formats and sizes
4. **Test locally**: Always test your changes before pushing
5. **Use meaningful commit messages**: Help track content changes

## 🔧 Troubleshooting

### Common Issues

**GitBook CLI installation fails**:
```bash
# Try with specific Node.js version
nvm use 16
npm install -g gitbook-cli
```

**Plugin installation errors**:
```bash
# Clear GitBook cache
gitbook uninstall
gitbook install
```

**Build fails**:
```bash
# Check for syntax errors in markdown files
# Verify all links in SUMMARY.md exist
# Check book.json syntax
```

## 📞 Support

- **GitBook Documentation**: [docs.gitbook.com](https://docs.gitbook.com)
- **GitHub Issues**: Report issues in the repository
- **Community**: GitBook community forums

---

**Last Updated**: July 2025  
**Tested With**: GitBook CLI 2.6.9, Node.js 18+
