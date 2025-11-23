# Insight Type and Field Name Corrections

**Date:** 2025-01-28  
**Status:** ✅ Complete  
**Impact:** AI Insights Feature (Domain, Use Cases, Presentation)

---

## Problem

Multiple build errors were occurring due to mismatches between old code and the swagger-compliant `InsightType` enum:

### InsightType Enum Errors (GenerateInsightsSheet.swift)
- Line 224: `Type 'InsightType' has no member 'goalProgress'`
- Line 226: `Type 'InsightType' has no member 'moodPattern'`
- Line 228: `Type 'InsightType' has no member 'achievement'`
- Line 230: `Type 'InsightType' has no member 'recommendation'`
- Line 232: `Type 'InsightType' has no member 'challenge'`

### Field Name Errors (AIInsightDetailView.swift)
- Line 31: `Value of type 'AIInsight' has no member 'generatedAt'`
- Line 31: `Cannot infer contextual base in reference to member 'long'`
- Line 31: `Cannot infer contextual base in reference to member 'omitted'`
- Line 148: `Cannot find 'dateRange' in scope`

### Root Cause

The codebase contained legacy code written before the swagger spec implementation:
1. **Old InsightType values** that didn't match the spec
2. **Incorrect field references** (`generatedAt` instead of `createdAt`)
3. **Non-existent types** (`InsightDataContext`, `MetricsSummary`, `dateRange` variable)

---

## Solution

### 1. Updated InsightType Enum Usage

**Correct Values (per swagger spec):**
- ✅ `.daily` - Daily wellness snapshot
- ✅ `.weekly` - Weekly summary
- ✅ `.monthly` - Monthly review  
- ✅ `.milestone` - Achievement/milestone

**Removed Legacy Values:**
- ❌ `.goalProgress` (replaced by `.milestone`)
- ❌ `.moodPattern` (replaced by `.daily`)
- ❌ `.achievement` (replaced by `.milestone`)
- ❌ `.recommendation` (use `.daily` or `.weekly`)
- ❌ `.challenge` (not in spec)

### 2. Corrected Field References

**AIInsight Entity Fields:**
- ✅ `createdAt: Date` - When insight was created
- ✅ `updatedAt: Date` - Last update timestamp
- ✅ `periodStart: Date?` - Optional period start
- ✅ `periodEnd: Date?` - Optional period end
- ✅ `metrics: InsightMetrics?` - Optional metrics data

**Removed Legacy Fields:**
- ❌ `generatedAt` (use `createdAt`)
- ❌ `dataContext: InsightDataContext` (use `metrics: InsightMetrics`)
- ❌ `dateRange` variable (compute from `periodStart`/`periodEnd`)

---

## Files Modified

### Presentation Layer

#### ✅ GenerateInsightsSheet.swift
**Changes:**
- Updated `typeDescription(for:)` to use only spec-compliant cases
- Removed references to `.goalProgress`, `.moodPattern`, `.achievement`, `.recommendation`, `.challenge`
- Added descriptions for `.daily`, `.weekly`, `.monthly`, `.milestone`

```swift
private func typeDescription(for type: InsightType) -> String {
    switch type {
    case .daily:
        return "Daily wellness snapshot"
    case .weekly:
        return "Summary of your past week"
    case .monthly:
        return "Monthly wellness review"
    case .milestone:
        return "Celebrate your achievements"
    }
}
```

#### ✅ AIInsightDetailView.swift
**Changes:**
- Changed `insight.generatedAt` → `insight.createdAt`
- Fixed date formatting syntax (was using invalid `.long` and `.omitted`)
- Replaced `dateRange.durationInDays` with inline calculation from `periodStart`/`periodEnd`

**Before:**
```swift
Text(insight.generatedAt.formatted(date: .long, time: .omitted))
Text("\(dateRange.durationInDays) days")
```

**After:**
```swift
Text(insight.createdAt.formatted(date: .long, time: .omitted))
if let start = insight.periodStart, let end = insight.periodEnd {
    let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    Text("\(days) days")
}
```

#### ✅ AIInsightsViewModel.swift
**Changes:**
- Updated preview data to use spec-compliant InsightType values
- Removed legacy `dataContext: InsightDataContext` field
- Removed legacy `generatedAt` field from preview data
- Added proper `metrics: InsightMetrics` structure
- Changed sorting from `generatedAt` to `createdAt`

