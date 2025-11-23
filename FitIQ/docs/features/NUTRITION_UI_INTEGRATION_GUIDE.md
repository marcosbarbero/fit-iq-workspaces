# Nutrition UI Integration Guide

**Date:** 2025-01-27  
**Status:** 🔴 **NOT CONNECTED** - UI needs integration  
**Priority:** HIGH

---

## 🚨 Current Situation

### What's Implemented ✅
- ✅ **Domain Layer** - `MealLog`, `MealLogItem`, status enums
- ✅ **Infrastructure Layer** - Repositories, API clients, Outbox Pattern
- ✅ **Use Cases** - `SaveMealLogUseCase`, `GetMealLogsUseCase`
- ✅ **Dependency Injection** - All components registered in `AppDependencies`

### What's NOT Connected ❌
- ❌ **NutritionView** - Using mock data (`DailyMealLog`)
- ❌ **NutritionViewModel** - Not using the real use cases
- ❌ **AddMealView** - Not calling `SaveMealLogUseCase`
- ❌ **MealDetailView** - Not using real `MealLog` data

---

## 🔍 Problem Analysis

### Current Implementation

**File:** `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`

```swift
// ❌ PROBLEM: Using mock structure instead of domain model
struct DailyMealLog: Identifiable {
    let id = UUID()
    let name: String
    let time: Date
    let calories: Int
    let protein: Int
    // ... etc
}

@Observable
final class NutritionViewModel {
    var meals: [DailyMealLog] = [] // ❌ Wrong type
    
    @MainActor
    func loadDataForSelectedDate() async {
        // ❌ Mock data instead of calling GetMealLogsUseCase
        self.meals = [
            DailyMealLog(name: "Breakfast...", ...)
        ]
    }
}
```

**File:** `FitIQ/Presentation/UI/Nutrition/NutritionView.swift`

```swift
struct NutritionView: View {
    @State private var viewModel: NutritionViewModel
    
    // ❌ PROBLEM: ViewModel not injected with use cases
    init(viewModel: NutritionViewModel, ...) {
        self._viewModel = State(initialValue: viewModel)
    }
}
```

---

## ✅ Solution: Integration Steps

### Step 1: Update NutritionViewModel

**File:** `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`

**Changes Required:**

1. **Remove mock `DailyMealLog` struct**
2. **Inject use cases via dependencies**
3. **Replace mock data with real API calls**
4. **Map `MealLog` domain model to UI-friendly structure (if needed)**

**New Implementation:**

