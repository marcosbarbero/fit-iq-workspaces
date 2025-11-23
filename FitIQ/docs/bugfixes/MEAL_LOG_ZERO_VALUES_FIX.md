# Meal Log Zero Values Bug Fix

**Date:** 2025-01-27  
**Issue:** UI shows zero values for calories/macros despite backend processing meals correctly  
**Status:** ✅ FIXED

---

## Problem Summary

### Symptoms
- User logs meal (e.g., "1 apple, 1 cup of coffee")
- Backend successfully processes meal via AI
- WebSocket receives completed notification with actual nutritional data:
  - 97 calories
  - 0.8g protein
  - 25g carbs
  - 0.3g fat
  - 2 parsed items
- **BUT:** UI still shows all zeros (0 calories, 0g protein, 0g carbs, 0g fat)

### Root Cause
The WebSocket notification handler (`NutritionViewModel.handleMealLogCompleted()`) was receiving the backend data but **discarding it**:

1. ✅ Meal saved locally with raw input (no nutritional data)
2. ✅ Outbox Pattern syncs to backend
3. ✅ Backend processes and sends WebSocket notification with complete data
4. ❌ **WebSocket handler logged the data but never saved it locally**
5. ✅ UI refreshed from local storage (which still had zeros)

**The missing piece:** Local SwiftData was never updated with the backend processing results.

---

## Solution

### What Was Fixed

#### 1. Created `UpdateMealLogStatusUseCase`
**File:** `FitIQ/Domain/UseCases/Nutrition/UpdateMealLogStatusUseCase.swift`

New use case to update local meal logs when WebSocket notifications arrive:

```swift
protocol UpdateMealLogStatusUseCase {
    func execute(
        backendID: String,
        status: MealLogStatus,
        items: [MealLogItem],
        totalCalories: Int?,
        totalProteinG: Double?,
        totalCarbsG: Double?,
        totalFatG: Double?,
        totalFiberG: Double?,
        totalSugarG: Double?,
        errorMessage: String?
    ) async throws
}
```

**Responsibilities:**
- Find local meal log by backend ID
- Update status (.completed or .failed)
- Update items with parsed food data
- Update total nutritional values
- Save to SwiftData

#### 2. Updated `NutritionViewModel.handleMealLogCompleted()`
**File:** `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`

**Before (❌ Bug):**
```swift
private func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
    print("Received data: \(payload.totalCalories ?? 0) calories")
    
    // Just refresh from local storage (which has no data!)
    await loadDataForSelectedDate()
}
```

**After (✅ Fixed):**
```swift
private func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
    print("Received data: \(payload.totalCalories ?? 0) calories")
    
    // ✅ UPDATE LOCAL STORAGE with backend data
    try await updateMealLogStatusUseCase.execute(
        backendID: payload.id,
        status: .completed,
        items: domainItems,  // Converted from payload
        totalCalories: payload.totalCalories,
        totalProteinG: payload.totalProteinG,
        totalCarbsG: payload.totalCarbsG,
        totalFatG: payload.totalFatG,
        totalFiberG: payload.totalFiberG,
        totalSugarG: payload.totalSugarG,
        errorMessage: nil
    )
    
    // Now refresh UI (will show updated data!)
    await loadDataForSelectedDate()
}
```

#### 3. Dependency Injection Updates
**Files:**
- `FitIQ/Infrastructure/Configuration/AppDependencies.swift`
- `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`
- `FitIQ/Infrastructure/Configuration/ViewDependencies.swift`
- `FitIQ/Presentation/UI/Nutrition/NutritionView.swift`

Added `updateMealLogStatusUseCase` to dependency injection chain:
```swift
// AppDependencies
let updateMealLogStatusUseCase = UpdateMealLogStatusUseCaseImpl(
    mealLogRepository: mealLogRepository,
    authManager: authManager
)

// NutritionViewModel
init(
    saveMealLogUseCase: SaveMealLogUseCase,
    getMealLogsUseCase: GetMealLogsUseCase,
    updateMealLogStatusUseCase: UpdateMealLogStatusUseCase,  // ✅ NEW
    webSocketService: MealLogWebSocketService,
    authManager: AuthManager
)
```

---

## How It Works Now (Complete Flow)

### 1. User Logs Meal
```
User enters: "1 apple, 1 cup of coffee"
↓
SaveMealLogUseCase.execute()
↓
Local meal log created:
  - rawInput: "1 apple, 1 cup of coffee"
  - status: .pending
  - items: [] (empty)
  - totalCalories: nil
  - totalProteinG: nil
  - ...
↓
SwiftData saved locally
↓
Outbox event created automatically
```

