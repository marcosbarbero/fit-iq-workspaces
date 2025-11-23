# Chat Archive/Delete Backend Sync Status

**Date:** 2025-01-29  
**Status:** ⚠️ Partially Implemented  
**Components:** ChatRepository, ChatService, Backend API  

---

## Current Implementation Status

### ✅ Delete - FULLY SYNCED

**Status:** Backend sync is implemented and working

**Flow:**
1. User deletes conversation (swipe or menu)
2. `ChatViewModel.deleteConversation()` called
3. `ChatRepository.deleteConversation()` called
4. **Backend deletion** via `ChatService.deleteConversation()`
5. Local database deletion
6. UI update

**Backend Endpoint:** 
```
DELETE /api/v1/consultations/{id}
```

**Behavior:**
- Deletes from backend FIRST (if online)
- If backend deletion fails, still deletes locally (offline support)
- All messages are deleted cascade-style
- Conversation removed from both backend and local DB

**Code Location:**
```swift
// ChatRepository.swift - Line ~306
func deleteConversation(_ id: UUID) async throws {
    // Sync deletion to backend first
    try await chatService.deleteConversation(id: id)
    
    // Delete from local database
    // ... SwiftData deletion code
}
```

---

### ⚠️ Archive - LOCAL ONLY (NOT SYNCED)

**Status:** Backend sync is NOT yet implemented

**Current Flow:**
1. User archives conversation (swipe or menu)
2. `ChatViewModel.archiveConversation()` called
3. `ChatRepository.archiveConversation()` called
4. **Local database only** - `isArchived = true`
5. UI update

**Why Not Synced?**

The backend Swagger documentation shows:
- ✅ Consultation has `archived` status in the enum
- ❌ No dedicated `POST /api/v1/consultations/{id}/archive` endpoint
- ❌ No dedicated `POST /api/v1/consultations/{id}/unarchive` endpoint

**Possible Backend Implementation:**

The backend DOES support archived status, so there are two possible approaches:

#### Option 1: Status Update Endpoint (Recommended)
```
PATCH /api/v1/consultations/{id}/status
Body: { "status": "archived" }
```

#### Option 2: Dedicated Archive Endpoints
```
POST /api/v1/consultations/{id}/archive
POST /api/v1/consultations/{id}/unarchive
```

**Current Workaround:**

Archive/unarchive is stored locally. When the app fetches conversations from the backend, the local archive flag is preserved but won't sync across devices.

**Code Location:**
```swift
// ChatRepository.swift - Line ~250
func archiveConversation(_ id: UUID) async throws -> ChatConversation {
    // Update local database only
    sdConversation.isArchived = true
    try modelContext.save()
    
    // TODO: Sync to backend when endpoint available
    print("⚠️ Archive is local-only, backend sync not implemented")
}
```

---

### ⚠️ Unarchive - LOCAL ONLY (NOT SYNCED)

**Status:** Backend sync is NOT yet implemented

**Current Flow:**
1. User unarchives conversation
2. `ChatViewModel.unarchiveConversation()` called
3. `ChatRepository.unarchiveConversation()` called
4. **Local database only** - `isArchived = false`
5. UI update

**Code Location:**
```swift
// ChatRepository.swift - Line ~279
func unarchiveConversation(_ id: UUID) async throws -> ChatConversation {
    // Update local database only
    sdConversation.isArchived = false
    try modelContext.save()
    
    // TODO: Sync to backend when endpoint available
    print("⚠️ Unarchive is local-only, backend sync not implemented")
}
```

---

## Impact Analysis

### What Works

✅ **Delete syncs to backend** - Conversation deleted everywhere  
✅ **Archive works locally** - User can organize chats in-app  
✅ **Unarchive works locally** - User can restore archived chats  
✅ **Offline delete** - Deletes locally if backend unavailable  

### What Doesn't Work

❌ **Archive doesn't sync across devices** - Archive on iPhone, still active on iPad  
❌ **Backend can't filter archived** - Server doesn't know which conversations are archived  
❌ **Data inconsistency** - Local archive state can diverge from backend  
❌ **No archive recovery** - If app reinstalled, archive state is lost  

---

## User Experience Impact

### Single Device Users
- ✅ **No impact** - Archive works perfectly for local organization
- ✅ Delete works as expected

### Multi-Device Users
- ⚠️ **Archive doesn't sync** - Must archive on each device separately
- ⚠️ **Inconsistent state** - Archived on phone but active on tablet
- ✅ Delete syncs correctly across all devices

### App Reinstall
- ❌ **Archive state lost** - All conversations appear as active
- ✅ Delete state preserved - Deleted conversations stay deleted

---

## Recommended Backend Changes

### Priority 1: Archive Endpoint (High Priority)

Add dedicated archive endpoint:

```yaml
/api/v1/consultations/{id}/archive:
  post:
    summary: Archive a consultation
    description: Mark consultation as archived for the user
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      '200':
        description: Consultation archived successfully
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ConsultationResponse'
      '404':
        description: Consultation not found
```

### Priority 2: Unarchive Endpoint (High Priority)

```yaml
/api/v1/consultations/{id}/unarchive:
  post:
    summary: Unarchive a consultation
    description: Restore consultation to active state
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      '200':
        description: Consultation unarchived successfully
```

### Alternative: Generic Status Update (Medium Priority)

