# Nutrition Feature Documentation

**Last Updated:** 2025-01-28  
**Current Features:** Meal Logging, Food Type Classification  

---

## 📚 Documentation Index

### Food Type Classification

The iOS app now supports food type classification for meal log items, enabling:
- **Water intake tracking** - Automatic calculation of daily water consumption
- **Beverage insights** - Track calories from beverages separately
- **Better UX** - Visual distinction between solid foods, beverages, and water

#### Quick Links

- 📖 **[Quick Start Guide](./FOOD_TYPE_QUICK_START.md)** - Start here! Learn how to use food_type in 5 minutes
- 📘 **[Implementation Details](./FOOD_TYPE_IOS_IMPLEMENTATION.md)** - Complete technical documentation
- 📋 **[Changes Summary](./FOOD_TYPE_CHANGES_SUMMARY.md)** - What changed and where

#### Backend Documentation

- 📄 **[Frontend Handoff](./food-type/FRONTEND_HANDOFF_SUMMARY.MD)** - Backend team handoff document
- 🔧 **[Migration Guide](./food-type/FOOD_TYPE_MIGRATION_GUIDE.md)** - Frontend migration guide
- 📊 **[API Documentation](./food-type/FOOD_TYPE_API_DOCUMENTATION.MD)** - Complete API specs
- ⚡ **[Quick Reference](./food-type/FOOD_TYPE_QUICK_REFERENCE.MD)** - Backend API cheat sheet
- 📝 **[Feature Summary](./food-type/FOOD_TYPE_FEATURE_SUMMARY.md)** - Backend implementation details

---

## 🚀 Getting Started

### For Developers

1. **Read the Quick Start Guide** - Learn the basics in 5 minutes
   - [`docs/nutrition/FOOD_TYPE_QUICK_START.md`](./FOOD_TYPE_QUICK_START.md)

2. **Review Implementation Details** - Understand the architecture
   - [`docs/nutrition/FOOD_TYPE_IOS_IMPLEMENTATION.md`](./FOOD_TYPE_IOS_IMPLEMENTATION.md)

3. **Check Changes Summary** - See what files were modified
   - [`docs/nutrition/FOOD_TYPE_CHANGES_SUMMARY.md`](./FOOD_TYPE_CHANGES_SUMMARY.md)

### For Product/Design

1. **Review Feature Summary** - Understand what's possible
   - [`docs/nutrition/food-type/FOOD_TYPE_FEATURE_SUMMARY.md`](./food-type/FOOD_TYPE_FEATURE_SUMMARY.md)

2. **Check Frontend Handoff** - See backend capabilities
   - [`docs/nutrition/food-type/FRONTEND_HANDOFF_SUMMARY.MD`](./food-type/FRONTEND_HANDOFF_SUMMARY.MD)

---

## 🎯 Current Feature Status

### ✅ Implemented

- [x] Domain model with `FoodType` enum (`.food`, `.drink`, `.water`)
- [x] SwiftData schema V7 with `foodType` field
- [x] Repository support for storing/retrieving food types
- [x] WebSocket integration for receiving food types from backend
- [x] Helper methods for filtering and calculations
- [x] Comprehensive documentation

### ⏳ Pending

- [ ] Unit tests for all components
- [ ] Integration tests for meal logging flow
- [ ] UI components (badges, water widget, insights)
- [ ] User acceptance testing

### 🔮 Future Enhancements

- [ ] Water goal setting in user profile
- [ ] Hydration notifications and reminders
- [ ] Advanced analytics (trends, correlations)
- [ ] Smart suggestions for healthier alternatives
- [ ] Home screen widget for water intake

---

## 📖 Key Concepts

### Food Type Classification

Every meal log item is classified into one of three types:

| Type | Description | Examples | Use Case |
|------|-------------|----------|----------|
| **`food`** | Solid foods | Chicken, rice, vegetables, fruits | General nutrition tracking |
| **`drink`** | Caloric beverages | Juice, milk, soda, smoothies | Beverage calorie insights |
| **`water`** | Water/zero-cal drinks | Water, black coffee, unsweetened tea | Hydration tracking |

### Schema Version

- **Current Schema:** V7
- **Previous Schema:** V6
- **Migration Type:** Lightweight (additive only)
- **Backward Compatibility:** ✅ Yes (default value: `"food"`)

### Architecture

- **Pattern:** Hexagonal Architecture (Ports & Adapters)
- **Domain Layer:** Pure business logic with `FoodType` enum
- **Infrastructure Layer:** SwiftData persistence, WebSocket networking
- **Presentation Layer:** ViewModels and Views (UI pending)

