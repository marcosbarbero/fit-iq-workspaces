# Meal Log WebSocket Quick Reference

**Endpoint:** `/ws/meal-logs`  
**Authentication:** JWT token via query parameter  
**Purpose:** Real-time notifications for meal log processing  
**Last Updated:** 2025-01-27

---

## Quick Start

### 1. Connect to WebSocket

```swift
// Get service from AppDependencies
let webSocketService = appDependencies.mealLogWebSocketService

// Connect with separate handlers for success and failure
try await webSocketService.connect(
    onCompleted: { payload in
        // Handle successful meal processing
        print("✅ Meal completed: \(payload.id)")
        print("   Items: \(payload.items.count)")
        print("   Calories: \(payload.totalCalories ?? 0)")
    },
    onFailed: { payload in
        // Handle failed meal processing
        print("❌ Meal failed: \(payload.error)")
        print("   Suggestions: \(payload.suggestions ?? [])")
    }
)
```

### 2. Create Meal Log

```swift
// Submit meal via API
let localID = try await saveMealLogUseCase.execute(
    rawInput: "2 eggs, 1 slice toast, coffee",
    mealType: .breakfast,
    loggedAt: Date(),
    notes: nil
)

// WebSocket will automatically notify when processing completes
```

### 3. Handle Updates

```swift
// In ViewModel or View
private func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
    // Update UI with completed meal data
    await loadDataForSelectedDate()
}

private func handleMealLogFailed(_ payload: MealLogFailedPayload) async {
    // Show error message to user
    errorMessage = payload.error
    
    // Display suggestions if available
    if let suggestions = payload.suggestions {
        for suggestion in suggestions {
            print("💡 \(suggestion)")
        }
    }
}
```

---

## Message Types

### Server → Client

| Type | When | Payload |
|------|------|---------|
| `connected` | Connection established | `user_id`, `timestamp` |
| `pong` | Keep-alive response | `timestamp` |
| `meal_log.completed` | AI processing succeeded | Full meal data + items |
| `meal_log.failed` | AI processing failed | Error + suggestions |
| `error` | Connection error | Error code + details |

### Client → Server

| Type | When | Purpose |
|------|------|---------|
| `ping` | Every 30 seconds | Keep connection alive |

---

## Complete Meal Data Structure

### `meal_log.completed` Payload

```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "raw_input": "2 eggs, toast, coffee",
    "meal_type": "breakfast",
    "status": "completed",
    "total_calories": 350,
    "total_protein_g": 18.5,
    "total_carbs_g": 25.0,
    "total_fat_g": 15.2,
    "total_fiber_g": 2.5,
    "total_sugar_g": 3.0,
    "logged_at": "2024-01-15T08:30:00Z",
    "processing_started_at": "2024-01-15T08:30:01Z",
    "processing_completed_at": "2024-01-15T08:30:04Z",
    "created_at": "2024-01-15T08:30:00Z",
    "updated_at": "2024-01-15T08:30:04Z",
    "items": [
      {
        "id": "uuid",
        "meal_log_id": "uuid",
        "food_name": "Scrambled Eggs",
        "quantity": 2,
        "unit": "large",
        "calories": 180,
        "protein_g": 12.6,
        "carbs_g": 1.2,
        "fat_g": 12.0,
        "fiber_g": 0.0,
        "sugar_g": 0.5,
        "confidence_score": 0.95,
        "parsing_notes": "Assumed scrambled preparation",
        "order_index": 0,
        "created_at": "2024-01-15T08:30:04Z"
      }
      // ... more items
    ]
  },
  "timestamp": "2024-01-15T08:30:04Z"
}
```

### `meal_log.failed` Payload

