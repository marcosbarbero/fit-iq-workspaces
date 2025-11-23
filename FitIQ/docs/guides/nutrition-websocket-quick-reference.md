# Nutrition WebSocket Integration - Quick Reference

**Last Updated:** 2025-01-27

---

## 🚀 Quick Start

### For App Developers

The WebSocket integration is **automatic** - no manual setup required!

```swift
// ViewModel automatically connects on initialization
let viewModel = NutritionViewModel(
    saveMealLogUseCase: saveMealLogUseCase,
    getMealLogsUseCase: getMealLogsUseCase,
    webSocketClient: webSocketClient,
    mealLogRepository: repository,
    authTokenPersistence: tokenPersistence
)

// Submit a meal log
await viewModel.saveMealLog(
    rawInput: "scrambled eggs, bacon, toast",
    mealType: "breakfast",
    loggedAt: Date()
)

// WebSocket automatically receives real-time updates!
// UI refreshes automatically when processing completes
```

---

## 📦 Key Components

### 1. WebSocket Protocol (Domain/Ports)

**File:** `Domain/Ports/MealLogWebSocketProtocol.swift`

```swift
protocol MealLogWebSocketProtocol: AnyObject {
    func connect(accessToken: String) async throws
    func disconnect()
    func subscribe(onUpdate: @escaping (MealLogStatusUpdate) -> Void) -> UUID
    func unsubscribe(_ subscriptionId: UUID)
    func sendPing()
}
```

### 2. WebSocket Client (Infrastructure/Network)

**File:** `Infrastructure/Network/MealLogWebSocketClient.swift`

```swift
let client = MealLogWebSocketClient(webSocketURL: "wss://backend.com/ws")
try await client.connect(accessToken: token)
```

### 3. ViewModel (Presentation/ViewModels)

**File:** `Presentation/ViewModels/NutritionViewModel.swift`

Handles WebSocket lifecycle and UI updates automatically.

---

## 📨 WebSocket Message Format

### Status Update Payload

```json
{
  "type": "meal_log_status_update",
  "payload": {
    "meal_log_id": "uuid-string",
    "status": "completed",
    "meal_type": "breakfast",
    "logged_at": "2025-01-27T08:30:00Z",
    "items": [
      {
        "id": "item-uuid",
        "name": "Scrambled Eggs",
        "quantity": "2 large eggs",
        "calories": 180.0,
        "protein_g": 12.0,
        "carbs_g": 1.0,
        "fat_g": 12.0,
        "fiber_g": 0.0,
        "sugar_g": 0.5,
        "confidence": 0.95,
        "parsing_notes": "Standard large eggs",
        "order_index": 0
      }
    ],
    "total_protein_g": 25.0,
    "total_carbs_g": 30.0,
    "total_fat_g": 15.0,
    "total_fiber_g": 3.0,
    "total_sugar_g": 5.0,
    "processing_started_at": "2025-01-27T08:30:01Z",
    "processing_completed_at": "2025-01-27T08:30:05Z",
    "error_message": null
  }
}
```

### Status Values

| Status | Description |
|--------|-------------|
| `pending` | Meal log submitted, waiting for processing |
| `processing` | AI is analyzing the meal |
| `completed` | Processing done, items available |
| `failed` | Processing failed (check error_message) |

---

## 🔄 Processing Flow

```
User submits meal
      ↓
  status: pending
      ↓
  [API saves to DB]
      ↓
  status: processing ← WebSocket update
      ↓
  [AI processes meal]
      ↓
  status: completed ← WebSocket update (with items)
      ↓
  UI automatically refreshes
      ↓
  User sees parsed items
```

---

## 🛠️ Common Tasks

### Manually Reconnect WebSocket

```swift
await viewModel.reconnectWebSocket()
```

### Subscribe to Updates (Advanced)

```swift
let subscriptionId = webSocketClient.subscribe { update in
    print("Received update for meal: \(update.mealLogId)")
    print("Status: \(update.status)")
    
    if let items = update.items {
        print("Items: \(items.count)")
    }
}

// Later, unsubscribe
webSocketClient.unsubscribe(subscriptionId)
```

### Check Connection State

```swift
switch webSocketClient.connectionState {
case .connected:
    print("✅ Connected")
case .connecting:
    print("🔄 Connecting...")
case .disconnected:
    print("❌ Disconnected")
case .error(let error):
    print("⚠️ Error: \(error)")
}
```

---

## 🐛 Debugging

### Enable Verbose Logging

WebSocket client prints detailed logs:

```
MealLogWebSocketClient: Connecting to wss://...
MealLogWebSocketClient: ✅ Connected successfully
MealLogWebSocketClient: 📩 Received message: {"type":"meal_log_status_update",...}
MealLogWebSocketClient: ✅ Status update for meal log ABC123: completed
MealLogWebSocketClient: 📢 Notifying subscriber UUID-...
```

### Common Issues

#### Connection Fails

**Symptom:** `connectionState == .error`

**Solutions:**
1. Check WebSocket URL in `config.plist`
2. Verify JWT token is valid
3. Check network connectivity
4. Verify backend WebSocket endpoint is running

#### No Updates Received

**Symptom:** Meal status stays "pending"

**Solutions:**
1. Check backend logs for processing errors
2. Verify WebSocket subscription is active
3. Check if meal log has valid backend ID
4. Manually reconnect: `await viewModel.reconnectWebSocket()`

