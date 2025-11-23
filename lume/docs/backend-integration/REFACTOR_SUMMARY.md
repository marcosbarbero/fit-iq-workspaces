# Domain Model Refactor - Executive Summary

**Date:** 2025-01-15  
**Status:** ✅ Infrastructure Complete | 🔄 UI Updates Required  
**Impact:** Breaking change - requires app reinstall  
**Scope:** Backend API alignment + HealthKit preparation

---

## TL;DR

The iOS app's mood tracking model has been refactored from `mood: MoodKind` + `intensity: Int` to `valence: Double` + `labels: [String]` to match the backend API and Apple HealthKit standards.

**What's Done:**
- ✅ Domain model refactored
- ✅ Database schema updated (SchemaV4)
- ✅ Repository layer updated
- ✅ Backend service simplified
- ✅ Tests updated

**What's Next:**
- 🔄 Update ViewModels to create entries with new model
- 🔄 Update Views to display valence/labels
- 🔄 Test end-to-end flow

---

## The Change

### Before
```swift
struct MoodEntry {
    let mood: MoodKind        // Enum: .happy, .sad, etc.
    let intensity: Int        // 1-10 scale
    let note: String?
}
```

### After
```swift
struct MoodEntry {
    let valence: Double       // -1.0 (unpleasant) to 1.0 (pleasant)
    let labels: [String]      // ["happy", "excited"]
    let associations: [String] // ["work", "family"]
    let notes: String?
    let source: MoodSource    // .manual or .healthkit
}
```

---

## Why This Matters

### 1. **No More Conversion Logic**
- **Before:** Convert between mood/intensity ↔ valence/labels at service boundary
- **After:** Domain model matches backend API 1:1
- **Result:** Simpler, cleaner code

### 2. **HealthKit Ready**
- Apple HealthKit uses valence (-1.0 to 1.0) for mental wellness
- Future HealthKit integration will be seamless
- Scientifically grounded emotional measurement

### 3. **More Flexible**
- Can store multiple mood labels per entry
- Can add contextual associations (work, family, etc.)
- Extensible for future features

---

## What You Need to Know

### If You're Working on UI/Views:

**Old way to create mood:**
```swift
MoodEntry(
    userId: userId,
    date: Date(),
    mood: .happy,
    intensity: 8,
    note: "Great day!"
)
```

**New way (convenience init):**
```swift
MoodEntry(
    userId: userId,
    date: Date(),
    moodLabel: .happy,    // Uses default valence
    notes: "Great day!"
)
```

**New way (direct):**
```swift
MoodEntry(
    userId: userId,
    date: Date(),
    valence: 0.6,         // -1.0 to 1.0
    labels: ["happy"],
    notes: "Great day!"
)
```

### If You're Displaying Moods:

**Old way:**
```swift
Text(entry.mood.displayName)
Image(systemName: entry.mood.systemImage)
```

**New way:**
```swift
// Use primary label
if let label = entry.primaryMoodLabel {
    Text(label.displayName)
    Image(systemName: label.systemImage)
}

// Or use valence category
Text(entry.valenceCategory.rawValue)  // "Pleasant"

// Or show percentage
Text("\(entry.valencePercentage)% Pleasant")  // "80% Pleasant"
```

---

## Database Migration

- **SchemaV4** added with new fields
- **Migration type:** Lightweight
- **Recommendation:** Delete and reinstall app (user confirmed OK)
- **Data loss:** Acceptable (fresh start)

---

## Files Changed

### ✅ Infrastructure (Complete)
- `Domain/Entities/MoodEntry.swift` - New model structure
- `Data/Persistence/SchemaVersioning.swift` - Added SchemaV4
- `Data/Repositories/MoodRepository.swift` - Updated mapping
- `Data/Repositories/MockMoodRepository.swift` - Updated samples
- `Services/Backend/MoodBackendService.swift` - Simplified
- `lumeTests/MoodBackendServiceTests.swift` - Updated tests

### 🔄 UI (Needs Update)
- `Presentation/Features/Mood/MoodTrackingView.swift`
- `Presentation/Features/Mood/MoodViewModel.swift`
- `Presentation/Features/Mood/MoodDashboardView.swift`
- Any other views referencing `entry.mood` or `entry.intensity`

---

## Breaking Changes

### Removed Properties
```swift
entry.mood         // ❌ No longer exists
entry.intensity    // ❌ No longer exists
entry.note         // ❌ Renamed to .notes (plural)
```

### New Properties
```swift
entry.valence           // Double (-1.0 to 1.0)
entry.labels            // [String]
entry.associations      // [String]
entry.notes             // String? (plural)
entry.source            // MoodSource (.manual or .healthkit)
entry.sourceId          // String?
```