```yaml
/api/v1/consultations/{id}/status:
  patch:
    summary: Update consultation status
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              status:
                type: string
                enum: [active, completed, archived, abandoned]
    responses:
      '200':
        description: Status updated successfully
```

---

## iOS Implementation Plan (After Backend Added)

### Step 1: Add Service Methods

```swift
// ChatServiceProtocol.swift
protocol ChatServiceProtocol {
    func archiveConversation(id: UUID) async throws
    func unarchiveConversation(id: UUID) async throws
}

// ChatService.swift
func archiveConversation(id: UUID) async throws {
    let token = try await getAccessToken()
    try await backendService.archiveConsultation(id: id, token: token)
}
```

### Step 2: Update Repository

```swift
// ChatRepository.swift
func archiveConversation(_ id: UUID) async throws -> ChatConversation {
    // Sync to backend first
    try await chatService.archiveConversation(id: id)
    
    // Then update local database
    sdConversation.isArchived = true
    try modelContext.save()
    
    return try await fetchConversationById(id)!
}
```

### Step 3: Add Backend Service Method

```swift
// ChatBackendService.swift
func archiveConsultation(id: UUID, token: String) async throws {
    let url = baseURL.appendingPathComponent("api/v1/consultations/\(id)/archive")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    
    let (_, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw ChatBackendError.archiveFailed
    }
}
```

### Step 4: Testing

- [ ] Archive on device A, verify synced to device B
- [ ] Unarchive on device A, verify synced to device B
- [ ] Archive offline, verify syncs when online
- [ ] Delete app and reinstall, verify archive state restored

---

## Temporary Workarounds

### For Single Device Users
- ✅ Current implementation works fine
- No action needed

### For Multi-Device Users

**Option 1: Complete Endpoint**
Backend can use the existing `complete` endpoint as a proxy:
```
POST /api/v1/consultations/{id}/complete
```
Then on iOS, treat "completed" as "archived" in the UI.

**Option 2: Local-Only Warning**
Add UI hint: "Archive is device-specific and won't sync across devices"

**Option 3: Use Tags/Labels (Future)**
If backend adds tagging system, use "archived" tag instead of status.

---

## Migration Strategy

### When Backend Endpoints Are Added

1. **Detect Old Archive Data:**
   - Query local DB for conversations where `isArchived = true`
   - Sync each to backend on next app launch

2. **Migration Code:**
```swift
func migrateLocalArchiveStateToBackend() async {
    let archivedConversations = try await chatRepository.fetchArchivedConversations()
    
    for conversation in archivedConversations {
        do {
            try await chatService.archiveConversation(id: conversation.id)
            print("✅ Migrated archive state for: \(conversation.id)")
        } catch {
            print("❌ Failed to migrate: \(conversation.id)")
        }
    }
}
```

3. **Run Migration:**
   - On app update to version with backend sync
   - One-time migration at launch
   - Background task to prevent blocking UI

---

## Testing Checklist

### Delete (Backend Synced)
- [x] Delete from chat list → Deleted on backend
- [x] Delete from chat view → Deleted on backend
- [x] Delete offline → Syncs when online
- [x] Delete on device A → Removed on device B
- [x] Reinstall app → Deleted conversations stay deleted

### Archive (Local Only)
- [x] Archive from chat list → Saved locally
- [x] Archive from chat view → Saved locally
- [ ] Archive on device A → NOT synced to device B ⚠️
- [ ] Reinstall app → Archive state LOST ⚠️
- [x] Offline archive → Works (local only)

### Unarchive (Local Only)
- [x] Unarchive from list → Restored locally
- [ ] Unarchive on device A → NOT synced to device B ⚠️
- [x] Works offline → Yes (local only)

---

## Monitoring & Logs

### Success Logs

```
✅ [ChatRepository] Deleted from backend: <UUID>
✅ [ChatRepository] Deleted locally: <UUID>
✅ [ChatViewModel] Deleted conversation: <UUID>
```

### Warning Logs

```
⚠️ [ChatRepository] Archive is local-only, backend sync not yet implemented
⚠️ [ChatRepository] Unarchive is local-only, backend sync not yet implemented
```

### Error Logs

```
❌ [ChatRepository] Backend deletion failed: <error>
❌ [ChatViewModel] Failed to delete conversation: <error>
```

---

## Conclusion

**Current State:**
- ✅ Delete operations are **fully synced** to backend
- ⚠️ Archive/unarchive operations are **local-only**

**Recommendation:**
- Backend team should add archive/unarchive endpoints
- iOS implementation is ready to integrate once endpoints available
- Current implementation is acceptable for single-device users
- Multi-device users will experience archive sync issues

**Priority:**
- **High** - Add backend archive/unarchive endpoints
- **Medium** - Implement iOS sync once endpoints ready
- **Low** - Add migration for existing local archive states

---

## Related Files

**iOS Implementation:**
- `lume/Presentation/ViewModels/ChatViewModel.swift` - Archive/delete actions
- `lume/Data/Repositories/ChatRepository.swift` - Database operations
- `lume/Services/ChatService.swift` - Backend service calls
- `lume/Services/Backend/ChatBackendService.swift` - HTTP requests

**Backend Documentation:**
- `lume/docs/swagger-consultations.yaml` - API specification
- Backend should add `/archive` and `/unarchive` endpoints

**Status:** Documented and tracked for future implementation ⚠️