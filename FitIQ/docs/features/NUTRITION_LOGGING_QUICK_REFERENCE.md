# Nutrition Logging - Quick Reference Guide

**Version:** 1.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Ready for Use

---

## 🚀 Quick Start

### How to Use in ViewModels

```swift
// 1. Inject use cases via AppDependencies
let saveMealLogUseCase: SaveMealLogUseCase
let getMealLogsUseCase: GetMealLogsUseCase

// 2. Save a meal log
let localID = try await saveMealLogUseCase.execute(
    rawInput: "2 eggs, toast, coffee",
    mealType: "breakfast",
    loggedAt: Date(),
    notes: nil
)

// 3. Fetch meal logs
let mealLogs = try await getMealLogsUseCase.execute(
    status: nil,           // Filter by status (optional)
    syncStatus: nil,       // Filter by sync status (optional)
    mealType: nil,         // Filter by meal type (optional)
    startDate: nil,        // Filter by date range (optional)
    endDate: nil,          // Filter by date range (optional)
    limit: nil,            // Limit results (optional)
    useLocalOnly: false    // Offline mode (default: false)
)
```

---

## 📦 What's Available

### Use Cases

| Use Case | Purpose | Method |
|----------|---------|--------|
| `SaveMealLogUseCase` | Save meal log locally + sync to backend | `execute(rawInput:mealType:loggedAt:notes:)` |
| `GetMealLogsUseCase` | Fetch meal logs with filtering | `execute(status:syncStatus:mealType:startDate:endDate:limit:useLocalOnly:)` |

### Repositories

| Repository | Type | Purpose |
|------------|------|---------|
| `mealLogLocalRepository` | `MealLogLocalStorageProtocol` | Local SwiftData operations |
| `nutritionAPIClient` | `MealLogRemoteAPIProtocol` | Backend API operations |
| `mealLogRepository` | `MealLogRepositoryProtocol` | Combined (local + remote) |

**⚠️ IMPORTANT:** Always use `mealLogRepository` (composite) or use cases. Never access local/remote directly.

---

## 🎯 Common Use Cases

### 1. Save a Meal Log

