# Profile Save - Local-First Architecture Fix

## Issue Summary

**Problem:** The physical profile update flow was **blocking on backend API calls**, violating the app's local-first architecture principle. This caused:
- Slow save operations (waiting for network)
- Save failures when offline
- 405 errors when backend endpoints weren't available
- Poor user experience (UI freezes during save)

**Root Cause:** `UpdatePhysicalProfileUseCase` was calling the backend repository **synchronously** before saving to local storage.

## Architectural Principle

**Core Principle: LOCAL STORAGE IS THE SOURCE OF TRUTH**

```
┌─────────────────────────────────────────────────────────────┐
│  LOCAL-FIRST ARCHITECTURE                                    │
│                                                              │
│  User Action → Save to Local Storage (FIRST) → Return       │
│                       ↓                                       │
│                 Publish Event                                │
│                       ↓                                       │
│              Async Backend Sync                              │
│          (Background, non-blocking)                          │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Local Storage First:** Always save to SwiftData BEFORE any backend interaction
2. **Immediate Response:** Return updated data to user immediately (no network wait)
3. **Async Sync:** Backend sync happens in background via event-driven architecture
4. **Offline-First:** App works fully offline, syncs when connection available
5. **Backend for Enrichment:** Backend provides analytics, AI features, cross-device sync - NOT primary storage

## Technical Details

### Before the Fix

#### UpdatePhysicalProfileUseCase (WRONG - Backend-First)

```swift
func execute(...) async throws -> PhysicalProfile {
    // ❌ BLOCKS on backend call
    let updatedProfile = try await repository.updatePhysicalProfile(...)
    
    // ❌ Only saves locally AFTER backend succeeds
    try await userProfileStorage.save(userProfile: updatedProfile)
    
    // ❌ If backend fails (405, timeout, offline), nothing is saved
    return updatedProfile
}
```

**Problems:**
- Requires network connection
- Slow (waits for API response)
- Fails if backend has issues
- User sees loading spinner
- Violates local-first principle

#### UpdateProfileMetadataUseCase (CORRECT - Local-First)

```swift
func execute(...) async throws -> UserProfile {
    // ✅ Validates data
    // ... validation logic ...
    
    // ✅ Saves to local storage FIRST
    try await userProfileStorage.save(userProfile: updatedProfile)
    
    // ✅ Publishes event for async sync
    eventPublisher.publish(event: .metadataUpdated(...))
    
    // ✅ Returns immediately
    return updatedProfile
}
```

**Benefits:**
- Works offline
- Fast (no network wait)
- Always succeeds (if data valid)
- User sees instant update
- Follows local-first principle

### After the Fix

#### UpdatePhysicalProfileUseCase (FIXED - Local-First)

```swift
func execute(...) async throws -> PhysicalProfile {
    // 1. Validate input data
    guard biologicalSex != nil || heightCm != nil || dateOfBirth != nil else {
        throw PhysicalProfileUpdateValidationError.noFieldsProvided
    }
    // ... more validation ...
    
    // 2. Fetch current profile from local storage
    let currentProfile = try await userProfileStorage.fetch(forUserID: userUUID)
    
    // 3. Merge new values with existing
    let currentPhysical = currentProfile.physical ?? PhysicalProfile.empty
    let updatedPhysicalProfile = PhysicalProfile(
        biologicalSex: biologicalSex ?? currentPhysical.biologicalSex,
        heightCm: heightCm ?? currentPhysical.heightCm,
        dateOfBirth: dateOfBirth ?? currentPhysical.dateOfBirth
    )
    
    // 4. Validate the merged result
    let validationErrors = updatedPhysicalProfile.validate()
    guard validationErrors.isEmpty else {
        throw PhysicalProfileUpdateValidationError.validationFailed(validationErrors)
    }
    
    // 5. Update profile with new physical data
    let updatedProfile = currentProfile.updatingPhysical(updatedPhysicalProfile)
    
    // 6. ✅ Save to local storage FIRST (source of truth)
    try await userProfileStorage.save(userProfile: updatedProfile)
    
    // 7. ✅ Publish event for async backend sync
    eventPublisher.publish(event: .physicalProfileUpdated(...))
    
    // 8. ✅ Return immediately
    return updatedPhysicalProfile
}
```

## Files Modified

### 1. `Domain/UseCases/UpdatePhysicalProfileUseCase.swift`

**Changes:**
- Removed `PhysicalProfileRepositoryProtocol` dependency (backend repository)
- Changed flow to save local first, sync async
- Updated documentation to reflect local-first architecture
- Added merge logic to combine new values with existing
- Added validation errors for save failures

**Key Diffs:**
```swift
// BEFORE
- private let repository: PhysicalProfileRepositoryProtocol
- let updatedProfile = try await repository.updatePhysicalProfile(...)
- try await userProfileStorage.save(userProfile: updatedProfile)

