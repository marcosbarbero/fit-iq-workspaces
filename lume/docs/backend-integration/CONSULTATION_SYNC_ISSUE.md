# Consultation Sync Issue and Backend API Limitations

**Date:** 2025-01-15  
**Status:** KNOWN LIMITATION  
**Severity:** HIGH (Blocks users after app reinstall or device switch)

---

## Problem Summary

Users cannot access their existing AI chat consultations after:
- Reinstalling the app
- Switching to a new device
- Clearing app data

This results in **409 Conflict** errors when trying to create a new chat, but the existing consultation cannot be discovered or accessed.

---

## Technical Details

### Backend API Limitations

The backend currently has these endpoints:

| Endpoint | Method | Status | Purpose |
|----------|--------|--------|---------|
| `/api/v1/consultations` | POST | ✅ Works | Create new consultation |
| `/api/v1/consultations/{id}` | GET | ✅ Works | Fetch specific consultation by ID |
| `/api/v1/consultations/{id}/messages` | POST | ✅ Works | Send message to consultation |
| `/api/v1/consultations` | GET | ❌ 405 Not Allowed | List all consultations |

**Missing Capability:** There is no way to discover what consultation IDs exist for a user.

### Backend Business Rule

The backend enforces: **One active consultation per persona per user**

When attempting to create a duplicate consultation:
```
POST /api/v1/consultations
{
  "persona": "wellness_specialist"
}

Response: 409 Conflict
{
  "error": {
    "message": "conflicting consultation: already have an active consultation for this persona and goal"
  }
}
```

**Problem:** The 409 response doesn't include the existing consultation's ID.

### Current App Behavior

#### Normal Flow (Works ✅)
1. User creates consultation → Backend returns ID
2. App saves consultation locally with backend ID
3. User opens chat → App finds it in local database
4. ✅ Chat works perfectly

#### Reinstall/New Device Flow (Broken ❌)
1. Local database is empty (no consultation records)
2. User tries to create consultation
3. Backend returns 409 (consultation already exists)
4. App can't discover the existing consultation ID
5. ❌ User is stuck - can't create new chat, can't access existing one

### Error Message Shown to User

```
A chat already exists on the server but can't be accessed from this device. 
This can happen after reinstalling the app or switching devices. 
Please contact support to reset your chat history, or try logging out and back in.
```

---

## Root Cause Analysis

### Why This Happens

1. **No Discovery Mechanism**
   - Backend doesn't provide `GET /api/v1/consultations` to list consultations
   - 409 error doesn't include existing consultation ID
   - No way to query consultations by persona

2. **Local-Only Tracking**
   - App tracks consultations in local SwiftData database
   - When local database is cleared, consultation IDs are lost
   - Can't reconstruct consultation list from backend

3. **Strict Business Rule**
   - One consultation per persona limit prevents workaround
   - Can't just create a new consultation with different persona

### Impact

- **High Impact Scenarios:**
  - User reinstalls app → permanently blocked from AI chat
  - User switches devices → can't access existing chats
  - App cache cleared → loses all consultation history

- **User Experience:**
  - Confusing error message
  - No self-service recovery
  - Requires support intervention

---

## Recommended Backend Fixes

### Option 1: Add List Consultations Endpoint (BEST)

**Endpoint:** `GET /api/v1/consultations`

**Response:**
```json
{
  "data": {
    "consultations": [
      {
        "id": "uuid",
        "persona": "wellness_specialist",
        "title": "Wellness Chat",
        "created_at": "2025-01-15T10:00:00Z",
        "updated_at": "2025-01-15T12:00:00Z",
        "is_archived": false,
        "message_count": 42
      }
    ]
  }
}
```

**Benefits:**
- ✅ Enables full consultation sync across devices
- ✅ Allows app to discover existing consultations
- ✅ Standard REST pattern
- ✅ Fixes all sync issues

