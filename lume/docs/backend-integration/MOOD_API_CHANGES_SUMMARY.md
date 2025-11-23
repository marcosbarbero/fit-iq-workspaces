# Mood API Changes - Quick Reference

**Date:** 2025-01-15  
**Status:** ✅ Implemented  
**Impact:** Backend sync layer only (no UI changes)

---

## What Changed

The backend mood API has been updated to align with Apple HealthKit's mental wellness model.

### API Contract Changes

| Aspect | Old API | New API |
|--------|---------|---------|
| **Mood Value** | `mood_score: Int` (1-10) | `valence: Double` (-1.0 to 1.0) |
| **Mood Labels** | `emotions: [String]` | `labels: [String]` (enum-based) |
| **Context** | ❌ Not supported | `associations: [String]` (enum-based) |
| **Source** | ❌ Not tracked | `source: String` ("manual"/"healthkit") |
| **Response** | Flat `{ entries: [...] }` | Nested `{ data: { entries: [...], total, limit, ... } }` |

### Example Request

**Before:**
```json
{
  "mood_score": 7,
  "emotions": ["happy", "excited"],
  "notes": "Great day!",
  "logged_at": "2025-01-15T14:30:00Z"
}
```

**After:**
```json
{
  "valence": 0.4,
  "labels": ["happy"],
  "associations": [],
  "notes": "Great day!",
  "logged_at": "2025-01-15T14:30:00Z",
  "source": "manual"
}
```

---

## iOS Implementation

### Files Modified
- `lume/Services/Backend/MoodBackendService.swift`

### Key Changes

1. **Request Model Updated**
   - Converts `intensity` (1-10) → `valence` (-1.0 to 1.0)
   - Maps `MoodKind` → `labels` array
   - Adds empty `associations` array (future use)
   - Includes `source: "manual"`

2. **Response Model Updated**
   - Handles nested `{ data: { ... } }` structure
   - Parses pagination metadata (`total`, `limit`, `offset`, `has_more`)
   - Maps `valence` → `intensity` for local storage
   - Maps `labels` → `MoodKind` enum

3. **Mapping Functions**
   ```swift
   // Intensity (1-10) ↔ Valence (-1.0 to 1.0)
   intensityToValence(_:) 
   valenceToIntensity(_:)
   
   // MoodKind ↔ Labels
   moodKindToLabels(_:)
   labelsToMoodKind(_:)
   ```

---

## Conversion Formulas

### Intensity → Valence
```
normalized = (intensity - 1) / 9.0       // [0, 1]
valence = normalized * 2.0 - 1.0         // [-1.0, 1.0]
```

### Valence → Intensity
```
normalized = (valence + 1.0) / 2.0       // [0, 1]
intensity = round(normalized * 9.0 + 1.0) // [1, 10]
```

### Mood Labels Mapping
```
MoodKind.peaceful → ["peaceful"]
MoodKind.calm → ["calm"]
MoodKind.happy → ["happy"]
MoodKind.stressed → ["stressed"]
// etc. (1:1 mapping)
```

---

## Testing

### Verified ✅
- Request serialization with new fields
- Response deserialization with nested structure
- Valence conversion accuracy
- Labels mapping for all MoodKind values
- No compilation errors

### Still Needed 🔄
- [ ] Integration test with live backend
- [ ] Pull-to-refresh sync test
- [ ] Mood creation roundtrip test
- [ ] Error handling verification

---

## User Impact

**None.** This is a backend-only change:
- UI remains unchanged
- Local storage unchanged  
- User experience unchanged
- All mapping happens transparently in the service layer

---

## Future Enhancements

1. **Associations** - Add UI for selecting contextual factors (work, family, health, etc.)
2. **Multiple Labels** - Allow selecting multiple mood states per entry
3. **HealthKit Sync** - Import mood data from Apple Health

---

## References

- [Full Migration Guide](MOOD_API_MIGRATION.md)
- [Backend API Spec](swagger.yaml)
- [Hexagonal Architecture](../architecture/HEXAGONAL_ARCHITECTURE_SYNC_REFACTOR.md)

---

## Summary

The mood API has been modernized to use scientific valence measurements and standardized mood labels, preparing for future HealthKit integration. All changes are backward compatible and transparent to users.