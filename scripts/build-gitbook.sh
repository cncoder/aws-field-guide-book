#!/bin/bash

# AWS Field Guide Book - GitBook Build Script
# This script builds the GitBook from the current repository

set -e

echo "🚀 Building AWS Field Guide Book with GitBook..."

# Check if gitbook-cli is installed
if ! command -v gitbook &> /dev/null; then
    echo "📦 Installing GitBook CLI..."
    npm install -g gitbook-cli
fi

# Install GitBook plugins
echo "🔌 Installing GitBook plugins..."
gitbook install

# Build the book
echo "📚 Building the book..."
gitbook build . _book

echo "✅ GitBook build completed!"
echo "📖 Open _book/index.html in your browser to view the book"

# Optional: Serve the book locally
read -p "🌐 Do you want to serve the book locally? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🌐 Starting local server..."
    gitbook serve . --port 4000
fi
