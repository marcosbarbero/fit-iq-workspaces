# Food Type - iOS Quick Start Guide

**TL;DR:** Meal log items now have a `foodType` field (`.food`, `.drink`, `.water`) for better tracking and insights.

---

## 🚀 Quick Start

### 1. Using the FoodType Enum

```swift
import Foundation

// Available food types
let foodType: FoodType = .food   // Solid foods
let foodType: FoodType = .drink  // Caloric beverages
let foodType: FoodType = .water  // Water/zero-cal drinks

// Display properties
foodType.displayName  // "Food", "Beverage", "Water"
foodType.emoji        // "🍽️", "☕", "💧"
foodType.color        // "#4CAF50", "#FF9800", "#2196F3"
```

### 2. Creating a MealLogItem

```swift
let item = MealLogItem(
    id: UUID(),
    mealLogID: mealLogID,
    name: "Orange Juice",
    quantity: "250ml",
    calories: 110,
    protein: 1.7,
    carbs: 25.8,
    fat: 0.5,
    foodType: .drink  // ✅ NEW FIELD
)
```

### 3. Filtering Items by Type

```swift
let mealLog: MealLog = ...

// Get all solid food items
let foods = mealLog.foodItems

// Get all beverage items
let drinks = mealLog.drinkItems

// Get all water items
let water = mealLog.waterItems

// Or filter by specific type
let specificItems = mealLog.items(ofType: .drink)
```

### 4. Calculate Water Intake

```swift
let mealLog: MealLog = ...

// Get estimated water intake in milliliters
let waterMl = mealLog.estimatedWaterIntakeMl
print("Water intake: \(Int(waterMl))ml")
```

### 5. Track Beverage Calories

```swift
let mealLog: MealLog = ...

// Get calories from beverages only
let beverageCals = mealLog.beverageCalories

// Get percentage of total calories from beverages
let percentage = mealLog.beverageCaloriePercentage

if percentage > 30 {
    print("⚠️ High beverage calories: \(Int(percentage))%")
}
```

---

## 📊 Common Use Cases

### Display Food Type Badge

```swift
struct FoodTypeBadge: View {
    let foodType: FoodType
    
    var body: some View {
        HStack(spacing: 4) {
            Text(foodType.emoji)
            Text(foodType.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: foodType.color).opacity(0.2))
        .cornerRadius(8)
    }
}

// Usage
FoodTypeBadge(foodType: item.foodType)
```

### Water Intake Summary

```swift
func calculateDailyWaterIntake(mealLogs: [MealLog]) -> Double {
    mealLogs.reduce(0) { total, mealLog in
        total + mealLog.estimatedWaterIntakeMl
    }
}

// Usage
let waterGoal: Double = 3000 // ml
let intake = calculateDailyWaterIntake(mealLogs: todaysMeals)
let progress = intake / waterGoal

print("Water: \(Int(intake))ml / \(Int(waterGoal))ml (\(Int(progress * 100))%)")
```

### Beverage Insights

```swift
func getBeverageInsight(mealLog: MealLog) -> String? {
    let percentage = mealLog.beverageCaloriePercentage
    
    if percentage > 40 {
        return "⚠️ Very high beverage calories (\(Int(percentage))%)"
    } else if percentage > 25 {
        return "💡 Moderate beverage calories (\(Int(percentage))%)"
    } else {
        return nil
    }
}
```

---

## 🔧 Working with SwiftData

### Saving Items with Food Type

```swift
// The repository automatically handles foodType conversion
let item = MealLogItem(
    // ... fields ...
    foodType: .drink
)

// Save (foodType is automatically converted to string for storage)
try await repository.save(mealLog: mealLog, forUserID: userID)
```

### Fetching and Converting

```swift
// Fetch from repository
let mealLogs = try await repository.fetchLocal(
    forUserID: userID,
    status: .completed,
    syncStatus: nil,
    startDate: nil,
    endDate: nil,
    limit: 50
)

// Items automatically have foodType populated
mealLogs.forEach { mealLog in
    mealLog.items.forEach { item in
        print("\(item.name): \(item.foodType.displayName)")
    }
}
```

---

## 📱 WebSocket Integration

### Receiving Food Type from Backend

```swift
// WebSocket payload automatically includes foodType
func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
    let domainItems = payload.items.map { item in
        MealLogItem(
            // ... other fields ...
            foodType: FoodType(rawValue: item.foodType) ?? .food,
            // ... rest of fields ...
        )
    }
    
    // Update local storage with items including foodType
    try await updateMealLogStatus(items: domainItems)
}
```

