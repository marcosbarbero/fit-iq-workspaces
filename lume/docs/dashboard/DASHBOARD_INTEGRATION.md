# Dashboard Integration Guide

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** ✅ Complete

---

## Overview

This document describes the integration of the comprehensive **Wellness Dashboard** into the Lume iOS app. The Dashboard provides a holistic view of user wellness by combining mood tracking and journaling statistics into a single, actionable overview.

---

## Architecture

### Layer Structure

```
Presentation Layer
├── DashboardView.swift              # Main dashboard UI
└── DashboardViewModel.swift         # Dashboard logic & state

Domain Layer
├── Entities/
│   └── MoodStatistics.swift        # MoodStatistics, JournalStatistics, WellnessStatistics
└── Ports/
    └── StatisticsRepositoryProtocol.swift  # Repository interface

Data Layer
└── Repositories/
    └── StatisticsRepository.swift  # Statistics calculation implementation
```

### Dependencies

The Dashboard is wired through `AppDependencies`:

```swift
// In AppDependencies.swift
private(set) lazy var statisticsRepository: StatisticsRepositoryProtocol = {
    StatisticsRepository(modelContext: modelContext)
}()

func makeDashboardViewModel() -> DashboardViewModel {
    DashboardViewModel(statisticsRepository: statisticsRepository)
}
```

---

## Integration Points

### 1. Main Tab Navigation

The Dashboard is integrated as the **third tab** in `MainTabView`:

```swift
NavigationStack {
    DashboardView(viewModel: dependencies.makeDashboardViewModel())
}
.tabItem {
    Label("Dashboard", systemImage: "chart.bar.fill")
}
.tag(2)
```

**Tab Order:**
1. Mood (sun.max.fill)
2. Journal (book.fill)
3. **Dashboard (chart.bar.fill)** ← New
4. Profile (person.fill)

### 2. Relationship to MoodDashboardView

| Feature | MoodDashboardView | DashboardView |
|---------|-------------------|---------------|
| **Location** | Mood tab → Chart button (sheet) | Dedicated main tab |
| **Scope** | Mood analytics only | Mood + Journal combined |
| **Purpose** | Detailed mood insights | Holistic wellness overview |
| **Charts** | Detailed timeline, entry breakdown | High-level trends, distribution |
| **Access** | Drill-down from Mood tab | Primary navigation |

**They complement each other:**
- **DashboardView** = "How am I doing overall?"
- **MoodDashboardView** = "What's happening with my mood specifically?"

---

## Features

### Time Range Selection

Users can view statistics across multiple time periods:

- **7 Days** - Recent trends
- **30 Days** - Monthly overview (default)
- **90 Days** - Quarterly patterns
- **365 Days** - Yearly insights

Selected via dropdown menu in the navigation bar toolbar.

### Mood Statistics

#### Streak Information
- **Current Streak:** Consecutive days with mood entries
- **Longest Streak:** Best streak ever achieved
- **Motivational Messages:** Dynamic encouragement based on progress

#### Mood Distribution
- **Positive Moods:** Happy, grateful, excited, etc.
- **Neutral Moods:** Content, peaceful, okay
- **Negative Moods:** Sad, anxious, stressed, etc.

Displayed as percentages with visual color coding.

#### Mood Trends
- **Line Chart:** Daily mood averages over selected time range
- **Trend Analysis:** Improving, stable, or declining indicators
- **Average Mood Score:** Overall wellness metric (0-10 scale)

#### Daily Breakdown
- Date-by-date mood summaries
- Entry counts per day
- Dominant mood identification

### Journal Statistics

- **Total Entries:** Lifetime journal count
- **Total Words:** Words written across all entries
- **Average Words:** Mean words per entry
- **Longest Entry:** Maximum word count
- **Recent Activity:**
  - Entries this week
  - Entries this month
- **Favorites Count:** Starred entries
- **Entries with Mood:** Journal entries linked to mood data

### Quick Actions

Convenient buttons to:
- **Log Mood** → Navigate to mood entry
- **Write Journal** → Navigate to journal creation

---

## Data Flow

