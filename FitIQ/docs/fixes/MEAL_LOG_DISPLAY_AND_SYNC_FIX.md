# Meal Log Display and Outbox Sync Fix

**Date:** 2025-01-27  
**Issues:** 
1. Newly saved meals not appearing in UI
2. Outbox processor not syncing meal logs to backend
**Status:** ✅ Resolved

---

## Problems

### Problem 1: Meals Not Appearing After Save

**Symptom:**
```
User logs meal → Saves successfully → UI shows 0 meals
```

**Root Cause:** ViewModel filtered for `.completed` status only, but newly saved meals have `.pending` status.

```swift
// ❌ WRONG - Only shows completed meals
let mealLogs = try await getMealLogsUseCase.execute(
    status: .completed,  // Filters out pending/processing meals!
    ...
)
```

**Expected Behavior:**
- Show meal immediately after saving (status: `.pending`)
- Update meal when processing starts (status: `.processing`)
- Update meal when processing completes (status: `.completed`)
- Show all meals regardless of status

### Problem 2: Outbox Processor Not Syncing Meal Logs

**Symptom:**
```
OutboxProcessor: ⚠️ Meal log processing not yet implemented (Phase 2)
OutboxProcessor: ❌ Failed to process [Meal Log]
Error: Feature not yet implemented: Meal log processing - will be implemented in Phase 2
```

**Root Cause:** Outbox processor had a TODO placeholder instead of actual implementation.

```swift
case .mealLog:
    // TODO: Implement meal log processing in Phase 2
    print("OutboxProcessor: ⚠️ Meal log processing not yet implemented (Phase 2)")
    throw OutboxProcessorError.notImplemented("Meal log processing...")
```

---

## Solutions

### Fix 1: Show All Meal Statuses in UI

**File:** `Presentation/ViewModels/NutritionViewModel.swift` (Line 146)

**Before:**
```swift
let mealLogs = try await getMealLogsUseCase.execute(
    status: .completed,  // ❌ Only show completed meals
    syncStatus: nil,
    mealType: nil,
    startDate: startOfDay,
    endDate: endOfDay,
    limit: nil,
    useLocalOnly: true
)
```

**After:**
```swift
let mealLogs = try await getMealLogsUseCase.execute(
    status: nil,  // ✅ Show all meals regardless of status
    syncStatus: nil,
    mealType: nil,
    startDate: startOfDay,
    endDate: endOfDay,
    limit: nil,
    useLocalOnly: true
)
```

**Why This Works:**
- User sees their meal immediately after logging (status: `.pending`)
- UI shows processing status in real-time
- WebSocket updates will update the meal's status and nutrition data
- Provides instant feedback to the user

### Fix 2: Implement Meal Log Processing in Outbox Processor

**File:** `Infrastructure/Network/OutboxProcessorService.swift`

#### 2a. Add Dependencies (Lines 35-36, 61-62, 76-77)

```swift
// Add to properties
private let mealLogRepository: MealLogLocalStorageProtocol
private let nutritionAPIClient: MealLogRemoteAPIProtocol

// Add to init parameters
init(
    ...
    sleepAPIClient: SleepAPIClientProtocol,
    mealLogRepository: MealLogLocalStorageProtocol,  // ✅ New
    nutritionAPIClient: MealLogRemoteAPIProtocol,    // ✅ New
    ...
)

// Store in init
self.mealLogRepository = mealLogRepository
self.nutritionAPIClient = nutritionAPIClient
```

#### 2b. Replace TODO with Implementation (Line 249)

**Before:**
```swift
case .mealLog:
    // TODO: Implement meal log processing in Phase 2
    throw OutboxProcessorError.notImplemented("...")
```

**After:**
```swift
case .mealLog:
    try await processMealLog(event)  // ✅ Call actual implementation
```

#### 2c. Add Processing Method (Lines 558-615)

