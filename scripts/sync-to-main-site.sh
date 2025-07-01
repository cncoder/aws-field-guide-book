#!/bin/bash

# Sync AWS Field Guide to Main GitHub Pages Site
# This script builds the GitBook and syncs it to your main cncoder.github.io repository

set -e

MAIN_SITE_DIR="../cncoder.github.io"
TARGET_DIR="aws-field-guide"

echo "🚀 Syncing AWS Field Guide to main GitHub Pages site..."

# Check if main site directory exists
if [ ! -d "$MAIN_SITE_DIR" ]; then
    echo "📥 Cloning main site repository..."
    git clone https://github.com/cncoder/cncoder.github.io.git "$MAIN_SITE_DIR"
fi

# Build the GitBook
echo "📚 Building GitBook..."
if command -v honkit &> /dev/null; then
    honkit build . _book
elif command -v gitbook &> /dev/null; then
    gitbook build . _book
else
    echo "❌ Neither HonKit nor GitBook CLI found. Please install one of them:"
    echo "   npm install -g honkit"
    exit 1
fi

# Sync to main site
echo "🔄 Syncing to main site..."
cd "$MAIN_SITE_DIR"

# Pull latest changes
git pull origin master

# Create target directory
mkdir -p "$TARGET_DIR"

# Copy built files
cp -r "../aws-field-guide-book/_book/"* "$TARGET_DIR/"

# Update main index.html to include link (optional)
if [ -f "index.html" ] && ! grep -q "aws-field-guide" index.html; then
    echo "🔗 Adding link to main page..."
    # You can customize this part based on your main site structure
    sed -i.bak 's|</body>|<p><a href="/aws-field-guide/">📚 AWS Field Guide Book</a></p></body>|' index.html
fi

# Commit and push
echo "📤 Committing and pushing changes..."
git add .
git commit -m "Update AWS Field Guide Book - $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"
git push origin master

echo "✅ Sync completed!"
echo "🌐 AWS Field Guide is now available at: https://cncoder.github.io/$TARGET_DIR/"