#### Updates Not Reflected in UI

**Symptom:** WebSocket receives updates but UI doesn't change

**Solutions:**
1. Check `handleWebSocketUpdate()` is being called
2. Verify `loadDataForSelectedDate()` is refreshing
3. Check if meal log is for the currently selected date
4. Verify SwiftData updates are propagating

---

## 🔐 Authentication

### WebSocket URL with Token

```
wss://backend.com/ws?token=<JWT_ACCESS_TOKEN>
```

**Token Sources:**
- Retrieved from `AuthTokenPersistencePortProtocol`
- Automatically refreshed by `AuthManager` when expired
- Passed as query parameter (not header)

### Token Refresh During Session

If token expires during WebSocket session:
1. WebSocket may disconnect
2. `NutritionViewModel` handles reconnection
3. New token fetched from `authTokenPersistence`
4. WebSocket reconnects automatically

---

## 📊 Performance

### Connection Management

- **Auto-connect:** On ViewModel init
- **Auto-disconnect:** On ViewModel deinit
- **Keep-alive:** Ping every 30 seconds
- **Reconnect:** Automatic on error (5 second delay)

### Message Processing

- **Thread-safe:** Subscriber callbacks on main thread
- **Async:** Non-blocking message parsing
- **Efficient:** Only notifies active subscribers

### Memory

- **Subscribers:** Stored in weak references
- **Cleanup:** Automatic on deinit
- **Leaks:** None (verified with Instruments)

---

## 🧪 Testing

### Unit Tests

```swift
func testWebSocketConnection() async throws {
    let client = MealLogWebSocketClient(webSocketURL: "wss://test.com/ws")
    try await client.connect(accessToken: "test-token")
    
    XCTAssertEqual(client.connectionState, .connected)
}

func testStatusUpdateParsing() throws {
    let json = """
    {
        "type": "meal_log_status_update",
        "payload": { ... }
    }
    """
    
    let data = json.data(using: .utf8)!
    let message = try JSONDecoder().decode(MealLogWebSocketMessage.self, from: data)
    
    XCTAssertEqual(message.type, "meal_log_status_update")
    XCTAssertNotNil(message.payload)
}
```

### Integration Tests

```swift
func testEndToEndMealLogging() async throws {
    // 1. Submit meal
    let localID = try await viewModel.saveMealLog(
        rawInput: "test meal",
        mealType: "breakfast"
    )
    
    // 2. Wait for WebSocket update
    let expectation = XCTestExpectation(description: "WebSocket update")
    
    let subscriptionId = webSocketClient.subscribe { update in
        if update.status == "completed" {
            expectation.fulfill()
        }
    }
    
    await fulfillment(of: [expectation], timeout: 10.0)
    
    // 3. Verify local data updated
    let mealLog = try await repository.fetchByID(localID, forUserID: userID)
    XCTAssertEqual(mealLog?.status, .completed)
    XCTAssertFalse(mealLog?.items.isEmpty ?? true)
}
```

---

## 📖 Configuration

### config.plist

```xml
<key>WebSocketURL</key>
<string>wss://fit-iq-backend.fly.dev/ws</string>
```

### Fallback Default

If not configured: `wss://fit-iq-backend.fly.dev/ws`

---

## 🎯 Best Practices

### Do's ✅

- Let ViewModel manage WebSocket lifecycle
- Use dependency injection for testing
- Handle all connection states
- Log errors for debugging
- Test with real backend
- Verify token refresh works

### Don'ts ❌

- Don't create multiple WebSocket connections
- Don't forget to unsubscribe
- Don't block main thread
- Don't hardcode WebSocket URL
- Don't ignore connection errors
- Don't skip error handling

---

## 🔗 Related Files

| Component | File Path |
|-----------|-----------|
| Protocol | `Domain/Ports/MealLogWebSocketProtocol.swift` |
| Client | `Infrastructure/Network/MealLogWebSocketClient.swift` |
| ViewModel | `Presentation/ViewModels/NutritionViewModel.swift` |
| Repository | `Infrastructure/Repositories/CompositeMealLogRepository.swift` |
| Schema | `Infrastructure/Persistence/Schema/SchemaV6.swift` |
| Dependencies | `Infrastructure/Configuration/AppDependencies.swift` |
| View | `Presentation/UI/Nutrition/NutritionView.swift` |

---

## 📞 Support

### Logs to Check

1. **WebSocket Client:** `MealLogWebSocketClient: ...`
2. **ViewModel:** `NutritionViewModel: ...`
3. **Repository:** `CompositeMealLogRepository: ...`
4. **Network:** `URLSessionWebSocketTask` errors

### Backend Endpoints

- **REST API:** `POST /api/v1/meal-logs/natural`
- **WebSocket:** `wss://backend.com/ws?token=JWT`
- **Docs:** https://fit-iq-backend.fly.dev/swagger/index.html

---

## ✅ Checklist for New Features

When adding WebSocket support to new features:

- [ ] Define WebSocket protocol in `Domain/Ports`
- [ ] Implement client in `Infrastructure/Network`
- [ ] Integrate with ViewModel
- [ ] Add to `AppDependencies`
- [ ] Update Views to pass dependencies
- [ ] Add unit tests
- [ ] Add integration tests
- [ ] Document in README
- [ ] Test with real backend

---

**Questions?** Check `docs/nutrition-websocket-integration-summary.md` for full implementation details.