```swift
private func processMealLog(_ event: SDOutboxEvent) async throws {
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        throw OutboxProcessorError.userNotAuthenticated
    }

    print("OutboxProcessor: 🍽️ Processing [Meal Log] - EventID: \(event.id)")

    // Fetch the meal log from local storage
    guard
        let mealLog = try await mealLogRepository.fetchByID(
            event.entityID,
            forUserID: userID
        )
    else {
        throw OutboxProcessorError.entityNotFound(event.entityID)
    }

    print("OutboxProcessor: 📤 Uploading meal log to /api/v1/meal-logs/natural")
    print("  - Meal Log ID: \(mealLog.id)")
    print("  - Raw Input: \(mealLog.rawInput)")
    print("  - Meal Type: \(mealLog.mealType.rawValue)")

    // Upload to backend
    do {
        let backendID = try await nutritionAPIClient.submitMealLog(
            rawInput: mealLog.rawInput,
            mealType: mealLog.mealType.rawValue,
            loggedAt: mealLog.loggedAt,
            notes: mealLog.notes
        )

        print("OutboxProcessor: ✅ Meal log uploaded successfully")
        print("  - Backend ID: \(backendID)")

        // Update local meal log with backend ID and mark as synced
        try await mealLogRepository.updateBackendID(
            forLocalID: event.entityID,
            backendID: backendID,
            forUserID: userID
        )

        try await mealLogRepository.updateSyncStatus(
            forLocalID: event.entityID,
            syncStatus: .synced,
            forUserID: userID
        )

        print("OutboxProcessor: ✅ Meal log marked as synced locally")

    } catch {
        print("OutboxProcessor: ❌ Failed to upload meal log: \(error)")
        throw error
    }
}
```

### Fix 3: Wire Dependencies in AppDependencies

**File:** `Infrastructure/Configuration/AppDependencies.swift` (Lines 758-759)

**Before:**
```swift
let outboxProcessorService = OutboxProcessorService(
    ...
    sleepAPIClient: sleepAPIClient,
    batchSize: 10,
    ...
)
```

**After:**
```swift
let outboxProcessorService = OutboxProcessorService(
    ...
    sleepAPIClient: sleepAPIClient,
    mealLogRepository: compositeMealLogRepository,  // ✅ New
    nutritionAPIClient: nutritionAPIClient,         // ✅ New
    batchSize: 10,
    ...
)
```

---

## Complete Data Flow (After Fix)

### 1. User Logs Meal

```
User enters "120g chicken breast" → NutritionViewModel.saveMealLog()
  ↓
SaveMealLogUseCase.execute()
  ↓
SwiftDataMealLogRepository.save()
  ↓
Creates SDMeal (status: .pending, syncStatus: .pending)
  ↓
Creates SDOutboxEvent automatically
  ↓
Returns localID immediately
  ↓
ViewModel refreshes: loadDataForSelectedDate()
  ↓
✅ UI shows meal with "pending" status instantly
```

### 2. Outbox Processor Syncs to Backend

```
OutboxProcessorService (background timer, every 2s)
  ↓
Fetches pending SDOutboxEvent entries
  ↓
For meal log event:
  ↓
processMealLog(event) ✅ Now implemented!
  ↓
Fetches SDMeal from local storage
  ↓
nutritionAPIClient.submitMealLog()
  ↓
POST /api/v1/meal-logs/natural
  ↓
Backend responds with backendID
  ↓
Updates SDMeal.backendID
  ↓
Updates SDMeal.syncStatus = .synced
  ↓
Deletes SDOutboxEvent (successful)
  ↓
✅ Backend has meal log, starts AI processing
```

### 3. Backend Processing & WebSocket Update

```
Backend AI processes meal log
  ↓
Extracts food items, calculates nutrition
  ↓
Sends WebSocket message:
  {
    "type": "meal_log_status_update",
    "data": {
      "meal_log_id": "abc123",
      "status": "completed",
      "items": [
        {
          "name": "Chicken Breast",
          "quantity": "120g",
          "calories": 198,
          "protein": 37,
          ...
        }
      ],
      "total_calories": 198,
      ...
    }
  }
  ↓
MealLogWebSocketService receives update
  ↓
Calls ViewModel.handleWebSocketUpdate()
  ↓
Updates SDMeal in local storage:
  - status = .completed
  - items = [parsed items]
  - totalCalories = 198
  - totalProteinG = 37
  - etc.
  ↓
ViewModel refreshes: loadDataForSelectedDate()
  ↓
✅ UI shows meal with "completed" status + full nutrition info
```

---

## User Experience Timeline

### Immediate (< 100ms)
```
User clicks "Save"
  ↓
✅ Meal appears in list instantly
✅ Shows "Processing..." status
✅ Shows raw input text
```

