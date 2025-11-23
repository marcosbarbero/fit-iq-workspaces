# Local-First Nutrition Pattern

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Document the local-first architecture pattern for nutrition tracking

---

## Overview

The FitIQ nutrition tracking feature follows a **local-first architecture** where:
- All data is **read from local storage** (SwiftData)
- All writes go to **local storage first**, then sync to backend via **Outbox Pattern**
- **WebSocket** receives real-time updates from backend and updates local storage
- The UI **never directly calls the remote API** for data fetching

This ensures:
✅ Instant UI updates  
✅ Offline capability  
✅ Reliable data synchronization  
✅ No duplicate API calls  
✅ Single source of truth (local storage)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│                      (NutritionView)                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Always reads local
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                      NutritionViewModel                         │
│                                                                 │
│  loadDataForSelectedDate() {                                   │
│    getMealLogsUseCase.execute(useLocalOnly: true) ✅          │
│  }                                                             │
│                                                                 │
│  saveMealLog() {                                               │
│    saveMealLogUseCase.execute() → Triggers Outbox Pattern     │
│  }                                                             │
└────────────┬───────────────────────────────────┬───────────────┘
             │                                   │
             │ Read                              │ Write
             ↓                                   ↓
┌────────────────────────────────┐  ┌──────────────────────────────┐
│   GetMealLogsUseCase           │  │  SaveMealLogUseCase          │
│   (reads local only)           │  │  (writes local + outbox)     │
└────────────┬───────────────────┘  └──────────┬───────────────────┘
             │                                  │
             │                                  │
             ↓                                  ↓
┌────────────────────────────────────────────────────────────────┐
│                    Local Storage (SwiftData)                   │
│                  SDMeal, SDMealLogItem, etc.                   │
└───────────┬──────────────────────────────────┬─────────────────┘
            │                                  │
            │ Reads                            │ Writes create
            │                                  │ SDOutboxEvent
            ↓                                  ↓
┌───────────────────────┐         ┌──────────────────────────────┐
│  Returns to ViewModel │         │   OutboxProcessorService     │
└───────────────────────┘         │   (background sync)          │
                                  └──────────┬───────────────────┘
                                             │
                                             │ Syncs to backend
                                             ↓
                                  ┌──────────────────────────────┐
                                  │      Backend API             │
                                  │  POST /meal-logs/natural     │
                                  └──────────┬───────────────────┘
                                             │
                                             │ Processing complete
                                             ↓
                                  ┌──────────────────────────────┐
                                  │      WebSocket               │
                                  │  meal_log_status_update      │
                                  └──────────┬───────────────────┘
                                             │
                                             │ Updates local
                                             ↓
                                  ┌──────────────────────────────┐
                                  │    Local Storage Update      │
                                  │  (status, items, nutrition)  │
                                  └──────────┬───────────────────┘
                                             │
                                             │ Triggers UI refresh
                                             ↓
                                  ┌──────────────────────────────┐
                                  │    ViewModel refreshes       │
                                  │    loadDataForSelectedDate() │
                                  └──────────────────────────────┘
```

---

## Data Flow

### 1. User Logs a Meal

```
User enters "120g chicken breast" → NutritionViewModel.saveMealLog()
  ↓
SaveMealLogUseCase.execute()
  ↓
SwiftDataMealLogRepository.save()
  ↓
1. Creates SDMeal (status: .pending, syncStatus: .pending)
  ↓
2. Automatically creates SDOutboxEvent (via Outbox Pattern)
  ↓
3. Returns localID to ViewModel immediately
  ↓
4. ViewModel refreshes: loadDataForSelectedDate() → reads local storage
  ↓
UI shows meal with "pending" status instantly ✅
```

### 2. Background Sync (Outbox Pattern)

```
OutboxProcessorService (background timer)
  ↓
Fetches pending SDOutboxEvent entries
  ↓
For each event:
  ↓
NutritionAPIClient.submitMealLog()
  ↓
POST /api/v1/meal-logs/natural
  ↓
Backend responds with backendID
  ↓
Updates SDMeal.backendID and syncStatus = .synced
  ↓
Marks SDOutboxEvent as completed
```

### 3. Backend Processing & WebSocket Update

```
Backend processes meal log (AI parsing)
  ↓