```json
{
  "type": "meal_log.failed",
  "data": {
    "meal_log_id": "uuid",
    "user_id": "uuid",
    "raw_input": "xyz123",
    "meal_type": "lunch",
    "error": "Failed to parse meal input",
    "error_code": "PARSING_FAILED",
    "details": "Could not identify any valid food items in the input.",
    "suggestions": [
      "Use specific food names (e.g., 'chicken breast' instead of 'meat')",
      "Include quantities (e.g., '100g', '1 cup', '2 slices')",
      "Separate items with commas"
    ]
  },
  "timestamp": "2024-01-15T12:30:04Z"
}
```

---

## Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| `AUTH_FAILED` | Invalid/expired token | Refresh token and reconnect |
| `CONNECTION_LIMIT` | Too many connections | Close old connections first |
| `PARSING_FAILED` | AI couldn't parse input | Show suggestions to user |
| `RATE_LIMIT` | Too many requests | Slow down requests |
| `SERVER_ERROR` | Internal error | Retry with backoff |

---

## Common Patterns

### Pattern 1: Local-First with WebSocket Updates

```swift
// 1. Save meal locally (instant feedback)
let localID = try await saveMealLogUseCase.execute(...)

// 2. Show meal with "processing" status immediately
await loadDataForSelectedDate()

// 3. WebSocket notifies when processing completes
// 4. UI updates automatically (no polling needed)
```

### Pattern 2: Handling Connection Errors

```swift
do {
    try await webSocketService.connect(
        onCompleted: { ... },
        onFailed: { ... }
    )
} catch MealLogWebSocketServiceError.notAuthenticated {
    // User needs to log in
    navigationPath.append(.login)
} catch MealLogWebSocketServiceError.missingAccessToken {
    // Token expired - refresh it
    try await authManager.refreshAccessToken()
    try await webSocketService.reconnect(...)
} catch {
    // Other connection error
    print("Connection failed: \(error)")
}
```

### Pattern 3: Reconnection on Auth Token Refresh

```swift
// After refreshing auth token
func onTokenRefreshed() async {
    // Reconnect WebSocket with new token
    try? await webSocketService.reconnect(
        onCompleted: handleMealLogCompleted,
        onFailed: handleMealLogFailed
    )
}
```

---

## Best Practices

### ✅ Do This

1. **Connect once per app session**
   ```swift
   // In ViewModel init or App startup
   Task {
       await connectWebSocket()
   }
   ```

2. **Handle both success and failure**
   ```swift
   try await webSocketService.connect(
       onCompleted: { ... },  // ✅ Handle success
       onFailed: { ... }      // ✅ Handle failure
   )
   ```

3. **Show helpful error messages**
   ```swift
   if let suggestions = payload.suggestions {
       // Display suggestions to help user retry
       suggestionsList = suggestions
   }
   ```

4. **Disconnect on cleanup**
   ```swift
   deinit {
       webSocketService.disconnect()
   }
   ```

5. **Load from local storage first**
   ```swift
   // Always read from local DB, not WebSocket
   let meals = try await getMealLogsUseCase.execute(useLocalOnly: true)
   ```

### ❌ Don't Do This

1. **Don't poll for status**
   ```swift
   // ❌ Bad: Polling
   Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
       await checkMealStatus()
   }
   
   // ✅ Good: WebSocket
   // WebSocket notifies automatically
   ```

2. **Don't store WebSocket data directly**
   ```swift
   // ❌ Bad: Using WebSocket data directly
   meals = webSocketPayload.items
   
   // ✅ Good: Store in local DB, then read
   await repository.updateMealLog(...)
   meals = try await getMealLogsUseCase.execute(...)
   ```

3. **Don't ignore connection errors**
   ```swift
   // ❌ Bad: Silent failure
   try? await webSocketService.connect(...)
   
   // ✅ Good: Handle errors
   do {
       try await webSocketService.connect(...)
   } catch {
       errorMessage = error.localizedDescription
   }
   ```

4. **Don't forget to disconnect**
   ```swift
   // ❌ Bad: Memory leak
   // (no cleanup)
   
   // ✅ Good: Proper cleanup
   deinit {
       webSocketService.disconnect()
   }
   ```

---

