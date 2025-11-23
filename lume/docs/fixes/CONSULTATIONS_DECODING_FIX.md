# Consultations Decoding Fix

**Date:** January 29, 2025  
**Issue:** Backend API returns `"consultations"` but Swift DTO expected `"conversations"`  
**Status:** ✅ Fixed

---

## Problem

The backend API endpoint `/api/v1/consultations` returns:

```json
{
  "data": {
    "consultations": [...],  // ← Backend uses "consultations"
    "total_count": 1,
    "limit": 100,
    "offset": 0
  }
}
```

But the Swift DTO was expecting:

```swift
struct ConversationsListData: Decodable {
    let conversations: [ConversationDTO]  // ← Was looking for "conversations"
    // ...
}
```

This caused a decoding error:

```
keyNotFound(CodingKeys(stringValue: "conversations", intValue: nil))
No value associated with key "conversations"
```

---

## Root Cause

**Backend terminology:** The API uses "consultations" (mental health/wellness terminology)  
**App terminology:** The app internally uses "conversations" (chat terminology)

The DTO tried to match Swift naming but didn't account for backend API field names.

---

## Solution

### Updated ConversationsListData DTO

**File:** `lume/Services/Backend/ChatBackendService.swift`

```swift
private struct ConversationsListData: Decodable {
    let consultations: [ConversationDTO]  // ← Changed from conversations
    let total_count: Int
    let limit: Int
    let offset: Int
    
    enum CodingKeys: String, CodingKey {  // ← Added for clarity
        case consultations
        case total_count
        case limit
        case offset
    }
}
```

### Updated Usage

```swift
func fetchAllConversations(...) async throws -> [ChatConversation] {
    let response: ConversationsListResponse = try await httpClient.get(...)
    
    // Changed from: response.data.conversations
    return response.data.consultations.map { $0.toDomain() }
}
```

---

## Key Insights

### API Terminology vs. Internal Terminology

The backend uses healthcare/wellness terminology:
- **Consultations** (sessions with AI wellness coach)
- **Messages** (within consultations)

The app uses conversational/chat terminology internally:
- **Conversations** (domain model)
- **Messages** (within conversations)

### The Translation Layer

The DTO layer acts as a translation between API and domain:

```
Backend API              DTO Layer              Domain Layer
─────────────────────────────────────────────────────────────
consultations    →    ConversationDTO    →    ChatConversation
messages         →    MessageDTO         →    ChatMessage
persona          →    persona            →    ChatPersona
```

This is **correct architecture** - the domain layer should use app-appropriate terminology, and DTOs handle translation.

---

## Testing

### Before Fix

```
❌ [HTTPClient] Decoding failed for type: ConversationsListResponse
🔍 [HTTPClient] Decoding error: keyNotFound("conversations")
```

### After Fix

```
✅ [ChatBackendService] Fetched 1 conversations (total: 1, limit: 100, offset: 0)
```

---

## Related Issues

This same pattern might exist in other DTOs. Check for:

1. ❓ **WebSocket messages** - Do they use "consultation_id" or "conversation_id"?
   - ✅ Already correctly using `consultation_id` in `WebSocketMessageWrapper`

2. ❓ **Message endpoints** - Do they reference consultations?
   - ✅ Already correctly using `/api/v1/consultations/{id}/messages`

3. ❓ **Create conversation** - Does it use consultations endpoint?
   - ✅ Already correctly using `/api/v1/consultations` (POST)

---

## Best Practices

### 1. Always Match Backend Field Names in DTOs

```swift
// ✅ Good - Matches backend exactly
private struct BackendResponse: Decodable {
    let consultations: [ConsultationDTO]
}

// ❌ Bad - Assumes backend field name
private struct BackendResponse: Decodable {
    let conversations: [ConsultationDTO]
}
```

### 2. Use Explicit CodingKeys for Clarity

```swift
struct ConversationsListData: Decodable {
    let consultations: [ConversationDTO]
    
    enum CodingKeys: String, CodingKey {
        case consultations  // Makes it explicit what we're decoding
        case total_count
        case limit
        case offset
    }
}
```

### 3. Keep Domain Pure

```swift
// Domain layer uses app terminology
struct ChatConversation {
    // Uses "conversation" terminology internally
}

// DTO translates from backend terminology
struct ConversationDTO: Decodable {
    // Decodes "consultations" from API
    func toDomain() -> ChatConversation {
        // Translates to domain model
    }
}
```

---

## Files Changed

| File | Change | Lines |
|------|--------|-------|
| `ChatBackendService.swift` | Updated DTO field name | 4 |
| `ChatBackendService.swift` | Updated usage | 2 |

**Total:** 6 lines changed

---

## Verification

✅ No compilation errors  
✅ DTO matches backend API response  
✅ Decoding works correctly  
✅ Conversations load successfully  

---

## Impact

- **User Experience:** ✅ No change (works as expected now)
- **Architecture:** ✅ Improved (clearer DTO naming)
- **Backend Compatibility:** ✅ Fixed (matches API exactly)
- **Breaking Changes:** ❌ None (internal DTO change only)

---

## Lessons Learned

1. **Trust the API contract** - When backend says "consultations", use "consultations"
2. **DTOs are translators** - Their job is to adapt backend structure to domain models
3. **Domain terminology can differ** - That's okay, DTOs handle the translation
4. **Explicit is better** - Using CodingKeys makes the mapping obvious

---

**Status:** ✅ Complete and verified  
**Ready for:** Production use
