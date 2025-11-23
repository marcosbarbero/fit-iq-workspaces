# Domain Model Refactor - Valence & Labels

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** ✅ Infrastructure Complete, 🔄 Presentation Layer Pending

---

## Overview

The Lume iOS app has been refactored to align the domain model with the backend API and Apple HealthKit's mental wellness standards. This eliminates impedance mismatch and simplifies the codebase.

---

## What Changed

### Before (Old Model)

```swift
struct MoodEntry {
    let mood: MoodKind              // Enum: peaceful, calm, happy, etc.
    let intensity: Int              // 1-10 scale
    let note: String?               // Optional note
}

enum MoodKind: String {
    case peaceful, calm, content, happy, excited
    case energetic, tired, sad, anxious, stressed
}
```

### After (New Model)

```swift
struct MoodEntry {
    let valence: Double             // -1.0 to 1.0 (HealthKit standard)
    let labels: [String]            // ["happy", "excited"]
    let associations: [String]      // ["work", "family"]
    let notes: String?              // Optional notes (plural)
    let source: MoodSource          // .manual or .healthkit
    let sourceId: String?           // External source ID
}

enum MoodLabel: String {
    case peaceful, calm, content, happy, excited
    case energetic, tired, sad, anxious, stressed
    
    var defaultValence: Double { ... }
}

enum MoodSource: String {
    case manual, healthkit
}
```

---

## Why This Change?

### 1. **API Alignment**
- Backend uses `valence` + `labels` + `associations`
- Old model required constant conversion at service boundary
- New model: 1:1 mapping with backend

### 2. **HealthKit Compatibility**
- Apple HealthKit uses valence (-1.0 to 1.0) for mental wellness
- Prepares for future HealthKit integration
- Scientifically grounded emotional measurement

### 3. **Future-Proof**
- Supports multiple mood labels per entry
- Supports contextual associations
- Extensible for new features

### 4. **Cleaner Architecture**
- No conversion logic needed in services
- Domain model matches infrastructure
- Simpler, more maintainable code

---

## Files Changed

### ✅ Complete (Infrastructure Layer)

1. **Domain Layer**
   - `lume/Domain/Entities/MoodEntry.swift` - New structure with valence/labels
   - Added `MoodLabel` enum with default valence values
   - Added `MoodAssociation` enum for contextual factors
   - Added `MoodSource` enum for manual vs HealthKit
   - Added `ValenceCategory` for UI display

2. **Data Layer**
   - `lume/Data/Persistence/SchemaVersioning.swift` - Added SchemaV4
   - `lume/Data/Repositories/MoodRepository.swift` - Updated mapping
   - `lume/Data/Repositories/MockMoodRepository.swift` - Updated sample data

3. **Services Layer**
   - `lume/Services/Backend/MoodBackendService.swift` - Simplified (no conversion)

4. **Tests**
   - `lumeTests/MoodBackendServiceTests.swift` - Updated for new model

### 🔄 TODO (Presentation Layer)

The following files need to be updated to work with the new model:

1. **ViewModels**
   - `MoodViewModel.swift` - Update to create entries with valence/labels
   - `MoodDashboardViewModel.swift` - Update mood aggregation logic

2. **Views**
   - `MoodTrackingView.swift` - Update mood selection UI
   - `MoodDashboardView.swift` - Update mood display
   - Any other views that reference `MoodEntry.mood` or `.intensity`

---

## Migration Strategy

### Database Migration

**SchemaV4** added to SchemaVersioning:

```swift
@Model
final class SDMoodEntry {
    var id: UUID
    var userId: UUID
    var date: Date
    var valence: Double              // NEW: -1.0 to 1.0
    var labels: [String]             // NEW: mood labels
    var associations: [String]       // NEW: contextual factors
    var notes: String?               // RENAMED: from 'note'
    var source: String               // NEW: "manual" or "healthkit"
    var sourceId: String?            // NEW: external ID
    var backendId: String?           // KEPT: for sync
    var createdAt: Date
    var updatedAt: Date
}
```