Sends WebSocket message:
  {
    "type": "meal_log_status_update",
    "data": {
      "meal_log_id": "abc123",
      "status": "completed",
      "items": [...],
      "total_calories": 200,
      ...
    }
  }
  ↓
MealLogWebSocketService receives update
  ↓
Calls ViewModel.handleWebSocketUpdate()
  ↓
ViewModel triggers: loadDataForSelectedDate()
  ↓
Reads updated local storage
  ↓
UI shows meal with "completed" status and nutrition info ✅
```

### 4. User Switches Dates

```
User selects different date → ViewModel.loadDataForSelectedDate()
  ↓
GetMealLogsUseCase.execute(useLocalOnly: true)
  ↓
SwiftDataMealLogRepository.fetchLocal()
  ↓
Returns meals from local storage (filtered by date)
  ↓
UI renders instantly (no network call) ✅
```

---

## Critical Implementation Details

### ✅ Always Use `useLocalOnly: true`

**In NutritionViewModel.swift:**

```swift
// ✅ CORRECT - Local-first
let mealLogs = try await getMealLogsUseCase.execute(
    status: .completed,
    syncStatus: nil,
    mealType: nil,
    startDate: startOfDay,
    endDate: endOfDay,
    limit: nil,
    useLocalOnly: true  // ✅ Always read from local storage
)

// ❌ WRONG - Remote-first (defeats the purpose)
let mealLogs = try await getMealLogsUseCase.execute(
    ...
    useLocalOnly: false  // ❌ Tries remote API, causes delays
)
```

### ✅ WebSocket Updates Trigger Local Refresh

**In NutritionViewModel.swift:**

```swift
private func handleWebSocketUpdate(_ update: MealLogStatusUpdate) async {
    print("Received WebSocket update for meal log \(update.mealLogId)")
    
    // Update local storage (via repository)
    // ... update logic ...
    
    // ✅ Refresh view from local storage
    await loadDataForSelectedDate()
}
```

### ✅ Outbox Pattern Handles Sync Automatically

**No manual sync calls needed!**

```swift
// ✅ CORRECT - Just save locally, Outbox handles sync
func saveMealLog(...) async {
    let localID = try await saveMealLogUseCase.execute(...)
    // That's it! Outbox Pattern will sync to backend automatically
    
    await loadDataForSelectedDate()  // Refresh from local
}

