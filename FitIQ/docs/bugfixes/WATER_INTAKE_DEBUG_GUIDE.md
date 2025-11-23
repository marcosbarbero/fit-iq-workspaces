# Water Intake Debug Guide

**Date:** 2025-01-27  
**Issue:** Water intake showing incorrect values (e.g., 2.5L + 500mL = 3.5L instead of 3.0L)  
**Status:** 🔍 Investigation In Progress

---

## Current Issue

**Reported Behavior:**
- Starting water intake: 2.5L
- User adds: 500mL water
- Expected result: 3.0L
- Actual result: 3.5L
- **Difference: +1.0L extra**

---

## Debugging Steps

### Step 1: Check Console Logs

When you log a meal with water, look for these log entries:

```
NutritionViewModel: 💧 ========== trackWaterIntake CALLED ==========
NutritionViewModel: 💧 Total items: X
NutritionViewModel: 💧 Found X water item(s) to track
NutritionViewModel: 💧 Water item #1: 'Water', quantity: '500 mL', foodType: water
NutritionViewModel: 💧 Parsing water item 'Water': '500 ml' (lowercase: '500 ml')
NutritionViewModel: 💧   Extracted numeric value: 500.0
NutritionViewModel: 💧   Unit: mL → 0.500L
NutritionViewModel: 💧   Running total: 0.500L
NutritionViewModel: 💧 Total water intake: 0.50L
NutritionViewModel: 💧 Calling SaveWaterProgressUseCase with 0.500L
```

**Check for:**
1. How many water items are detected?
2. What is the quantity string? (e.g., "500 mL", "500 ml", "0.5 L")
3. What numeric value is extracted?
4. What unit is detected?
5. What is the final total sent to SaveWaterProgressUseCase?

### Step 2: Check SaveWaterProgressUseCase Logs

```
SaveWaterProgressUseCase: Saving 0.5L for user <UUID> on <DATE>
SaveWaterProgressUseCase: Found X existing water entries in local storage
SaveWaterProgressUseCase: Found existing entry with ID: <UUID>
SaveWaterProgressUseCase: Entry exists for <DATE> with 2.5L. Adding 0.5L for new total of 3.0L.
SaveWaterProgressUseCase: Successfully updated water intake progress. Local ID: <UUID>, Total: 3.0L
SaveWaterProgressUseCase: After update, total water entries: X
```

**Check for:**
1. What is the existing water amount? (Should be 2.5L)
2. What is being added? (Should be 0.5L)
3. What is the new total? (Should be 3.0L)
4. How many total entries exist after update? (Should be 1 or 2 at most)

### Step 3: Check GetTodayWaterIntakeUseCase Logs

```
GetTodayWaterIntakeUseCase: Fetching water intake for user <UUID>
GetTodayWaterIntakeUseCase: Found X local water entries for today
GetTodayWaterIntakeUseCase: Latest water intake today: 3.00L (from X entries)
```

**Check for:**
1. How many entries are found? (Should be 1-2)
2. What is the latest entry's value? (Should be 3.0L)
3. If > 1 entry, we have duplicates (but handled gracefully)

### Step 4: Check UI Refresh Logs

```
NutritionViewModel: 💧 Refreshing UI with latest water intake from local storage...
NutritionSummaryViewModel: Loaded water intake: 3.00L
NutritionViewModel: 💧 UI refresh complete. Current display: 3.0L
```

**Check for:**
1. What value is loaded from local storage?
2. Does it match the SaveWaterProgressUseCase total?

---

## Possible Root Causes

### 1. Unit Parsing Issue

**Symptom:** Backend sends quantity in unexpected format

**Examples:**
- Backend sends: `quantity: 0.5, unit: "L"` → Parsed as 0.5L ✅
- Backend sends: `quantity: 500, unit: "mL"` → Parsed as 0.5L ✅
- Backend sends: `quantity: 500, unit: "ml"` → Parsed as 0.5L ✅
- Backend sends: `quantity: 500, unit: ""` → Parsed as 0.5L (assumes mL) ✅

**But might fail if:**
- Backend sends: `quantity: 0.5, unit: "liters"` → Parsed as 0.5L ✅
- Backend sends: `quantity: 500, unit: "milliliters"` → Parsed as 0.5L ✅
- Backend sends: `quantity: 0.5, unit: "l"` → Might match "ml" check incorrectly ⚠️

**Check logs for:**
```
NutritionViewModel: 💧 Parsing water item 'Water': '0.5 l' (lowercase: '0.5 l')
NutritionViewModel: 💧   Extracted numeric value: 0.5
NutritionViewModel: 💧   Unit: ??? → ???L
```

### 2. Multiple Water Items

**Symptom:** Meal contains multiple water items that are all being summed

**Example:**
- Item 1: Water 500mL → 0.5L
- Item 2: Water 1000mL → 1.0L
- Total: 1.5L (but maybe only expected 0.5L)

**Check logs for:**
```
NutritionViewModel: 💧 Found 2 water item(s) to track
NutritionViewModel: 💧 Water item #1: 'Water', quantity: '500 mL'
NutritionViewModel: 💧 Water item #2: 'Water', quantity: '1000 mL'
```

### 3. Duplicate Entries in Database

**Symptom:** Multiple entries exist for same day, and GetTodayWaterIntakeUseCase returns wrong one

**Example:**
- Entry 1: 2.5L (old)
- Entry 2: 3.5L (new, but incorrectly calculated)
- Latest returned: 3.5L ❌