**Migration Path:**
- V3 → V4 is marked as lightweight migration
- SwiftData will handle schema changes
- **User Action Required:** Delete and reinstall app (confirmed by user)

### Creating Mood Entries

**Old Way:**
```swift
let entry = MoodEntry(
    userId: userId,
    date: Date(),
    mood: .happy,
    intensity: 8,
    note: "Great day!"
)
```

**New Way (Option 1 - Direct):**
```swift
let entry = MoodEntry(
    userId: userId,
    date: Date(),
    valence: 0.6,              // -1.0 to 1.0
    labels: ["happy"],
    associations: [],
    notes: "Great day!"
)
```

**New Way (Option 2 - Convenience):**
```swift
let entry = MoodEntry(
    userId: userId,
    date: Date(),
    moodLabel: .happy,         // Uses default valence
    notes: "Great day!"
)
```

---

## UI Changes Required

### Mood Selection

**Current:** User selects a single `MoodKind` enum value

**New Options:**

1. **Simple (Phase 1):** Keep single mood selection
   - UI selects one `MoodLabel`
   - Use `defaultValence` from label
   - Store as single-item array in `labels`
   
2. **Advanced (Phase 2):** Multiple mood selection
   - UI allows multiple `MoodLabel` selections
   - Calculate average valence or let user adjust
   - Store all labels in array

3. **Valence Slider (Phase 3):** Direct valence input
   - Show slider from "Unpleasant" to "Pleasant"
   - User sets exact valence value
   - Optional: Suggest labels based on valence

### Mood Display

**Current:** Display mood icon and name from `MoodKind`

**New Approach:**
```swift
// Get primary mood label
if let primaryLabel = entry.primaryMoodLabel {
    Text(primaryLabel.displayName)
    Image(systemName: primaryLabel.systemImage)
    Color(hex: primaryLabel.color)
}

// Or display valence category
Text(entry.valenceCategory.rawValue)
Color(hex: entry.valenceCategory.color)

// Or show valence as percentage
Text("\(entry.valencePercentage)% Pleasant")
```

---

## Code Examples

### Creating Entry in ViewModel

```swift
// In MoodViewModel or similar

func logMood(label: MoodLabel, notes: String?) async {
    let entry = MoodEntry(
        userId: currentUserId,
        date: Date(),
        moodLabel: label,        // Convenience init
        notes: notes
    )
    
    try await moodRepository.save(entry)
}
```

### Displaying Entry in View

```swift
struct MoodEntryCard: View {
    let entry: MoodEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            // Show primary label
            if let label = entry.primaryMoodLabel {
                HStack {
                    Image(systemName: label.systemImage)
                    Text(label.displayName)
                }
                .foregroundColor(Color(hex: label.color))
            }
            
            // Show valence as bar
            ValenceBar(valence: entry.valence)
            
            // Show notes
            if let notes = entry.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

### Valence Helpers

```swift
// Convert valence to user-friendly category
entry.valenceCategory  // .pleasant, .veryPleasant, etc.

// Convert valence to percentage (0-100)
entry.valencePercentage  // 80 (for valence = 0.6)

// Get primary mood label
entry.primaryMoodLabel  // MoodLabel.happy