### Convenience Access
```swift
entry.primaryLabel         // String? - First label
entry.primaryMoodLabel     // MoodLabel? - As enum
entry.valenceCategory      // ValenceCategory - "Pleasant", etc.
entry.valencePercentage    // Int - 0 to 100
entry.hasNote              // Bool - Still works
entry.notePreview          // String - Still works
```

---

## New Enums

### MoodLabel
```swift
enum MoodLabel: String {
    case peaceful, calm, content, happy, excited
    case energetic, tired, sad, anxious, stressed
    
    var displayName: String { ... }
    var systemImage: String { ... }
    var color: String { ... }
    var defaultValence: Double { ... }
    var reflectionPrompt: String { ... }
}
```

### MoodSource
```swift
enum MoodSource: String {
    case manual      // User-entered
    case healthkit   // From Apple Health
}
```

### MoodAssociation
```swift
enum MoodAssociation: String {
    case work, family, health, weather
    case fitness, social, travel, hobbies
    case dating, currentEvents, finances, education
    
    var displayName: String { ... }
    var systemImage: String { ... }
}
```

### ValenceCategory
```swift
enum ValenceCategory: String {
    case veryUnpleasant, unpleasant, neutral
    case pleasant, veryPleasant
    
    var color: String { ... }
}
```

---

## Testing Requirements

### Infrastructure (✅ Done)
- Domain model compiles
- Repository CRUD operations work
- Backend service sends/receives correct format
- Unit tests pass

### UI (🔄 TODO)
- Create mood entry with new model
- Display mood with valence/labels
- Edit mood entry
- Delete mood entry
- Mood history view
- Pull-to-refresh sync

### Integration (🔄 TODO)
- End-to-end: Create → Save → Sync → Fetch → Display
- Offline mode with outbox pattern
- Error handling

---

## Rollout Plan

### Phase 1: Infrastructure ✅
- Update domain model
- Update database schema
- Update repositories
- Update services
- Update tests

### Phase 2: Basic UI 🔄 (Current)
- Update mood creation (single label)
- Update mood display (show primary label)
- Keep UI design similar
- Test everything works

### Phase 3: Enhanced Features 🔮 (Future)
- Multiple label selection UI
- Valence slider for precise input
- Associations selector
- HealthKit integration

---

## Benefits

✅ **Cleaner Code** - No conversion logic between layers  
✅ **API Aligned** - Direct mapping to backend  
✅ **HealthKit Ready** - Uses standard valence model  
✅ **More Flexible** - Supports multiple labels and associations  
✅ **Future Proof** - Ready for advanced features  
✅ **Scientifically Sound** - Based on psychological research  

---

## Trade-offs

⚠️ **Breaking Change** - Requires app reinstall  
⚠️ **More Complex** - More fields than simple enum  
⚠️ **UI Updates Needed** - All mood views need changes  

**Decision:** Benefits outweigh costs. The refactor makes the codebase more maintainable and prepares for future enhancements.

---

## Quick Start for Developers

### Creating a Mood Entry
```swift
// Simple way (recommended for now)
let entry = MoodEntry(
    userId: currentUserId,
    date: Date(),
    moodLabel: .happy,
    notes: "Feeling good!"
)

try await moodRepository.save(entry)
```

### Displaying a Mood Entry
```swift
// Get primary mood for display
if let mood = entry.primaryMoodLabel {
    HStack {
        Image(systemName: mood.systemImage)
        Text(mood.displayName)
    }
    .foregroundColor(Color(hex: mood.color))
}

// Show valence as bar
ProgressView(value: (entry.valence + 1.0) / 2.0)
```

### Migrating Existing Code
1. Find all references to `entry.mood` → Use `entry.primaryMoodLabel`
2. Find all references to `entry.intensity` → Use `entry.valencePercentage`
3. Find all references to `entry.note` → Change to `entry.notes`
4. Update creation logic to use convenience init with `moodLabel:`

---

## Documentation

- [DOMAIN_MODEL_REFACTOR.md](DOMAIN_MODEL_REFACTOR.md) - Full technical details
- [MOOD_API_MIGRATION.md](MOOD_API_MIGRATION.md) - API changes explained
- [MOOD_API_CHANGES_SUMMARY.md](MOOD_API_CHANGES_SUMMARY.md) - Quick reference
- [Backend API Spec](swagger.yaml) - Complete API documentation

---

## Support

If you have questions about:
- **Domain model structure** - See `MoodEntry.swift` inline docs
- **Database migration** - See `SchemaVersioning.swift`
- **Backend API** - See `swagger.yaml`
- **UI updates** - See [DOMAIN_MODEL_REFACTOR.md](DOMAIN_MODEL_REFACTOR.md)

---

## Summary

The mood tracking model has been modernized to align with industry standards (HealthKit) and the backend API. The infrastructure is complete and ready. UI updates are straightforward and can be done incrementally.

**Next action:** Update `MoodTrackingView` and `MoodViewModel` to create entries with the new model.