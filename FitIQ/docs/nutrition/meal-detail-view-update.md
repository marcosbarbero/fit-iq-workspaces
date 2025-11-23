# MealDetailView Data Model Update

**Date:** 2025-01-27  
**Status:** ✅ Complete  
**Related:** Nutrition Logging & Food Type Feature

---

## Overview

Updated `MealDetailView` and `DailyMealLog` to correctly use the nutrition data model structure with proper field naming and support for displaying individual meal items with food type classification.

---

## Changes Made

### 1. DailyMealLog Data Model (`NutritionViewModel.swift`)

**Before:**
```swift
struct DailyMealLog: Identifiable {
    let id: UUID
    let name: String  // ❌ Misleading - this is raw input, not a meal name
    let time: Date
    let calories: Int
    // ... other fields
}
```

**After:**
```swift
struct DailyMealLog: Identifiable {
    let id: UUID
    let description: String  // ✅ Natural language description (raw input)
    let time: Date
    let calories: Int
    // ... other fields
    
    // ✅ Added: Array of parsed food items
    let items: [MealLogItem]
}
```

**Key Changes:**
- ✅ Renamed `name` → `description` (more accurate - it's the user's natural language input)
- ✅ Added `items: [MealLogItem]` array to match backend response structure
- ✅ Updated `from(mealLog:)` mapper to include `items: mealLog.items`

---

### 2. MealDetailView UI (`MealDetailView.swift`)

**Before:**
- Used `meal.name` to extract meal type and description via string splitting
- No display of individual meal items
- No food type indicators

**After:**
- Uses `meal.description` for natural language display
- Uses `meal.mealType.displayName` for navigation title
- **New:** Displays individual meal items with:
  - Food type emoji indicator (🍽️ food, ☕ drink, 💧 water)
  - Item name and quantity
  - Per-item macros (P/C/F breakdown)
  - Confidence score badge (if available)

**New Components:**

#### MealItemRow
Displays individual food items from the meal with:
- Food type emoji (from `FoodType.emoji`)
- Item name and quantity
- Calories and macros
- AI confidence score (when available)

#### MacroLabel
Reusable macro display component showing label + value with color coding.

#### ConfidenceBadge
Visual indicator of AI parsing confidence:
- 🟢 Green: 90%+ confident
- 🟠 Orange: 70-89% confident
- 🔴 Red: <70% confident

---

### 3. NutritionView Updates (`NutritionView.swift`)

**MealRowCard Component:**
- Updated to use `meal.description` instead of `meal.name`

---

## Food Type Classification

### Domain Model (`FoodType` enum)
```swift
public enum FoodType: String, Codable, CaseIterable {
    case food = "food"   // Solid foods
    case drink = "drink" // Caloric beverages
    case water = "water" // Water/zero-cal drinks
    
    public var emoji: String {
        case .food: return "🍽️"
        case .drink: return "☕"
        case .water: return "💧"
    }
}
```

### SwiftData Model (`SDMealLogItem`)
```swift
@Model final class SDMealLogItem {
    var foodType: String = "food"  // ✅ String for SwiftData compatibility
    // ... other fields
}
```

**Why String in SwiftData?**
- SwiftData requires RawRepresentable types with basic storage
- Conversion happens in `PersistenceHelper.swift`:
  ```swift
  extension SDMealLogItem {
      func toDomain() -> MealLogItem {
          MealLogItem(
              // ...
              foodType: FoodType(rawValue: self.foodType) ?? .food,
              // ...
          )
      }
  }
  ```

---

## Backend Integration

### Response Structure
```json
{
  "id": "uuid",
  "rawInput": "scrambled eggs and toast",
  "mealType": "breakfast",
  "items": [
    {
      "id": "uuid",
      "name": "Scrambled Eggs",
      "quantity": "2 eggs",
      "calories": 180,
      "protein": 12.0,
      "carbs": 2.0,
      "fat": 14.0,
      "foodType": "food",
      "confidence": 0.95
    },
    {
      "id": "uuid",
      "name": "Whole Wheat Toast",
      "quantity": "2 slices",
      "calories": 160,
      "protein": 8.0,
      "carbs": 30.0,
      "fat": 2.0,
      "foodType": "food",
      "confidence": 0.92
    }
  ]
}
```

---

## User Experience Improvements

### Before
- Single meal card with aggregated totals
- No breakdown of individual items
- Meal type extracted via string parsing (fragile)

### After
- **Aggregated View:** Total calories and macros at top
- **Item Breakdown:** See each food item with:
  - Visual food type indicator
  - Individual nutritional values
  - AI confidence score
- **Better Context:** Users understand what the AI parsed from their input
- **Water Tracking:** Visual distinction for water/beverages vs. solid food

---

## Files Modified

1. ✅ `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`
   - Updated `DailyMealLog` struct
   - Renamed `name` → `description`
   - Added `items` array

2. ✅ `FitIQ/Presentation/UI/Nutrition/MealDetailView.swift`
   - Removed string parsing for meal type
   - Added `MealItemRow` component
   - Added `MacroLabel` component
   - Added `ConfidenceBadge` component
   - Display individual meal items

3. ✅ `FitIQ/Presentation/UI/Nutrition/NutritionView.swift`
   - Updated `MealRowCard` to use `meal.description`

---

## Architecture Compliance

✅ **Hexagonal Architecture:**
- Domain model (`MealLogItem`, `FoodType`) defines structure
- SwiftData uses raw values (`String`)
- Conversion in infrastructure layer (`PersistenceHelper`)
- Presentation layer uses domain models

✅ **No Breaking Changes:**
- Backend API already provides `items` array
- Existing meals without items show empty list (graceful degradation)

✅ **Type Safety:**
- `FoodType` enum prevents invalid values
- Compile-time checks for all food type operations

---

## Testing Recommendations

### Unit Tests
- [ ] Test `DailyMealLog.from(mealLog:)` mapper with items
- [ ] Test empty items array handling
- [ ] Test food type enum conversion

### UI Tests
- [ ] Verify meal items display correctly
- [ ] Test food type emoji indicators
- [ ] Verify confidence badge colors
- [ ] Test empty items state

### Integration Tests
- [ ] Verify WebSocket payload mapping includes items
- [ ] Test meal detail navigation with items
- [ ] Verify macro calculations match item totals

---

## Future Enhancements

### Water Intake Tracking
With `foodType` classification, we can now:
- Track daily water intake (sum of `water` type items)
- Show hydration goals/progress
- Separate beverage calories from food calories

### Beverage Insights
- Filter meals by food type
- Show caloric beverage consumption trends
- Recommend water alternatives for high-calorie drinks

### AI Confidence Improvements
- Allow users to edit low-confidence items
- Provide feedback to improve parsing
- Show parsing notes for transparency

---

## Related Documentation

- **Backend API:** `docs/be-api-spec/swagger.yaml` → `/api/v1/nutrition/meals`
- **Food Type Feature:** Thread context (Nutrition Logging Data Model Update)
- **Domain Models:** `FitIQ/Domain/Entities/Nutrition/MealLogEntities.swift`
- **Schema V7:** `FitIQ/Infrastructure/Persistence/Schema/SchemaV7.swift`

---

**Status:** ✅ All changes complete and compiling successfully