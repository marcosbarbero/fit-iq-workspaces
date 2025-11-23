# Mood API Migration Guide

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** ✅ Complete

---

## Overview

The backend mood tracking API has been updated to use a more sophisticated data model based on Apple HealthKit's mental wellness framework. This document describes the changes and how the iOS app has been updated to support them.

---

## API Changes Summary

### Old API Model (Deprecated)

```json
{
  "mood_score": 7,
  "emotions": ["happy", "excited"],
  "notes": "Great day!",
  "logged_at": "2025-01-15T14:30:00Z"
}
```

### New API Model (Current)

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

## Key Differences

### 1. Valence Instead of Mood Score

**Old:** `mood_score` (integer, 1-10 scale)
- Simple numeric representation
- Range: 1 (low) to 10 (high)

**New:** `valence` (double, -1.0 to 1.0 scale)
- Based on psychological research and HealthKit standards
- Range: -1.0 (very unpleasant) to 1.0 (very pleasant)
- More granular and scientifically grounded

**iOS Mapping:**
```swift
// Intensity to Valence
let normalized = Double(intensity - 1) / 9.0  // [0, 1]
let valence = normalized * 2.0 - 1.0  // [-1.0, 1.0]

// Valence to Intensity
let normalized = (valence + 1.0) / 2.0  // [0, 1]
let intensity = Int(round(normalized * 9.0 + 1.0))  // [1, 10]
```

### 2. Labels Instead of Emotions

**Old:** `emotions` (array of strings)
- Arbitrary emotion labels
- Multiple emotions per entry

**New:** `labels` (array of strings, from predefined enum)
- Standardized mood states
- Aligned with HealthKit categories
- Enum values: `peaceful`, `calm`, `content`, `happy`, `excited`, `energetic`, `tired`, `sad`, `anxious`, `stressed`, etc.

**iOS Mapping:**
```swift
// MoodKind to labels (1:1 mapping)
case .peaceful: return ["peaceful"]
case .calm: return ["calm"]
case .happy: return ["happy"]
// etc.

// Labels to MoodKind (use first label)
guard let primary = labels.first?.lowercased() else {
    return .content
}
```

### 3. New: Associations Field

**New:** `associations` (array of strings, from predefined enum)
- Contextual factors influencing mood
- Examples: `work`, `family`, `health`, `weather`, `fitness`, `social`, `travel`, `hobbies`, `dating`, `currentEvents`, `finances`, `education`
- Currently not used by iOS app (empty array)
- Reserved for future feature enhancement

### 4. New: Source Tracking

**New:** `source` (string enum: `manual` or `healthkit`)
- Tracks where the mood entry originated
- iOS app always sends `"manual"`
- Enables future HealthKit integration

**New:** `source_id` (optional string)
- External source identifier (e.g., HealthKit sample ID)
- Currently `null` for manual entries

**New:** `is_healthkit` (boolean)
- Quick flag for HealthKit entries
- Always `false` for iOS app entries

---

## Response Format Changes

### List Mood Entries Response

**Old Format:**
```json
{
  "entries": [...]
}
```

**New Format:**
```json
{
  "data": {
    "entries": [...],
    "total": 4,
    "limit": 50,
    "offset": 0,
    "has_more": false
  }
}
```

### Create Mood Entry Response

**Old Format:**
```json
{
  "id": "uuid"
}
```

**New Format:**
```json
{
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "valence": 0.4,
    "labels": ["happy"],
    "associations": [],
    "notes": "Great day!",
    "logged_at": "2025-01-15T14:30:00Z",
    "source": "manual",
    "source_id": null,
    "is_healthkit": false,
    "created_at": "2025-01-15T14:30:00Z",
    "updated_at": "2025-01-15T14:30:00Z"
  }
}
```

---

## iOS Implementation Changes

### MoodBackendService Updates

**File:** `lume/Services/Backend/MoodBackendService.swift`

#### 1. Request Model (`CreateMoodRequest`)

```swift
private struct CreateMoodRequest: Encodable {
    let valence: Double          // NEW: replaces mood_score
    let labels: [String]         // NEW: replaces emotions
    let associations: [String]   // NEW: contextual factors
    let notes: String?           // SAME
    let logged_at: String        // CHANGED: now ISO8601 string
    let source: String           // NEW: always "manual"
}
```

#### 2. Response Models

```swift
// Wraps the actual mood data
private struct CreateMoodResponse: Decodable {
    let data: MoodLogResponse
}

// Full mood entry from backend
private struct MoodLogResponse: Decodable {
    let id: String
    let user_id: String
    let valence: Double
    let labels: [String]
    let associations: [String]
    let notes: String?
    let logged_at: Date
    let source: String
    let source_id: String?
    let is_healthkit: Bool
    let created_at: Date
    let updated_at: Date
}

// List response with pagination
private struct FetchMoodsResponse: Decodable {
    let data: MoodListData
}

private struct MoodListData: Decodable {
    let entries: [MoodEntryDTO]
    let total: Int
    let limit: Int
    let offset: Int
    let has_more: Bool
}
```

#### 3. Mapping Functions

**Intensity ↔ Valence Conversion:**
```swift
private func intensityToValence(_ intensity: Int) -> Double {
    let clamped = min(max(intensity, 1), 10)
    let normalized = Double(clamped - 1) / 9.0  // [0, 1]
    return normalized * 2.0 - 1.0  // [-1.0, 1.0]
}

private func valenceToIntensity(_ valence: Double) -> Int {
    let normalized = (valence + 1.0) / 2.0  // [0, 1]
    let intensity = Int(round(normalized * 9.0 + 1.0))  // [1, 10]
    return min(max(intensity, 1), 10)
}
```

