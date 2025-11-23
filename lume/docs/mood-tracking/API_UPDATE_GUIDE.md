# Mood Tracking API Update Guide

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** Action Required

---

## Overview

The backend API for mood tracking has been updated with new endpoints and data structure. This guide documents the changes and provides step-by-step instructions for updating the iOS app implementation.

---

## API Changes Summary

### Endpoint Changes

| Old Endpoint | New Endpoint | Change |
|--------------|--------------|--------|
| `POST /api/v1/moods` | `POST /api/v1/wellness/mood-entries` | Path changed |
| `DELETE /api/v1/moods/{id}` | `DELETE /api/v1/wellness/mood-entries/{id}` | Path changed |

### Data Structure Changes

#### Old Structure (Current iOS App)
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "mood": "happy",
  "note": "Optional text",
  "date": "2024-01-15T14:30:00Z",
  "created_at": "2024-01-15T14:30:00Z",
  "updated_at": "2024-01-15T14:30:00Z"
}
```

#### New Structure (Backend API)
```json
{
  "mood_score": 7,
  "emotions": ["happy", "energetic", "motivated"],
  "notes": "Had a great workout today!",
  "logged_at": "2024-01-15T14:30:00Z"
}

// Response includes:
{
  "id": "uuid",
  "user_id": "uuid",
  "mood_score": 7,
  "emotions": ["happy", "energetic"],
  "notes": "Had a great workout today!",
  "logged_at": "2024-01-15T14:30:00Z",
  "created_at": "2024-01-15T14:30:00Z",
  "updated_at": "2024-01-15T14:30:00Z"
}
```

### Key Differences

1. **Mood Representation:**
   - **Old:** Single string field `mood` (e.g., "happy", "sad")
   - **New:** Integer `mood_score` (1-10) + array of `emotions`

2. **Field Names:**
   - **Old:** `note` (singular), `date`
   - **New:** `notes` (plural), `logged_at`

3. **Request vs Response:**
   - **Old:** Client sends full object including `id`, `user_id`, timestamps
   - **New:** Client sends only `mood_score`, `emotions`, `notes`, `logged_at`
   - **New:** Backend generates `id`, `user_id`, and timestamps

4. **Emotions:**
   - **New:** Supports array of predefined emotions from enum list
   - Available emotions: `happy`, `sad`, `anxious`, `calm`, `energetic`, `tired`, `stressed`, `relaxed`, `angry`, `content`, `frustrated`, `motivated`, `overwhelmed`, `peaceful`, `excited`

---

## Current iOS Implementation

### Domain Layer (`MoodEntry.swift`)

```swift
struct MoodEntry {
    let id: UUID
    let userId: UUID
    let date: Date
    let mood: MoodKind  // Enum with 10 values
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}

enum MoodKind: String {
    case peaceful, calm, content, happy, excited,
         energetic, tired, sad, anxious, stressed
}
```

### Current Backend Service

- Path: `/api/v1/moods`
- Sends full `MoodEntry` as-is to backend

---

## Proposed Solution

We have **two options** for updating the implementation:

### Option 1: Transform at Backend Service Layer (Recommended)

**Pros:**
- No changes to domain layer or UI
- Maintains current app architecture
- Simple mapping logic

**Cons:**
- Need bidirectional mapping (app model ↔ API model)

### Option 2: Update Domain Model

**Pros:**
- Direct alignment with backend API

**Cons:**
- Breaking changes throughout the app
- UI needs complete redesign (mood score slider + emotion tags)
- More complex user experience

**Recommendation:** Use **Option 1** to minimize changes and maintain the current warm, simple UX.

---

## Implementation Plan (Option 1)

### Step 1: Update Backend Service Endpoints

**File:** `lume/Services/Backend/MoodBackendService.swift`

```swift
func createMood(_ entry: MoodEntry, accessToken: String) async throws {
    let request = CreateMoodRequest(entry: entry)
    
    try await httpClient.post(
        path: "/api/v1/wellness/mood-entries",  // ✅ Updated
        body: request,
        accessToken: accessToken
    )
}

