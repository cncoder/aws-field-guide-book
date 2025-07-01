#!/bin/bash

# AWS Field Guide Book - Modern GitBook Build Script
# This script builds the GitBook using HonKit (modern GitBook alternative)

set -e

echo "🚀 Building AWS Field Guide Book with HonKit..."

# Check if honkit is installed
if ! command -v honkit &> /dev/null; then
    echo "📦 Installing HonKit (modern GitBook alternative)..."
    npm install -g honkit
fi

# Install GitBook plugins
echo "🔌 Installing GitBook plugins..."
honkit install

# Build the book
echo "📚 Building the book..."
honkit build . _book

echo "✅ HonKit build completed!"
echo "📖 Open _book/index.html in your browser to view the book"

# Optional: Serve the book locally
read -p "🌐 Do you want to serve the book locally? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🌐 Starting local server..."
    honkit serve . --port 4000
fi