```
User Views Dashboard
        ↓
DashboardViewModel.loadStatistics()
        ↓
StatisticsRepository.fetchWellnessStatistics()
        ↓
├── fetchMoodStatistics() ────→ Query SDMoodEntry (SwiftData)
│                                      ↓
│                               Calculate metrics
│                                      ↓
│                               Return MoodStatistics
│
└── fetchJournalStatistics() ──→ Query SDJournalEntry (SwiftData)
                                       ↓
                                Calculate metrics
                                       ↓
                                Return JournalStatistics
        ↓
Combine into WellnessStatistics
        ↓
Update DashboardViewModel state
        ↓
DashboardView re-renders with data
```

---

## State Management

### DashboardViewModel States

```swift
@Observable
class DashboardViewModel {
    var wellnessStats: WellnessStatistics?  // nil = no data loaded
    var isLoading: Bool = false              // true = calculating
    var errorMessage: String?                // nil = no error
    var selectedTimeRange: TimeRange         // user selection
}
```

### View States

| State | Condition | Display |
|-------|-----------|---------|
| **Loading** | `isLoading == true` | Loading spinner |
| **Error** | `errorMessage != nil` | Error message with retry |
| **Empty** | `wellnessStats == nil` | Empty state with guidance |
| **Success** | `wellnessStats != nil` | Full dashboard with charts |

---

## Calculation Details

### Mood Numeric Values

Each `MoodKind` is assigned a numeric value (0-10 scale):

```swift
// Positive (7-10)
.joyful, .amazed → 9.0
.grateful, .proud → 8.5
.happy, .excited → 8.0
.peaceful, .hopeful → 7.5
.content → 7.0

// Neutral (5)
.ok → 5.0

// Negative (2-4)
.sad, .stressed, .frustrated, .lonely → 3.0
.anxious, .worried → 3.5
.overwhelmed, .scared → 2.5
.angry → 2.0
```

### Streak Calculation

**Current Streak Logic:**
1. Check if user logged mood today → streak continues
2. If not today, check yesterday → streak still active
3. Count consecutive days backwards from most recent entry
4. Break if gap > 1 day

**Longest Streak Logic:**
- Iterate through all unique mood entry dates
- Count consecutive day sequences
- Track maximum sequence length

### Average Calculations

```swift
averageMood = sum(dailyMoodAverages) / dayCount
consistencyPercentage = (daysWithEntries / totalDays) * 100
averageWordsPerEntry = totalWords / entryCount
```

---

## Error Handling

### Repository Errors

```swift
enum StatisticsRepositoryError: LocalizedError {
    case notAuthenticated     // No user session
    case noDataAvailable      // No entries in date range
    case fetchFailed(Error)   // Calculation or fetch error
}
```

### User-Facing Messages

| Error | Display Message |
|-------|----------------|
| `notAuthenticated` | "Please log in to view statistics" |
| `noDataAvailable` | "Start tracking to see insights" |
| `fetchFailed` | "Failed to load statistics. Pull to refresh." |

---

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading:** Statistics calculated only when Dashboard tab is viewed
2. **Caching:** ViewModel retains loaded statistics until time range changes
3. **Local Computation:** All calculations done on-device (SwiftData queries)
4. **Async/Await:** Non-blocking UI during calculations
5. **Pull-to-Refresh:** Manual refresh control for data updates

### Query Efficiency

```swift
// Optimized fetch with predicate and sort
FetchDescriptor<SDMoodEntry>(
    predicate: #Predicate { entry in
        entry.userId == userId &&
        entry.date >= startDate &&
        entry.date <= endDate
    },
    sortBy: [SortDescriptor(\.date, order: .forward)]
)
```

---

## Type Safety Fix

### JournalStatistics Ambiguity

**Issue:** Two `JournalStatistics` types existed:
- `Domain/Entities/MoodStatistics.swift` → Domain entity ✅
- `Presentation/ViewModels/JournalViewModel.swift` → ViewModel struct ❌

**Resolution:** Renamed ViewModel version to `JournalViewStatistics`:

