#!/bin/bash

# find_phantom_files.sh
# Finds phantom file references in RootWorkspace.xcworkspace
# Date: 2025-01-27

set -e

echo "🔍 Finding Phantom Files in RootWorkspace"
echo "=========================================="
echo ""

WORKSPACE_FILE="RootWorkspace.xcworkspace/contents.xcworkspacedata"

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

# Counters
TOTAL=0
PHANTOM=0
EXISTS=0

echo "📝 Extracting file references from workspace..."
echo ""

# Extract all FileRef locations from workspace
# Format: location = "group:path/to/file.ext"
REFS=$(grep -o 'location = "group:[^"]*"' "$WORKSPACE_FILE" | sed 's/location = "group://' | sed 's/"//' | grep -v ".xcodeproj$" | sort | uniq)

# Check if we're in FitIQ or lume context for each ref
while IFS= read -r ref; do
    ((TOTAL++))

    # Determine base path (FitIQ or lume)
    if [[ "$ref" == */* ]]; then
        # Has path separator - check in both projects
        FITIQ_PATH="FitIQ/$ref"
        LUME_PATH="lume/$ref"

        if [ -f "$FITIQ_PATH" ] || [ -f "$LUME_PATH" ]; then
            ((EXISTS++))
        else
            ((PHANTOM++))
            echo -e "${RED}❌ PHANTOM:${NC} $ref"
            # Try to find where it might have been moved
            FILENAME=$(basename "$ref")
            if [ -n "$FILENAME" ]; then
                FOUND=$(find FitIQ lume -name "$FILENAME" -type f 2>/dev/null | head -3)
                if [ -n "$FOUND" ]; then
                    echo -e "   ${YELLOW}   Possible locations:${NC}"
                    echo "$FOUND" | sed 's/^/      ➜ /'
                fi
            fi
            echo ""
        fi
    else
        # No path separator - direct file in root
        FITIQ_PATH="FitIQ/$ref"
        LUME_PATH="lume/$ref"

        if [ -f "$FITIQ_PATH" ] || [ -f "$LUME_PATH" ]; then
            ((EXISTS++))
        else
            ((PHANTOM++))
            echo -e "${RED}❌ PHANTOM:${NC} $ref (root level)"
            # Try to find where it might have been moved
            FILENAME=$(basename "$ref")
            FOUND=$(find FitIQ lume -name "$FILENAME" -type f 2>/dev/null | head -3)
            if [ -n "$FOUND" ]; then
                echo -e "   ${YELLOW}   Possible locations:${NC}"
                echo "$FOUND" | sed 's/^/      ➜ /'
            fi
            echo ""
        fi
    fi
done <<< "$REFS"

# Summary
echo "=========================================="
echo "📊 SUMMARY"
echo "=========================================="
echo -e "Total references:    $TOTAL"
echo -e "${GREEN}Exist:${NC}              $EXISTS"
echo -e "${RED}Phantom:${NC}            $PHANTOM"
echo ""

if [ $PHANTOM -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $PHANTOM phantom file reference(s)${NC}"
    echo ""
    echo "These references exist in the workspace but files don't exist on disk."
    echo "They were likely moved to docs/ folders or deleted."
    echo ""
    echo "To fix:"
    echo "  1. Option A: Manually remove references in Xcode"
    echo "     - Open RootWorkspace.xcworkspace"
    echo "     - Select red files"
    echo "     - Right-click → Delete (select 'Remove Reference')"
    echo ""
    echo "  2. Option B: Clean workspace file with script"
    echo "     - Run: ./clean_workspace.sh (creates backup first)"
    echo ""
else
    echo -e "${GREEN}✅ No phantom files found!${NC}"
fi

exit 0
