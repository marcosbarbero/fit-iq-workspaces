# Backend ID Mapping & UX Fixes

**Date:** 2025-01-15  
**Version:** 2.2.0  
**Status:** Completed

---

## Overview

This document covers critical fixes for backend synchronization and user experience improvements in the mood tracking feature.

---

## Issue 1: Backend ID Mapping ✅

### Problem

The application was using **local UUIDs** for DELETE requests to the backend, but the backend expects its own generated IDs. This caused 404 errors when trying to delete mood entries that had been synced to the backend.

**Error Example:**
```
DELETE /api/v1/wellness/mood-entries/BD90861D-8946-4A12-A650-2D53FD11A9AC
Status: 404
Response: {"error":{"message":"mood entry not found"}}
```

The local UUID `BD90861D-8946-4A12-A650-2D53FD11A9AC` doesn't exist in the backend database.

### Root Cause

The Outbox pattern was correctly sending data to the backend, but:
1. ❌ Backend response IDs were not being captured
2. ❌ Backend IDs were not being stored locally
3. ❌ DELETE requests were using local IDs instead of backend IDs

### Solution

Implemented a complete backend ID mapping system:

#### 1. Updated Data Model

**File:** `SchemaVersioning.swift`

Added two new fields to `SDMoodEntry`:
- `intensity: Int` - The 1-10 mood intensity scale
- `backendId: String?` - The backend's UUID for this entry

```swift
@Model
final class SDMoodEntry {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var date: Date
    var mood: String
    var intensity: Int
    var note: String?
    var backendId: String?  // NEW: Backend UUID for sync
    var createdAt: Date
    var updatedAt: Date
}
```

#### 2. Updated Domain Conversion

**File:** `SDMoodEntry.swift`

Added helper to access backend ID as UUID:
```swift
var backendUUID: UUID? {
    guard let backendId = backendId else { return nil }
    return UUID(uuidString: backendId)
}
```

Updated `fromDomain()` to accept optional `backendId`:
```swift
static func fromDomain(_ entry: MoodEntry, backendId: String? = nil) -> SDMoodEntry
```

#### 3. Updated Backend Service

**File:** `MoodBackendService.swift`

Changed method signatures:
```swift
// Before
func createMood(_ entry: MoodEntry, accessToken: String) async throws

// After
func createMood(_ entry: MoodEntry, accessToken: String) async throws -> String
```

Now returns the backend ID from the response:
```swift
let response: MoodResponse = try await httpClient.post(
    path: "/api/v1/wellness/mood-entries",
    body: request,
    accessToken: accessToken
)
return response.id  // Backend UUID string
```

Updated DELETE to use backend ID:
```swift
// Before
func deleteMood(id: UUID, accessToken: String) async throws

// After
func deleteMood(backendId: String, accessToken: String) async throws
```

#### 4. Updated Repository

**File:** `MoodRepository.swift`

Updated `save()` to preserve backend ID on updates:
```swift
// Check if entry already exists
let existing = try modelContext.fetch(descriptor).first

// Preserve backendId if updating
let sdEntry = SDMoodEntry.fromDomain(entry, backendId: existing?.backendId)
```

Updated `delete()` to include backend ID in outbox payload:
```swift
let backendId = sdEntry.backendId
let payload = DeletePayload(localId: id, backendId: backendId)
```

#### 5. Updated Outbox Processor

**File:** `OutboxProcessorService.swift`

Added `ModelContext` dependency to update local database:
```swift
init(
    outboxRepository: OutboxRepositoryProtocol,
    tokenStorage: TokenStorageProtocol,
    moodBackendService: MoodBackendServiceProtocol,
    modelContext: ModelContext,  // NEW
    refreshTokenUseCase: RefreshTokenUseCase? = nil
)
```

Updated `processMoodCreated()` to store backend ID:
```swift
// Send to backend and get backend ID
let backendId = try await moodBackendService.createMood(moodEntry, accessToken: accessToken)

// Store backend ID in local database
let descriptor = FetchDescriptor<SDMoodEntry>(
    predicate: #Predicate { entry in
        entry.id == payload.id
    }
)

if let sdEntry = try modelContext.fetch(descriptor).first {
    sdEntry.backendId = backendId
    try modelContext.save()
    print("✅ [OutboxProcessor] Stored backend ID: \(backendId)")
}
```

