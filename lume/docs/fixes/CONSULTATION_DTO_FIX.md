# Consultation DTO Decoding Fix

**Date:** 2025-01-15  
**Issue:** Decoding error when fetching consultation from backend  
**Status:** ✅ Fixed

---

## Problem

When fetching a consultation by ID via `GET /api/v1/consultations/{id}`, the app was failing to decode the response with the following error:

```
⚠️ [FetchConversationsUseCase] Backend fetch failed, checking local: 
decodingFailed(Swift.DecodingError.keyNotFound(
    CodingKeys(stringValue: "title", intValue: nil), 
    Swift.DecodingError.Context(
        codingPath: [CodingKeys(stringValue: "data", intValue: nil)], 
        debugDescription: "No value associated with key CodingKeys(stringValue: \"title\", intValue: nil) (\"title\").", 
        underlyingError: nil
    )
))
```

### Root Cause

The `ConversationDTO` model was expecting a `title` field in the backend response, but the backend API does not return this field. The consultation API returns:

```json
{
  "data": {
    "id": "66a66183-4639-47fb-a5ec-b150a54033fe",
    "user_id": "15d3af32-a0f7-424c-952a-18c372476bfe",
    "persona": "wellness_specialist",
    "status": "active",
    "started_at": "2025-11-17T22:03:09Z",
    "message_count": 0,
    "created_at": "2025-11-17T22:03:09Z",
    "updated_at": "2025-11-17T22:03:09Z"
  }
}
```

**Note:** No `title` field exists in the backend response.

---

## Solution

Updated `ConversationDTO` in `ChatBackendService.swift` to match the actual backend API response structure.

### Changes Made

#### Before (Incorrect)
```swift
private struct ConversationDTO: Decodable {
    let id: String
    let user_id: String
    let title: String              // ❌ Not in backend response
    let persona: String
    let messages: [MessageDTO]?
    let created_at: Date
    let updated_at: Date
    let is_archived: Bool          // ❌ Not in backend response
    let context: ConversationContextDTO?  // ❌ Wrong structure
}
```

#### After (Correct)
```swift
private struct ConversationDTO: Decodable {
    let id: String
    let user_id: String
    let persona: String
    let status: String             // ✅ Added
    let goal_id: String?           // ✅ Added
    let context_type: String?      // ✅ Added
    let context_id: String?        // ✅ Added
    let quick_action: String?      // ✅ Added
    let started_at: Date?          // ✅ Added
    let completed_at: Date?        // ✅ Added
    let last_message_at: Date?     // ✅ Added
    let message_count: Int         // ✅ Added
    let messages: [MessageDTO]?
    let created_at: Date
    let updated_at: Date
}
```

### Title Generation

Since the backend doesn't provide a `title`, we generate one based on the persona:

```swift
func toDomain() -> ChatConversation {
    // Generate title based on persona
    let personaEnum = ChatPersona(rawValue: persona) ?? .generalWellness
    let generatedTitle = "Chat with \(personaEnum.displayName)"
    
    // Determine if archived based on status
    let isArchived = status == "archived"
    
    // Build context if available
    var contextObj: ConversationContext?
    if let goalId = goal_id, let goalUUID = UUID(uuidString: goalId) {
        contextObj = ConversationContext(
            relatedGoalIds: [goalUUID],
            quickAction: quick_action
        )
    } else if let quickActionValue = quick_action {
        contextObj = ConversationContext(
            quickAction: quickActionValue
        )
    }
    
    return ChatConversation(
        id: UUID(uuidString: id) ?? UUID(),
        userId: UUID(uuidString: user_id) ?? UUID(),
        title: generatedTitle,  // ✅ Generated, not from backend
        persona: personaEnum,
        messages: messages?.map { $0.toDomain(conversationId: UUID(uuidString: id) ?? UUID()) } ?? [],
        createdAt: created_at,
        updatedAt: updated_at,
        isArchived: isArchived,  // ✅ Derived from status
        context: contextObj
    )
}
```

---

## Backend API Fields