---

## 💻 Code Examples

### Basic Usage

```swift
// Filter by food type
let mealLog: MealLog = ...
let waterItems = mealLog.waterItems
let drinkItems = mealLog.drinkItems
let foodItems = mealLog.foodItems

// Calculate water intake
let waterMl = mealLog.estimatedWaterIntakeMl
print("Water: \(Int(waterMl))ml")

// Track beverage calories
let beverageCals = mealLog.beverageCalories
let percentage = mealLog.beverageCaloriePercentage
```

### Creating Items

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

### Display Properties

```swift
let foodType: FoodType = .water

foodType.displayName  // "Water"
foodType.emoji        // "💧"
foodType.color        // "#2196F3" (blue)
```

---

## 🧪 Testing

### Test Coverage Needed

1. **Domain Tests**
   - FoodType enum properties
   - MealLogItem initialization
   - MealLog filtering and calculations

2. **Repository Tests**
   - Saving items with food types
   - Fetching and converting correctly
   - Default value handling

3. **WebSocket Tests**
   - Payload parsing with food_type
   - Conversion to domain model
   - Invalid value fallback

4. **Integration Tests**
   - End-to-end meal logging
   - Schema migration V6 → V7
   - WebSocket real-time updates

---

## 🎨 UI Components (Planned)

### Food Type Badge
Visual indicator for each item showing its food type with emoji and color.

### Water Intake Widget
Card showing daily water consumption progress toward goal.

### Calorie Breakdown
Chart showing percentage of calories from solid foods vs beverages.

### Beverage Insights
Alerts and tips when beverage calories are high.

---

## 📦 Files Structure

```
FitIQ/
├── Domain/
│   ├── Entities/
│   │   └── Nutrition/
│   │       └── MealLogEntities.swift (FoodType enum, MealLogItem)
│   └── Ports/
│       └── MealLogWebSocketProtocol.swift (MealLogItemPayload)
│
├── Infrastructure/
│   ├── Persistence/
│   │   └── Schema/
│   │       ├── SchemaV7.swift (NEW - with foodType)
│   │       ├── SchemaDefinition.swift (Updated to V7)
│   │       └── PersistenceHelper.swift (Updated typealiases)
│   └── Repositories/
│       └── SwiftDataMealLogRepository.swift (Updated conversions)
│
├── Presentation/
│   └── ViewModels/
│       └── NutritionViewModel.swift (WebSocket handling)
│
└── docs/
    └── nutrition/
        ├── README.md (this file)
        ├── FOOD_TYPE_QUICK_START.md
        ├── FOOD_TYPE_IOS_IMPLEMENTATION.md
        ├── FOOD_TYPE_CHANGES_SUMMARY.md
        └── food-type/ (Backend docs)
            ├── FRONTEND_HANDOFF_SUMMARY.MD
            ├── FOOD_TYPE_MIGRATION_GUIDE.md
            ├── FOOD_TYPE_API_DOCUMENTATION.MD
            ├── FOOD_TYPE_QUICK_REFERENCE.MD
            └── FOOD_TYPE_FEATURE_SUMMARY.md
```

---

## 🔗 External Resources

- **Backend API:** `docs/be-api-spec/swagger.yaml`
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **Architecture Guidelines:** `docs/.github/copilot-instructions.md`

---

## 📞 Support

### Questions?
- Technical implementation: Review implementation docs
- Schema migration: Check SchemaV7.swift and migration guide
- WebSocket integration: Review WebSocket protocol docs
- Backend coordination: Check backend documentation folder

### Issues?
- Compilation errors: Check diagnostics output
- Schema errors: Verify SchemaV7 and PersistenceHelper
- WebSocket errors: Check payload structure matches backend
- Data conversion: Review repository conversion logic

---

## ✅ Checklist for New Features

When adding new nutrition features:

- [ ] Define domain model in `Domain/Entities/Nutrition/`
- [ ] Create/update schema version if needed
- [ ] Update repository for persistence
- [ ] Update WebSocket protocol if backend integration needed
- [ ] Update ViewModel for presentation logic
- [ ] Write comprehensive tests
- [ ] Document in this folder
- [ ] Follow Hexagonal Architecture
- [ ] Use SD prefix for SwiftData models
- [ ] Consider Outbox Pattern for sync

---

**Status:** ✅ Food Type feature implementation complete  
**Next:** UI integration and user testing  
**Version:** 1.0.0  
**Last Updated:** 2025-01-28