Updated `processMoodDeleted()` to use backend ID:
```swift
// Use backend ID if available, otherwise skip
guard let backendId = payload.backendId else {
    print("⚠️ [OutboxProcessor] No backend ID, entry was never synced")
    return
}

try await moodBackendService.deleteMood(backendId: backendId, accessToken: accessToken)
```

#### 6. Updated Payloads

Added intensity and backend ID to all payloads:

**MoodPayload:**
```swift
struct MoodPayload: Codable {
    let id: UUID
    let userId: UUID
    let mood: String
    let intensity: Int  // NEW
    let note: String?
    let date: Date
    let createdAt: Date
    let updatedAt: Date
}
```

**DeletePayload:**
```swift
struct DeletePayload: Codable {
    let localId: UUID
    let backendId: String?  // NEW
}
```

### Flow Diagram

```
┌─────────────┐
│ User creates│
│ mood entry  │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Save to local DB    │
│ with local UUID     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Create outbox event │
│ (mood.created)      │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ OutboxProcessor     │
│ sends to backend    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Backend returns ID  │
│ "abc-123-def-456"   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Store backend ID    │
│ in local entry      │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│ User deletes entry  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Delete from local   │
│ DB by local UUID    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Create outbox event │
│ (mood.deleted)      │
│ with BACKEND ID     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ OutboxProcessor     │
│ DELETE /entries/    │
│ {backendId}         │
└─────────────────────┘
       │
       ▼
    ✅ 200 OK
```

### Testing

- [x] Create mood entry syncs to backend
- [x] Backend ID is stored locally
- [x] Delete mood entry uses backend ID
- [x] No more 404 errors on delete
- [x] Entries never synced skip backend delete gracefully

---

## Issue 2: Text Area Auto-Scroll ✅

### Problem

When the user tapped the note text area in MoodDetailsView, the keyboard would appear but the view wouldn't scroll, causing the text area to be hidden behind the keyboard.

### Solution

Wrapped the `ScrollView` in a `ScrollViewReader` and added auto-scroll on focus:

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack {
            // ... mood content
            
            TextEditor(text: $note)
                .focused($isNoteFocused)
                .id("noteField")  // Anchor for scrolling
        }
        .onChange(of: isNoteFocused) { _, isFocused in
            if isFocused {
                withAnimation {
                    proxy.scrollTo("noteField", anchor: .center)
                }
            }
        }
    }
}
```

**Behavior:**
- When user taps text area, `isNoteFocused` becomes `true`
- `onChange` detects the change
- View smoothly scrolls to center the text field
- Keyboard appears without hiding content

### Testing

- [x] Tapping note field scrolls view up
- [x] Text field is visible above keyboard
- [x] Smooth animation
- [x] Works on all device sizes

---

## Issue 3: Intensity Not Displayed in Charts ✅

### Problem

The new intensity scoring system (1-10) wasn't being reflected in the dashboard charts. Charts were still using the old `mood.score` property (1-5 scale) instead of `entry.intensity`.

### Root Cause

The `MoodTimelineChart` was using:
```swift
y: .value("Score", entry.mood.score)  // OLD: 1-5 scale
```

And the Y-axis was scaled to 0-5.

### Solution

Updated all chart marks and axis to use intensity:

**File:** `MoodDashboardView.swift`

```swift
// Updated Y-axis scale
.chartYScale(domain: 0...10)
.chartYAxis {
    AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) { value in
        // ... axis labels
    }
}

// Updated chart marks
LineMark(
    x: .value("Time", date),
    y: .value("Intensity", entry.intensity)  // NEW: 1-10 scale
)

AreaMark(
    x: .value("Time", date),
    y: .value("Intensity", entry.intensity)  // NEW: 1-10 scale
)

PointMark(
    x: .value("Time", date),
    y: .value("Intensity", entry.intensity)  // NEW: 1-10 scale
)
```

**File:** `MoodViewModel.swift`

Updated dashboard statistics:
```swift
var averageTodayScore: Double {
    guard !todayEntries.isEmpty else { return 0 }
    let total = todayEntries.reduce(0) { $0 + $1.intensity }  // NEW
    return Double(total) / Double(todayEntries.count)
}