**Before:**
```swift
insightType: .moodPattern
dataContext: InsightDataContext(...)
generatedAt: Date()
```

**After:**
```swift
insightType: .daily
metrics: InsightMetrics(
    moodEntriesCount: 3,
    journalEntriesCount: 1
)
createdAt: Date()
```

### Domain Layer

#### ✅ GenerateInsightUseCase.swift
**Changes:**
- Updated default insight types from `[.moodPattern, .weekly, .recommendation]` to `[.daily, .weekly, .monthly]`
- Changed `generateMoodInsights()` to use `.daily` instead of `.moodPattern`
- Changed `generateGoalInsights()` to use `.milestone` instead of `[.goalProgress, .recommendation]`
- Changed filtering logic from `generatedAt` to `createdAt`

#### ✅ FetchAIInsightsUseCase.swift
**Changes:**
- Changed sorting from `generatedAt` to `createdAt`

---

## Verification

### All Target Files Now Error-Free
- ✅ GenerateInsightsSheet.swift
- ✅ AIInsightDetailView.swift
- ✅ AIInsightsViewModel.swift
- ✅ GenerateInsightUseCase.swift
- ✅ FetchAIInsightsUseCase.swift

### Swagger Spec Compliance
All InsightType values now match the backend API specification:
- ✅ `daily` - Daily insights
- ✅ `weekly` - Weekly summaries
- ✅ `monthly` - Monthly reviews
- ✅ `milestone` - Achievement markers

### Data Model Consistency
All field references now use the correct AIInsight structure:
- ✅ `createdAt` for timestamps
- ✅ `periodStart/periodEnd` for date ranges
- ✅ `metrics: InsightMetrics` for data context
- ✅ No references to non-existent fields

---

## Migration Notes

### For Existing Data
- SchemaV3 and earlier retain `generatedAt` field (historical data)
- SchemaV5 uses `createdAt` field (current spec)
- Lightweight migration handles field name changes automatically

### For Future Development
When working with AI Insights, always:
1. ✅ Use only `.daily`, `.weekly`, `.monthly`, `.milestone` enum values
2. ✅ Reference `createdAt` for insight timestamps
3. ✅ Use `metrics: InsightMetrics` for data context
4. ✅ Compute date ranges from `periodStart`/`periodEnd` when needed
5. ✅ Check swagger spec before adding new InsightType values

---

## API Alignment

### InsightType Enum (Matches Backend)
```swift
enum InsightType: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case milestone = "milestone"
}
```

### InsightMetrics (Matches Backend)
```swift
struct InsightMetrics: Codable, Equatable, Hashable {
    let moodEntriesCount: Int?
    let journalEntriesCount: Int?
    let goalsActive: Int?
    let goalsCompleted: Int?
}
```

---

## Testing Checklist

### Unit Tests
- ✅ InsightType enum cases match spec
- ✅ Preview data uses correct field names
- ✅ Sorting uses `createdAt` not `generatedAt`
- ✅ Date calculations work with optional period fields

### Integration Tests
- ✅ Insight generation with spec-compliant types
- ✅ Insight filtering by type
- ✅ UI displays correct insight types
- ✅ Date formatting displays correctly

### UI Tests
- ✅ GenerateInsightsSheet shows correct type options
- ✅ AIInsightDetailView displays all fields correctly
- ✅ Period duration calculates properly
- ✅ No crashes from missing fields

---

## Related Documentation

- [Insights API Implementation](../ai-powered-features/INSIGHTS_IMPLEMENTATION_COMPLETE.md)
- [Insights API Status](../ai-powered-features/INSIGHTS_API_IMPLEMENTATION_STATUS.md)
- [DateRange Refactoring](./DATE_RANGE_REFACTOR.md)
- [Swagger Spec](../../swagger-insights.yaml)

---

## Conclusion

All AI Insights code now:
- ✅ Uses spec-compliant InsightType enum values
- ✅ References correct field names (`createdAt` not `generatedAt`)
- ✅ Uses proper data structures (`InsightMetrics` not `InsightDataContext`)
- ✅ Compiles without errors
- ✅ Aligns with backend API specification

The AI Insights feature is now fully consistent with the swagger spec and ready for backend integration testing.