func deleteMood(id: UUID, accessToken: String) async throws {
    try await httpClient.delete(
        path: "/api/v1/wellness/mood-entries/\(id.uuidString)",  // ✅ Updated
        accessToken: accessToken
    )
}
```

### Step 2: Update Request Model with Transformation

**File:** `lume/Services/Backend/MoodBackendService.swift`

```swift
private struct CreateMoodRequest: Encodable {
    let mood_score: Int
    let emotions: [String]
    let notes: String?
    let logged_at: Date
    
    init(entry: MoodEntry) {
        // Map MoodKind to mood_score (1-10)
        self.mood_score = Self.moodKindToScore(entry.mood)
        
        // Map MoodKind to emotions array
        self.emotions = Self.moodKindToEmotions(entry.mood)
        
        // Map note to notes
        self.notes = entry.note
        
        // Map date to logged_at
        self.logged_at = entry.date
    }
    
    private static func moodKindToScore(_ mood: MoodKind) -> Int {
        switch mood {
        case .anxious, .stressed, .sad: return 2
        case .tired: return 4
        case .calm, .peaceful: return 6
        case .content: return 7
        case .happy: return 8
        case .energetic, .excited: return 9
        }
    }
    
    private static func moodKindToEmotions(_ mood: MoodKind) -> [String] {
        switch mood {
        case .peaceful: return ["peaceful", "calm"]
        case .calm: return ["calm", "relaxed"]
        case .content: return ["content"]
        case .happy: return ["happy"]
        case .excited: return ["excited", "happy"]
        case .energetic: return ["energetic", "motivated"]
        case .tired: return ["tired"]
        case .sad: return ["sad"]
        case .anxious: return ["anxious"]
        case .stressed: return ["stressed", "overwhelmed"]
        }
    }
}
```

### Step 3: Update Outbox Payload Encoding

**File:** `lume/Data/Repositories/MoodRepository.swift`

The `MoodPayload` struct used for outbox events can remain the same since it's only used for local storage. The transformation happens at the backend service layer when the event is processed.

**No changes required** to `MoodRepository.swift`.

### Step 4: Update OutboxProcessorService

**File:** `lume/Services/Outbox/OutboxProcessorService.swift`

```swift
private func processMoodCreated(_ event: OutboxEvent, accessToken: String) async throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let payload = try decoder.decode(MoodPayload.self, from: event.payload)
    
    // Create MoodEntry from payload
    let entry = MoodEntry(
        id: payload.id,
        userId: payload.userId,
        date: payload.date,
        mood: MoodKind(rawValue: payload.mood) ?? .content,
        note: payload.note,
        createdAt: payload.createdAt,
        updatedAt: payload.updatedAt
    )
    
    // Send to backend (transformation happens inside MoodBackendService)
    try await moodBackendService.createMood(entry, accessToken: accessToken)
}
```

**No changes required** - current implementation is already correct.

---

## Migration Checklist

### Code Changes

- [ ] Update `MoodBackendService.swift`
  - [ ] Update `createMood` endpoint path to `/api/v1/wellness/mood-entries`
  - [ ] Update `deleteMood` endpoint path to `/api/v1/wellness/mood-entries/{id}`
  - [ ] Add `CreateMoodRequest` transformation logic
  - [ ] Add `moodKindToScore` mapping function
  - [ ] Add `moodKindToEmotions` mapping function
  
- [ ] Update tests for `MoodBackendService`
  - [ ] Test mood score mapping (all 10 MoodKind values)
  - [ ] Test emotions array mapping
  - [ ] Test field name transformations (note → notes, date → logged_at)

### Testing

- [ ] Unit Tests
  - [ ] Test MoodKind → mood_score mapping
  - [ ] Test MoodKind → emotions array mapping
  - [ ] Test request encoding with new field names
  
- [ ] Integration Tests
  - [ ] Test POST to `/api/v1/wellness/mood-entries`
  - [ ] Test DELETE to `/api/v1/wellness/mood-entries/{id}`
  - [ ] Verify correct JWT token usage
  
- [ ] End-to-End Tests
  - [ ] Create mood entry locally → verify outbox event
  - [ ] Process outbox event → verify backend sync
  - [ ] Delete mood entry → verify backend deletion
  - [ ] Check logs for correct endpoint calls

### Documentation

- [ ] Update `BACKEND_INTEGRATION.md` with new endpoints
- [ ] Update `swagger.yaml` reference in docs
- [ ] Update `MOOD_REDESIGN_SUMMARY.md` with API notes
- [ ] Add this guide to `docs/mood-tracking/`

---

## Mood Score Mapping Reference

| MoodKind | Mood Score | Emotions | Rationale |
|----------|-----------|----------|-----------|
| anxious | 2 | ["anxious"] | Low wellbeing |
| stressed | 2 | ["stressed", "overwhelmed"] | Low wellbeing |
| sad | 2 | ["sad"] | Low wellbeing |
| tired | 4 | ["tired"] | Below neutral |
| calm | 6 | ["calm", "relaxed"] | Positive |
| peaceful | 6 | ["peaceful", "calm"] | Positive |
| content | 7 | ["content"] | Good |
| happy | 8 | ["happy"] | Very good |
| energetic | 9 | ["energetic", "motivated"] | Excellent |
| excited | 9 | ["excited", "happy"] | Excellent |

**Note:** The mapping preserves the warm, simple UX while conforming to the backend's numeric scale.

---

## Testing the Changes

### 1. Local Testing (AppMode.local)

```bash
# Set AppMode to local in LumeApp.swift
AppMode.current = .local

