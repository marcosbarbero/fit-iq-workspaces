#!/bin/bash

# Dashboard Integration Verification Script
# Checks that all Dashboard files are correctly set up

set -e

echo "🔍 Verifying Dashboard Integration..."
echo ""

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track errors
ERRORS=0

# Function to check file exists
check_file() {
    local file=$1
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} Found: $file"
        return 0
    else
        echo -e "${RED}✗${NC} Missing: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check for string in file
check_content() {
    local file=$1
    local search=$2
    local description=$3

    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} File not found: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    if grep -q "$search" "$file"; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description - NOT FOUND"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "📁 Checking Domain Layer Files..."
check_file "lume/Domain/Entities/MoodStatistics.swift"
check_file "lume/Domain/Ports/StatisticsRepositoryProtocol.swift"
echo ""

echo "📁 Checking Data Layer Files..."
check_file "lume/Data/Repositories/StatisticsRepository.swift"
echo ""

echo "📁 Checking Presentation Layer Files..."
check_file "lume/Presentation/ViewModels/DashboardViewModel.swift"
check_file "lume/Presentation/Features/Dashboard/DashboardView.swift"
echo ""

echo "🔧 Checking AppDependencies Integration..."
check_content "lume/DI/AppDependencies.swift" "statisticsRepository" "StatisticsRepository wired up"
check_content "lume/DI/AppDependencies.swift" "makeDashboardViewModel" "DashboardViewModel factory method exists"
echo ""

echo "🔧 Checking MainTabView Integration..."
check_content "lume/Presentation/MainTabView.swift" "DashboardView" "DashboardView integrated"
check_content "lume/Presentation/MainTabView.swift" "makeDashboardViewModel" "DashboardViewModel used"
echo ""

echo "🔍 Checking for JournalStatistics Ambiguity..."
# Count occurrences of "struct JournalStatistics" (should be exactly 1)
JOURNAL_STATS_COUNT=$(grep -r "^struct JournalStatistics" lume --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

if [ "$JOURNAL_STATS_COUNT" -eq "1" ]; then
    echo -e "${GREEN}✓${NC} JournalStatistics defined once (no ambiguity)"
else
    echo -e "${RED}✗${NC} JournalStatistics defined $JOURNAL_STATS_COUNT times (ambiguity detected!)"
    echo "   Locations:"
    grep -rn "^struct JournalStatistics" lume --include="*.swift" 2>/dev/null || true
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "🔍 Checking for JournalViewStatistics..."
if grep -q "struct JournalViewStatistics" "lume/Presentation/ViewModels/JournalViewModel.swift" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} JournalViewStatistics exists (ViewModel version renamed)"
else
    echo -e "${YELLOW}⚠${NC}  JournalViewStatistics not found (check if rename was applied)"
fi
echo ""

echo "🔍 Checking Type Definitions..."
check_content "lume/Domain/Entities/MoodStatistics.swift" "struct MoodStatistics" "MoodStatistics defined"
check_content "lume/Domain/Entities/MoodStatistics.swift" "struct JournalStatistics" "JournalStatistics defined"
check_content "lume/Domain/Entities/MoodStatistics.swift" "struct WellnessStatistics" "WellnessStatistics defined"
echo ""

echo "📊 Summary"
echo "=========="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Dashboard integration is correct.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open project in Xcode"
    echo "2. Clean Build Folder (Cmd+Shift+K)"
    echo "3. Build project (Cmd+B)"
    echo "4. Run on simulator or device"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s). Please review the output above.${NC}"
    exit 1
fi
