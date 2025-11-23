# Water Tracking Flow Diagram

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Visual representation of water intake tracking flow

---

## High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER LOGS MEAL WITH WATER                   │
│                    (e.g., "500ml water, chicken")                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              NutritionViewModel.handleMealLogCompleted()         │
│                                                                   │
│  1. Receive MealLogCompletedPayload from WebSocket               │
│  2. Extract meal items (food + water)                            │
│  3. Call trackWaterIntake(from: items)                           │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              NutritionViewModel.trackWaterIntake()               │
│                                                                   │
│  1. Filter water items: items.filter { $0.foodType == .water }  │
│  2. Convert to liters:                                           │
│     - ml → L: quantity / 1000                                    │
│     - cups → L: quantity * 0.237                                 │
│     - oz → L: quantity * 0.0296                                  │
│  3. Sum total: totalWaterLiters = sum of all water items         │
│  4. Call SaveWaterProgressUseCase.execute(liters: total)         │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              SaveWaterProgressUseCase.execute()                  │
│                                                                   │
│  1. Fetch existing water entries for user                        │
│  2. Normalize dates to start of day                              │
│  3. Search for entry on same calendar day                        │
│                                                                   │
│     ┌──────────────────┐         ┌──────────────────┐           │
│     │ Entry Found?     │         │ Entry Found?     │           │
│     │      YES         │         │       NO         │           │
│     └────────┬─────────┘         └────────┬─────────┘           │
│              │                            │                      │
│              ▼                            ▼                      │
│     ┌────────────────────────┐  ┌────────────────────────┐      │
│     │ AGGREGATE              │  │ CREATE NEW             │      │
│     │                        │  │                        │      │
│     │ newTotal =             │  │ quantity = liters      │      │
│     │   existing + liters    │  │ date = today           │      │
│     │                        │  │ id = UUID()            │      │
│     │ Keep same:             │  │                        │      │
│     │ - id (existing.id)     │  └───────────┬────────────┘      │
│     │ - date (existing.date) │              │                   │
│     │                        │              │                   │
│     │ Update:                │              │                   │
│     │ - quantity (newTotal)  │              │                   │
│     │ - updatedAt (now)      │              │                   │
│     │ - backendID (nil)      │              │                   │
│     │ - syncStatus (pending) │              │                   │
│     └───────────┬────────────┘              │                   │
│                 │                           │                   │
│                 └───────────┬───────────────┘                   │
│                             ▼                                    │
│              repository.save(progressEntry)                      │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│           SwiftDataProgressRepository.save()                     │
│                                                                   │
│  1. Search for duplicate by date range:                          │
│     - userID matches                                             │
│     - type = "water_liters"                                      │
│     - time = nil                                                 │
│     - date >= startOfDay AND date < endOfDay                     │
│                                                                   │
│     ┌──────────────────┐         ┌──────────────────┐           │
│     │ Duplicate Found? │         │ Duplicate Found? │           │
│     │      YES         │         │       NO         │           │
│     └────────┬─────────┘         └────────┬─────────┘           │
│              │                            │                      │
│              ▼                            ▼                      │
│     ┌────────────────────────┐  ┌────────────────────────┐      │
│     │ UPDATE EXISTING        │  │ INSERT NEW             │      │
│     │                        │  │                        │      │
│     │ Check quantity change: │  │ modelContext.insert()  │      │
│     │ if changed:            │  │ modelContext.save()    │      │
│     │   - update quantity    │  │ Create outbox event    │      │
│     │   - update updatedAt   │  │                        │      │
│     │   - clear backendID    │  └────────────────────────┘      │
│     │   - mark pending       │                                   │
│     │   - save context       │                                   │
│     │   - create outbox      │                                   │
│     │                        │                                   │
│     │ Return existing.id     │                                   │
│     └────────────────────────┘                                   │
│                                                                   │
│  2. Notify LocalDataChangeMonitor for UI refresh                 │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              NutritionSummaryViewModel.loadWaterIntake()         │
│                                                                   │
│  Called to refresh UI after save                                 │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              GetTodayWaterIntakeUseCase.execute()                │
│                                                                   │
│  1. Fetch entries for today:                                     │
│     - startDate = calendar.startOfDay(for: now)                  │
│     - endDate = startDate + 1 day                                │
│                                                                   │
│  2. Sort by updatedAt (most recent first):                       │
│     - Primary: entry.updatedAt (DESC)                            │
│     - Secondary: entry.date (DESC)                               │
│                                                                   │
│  3. Return latestEntry.quantity                                  │
│     (This is the aggregated total for today)                     │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     UI DISPLAYS WATER INTAKE                     │
│                    (e.g., "1.75L / 3.0L goal")                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Example: Three Water Logs in One Day

### Initial State (Empty)
```
Database: []
UI: 0.0L
```

---

### Log #1: 500ml at 8:00 AM

