# Water Intake Tracking

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Implemented

---

## Overview

The water intake tracking feature automatically monitors water consumption by detecting water items from meal logging and syncing them to the backend via the `/api/v1/progress` API. This enables hydration goal tracking and insights.

---

## Architecture

### Hexagonal Architecture Pattern

```
User logs meal with water
    ↓
MealLogWebSocketService receives completed event
    ↓
NutritionViewModel.handleMealLogCompleted()
    ↓
NutritionViewModel.trackWaterIntake() (filters water items)
    ↓
SaveWaterProgressUseCase.execute()
    ↓
ProgressRepository.save() (Outbox Pattern)
    ↓
Backend /api/v1/progress API
```

---

## Components

### 1. Domain Layer

#### Use Case: `SaveWaterProgressUseCase`

**Location:** `FitIQ/Domain/UseCases/SaveWaterProgressUseCase.swift`

**Purpose:** Saves water intake to local storage and triggers backend sync via Outbox Pattern.

**Key Features:**
- ✅ Validates water amount (must be > 0)
- ✅ Aggregates water intake for same day (adds to existing entry)
- ✅ Uses Outbox Pattern for reliable sync
- ✅ Handles duplicate detection
- ✅ Updates existing entries with new totals

**Example:**
```swift
let localID = try await saveWaterProgressUseCase.execute(
    liters: 0.5,  // 500 mL
    date: Date()
)
```

**Aggregation Behavior:**
- If entry exists for same day: **adds** to existing quantity
- If entry doesn't exist: **creates** new entry
- Example: Log 0.5L, then log 0.3L → Total becomes 0.8L

#### Entity: `ProgressMetricType.waterLiters`

**Location:** `FitIQ/Domain/Entities/Progress/ProgressMetricType.swift`

**Purpose:** Enum case for water intake metric type.

```swift
case waterLiters = "water_liters"
```

#### Entity: `FoodType.water`

**Location:** `FitIQ/Domain/Entities/Nutrition/MealLogEntities.swift`

**Purpose:** Classifies meal items as water for automatic tracking.

```swift
case water = "water"  // Water or zero-calorie drinks
```

---

### 2. Presentation Layer

#### ViewModel: `NutritionSummaryViewModel`

**Location:** `FitIQ/Presentation/ViewModels/NutritionSummaryViewModel.swift`

**Properties:**
```swift
var waterIntakeLiters: Double = 0.0        // Current intake
var waterGoalLiters: Double = 2.5          // Daily goal (default 2.5L)
var waterIntakeFormatted: String           // "2.3"
var waterGoalFormatted: String             // "2.5"
var waterIntakeProgress: Double            // 0.0 to 1.0
```

**Usage:**
```swift
let viewModel = NutritionSummaryViewModel()
print("Water: \(viewModel.waterIntakeFormatted)L / \(viewModel.waterGoalFormatted)L")
print("Progress: \(Int(viewModel.waterIntakeProgress * 100))%")
```

#### ViewModel: `NutritionViewModel`

**Location:** `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`

**Water Tracking Method:**
```swift
private func trackWaterIntake(from items: [MealLogItem], loggedAt: Date) async
```

**Behavior:**
1. Filters meal items with `foodType == .water`
2. Parses quantity strings to extract numeric values
3. Converts units to liters (supports mL, L, cups, oz, glasses)
4. Aggregates total water intake
5. Calls `SaveWaterProgressUseCase` to sync to backend

**Supported Units:**
- `mL` or `milliliter` → Converts to liters (÷ 1000)
- `L` (but not `mL`) → Already in liters
- `cup` → 1 cup ≈ 0.237 L
- `oz` or `ounce` → 1 fl oz ≈ 0.0296 L
- `glass` → 1 glass ≈ 0.25 L (250 mL)
- **No unit:** Assumes mL and converts to liters

**Example:**
```swift
// Meal items from WebSocket
let items = [
    MealLogItem(name: "Water", quantity: "500 mL", foodType: .water, ...),
    MealLogItem(name: "Black Coffee", quantity: "1 cup", foodType: .water, ...)
]

// Automatically tracked:
// - 500 mL → 0.5 L
// - 1 cup → 0.237 L
// - Total: 0.737 L saved to progress API
```

#### View: `SummaryView` - Water Card

**Location:** `FitIQ/Presentation/UI/Summary/SummaryView.swift`

**Display:**
```swift
StatCard(
    currentValue: "\(nutritionViewModel.waterIntakeFormatted) / \(nutritionViewModel.waterGoalFormatted)",
    unit: "Liters",
    icon: "drop.fill",
    color: .vitalityTeal
)
```

