# Food Type Feature - Frontend Migration Guide

**Version:** 1.0.0
**Date:** 2025-01-28
**Target Audience:** Frontend Developers
**Estimated Migration Time:** 2-4 hours

---

## 📋 Overview

This guide helps you update your existing FitIQ frontend code to support the new `food_type` field in meal logging responses.

**What's changing:**
- ✅ API responses now include `food_type` in each parsed food item
- ✅ New opportunities for water tracking and beverage insights
- ✅ No breaking changes - fully backward compatible

**What's NOT changing:**
- ❌ API endpoint URLs remain the same
- ❌ Request payloads remain the same
- ❌ Existing fields remain unchanged

---

## 🚀 Step-by-Step Migration

### Step 1: Update TypeScript Types (5 minutes)

**Before:**
```typescript
interface ParsedFoodItem {
  id: string;
  name: string;
  quantity: number;
  unit: string;
  category: string;
  confidence: number;
  needs_review: boolean;
  macronutrients: Macronutrients;
  micronutrients?: Micronutrients;
  alternatives?: AlternativeFood[];
}
```

**After:**
```typescript
interface ParsedFoodItem {
  id: string;
  name: string;
  quantity: number;
  unit: string;
  category: string;
  food_type: 'food' | 'drink' | 'water'; // ← ADD THIS
  confidence: number;
  needs_review: boolean;
  macronutrients: Macronutrients;
  micronutrients?: Micronutrients;
  alternatives?: AlternativeFood[];
}
```

**Files to update:**
- `src/types/nutrition.ts` (or wherever you define API types)
- `src/types/api.ts`
- Any component-specific type files

---

### Step 2: Add Helper Functions (10 minutes)

Create a new file: `src/utils/foodType.ts`

```typescript
export type FoodType = 'food' | 'drink' | 'water';

export const getFoodTypeLabel = (type: FoodType): string => {
  const labels = {
    food: 'Food',
    drink: 'Beverage',
    water: 'Water'
  };
  return labels[type];
};

export const getFoodTypeColor = (type: FoodType): string => {
  const colors = {
    food: '#4CAF50',   // Green
    drink: '#FF9800',  // Orange
    water: '#2196F3'   // Blue
  };
  return colors[type];
};

export const getFoodTypeIcon = (type: FoodType): string => {
  const icons = {
    food: '🍽️',
    drink: '☕',
    water: '💧'
  };
  return icons[type];
};

// Safe getter with fallback
export const getFoodTypeSafe = (item: ParsedFoodItem): FoodType => {
  return item.food_type || 'food';
};
```

---

### Step 3: Update Food Item Components (20 minutes)

**Before:**
```tsx
const FoodItemCard: React.FC<{ item: ParsedFoodItem }> = ({ item }) => {
  return (
    <div className="food-item">
      <h3>{item.name}</h3>
      <p>{item.quantity} {item.unit}</p>
      <span className="category">{item.category}</span>
      <div className="macros">
        {item.macronutrients.calories} cal
      </div>
    </div>
  );
};
```

**After:**
```tsx
import { getFoodTypeIcon, getFoodTypeColor, getFoodTypeLabel } from '@/utils/foodType';

const FoodItemCard: React.FC<{ item: ParsedFoodItem }> = ({ item }) => {
  return (
    <div className="food-item">
      <div className="food-type-badge"
           style={{ backgroundColor: getFoodTypeColor(item.food_type) }}>
        <span>{getFoodTypeIcon(item.food_type)}</span>
        <span>{getFoodTypeLabel(item.food_type)}</span>
      </div>
      <h3>{item.name}</h3>
      <p>{item.quantity} {item.unit}</p>
      <span className="category">{item.category}</span>
      <div className="macros">
        {item.macronutrients.calories} cal
      </div>
    </div>
  );
};
```

**Add CSS:**
```css
.food-type-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  color: white;
  margin-bottom: 8px;
}
```

---

### Step 4: Add Water Tracking Widget (30 minutes)

Create new component: `src/components/WaterIntakeWidget.tsx`