// AFTER
+ let updatedPhysicalProfile = PhysicalProfile(...)
+ try await userProfileStorage.save(userProfile: updatedProfile)
+ eventPublisher.publish(event: .physicalProfileUpdated(...))
```

### 2. `Infrastructure/Configuration/AppDependencies.swift`

**Changes:**
- Removed `repository: physicalProfileRepository` parameter from `UpdatePhysicalProfileUseCaseImpl` initialization
- Use case now only depends on local storage and event publisher

**Key Diff:**
```swift
// BEFORE
let updatePhysicalProfileUseCase = UpdatePhysicalProfileUseCaseImpl(
-    repository: physicalProfileRepository,
    userProfileStorage: userProfileStorageAdapter,
    eventPublisher: profileEventPublisher
)

// AFTER
let updatePhysicalProfileUseCase = UpdatePhysicalProfileUseCaseImpl(
    userProfileStorage: userProfileStorageAdapter,
    eventPublisher: profileEventPublisher
)
```

## Async Backend Sync

The backend sync happens **asynchronously** via:

1. **ProfileEventPublisher** - Publishes domain events
2. **ProfileSyncService** - Listens to events, syncs to backend
3. **Background Operations** - Handles retries, queuing, offline scenarios

```
User saves profile
    ↓
UpdatePhysicalProfileUseCase.execute()
    ↓
Save to SwiftData (local)
    ↓
Publish ProfileEvent.physicalProfileUpdated
    ↓
ProfileSyncService receives event
    ↓
Queue for background sync
    ↓
When network available:
    - PATCH /api/v1/users/me/physical
    - Handle success/failure
    - Retry on failure
