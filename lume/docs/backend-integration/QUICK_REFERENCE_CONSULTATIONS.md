# Consultations API Quick Reference

**Version:** 2.0.0  
**Last Updated:** 2025-01-15

---

## Endpoint

```
GET /api/v1/consultations
```

---

## Query Parameters

```swift
status: String?      // "pending", "active", "completed", "abandoned", "archived"
persona: String?     // "nutritionist", "fitness_coach", "wellness_specialist", "general_wellness"
limit: Int          // 1-100, default: 20
offset: Int         // ≥0, default: 0
```

---

## Response Structure

```json
{
  "success": true,
  "data": {
    "consultations": [
      {
        "id": "uuid",
        "user_id": "uuid",
        "persona": "general_wellness",
        "status": "active",
        "goal_id": "uuid",
        "context_type": "goal",
        "context_id": "uuid",
        "quick_action": null,
        "started_at": "2025-01-15T10:00:00Z",
        "completed_at": null,
        "last_message_at": "2025-01-15T14:30:00Z",
        "message_count": 12,
        "created_at": "2025-01-15T10:00:00Z",
        "updated_at": "2025-01-15T14:30:00Z"
      }
    ],
    "total_count": 42,
    "limit": 20,
    "offset": 0
  }
}
```

---

## Common Usage Patterns

### 1. Load Active Consultations

```swift
// ViewModel
await loadConversations()

// Use Case
let conversations = try await fetchConversationsUseCase.execute(
    includeArchived: false,
    syncFromBackend: true,
    status: "active",
    persona: nil,
    limit: 50,
    offset: 0
)
```

### 2. Load All History

```swift
let conversations = try await fetchConversationsUseCase.execute(
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
let conversations = try await fetchConversationsUseCase.fetchByPersona(
    .wellnessSpecialist,
    syncFromBackend: true,
    limit: 20,
    offset: 0
)
```

### 4. Load More (Pagination)

```swift
// First page
let page1 = try await chatService.fetchConversations(
    status: nil,
    persona: nil,
    limit: 20,
    offset: 0
)

// Next page
let page2 = try await chatService.fetchConversations(
    status: nil,
    persona: nil,
    limit: 20,
    offset: 20
)
```

### 5. Recent Activity (Last 24 Hours)

```swift
let conversations = try await fetchConversationsUseCase.fetchWithRecentActivity(
    syncFromBackend: true,
    limit: 20,
    offset: 0
)
```

### 6. Search by Title

```swift
let conversations = try await fetchConversationsUseCase.search(
    query: "wellness",
    syncFromBackend: false,
    limit: 100,
    offset: 0
)
```

---

## Architecture Layers

```
ChatViewModel (Presentation)
    ↓
FetchConversationsUseCase (Domain)
    ↓
ChatService (Service)
    ↓
ChatBackendService (Infrastructure)
    ↓
Backend API
```

---

## Error Handling

```swift
do {
    let conversations = try await chatService.fetchConversations(
        status: "active",
        persona: nil,
        limit: 20,
        offset: 0
    )
} catch {
    print("❌ Failed to fetch: \(error.localizedDescription)")
    // Fall back to local data
    conversations = try await chatRepository.fetchAllConversations()
}
```

---

## Status Values

| Status | Description |
|--------|-------------|
| `pending` | Consultation created but not started |
| `active` | Ongoing consultation |
| `completed` | Consultation finished normally |
| `abandoned` | User stopped responding |
| `archived` | User manually archived |

---

## Persona Values

| Persona | Use Case |
|---------|----------|
| `nutritionist` | Nutrition advice |
| `fitness_coach` | Exercise guidance |
| `wellness_specialist` | Holistic wellness |
| `general_wellness` | General conversations |

---

## Performance Tips

1. **Default limit: 20** - Fast initial load
2. **Use limit: 100** - Full sync scenarios
3. **Filter on backend** - More efficient than local filtering
4. **Cache locally** - Avoid redundant requests
5. **Sync on app launch** - Background thread

---

## Testing Scenarios

- [ ] Empty result (no consultations)
- [ ] Single consultation
- [ ] Multiple consultations (>20)
- [ ] Filter by status
- [ ] Filter by persona
- [ ] Pagination (load more)
- [ ] Error handling (401, 404, 500)
- [ ] Cross-device sync

---

## Related Files

```
lume/Services/Backend/ChatBackendService.swift
lume/Services/ChatService.swift
lume/Domain/UseCases/Chat/FetchConversationsUseCase.swift
lume/Domain/Ports/ChatServiceProtocol.swift
lume/Presentation/ViewModels/ChatViewModel.swift
docs/swagger-consultations.yaml
```

---

## Key Methods

### Backend Service
```swift
ChatBackendService.fetchAllConversations(
    status: String?,
    persona: ChatPersona?,
    limit: Int,
    offset: Int,
    accessToken: String
) -> [ChatConversation]
```

### Service Layer
```swift
ChatService.fetchConversations(
    status: String?,
    persona: ChatPersona?,
    limit: Int,
    offset: Int
) -> [ChatConversation]
```

### Use Case Layer
```swift
FetchConversationsUseCase.execute(
    includeArchived: Bool,
    syncFromBackend: Bool,
    status: String?,
    persona: ChatPersona?,
    limit: Int,
    offset: Int
) -> [ChatConversation]
```

---

## Quick Debug Checklist

1. ✅ Token valid? (`await tokenStorage.getAccessToken()`)
2. ✅ Backend reachable? (Check network)
3. ✅ Valid parameters? (status/persona values)
4. ✅ Pagination correct? (offset < total_count)
5. ✅ Local sync working? (Check repository)

---

## Need More Info?

- Full guide: [CONSULTATIONS_LIST_ENDPOINT.md](./CONSULTATIONS_LIST_ENDPOINT.md)
- API changes: [CONSULTATIONS_API_CHANGES.md](./CONSULTATIONS_API_CHANGES.md)
- Swagger spec: [swagger-consultations.yaml](../swagger-consultations.yaml)