#!/bin/bash

echo "🔧 Fixing Swinject dependency..."

# Reset package caches
echo "📦 Resetting package caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Reset packages in project
echo "🗑️  Removing resolved packages..."
rm -rf .build
rm Package.resolved 2>/dev/null

echo "✅ Package cache cleared"
echo ""
echo "📋 Next steps:"
echo "   1. Open FitIQ.xcodeproj in Xcode"
echo "   2. File → Packages → Reset Package Caches"
echo "   3. File → Packages → Resolve Package Versions"
echo "   4. Wait for Swinject to download"
echo "   5. Build and run"
echo ""