```tsx
import React, { useMemo } from 'react';
import { LinearProgress } from '@mui/material';

interface WaterIntakeWidgetProps {
  items: ParsedFoodItem[];
  goal?: number; // in ml, default 3000ml
}

export const WaterIntakeWidget: React.FC<WaterIntakeWidgetProps> = ({
  items,
  goal = 3000
}) => {
  const waterIntake = useMemo(() => {
    return items
      .filter(item => item.food_type === 'water')
      .reduce((total, item) => {
        let amountInMl = item.quantity;

        // Convert to ml based on unit
        switch (item.unit.toLowerCase()) {
          case 'l':
            amountInMl *= 1000;
            break;
          case 'cup':
          case 'cups':
            amountInMl *= 240;
            break;
          case 'oz':
          case 'fl oz':
            amountInMl *= 29.5735;
            break;
          // ml is already in correct unit
        }

        return total + amountInMl;
      }, 0);
  }, [items]);

  const progress = (waterIntake / goal) * 100;
  const remaining = Math.max(0, goal - waterIntake);
  const isGoalReached = progress >= 100;

  return (
    <div className="water-intake-widget">
      <div className="header">
        <span className="icon">💧</span>
        <h3>Water Intake</h3>
      </div>

      <div className="progress-container">
        <LinearProgress
          variant="determinate"
          value={Math.min(progress, 100)}
          sx={{
            height: 8,
            borderRadius: 4,
            backgroundColor: '#E3F2FD',
            '& .MuiLinearProgress-bar': {
              backgroundColor: '#2196F3',
            }
          }}
        />
      </div>

      <div className="stats">
        <span className="current">{Math.round(waterIntake)}ml</span>
        <span className="divider">/</span>
        <span className="goal">{goal}ml</span>
      </div>

      {isGoalReached ? (
        <div className="status success">
          ✅ Goal reached! Great hydration today!
        </div>
      ) : (
        <div className="status pending">
          {Math.round(remaining)}ml to go
        </div>
      )}
    </div>
  );
};
```

**Add to your daily summary page:**
```tsx
<WaterIntakeWidget items={todaysParsedItems} goal={3000} />
```

---

### Step 5: Add Calorie Breakdown (20 minutes)

Create new component: `src/components/CalorieBreakdown.tsx`

```tsx
import React, { useMemo } from 'react';

interface CalorieBreakdownProps {
  items: ParsedFoodItem[];
}

export const CalorieBreakdown: React.FC<CalorieBreakdownProps> = ({ items }) => {
  const breakdown = useMemo(() => {
    return items.reduce((acc, item) => {
      const calories = item.macronutrients.calories;
      acc[item.food_type] = (acc[item.food_type] || 0) + calories;
      acc.total += calories;
      return acc;
    }, { food: 0, drink: 0, water: 0, total: 0 });
  }, [items]);

  const foodPercent = breakdown.total > 0
    ? Math.round((breakdown.food / breakdown.total) * 100)
    : 0;
  const drinkPercent = breakdown.total > 0
    ? Math.round((breakdown.drink / breakdown.total) * 100)
    : 0;

  return (
    <div className="calorie-breakdown">
      <h3>Calorie Sources</h3>

      <div className="total">
        <span className="label">Total Calories</span>
        <span className="value">{Math.round(breakdown.total)} cal</span>
      </div>

      <div className="breakdown-items">
        <div className="breakdown-item food">
          <span className="icon">🍽️</span>
          <span className="label">Food</span>
          <div className="bar" style={{ width: `${foodPercent}%` }} />
          <span className="value">{Math.round(breakdown.food)} cal</span>
          <span className="percent">({foodPercent}%)</span>
        </div>

        <div className="breakdown-item drink">
          <span className="icon">☕</span>
          <span className="label">Beverages</span>
          <div className="bar" style={{ width: `${drinkPercent}%` }} />
          <span className="value">{Math.round(breakdown.drink)} cal</span>
          <span className="percent">({drinkPercent}%)</span>
        </div>
      </div>

      {breakdown.drink > 300 && (
        <div className="insight warning">
          ⚠️ High beverage calories today. Consider water or unsweetened drinks.
        </div>
      )}
    </div>
  );
};
```

