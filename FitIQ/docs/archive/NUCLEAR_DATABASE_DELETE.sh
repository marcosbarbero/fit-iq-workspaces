#!/bin/bash

echo "🔥 NUCLEAR DATABASE DELETION - This will delete EVERYTHING"
echo ""

# Kill Xcode and simulators
echo "1️⃣  Killing Xcode and Simulators..."
killall Xcode 2>/dev/null
killall Simulator 2>/dev/null
xcrun simctl shutdown all 2>/dev/null
sleep 2
echo "   ✅ Processes killed"

# Delete app from all simulators
echo ""
echo "2️⃣  Deleting FitIQ from ALL simulators..."
xcrun simctl list devices -j | grep -o '"udid" : "[^"]*"' | cut -d'"' -f4 | while read SIM_ID; do
    xcrun simctl uninstall "$SIM_ID" com.fitiq.FitIQ 2>/dev/null
    xcrun simctl uninstall "$SIM_ID" com.yourcompany.FitIQ 2>/dev/null
    xcrun simctl uninstall "$SIM_ID" FitIQ 2>/dev/null
done
echo "   ✅ Apps deleted"

# Delete ALL simulator data
echo ""
echo "3️⃣  Deleting ALL FitIQ data from simulators..."
find ~/Library/Developer/CoreSimulator/Devices -name "*FitIQ*" -type d 2>/dev/null | while read dir; do
    echo "   🗑️  Deleting: $dir"
    rm -rf "$dir"
done
echo "   ✅ Simulator data deleted"

# Clean derived data
echo ""
echo "4️⃣  Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/FitIQ* 2>/dev/null
rm -rf .build 2>/dev/null
echo "   ✅ Derived data cleaned"

# Clean Swift package caches
echo ""
echo "5️⃣  Cleaning package caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm 2>/dev/null
echo "   ✅ Caches cleaned"

# Clean Xcode build products
echo ""
echo "6️⃣  Cleaning Xcode build products..."
xcodebuild clean -quiet 2>/dev/null
echo "   ✅ Build products cleaned"

echo ""
echo "🔥 NUCLEAR DELETION COMPLETE!"
echo ""
echo "✅ Everything FitIQ-related has been deleted"
echo "✅ Next build will be completely fresh"
echo ""
echo "📋 Next steps:"
echo "   1. Open Xcode"
echo "   2. File → Packages → Resolve Package Versions"
echo "   3. Product → Clean Build Folder (Cmd+Shift+K)"
echo "   4. Product → Build (Cmd+B)"
echo "   5. Product → Run (Cmd+R)"
echo ""
echo "💾 A completely fresh SchemaV4 database will be created"
echo ""