// ❌ WRONG - Manual remote API call
func saveMealLog(...) async {
    let localID = try await saveMealLogUseCase.execute(...)
    try await nutritionAPIClient.submitMealLog(...)  // ❌ Duplicate sync!
}
```

---

## Benefits of Local-First Architecture

### 1. **Instant UI Updates**
- No waiting for network requests
- Immediate feedback to user actions
- Smooth, responsive experience

### 2. **Offline Capability**
- Works without internet connection
- Data is always available locally
- Syncs automatically when connection restored

### 3. **Reliable Synchronization**
- Outbox Pattern guarantees eventual consistency
- No data loss if app crashes
- Automatic retries on failure

### 4. **Single Source of Truth**
- Local storage is the authoritative source for UI
- WebSocket updates keep it in sync with backend
- No confusion about which data to display

### 5. **Reduced Network Traffic**
- No redundant API calls
- Only sync when needed (via Outbox)
- WebSocket provides efficient real-time updates

### 6. **Better Performance**
- Reading from local storage is orders of magnitude faster
- No network latency
- Battery efficient (fewer network requests)

---

## Anti-Patterns to Avoid

### ❌ Don't Fetch from Remote API in ViewModel

```swift
// ❌ WRONG - Defeats local-first architecture
func loadDataForSelectedDate() async {
    let mealLogs = try await nutritionAPIClient.getMealLogs(...)  // ❌ Direct API call
    self.meals = mealLogs
}
```

**Why it's wrong:**
- Requires internet connection
- Slow (network latency)
- Duplicate data fetching
- Bypasses local storage

### ❌ Don't Use `useLocalOnly: false` for Regular Views

```swift
// ❌ WRONG - Only use remote fetching for special cases
let mealLogs = try await getMealLogsUseCase.execute(
    ...
    useLocalOnly: false  // ❌ Tries remote first
)
```

**Why it's wrong:**
- Slow UI updates
- Doesn't work offline
- Unnecessary network calls
- Defeats the purpose of local storage

### ❌ Don't Manually Sync to Backend

```swift
// ❌ WRONG - Outbox Pattern handles this automatically
func saveMealLog(...) async {
    let localID = try await saveMealLogUseCase.execute(...)
    try await nutritionAPIClient.submitMealLog(...)  // ❌ Manual sync
}
```

**Why it's wrong:**
- Duplicate sync logic
- No retry on failure
- Not crash-resistant
- Bypasses Outbox Pattern

---

## When to Use Remote API Directly

### ✅ Only in Background Services

Remote API calls should **only** be made by:

1. **OutboxProcessorService** - Syncing pending events to backend
2. **Background refresh tasks** - Periodically syncing data when app is backgrounded
3. **Admin/debug tools** - Special cases for troubleshooting

### ✅ Never in ViewModels or Views

ViewModels and Views should **always** read from local storage.

---

## Testing the Pattern

### Test 1: Offline Functionality

```
1. Turn off internet
2. Log a meal
3. ✅ Meal appears in list immediately (status: pending)
4. Turn on internet
5. ✅ Meal syncs to backend automatically
6. ✅ WebSocket updates status to "completed"
```

### Test 2: Real-time Updates

```
1. Log a meal on Device A
2. ✅ Device A shows meal immediately (status: pending)
3. Backend processes meal
4. ✅ Device A receives WebSocket update
5. ✅ Device A shows meal with status "completed" + nutrition info
6. ✅ Device B (same user) also receives WebSocket update
7. ✅ Both devices show identical data
```

### Test 3: App Restart

```
1. Log a meal
2. Force quit app (before sync completes)
3. Restart app
4. ✅ Meal is still in local storage (not lost)
5. ✅ Outbox Pattern automatically syncs on next run
```

### Test 4: Date Switching Performance

```
1. Log 10 meals across different dates
2. Switch between dates
3. ✅ Each date switch is instant (reads local storage)
4. ✅ No network indicator shown
5. ✅ No loading delays
```

---

## Migration from Remote-First to Local-First

### Before (Remote-First) ❌

```swift
func loadDataForSelectedDate() async {
    // ❌ Fetches from remote API
    let mealLogs = try await nutritionAPIClient.getMealLogs(
        startDate: startOfDay,
        endDate: endOfDay
    )
    self.meals = mealLogs
}
```

**Problems:**
- Slow (network latency)
- Doesn't work offline
- Unnecessary network calls
- Battery drain

### After (Local-First) ✅

```swift
func loadDataForSelectedDate() async {
    // ✅ Reads from local storage
    let mealLogs = try await getMealLogsUseCase.execute(
        startDate: startOfDay,
        endDate: endOfDay,
        useLocalOnly: true  // ✅ Local-first
    )
    self.meals = mealLogs.map { DailyMealLog.from(mealLog: $0) }
}
```

**Benefits:**
- Instant (no network)
- Works offline
- Battery efficient
- Always up-to-date (via WebSocket)

---

## Related Patterns

- **Outbox Pattern** - Ensures reliable sync to backend
- **WebSocket Updates** - Keeps local storage in sync with backend
- **Repository Pattern** - Abstracts local storage access
- **CQRS** - Separate read (local) and write (local + outbox) paths

---

## Related Documentation

- [Outbox Pattern Documentation](./OUTBOX_PATTERN.md)
- [WebSocket Service Pattern](./WEBSOCKET_SERVICE_PATTERN.md)
- [Repository Pattern Guidelines](./REPOSITORY_PATTERN.md)
- [Summary Data Loading Pattern](./SUMMARY_DATA_LOADING_PATTERN.md)

---

## Key Takeaways

1. **Always read from local storage** - Never fetch from remote API in ViewModels
2. **Use `useLocalOnly: true`** - This is the default for all UI data fetching
3. **Outbox Pattern handles sync** - Don't manually sync to backend
4. **WebSocket updates local storage** - Keeps data fresh automatically
5. **Local storage is the source of truth** - For the UI, not the backend

---

**Remember: The backend is authoritative for the entire system, but local storage is authoritative for the UI. WebSocket and Outbox Pattern keep them in sync.**

---

**Status:** ✅ Active  
**Pattern Used In:** Nutrition tracking, Progress tracking, Sleep tracking, Mood tracking  
**Last Verified:** 2025-01-27