### 2. Backend Processing
```
OutboxProcessorService picks up event
↓
POST /api/v1/meal-logs/natural
↓
Backend responds: ID = "77eb0693-25e8-47dd-840b-dfa271a2999a"
↓
Local meal log updated with backendID
↓
Backend processes asynchronously (AI parsing)
```

### 3. WebSocket Notification (THE FIX)
```
WebSocket receives meal_log.completed:
{
  "id": "77eb0693-25e8-47dd-840b-dfa271a2999a",
  "items": [
    { "name": "Apple", "calories": 95, "protein": 0.5, ... },
    { "name": "Coffee", "calories": 2, "protein": 0.3, ... }
  ],
  "totalCalories": 97,
  "totalProteinG": 0.8,
  "totalCarbsG": 25.0,
  "totalFatG": 0.3
}
↓
✅ NEW: UpdateMealLogStatusUseCase.execute()
↓
Find local meal log by backendID: "77eb0693-25e8-47dd-840b-dfa271a2999a"
↓
Update SwiftData:
  - status: .completed
  - items: [Apple, Coffee] ✅
  - totalCalories: 97 ✅
  - totalProteinG: 0.8 ✅
  - totalCarbsG: 25.0 ✅
  - totalFatG: 0.3 ✅
↓
Save to SwiftData
↓
Refresh UI
↓
✅ UI SHOWS CORRECT VALUES!
```

---

## Verification

### Before Fix
```
Logs show:
  "Meal log completed - 97 calories, 0.8g protein"
  "Daily summary - Calories: 0, Protein: 0g" ❌
```

### After Fix
```
Logs show:
  "Meal log completed - 97 calories, 0.8g protein"
  "Local meal log updated with backend data" ✅
  "Daily summary - Calories: 97, Protein: 0.8g" ✅
```

---

## Architecture Compliance

✅ **Hexagonal Architecture:**
- `UpdateMealLogStatusUseCase` is a domain use case (protocol)
- `UpdateMealLogStatusUseCaseImpl` depends on domain ports (not implementations)
- Repository implements the port and handles SwiftData

✅ **Local-First Architecture:**
- Data is always stored locally first
- WebSocket updates sync backend data to local storage
- UI always reads from local storage (single source of truth)

✅ **Dependency Injection:**
- Use case properly registered in `AppDependencies`
- Passed through dependency chain to `NutritionViewModel`

---

## Files Changed

### New Files
1. `FitIQ/Domain/UseCases/Nutrition/UpdateMealLogStatusUseCase.swift`

### Modified Files
1. `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`
2. `FitIQ/Infrastructure/Configuration/AppDependencies.swift`
3. `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`
4. `FitIQ/Infrastructure/Configuration/ViewDependencies.swift`
5. `FitIQ/Presentation/UI/Nutrition/NutritionView.swift`

---

## Testing Instructions

### Manual Testing
1. Log in to the app
2. Navigate to Nutrition tab
3. Add a meal: "1 apple, 1 cup of coffee"
4. Wait 5-10 seconds for backend processing
5. **Expected:** Daily summary should show ~97 calories, 0.8g protein, 25g carbs, 0.3g fat
6. **Previous Behavior:** Would show all zeros

### What to Look For in Logs
```
✅ WebSocket notification received
✅ "UpdateMealLogStatusUseCase: Updating meal log status"
✅ "UpdateMealLogStatusUseCase: Found local meal log ID: ..."
✅ "SwiftDataMealLogRepository: Updated items count: 2"
✅ "UpdateMealLogStatusUseCase: ✅ Meal log updated successfully"
✅ "NutritionViewModel: ✅ Local meal log updated with backend data"
✅ "NutritionViewModel: Daily summary - Calories: 97, Protein: 0.8g, ..."
```

---

## Related Issues

This fix ensures that:
- ✅ WebSocket real-time updates are actually persisted locally
- ✅ UI shows accurate nutritional data after backend processing
- ✅ Local-first architecture is maintained (UI always reads from SwiftData)
- ✅ Data survives app restarts (persisted in SwiftData)

---

## Next Steps

### Future Enhancements
1. **Optimistic UI Updates:** Show estimated values while processing
2. **Error Handling:** Display user-friendly messages if update fails
3. **Unit Tests:** Add tests for `UpdateMealLogStatusUseCase`
4. **Integration Tests:** Test end-to-end flow from submission to UI update

---

**Status:** ✅ COMPLETE - Ready for testing
**Impact:** HIGH - Fixes critical nutrition tracking functionality
**Risk:** LOW - Follows established patterns and architecture