```

## Comparison Table

| Aspect | Before (Backend-First) | After (Local-First) |
|--------|----------------------|-------------------|
| **Save Speed** | Slow (network wait) | Instant (local only) |
| **Offline Support** | ❌ Fails | ✅ Works |
| **Network Error** | ❌ User sees error | ✅ Syncs later |
| **User Experience** | Loading spinner | Immediate feedback |
| **Backend 405 Error** | ❌ Blocks save | ✅ Saves anyway |
| **Data Consistency** | Backend is source | Local is source |
| **Sync Strategy** | Synchronous | Asynchronous |

## Benefits

### 1. **Better User Experience**
- ✅ Instant save feedback
- ✅ No loading spinners
- ✅ Works offline
- ✅ Smooth, responsive UI

### 2. **Architectural Consistency**
- ✅ Matches `UpdateProfileMetadataUseCase` pattern
- ✅ Follows hexagonal architecture properly
- ✅ Local storage as single source of truth
- ✅ Event-driven async sync

### 3. **Reliability**
- ✅ Saves always succeed (if data valid)
- ✅ Backend issues don't block user
- ✅ Automatic retry on failure
- ✅ Offline queue for sync

### 4. **Performance**
- ✅ No network latency
- ✅ No blocking operations
- ✅ Background sync doesn't impact UI
- ✅ Efficient resource usage

## Backend Sync Details

### ProfileSyncService Responsibilities

1. **Listen to Events:**
   - `.metadataUpdated` → PUT `/api/v1/users/me`
   - `.physicalProfileUpdated` → PATCH `/api/v1/users/me/physical`

2. **Queue Operations:**
   - Store sync operations in queue
   - Process when network available
   - Retry on failure with exponential backoff

3. **Conflict Resolution:**
   - Last-write-wins (local always preferred)
   - Backend enrichment doesn't overwrite local
   - Merge backend insights (AI, analytics) with local data

### Endpoints Used (Async)

- **PUT `/api/v1/users/me`** - Update full profile metadata
- **PATCH `/api/v1/users/me/physical`** - Update physical profile attributes
- **GET `/api/v1/users/me`** - Fetch enriched data from backend (periodically)

Note: The 405 error on `/api/v1/users/me/physical` GET is no longer an issue because we don't fetch from there - we only PATCH (update) asynchronously.

## Migration Notes

### Existing Code Impact

- ✅ **No breaking changes** to API
- ✅ **No database migration** needed
- ✅ **Existing profiles** continue to work
- ✅ **UI code** remains unchanged

### Behavior Changes

- **Before:** Save button shows loading, waits for network
- **After:** Save button returns immediately, sync happens in background

Users will notice:
- ✅ Faster save operations
- ✅ No error dialogs from network issues
- ✅ Works offline

## Testing Recommendations

### Manual Testing

1. **Offline Save:**
   - Turn off network
   - Edit physical profile (height, sex, DOB)
   - Tap save → Should succeed instantly
   - Turn on network → Verify sync happens

2. **Backend Error (405):**
   - Force backend to return 405
   - Edit profile → Should still save locally
   - Check background sync retries

3. **Fast Save:**
   - Edit profile
   - Tap save → Should return immediately
   - No loading spinner
   - Data persists across app restart

### Unit Tests (Recommended)

```swift
func testPhysicalProfileUpdate_SavesLocallyFirst() async throws {
    // Arrange
    let useCase = UpdatePhysicalProfileUseCaseImpl(
        userProfileStorage: mockStorage,
        eventPublisher: mockPublisher
    )
    
    // Act
    let result = try await useCase.execute(
        userId: "123",
        biologicalSex: "male",
        heightCm: 180,
        dateOfBirth: Date()
    )
    
    // Assert
    XCTAssertEqual(mockStorage.saveCallCount, 1, "Should save to local storage")
    XCTAssertEqual(mockPublisher.publishCallCount, 1, "Should publish event")
    XCTAssertNotNil(result, "Should return result immediately")
}

func testPhysicalProfileUpdate_WorksOffline() async throws {
    // Arrange
    let useCase = UpdatePhysicalProfileUseCaseImpl(
        userProfileStorage: mockStorage,
        eventPublisher: mockPublisher
    )
    
    // Simulate offline (no network client)
    
    // Act
    let result = try await useCase.execute(
        userId: "123",
        biologicalSex: "female",
        heightCm: 165,
        dateOfBirth: Date()
    )
    
    // Assert
    XCTAssertNotNil(result, "Should work offline")
    XCTAssertEqual(mockStorage.saveCallCount, 1, "Should save locally")
}
```

## Related Issues

- **405 Errors:** No longer an issue because we don't do synchronous GET/PATCH to backend
- **Slow Saves:** Fixed by removing network wait
- **Offline Editing:** Now fully supported
- **Architecture Consistency:** Both metadata and physical profile now follow same pattern

## Future Enhancements

1. **Conflict Resolution:** Handle backend conflicts more gracefully
2. **Sync Status UI:** Show sync status indicator (syncing/synced/offline)
3. **Manual Sync:** Allow user to trigger manual sync
4. **Sync History:** Log sync attempts for debugging

## References

- **Local-First Principles:** [Local-First Software](https://www.inkandswitch.com/local-first/)
- **Hexagonal Architecture:** Clean separation of domain, infrastructure, presentation
- **Event-Driven Sync:** Domain events trigger async operations
- **API Spec:** `docs/api-spec.yaml` - Physical Profile endpoints

---

**Status:** ✅ Fixed  
**Date:** 2025-01-27  
**Architecture:** Local-First (Local Storage as Source of Truth)  
**Sync:** Async via event-driven ProfileSyncService
