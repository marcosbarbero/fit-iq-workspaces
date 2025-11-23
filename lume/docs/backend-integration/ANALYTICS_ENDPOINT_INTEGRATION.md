# Analytics Endpoint Integration Analysis

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** Ready for Implementation  
**Endpoint:** `GET /api/v1/wellness/mood-entries/analytics`

---

## Executive Summary

The backend analytics endpoint provides **rich, pre-computed mood statistics** that can significantly enhance the Mood Insights view. Currently, the app computes all statistics locally from raw mood entries. The analytics endpoint offers:

✅ **Pre-computed aggregations** - Faster performance, less device processing  
✅ **Trend analysis** - Week-over-week mood trends with direction  
✅ **Top labels & associations** - Most frequent moods with percentages  
✅ **Daily breakdowns** - Optional granular daily statistics  
✅ **Consistency metrics** - Logging consistency percentage  

**Recommendation:** Replace local computation with backend analytics for better performance, richer insights, and future scalability.

---

## Current Implementation vs Analytics Endpoint

### What We Compute Locally Now

```swift
struct MoodDashboardStats {
    let todayEntries: [MoodEntry]
    let weekEntries: [MoodEntry]
    let monthEntries: [MoodEntry]

    var averageTodayValence: Double { ... }
    var averageWeekValence: Double { ... }
    var averageMonthValence: Double { ... }
    var todayLabelDistribution: [String: Int] { ... }
}
```

**Limitations:**
- ❌ Only basic averages
- ❌ No trend direction (improving/declining/stable)
- ❌ No weekly breakdown
- ❌ No consistency metrics
- ❌ No association tracking
- ❌ Device processes all raw data every time

### What Analytics Endpoint Provides

```json
{
  "data": {
    "period": {
      "start_date": "2024-01-01",
      "end_date": "2024-01-31",
      "total_days": 31
    },
    "summary": {
      "total_entries": 45,
      "average_valence": 0.35,
      "days_with_entries": 28,
      "logging_consistency": 0.903
    },
    "trends": {
      "trend_direction": "improving",
      "weekly_averages": [
        { "week_start": "2024-01-01", "average_valence": 0.2 },
        { "week_start": "2024-01-08", "average_valence": 0.35 },
        { "week_start": "2024-01-15", "average_valence": 0.45 },
        { "week_start": "2024-01-22", "average_valence": 0.5 }
      ]
    },
    "top_labels": [
      { "label": "happy", "count": 15, "percentage": 0.333 },
      { "label": "grateful", "count": 12, "percentage": 0.267 },
      { "label": "peaceful", "count": 10, "percentage": 0.222 }
    ],
    "top_associations": [
      { 
        "association": "fitness", 
        "count": 20, 
        "percentage": 0.444,
        "average_valence": 0.6
      }
    ],
    "daily_aggregates": [
      {
        "date": "2024-01-15",
        "entry_count": 3,
        "average_valence": 0.5,
        "min_valence": 0.2,
        "max_valence": 0.8,
        "most_common_labels": [
          { "label": "happy", "count": 2 }
        ]
      }
    ]
  }
}
```

**Advantages:**
- ✅ Pre-computed on backend (faster, scales better)
- ✅ Trend direction analysis
- ✅ Weekly breakdowns for trend visualization
- ✅ Consistency metrics (days logged vs total days)
- ✅ Top labels with percentages
- ✅ Association tracking with average valence
- ✅ Optional daily granular data
- ✅ Min/max valence per day

---

## Integration Opportunities

### 1. Enhanced Summary Card

**Current:** Shows average valence as a large mood icon (closest matching mood)

**With Analytics:**
- ✅ Show **logging consistency** percentage ("You logged 28 of 31 days - 90%!")
- ✅ Display **trend direction** with visual indicator (↗️ improving, → stable, ↘️ declining)
- ✅ Add **entry count** ("Based on 45 mood entries")
- ✅ Show **most frequent mood** from top_labels

