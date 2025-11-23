# Water Intake Tracking - Quick Reference

**Version:** 1.0.0  
**Last Updated:** 2025-01-27

---

## Overview

Automatic water intake tracking that detects water items from meal logs and syncs to backend.

---

## Key Components

### Use Case
```swift
// FitIQ/Domain/UseCases/SaveWaterProgressUseCase.swift
protocol SaveWaterProgressUseCase {
    func execute(liters: Double, date: Date) async throws -> UUID
}
```

### ViewModel Properties
```swift
// FitIQ/Presentation/ViewModels/NutritionSummaryViewModel.swift
var waterIntakeLiters: Double = 0.0
var waterGoalLiters: Double = 2.5
var waterIntakeFormatted: String        // "2.3"
var waterGoalFormatted: String          // "2.5"
var waterIntakeProgress: Double         // 0.0-1.0
```

---

## How It Works

### Automatic Detection Flow

```
1. User logs: "2 bottles of water"
    ↓
2. Backend AI detects: 2x 500mL water items (food_type: water)
    ↓
3. WebSocket: meal_log.completed event
    ↓
4. NutritionViewModel.handleMealLogCompleted()
    ↓
5. trackWaterIntake() filters water items
    ↓
6. SaveWaterProgressUseCase.execute(liters: 1.0)
    ↓
7. ProgressRepository.save() (Outbox Pattern)
    ↓
8. Backend sync: POST /api/v1/progress
    ↓
9. UI updates: Water card shows "1.0 / 2.5 Liters"
```

---

## Usage Examples

### Save Water Intake
```swift
let localID = try await saveWaterProgressUseCase.execute(
    liters: 0.5,  // 500 mL
    date: Date()
)
```

### Display Water Data
```swift
// In SwiftUI View
Text("\(viewModel.waterIntakeFormatted) / \(viewModel.waterGoalFormatted) L")

// Progress bar
ProgressView(value: viewModel.waterIntakeProgress)
```

### Manual Water Tracking (Future)
```swift
// Quick add buttons
Button("+ 250mL") {
    Task {
        try await saveWaterProgressUseCase.execute(
            liters: 0.25,
            date: Date()
        )
    }
}
```

---

## Unit Conversion

### Supported Units

| Input | Conversion | Example |
|-------|-----------|---------|
| `mL` | ÷ 1000 | 500 mL → 0.5 L |
| `L` | Direct | 2 L → 2 L |
| `cup` | × 0.237 | 1 cup → 0.237 L |
| `oz` | × 0.0296 | 16 oz → 0.474 L |
| `glass` | × 0.25 | 2 glasses → 0.5 L |
| No unit | ÷ 1000 | 500 → 0.5 L |

### Parsing Logic
```swift
private func trackWaterIntake(from items: [MealLogItem], loggedAt: Date) async {
    let waterItems = items.filter { $0.foodType == .water }
    
    var totalLiters: Double = 0.0
    for item in waterItems {
        let quantity = item.quantity.lowercased()
        if let value = parseNumericValue(from: quantity) {
            totalLiters += convertToLiters(value, from: quantity)
        }
    }
    
    try await saveWaterProgressUseCase.execute(liters: totalLiters, date: loggedAt)
}
```

---

## Aggregation Behavior

### Daily Aggregation
Water intake **adds** to existing entries on the same day:

```swift
// 9:00 AM - Log 500 mL
try await saveWaterProgressUseCase.execute(liters: 0.5, date: Date())
// Entry: 0.5 L

// 2:00 PM - Log 300 mL
try await saveWaterProgressUseCase.execute(liters: 0.3, date: Date())
// Entry: 0.8 L (aggregated)
```

### Different Days
Water intake for different days creates separate entries:

```swift
// Today - Log 1.0 L
try await saveWaterProgressUseCase.execute(liters: 1.0, date: Date())

// Yesterday - Log 0.5 L
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
try await saveWaterProgressUseCase.execute(liters: 0.5, date: yesterday)

// Result: 2 separate entries
```

---

## Backend Integration

### API Endpoint
**POST** `/api/v1/progress`

### Request
```json
{
  "type": "water_liters",
  "quantity": 0.5,
  "logged_at": "2025-01-27T14:30:00Z",
  "notes": null
}
```

### Response
```json
{
  "success": true,
  "data": {
    "id": "uuid-12345",
    "user_id": "user-uuid",
    "type": "water_liters",
    "quantity": 0.5,
    "logged_at": "2025-01-27T14:30:00Z"
  }
}
```

---

## Outbox Pattern

### Reliable Sync Guarantee

```
SaveWaterProgressUseCase
    ↓
ProgressRepository.save()
    ↓
1. Save to SwiftData (SDProgressEntry)
2. Create Outbox event (SDOutboxEvent, status: .pending)
    ↓
OutboxProcessorService (background)
    ↓
POST /api/v1/progress
    ↓
Mark event as .completed
```

### Benefits
- ✅ Crash-resistant
- ✅ Offline-first
- ✅ Automatic retry
- ✅ No data loss