## Architecture Flow

```
User submits meal
        ↓
SaveMealLogUseCase
        ↓
Local SwiftData storage (status: "processing")
        ↓
UI shows meal immediately with loading indicator
        ↓
POST /api/v1/meal-logs/natural (via Outbox Pattern)
        ↓
Backend AI processes meal (2-5 seconds)
        ↓
WebSocket: meal_log.completed (or meal_log.failed)
        ↓
ViewModel receives notification
        ↓
Repository updates local storage
        ↓
UI refreshes automatically
        ↓
User sees completed meal with parsed items
```

---

## Debugging

### Enable Verbose Logging

All WebSocket operations log to console with prefixes:
- `MealLogWebSocketClient:` - Low-level WebSocket events
- `MealLogWebSocketService:` - Service-level operations
- `NutritionViewModel:` - ViewModel-level handling

### Common Issues

**Problem:** WebSocket not connecting

```swift
// Check logs for:
MealLogWebSocketClient: 🔌 Attempting connection to wss://...
MealLogWebSocketClient: ✅ Connected successfully

// If not connecting, check:
// 1. WebSocketURL in config.plist
// 2. JWT token is valid
// 3. Network connectivity
// 4. Backend version (requires v0.31.0+)
```

**Problem:** Messages not received

```swift
// Check logs for:
MealLogWebSocketClient: 📨 Received message
MealLogWebSocketClient: 📩 Message type: meal_log.completed

// If not receiving, check:
// 1. Subscription was successful
// 2. Ping/pong is working (connection alive)
// 3. Meal log was created successfully
```

**Problem:** UI not updating

```swift
// Check logs for:
NutritionViewModel: 📩 Meal log completed
NutritionViewModel: Refreshing meal list to show completed meal

// If not updating, check:
// 1. Handler was called (@MainActor)
// 2. loadDataForSelectedDate() executed
// 3. Meal is in correct date range
```

---

## Testing

### Manual Testing

```swift
// In NutritionViewModel or debug view

// Test connection
Task {
    try await webSocketService.connect(
        onCompleted: { print("✅ Completed: \($0.id)") },
        onFailed: { print("❌ Failed: \($0.error)") }
    )
}

// Test reconnection
Task {
    try await viewModel.reconnectWebSocket()
}

// Test meal submission
Task {
    await viewModel.saveMealLog(
        rawInput: "chicken breast 150g, broccoli 100g",
        mealType: .lunch
    )
}
```

### Integration Testing

See `WEBSOCKET_MIGRATION_SUMMARY.md` for comprehensive test checklist.

---

## FAQ

**Q: Do I need to connect to WebSocket for meal logging to work?**  
A: No. Meal logging works offline. WebSocket provides real-time updates for AI processing status.

**Q: What happens if WebSocket disconnects?**  
A: Meal logging continues to work. WebSocket will attempt reconnection. Meals sync via Outbox Pattern.

**Q: Can I have multiple WebSocket connections?**  
A: Backend may limit connections per user. Typically one connection per device is sufficient.

**Q: How long does meal processing take?**  
A: Typically 2-5 seconds for AI parsing. WebSocket notifies when complete.

**Q: What if I submit a meal while offline?**  
A: Meal saves locally. Outbox Pattern syncs to backend when online. WebSocket updates when processing completes.

---

## Related Documentation

- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Migration Summary:** `WEBSOCKET_MIGRATION_SUMMARY.md`
- **Proposal:** `docs/proposals/MEAL_LOG_WEBSOCKET_ENDPOINT_SPEC.md`
- **Protocol:** `Domain/Ports/MealLogWebSocketProtocol.swift`
- **Client:** `Infrastructure/Network/MealLogWebSocketClient.swift`
- **Service:** `Infrastructure/Services/WebSocket/MealLogWebSocketService.swift`

---

**Last Updated:** 2025-01-27  
**API Version:** v0.31.0  
**iOS Minimum:** iOS 17.0