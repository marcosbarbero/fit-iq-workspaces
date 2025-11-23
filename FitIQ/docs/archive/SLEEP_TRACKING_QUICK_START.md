# Sleep Tracking Quick Start Guide

**Last Updated:** 2025-01-27  
**Status:** ✅ Production Ready  
**For:** iOS Developers

---

## 🚀 Quick Start

### 1. Sync Sleep Data from HealthKit

```swift
// Trigger sleep sync for yesterday
await healthDataSyncManager.syncSleepData(
    forDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
    skipIfAlreadySynced: true
)
```

### 2. Display Latest Sleep in Summary

```swift
// Already available in SummaryViewModel
if let hours = summaryViewModel.latestSleepHours,
   let efficiency = summaryViewModel.latestSleepEfficiency {
    Text("Sleep: \(String(format: "%.1f", hours))h")
    Text("Efficiency: \(efficiency)%")
}
```

### 3. Show Sleep History

```swift
// Navigate to detail view
NavigationLink {
    SleepDetailView(
        viewModel: viewModelAppDependencies.sleepDetailViewModel,
        onSaveSuccess: { }
    )
}
```

---

## 📋 Integration Checklist

### For Background Sync
- [ ] Call `healthDataSyncManager.syncSleepData()` in background task
- [ ] Set `skipIfAlreadySynced: true` to prevent duplicates
- [ ] Default syncs yesterday's data automatically

### For Summary Card (UI TODO)
- [ ] Bind to `viewModel.latestSleepHours`
- [ ] Bind to `viewModel.latestSleepEfficiency`
- [ ] Show "No Data" when values are nil
- [ ] Add navigation to `SleepDetailView`

### For Detail View
- [x] ViewModel already integrated
- [x] Real repository data displayed
- [x] Time range selection working
- [x] Charts and statistics working

---

## 🎯 Key Features

### Automatic Sync
- HealthKit → Local Storage → Backend
- Outbox Pattern ensures no data loss
- Deduplication by HealthKit UUID

### Data Available
- Latest sleep duration (hours)
- Sleep efficiency percentage (0-100)
- Historical sleep sessions
- Sleep stage breakdown (Core, Deep, REM, Awake)

### Time Ranges
- Daily (today)
- Last 7 days
- Last 30 days
- Last 3 months

---

## 🔧 Common Tasks

### Force Re-sync
```swift
// Clear sync tracking and re-sync
healthDataSyncManager.clearHistoricalSyncTracking()
await healthDataSyncManager.syncSleepData(forDate: date, skipIfAlreadySynced: false)
```

### Check Sync Status
```swift
// Check if date already synced
let isSynced = healthDataSyncManager.hasAlreadySyncedDate(
    date,
    forKey: "com.fitiq.historical.sleep.synced"
)
```

### Fetch Specific Date Range
```swift
// Fetch sessions from repository
let sessions = try await sleepRepository.fetchSessions(
    forUserID: userID,
    from: startDate,
    to: endDate,
    syncStatus: .synced  // Or nil for all statuses
)
```

---

## 🐛 Troubleshooting

### No Sleep Data Showing
1. Check HealthKit permissions granted
2. Verify sleep data exists in Health app
3. Check sync was triggered: `healthDataSyncManager.syncSleepData()`
4. Look for console logs: "HealthDataSyncService: 🌙 Syncing sleep data..."

### Duplicate Sessions
- Should not happen due to `sourceID` deduplication
- If duplicates appear, check `sourceID` is set correctly
- Repository checks for existing `sourceID` before inserting

### Backend Sync Failing
1. Check outbox events: Query `SDOutboxEvent` where `eventType == "sleepSession"`
2. Check event status: `.pending`, `.synced`, or `.failed`
3. Review `OutboxProcessorService` logs
4. Verify backend API is accessible

---

## 📊 Data Model Reference