### Actual Response Fields (from Swagger spec)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (UUID) | Yes | Consultation ID |
| `user_id` | string (UUID) | Yes | User ID |
| `persona` | string | Yes | AI persona type |
| `status` | string | Yes | Status (pending, active, completed, abandoned, archived) |
| `goal_id` | string (UUID) | No | Related goal ID |
| `context_type` | string | No | Context type (general, goal, insight, mood, journal) |
| `context_id` | string | No | Context ID |
| `quick_action` | string | No | Quick action ID that started this |
| `started_at` | string (ISO 8601) | No | When consultation started |
| `completed_at` | string (ISO 8601) | No | When consultation completed |
| `last_message_at` | string (ISO 8601) | No | Last message timestamp |
| `message_count` | integer | Yes | Number of messages |
| `created_at` | string (ISO 8601) | Yes | Creation timestamp |
| `updated_at` | string (ISO 8601) | Yes | Last update timestamp |

### Fields NOT in Backend Response

- `title` - Not provided by backend
- `is_archived` - Use `status == "archived"` instead
- `context` - Use `goal_id`, `context_type`, `context_id` instead

---

## Impact

### ✅ Fixed Issues

1. **Decoding no longer fails** - App can now fetch consultations from backend
2. **Cross-device sync works** - Consultations sync correctly across devices
3. **No more 404 fallback** - App successfully fetches existing consultations
4. **Status tracking** - App now correctly handles consultation status

### 📊 Generated Titles

Consultations now have auto-generated titles based on persona:

| Persona | Generated Title |
|---------|----------------|
| `general_wellness` | "Chat with General Wellness" |
| `wellness_specialist` | "Chat with Wellness Specialist" |
| `nutritionist` | "Chat with Nutritionist" |
| `fitness_coach` | "Chat with Fitness Coach" |

---

## Testing

### Test Case 1: Fetch Single Consultation

```swift
let conversation = try await chatService.fetchConversation(
    id: UUID(uuidString: "66a66183-4639-47fb-a5ec-b150a54033fe")!
)

// Expected:
// - conversation.title = "Chat with Wellness Specialist"
// - conversation.persona = .wellnessSpecialist
// - conversation.isArchived = false (status is "active")
// - No decoding errors
```

### Test Case 2: Fetch All Consultations

```swift
let conversations = try await chatService.fetchConversations(
    status: "active",
    persona: nil,
    limit: 20,
    offset: 0
)

// Expected:
// - All consultations decoded successfully
// - Each has a generated title
// - isArchived correctly derived from status
```

### Test Case 3: Cross-Device Sync

```swift
// Device 1: Create consultation
let newChat = try await chatService.createConversation(
    title: "My Chat",
    persona: .wellnessSpecialist,
    context: nil
)

// Device 2: Fetch from backend
let synced = try await chatService.fetchConversation(id: newChat.id)

// Expected:
// - synced.id == newChat.id
// - synced.title = "Chat with Wellness Specialist" (generated)
// - No decoding errors
```

---

## Related Files

- `lume/Services/Backend/ChatBackendService.swift` - Fixed DTO
- `lume/Domain/Entities/ChatMessage.swift` - Domain models
- `docs/swagger-consultations.yaml` - API specification
- `docs/backend-integration/CONSULTATIONS_LIST_ENDPOINT.md` - Endpoint docs

---

## Lessons Learned

1. **Always match API spec** - DTO must exactly match backend response
2. **Generate missing fields** - If backend doesn't provide a field, generate it
3. **Test with real responses** - Use actual backend responses for testing
4. **Document field mappings** - Clearly document how backend fields map to domain models
5. **Handle optionals** - Backend fields may be nullable, handle gracefully

---

## Verification

### Before Fix
```
URL: https://fit-iq-backend.fly.dev/api/v1/consultations/{id}
Status: 200 OK
Result: ❌ Decoding error - "No value associated with key title"
```

### After Fix
```
URL: https://fit-iq-backend.fly.dev/api/v1/consultations/{id}
Status: 200 OK
Result: ✅ Successfully decoded
        Title: "Chat with Wellness Specialist"
        Status: active
        Messages: 0
```

---

## Future Improvements

1. **Backend: Add title field** - Consider adding optional `title` field to backend API
2. **Custom titles** - Allow users to customize consultation titles
3. **Title formatting** - More descriptive titles based on context (e.g., "Goal: Run 5K")
4. **Title history** - Track title changes over time

---

## Summary

The consultation DTO has been fixed to match the actual backend API response. The app now:

✅ Successfully decodes consultation responses  
✅ Generates appropriate titles from persona  
✅ Correctly handles status and archived state  
✅ Properly maps context fields  
✅ Enables cross-device synchronization  

**Impact:** High - Fixes critical decoding error preventing consultation sync  
**Risk:** Low - Changes are backward compatible  
**Testing:** Verified with real backend responses