**Example Display:**
- **Current:** `1.5 / 2.5 Liters`
- **Icon:** 💧 (drop.fill)
- **Color:** Teal

---

### 3. Infrastructure Layer

#### Repository: `ProgressRepositoryProtocol`

**Location:** `FitIQ/Domain/Ports/ProgressRepositoryProtocol.swift`

**Used By:** `SaveWaterProgressUseCase`

**Methods:**
```swift
func save(progressEntry: ProgressEntry, forUserID: String) async throws -> UUID
func fetchLocal(forUserID: String, type: ProgressMetricType?, syncStatus: SyncStatus?, limit: Int?) async throws -> [ProgressEntry]
```

**Automatic Behavior:**
- ✅ Saves to local SwiftData storage
- ✅ Creates Outbox event for backend sync
- ✅ Triggers `OutboxProcessorService` for immediate sync
- ✅ Retries failed syncs automatically

---

## Backend Integration

### API Endpoint

**POST** `/api/v1/progress`

**Request:**
```json
{
  "type": "water_liters",
  "quantity": 0.5,
  "logged_at": "2025-01-27T14:30:00Z",
  "notes": null
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid-12345",
    "user_id": "user-uuid",
    "type": "water_liters",
    "quantity": 0.5,
    "logged_at": "2025-01-27T14:30:00Z",
    "created_at": "2025-01-27T14:30:05Z"
  }
}
```

---

## Flow Diagram

### Complete Water Intake Flow

```
1. User logs meal: "2 bottles of water"
    ↓
2. Backend processes via AI: Detects 2x 500mL water items
    ↓
3. WebSocket sends meal_log.completed event
    {
      "items": [
        {
          "food_name": "Water",
          "quantity": 500,
          "unit": "mL",
          "food_type": "water",  ← CRITICAL
          ...
        },
        {
          "food_name": "Water",
          "quantity": 500,
          "unit": "mL",
          "food_type": "water",  ← CRITICAL
          ...
        }
      ]
    }
    ↓
4. NutritionViewModel.handleMealLogCompleted()
    - Updates local meal log with items
    - Calls trackWaterIntake(from: items)
    ↓
5. trackWaterIntake() filters water items:
    - Item 1: 500 mL → 0.5 L
    - Item 2: 500 mL → 0.5 L
    - Total: 1.0 L
    ↓
6. SaveWaterProgressUseCase.execute(liters: 1.0, date: Date())
    - Check for existing entry on same date
    - If exists: aggregate (add to existing)
    - If not: create new entry
    - syncStatus: .pending
    ↓
7. ProgressRepository.save()
    - Save to SwiftData (SDProgressEntry)
    - Create SDOutboxEvent (status: .pending)
    ↓
8. OutboxProcessorService (background)
    - Polls for pending events
    - POST /api/v1/progress (type: water_liters, quantity: 1.0)
    - Mark event as .completed
    ↓
9. Backend stores water intake
    ↓
10. User sees water intake in:
    - SummaryView Water Card: "1.0 / 2.5 Liters"
    - Progress charts (future)
    - Hydration insights (future)
```

---

## Dependency Injection

### `AppDependencies.swift`

**Property:**
```swift
let saveWaterProgressUseCase: SaveWaterProgressUseCase
```

**Initialization:**
```swift
let saveWaterProgressUseCase = SaveWaterProgressUseCaseImpl(
    progressRepository: progressRepository,
    authManager: authManager
)
```

**Usage in Init:**
```swift
init(
    // ... other params
    saveWaterProgressUseCase: SaveWaterProgressUseCase
) {
    self.saveWaterProgressUseCase = saveWaterProgressUseCase
}
```

### `ViewModelAppDependencies.swift`

**NutritionViewModel Injection:**
```swift
let nutritionViewModel = NutritionViewModel(
    saveMealLogUseCase: appDependencies.saveMealLogUseCase,
    getMealLogsUseCase: appDependencies.getMealLogsUseCase,
    updateMealLogStatusUseCase: appDependencies.updateMealLogStatusUseCase,
    syncPendingMealLogsUseCase: appDependencies.syncPendingMealLogsUseCase,
    deleteMealLogUseCase: appDependencies.deleteMealLogUseCase,
    webSocketService: appDependencies.mealLogWebSocketService,
    authManager: authManager,
    outboxProcessor: appDependencies.outboxProcessorService,
    saveWaterProgressUseCase: appDependencies.saveWaterProgressUseCase  // ← NEW
)
```

---

## Testing

### Unit Tests

#### SaveWaterProgressUseCase Tests