```swift
import Foundation
import Observation
import SwiftUI

// MARK: - UI Model (Adapter from Domain Model)

/// UI-friendly representation of MealLog for display
struct DailyMealLog: Identifiable {
    let id: UUID
    let name: String
    let time: Date
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let sugar: Int
    let fiber: Int
    let saturatedFat: Int
    let sodiumMg: Int
    let ironMg: Double
    let vitaminCmg: Int
    
    // Status information
    let status: MealLogStatus
    let syncStatus: SyncStatus
    let backendID: String?
    
    var fullNutrientList: [(name: String, amount: String, color: Color)] {
        [
            ("Calories", "\(calories) kcal", .ascendBlue),
            ("Protein", "\(protein)g", .sustenanceYellow),
            ("Carbs", "\(carbs)g", .vitalityTeal),
            ("Fat", "\(fat)g", .serenityLavender),
            ("Fiber", "\(fiber)g", .growthGreen),
            ("Sugar", "\(sugar)g", .attentionOrange),
            ("Sat. Fat", "\(saturatedFat)g", .warningRed),
            ("Sodium", "\(sodiumMg)mg", .secondary),
            ("Iron", "\(String(format: "%.1f", ironMg))mg", .secondary),
            ("Vitamin C", "\(vitaminCmg)mg", .secondary)
        ]
    }
    
    /// Maps from domain MealLog to UI DailyMealLog
    static func from(mealLog: MealLog) -> DailyMealLog {
        return DailyMealLog(
            id: mealLog.id,
            name: mealLog.rawInput, // Use raw input as name
            time: mealLog.loggedAt,
            calories: Int(mealLog.totalCalories),
            protein: Int(mealLog.totalProteinG),
            carbs: Int(mealLog.totalCarbsG),
            fat: Int(mealLog.totalFatG),
            // NOTE: These values need to be calculated from items
            // For now, using placeholder values
            sugar: 0, // TODO: Sum from items if available
            fiber: 0, // TODO: Sum from items if available
            saturatedFat: 0, // TODO: Sum from items if available
            sodiumMg: 0, // TODO: Sum from items if available
            ironMg: 0.0, // TODO: Sum from items if available
            vitaminCmg: 0, // TODO: Sum from items if available
            status: mealLog.status,
            syncStatus: mealLog.syncStatus,
            backendID: mealLog.backendID
        )
    }
}

// MARK: - ViewModel

@Observable
final class NutritionViewModel {
    
    // MARK: - State
    var selectedDate: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?
    
    var dailySummary: (kcal: Int, protein: Int, carbs: Int, fat: Int) = (0, 0, 0, 0)
    var meals: [DailyMealLog] = []
    
    var dailyTargets: (kcal: Int, protein: Int, carbs: Int, fat: Int) = (2500, 150, 250, 60)
    var netGoal: Int = 0
    
    // MARK: - Dependencies
    private let saveMealLogUseCase: SaveMealLogUseCase
    private let getMealLogsUseCase: GetMealLogsUseCase
    
    // MARK: - Initialization
    init(
        saveMealLogUseCase: SaveMealLogUseCase,
        getMealLogsUseCase: GetMealLogsUseCase
    ) {
        self.saveMealLogUseCase = saveMealLogUseCase
        self.getMealLogsUseCase = getMealLogsUseCase
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadDataForSelectedDate() async {
        isLoading = true
        errorMessage = nil
        
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            // ✅ REAL API CALL: Fetch meal logs for selected date
            let mealLogs = try await getMealLogsUseCase.execute(
                status: .completed, // Only show completed meals
                syncStatus: nil,
                mealType: nil,
                startDate: startOfDay,
                endDate: endOfDay,
                limit: nil,
                useLocalOnly: false
            )
            
            // Map domain models to UI models
            self.meals = mealLogs.map { DailyMealLog.from(mealLog: $0) }
            
            // Calculate daily summary
            self.dailySummary = meals.reduce((kcal: 0, protein: 0, carbs: 0, fat: 0)) { result, meal in
                (
                    result.kcal + meal.calories,
                    result.protein + meal.protein,
                    result.carbs + meal.carbs,
                    result.fat + meal.fat
                )
            }
            
            print("NutritionViewModel: Loaded \(meals.count) meals for \(selectedDate)")
        } catch {
            errorMessage = error.localizedDescription
            print("NutritionViewModel: Failed to load meals: \(error)")
        }
        
        isLoading = false
    }
    
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
            // ✅ REAL API CALL: Save meal log
            _ = try await saveMealLogUseCase.execute(
                rawInput: rawInput,
                mealType: mealType,
                loggedAt: loggedAt,
                notes: notes
            )
            
            // Refresh meal list
            await loadDataForSelectedDate()
            
            print("NutritionViewModel: Meal log saved successfully")
        } catch {
            errorMessage = error.localizedDescription
            print("NutritionViewModel: Failed to save meal: \(error)")
        }
        
        isLoading = false
    }
}
```

### Step 2: Update NutritionView Initialization

**File:** `FitIQ/Presentation/UI/Nutrition/NutritionView.swift`

**Change the initialization:**