```swift
// Before (ambiguous)
struct JournalStatistics { ... }  // In JournalViewModel

// After (clear)
struct JournalViewStatistics { ... }  // In JournalViewModel
```

This ensures the Domain's `JournalStatistics` is used for cross-layer statistics.

---

## Testing Checklist

### Functional Testing

- [ ] Dashboard tab appears in main navigation
- [ ] Statistics load when tab is selected
- [ ] Time range picker works (7/30/90/365 days)
- [ ] Pull-to-refresh recalculates statistics
- [ ] Empty state shown when no data exists
- [ ] Loading state shown during calculation
- [ ] Error state shown on failures

### Data Validation

- [ ] Mood statistics match actual entries
- [ ] Journal statistics match actual entries
- [ ] Streak calculations are accurate
- [ ] Average calculations are correct
- [ ] Distribution percentages sum to 100%

### Edge Cases

- [ ] New user (no data) → Empty state
- [ ] Single entry → Statistics display correctly
- [ ] Date range with no entries → Appropriate message
- [ ] Offline mode → Cached data shown
- [ ] Time zone changes → Dates handled correctly

### UI/UX Testing

- [ ] Charts render correctly
- [ ] Colors follow Lume design system
- [ ] Typography is consistent
- [ ] Spacing and padding are appropriate
- [ ] Pull-to-refresh animation is smooth
- [ ] Quick action buttons navigate correctly

---

## Future Enhancements

### Phase 2 Features

1. **Goal Tracking Integration**
   - Show goal progress on Dashboard
   - Quick actions for goal creation

2. **Advanced Analytics**
   - Mood-journal correlation insights
   - Weekly/monthly reports
   - Trend predictions

3. **Personalization**
   - Customizable dashboard cards
   - User-selected metrics
   - Widget support

4. **Export & Sharing**
   - Generate PDF reports
   - Share insights with therapist
   - Data export (CSV/JSON)

5. **AI Insights**
   - Personalized wellness recommendations
   - Pattern detection and alerts
   - Motivational messages based on data

---

## Troubleshooting

### Common Issues

**"Cannot find type 'JournalStatistics' is ambiguous"**
- ✅ Fixed: Renamed ViewModel version to `JournalViewStatistics`

**"Statistics not loading"**
- Check user authentication (UserSession.shared.currentUserId)
- Verify SwiftData entries exist for date range
- Check error message for specific failure

**"Empty state shows but I have data"**
- Verify date range selection
- Check userId matches entries
- Confirm entries are within selected time range

**"Charts not displaying"**
- Ensure Charts framework is imported
- Verify data arrays are not empty
- Check for numeric value calculation errors

---

## Files Modified

### New Files
- `lume/Domain/Entities/MoodStatistics.swift`
- `lume/Domain/Ports/StatisticsRepositoryProtocol.swift`
- `lume/Data/Repositories/StatisticsRepository.swift`
- `lume/Presentation/ViewModels/DashboardViewModel.swift`
- `lume/Presentation/Features/Dashboard/DashboardView.swift`
- `lume/docs/dashboard/DASHBOARD_INTEGRATION.md`

### Modified Files
- `lume/DI/AppDependencies.swift` → Added statisticsRepository and makeDashboardViewModel()
- `lume/Presentation/MainTabView.swift` → Replaced Goals tab with Dashboard tab
- `lume/Presentation/ViewModels/JournalViewModel.swift` → Renamed JournalStatistics to JournalViewStatistics

---

## Summary

The Dashboard integration provides Lume users with a **unified wellness overview** combining mood and journal data. It follows Hexagonal Architecture principles, maintains type safety, and delivers actionable insights through beautiful, calm UI aligned with Lume's design system.

**Key Benefits:**
- ✅ Holistic wellness view (mood + journal)
- ✅ Multiple time ranges for trend analysis
- ✅ Motivational streak tracking
- ✅ Quick access to logging actions
- ✅ Offline-first with local calculations
- ✅ Pull-to-refresh for data updates
- ✅ Clean separation of concerns (Domain/Data/Presentation)

**Ready for production** pending Xcode project integration and QA testing.

---

**End of Document**