### Background (2-5 seconds)
```
Outbox processor syncs to backend
  ↓
Backend receives meal log
  ↓
Backend starts AI processing
```

### Real-time (5-30 seconds)
```
Backend completes processing
  ↓
WebSocket sends update
  ↓
✅ Meal updates to "Completed"
✅ Shows parsed food items
✅ Shows nutrition breakdown
✅ Shows calories, macros, etc.
```

---

## UI Status Display

The UI should show different states based on meal log status:

### Pending
```
┌─────────────────────────────────┐
│ 🍽️ 120g chicken breast          │
│ 🔄 Processing...                 │
│ 8:30 AM                          │
└─────────────────────────────────┘
```

### Processing
```
┌─────────────────────────────────┐
│ 🍽️ 120g chicken breast          │
│ ⏳ Analyzing nutrition...        │
│ 8:30 AM                          │
└─────────────────────────────────┘
```

### Completed
```
┌─────────────────────────────────┐
│ 🍽️ Chicken Breast               │
│ ✅ 198 kcal | 37g protein        │
│ 8:30 AM                          │
│                                  │
│ Chicken Breast (120g)            │
│   • Calories: 198 kcal           │
│   • Protein: 37g                 │
│   • Fat: 4g                      │
│   • Carbs: 0g                    │
└─────────────────────────────────┘
```

### Failed
```
┌─────────────────────────────────┐
│ 🍽️ 120g chicken breast          │
│ ❌ Processing failed             │
│ 🔄 Tap to retry                  │
│ 8:30 AM                          │
└─────────────────────────────────┘
```

---

## Testing

### Test 1: Immediate Display
```
1. Log a meal
2. ✅ Meal appears in list immediately (< 100ms)
3. ✅ Status shows "Processing..."
4. ✅ Raw input text is displayed
```

### Test 2: Background Sync
```
1. Log a meal
2. Wait 2-5 seconds
3. ✅ Check backend logs: POST /api/v1/meal-logs/natural
4. ✅ Outbox event deleted from local storage
5. ✅ Meal syncStatus = .synced
```

### Test 3: WebSocket Update
```
1. Log a meal
2. Wait for backend processing (5-30 seconds)
3. ✅ Meal status updates to "Completed"
4. ✅ Nutrition information appears
5. ✅ Food items list populated
```

### Test 4: Offline Mode
```
1. Turn off internet
2. Log a meal
3. ✅ Meal appears immediately
4. ✅ Status shows "Processing..." (can't sync yet)
5. Turn on internet
6. ✅ Outbox processor syncs automatically
7. ✅ WebSocket updates meal when complete
```

### Test 5: Multiple Meals
```
1. Log 3 meals in quick succession
2. ✅ All 3 appear immediately
3. ✅ All show "Processing..." status
4. ✅ Outbox processor syncs all 3 in order
5. ✅ WebSocket updates each as they complete
```

---

## Key Takeaways

1. **Show All Statuses:** Never filter out pending/processing meals - users need to see their data immediately

2. **Local-First Display:** Always show from local storage, regardless of sync status

3. **Background Sync:** Let Outbox Pattern handle syncing - no manual API calls from ViewModels

4. **Real-time Updates:** WebSocket updates keep UI fresh without polling

5. **Status Feedback:** Show clear status indicators (pending, processing, completed, failed)

6. **Dependency Injection:** Ensure all services have required dependencies (repositories, API clients)

---

## Related Patterns

- **Local-First Architecture** - Always read from local storage
- **Outbox Pattern** - Reliable background sync
- **WebSocket Updates** - Real-time data freshness
- **Progressive Enhancement** - Show data immediately, enhance with details later

---

## Related Documentation

- [Local-First Nutrition Pattern](../architecture/LOCAL_FIRST_NUTRITION_PATTERN.md)
- [Outbox Pattern Documentation](../architecture/OUTBOX_PATTERN.md)
- [WebSocket Service Pattern](../architecture/WEBSOCKET_SERVICE_PATTERN.md)

---

**Status:** ✅ Fixed  
**Verified:** Meals appear immediately, sync in background, update via WebSocket  
**Impact:** Nutrition tracking fully operational with instant feedback

---

**Remember: Show first, sync later, update in real-time!**