---

## ✅ Best Practices

### DO:

```swift
// ✅ Use the enum, not strings
let foodType: FoodType = .drink

// ✅ Provide default when parsing external data
let foodType = FoodType(rawValue: jsonString) ?? .food

// ✅ Use helper methods for filtering
let waterItems = mealLog.waterItems

// ✅ Handle missing data gracefully
let intake = mealLog.estimatedWaterIntakeMl // Returns 0 if no water items
```

### DON'T:

```swift
// ❌ Don't use raw strings
let foodType = "drink" // Wrong! Use .drink

// ❌ Don't assume all items are food
let allFood = mealLog.items // Some might be drinks/water

// ❌ Don't hardcode detection logic
if item.name.contains("water") { ... } // Wrong! Use item.foodType

// ❌ Don't ignore the foodType when creating items
MealLogItem(...) // Missing foodType parameter
```

---

## 🎨 UI Examples

### Meal Log Item Row

```swift
struct MealLogItemRow: View {
    let item: MealLogItem
    
    var body: some View {
        HStack {
            // Food type indicator
            Circle()
                .fill(Color(hex: item.foodType.color))
                .frame(width: 8, height: 8)
            
            Text(item.foodType.emoji)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.body)
                Text(item.quantity)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(item.calories)) cal")
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
```

### Simple Water Progress

```swift
struct WaterProgressView: View {
    let currentMl: Double
    let goalMl: Double = 3000
    
    var progress: Double {
        min(currentMl / goalMl, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("💧 Water")
                    .font(.headline)
                Spacer()
                Text("\(Int(currentMl))ml / \(Int(goalMl))ml")
                    .font(.caption)
            }
            
            ProgressView(value: progress)
                .tint(.blue)
        }
    }
}
```

---

## 🧪 Testing

### Unit Test Example

```swift
func testWaterItemsFiltering() {
    // Arrange
    let mealLog = MealLog(
        // ... required fields ...
        items: [
            MealLogItem(name: "Chicken", foodType: .food, ...),
            MealLogItem(name: "Juice", foodType: .drink, ...),
            MealLogItem(name: "Water", foodType: .water, ...),
        ]
    )
    
    // Act
    let waterItems = mealLog.waterItems
    
    // Assert
    XCTAssertEqual(waterItems.count, 1)
    XCTAssertEqual(waterItems.first?.name, "Water")
}

func testBeverageCalorieCalculation() {
    // Arrange
    let mealLog = MealLog(
        items: [
            MealLogItem(calories: 200, foodType: .food, ...),
            MealLogItem(calories: 100, foodType: .drink, ...),
            MealLogItem(calories: 0, foodType: .water, ...),
        ]
    )
    
    // Act
    let beverageCals = mealLog.beverageCalories
    
    // Assert
    XCTAssertEqual(beverageCals, 100)
}
```

---

## 📋 Quick Reference Table

| Property | Type | Example | Description |
|----------|------|---------|-------------|
| `foodType` | `FoodType` | `.food` | Item classification |
| `displayName` | `String` | "Food" | Human-readable name |
| `emoji` | `String` | "🍽️" | Display emoji |
| `color` | `String` | "#4CAF50" | Hex color code |

| Helper Method | Returns | Description |
|---------------|---------|-------------|
| `mealLog.foodItems` | `[MealLogItem]` | All solid food items |
| `mealLog.drinkItems` | `[MealLogItem]` | All beverage items |
| `mealLog.waterItems` | `[MealLogItem]` | All water items |
| `mealLog.estimatedWaterIntakeMl` | `Double` | Total water in ml |
| `mealLog.beverageCalories` | `Double` | Calories from drinks |
| `mealLog.beverageCaloriePercentage` | `Double` | % of cals from drinks |

---

## 🔗 More Resources

- **Full Implementation Guide:** `docs/nutrition/FOOD_TYPE_IOS_IMPLEMENTATION.md`
- **Backend API Docs:** `docs/nutrition/food-type/FOOD_TYPE_API_DOCUMENTATION.MD`
- **Migration Guide:** `docs/nutrition/food-type/FOOD_TYPE_MIGRATION_GUIDE.md`

---

**Last Updated:** 2025-01-28  
**Status:** ✅ Ready to Use