**MoodKind ↔ Labels Mapping:**
```swift
private func moodKindToLabels(_ mood: MoodKind) -> [String] {
    // 1:1 mapping between MoodKind and backend labels
    switch mood {
    case .peaceful: return ["peaceful"]
    case .calm: return ["calm"]
    case .content: return ["content"]
    // etc.
    }
}

private func labelsToMoodKind(_ labels: [String]) -> MoodKind {
    // Use first label, with fallback to .content
    guard let primary = labels.first?.lowercased() else {
        return .content
    }
    // Map string to enum
}
```

---

## Testing Checklist

### Unit Tests
- [x] Intensity to valence conversion (edge cases: 1, 5, 10)
- [x] Valence to intensity conversion (edge cases: -1.0, 0.0, 1.0)
- [x] MoodKind to labels mapping (all enum cases)
- [x] Labels to MoodKind mapping (all backend labels + fallback)
- [x] Request serialization (verify JSON structure)
- [x] Response deserialization (verify parsing)

### Integration Tests
- [ ] Create mood entry (verify backend receives correct valence/labels)
- [ ] Fetch mood entries (verify parsing of new response format)
- [ ] Delete mood entry (verify still works with new API)
- [ ] Sync flow (verify local → remote → local roundtrip)

### Manual Testing
- [ ] Log mood with different intensities (verify correct valence sent)
- [ ] Log mood with all MoodKind values (verify labels mapping)
- [ ] Pull to refresh (verify sync works with new API)
- [ ] View mood history (verify display is correct)
- [ ] Offline mode (verify queuing still works)

---

## Backward Compatibility

### Migration Strategy

**No data migration needed:**
- All mood data is stored locally in SwiftData with the existing schema
- Only the backend sync layer has changed
- Local `MoodEntry` model remains unchanged
- Mapping happens only at the backend service boundary

**Rollout:**
1. Backend API updated (✅ Complete)
2. iOS app updated to use new API (✅ Complete)
3. Old API deprecated (future)
4. Old API removed (future)

---

## Future Enhancements

### 1. Associations Support
**Status:** Backend ready, iOS not implemented

Add UI for selecting contextual associations:
```swift
struct MoodAssociation: String, CaseIterable {
    case work = "work"
    case family = "family"
    case health = "health"
    case weather = "weather"
    case fitness = "fitness"
    case social = "social"
    // etc.
}
```

### 2. HealthKit Integration
**Status:** Backend ready, iOS not implemented

Future integration to sync mood data from Apple Health:
- Read mood entries from HealthKit
- Send to backend with `source: "healthkit"`
- Include HealthKit sample ID as `source_id`
- Avoid duplicate syncing

### 3. Multiple Labels
**Status:** Backend supports, iOS uses single label

Current iOS implementation maps 1:1 (MoodKind → single label).
Future: Allow users to select multiple mood states.

---

## API Reference

### Endpoints

**List Mood Entries:**
```
GET /api/v1/wellness/mood-entries
Query params: from, to, source, limit, offset
Response: { data: { entries: [...], total, limit, offset, has_more } }
```

**Create Mood Entry:**
```
POST /api/v1/wellness/mood-entries
Body: { valence, labels, associations, notes, logged_at, source }
Response: { data: { id, user_id, valence, labels, ... } }
```

**Get Mood Entry:**
```
GET /api/v1/wellness/mood-entries/{id}
Response: { data: { id, user_id, valence, labels, ... } }
```

**Update Mood Entry:**
```
PUT /api/v1/wellness/mood-entries/{id}
Body: { valence, labels, associations, notes, logged_at, source }
Response: { data: { id, user_id, valence, labels, ... } }
```

**Delete Mood Entry:**
```
DELETE /api/v1/wellness/mood-entries/{id}
Response: 204 No Content
```

**Get Analytics:**
```
GET /api/v1/wellness/mood-entries/analytics
Query params: from, to, include_daily_breakdown, top_labels_limit, top_associations_limit
Response: { data: { period, summary, trends, top_labels, top_associations, daily_aggregates } }
```

---

## Troubleshooting

### Common Issues

**Issue:** Mood entries not syncing
- **Check:** Network connectivity
- **Check:** Access token validity
- **Check:** Backend API health
- **Debug:** Enable HTTP client logging

**Issue:** Intensity/valence mismatch
- **Check:** Conversion formulas
- **Test:** Roundtrip conversion (intensity → valence → intensity)
- **Verify:** Edge cases (1, 5, 10)

**Issue:** Labels not mapping correctly
- **Check:** Case sensitivity (backend uses lowercase)
- **Verify:** All MoodKind enum values have mappings
- **Test:** Reverse mapping (labels → MoodKind → labels)

---

## References

- [Backend API Swagger Spec](../backend-integration/swagger.yaml)
- [Apple HealthKit Mental Wellness](https://developer.apple.com/documentation/healthkit/mental_well_being)
- [Hexagonal Architecture Sync Refactor](../architecture/HEXAGONAL_ARCHITECTURE_SYNC_REFACTOR.md)

---

## Changelog

### 2025-01-15 - Initial Migration
- Updated `MoodBackendService` to use new API contract
- Implemented valence ↔ intensity conversion
- Implemented labels mapping
- Added support for new response format with pagination
- Updated request/response models
- Maintained backward compatibility in local storage

---

## Summary

The mood API migration brings the iOS app in line with modern mental wellness standards and prepares for future HealthKit integration. The key changes are:

1. **Valence-based mood measurement** (scientific, HealthKit-compatible)
2. **Standardized mood labels** (consistent taxonomy)
3. **Contextual associations** (future enhancement)
4. **Source tracking** (manual vs HealthKit)
5. **Enhanced response format** (pagination, metadata)

All changes are transparent to the user and maintain the warm, calm Lume experience.