// Same for averageWeekScore, averageMonthScore, weekDailyAverages, monthDailyAverages
```

### Testing

- [x] Charts display intensity (1-10) correctly
- [x] Y-axis shows 0, 2, 4, 6, 8, 10 labels
- [x] Dashboard stats use intensity averages
- [x] Higher intensity = higher point on chart
- [x] Intensity badge matches chart position

---

## Backend API Contract

### Create/Update Mood Entry

**Endpoint:** `POST /api/v1/wellness/mood-entries`

**Request:**
```json
{
  "mood_score": 7,
  "emotions": ["happy", "content"],
  "notes": "Had a great day!",
  "logged_at": "2025-01-15T14:30:00Z"
}
```

**Response:**
```json
{
  "id": "abc-123-def-456",
  "mood_score": 7,
  "emotions": ["happy", "content"],
  "notes": "Had a great day!",
  "logged_at": "2025-01-15T14:30:00Z",
  "created_at": "2025-01-15T14:30:05Z"
}
```

**Key Field:** `id` - This is the backend ID that must be stored locally.

### Delete Mood Entry

**Endpoint:** `DELETE /api/v1/wellness/mood-entries/{backend_id}`

**Important:** Use the `backendId` stored locally, NOT the local UUID.

**Response:**
```json
{
  "success": true
}
```

---

## Files Modified

### Core Data Layer
- `lume/Data/Persistence/SchemaVersioning.swift` - Added `intensity` and `backendId` fields
- `lume/Data/Persistence/SDMoodEntry.swift` - Updated domain conversion
- `lume/Data/Repositories/MoodRepository.swift` - Store/use backend IDs

### Services
- `lume/Services/Backend/MoodBackendService.swift` - Return backend ID, use for deletes
- `lume/Services/Outbox/OutboxProcessorService.swift` - Capture and store backend IDs

### Presentation
- `lume/Presentation/Features/Mood/MoodTrackingView.swift` - Auto-scroll on focus
- `lume/Presentation/Features/Mood/MoodDashboardView.swift` - Use intensity in charts
- `lume/Presentation/ViewModels/MoodViewModel.swift` - Use intensity in stats

### Dependency Injection
- `lume/DI/AppDependencies.swift` - Pass ModelContext to OutboxProcessor

---

## Migration Notes

### For Existing Users

Entries created before this fix will:
1. Have `backendId = nil` initially
2. Sync to backend on next outbox processing
3. Receive backend ID on sync
4. Be deletable from both app and backend

### For Backend Team

Ensure the API:
1. Returns the `id` field in POST responses
2. Accepts backend `id` in DELETE requests
3. Returns 404 if ID not found (handled gracefully by app)

---

## Testing Checklist

### Backend ID Mapping
- [x] Create mood entry locally
- [x] Outbox sends to backend
- [x] Backend ID stored in `backendId` field
- [x] Verify in database: `SELECT id, backendId FROM SDMoodEntry`
- [x] Delete mood entry
- [x] Outbox uses `backendId` for DELETE request
- [x] Backend returns 200 OK
- [x] No 404 errors

### Auto-Scroll
- [x] Tap note field
- [x] View scrolls up smoothly
- [x] Text field visible above keyboard
- [x] Works in portrait and landscape
- [x] Works on small screens (SE)

### Intensity Display
- [x] Create mood with intensity 7
- [x] Chart shows point at Y=7
- [x] History card shows "7/10" badge
- [x] Dashboard stats reflect intensity
- [x] Averages calculated correctly

---

## Known Limitations

1. **No Conflict Resolution:** If an entry is modified offline and synced later, last-write-wins
2. **No Batch Sync:** Each entry syncs individually (could be optimized)
3. **No Backend Webhooks:** App doesn't receive real-time updates from backend

---

## Future Enhancements

1. Add conflict resolution strategy (server-wins, client-wins, or merge)
2. Implement batch sync for better performance
3. Add webhook support for real-time sync
4. Add sync status indicator in UI
5. Add retry queue visualization for debugging

---

## Related Documentation

- [Intensity Scoring System](INTENSITY_SCORING_UPDATE.md)
- [Mood Tracking UX Enhancements](UX_ENHANCEMENTS.md)
- [Architecture Guide](../../.github/copilot-instructions.md)

---

**Status:** ✅ All critical issues resolved. Ready for production testing.