**Check logs for:**
```
GetTodayWaterIntakeUseCase: Found 3 local water entries for today
SaveWaterProgressUseCase: After update, total water entries: 3
```

If `> 1 entry`, we have duplicates.

### 4. Aggregation Logic Error

**Symptom:** SaveWaterProgressUseCase is adding wrong amount

**Example:**
- Existing: 2.5L
- Adding: 0.5L
- New total: 3.5L ❌ (should be 3.0L)

**This would mean:**
- Either existing value is wrong (2.5L is actually 3.0L)
- Or the incoming value is wrong (0.5L is actually 1.0L)

**Check logs for:**
```
SaveWaterProgressUseCase: Entry exists with 2.5L. Adding 0.5L for new total of 3.0L.
```

If log shows 3.0L but UI shows 3.5L, issue is elsewhere.

### 5. Multiple Meals with Water

**Symptom:** User logged multiple meals with water in quick succession

**Example:**
- Meal 1: 500mL water at 14:00
- Meal 2: 500mL water at 14:01 (WebSocket delayed)
- Both process simultaneously → race condition

**Check logs for:**
```
NutritionViewModel: 💧 ========== trackWaterIntake CALLED ==========
(multiple times in quick succession)
```

### 6. Backend Returning Wrong Unit

**Symptom:** Backend AI parsed "500mL" as "0.5L" in quantity field

**Example:**
- User input: "500mL water"
- Backend parses: `quantity: 0.5, unit: "L"` (already converted)
- iOS receives: "0.5 L"
- iOS parses: 0.5L ✅
- But maybe backend meant: `quantity: 500, unit: "mL"`

**Check logs for:**
```
NutritionViewModel: 💧 Water item #1: 'Water', quantity: '0.5 L', foodType: water
```

If quantity already shows "0.5 L" from backend, check if backend is double-converting.

---

## Debugging Commands

### Print All Water Entries in Database

Add this to your code temporarily:

```swift
// In GetTodayWaterIntakeUseCase.execute()
print("=== ALL WATER ENTRIES FOR TODAY ===")
for (index, entry) in localEntries.enumerated() {
    print("Entry #\(index + 1):")
    print("  ID: \(entry.id)")
    print("  Quantity: \(entry.quantity)L")
    print("  Date: \(entry.date)")
    print("  Status: \(entry.syncStatus)")
    print("  Backend ID: \(entry.backendID ?? "nil")")
}
print("=== END ===")
```

### Check Backend Response

Add logging to see what backend actually sends:

```swift
// In NutritionViewModel.handleMealLogCompleted()
print("=== MEAL LOG PAYLOAD ===")
print("Meal ID: \(payload.id)")
print("Items count: \(payload.items.count)")
for (index, item) in payload.items.enumerated() {
    print("Item #\(index + 1):")
    print("  Name: \(item.foodName)")
    print("  Quantity: \(item.quantity)")
    print("  Unit: \(item.unit)")
    print("  Food Type: \(item.foodType)")
}
print("=== END ===")
```

---

## Expected Correct Flow

```
1. User logs: "500mL water"
    ↓
2. Backend parses: quantity=500, unit="mL", food_type="water"
    ↓
3. WebSocket payload:
   {
     "food_name": "Water",
     "quantity": 500,
     "unit": "mL",
     "food_type": "water"
   }
    ↓
4. iOS creates MealLogItem:
   quantity: "500 mL" (combined)
   foodType: .water
    ↓
5. trackWaterIntake() filters:
   Found 1 water item: "500 mL"
    ↓
6. Parse quantity:
   Extracted: 500.0
   Unit: mL
   Converted: 0.5L
    ↓
7. SaveWaterProgressUseCase:
   Existing: 2.5L
   Adding: 0.5L
   New total: 3.0L
    ↓
8. GetTodayWaterIntakeUseCase:
   Latest entry: 3.0L
    ↓
9. UI displays: "3.0 / 2.5 Liters" ✅
```

---

## Quick Fixes to Try

### Fix 1: Clear All Water Entries

If there are duplicate entries, clear them:

```swift
// Temporary: Delete all water entries for today
let entries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .waterLiters,
    syncStatus: nil,
    limit: 100
)

for entry in entries {
    try await progressRepository.delete(entry.id, forUserID: userID)
}

// Then log water again
```

### Fix 2: Check for Off-by-One in Unit Detection

The unit detection logic might be matching "ml" when it should match "l":

```swift
// OLD (potentially buggy):
} else if quantityString.contains("l") && !quantityString.contains("ml") {

// NEW (more explicit):
} else if quantityString.contains(" l") || quantityString.hasSuffix("l") {
```

### Fix 3: Add Unit Validation

Add assertion to verify conversion:

```swift
if itemLiters > 10.0 {
    print("⚠️ WARNING: Suspiciously high water amount: \(itemLiters)L from '\(item.quantity)'")
}
```

---

## Next Steps

1. **Collect logs** from next water logging attempt
2. **Share logs** showing:
   - trackWaterIntake entry
   - All water items detected
   - Unit parsing details
   - SaveWaterProgressUseCase aggregation
   - GetTodayWaterIntakeUseCase result
3. **Verify backend data** - Check what backend actually sends
4. **Check for duplicates** - See how many entries exist

---

## Contact

If issue persists after collecting logs, provide:
1. Full console output from water logging
2. Number of water entries in database
3. Backend payload (if available)
4. Expected vs actual behavior

**Status:** 🔍 Awaiting logs to identify root cause  
**Priority:** High (Incorrect data calculation)  
**Version:** 1.1.1 (With debug logging)