```swift
struct NutritionView: View {
    @State private var viewModel: NutritionViewModel
    @State private var addMealViewModel: AddMealViewModel
    @State private var quickSelectViewModel: MealQuickSelectViewModel
    
    // ✅ UPDATED: Inject dependencies
    init(
        saveMealLogUseCase: SaveMealLogUseCase,
        getMealLogsUseCase: GetMealLogsUseCase,
        addMealViewModel: AddMealViewModel,
        quickSelectViewModel: MealQuickSelectViewModel
    ) {
        // Create NutritionViewModel with real use cases
        self._viewModel = State(initialValue: NutritionViewModel(
            saveMealLogUseCase: saveMealLogUseCase,
            getMealLogsUseCase: getMealLogsUseCase
        ))
        self._addMealViewModel = State(initialValue: addMealViewModel)
        self._quickSelectViewModel = State(initialValue: quickSelectViewModel)
    }
    
    // ... rest of view
}
```

### Step 3: Update App/Scene to Pass Dependencies

**File:** Find where `NutritionView` is instantiated (likely in a TabView or similar)

**Change from:**

```swift
// ❌ OLD
NutritionView(
    viewModel: NutritionViewModel(),
    addMealViewModel: addMealViewModel,
    quickSelectViewModel: quickSelectViewModel
)
```

**Change to:**

```swift
// ✅ NEW
NutritionView(
    saveMealLogUseCase: appDependencies.saveMealLogUseCase,
    getMealLogsUseCase: appDependencies.getMealLogsUseCase,
    addMealViewModel: addMealViewModel,
    quickSelectViewModel: quickSelectViewModel
)
```

### Step 4: Update AddMealView to Call SaveMealLogUseCase

**File:** Find `AddMealView.swift` (not provided, but likely exists)

**Required changes:**

```swift
struct AddMealView: View {
    @State private var mealInput: String = ""
    @State private var selectedMealType: String = "breakfast"
    @State private var selectedDate: Date = Date()
    @State private var notes: String = ""
    
    let viewModel: NutritionViewModel // Pass the ViewModel
    
    var body: some View {
        Form {
            TextField("What did you eat?", text: $mealInput)
            
            Picker("Meal Type", selection: $selectedMealType) {
                Text("Breakfast").tag("breakfast")
                Text("Lunch").tag("lunch")
                Text("Dinner").tag("dinner")
                Text("Snack").tag("snack")
            }
            
            DatePicker("Date & Time", selection: $selectedDate)
            TextField("Notes (optional)", text: $notes)
            
            Button("Save Meal") {
                Task {
                    // ✅ CALL THE VIEWMODEL METHOD
                    await viewModel.saveMealLog(
                        rawInput: mealInput,
                        mealType: selectedMealType,
                        loggedAt: selectedDate,
                        notes: notes.isEmpty ? nil : notes
                    )
                }
            }
            .disabled(mealInput.isEmpty || viewModel.isLoading)
        }
    }
}
```

---

## 📋 Complete Integration Checklist

### Phase 1: ViewModel Update
- [ ] Update `NutritionViewModel.swift`
  - [ ] Remove mock `DailyMealLog` struct (keep as UI adapter)
  - [ ] Add dependencies: `saveMealLogUseCase`, `getMealLogsUseCase`
  - [ ] Update `loadDataForSelectedDate()` to call real use case
  - [ ] Add `saveMealLog()` method
  - [ ] Add `DailyMealLog.from(mealLog:)` mapper method

### Phase 2: View Update
- [ ] Update `NutritionView.swift`
  - [ ] Change `init` to accept use cases
  - [ ] Create `NutritionViewModel` with injected dependencies
  - [ ] Pass dependencies from parent view

### Phase 3: Parent View Update
- [ ] Find where `NutritionView` is instantiated
  - [ ] Inject `appDependencies.saveMealLogUseCase`
  - [ ] Inject `appDependencies.getMealLogsUseCase`

### Phase 4: AddMealView Update
- [ ] Update `AddMealView.swift`
  - [ ] Add form fields for meal logging
  - [ ] Call `viewModel.saveMealLog()` on submit
  - [ ] Show loading/error states