---

### Step 6: Update Analytics (15 minutes)

**Add tracking for water intake:**

```typescript
// src/analytics/nutrition.ts

export const trackWaterIntake = (intake: number, goal: number) => {
  analytics.track('water_intake_logged', {
    amount_ml: intake,
    goal_ml: goal,
    progress_percent: (intake / goal) * 100,
    date: new Date().toISOString().split('T')[0],
  });
};

export const trackWaterGoalAchieved = (intake: number, goal: number) => {
  analytics.track('water_goal_achieved', {
    amount_ml: intake,
    goal_ml: goal,
    date: new Date().toISOString().split('T')[0],
  });
};

export const trackHighBeverageCalories = (calories: number, total: number) => {
  analytics.track('high_beverage_calories', {
    drink_calories: calories,
    total_calories: total,
    drink_percentage: Math.round((calories / total) * 100),
    date: new Date().toISOString().split('T')[0],
  });
};
```

**Add to your logging flow:**

```tsx
useEffect(() => {
  if (waterIntake > 0) {
    trackWaterIntake(waterIntake, waterGoal);
  }

  if (waterIntake >= waterGoal) {
    trackWaterGoalAchieved(waterIntake, waterGoal);
  }

  if (drinkCalories > 300) {
    trackHighBeverageCalories(drinkCalories, totalCalories);
  }
}, [waterIntake, waterGoal, drinkCalories, totalCalories]);
```

---

### Step 7: Update Tests (30 minutes)

**Add test utilities:**

```typescript
// src/test/fixtures/nutrition.ts

export const mockFoodItem: ParsedFoodItem = {
  id: 'item-1',
  name: 'Grilled Chicken',
  quantity: 200,
  unit: 'g',
  category: 'protein',
  food_type: 'food',
  confidence: 92.5,
  needs_review: false,
  macronutrients: { calories: 330, protein: 62, carbohydrates: 0, fats: 7.4 },
};

export const mockDrinkItem: ParsedFoodItem = {
  id: 'item-2',
  name: 'Orange Juice',
  quantity: 250,
  unit: 'ml',
  category: 'beverage',
  food_type: 'drink',
  confidence: 95.0,
  needs_review: false,
  macronutrients: { calories: 110, protein: 1.7, carbohydrates: 25.8, fats: 0.5 },
};

export const mockWaterItem: ParsedFoodItem = {
  id: 'item-3',
  name: 'Water',
  quantity: 500,
  unit: 'ml',
  category: 'water',
  food_type: 'water',
  confidence: 100.0,
  needs_review: false,
  macronutrients: { calories: 0, protein: 0, carbohydrates: 0, fats: 0 },
};
```

**Add component tests:**

```typescript
// src/components/__tests__/WaterIntakeWidget.test.tsx

import { render, screen } from '@testing-library/react';
import { WaterIntakeWidget } from '../WaterIntakeWidget';
import { mockWaterItem } from '@/test/fixtures/nutrition';

describe('WaterIntakeWidget', () => {
  it('calculates water intake correctly', () => {
    const items = [
      { ...mockWaterItem, quantity: 500, unit: 'ml' },
      { ...mockWaterItem, quantity: 1, unit: 'l' },
    ];

    render(<WaterIntakeWidget items={items} goal={3000} />);

    expect(screen.getByText(/1500ml/)).toBeInTheDocument();
  });

  it('shows goal reached status', () => {
    const items = [
      { ...mockWaterItem, quantity: 3000, unit: 'ml' },
    ];

    render(<WaterIntakeWidget items={items} goal={3000} />);

    expect(screen.getByText(/Goal reached/)).toBeInTheDocument();
  });
});
```

---

## ✅ Migration Checklist

