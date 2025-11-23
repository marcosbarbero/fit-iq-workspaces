# Mood Tracking Documentation

**Last Updated:** 2025-01-15  
**Status:** Active Development

---

## Overview

This directory contains all documentation related to the Mood Tracking feature in the Lume iOS app. Mood tracking is a core wellness feature that allows users to log their emotional state using a warm, simple interface.

---

## Architecture

Lume's mood tracking follows **Hexagonal Architecture** principles:

```
Presentation Layer (SwiftUI Views + ViewModels)
    ↓
Domain Layer (MoodEntry, MoodKind, Use Cases)
    ↓
Data Layer (MoodRepository, SwiftData)
    ↓
Infrastructure (Backend Service, Outbox Pattern)
```

**Key Principle:** Domain layer remains pure and independent of UI and persistence frameworks.

---

## Core Concepts

### Mood Types

Users select from **10 warm mood types** that represent their emotional state:

| Mood Type | Score | Description |
|-----------|-------|-------------|
| Peaceful | 6 | Tranquil and serene |
| Calm | 6 | Relaxed and steady |
| Content | 7 | Satisfied and at ease |
| Happy | 8 | Joyful and positive |
| Excited | 9 | Enthusiastic and eager |
| Energetic | 9 | Motivated and active |
| Tired | 4 | Low energy and weary |
| Sad | 2 | Down or melancholy |
| Anxious | 2 | Worried or uneasy |
| Stressed | 2 | Overwhelmed or tense |

### Data Flow

1. **User Selection:** User picks a mood type and optionally adds a note
2. **Local Storage:** Entry saved to SwiftData immediately
3. **Outbox Event:** If in production mode, create sync event
4. **Backend Sync:** OutboxProcessorService sends data to backend API
5. **Confirmation:** Event marked as completed on success

### Offline Support

The **Outbox Pattern** ensures reliable sync:
- Entries saved locally first (instant feedback)
- Sync happens asynchronously in background
- Automatic retry on failure
- No data loss if network unavailable

---

## Documentation Index

### Implementation Guides

- **[API Update Guide](API_UPDATE_GUIDE.md)** ⭐ **Start Here**  
  Comprehensive guide for updating to the new backend API specification. Includes:
  - Endpoint changes
  - Data structure transformation
  - Step-by-step implementation plan
  - Testing checklist
  - Migration guide

- **[API Update Changelog](API_UPDATE_CHANGELOG.md)**  
  Detailed changelog of the recent API update. Includes:
  - Summary of changes
  - Files modified
  - Transformation logic
  - Testing status
  - Rollback plan

### Design Documentation

- **[Mood Redesign Summary](MOOD_REDESIGN_SUMMARY.md)**  
  Original design document for the mood tracking interface. Covers:
  - UX principles (warm sunlight metaphor)
  - Color palette
  - Component design
  - User flow

### Technical Specifications

- **[Backend API Specification](../backend-integration/swagger.yaml)**  
  Full OpenAPI specification for mood tracking endpoints:
  - `POST /api/v1/wellness/mood-entries` - Create mood log
  - `GET /api/v1/wellness/mood-entries` - List mood logs
  - `GET /api/v1/wellness/mood-entries/{id}` - Get specific entry
  - `PUT /api/v1/wellness/mood-entries/{id}` - Update entry
  - `DELETE /api/v1/wellness/mood-entries/{id}` - Delete entry
  - `GET /api/v1/wellness/mood-entries/analytics` - Get statistics

### Related Documentation

- **[Outbox Pattern Implementation](../backend-integration/OUTBOX_PATTERN_IMPLEMENTATION.md)**  
  How the outbox pattern ensures reliable backend sync

- **[Backend Integration Guide](../backend-integration/BACKEND_INTEGRATION.md)**  
  Overall backend integration architecture and authentication

---

## Quick Reference

### Creating a Mood Entry

```swift
// In ViewModel or Use Case
let entry = MoodEntry(
    userId: currentUserId,
    date: Date(),
    mood: .happy,
    note: "Had a great workout today!"
)

try await moodRepository.save(entry)
```

### Backend API Request Format