**Implementation Notes:**
- Filter by authenticated user ID
- Support pagination (optional)
- Include basic metadata (don't need full message history)

---

### Option 2: Include Existing ID in 409 Response

**Modified 409 Response:**
```json
{
  "error": {
    "code": "CONSULTATION_EXISTS",
    "message": "already have an active consultation for this persona and goal",
    "existing_consultation_id": "uuid-of-existing-consultation"
  }
}
```

**Benefits:**
- ✅ Minimal backend change
- ✅ App can fetch existing consultation immediately
- ✅ Solves 409 error problem

**App Implementation:**
```swift
catch let error as HTTPError where error.isConflict {
    // Parse consultation ID from error response
    if let consultationId = parseExistingIdFromError(error) {
        // Fetch the existing consultation
        let existing = try await fetchConversation(id: consultationId)
        // Save it locally and open it
    }
}
```

---

### Option 3: Allow Multiple Consultations Per Persona

**Remove or relax the one-per-persona limit**

**Benefits:**
- ✅ Users can create new consultation if lost
- ✅ More flexible for advanced use cases

**Drawbacks:**
- Changes business logic
- May not align with product requirements
- Doesn't solve discovery problem

---

## Current App-Side Mitigations

### Implemented ✅

1. **Check Local Database First**
   - Before creating consultation, check if one exists locally
   - Reuse existing consultation if found
   - Prevents most 409 errors

2. **Graceful 409 Handling**
   - Search local database when 409 occurs
   - Show clear error message if not found locally
   - Provide guidance to user

3. **Graceful Backend Sync Failures**
   - Attempt to sync from backend
   - Continue with local data if sync fails
   - App works offline with local data

### Limitations ❌

1. **Can't discover consultations from backend**
   - No way to sync after reinstall
   - No cross-device consultation access

2. **No self-service recovery**
   - User must contact support
   - Manual intervention required

3. **Data loss risk**
   - Old consultations inaccessible after reinstall
   - Message history lost from user perspective

---

## Workarounds for Users

### If User Gets 409 Error:

1. **Try Logging Out and Back In**
   - May trigger a fresh sync (limited effectiveness)

2. **Contact Support**
   - Support can delete backend consultation
   - User can then create a new one

3. **Wait for Backend Fix**
   - Once backend implements Option 1 or 2, app will work

### For Developers:

**Temporary Backend Data Clear (if backend supports):**
```bash
# If backend has admin endpoint to clear user consultations
DELETE /api/v1/admin/users/{userId}/consultations
```

**Database Reset:**
```bash
# User can clear app data as last resort
# Settings → Lume → Clear Data
# But this loses all local data (moods, journals, etc.)
```

---

## Testing Scenarios

### Test Case 1: Normal Flow ✅
1. Fresh install
2. Create consultation
3. Send messages
4. **Expected:** Works perfectly

### Test Case 2: Reuse Existing ✅
1. Open app with existing consultation
2. Try to create new consultation with same persona
3. **Expected:** Finds and opens existing consultation

### Test Case 3: Reinstall (Known Issue ❌)
1. Have existing consultation on backend
2. Reinstall app (clear local data)
3. Try to create consultation
4. **Expected:** 409 error, clear message shown
5. **Actual:** User blocked from using chat

### Test Case 4: Device Switch (Known Issue ❌)
1. Create consultation on Device A
2. Install app on Device B
3. Login with same account
4. Try to create consultation
5. **Expected:** Should sync and show existing consultation
6. **Actual:** 409 error, can't access chat

---

## Metrics to Track

1. **409 Error Rate**
   - How often users hit this issue
   - Indicates severity of problem

2. **Support Tickets**
   - "Can't create chat" complaints
   - "Chat disappeared" issues

3. **User Drop-off**
   - Users who hit 409 and stop using app
   - Conversion impact

---

## Communication

### For Product Team
- High severity issue blocking chat feature after reinstall
- Requires backend changes to fully resolve
- Currently showing helpful error message to users

### For Backend Team
- Need `GET /api/v1/consultations` endpoint (Option 1)
- OR modify 409 response to include existing ID (Option 2)
- See technical specs above

### For Support Team
- Known issue: Users can't access chat after reinstall
- Workaround: Backend team can clear consultation
- Tell users: "This is a known issue we're fixing"

---

## Timeline

- **2025-01-15:** Issue identified and documented
- **TBD:** Backend team implements Option 1 or 2
- **TBD:** App updated to use new endpoint/response
- **TBD:** Issue resolved

---

## Related Files

- `lume/lume/Presentation/ViewModels/ChatViewModel.swift` - 409 handling
- `lume/lume/Services/Backend/ChatBackendService.swift` - API calls
- `lume/lume/Data/Repositories/ChatRepository.swift` - Local storage
- `lume/docs/backend-integration/CONSULTATIONS_API.md` - API documentation

---

## Conclusion

This is a **backend API limitation** that prevents proper consultation sync across devices and app reinstalls.

**Recommended Action:** Backend team should implement Option 1 (list consultations endpoint) for complete solution.

**Current Status:** App handles the limitation gracefully with clear error messages, but users are blocked from using chat after reinstall/device switch.

**Priority:** HIGH - Impacts core feature accessibility