# Run app and create mood entries
# Verify no outbox events are created (expected behavior)
```

### 2. Mock Backend Testing (AppMode.mockBackend)

```bash
# Set AppMode to mockBackend
AppMode.current = .mockBackend

# Create mood entries
# Verify outbox events are created and processed
# Check logs for transformation logic
```

### 3. Production Backend Testing

```bash
# Set AppMode to production
AppMode.current = .production

# Create mood entries
# Verify POST to /api/v1/wellness/mood-entries
# Verify correct payload structure in logs
# Confirm 201 Created response from backend
```

### Log Verification

Look for these log messages:

```
✅ [MoodBackendService] Successfully synced mood entry: <uuid>
📦 [OutboxProcessor] Processing event: mood.created
✅ [OutboxProcessor] Event completed: <uuid>
```

If you see 404 errors, verify:
1. Backend endpoint is deployed
2. Endpoint path matches `/api/v1/wellness/mood-entries`
3. Authentication token is valid

---

## Backward Compatibility

### Existing Outbox Events

Events created before this update will have the old payload format. The decoder will handle them correctly since we're not changing the internal payload structure - only the transformation at the backend service layer.

**No migration required** for existing outbox events.

### SwiftData Models

No changes to `SDMoodEntry` or any SwiftData models. All transformations happen at the service layer.

---

## Rollback Plan

If issues occur:

1. **Revert endpoint paths** back to `/api/v1/moods`
2. **Revert CreateMoodRequest** to old structure
3. **Keep ISO 8601 date encoding** (already in place)
4. **Mark failing events as completed** to clear outbox

```swift
// Emergency rollback - mark all pending events as completed
func clearPendingEvents() async throws {
    let events = try await outboxRepository.fetchPendingEvents()
    for event in events where event.eventType.starts(with: "mood.") {
        try await outboxRepository.markCompleted(event.id)
    }
}
```

---

## Questions & Answers

### Q: Do we need to update the domain model?
**A:** No. The domain model remains unchanged. Transformation happens at the backend service layer.

### Q: What about UI changes?
**A:** No UI changes required. Users continue to select from 10 warm mood types.

### Q: Will old outbox events work?
**A:** Yes. The internal payload structure remains the same. Only the backend request format changes.

### Q: What if the backend is not ready?
**A:** The app continues to work in local mode. Events accumulate in the outbox and sync when the backend is available.

---

## Related Documentation

- [Backend Integration Guide](../backend-integration/BACKEND_INTEGRATION.md)
- [Outbox Pattern Implementation](../backend-integration/OUTBOX_PATTERN_IMPLEMENTATION.md)
- [Mood Tracking Redesign Summary](MOOD_REDESIGN_SUMMARY.md)
- [API Specification (swagger.yaml)](../backend-integration/swagger.yaml)

---

## Status

- [x] API changes documented
- [x] Implementation plan created
- [ ] Code changes implemented
- [ ] Tests updated
- [ ] Integration testing completed
- [ ] Production deployment verified

**Next Action:** Implement Step 1-4 from the Implementation Plan.