```swift
VStack(spacing: 12) {
    // Large mood icon (based on average valence)
    MoodIconView(averageValence: stats.summary.averageValence)
    
    // Trend indicator
    HStack {
        Image(systemName: trendIcon)
        Text(trendText) // "Improving this month"
    }
    .foregroundColor(trendColor)
    
    // Consistency badge
    Text("\(Int(stats.summary.loggingConsistency * 100))% consistency")
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.2))
        .cornerRadius(12)
    
    // Entry count
    Text("\(stats.summary.totalEntries) entries over \(stats.period.totalDays) days")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

### 2. Weekly Trend Visualization

**Current:** Shows all entries as individual points

**With Analytics:**
- ✅ Show **weekly averages** as a smoother trend line
- ✅ Highlight **week-over-week changes**
- ✅ Compare current week to previous weeks
- ✅ Show trend direction clearly

```swift
Chart {
    ForEach(stats.trends.weeklyAverages) { week in
        LineMark(
            x: .value("Week", week.weekStart),
            y: .value("Valence", week.averageValence)
        )
        .foregroundStyle(getMoodColor(week.averageValence))
        
        PointMark(
            x: .value("Week", week.weekStart),
            y: .value("Valence", week.averageValence)
        )
        .foregroundStyle(getMoodColor(week.averageValence))
    }
}
```

### 3. Top Moods Section (NEW!)

**Not currently implemented** - would be a great addition

**With Analytics:**
- ✅ Show **top 5 most frequent moods** with percentages
- ✅ Visual bar chart or percentage indicators
- ✅ Mood icon + label + percentage
- ✅ Help users understand their mood patterns

```swift
VStack(alignment: .leading, spacing: 16) {
    Text("Your Top Moods")
        .font(LumeTypography.titleMedium)
        .fontWeight(.semibold)
    
    ForEach(stats.topLabels.prefix(5)) { labelStat in
        HStack {
            // Mood icon
            Image(systemName: moodLabel.systemImage)
                .foregroundColor(moodLabel.color)
            
            // Label name
            Text(moodLabel.displayName)
                .font(LumeTypography.body)
            
            Spacer()
            
            // Percentage
            Text("\(Int(labelStat.percentage * 100))%")
                .font(LumeTypography.body)
                .fontWeight(.semibold)
            
            // Percentage bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(moodLabel.color.opacity(0.3))
                    .frame(width: geo.size.width * labelStat.percentage)
            }
            .frame(width: 60, height: 8)
        }
    }
}
.padding(20)
.background(LumeColors.surface)
.cornerRadius(16)
```

### 4. Consistency Insights (NEW!)

**Not currently implemented** - valuable motivational feature

**With Analytics:**
- ✅ Show **logging consistency** as a motivational metric
- ✅ Celebrate streaks and consistency improvements
- ✅ Gentle encouragement for better tracking
- ✅ Warm, supportive messaging

```swift
VStack(spacing: 12) {
    HStack {
        Image(systemName: "calendar.badge.checkmark")
            .foregroundColor(.green)
        Text("Consistency")
            .font(LumeTypography.titleMedium)
            .fontWeight(.semibold)
    }
    
    // Progress circle
    ZStack {
        Circle()
            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
        
        Circle()
            .trim(from: 0, to: stats.summary.loggingConsistency)
            .stroke(Color.green, lineWidth: 8)
            .rotationEffect(.degrees(-90))
        
        VStack {
            Text("\(Int(stats.summary.loggingConsistency * 100))%")
                .font(.system(size: 32, weight: .bold))
            Text("of days")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .frame(width: 120, height: 120)
    
    Text(consistencyMessage)
        .font(LumeTypography.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
}
.padding(20)
.background(LumeColors.surface)
.cornerRadius(16)

// Warm messaging based on consistency
var consistencyMessage: String {
    switch stats.summary.loggingConsistency {
    case 0.9...: return "Amazing! You're building a wonderful habit 🌟"
    case 0.7..<0.9: return "Great job staying consistent! Keep it up 💚"
    case 0.5..<0.7: return "You're doing well! A few more days each week 🌱"
    case 0.3..<0.5: return "Every entry counts. You're on your way 🌿"
    default: return "Take it one day at a time 🤍"
    }
}
```

### 5. Association Insights (FUTURE)

**Not currently tracked** - requires backend association tracking

**With Analytics (when associations are tracked):**
- ✅ Show which activities correlate with positive moods
- ✅ "Your mood is 0.6 higher when you log 'fitness'"
- ✅ Help users identify mood-boosting activities
- ✅ Personalized insights

```swift
VStack(alignment: .leading, spacing: 16) {
    Text("What Brightens Your Mood")
        .font(LumeTypography.titleMedium)
        .fontWeight(.semibold)
    
    ForEach(stats.topAssociations.prefix(3)) { assoc in
        HStack(spacing: 12) {
            // Icon based on association type
            Image(systemName: getAssociationIcon(assoc.association))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(assoc.association.capitalized)
                    .font(LumeTypography.body)
                    .fontWeight(.medium)
                
                Text("Avg mood: \(formatValence(assoc.averageValence))")
                    .font(LumeTypography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(assoc.count)x")
                .font(LumeTypography.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}
.padding(20)
.background(LumeColors.surface)
.cornerRadius(16)
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1)

**Goal:** Set up analytics API integration without breaking existing functionality

1. **Create Analytics Models**
   ```swift
   // In Domain/Entities/
   struct MoodAnalytics {
       let period: AnalyticsPeriod
       let summary: AnalyticsSummary
       let trends: AnalyticsTrends
       let topLabels: [LabelStatistic]
       let topAssociations: [AssociationStatistic]
       let dailyAggregates: [DailyAggregate]?
   }
   
   struct AnalyticsPeriod {
       let startDate: Date
       let endDate: Date
       let totalDays: Int
   }
   
   struct AnalyticsSummary {
       let totalEntries: Int
       let averageValence: Double
       let daysWithEntries: Int
       let loggingConsistency: Double
   }
   
   struct AnalyticsTrends {
       let trendDirection: TrendDirection
       let weeklyAverages: [WeeklyAverage]
   }
   
   enum TrendDirection: String, Codable {
       case improving
       case stable
       case declining
       case insufficientData = "insufficient_data"
   }
   ```

2. **Add Analytics Port**
   ```swift
   // In Domain/Ports/
   protocol MoodAnalyticsRepositoryProtocol {
       func fetchAnalytics(
           from: Date,
           to: Date,
           includeDailyBreakdown: Bool
       ) async throws -> MoodAnalytics
   }
   ```

3. **Implement Backend Service**
   ```swift
   // In Services/MoodBackendService.swift
   func fetchAnalytics(
       from: Date,
       to: Date,
       includeDailyBreakdown: Bool,
       accessToken: String
   ) async throws -> MoodAnalytics {
       let params: [String: String] = [
           "from": ISO8601DateFormatter().string(from: from),
           "to": ISO8601DateFormatter().string(from: to),
           "include_daily_breakdown": "\(includeDailyBreakdown)"
       ]
       
       let response: AnalyticsResponse = try await httpClient.get(
           path: "/api/v1/wellness/mood-entries/analytics",
           queryParams: params,
           accessToken: accessToken
       )
       
       return response.data
   }
   ```

4. **Add Repository Method**
   ```swift
   // In Data/Repositories/MoodRepository.swift
   func fetchAnalytics(
       from: Date,
       to: Date,
       includeDailyBreakdown: Bool
   ) async throws -> MoodAnalytics {
       guard let token = try await authRepository.getAccessToken() else {
           throw MoodError.notAuthenticated
       }
       
       return try await backendService.fetchAnalytics(
           from: from,
           to: to,
           includeDailyBreakdown: includeDailyBreakdown,
           accessToken: token
       )
   }
   ```

### Phase 2: UI Integration (Week 2)

**Goal:** Update MoodDashboardView to use analytics data

1. **Update ViewModel**
   ```swift
   // In Presentation/ViewModels/MoodViewModel.swift
   @Published var analytics: MoodAnalytics?
   @Published var analyticsError: Error?
   
   func loadAnalytics(for period: MoodTimePeriod) async {
       let endDate = Date()
       let startDate = Calendar.current.date(
           byAdding: .day,
           value: -period.days,
           to: endDate
       ) ?? endDate
       
       do {
           analytics = try await moodRepository.fetchAnalytics(
               from: startDate,
               to: endDate,
               includeDailyBreakdown: period == .today
           )
       } catch {
           analyticsError = error
           print("Failed to load analytics: \(error)")
       }
   }
   ```

2. **Update Summary Card**
   - Add trend direction indicator
   - Add consistency percentage
   - Add entry count
   - Keep existing mood icon based on average valence

3. **Update Chart View**
   - Option to show weekly averages vs daily entries
   - Smoother trend line for longer periods
   - Keep existing interaction

### Phase 3: New Features (Week 3)

**Goal:** Add new insights only possible with analytics

1. **Top Moods Section**
   - Show top 5 moods with percentages
   - Visual bars
   - Mood icons and colors

2. **Consistency Card**
   - Circular progress indicator
   - Warm, encouraging messaging
   - Celebrates logging habits

3. **Polish & Testing**
   - Error handling (fallback to local computation)
   - Loading states
   - Empty states
   - Performance testing

### Phase 4: Future Enhancements

1. **Association Tracking** (requires backend changes)
   - Track mood context (fitness, work, social, etc.)
   - Show which activities correlate with better moods

2. **Comparison Views**
   - "This week vs last week"
   - "This month vs last month"
   - Highlight improvements

3. **Insights Narratives**
   - "Your mood improved by 15% this month"
   - "You've been most consistent with weekend logging"
   - "Happy is your most frequent mood"

---

## API Query Strategy

### Recommended Parameters

**For Today View:**
```
from: start of today
to: now
include_daily_breakdown: false
```

**For 7D/30D/90D Views:**
```
from: period start
to: now
include_daily_breakdown: false
top_labels_limit: 5
```

**For Detailed Analysis:**
```
from: period start
to: now
include_daily_breakdown: true
top_labels_limit: 10
```

### Caching Strategy

- ✅ Cache analytics response for 5 minutes
- ✅ Invalidate cache when new mood entry is saved
- ✅ Background refresh on app launch
- ✅ Pull-to-refresh for manual update

---

## Error Handling

### Graceful Degradation

If analytics endpoint fails:
1. ✅ Fall back to local computation
2. ✅ Show error banner (temporary)
3. ✅ Log error for debugging
4. ✅ Don't break user experience

```swift
func loadAnalytics(for period: MoodTimePeriod) async {
    do {
        analytics = try await moodRepository.fetchAnalytics(...)
    } catch {
        // Fallback to local computation
        print("Analytics unavailable, computing locally")
        analytics = computeLocalAnalytics(for: period)
        
        // Show subtle error banner
        showTemporaryBanner("Showing local insights")
    }
}
```

---

## Benefits Summary

### Performance
- ✅ **Faster loading** - Backend does heavy computation
- ✅ **Less device processing** - Especially for large datasets
- ✅ **Scalable** - Works with thousands of entries

### Features
- ✅ **Richer insights** - Trend direction, consistency, top moods
- ✅ **Better visualizations** - Weekly trends, top labels
- ✅ **Motivational metrics** - Consistency tracking

### Architecture
- ✅ **Backend logic** - Complex analytics on server
- ✅ **Future-proof** - Easy to add new metrics
- ✅ **Consistent** - Same analytics across all clients

---

## Next Steps

1. **Review this proposal** with team
2. **Confirm analytics endpoint is production-ready** on backend
3. **Start Phase 1** - Foundation and API integration
4. **Design mockups** for new UI components (Top Moods, Consistency Card)
5. **Implement Phase 2** - Update existing views
6. **Test thoroughly** - Edge cases, error handling, empty states
7. **Launch Phase 3** - New features

---

## Questions for Backend Team

1. Is the analytics endpoint production-ready and stable?
2. What's the expected response time for analytics queries?
3. Are there rate limits or usage quotas?
4. How fresh is the data (real-time or cached)?
5. What happens when there are zero entries for a period?
6. Are associations tracked yet, or is that future work?
7. Can we get analytics for custom date ranges (not just fixed periods)?

---

## Conclusion

The `/api/v1/wellness/mood-entries/analytics` endpoint provides excellent opportunities to enhance the Mood Insights view with richer, more meaningful data. By replacing local computation with pre-computed backend analytics, we gain:

- **Better performance** at scale
- **Richer insights** (trends, consistency, top moods)
- **New features** (consistency tracking, top moods section)
- **Future scalability** for advanced analytics

**Recommendation:** Proceed with phased implementation, starting with foundation work and gradually migrating existing views to use analytics data.