```swift
func testExecute_ValidInput_SavesWaterIntake() async throws {
    // Arrange
    let useCase = SaveWaterProgressUseCaseImpl(
        progressRepository: mockRepository,
        authManager: mockAuthManager
    )
    
    // Act
    let localID = try await useCase.execute(
        liters: 0.5,
        date: Date()
    )
    
    // Assert
    XCTAssertNotNil(localID)
    XCTAssertEqual(mockRepository.saveCallCount, 1)
    XCTAssertEqual(mockRepository.savedEntries.first?.type, .waterLiters)
    XCTAssertEqual(mockRepository.savedEntries.first?.quantity, 0.5)
}

func testExecute_SameDay_AggregatesQuantity() async throws {
    // Arrange
    let useCase = SaveWaterProgressUseCaseImpl(
        progressRepository: mockRepository,
        authManager: mockAuthManager
    )
    
    // Pre-populate with existing entry: 0.5L
    let existingEntry = ProgressEntry(
        id: UUID(),
        userID: "user-123",
        type: .waterLiters,
        quantity: 0.5,
        date: Date(),
        notes: nil,
        createdAt: Date(),
        backendID: nil,
        syncStatus: .synced
    )
    mockRepository.existingEntries = [existingEntry]
    
    // Act: Add another 0.3L
    let localID = try await useCase.execute(
        liters: 0.3,
        date: Date()
    )
    
    // Assert: Should aggregate to 0.8L
    XCTAssertEqual(mockRepository.savedEntries.last?.quantity, 0.8)
}
```

#### trackWaterIntake() Tests

```swift
func testTrackWaterIntake_WithWaterItems_SavesToProgress() async {
    // Arrange
    let items = [
        MealLogItem(
            name: "Water",
            quantity: "500 mL",
            foodType: .water,
            ...
        )
    ]
    
    // Act
    await viewModel.trackWaterIntake(from: items, loggedAt: Date())
    
    // Assert
    XCTAssertEqual(mockSaveWaterUseCase.executeCallCount, 1)
    XCTAssertEqual(mockSaveWaterUseCase.lastLitersValue, 0.5)
}

func testTrackWaterIntake_NoWaterItems_DoesNotSave() async {
    // Arrange
    let items = [
        MealLogItem(
            name: "Chicken",
            quantity: "100 g",
            foodType: .food,
            ...
        )
    ]
    
    // Act
    await viewModel.trackWaterIntake(from: items, loggedAt: Date())
    
    // Assert
    XCTAssertEqual(mockSaveWaterUseCase.executeCallCount, 0)
}
```

### Integration Tests

```swift
func testWaterIntakeFlow_EndToEnd() async throws {
    // 1. User logs meal with water
    let mealID = try await saveMealLogUseCase.execute(
        rawInput: "2 bottles of water",
        mealType: .snack,
        loggedAt: Date(),
        notes: nil
    )
    
    // 2. Wait for backend processing (mock WebSocket event)
    let payload = MealLogCompletedPayload(
        id: "backend-id",
        items: [
            MealLogItemPayload(
                foodName: "Water",
                quantity: 500,
                unit: "mL",
                foodType: "water",
                ...
            ),
            MealLogItemPayload(
                foodName: "Water",
                quantity: 500,
                unit: "mL",
                foodType: "water",
                ...
            )
        ],
        ...
    )
    
    // 3. Simulate WebSocket event
    await nutritionViewModel.handleMealLogCompleted(payload)
    
    // 4. Verify water intake saved to progress
    let waterEntries = try await progressRepository.fetchLocal(
        forUserID: userID,
        type: .waterLiters,
        syncStatus: nil,
        limit: 10
    )
    
    XCTAssertEqual(waterEntries.count, 1)
    XCTAssertEqual(waterEntries.first?.quantity, 1.0)  // 500mL + 500mL
}
```

---

## User Experience

### 1. Logging Water

**Method 1: Via Meal Logging**
```
User: "2 bottles of water"
Backend: Detects 2x 500mL water items (food_type: water)
iOS: Automatically tracks 1.0L water intake
```

**Method 2: Quick Log (Future)**
```
User: Taps Water Card → Quick add buttons (250mL, 500mL, 1L)
iOS: Directly saves to progress API
```

### 2. Viewing Water Intake

**SummaryView Water Card:**
- Current: `1.5 / 2.5 Liters`
- Visual: Progress ring/bar (future)
- Tap: Navigate to water detail view (future)

**Nutrition Tab (Future):**
- Daily water intake chart
- Weekly hydration trends
- Hourly water consumption breakdown

### 3. Setting Water Goal (Future Enhancement)

