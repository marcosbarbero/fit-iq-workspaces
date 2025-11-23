# Consultations API Changes Summary

**Version:** 2.0.0  
**Date:** 2025-01-15  
**Status:** ✅ Implemented

---

## Overview

The `GET /api/v1/consultations` endpoint has been enhanced with filtering and pagination capabilities. This document summarizes the changes made to support the enhanced API in the Lume iOS app.

---

## What Changed

### Backend API Enhancements

The backend now supports the following query parameters on `GET /api/v1/consultations`:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `status` | string | Filter by status (pending, active, completed, abandoned, archived) | `active` |
| `persona` | string | Filter by persona (nutritionist, fitness_coach, wellness_specialist, general_wellness) | - |
| `limit` | integer | Results per page (1-100) | 20 |
| `offset` | integer | Pagination offset | 0 |

### Response Structure Changes

The response now includes pagination metadata:

```json
{
  "success": true,
  "data": {
    "consultations": [...],
    "total_count": 42,  // Total matching filters
    "limit": 20,        // Current limit
    "offset": 0         // Current offset
  }
}
```

**Changed from:**
```json
{
  "success": true,
  "data": {
    "consultations": [...],
    "total": 42,        // Old field name
    "has_more": true    // Removed in favor of offset/limit pattern
  }
}
```

---

## iOS Implementation Updates

### 1. ChatBackendService.swift

**Updated:**
- Added query parameters to `fetchAllConversations()` method
- Updated response model to use `total_count`, `limit`, `offset` instead of `total` and `has_more`

```swift
func fetchAllConversations(
    status: String? = nil,
    persona: ChatPersona? = nil,
    limit: Int = 20,
    offset: Int = 0,
    accessToken: String
) async throws -> [ChatConversation]
```

### 2. ChatServiceProtocol.swift

**Updated:**
- Enhanced `fetchConversations()` with filtering and pagination parameters

```swift
func fetchConversations(
    status: String?,
    persona: ChatPersona?,
    limit: Int,
    offset: Int
) async throws -> [ChatConversation]
```

### 3. ChatService.swift

**Updated:**
- Implemented parameter forwarding to backend service
- Added default parameter values for backward compatibility

### 4. FetchConversationsUseCase.swift

**Updated:**
- Added filtering and pagination support to `execute()` method
- Updated all convenience methods (`fetchActive()`, `fetchArchived()`, `fetchByPersona()`, etc.) to support pagination
- Backend filters applied when `syncFromBackend: true`
- Local filters still applied for offline-first behavior

```swift
func execute(
    includeArchived: Bool = false,
    syncFromBackend: Bool = true,
    status: String? = nil,
    persona: ChatPersona? = nil,
    limit: Int = 20,
    offset: Int = 0
) async throws -> [ChatConversation]
```

### 5. ChatViewModel.swift

**Updated:**
- Updated `loadConversations()` to explicitly pass filter parameters
- Changed default limit from 20 to 100 for better initial sync
- Updated comments to reflect new backend capabilities

---

## Migration Guide

### For Existing Code

**Old Usage (still works):**
```swift
let conversations = try await chatService.fetchConversations()
```

**New Usage (recommended):**
```swift
let conversations = try await chatService.fetchConversations(
    status: "active",
    persona: nil,
    limit: 20,
    offset: 0
)
```

### Backward Compatibility

✅ All changes are **fully backward compatible**  
✅ Default parameters ensure existing code works unchanged  
✅ Old response fields removed, but new fields provide equivalent functionality

---

## Use Case Examples

### 1. Load Active Consultations on App Launch

```swift
await fetchConversationsUseCase.execute(
    includeArchived: false,
    syncFromBackend: true,
    status: "active",
    persona: nil,
    limit: 50,
    offset: 0
)
```

### 2. View Complete History

```swift
await fetchConversationsUseCase.execute(
    includeArchived: true,
    syncFromBackend: true,
    status: nil,
    persona: nil,
    limit: 100,
    offset: 0
)
```

### 3. Filter by Persona

```swift
await fetchConversationsUseCase.fetchByPersona(
    .wellnessSpecialist,
    syncFromBackend: true,
    limit: 20,
    offset: 0
)
```

### 4. Paginated Loading

```swift
// Load first page
let page1 = try await chatService.fetchConversations(
    status: nil,
    persona: nil,
    limit: 20,
    offset: 0
)

// Load next page
let page2 = try await chatService.fetchConversations(
    status: nil,
    persona: nil,
    limit: 20,
    offset: 20
)
```

---

## Benefits

### ✅ Cross-Device Sync
- Users can now access consultations from any device
- No more orphaned consultations when reinstalling app
- Seamless multi-device experience

### ✅ Performance
- Pagination reduces initial load time
- Filtering reduces unnecessary data transfer
- Efficient backend queries

### ✅ Better UX
- View complete history
- Filter by persona
- Fast initial load with pagination

### ✅ Flexibility
- Support for multiple filtering strategies
- Scalable to large consultation lists
- Efficient for both mobile and backend

---

## Testing Checklist

- [x] Test with no consultations (empty result)
- [x] Test with active consultations only
- [x] Test with archived consultations
- [x] Test filtering by status
- [x] Test filtering by persona
- [x] Test pagination (offset/limit)
- [x] Test combining multiple filters
- [x] Test backward compatibility (no parameters)
- [x] Test error handling (401, 404, 500)
- [x] Test cross-device sync scenario

---

## API Version Compatibility

| iOS App Version | Min Backend API Version | Notes |
|----------------|------------------------|-------|
| 2.0.0+ | 0.34.0+ | Full support for filtering and pagination |
| 1.x.x | 0.30.0+ | Works but uses default parameters only |

---

## Known Limitations

### Current State
1. **No sorting parameter** - Results sorted by `started_at` (most recent first) on backend
2. **No search** - Cannot search consultation content via API
3. **No date range filtering** - Cannot filter by creation/update date ranges

### Workarounds
- Sorting: Client-side sorting available via use case methods
- Search: Local search implemented in `FetchConversationsUseCase.search()`
- Date filtering: Local filtering in `fetchRecent()` and `fetchWithRecentActivity()`

### Future Enhancements
See [CONSULTATIONS_LIST_ENDPOINT.md](./CONSULTATIONS_LIST_ENDPOINT.md#future-enhancements) for planned improvements.

---

## Related Documentation

- [GET /consultations Endpoint Guide](./CONSULTATIONS_LIST_ENDPOINT.md)
- [Swagger API Spec](../swagger-consultations.yaml)
- [Backend Integration Guide](./BACKEND_INTEGRATION.md)
- [Error Handling](./ERROR_HANDLING.md)

---

## Summary

The consultations API has been significantly enhanced with filtering and pagination capabilities. All Lume iOS app layers have been updated to support these new features while maintaining full backward compatibility. The changes enable better performance, cross-device sync, and improved user experience.

**Key Takeaway:** The app now has production-ready consultation synchronization that works seamlessly across devices and handles large consultation lists efficiently.