// Get all labels
entry.labels  // ["happy", "excited"]
```

---

## Testing Checklist

### Infrastructure (✅ Complete)

- [x] Domain model compiles
- [x] Repository saves/fetches new model
- [x] Backend service sends correct format
- [x] Schema migration defined
- [x] Unit tests updated

### Presentation (🔄 TODO)

- [ ] ViewModels create entries with valence/labels
- [ ] Views display primary mood label
- [ ] Mood selection UI works
- [ ] Mood history displays correctly
- [ ] Pull-to-refresh sync works
- [ ] Create mood entry flow works
- [ ] Edit mood entry works
- [ ] Delete mood entry works

### Integration (🔄 TODO)

- [ ] Create mood → Save locally → Sync to backend
- [ ] Fetch from backend → Parse → Display
- [ ] Offline mode queuing works
- [ ] Error handling works

---

## Rollout Plan

### Phase 1: Infrastructure (✅ Complete)
- Update domain model
- Update database schema
- Update repository
- Update backend service
- Update tests

### Phase 2: Basic Presentation (🔄 Current)
- Update mood creation to use single label
- Update mood display to show primary label
- Keep UI similar to current design
- Test end-to-end flow

### Phase 3: Enhanced Features (Future)
- Add multiple label selection
- Add valence slider
- Add associations selection
- Add HealthKit integration

---

## Breaking Changes

### API Breaking Changes

❌ **Removed:**
```swift
entry.mood         // MoodKind enum
entry.intensity    // Int (1-10)
entry.note         // String? (singular)
```

✅ **Added:**
```swift
entry.valence           // Double (-1.0 to 1.0)
entry.labels            // [String]
entry.associations      // [String]
entry.notes             // String? (plural)
entry.source            // MoodSource
entry.sourceId          // String?
```

✅ **Convenience Access:**
```swift
entry.primaryLabel         // String?
entry.primaryMoodLabel     // MoodLabel?
entry.valenceCategory      // ValenceCategory
entry.valencePercentage    // Int (0-100)
```

### Database Breaking Changes

- **SchemaV4** introduced with new fields
- **Migration:** Lightweight (but delete/reinstall recommended)
- **Old data:** Not preserved (fresh start)

---

## Documentation

### Created
- [DOMAIN_MODEL_REFACTOR.md](DOMAIN_MODEL_REFACTOR.md) - This file
- [MOOD_API_MIGRATION.md](MOOD_API_MIGRATION.md) - API changes
- [MOOD_API_CHANGES_SUMMARY.md](MOOD_API_CHANGES_SUMMARY.md) - Quick reference
- [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) - Status

### Updated
- Domain model includes comprehensive inline docs
- `MoodLabel` enum has `defaultValence` for each mood
- `MoodAssociation` enum ready for future use

---

## Benefits Summary

### ✅ Pros
- Aligns with backend API (no conversion needed)
- Aligns with Apple HealthKit standards
- Supports multiple mood labels
- Supports contextual associations
- Scientifically grounded measurement
- Simpler service layer
- Future-proof architecture

### ⚠️ Cons
- Breaking change (requires app reinstall)
- More complex than simple enum
- Presentation layer needs updates

### 💡 Decision
The benefits outweigh the costs. The refactor makes the codebase cleaner, more maintainable, and ready for future enhancements like HealthKit integration.

---

## Next Steps

1. **Update Presentation Layer** (Priority 1)
   - Start with `MoodTrackingView` - mood creation UI
   - Update `MoodViewModel` - create entries with labels
   - Test create mood flow end-to-end

2. **Update Display Logic** (Priority 2)
   - Update `MoodDashboardView` - show valence/labels
   - Update any other views displaying moods
   - Test mood history display

3. **Test Integration** (Priority 3)
   - Test sync with backend
   - Test offline mode
   - Test error handling

4. **Future Enhancements** (Priority 4)
   - Add multiple label selection UI
   - Add valence slider
   - Add associations selector
   - Add HealthKit integration

---

## References

- [Backend API Swagger](swagger.yaml)
- [MoodEntry Domain Model](../../lume/Domain/Entities/MoodEntry.swift)
- [SchemaVersioning](../../lume/Data/Persistence/SchemaVersioning.swift)
- [Apple HealthKit Mental Wellness](https://developer.apple.com/documentation/healthkit/mental_well_being)

---

## Summary

The domain model has been successfully refactored to use `valence` and `labels` instead of `mood` and `intensity`. This aligns with the backend API and Apple HealthKit standards, eliminating conversion logic and preparing for future enhancements.

**Infrastructure layer is complete. Presentation layer updates are next.**