```
trackWaterIntake(500ml)
    ↓
SaveWaterProgressUseCase
    ↓ No existing entry found
    ↓ Create new: { id: A, quantity: 0.5L, date: 08:00 }
    ↓
Repository.save()
    ↓ No duplicate found
    ↓ INSERT new entry
    ↓
Database: [Entry A: 0.5L (created: 08:00, updated: 08:00)]
    ↓
UI refresh
    ↓
GetTodayWaterIntake → returns 0.5L
    ↓
UI: 0.5L ✅
```

---

### Log #2: 750ml at 12:00 PM (same day)

```
trackWaterIntake(750ml)
    ↓
SaveWaterProgressUseCase
    ↓ Existing entry found: Entry A (0.5L)
    ↓ Aggregate: 0.5L + 0.75L = 1.25L
    ↓ Create updated: { id: A, quantity: 1.25L, date: 08:00, updatedAt: 12:00 }
    ↓
Repository.save()
    ↓ Duplicate found (same day, same ID)
    ↓ Quantity changed: 0.5L → 1.25L
    ↓ UPDATE existing entry: Entry A.quantity = 1.25L
    ↓
Database: [Entry A: 1.25L (created: 08:00, updated: 12:00)] ← UPDATED
    ↓
UI refresh
    ↓
GetTodayWaterIntake → returns 1.25L (from Entry A, most recent update)
    ↓
UI: 1.25L ✅
```

---

### Log #3: 500ml at 6:00 PM (same day)

```
trackWaterIntake(500ml)
    ↓
SaveWaterProgressUseCase
    ↓ Existing entry found: Entry A (1.25L)
    ↓ Aggregate: 1.25L + 0.5L = 1.75L
    ↓ Create updated: { id: A, quantity: 1.75L, date: 08:00, updatedAt: 18:00 }
    ↓
Repository.save()
    ↓ Duplicate found (same day, same ID)
    ↓ Quantity changed: 1.25L → 1.75L
    ↓ UPDATE existing entry: Entry A.quantity = 1.75L
    ↓
Database: [Entry A: 1.75L (created: 08:00, updated: 18:00)] ← UPDATED
    ↓
UI refresh
    ↓
GetTodayWaterIntake → returns 1.75L (from Entry A, most recent update)
    ↓
UI: 1.75L ✅
```

---

### Next Day: 600ml at 8:00 AM

```
trackWaterIntake(600ml)
    ↓
SaveWaterProgressUseCase
    ↓ Existing entries found: [Entry A]
    ↓ But Entry A is from YESTERDAY (2025-01-27)
    ↓ No entry found for TODAY (2025-01-28)
    ↓ Create new: { id: B, quantity: 0.6L, date: 08:00 }
    ↓
Repository.save()
    ↓ No duplicate found for today
    ↓ INSERT new entry
    ↓
Database: [
    Entry A: 1.75L (created: 2025-01-27 08:00, updated: 2025-01-27 18:00) ← Yesterday
    Entry B: 0.6L (created: 2025-01-28 08:00, updated: 2025-01-28 08:00)  ← Today
]
    ↓
UI refresh
    ↓
GetTodayWaterIntake → filters by today's date → returns 0.6L (from Entry B)
    ↓
UI: 0.6L ✅ (Yesterday's 1.75L is not included)
```

---

## Key Takeaways

### ✅ Aggregation
- Each water log **adds** to the daily total
- Formula: `newTotal = existingTotal + newAmount`
- Not replacement, not duplication, but **aggregation**

### ✅ Single Entry Per Day
- Only **one database entry** per calendar day
- Entry is **updated** with new total, not duplicated
- `createdAt` = first water log time
- `updatedAt` = most recent water log time

### ✅ Date Boundaries
- New calendar day = new entry
- Yesterday's total is **separate** from today's
- UI always shows **today's total only**

### ✅ Deduplication
- Repository prevents duplicates via date-range matching
- Use case reuses same entry ID for updates
- System guarantees: 1 entry per user per day per type

---

## Console Verification

### Expected Logs (Correct Behavior)

**First water log:**
```
SaveWaterProgressUseCase: ✅ NO EXISTING ENTRY
SaveWaterProgressUseCase: 💧   Creating new entry with 0.500L
SwiftDataProgressRepository: ✅ NEW ENTRY - No duplicate found
```

**Second water log (same day):**
```
SaveWaterProgressUseCase: ✅ EXISTING ENTRY FOUND
SaveWaterProgressUseCase: 💧   Current quantity: 0.500L
SaveWaterProgressUseCase: 💧   Input to add: 0.750L
SaveWaterProgressUseCase: 💧   NEW TOTAL: 1.250L
SwiftDataProgressRepository: 🔄 UPDATING quantity: 0.500 → 1.250
```

**Third water log (same day):**
```
SaveWaterProgressUseCase: ✅ EXISTING ENTRY FOUND
SaveWaterProgressUseCase: 💧   Current quantity: 1.250L
SaveWaterProgressUseCase: 💧   Input to add: 0.500L
SaveWaterProgressUseCase: 💧   NEW TOTAL: 1.750L
SwiftDataProgressRepository: 🔄 UPDATING quantity: 1.250 → 1.750
```

---

**Status:** ✅ Flow Verified Correct  
**Recommendation:** Use this diagram to understand water tracking behavior  
**Note:** All logs show the system is working as designed