**Option 1: Nutrition Settings**
```
Nutrition Tab → Settings Icon → Daily Water Goal → Slider (0.5L - 5.0L)
```

**Option 2: Quick Goal Adjustment**
```
Tap Water Card → Edit Goal Button → Picker
```

---

## Error Handling

### SaveWaterProgressUseCase Errors

```swift
enum SaveWaterProgressError: Error, LocalizedError {
    case invalidAmount         // Water amount ≤ 0
    case userNotAuthenticated  // No authenticated user
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Water intake must be greater than zero"
        case .userNotAuthenticated:
            return "User must be authenticated to save water intake progress"
        }
    }
}
```

### Parsing Failures

**Scenario:** Cannot parse quantity from meal item

**Behavior:**
- Logs warning: `"⚠️ Could not parse water quantity from items"`
- Does NOT block meal processing
- User can manually add water intake later

**Example:**
```swift
// Item with unparseable quantity
MealLogItem(name: "Water", quantity: "some water", foodType: .water)

// Result: Logs warning, continues meal processing normally
```

---

## Future Enhancements

### 1. Water Goal Management

**Storage:**
- Add `waterGoalLiters` to `SDUserProfile`
- Sync to backend via user preferences API
- Default: 2.5L if not set

**UI:**
- Settings screen for customizing goal
- Suggested goals based on weight/activity level
- Quick adjust from Water Card

### 2. Water Detail View

**Features:**
- Daily water intake chart
- Hourly breakdown
- Weekly/monthly trends
- Hydration streaks
- Goal achievement badges

**Navigation:**
```swift
NavigationLink(value: "waterDetail") {
    StatCard(...)  // Water card in SummaryView
}
```

### 3. Hydration Insights

**AI-Powered Insights:**
- "You're 30% more hydrated this week! 💧"
- "Drinking water after workouts helps recovery"
- "Your best hydration streak: 7 days"

**Notifications:**
- Remind to drink water if intake is low
- Celebrate goal achievement
- Suggest water after meals/workouts

### 4. HealthKit Integration

**Write to HealthKit:**
```swift
// After saving to progress API
healthRepository.saveWaterIntake(
    liters: 0.5,
    date: Date()
)
```

**Read from HealthKit:**
- Import water intake from other apps
- Aggregate with FitIQ water logs
- Sync to backend

### 5. Smart Detection

**Improved AI Classification:**
- Better detection of hydrating foods (soup, fruit)
- Separate tracking for caloric vs. zero-cal drinks
- Caffeine tracking (dehydrating beverages)

---

## Troubleshooting

### Issue: Water not tracked after meal logging

**Possible Causes:**
1. Backend did not classify item as `food_type: water`
2. WebSocket event not received
3. Quantity parsing failed

**Debug Steps:**
```swift
// 1. Check meal log items in local storage
let meals = try await getMealLogsUseCase.execute(...)
print("Items: \(meals.first?.items.map { ($0.name, $0.foodType) })")

// 2. Check progress entries
let waterEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .waterLiters,
    syncStatus: nil,
    limit: 10
)
print("Water entries: \(waterEntries.count)")

// 3. Check Outbox events
let outboxEvents = try await outboxRepository.fetchPendingEvents(...)
print("Pending events: \(outboxEvents.count)")
```

### Issue: Water goal not updating

**Temporary Solution:**
- Goal is hardcoded to 2.5L in `NutritionSummaryViewModel`
- Manually change `waterGoalLiters` property

**Permanent Fix:**
- Implement user preferences storage (future)
- Sync goal to backend

---

## Summary

### ✅ What Works Now

- ✅ Automatic water detection from meal logs
- ✅ Unit conversion (mL, L, cups, oz, glasses)
- ✅ Outbox Pattern for reliable sync
- ✅ Backend integration via `/api/v1/progress`
- ✅ Water card display in SummaryView
- ✅ Daily aggregation (multiple water entries add up)

### 🔜 Coming Soon

- 🔜 Water goal customization
- 🔜 Water detail view with charts
- 🔜 Hydration insights
- 🔜 HealthKit integration
- 🔜 Quick add buttons (250mL, 500mL, 1L)
- 🔜 Notifications/reminders

### 📊 Metrics Tracked

| Metric | Type | Unit | API Endpoint |
|--------|------|------|-------------|
| Water Intake | `water_liters` | Liters | `/api/v1/progress` |

---

**Status:** ✅ Feature Complete (v1.0)  
**Next Steps:** User testing, goal customization, detail view  
**Maintainer:** AI Assistant  
**Last Updated:** 2025-01-27