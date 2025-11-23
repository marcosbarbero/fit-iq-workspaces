#!/bin/bash

# Script to delete app and reset database for FitIQ
# This will fix the SchemaV2 → SchemaV4 mismatch

echo "🗑️  Deleting FitIQ app from simulator..."

# Get booted simulator
SIMULATOR_ID=$(xcrun simctl list devices | grep "Booted" | head -1 | grep -o '[A-F0-9]\{8\}-[A-F0-9]\{4\}-[A-F0-9]\{4\}-[A-F0-9]\{4\}-[A-F0-9]\{12\}')

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ No booted simulator found"
    echo "👉 Please boot a simulator first, then run this script"
    exit 1
fi

echo "📱 Found booted simulator: $SIMULATOR_ID"

# Delete the app (replace with your actual bundle ID)
BUNDLE_ID="com.fitiq.FitIQ"  # Update this if different

echo "🗑️  Uninstalling $BUNDLE_ID..."
xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ App deleted successfully"
else
    echo "⚠️  App may not have been installed yet (that's OK)"
fi

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -quiet 2>/dev/null

# Clean derived data
echo "🧹 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FitIQ-* 2>/dev/null

echo ""
echo "✅ Database reset complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Build and run the app in Xcode"
echo "   2. Fresh SchemaV4 database will be created"
echo "   3. No more SchemaV2 warnings!"
echo ""