### SleepSession
```swift
struct SleepSession {
    let id: UUID
    let userID: String
    let date: Date                  // Start of day
    let startTime: Date             // Actual sleep start
    let endTime: Date               // Actual sleep end
    let timeInBedMinutes: Int       // Total time in bed
    let totalSleepMinutes: Int      // Excludes awake/in_bed
    let sleepEfficiency: Double     // Percentage (0-100)
    let source: String?             // "healthkit"
    let sourceID: String?           // HealthKit UUID (for dedup)
    let stages: [SleepStage]?       // Sleep stage breakdown
}
```

### SleepStage
```swift
struct SleepStage {
    let stage: SleepStageType       // .asleepCore, .asleepDeep, etc.
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
}
```

### SleepStageType
```swift
enum SleepStageType {
    case inBed          // HealthKit: 0
    case asleep         // HealthKit: 1
    case awake          // HealthKit: 2
    case asleepCore     // HealthKit: 3 (light sleep)
    case asleepDeep     // HealthKit: 4
    case asleepREM      // HealthKit: 5
}
```

---

## 🎨 UI Color Reference

```swift
// Use these colors for consistency
.asleepDeep → .midnightIndigo
.asleepCore → .oceanCore
.asleepREM  → .skyBlue
.awake      → .warningRed
.inBed      → Color.gray.opacity(0.3)
.asleep     → .serenityLavender
```

---

## 📝 Code Examples

### Example 1: Sync Last 7 Days
```swift
let calendar = Calendar.current
for i in 1...7 {
    let date = calendar.date(byAdding: .day, value: -i, to: Date())!
    await healthDataSyncManager.syncSleepData(
        forDate: date,
        skipIfAlreadySynced: true
    )
}
```

### Example 2: Display Sleep Card
```swift
struct SleepSummaryCard: View {
    @Bindable var viewModel: SummaryViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Sleep")
                .font(.headline)
            
            if let hours = viewModel.latestSleepHours,
               let efficiency = viewModel.latestSleepEfficiency {
                HStack {
                    Text("\(String(format: "%.1f", hours))h")
                        .font(.title)
                    Spacer()
                    Text("\(efficiency)%")
                        .foregroundColor(efficiency > 85 ? .green : .orange)
                }
            } else {
                Text("No sleep data")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
```

### Example 3: Custom Date Range Query
```swift
// Fetch sleep sessions for a specific week
let startOfWeek = calendar.startOfDay(for: date)
let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!

let sessions = try await sleepRepository.fetchSessions(
    forUserID: authManager.currentUserProfileID!.uuidString,
    from: startOfWeek,
    to: endOfWeek,
    syncStatus: nil
)

// Calculate average for the week
let totalSleep = sessions.reduce(0) { $0 + $1.totalSleepMinutes }
let avgSleep = sessions.isEmpty ? 0 : totalSleep / sessions.count
print("Average sleep this week: \(avgSleep / 60)h \(avgSleep % 60)min")
```

---

## 🔐 Security Notes

- Sleep data is sensitive health information
- Always check user authentication before accessing
- Respect HealthKit permissions
- Backend sync requires valid JWT token
- Local storage encrypted via SwiftData

---

## 📚 Related Documentation

- **Full Implementation:** `SLEEP_TRACKING_IMPLEMENTATION.md`
- **Completion Summary:** `SLEEP_TRACKING_INTEGRATION_COMPLETE.md`
- **API Spec:** `docs/be-api-spec/swagger.yaml` (search for `/api/v1/sleep`)
- **Architecture Guide:** `.github/copilot-instructions.md`

---

## ✅ Status

**HealthKit Sync:** ✅ Complete  
**Local Storage:** ✅ Complete  
**Backend Sync:** ✅ Complete  
**Summary ViewModel:** ✅ Complete  
**Detail View:** ✅ Complete  
**UI Card:** ⏳ Pending (developer to implement)

---

**Questions?** Check the full documentation in `SLEEP_TRACKING_IMPLEMENTATION.md`
