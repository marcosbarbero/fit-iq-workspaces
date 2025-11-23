#!/bin/bash

echo "🚨 EMERGENCY: Deleting corrupted database..."

# Kill any running simulators
echo "📱 Stopping simulator..."
xcrun simctl shutdown all 2>/dev/null

# Get all simulator IDs
SIMULATORS=$(xcrun simctl list devices -j | grep -o '"udid" : "[^"]*"' | cut -d'"' -f4)

# Delete app from all simulators
for SIM_ID in $SIMULATORS; do
    echo "🗑️  Removing FitIQ from simulator $SIM_ID..."
    xcrun simctl uninstall "$SIM_ID" com.fitiq.FitIQ 2>/dev/null
done

# Clean everything
echo "🧹 Cleaning build..."
xcodebuild clean -quiet 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/FitIQ-* 2>/dev/null

# Also clean app support directory (where SwiftData stores data)
echo "🗑️  Removing app data..."
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Application\ Support/com.fitiq.FitIQ 2>/dev/null

echo ""
echo "✅ EMERGENCY FIX COMPLETE!"
echo ""
echo "🔥 Database completely deleted"
echo "📱 Now rebuild and run in Xcode"
echo "   Fresh SchemaV4 database will be created"
echo ""

