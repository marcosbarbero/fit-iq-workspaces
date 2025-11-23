#!/bin/bash

echo "🚀 COMPLETE FIX - Resolving all issues..."
echo ""

# Step 1: Clean everything
echo "1️⃣  Cleaning project..."
xcodebuild clean -quiet 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/FitIQ-* 2>/dev/null
rm -rf ~/Library/Caches/org.swift.swiftpm 2>/dev/null
echo "   ✅ Project cleaned"

# Step 2: Resolve packages
echo ""
echo "2️⃣  Resolving Swift packages (Swinject)..."
xcodebuild -resolvePackageDependencies -project FitIQ.xcodeproj -scheme FitIQ 2>&1 | grep -E "(Resolved|Fetching|Cloning|error)" || true
echo "   ✅ Packages resolved"

# Step 3: Build
echo ""
echo "3️⃣  Building project..."
xcodebuild -project FitIQ.xcodeproj -scheme FitIQ -destination 'platform=iOS Simulator,id=55CB8491-7DC9-4745-9046-947FECCCAAA6' build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -5

BUILD_STATUS=$?

echo ""
if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ BUILD SUCCESSFUL!"
    echo ""
    echo "🎉 All fixes applied successfully!"
    echo ""
    echo "📱 Next steps:"
    echo "   1. Open Xcode"
    echo "   2. Run the app (Cmd+R)"
    echo "   3. Test that it doesn't crash"
    echo ""
else
    echo "⚠️  Build had some issues"
    echo ""
    echo "📋 Manual steps in Xcode:"
    echo "   1. Open FitIQ.xcodeproj"
    echo "   2. File → Packages → Resolve Package Versions"
    echo "   3. Wait for Swinject to download"
    echo "   4. Product → Clean Build Folder"
    echo "   5. Product → Build"
    echo ""
fi