```swift
@MainActor
func saveMeal() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        let localID = try await saveMealLogUseCase.execute(
            rawInput: userInput,
            mealType: selectedMealType,
            loggedAt: Date(),
            notes: userNotes.isEmpty ? nil : userNotes
        )
        print("Meal log saved: \(localID)")
        
        // Refresh list to show new entry
        await fetchMealLogs()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 2. Fetch Today's Meals

```swift
@MainActor
func fetchTodaysMeals() async {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    
    do {
        mealLogs = try await getMealLogsUseCase.execute(
            status: .completed,     // Only show processed meals
            syncStatus: nil,
            mealType: nil,
            startDate: startOfDay,
            endDate: endOfDay,
            limit: nil,
            useLocalOnly: false
        )
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 3. Fetch by Meal Type

```swift
@MainActor
func fetchBreakfastMeals() async {
    do {
        mealLogs = try await getMealLogsUseCase.execute(
            status: nil,
            syncStatus: nil,
            mealType: "breakfast",
            startDate: nil,
            endDate: nil,
            limit: 20,
            useLocalOnly: false
        )
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 4. Offline Mode

```swift
@MainActor
func fetchMealsOffline() async {
    do {
        // Only fetch from local storage (no network call)
        mealLogs = try await getMealLogsUseCase.execute(
            status: nil,
            syncStatus: nil,
            mealType: nil,
            startDate: nil,
            endDate: nil,
            limit: nil,
            useLocalOnly: true  // ✅ Offline mode
        )
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

---

## 📊 Domain Models

### MealLog

```swift
struct MealLog {
    let id: UUID                      // Local ID
    let userID: String                // User profile ID
    let rawInput: String              // "2 eggs, toast, coffee"
    let mealType: String              // "breakfast", "lunch", "dinner", "snack"
    let status: MealLogStatus         // .pending, .processing, .completed, .failed
    let loggedAt: Date                // When meal was consumed
    let items: [MealLogItem]          // Parsed food items (empty until processed)
    let notes: String?                // Optional user notes
    let createdAt: Date               // When entry was created
    let updatedAt: Date?              // Last update timestamp
    let backendID: String?            // Server-assigned ID (nil until synced)
    let syncStatus: SyncStatus        // .pending, .synced, .failed
    let errorMessage: String?         // Error message if processing failed
    
    // Computed properties
    var totalCalories: Double         // Sum of all items
    var totalProteinG: Double         // Sum of protein
    var totalCarbsG: Double           // Sum of carbs
    var totalFatG: Double             // Sum of fat
}
```

### MealLogItem

```swift
struct MealLogItem {
    let id: UUID                      // Item ID
    let foodName: String              // "Egg", "Toast", etc.
    let quantity: Double              // 2.0
    let unit: String                  // "large", "slice", etc.
    let calories: Double              // 140.0
    let proteinG: Double              // 12.6
    let carbsG: Double                // 0.8
    let fatG: Double                  // 9.5
}
```

### MealLogStatus (Processing Status)

```swift
enum MealLogStatus: String {
    case pending      // Waiting to be sent to backend
    case processing   // Backend is parsing the meal
    case completed    // Successfully parsed
    case failed       // Parsing failed
}
```

### SyncStatus (Local Sync Status)

```swift
enum SyncStatus: String {
    case pending      // Waiting for Outbox sync
    case synced       // Successfully synced to backend
    case failed       // Sync failed (will retry)
}
```

---

## 🔄 Meal Logging Flow

```
┌─────────────────────────────────────────────────┐
│ 1. User enters: "2 eggs, toast, coffee"        │
│    Meal type: breakfast                         │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 2. SaveMealLogUseCase.execute()                │
│    - Creates MealLog (status: .pending)         │
│    - Saves to SwiftData via repository          │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 3. SwiftDataMealLogRepository.save()           │
│    - Inserts SDMealLog                          │
│    - Creates SDOutboxEvent (automatic)          │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 4. OutboxProcessorService (background)         │
│    - Polls for pending events                   │
│    - Calls NutritionAPIClient.submitMealLog()   │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 5. POST /api/v1/meal-logs/natural              │
│    - Backend receives meal log                  │
│    - Returns: { id, status: "processing" }      │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 6. Backend Processing (async)                  │
│    - AI parses "2 eggs, toast, coffee"          │
│    - Creates food items with nutrition data     │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 7. WebSocket Notification (optional)           │
│    - Sends: meal_log.completed event            │
│    - Includes parsed items and totals           │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ 8. Local Update                                 │
│    - Status: .pending → .completed              │
│    - Items populated with nutrition data        │
│    - UI refreshes automatically                 │
└─────────────────────────────────────────────────┘
```

---

## 🎨 Example ViewModel

```swift
import Foundation
import Observation

@Observable
final class NutritionViewModel {
    // MARK: - State
    var mealLogs: [MealLog] = []
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    private let saveMealLogUseCase: SaveMealLogUseCase
    private let getMealLogsUseCase: GetMealLogsUseCase
    
    // MARK: - Init
    init(
        saveMealLogUseCase: SaveMealLogUseCase,
        getMealLogsUseCase: GetMealLogsUseCase
    ) {
        self.saveMealLogUseCase = saveMealLogUseCase
        self.getMealLogsUseCase = getMealLogsUseCase
    }
    
    // MARK: - Actions
    @MainActor
    func saveMealLog(
        rawInput: String,
        mealType: String,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await saveMealLogUseCase.execute(
                rawInput: rawInput,
                mealType: mealType,
                loggedAt: loggedAt,
                notes: notes
            )
            await fetchMealLogs()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func fetchMealLogs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            mealLogs = try await getMealLogsUseCase.execute(
                status: nil,
                syncStatus: nil,
                mealType: nil,
                startDate: nil,
                endDate: nil,
                limit: nil,
                useLocalOnly: false
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

---

## 🔌 Accessing Dependencies

### From AppDependencies

```swift
// In your app or view
@EnvironmentObject var appDependencies: AppDependencies

// Access use cases
appDependencies.saveMealLogUseCase
appDependencies.getMealLogsUseCase

// Access repositories (if needed)
appDependencies.mealLogRepository
appDependencies.mealLogLocalRepository
appDependencies.nutritionAPIClient
```

### Creating ViewModel

```swift
// Example: In ContentView or parent view
let nutritionViewModel = NutritionViewModel(
    saveMealLogUseCase: appDependencies.saveMealLogUseCase,
    getMealLogsUseCase: appDependencies.getMealLogsUseCase
)
```

---

## 🚨 Common Errors

### SaveMealLogError

```swift
enum SaveMealLogError: Error {
    case emptyInput              // Meal description is empty
    case invalidMealType         // Invalid meal type
    case userNotAuthenticated    // User not logged in
}
```

**Handling:**
```swift
do {
    try await saveMealLogUseCase.execute(...)
} catch SaveMealLogError.emptyInput {
    print("Please enter a meal description")
} catch SaveMealLogError.invalidMealType {
    print("Please select a valid meal type")
} catch SaveMealLogError.userNotAuthenticated {
    print("Please log in first")
}
```

### GetMealLogsError

```swift
enum GetMealLogsError: Error {
    case userNotAuthenticated    // User not logged in
}
```

---

## 🧪 Testing Examples

### Unit Test: Save Meal Log

```swift
func testSaveMealLog() async throws {
    // Arrange
    let mockRepo = MockMealLogRepository()
    let mockAuthManager = MockAuthManager()
    mockAuthManager.currentUserProfileID = UUID()
    
    let useCase = SaveMealLogUseCaseImpl(
        mealLogRepository: mockRepo,
        authManager: mockAuthManager
    )
    
    // Act
    let localID = try await useCase.execute(
        rawInput: "Chicken salad",
        mealType: "lunch",
        loggedAt: Date(),
        notes: nil
    )
    
    // Assert
    XCTAssertEqual(mockRepo.saveCallCount, 1)
    XCTAssertNotNil(localID)
}
```

### Integration Test: End-to-End

```swift
func testMealLogFlow() async throws {
    // Arrange
    let appDeps = AppDependencies.build(authManager: authManager)
    
    // Act: Save meal log
    let localID = try await appDeps.saveMealLogUseCase.execute(
        rawInput: "2 eggs, toast",
        mealType: "breakfast",
        loggedAt: Date(),
        notes: nil
    )
    
    // Act: Fetch meal logs
    let mealLogs = try await appDeps.getMealLogsUseCase.execute(
        status: nil,
        syncStatus: nil,
        mealType: nil,
        startDate: nil,
        endDate: nil,
        limit: nil,
        useLocalOnly: true
    )
    
    // Assert
    XCTAssertTrue(mealLogs.contains { $0.id == localID })
}
```

---

## 📝 Meal Type Values

Valid meal types:
- `"breakfast"`
- `"lunch"`
- `"dinner"`
- `"snack"`

---

## 🔄 Outbox Pattern Notes

### What Happens Automatically

✅ **When you save a meal log:**
1. Saved to SwiftData immediately
2. Outbox event created automatically
3. OutboxProcessorService syncs in background
4. Backend processes asynchronously
5. Local entry updated via WebSocket (optional)

✅ **If app crashes:**
- Meal log survives (already in SwiftData)
- Outbox event survives
- Sync resumes on next app launch

✅ **If network is offline:**
- Meal log saved locally
- Outbox event marked as pending
- Sync happens when network returns

### What You DON'T Need to Do

❌ Manual Outbox event creation  
❌ Manual sync triggers  
❌ Manual retry logic  
❌ Manual crash recovery  

**Just call the use case and trust the pattern!**

---

## 🎯 Best Practices

### Do's ✅

1. ✅ Always use `SaveMealLogUseCase` to save meal logs
2. ✅ Always use `GetMealLogsUseCase` to fetch meal logs
3. ✅ Handle loading and error states in ViewModels
4. ✅ Test offline mode thoroughly
5. ✅ Validate user input before calling use cases
6. ✅ Show user feedback for pending/processing states

### Don'ts ❌

1. ❌ Never bypass use cases to access repositories directly
2. ❌ Never manually create Outbox events
3. ❌ Never modify SwiftData models directly
4. ❌ Never skip error handling
5. ❌ Never assume network is always available
6. ❌ Never hardcode meal types (use constants)

---

## 📚 Related Documentation

- **Full Implementation Details:** `NUTRITION_LOGGING_COMPLETION_SUMMARY.md`
- **Handoff Document:** `NUTRITION_LOGGING_HANDOFF.md`
- **API Specification:** `docs/be-api-spec/swagger.yaml`
- **Architecture Patterns:** `docs/architecture/SWIFTDATA_RELATIONSHIP_PATTERNS.md`
- **Outbox Pattern:** `.github/copilot-instructions.md` (search "Outbox Pattern")

---

## 🆘 Need Help?

### Check These First

1. **Compilation errors?** Run `diagnostics` to see errors
2. **Outbox not syncing?** Check `OutboxProcessorService` logs
3. **Network errors?** Verify API key in `config.plist`
4. **Auth errors?** Ensure user is logged in (`authManager.currentUserProfileID`)

### Common Issues

| Issue | Solution |
|-------|----------|
| "User not authenticated" | Call `saveMealLogUseCase` after user logs in |
| "Empty input" | Validate `rawInput` is not empty before calling |
| Meal not syncing | Check network, verify Outbox events created |
| Items not populated | Wait for backend processing (async) |

---

**Quick Reference Version:** 1.0  
**Last Updated:** 2025-01-27  
**Ready to Use:** ✅ YES