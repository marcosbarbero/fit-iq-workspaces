#!/bin/bash

echo "======================================"
echo "Lume Build Fix Script"
echo "======================================"
echo ""
echo "This script will help fix the 'Multiple commands produce Info.plist' error"
echo ""

# Clean build artifacts
echo "Step 1: Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*
echo "✓ Derived data cleaned"
echo ""

# Check for duplicate Info.plist files
echo "Step 2: Checking for duplicate Info.plist files..."
INFOPLIST_COUNT=$(find . -name "Info.plist" -not -path "*/DerivedData/*" -not -path "*/.build/*" -not -path "*/xcuserdata/*" | wc -l)
echo "Found $INFOPLIST_COUNT Info.plist file(s)"

if [ $INFOPLIST_COUNT -gt 1 ]; then
    echo "⚠️  WARNING: Multiple Info.plist files found:"
    find . -name "Info.plist" -not -path "*/DerivedData/*" -not -path "*/.build/*" -not -path "*/xcuserdata/*"
    echo ""
    echo "This might be causing the build error."
    echo "You should keep only one Info.plist (usually in the main target folder)"
fi
echo ""

# Show current Info.plist location
echo "Step 3: Current Info.plist location:"
find . -name "Info.plist" -not -path "*/DerivedData/*" -not -path "*/.build/*" -not -path "*/xcuserdata/*"
echo ""

echo "======================================"
echo "Next Steps (Do these in Xcode):"
echo "======================================"
echo ""
echo "1. Open the project in Xcode"
echo "2. Select the 'lume' project → 'lume' target"
echo "3. Go to 'Build Phases' tab"
echo "4. Expand 'Copy Bundle Resources'"
echo "5. Look for 'Info.plist' in the list"
echo "6. If found, select it and press DELETE"
echo "7. Clean Build Folder (Cmd+Shift+K)"
echo "8. Rebuild (Cmd+B)"
echo ""
echo "The Info.plist file at ./lume/Info.plist already has camera permissions!"
echo ""