---

## Error Handling

### SaveWaterProgressError
```swift
enum SaveWaterProgressError: Error, LocalizedError {
    case invalidAmount         // Water ≤ 0
    case userNotAuthenticated  // No user logged in
}
```

### Graceful Degradation
```swift
// If water parsing fails
do {
    try await trackWaterIntake(from: items, loggedAt: date)
} catch {
    print("⚠️ Water tracking failed: \(error)")
    // Continue meal processing normally
}
```

---

## Testing

### Unit Test Example
```swift
func testSaveWaterProgress_ValidInput_Succeeds() async throws {
    // Arrange
    let useCase = SaveWaterProgressUseCaseImpl(
        progressRepository: mockRepository,
        authManager: mockAuthManager
    )
    
    // Act
    let localID = try await useCase.execute(liters: 0.5, date: Date())
    
    // Assert
    XCTAssertNotNil(localID)
    XCTAssertEqual(mockRepository.savedEntries.first?.quantity, 0.5)
    XCTAssertEqual(mockRepository.savedEntries.first?.type, .waterLiters)
}
```

### Integration Test Example
```swift
func testWaterIntakeFlow_EndToEnd() async throws {
    // 1. Log meal with water
    let payload = MealLogCompletedPayload(
        items: [
            MealLogItemPayload(
                foodName: "Water",
                quantity: 500,
                unit: "mL",
                foodType: "water"
            )
        ]
    )
    
    // 2. Trigger WebSocket handler
    await nutritionViewModel.handleMealLogCompleted(payload)
    
    // 3. Verify water saved
    let entries = try await progressRepository.fetchLocal(
        forUserID: userID,
        type: .waterLiters,
        syncStatus: nil,
        limit: 10
    )
    
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.quantity, 0.5)
}
```

---

## Debugging

### Check Water Entries
```swift
let waterEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .waterLiters,
    syncStatus: nil,
    limit: 100
)

print("Water entries: \(waterEntries.count)")
for entry in waterEntries {
    print("- \(entry.date): \(entry.quantity)L (status: \(entry.syncStatus))")
}
```

### Check Outbox Events
```swift
let outboxEvents = try await outboxRepository.fetchPendingEvents(
    forUserID: userUUID,
    eventType: .progressCreated,
    limit: 50
)

print("Pending progress events: \(outboxEvents.count)")
```

### Verify Meal Items
```swift
let meals = try await getMealLogsUseCase.execute(
    startDate: Date(),
    endDate: Date(),
    useLocalOnly: true
)

for meal in meals {
    print("Meal: \(meal.rawInput)")
    for item in meal.items {
        print("  - \(item.name): \(item.quantity) (type: \(item.foodType))")
    }
}
```

---

## Common Issues

### Issue: Water not tracked
**Check:**
1. Backend classified item as `food_type: water`?
2. WebSocket event received?
3. Quantity parsing successful?

**Debug:**
```swift
// Add logging in trackWaterIntake()
print("💧 Water items found: \(waterItems.count)")
for item in waterItems {
    print("  - \(item.name): \(item.quantity)")
}
```

### Issue: Duplicate water entries
**Cause:** Multiple WebSocket events or API calls

**Solution:**
- Use case already handles deduplication by date
- Aggregates instead of duplicates

---

## Future Enhancements

### Phase 2
- [ ] Water goal customization UI
- [ ] Sync goal to backend user preferences
- [ ] Quick-add buttons (250mL, 500mL, 1L)

### Phase 3
- [ ] Water detail view with charts
- [ ] Hourly breakdown
- [ ] Weekly/monthly trends
- [ ] Hydration streaks

### Phase 4
- [ ] HealthKit integration
- [ ] Hydration reminders
- [ ] AI insights
- [ ] Goal suggestions based on weight/activity

---

## Quick Commands

### Add New Water Goal Property
```swift
// 1. Add to SDUserProfile
@Attribute var waterGoalLiters: Double = 2.5

// 2. Update NutritionSummaryViewModel
func loadWaterGoal() async {
    self.waterGoalLiters = userProfile.waterGoalLiters
}

// 3. Add settings UI
Slider(value: $waterGoalLiters, in: 0.5...5.0, step: 0.1)
```

### Add Quick-Add Button
```swift
Button("+ 250mL") {
    Task {
        try await saveWaterProgressUseCase.execute(
            liters: 0.25,
            date: Date()
        )
        // Refresh UI
        await nutritionSummaryViewModel.loadWaterIntake()
    }
}
```

---

## Resources

- **Full Documentation:** `docs/features/WATER_INTAKE_TRACKING.md`
- **Implementation Summary:** `docs/features/WATER_INTAKE_IMPLEMENTATION_SUMMARY.md`
- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Outbox Pattern:** `docs/architecture/OUTBOX_PATTERN.md`

---

**Status:** ✅ Production Ready (v1.0)  
**Last Updated:** 2025-01-27  
**Maintainer:** AI Assistant