### Phase 5: Testing
- [ ] Test saving a meal log
- [ ] Test fetching meal logs for a date
- [ ] Test date picker changes
- [ ] Test offline mode
- [ ] Test Outbox Pattern sync

---

## 🎯 Expected Behavior After Integration

### User Flow

1. **User opens NutritionView**
   - `loadDataForSelectedDate()` is called
   - `GetMealLogsUseCase` fetches meal logs for today
   - Meal logs are displayed in grouped list

2. **User taps FAB (+) button**
   - `AddMealView` sheet opens
   - User enters: "2 eggs, toast, coffee"
   - User selects meal type: "breakfast"
   - User taps "Save"

3. **Save flow**
   - `viewModel.saveMealLog()` is called
   - `SaveMealLogUseCase.execute()` is called
   - Meal log saved locally with status `.pending`
   - Outbox event created automatically
   - View refreshes to show new meal (status: pending)

4. **Background sync**
   - `OutboxProcessorService` syncs to backend
   - Backend processes meal log (AI parsing)
   - Status updates: `.pending` → `.processing` → `.completed`
   - Parsed items are populated
   - View can refresh to show completed meal with nutrition data

---

## 🚨 Important Notes

### Data Mapping

The domain `MealLog` has different fields than the UI `DailyMealLog`:

| Domain Model (`MealLog`) | UI Model (`DailyMealLog`) |
|--------------------------|---------------------------|
| `rawInput: String` | `name: String` |
| `loggedAt: Date` | `time: Date` |
| `totalCalories: Double` | `calories: Int` |
| `totalProteinG: Double` | `protein: Int` |
| `items: [MealLogItem]` | (individual nutrients) |

**Solution:** Use `DailyMealLog.from(mealLog:)` mapper to convert.

### Micronutrients

The domain model doesn't currently track:
- Sugar
- Fiber
- Saturated Fat
- Sodium
- Iron
- Vitamin C

**Options:**
1. **Option A:** Calculate from `MealLogItem` array (if backend provides)
2. **Option B:** Set to `0` for now and add later
3. **Option C:** Remove from UI until backend supports

**Recommendation:** Use Option B for now (set to 0).

### Status Indicators

Show processing status to user:
- **Pending** - "Processing your meal..."
- **Processing** - "Analyzing nutrition..."
- **Completed** - Show full details
- **Failed** - "Failed to process meal"

---

## 📚 Related Files

### Files to Modify
1. `FitIQ/Presentation/ViewModels/NutritionViewModel.swift` ⚠️ **MUST UPDATE**
2. `FitIQ/Presentation/UI/Nutrition/NutritionView.swift` ⚠️ **MUST UPDATE**
3. `FitIQ/Presentation/UI/Nutrition/AddMealView.swift` ⚠️ **MUST UPDATE**
4. Parent view that instantiates `NutritionView` ⚠️ **MUST UPDATE**

### Files Already Complete
1. `FitIQ/Domain/UseCases/Nutrition/SaveMealLogUseCase.swift` ✅
2. `FitIQ/Domain/UseCases/Nutrition/GetMealLogsUseCase.swift` ✅
3. `FitIQ/Infrastructure/Repositories/CompositeMealLogRepository.swift` ✅
4. `FitIQ/Infrastructure/Configuration/AppDependencies.swift` ✅

---

## 🎓 Summary

**Current State:**
- ✅ Infrastructure is 100% complete
- ❌ UI is not connected (using mock data)

**Required Work:**
1. Update `NutritionViewModel` to inject and use real use cases
2. Update `NutritionView` initialization to pass dependencies
3. Update parent view to pass `appDependencies.saveMealLogUseCase` and `getMealLogsUseCase`
4. Update `AddMealView` to call `viewModel.saveMealLog()`

**Estimated Effort:** 1-2 hours

**Priority:** HIGH (feature is complete but not usable until connected)

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27  
**Status:** Ready for Implementation