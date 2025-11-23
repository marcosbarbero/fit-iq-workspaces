# Food Type Feature - Quick Reference Cheat Sheet

**For Frontend Developers**
**Date:** 2025-01-28

---

## 🎯 What's New?

Every parsed food item now includes a `food_type` field:
- `"food"` = Solid foods
- `"drink"` = Caloric beverages
- `"water"` = Water/zero-cal drinks

---

## 📦 TypeScript Type

```typescript
interface ParsedFoodItem {
  id: string;
  name: string;
  quantity: number;
  unit: string;
  category: string;
  food_type: 'food' | 'drink' | 'water'; // ← NEW!
  confidence: number;
  needs_review: boolean;
  macronutrients: Macronutrients;
  micronutrients?: Micronutrients;
}
```

---

## 📊 Example Response

```json
{
  "parsed_items": [
    {
      "name": "Grilled Chicken",
      "food_type": "food",
      "macronutrients": { "calories": 330 }
    },
    {
      "name": "Orange Juice",
      "food_type": "drink",
      "macronutrients": { "calories": 110 }
    },
    {
      "name": "Water",
      "food_type": "water",
      "macronutrients": { "calories": 0 }
    }
  ]
}
```

---

## 🎨 Visual Design

| Type | Icon | Color | Use |
|------|------|-------|-----|
| `food` | 🍽️ | Green `#4CAF50` | Solid foods |
| `drink` | ☕ | Orange `#FF9800` | Caloric beverages |
| `water` | 💧 | Blue `#2196F3` | Water tracking |

---

## 💻 Common Code Snippets

### Filter Water Items
```typescript
const waterItems = items.filter(item => item.food_type === 'water');
```

### Calculate Water Intake (in ml)
```typescript
const waterIntake = items
  .filter(item => item.food_type === 'water')
  .reduce((sum, item) => {
    let ml = item.quantity;
    if (item.unit === 'l') ml *= 1000;
    if (item.unit === 'cup') ml *= 240;
    if (item.unit === 'oz') ml *= 29.5735;
    return sum + ml;
  }, 0);
```

### Calorie Breakdown
```typescript
const breakdown = items.reduce((acc, item) => {
  acc[item.food_type] += item.macronutrients.calories;
  return acc;
}, { food: 0, drink: 0, water: 0 });

console.log(`Food: ${breakdown.food} cal`);
console.log(`Drinks: ${breakdown.drink} cal`);
```

### Icon Component
```tsx
const FoodTypeIcon = ({ type }: { type: string }) => {
  switch (type) {
    case 'food': return <Restaurant />;
    case 'drink': return <LocalCafe />;
    case 'water': return <WaterDrop />;
  }
};
```

---

## 📊 Use Cases

### 1. Water Intake Widget
```tsx
<div className="water-widget">
  <h3>💧 Water: {waterIntake}ml / 3000ml</h3>
  <ProgressBar value={waterIntake / 3000 * 100} />
</div>
```

### 2. Beverage Calorie Alert
```tsx
{drinkCalories > 300 && (
  <Alert>
    ⚠️ High beverage calories today: {drinkCalories} cal
  </Alert>
)}
```

### 3. Food Type Badge
```tsx
<Badge
  color={getFoodTypeColor(item.food_type)}
  icon={<FoodTypeIcon type={item.food_type} />}
>
  {item.name}
</Badge>
```

---

## ✅ Testing Checklist

- [ ] Display food type icon/badge for each item
- [ ] Calculate water intake correctly (handle unit conversions)
- [ ] Show calorie breakdown (food vs drinks)
- [ ] Handle missing `food_type` gracefully (default to "food")
- [ ] Test with all three types: food, drink, water

---

## 🐛 Common Pitfalls

❌ **Don't assume all items are 'food'**
```typescript
// Bad
const calories = items.reduce((sum, item) =>
  sum + item.macronutrients.calories, 0);
```

✅ **Differentiate by food_type**
```typescript
// Good
const foodCalories = items
  .filter(item => item.food_type === 'food')
  .reduce((sum, item) => sum + item.macronutrients.calories, 0);
```

❌ **Don't hardcode water detection**
```typescript
// Bad
const isWater = item.name.toLowerCase().includes('water');
```

✅ **Use the food_type field**
```typescript
// Good
const isWater = item.food_type === 'water';
```

---

## 🔗 Related Docs

- **Full API Documentation:** `FOOD_TYPE_API_DOCUMENTATION.md`
- **Implementation Details:** `FOOD_TYPE_FEATURE_SUMMARY.md`
- **API Endpoint:** `POST /api/v1/nutrition/parse`

---

## 📞 Quick Help

**Questions?** Ask in `#fitiq-api-support`
**Bug Report?** File in Jira with label `food-type`
**Backend Team:** @engineering-backend

---

**TL;DR:** Every food item now has `food_type: 'food' | 'drink' | 'water'`. Use it for water tracking, calorie breakdowns, and better UX! 🚀
