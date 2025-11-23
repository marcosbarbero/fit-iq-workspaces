#!/bin/bash

# clean_workspace.sh
# Removes phantom file references from RootWorkspace.xcworkspace
# Date: 2025-01-27

set -e

echo "🧹 Cleaning RootWorkspace - Removing Phantom File References"
echo "============================================================="
echo ""

WORKSPACE_FILE="RootWorkspace.xcworkspace/contents.xcworkspacedata"
BACKUP_FILE="RootWorkspace.xcworkspace/contents.xcworkspacedata.backup-$(date +%Y%m%d-%H%M%S)"

if [ ! -f "$WORKSPACE_FILE" ]; then
    echo "❌ Error: $WORKSPACE_FILE not found"
    echo "Run this script from: /Users/marcosbarbero/Develop/GitHub/fit-iq-workspaces"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Backup
echo "📦 Creating backup..."
cp "$WORKSPACE_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
echo ""

# Strategy: Keep only the Xcode project references and FitIQCore package
# Remove all individual file references (they're managed by the project files)
echo "🔧 Cleaning workspace file..."
echo ""

cat > "$WORKSPACE_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:FitIQ/FitIQ.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:lume/lume.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:FitIQCore">
   </FileRef>
   <FileRef
      location = "group:README.md">
   </FileRef>
   <FileRef
      location = "group:.gitignore">
   </FileRef>
</Workspace>
EOF

echo -e "${GREEN}✅ Workspace file cleaned!${NC}"
echo ""
echo "=========================================="
echo "📊 SUMMARY"
echo "=========================================="
echo ""
echo "✅ Removed all phantom file references"
echo "✅ Kept essential project references:"
echo "   • FitIQ.xcodeproj"
echo "   • lume.xcodeproj"
echo "   • FitIQCore package"
echo "   • README.md"
echo "   • .gitignore"
echo ""
echo -e "${YELLOW}ℹ️  Individual files are managed by the .xcodeproj files${NC}"
echo "   You'll see them when you expand each project in Xcode"
echo ""
echo "=========================================="
echo "🎯 NEXT STEPS"
echo "=========================================="
echo ""
echo "1. Close Xcode if it's open"
echo ""
echo "2. Clear Xcode caches:"
echo "   rm -rf ~/Library/Developer/Xcode/DerivedData/*"
echo "   rm -rf ~/Library/Caches/com.apple.dt.Xcode"
echo ""
echo "3. Reopen workspace:"
echo "   open RootWorkspace.xcworkspace"
echo ""
echo "4. In Xcode:"
echo "   • Product → Clean Build Folder (⌘⇧K)"
echo "   • Select 'lume' scheme and build"
echo ""
echo "5. If you need to restore:"
echo "   cp $BACKUP_FILE $WORKSPACE_FILE"
echo ""
echo -e "${GREEN}✅ Done! No more phantom red files!${NC}"
echo ""

exit 0
