# Food Type API Documentation - Frontend Integration Guide

**Version:** 1.0.0
**Date:** 2025-01-28
**API Version:** v1
**Status:** ✅ Available in Production

---

## 📋 Overview

The FitIQ meal logging API now includes a `food_type` field in the natural language parsing response. This field classifies each parsed food item into one of three categories:

- **`food`** - Solid foods (chicken, rice, vegetables, fruits, bread, etc.)
- **`drink`** - Beverages with calories/nutrients (juice, milk, soda, smoothies, coffee with milk/sugar)
- **`water`** - Plain water or zero-calorie beverages (water, sparkling water, unsweetened tea/coffee)

### 🎯 Use Cases

1. **Water Intake Tracking:** Automatically track water consumption toward daily hydration goals
2. **Beverage Calorie Awareness:** Show users how many calories come from drinks vs food
3. **Nutrition Insights:** Provide better dietary recommendations based on consumption patterns
4. **Progress Tracking:** Enable goal-based tracking (e.g., "Drink 3L water today")

---

## 🔄 API Changes

### Endpoint: `POST /api/v1/nutrition/parse`

**Request:** (No changes)
```json
{
  "raw_input": "grilled chicken 200g, orange juice 250ml, and 500ml water",
  "meal_type": "lunch",
  "timestamp": "2024-01-28T12:30:00Z"
}
```

**Response:** (NEW `food_type` field added to each item)
```json
{
  "success": true,
  "parsed_items": [
    {
      "id": "item-abc123",
      "name": "Grilled Chicken",
      "quantity": 200,
      "unit": "g",
      "category": "protein",
      "food_type": "food",
      "confidence": 92.5,
      "needs_review": false,
      "macronutrients": {
        "calories": 330,
        "protein": 62,
        "carbohydrates": 0,
        "fats": 7.4
      },
      "micronutrients": {
        "vitamin_b6": 1.2,
        "iron": 1.5
      }
    },
    {
      "id": "item-def456",
      "name": "Orange Juice",
      "quantity": 250,
      "unit": "ml",
      "category": "beverage",
      "food_type": "drink",
      "confidence": 95.0,
      "needs_review": false,
      "macronutrients": {
        "calories": 110,
        "protein": 1.7,
        "carbohydrates": 25.8,
        "fats": 0.5
      },
      "micronutrients": {
        "vitamin_c": 124
      }
    },
    {
      "id": "item-ghi789",
      "name": "Water",
      "quantity": 500,
      "unit": "ml",
      "category": "water",
      "food_type": "water",
      "confidence": 100.0,
      "needs_review": false,
      "macronutrients": {
        "calories": 0,
        "protein": 0,
        "carbohydrates": 0,
        "fats": 0
      }
    }
  ],
  "total_macros": {
    "total_calories": 440,
    "total_protein": 63.7,
    "total_carbohydrates": 25.8,
    "total_fats": 7.9
  },
  "confidence": 95.8,
  "needs_review": false,
  "food_log_id": "log-xyz789",
  "raw_input": "grilled chicken 200g, orange juice 250ml, and 500ml water",
  "detected_language": "en"
}
```

---

## 📊 Field Specification

### `food_type` Field

**Type:** `string`
**Required:** Yes (always present in response)
**Enum Values:**
- `"food"` - Solid foods
- `"drink"` - Caloric beverages
- `"water"` - Water or zero-calorie drinks

**Location:** Inside each `parsed_items[]` object

**Examples:**

| Item | Category | Food Type | Reason |
|------|----------|-----------|--------|
| Grilled Chicken | protein | `food` | Solid food |
| Brown Rice | grain | `food` | Solid food |
| Apple | fruit | `food` | Solid food |
| Caesar Salad | vegetable | `food` | Solid food |
| Orange Juice | beverage | `drink` | Has calories/nutrients |
| Milk | dairy | `drink` | Has calories/nutrients |
| Coca-Cola | beverage | `drink` | Has calories |
| Coffee with milk | beverage | `drink` | Has calories from milk |
| Water | water | `water` | Zero calories |
| Sparkling Water | water | `water` | Zero calories |
| Black Coffee | beverage | `water` | Zero calories |
| Unsweetened Tea | beverage | `water` | Zero calories |

---

## 💻 Frontend Implementation Guide

### 1. TypeScript Interface Update

```typescript
interface ParsedFoodItem {
  id: string;
  name: string;
  quantity: number;
  unit: string;
  category: string;
  food_type: 'food' | 'drink' | 'water'; // NEW FIELD
  confidence: number;
  needs_review: boolean;
  macronutrients: Macronutrients;
  micronutrients?: Micronutrients;
  alternatives?: AlternativeFood[];
}

interface NutritionParseResponse {
  success: boolean;
  parsed_items: ParsedFoodItem[];
  total_macros: MacronutrientSummary;
  confidence: number;
  needs_review: boolean;
  food_log_id: string;
  raw_input: string;
  detected_language: string;
}
```