### Code Changes
- [ ] Update TypeScript interfaces to include `food_type`
- [ ] Add helper functions for food type handling
- [ ] Update food item display components with badges/icons
- [ ] Create water intake tracking widget
- [ ] Create calorie breakdown component
- [ ] Add analytics tracking
- [ ] Update unit tests

### Visual Design
- [ ] Add food type badges/icons to item cards
- [ ] Choose colors for each food type (green/orange/blue)
- [ ] Design water intake progress widget
- [ ] Design calorie breakdown visualization
- [ ] Add insight/alert messages

### Testing
- [ ] Test with all three food types (food, drink, water)
- [ ] Test water intake calculations with different units
- [ ] Test calorie breakdown accuracy
- [ ] Test UI with missing/null `food_type` (should default to 'food')
- [ ] Test on different screen sizes

### QA Scenarios
- [ ] Log a meal with only food items
- [ ] Log a meal with food + drinks
- [ ] Log a meal with water
- [ ] Log a meal with all three types
- [ ] Verify water goal progress updates
- [ ] Verify beverage calorie alerts show when appropriate

---

## 🐛 Known Issues & Workarounds

### Issue 1: Old cached responses missing `food_type`

**Problem:** Cached API responses from before deployment don't have `food_type`.

**Solution:**
```typescript
const getFoodTypeSafe = (item: ParsedFoodItem): FoodType => {
  return item.food_type || 'food'; // Default to 'food'
};
```

### Issue 2: Unit conversion edge cases

**Problem:** Some units might not be handled (e.g., "glass", "bottle").

**Solution:**
```typescript
const convertToMl = (quantity: number, unit: string): number => {
  const unitLower = unit.toLowerCase().trim();

  const conversions: Record<string, number> = {
    'ml': 1,
    'l': 1000,
    'cup': 240,
    'cups': 240,
    'oz': 29.5735,
    'fl oz': 29.5735,
    'glass': 240,      // Assume standard glass
    'bottle': 500,     // Assume standard bottle
    'pint': 473.176,
    'quart': 946.353,
  };

  return quantity * (conversions[unitLower] || 1);
};
```

---

## 📊 Testing Data

Use these test inputs to verify your implementation:

| Input | Expected Output |
|-------|----------------|
| "200g chicken breast" | food_type: "food" |
| "1 cup orange juice" | food_type: "drink" |
| "500ml water" | food_type: "water" |
| "protein shake 300ml" | food_type: "drink" |
| "black coffee" | food_type: "water" (zero cal) |
| "coffee with milk" | food_type: "drink" (has calories) |

---

## 🚀 Deployment Strategy

### Phase 1: Silent Launch (Week 1)
- Deploy code changes
- `food_type` present but not displayed in UI
- Monitor for errors/issues

### Phase 2: Soft Launch (Week 2)
- Show food type badges in UI
- No water tracking yet
- A/B test with 10% of users

### Phase 3: Full Launch (Week 3)
- Enable water intake widget for all users
- Enable calorie breakdown
- Full feature rollout

---

## 📚 Additional Resources

- **Full API Documentation:** `FOOD_TYPE_API_DOCUMENTATION.md`
- **Quick Reference:** `FOOD_TYPE_QUICK_REFERENCE.md`
- **Implementation Details:** `FOOD_TYPE_FEATURE_SUMMARY.md`
- **API Endpoint:** `POST /api/v1/nutrition/parse`

---

## 💡 Best Practices

### DO:
✅ Use the helper functions for consistency
✅ Handle missing `food_type` with defaults
✅ Test with all three food types
✅ Add loading states for water widget
✅ Show helpful insights based on data

### DON'T:
❌ Hardcode water detection from item names
❌ Assume all items have `food_type`
❌ Use different colors than specified
❌ Make water widget required on all pages
❌ Remove existing calorie displays

---

## 🆘 Need Help?

**Questions?** Ask in `#fitiq-frontend` or `#fitiq-api-support`
**Bug Found?** File in Jira with label `food-type`
**Backend Contact:** @engineering-backend
**Design Questions?** Ask @design-team

---

**Estimated Total Migration Time: 2-4 hours**

Good luck with the migration! 🚀
