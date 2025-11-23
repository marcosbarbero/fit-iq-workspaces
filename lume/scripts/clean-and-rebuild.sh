#!/bin/bash

# Lume - Clean and Rebuild Script
# This script completely removes the app and rebuilds from scratch
# Required when schema migrations need a fresh start

set -e  # Exit on error

echo "🧹 Lume Clean and Rebuild Script"
echo "================================"
echo ""

# Configuration
BUNDLE_ID="com.marcosbarbero.lume"
SCHEME="lume"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "📍 Project Directory: $PROJECT_DIR"
echo "📦 Bundle ID: $BUNDLE_ID"
echo ""

# Step 1: Clean Xcode build
echo "🔨 Step 1: Cleaning Xcode build..."
cd "$PROJECT_DIR"
xcodebuild clean -scheme "$SCHEME" > /dev/null 2>&1
echo "✅ Build cleaned"
echo ""

# Step 2: Remove derived data
echo "🗑️  Step 2: Removing derived data..."
DERIVED_DATA_PATH=$(xcodebuild -showBuildSettings -scheme "$SCHEME" 2>/dev/null | grep -m 1 "BUILD_DIR" | awk '{print $3}' | sed 's/\/Build\/Products//')
if [ -n "$DERIVED_DATA_PATH" ]; then
    rm -rf "$DERIVED_DATA_PATH"
    echo "✅ Derived data removed: $DERIVED_DATA_PATH"
else
    # Fallback: remove all lume derived data
    rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*
    echo "✅ All lume derived data removed"
fi
echo ""

# Step 3: Find booted simulators
echo "📱 Step 3: Checking for booted simulators..."
BOOTED_DEVICES=$(xcrun simctl list devices booted | grep -v "==" | grep -v "--" | grep -v "^$" | wc -l | xargs)

if [ "$BOOTED_DEVICES" -eq 0 ]; then
    echo "⚠️  No booted simulators found"
    echo "💡 Please boot a simulator first, then run this script again"
    echo ""
    echo "Or manually boot one with:"
    echo "   open -a Simulator"
    exit 1
fi

echo "✅ Found $BOOTED_DEVICES booted simulator(s)"
echo ""

# Step 4: Uninstall app from all booted simulators
echo "🗑️  Step 4: Uninstalling app from simulators..."
UNINSTALLED=0
for DEVICE_UDID in $(xcrun simctl list devices booted | grep -E "iPhone|iPad" | sed 's/.*(\([^)]*\)).*/\1/'); do
    echo "   Uninstalling from device: $DEVICE_UDID"
    xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" > /dev/null 2>&1 || true
    UNINSTALLED=$((UNINSTALLED + 1))
done

if [ $UNINSTALLED -gt 0 ]; then
    echo "✅ Uninstalled from $UNINSTALLED device(s)"
else
    echo "ℹ️  App was not installed or already removed"
fi
echo ""

# Step 5: Clean build folder
echo "🧹 Step 5: Cleaning build folder..."
rm -rf "$PROJECT_DIR/build"
echo "✅ Build folder cleaned"
echo ""

# Step 6: Rebuild the app
echo "🔨 Step 6: Building app..."
DESTINATION="platform=iOS Simulator,name=iPhone 17"
echo "   Destination: $DESTINATION"
echo ""

xcodebuild \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    build \
    2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | head -10

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo ""
    echo "✅ Build completed successfully"
else
    echo ""
    echo "❌ Build failed"
    exit 1
fi
echo ""

# Step 7: Success message
echo "🎉 Clean and rebuild complete!"
echo ""
echo "Next steps:"
echo "  1. Run the app from Xcode"
echo "  2. The app will start with a fresh SchemaV3 database"
echo "  3. No migration needed - clean slate!"
echo ""
echo "Note: All previous app data has been deleted"
echo ""