### 2. React Component Example

```tsx
import React from 'react';
import { WaterDrop, Restaurant, LocalCafe } from '@mui/icons-material';

interface FoodItemProps {
  item: ParsedFoodItem;
}

const FoodItemCard: React.FC<FoodItemProps> = ({ item }) => {
  const getFoodTypeIcon = () => {
    switch (item.food_type) {
      case 'food':
        return <Restaurant />;
      case 'drink':
        return <LocalCafe />;
      case 'water':
        return <WaterDrop />;
    }
  };

  const getFoodTypeLabel = () => {
    switch (item.food_type) {
      case 'food':
        return 'Food';
      case 'drink':
        return 'Beverage';
      case 'water':
        return 'Water';
    }
  };

  const getFoodTypeColor = () => {
    switch (item.food_type) {
      case 'food':
        return '#4CAF50';
      case 'drink':
        return '#FF9800';
      case 'water':
        return '#2196F3';
    }
  };

  return (
    <div className="food-item-card">
      <div className="food-type-badge" style={{ color: getFoodTypeColor() }}>
        {getFoodTypeIcon()}
        <span>{getFoodTypeLabel()}</span>
      </div>
      <h3>{item.name}</h3>
      <p>{item.quantity} {item.unit}</p>
      <div className="macros">
        <span>{item.macronutrients.calories} cal</span>
        <span>{item.macronutrients.protein}g protein</span>
      </div>
    </div>
  );
};
```

### 3. Water Intake Aggregation

```typescript
const calculateWaterIntake = (parsedItems: ParsedFoodItem[]): number => {
  return parsedItems
    .filter(item => item.food_type === 'water')
    .reduce((total, item) => {
      // Convert to ml if needed
      let amountInMl = item.quantity;
      if (item.unit === 'l' || item.unit === 'L') {
        amountInMl = item.quantity * 1000;
      } else if (item.unit === 'cup') {
        amountInMl = item.quantity * 240;
      } else if (item.unit === 'oz' || item.unit === 'fl oz') {
        amountInMl = item.quantity * 29.5735;
      }
      return total + amountInMl;
    }, 0);
};

// Usage
const waterIntakeToday = calculateWaterIntake(todaysParsedItems);
const waterGoal = 3000; // 3L goal
const progress = (waterIntakeToday / waterGoal) * 100;
```

### 4. Calorie Breakdown by Food Type

```typescript
const getCalorieBreakdown = (parsedItems: ParsedFoodItem[]) => {
  return parsedItems.reduce((breakdown, item) => {
    const calories = item.macronutrients.calories;

    switch (item.food_type) {
      case 'food':
        breakdown.food += calories;
        break;
      case 'drink':
        breakdown.drink += calories;
        break;
      case 'water':
        breakdown.water += calories; // Should always be 0
        break;
    }

    return breakdown;
  }, { food: 0, drink: 0, water: 0 });
};

// Usage
const breakdown = getCalorieBreakdown(todaysParsedItems);
console.log(`Food: ${breakdown.food} cal`);
console.log(`Drinks: ${breakdown.drink} cal`);
console.log(`Total: ${breakdown.food + breakdown.drink} cal`);
```

---

## 🎨 UI/UX Recommendations

### 1. Visual Distinction

Use icons and colors to help users quickly identify food types:

| Type | Icon | Color | Badge Text |
|------|------|-------|------------|
| food | 🍽️ Restaurant | Green (#4CAF50) | "Food" |
| drink | ☕ LocalCafe | Orange (#FF9800) | "Beverage" |
| water | 💧 WaterDrop | Blue (#2196F3) | "Water" |

### 2. Water Intake Widget

```tsx
<div className="water-intake-widget">
  <h3>💧 Water Intake</h3>
  <div className="progress-bar">
    <div className="progress" style={{ width: `${progress}%` }} />
  </div>
  <p>{waterIntakeToday}ml / {waterGoal}ml</p>
  <span className="status">
    {progress >= 100 ? '✅ Goal reached!' : `${waterGoal - waterIntakeToday}ml to go`}
  </span>
</div>
```

### 3. Nutrition Summary Enhancement

```tsx
<div className="nutrition-summary">
  <div className="total-calories">
    <h3>Total: {totalCalories} cal</h3>
    <div className="breakdown">
      <span className="food">
        🍽️ Food: {breakdown.food} cal ({foodPercent}%)
      </span>
      <span className="drink">
        ☕ Drinks: {breakdown.drink} cal ({drinkPercent}%)
      </span>
    </div>
  </div>
</div>
```

### 4. Insights & Recommendations

Show helpful insights based on food_type data:

```tsx
{breakdown.drink > 300 && (
  <div className="insight warning">
    ⚠️ You've consumed {breakdown.drink} calories from beverages today.
    Consider switching to water or unsweetened drinks to reduce calorie intake.
  </div>
)}

{waterIntakeToday < waterGoal * 0.5 && (
  <div className="insight info">
    💧 You're halfway to your hydration goal!
    Remember to drink {(waterGoal - waterIntakeToday) / 1000}L more water today.
  </div>
)}
```

---

## 🧪 Testing Recommendations

### 1. Unit Tests

```typescript
describe('food_type handling', () => {
  it('should correctly identify solid foods', () => {
    const item: ParsedFoodItem = {
      name: 'Chicken Breast',
      food_type: 'food',
      // ... other fields
    };
    expect(item.food_type).toBe('food');
    expect(getFoodTypeIcon(item.food_type)).toBe('Restaurant');
  });

  it('should correctly calculate water intake', () => {
    const items: ParsedFoodItem[] = [
      { food_type: 'water', quantity: 500, unit: 'ml', /* ... */ },
      { food_type: 'water', quantity: 1, unit: 'l', /* ... */ },
      { food_type: 'food', quantity: 200, unit: 'g', /* ... */ },
    ];
    expect(calculateWaterIntake(items)).toBe(1500); // 500ml + 1000ml
  });
});
```

### 2. API Response Validation

```typescript
const validateFoodType = (item: ParsedFoodItem): boolean => {
  const validTypes = ['food', 'drink', 'water'];
  return validTypes.includes(item.food_type);
};

const validateResponse = (response: NutritionParseResponse): void => {
  response.parsed_items.forEach(item => {
    if (!validateFoodType(item)) {
      console.error(`Invalid food_type: ${item.food_type} for item: ${item.name}`);
    }
  });
};
```

---

## 🔒 Backward Compatibility

### Migration Strategy

The `food_type` field is **always present** in new responses, but to handle potential edge cases:

```typescript
const getFoodTypeSafe = (item: ParsedFoodItem): string => {
  // Fallback for any edge cases
  return item.food_type || 'food'; // Default to 'food'
};

const isWater = (item: ParsedFoodItem): boolean => {
  return getFoodTypeSafe(item) === 'water';
};
```

---

## 📈 Analytics & Tracking

### Recommended Events

Track these analytics events for product insights:

```typescript
// User views water intake progress
analytics.track('water_intake_viewed', {
  current_intake: waterIntakeToday,
  goal: waterGoal,
  progress_percent: progress,
});

// User reaches water goal
if (progress >= 100) {
  analytics.track('water_goal_achieved', {
    intake: waterIntakeToday,
    goal: waterGoal,
    date: new Date().toISOString(),
  });
}

// Log beverage calorie awareness
if (breakdown.drink > 200) {
  analytics.track('high_beverage_calories', {
    drink_calories: breakdown.drink,
    total_calories: totalCalories,
    drink_percentage: drinkPercent,
  });
}
```

---

## ❓ FAQ

### Q: Will all existing meal logs have `food_type`?
**A:** No, only new meal logs parsed after this feature deployment will have the `food_type` field. Existing logs will not be retroactively updated.

### Q: Can I filter meal logs by `food_type`?
**A:** Not in v1. This will be added in a future API version with query parameters like `?food_type=water`.

### Q: What if the AI misclassifies an item?
**A:** Users can manually edit the classification in the UI (to be implemented). The `needs_review` flag may be set for low-confidence items.

### Q: How accurate is the classification?
**A:** The AI has been trained to classify with high accuracy (>95% for clear cases). Ambiguous items (e.g., "protein shake") will be marked with lower confidence.

### Q: Can I request specific `food_type` values in the input?
**A:** No, the `food_type` is determined automatically by the AI based on the food description. You cannot override it in the request.

---

## 🚀 Rollout Timeline

| Phase | Date | Status | Description |
|-------|------|--------|-------------|
| **Phase 1** | 2025-01-28 | ✅ Complete | Backend implementation, API returns `food_type` |
| **Phase 2** | 2025-02-05 | 📅 Planned | Frontend displays food type badges |
| **Phase 3** | 2025-02-12 | 📅 Planned | Water intake tracking widget |
| **Phase 4** | 2025-02-19 | 📅 Planned | Beverage calorie insights |
| **Phase 5** | 2025-03-01 | 📅 Planned | Goal setting & notifications |

---

## 📞 Support & Questions

**Backend API Contact:** [Engineering Team]
**API Documentation:** `/docs/swagger.yaml` (to be updated)
**Slack Channel:** `#fitiq-api-support`

**Questions?** Please reach out to the backend team for clarification or report any issues you encounter during integration.

---

**Happy Coding! 🚀**