```json
{
  "mood_score": 8,
  "emotions": ["happy"],
  "notes": "Had a great workout today!",
  "logged_at": "2024-01-15T14:30:00Z"
}
```

### Transformation Logic

The app's `MoodKind` enum is automatically transformed to the backend's format:

```swift
// happy → mood_score: 8, emotions: ["happy"]
// peaceful → mood_score: 6, emotions: ["peaceful", "calm"]
// stressed → mood_score: 2, emotions: ["stressed", "overwhelmed"]
```

---

## Recent Updates

### 2025-01-15: Backend API Alignment

**Status:** ✅ Implemented

Updated mood tracking to align with new backend API specification:
- Changed endpoints from `/api/v1/moods` to `/api/v1/wellness/mood-entries`
- Added transformation layer (MoodKind → mood_score + emotions array)
- Updated request format (removed client-generated IDs, timestamps)
- Created comprehensive unit tests

**See:** [API Update Guide](API_UPDATE_GUIDE.md) for full details.

---

## Testing

### Unit Tests

Location: `lume/Services/Backend/MoodBackendServiceTests.swift`

Tests cover:
- Mood score mapping (10 mood types → 1-10 scale)
- Emotions array mapping (mood type → emotion strings)
- Field name transformations
- API endpoint paths
- Request payload structure

Run tests:
```bash
# In Xcode
cmd + u

# Or via command line
xcodebuild test -scheme lume -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Manual Testing

1. Set app mode in `LumeApp.swift`:
   ```swift
   AppMode.current = .local        // No backend sync
   AppMode.current = .mockBackend  // Mock sync
   AppMode.current = .production   // Real backend
   ```

2. Create mood entries in the app
3. Check logs for sync events:
   ```
   ✅ [MoodRepository] Saved mood locally: Happy
   📦 [MoodRepository] Created outbox event 'mood.created'
   ✅ [OutboxProcessor] Event completed
   ```

---

## Common Issues & Solutions

### Issue: 404 Not Found on mood sync

**Cause:** Backend endpoint not yet deployed  
**Solution:** Set `AppMode.current = .local` until backend is ready

### Issue: Outbox events not processing

**Cause:** Token expired or AppMode set to .local  
**Solution:** Check logs for token refresh, verify AppMode setting

### Issue: Transformation errors

**Cause:** Mismatch between app model and API spec  
**Solution:** See [API Update Guide](API_UPDATE_GUIDE.md) for correct mappings

---

## Code Locations

### Domain
- `lume/Domain/Entities/MoodEntry.swift` - Core mood entity
- `lume/Domain/Entities/MoodKind.swift` - Enum of 10 mood types (in MoodEntry.swift)
- `lume/Domain/Ports/MoodRepositoryProtocol.swift` - Repository interface

### Data
- `lume/Data/Repositories/MoodRepository.swift` - Repository implementation
- `lume/Data/Persistence/SDMoodEntry.swift` - SwiftData model

### Presentation
- `lume/Presentation/Features/Mood/MoodTrackingView.swift` - Main UI
- `lume/Presentation/Features/Mood/MoodCardView.swift` - Mood selection card
- `lume/Presentation/Features/Mood/MoodHistoryView.swift` - History view

### Services
- `lume/Services/Backend/MoodBackendService.swift` - Backend API client
- `lume/Services/Outbox/OutboxProcessorService.swift` - Sync processor

---

## Contributing

When updating mood tracking:

1. ✅ Keep domain layer pure (no SwiftUI, no SwiftData)
2. ✅ Follow Hexagonal Architecture principles
3. ✅ Use Outbox Pattern for backend sync
4. ✅ Maintain warm, calm UX (no pressure mechanics)
5. ✅ Add unit tests for new functionality
6. ✅ Update documentation in this directory

---

## Questions?

- **Architecture questions:** See project root `copilot-instructions.md`
- **API questions:** See `swagger.yaml` in `backend-integration/`
- **Implementation questions:** See `API_UPDATE_GUIDE.md` in this directory
- **UX questions:** See `MOOD_REDESIGN_SUMMARY.md` in this directory

---

**Mood tracking is the heart of Lume's wellness experience. Keep it warm, simple, and reliable.** ☀️