# WebSocket Endpoint Architecture Issue

**Date:** 2025-01-27  
**Issue:** WebSocket connection failing - incorrect endpoint  
**Status:** ⚠️ Architecture Mismatch Identified

---

## Problem

The iOS app is trying to connect to a WebSocket at `/ws`, but the backend uses a consultation-based WebSocket at `/api/v1/consultations/{id}/ws`.

**Current Config:**
```xml
<key>WebSocketURL</key>
<string>wss://fit-iq-backend.fly.dev/ws</string>
```

**Error:**
```
MealLogWebSocketClient: ⚠️ Ping failed: There was a bad response from the server.
MealLogWebSocketClient: 🔄 Attempting to reconnect...
MealLogWebSocketClient: ⚠️ Reconnection requires caller to call connect() again
```

---

## Root Cause

According to `docs/be-api-spec/swagger.yaml` (lines 9574-9620), the WebSocket architecture is:

1. **Endpoint:** `/api/v1/consultations/{id}/ws` (NOT `/ws`)
2. **Purpose:** Multi-purpose WebSocket for:
   - AI consultation streaming
   - Meal log processing notifications
3. **Authentication:** JWT token + consultation ID required

### Backend WebSocket Design

```
/api/v1/consultations/{consultation_id}/ws
```

**Message Types (Server → Client):**
- `connected` - Connection established
- `stream_chunk` - AI consultation response chunks
- `stream_complete` - AI consultation complete
- `pong` - Keep-alive response
- `meal_log.completed` - ✅ Meal log processed successfully
- `meal_log.failed` - ❌ Meal log processing failed
- `error` - Error notification

### iOS Current Implementation

```
wss://fit-iq-backend.fly.dev/ws
```

**Issues:**
- ❌ Wrong endpoint (no consultation ID)
- ❌ Expects dedicated meal log WebSocket
- ❌ Doesn't handle consultation creation

---

## Temporary Solutions

### Option 1: Disable WebSocket (Recommended for MVP)

Since WebSocket requires consultation context, temporarily disable it and rely on polling:

**File:** `Presentation/ViewModels/NutritionViewModel.swift`

```swift
init(
    saveMealLogUseCase: SaveMealLogUseCase,
    getMealLogsUseCase: GetMealLogsUseCase,
    webSocketService: MealLogWebSocketService,
    authManager: AuthManager
) {
    self.saveMealLogUseCase = saveMealLogUseCase
    self.getMealLogsUseCase = getMealLogsUseCase
    self.webSocketService = webSocketService
    self.authManager = authManager

    // TODO: Re-enable WebSocket when consultation-based architecture is implemented
    // Task {
    //     await connectWebSocket()
    // }
}
```

**Polling Alternative:**

After saving a meal log, poll for status updates:

```swift
func saveMealLog(...) async {
    let localID = try await saveMealLogUseCase.execute(...)
    
    // Start polling for status updates
    Task {
        await pollMealLogStatus(localID: localID)
    }
    
    await loadDataForSelectedDate()
}

private func pollMealLogStatus(localID: UUID) async {
    var attempts = 0
    let maxAttempts = 12 // 12 attempts = 60 seconds (5s intervals)
    
    while attempts < maxAttempts {
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Fetch updated meal log from backend
        if let mealLog = try? await getMealLogsUseCase.execute(
            status: nil,
            syncStatus: nil,
            mealType: nil,
            startDate: nil,
            endDate: nil,
            limit: nil,
            useLocalOnly: false // Fetch from remote
        ).first(where: { $0.id == localID }) {
            
            if mealLog.status == .completed || mealLog.status == .failed {
                // Processing complete, update UI
                await loadDataForSelectedDate()
                break
            }
        }
        
        attempts += 1
    }
}
```

### Option 2: Implement Consultation-Based WebSocket

For proper WebSocket integration, the app needs to:

1. **Create or Fetch a Consultation**

```swift
// New API endpoint needed or use existing consultation
func getOrCreateDefaultConsultation() async throws -> String {
    // POST /api/v1/consultations
    // {
    //   "coach_type": "nutritionist",
    //   "context": "meal_log_tracking"
    // }
    // Returns consultation_id
}
```

2. **Update WebSocket URL Construction**

```swift
// In MealLogWebSocketClient.swift
func connect(accessToken: String, consultationID: String) async throws {
    let webSocketURL = "\(baseURL)/api/v1/consultations/\(consultationID)/ws"
    
    guard var urlComponents = URLComponents(string: webSocketURL) else {
        throw WebSocketError.invalidURL
    }
    
    // Add access token as query parameter
    var queryItems = urlComponents.queryItems ?? []
    queryItems.append(URLQueryItem(name: "token", value: accessToken))
    urlComponents.queryItems = queryItems
    
    // ... rest of connection logic
}
```

3. **Handle Multiple Message Types**

```swift
private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
    switch message {
    case .string(let text):
        guard let data = text.data(using: .utf8) else { return }
        
        // Decode base message to get type
        struct BaseMessage: Codable {
            let type: String
        }
        
        guard let baseMsg = try? JSONDecoder().decode(BaseMessage.self, from: data) else {
            return
        }
        
        switch baseMsg.type {
        case "connected":
            handleConnectedMessage(data)
        case "meal_log.completed":
            handleMealLogCompletedMessage(data)
        case "meal_log.failed":
            handleMealLogFailedMessage(data)
        case "pong":
            // Keep-alive response
            print("WebSocket: Received pong")
        default:
            print("WebSocket: Unknown message type: \(baseMsg.type)")
        }
        
    case .data(let data):
        // Handle binary data if needed
        break
    @unknown default:
        break
    }
}
```

---

## Recommended Approach

### Phase 1: MVP (Current Sprint)

**Disable WebSocket, use polling:**

1. Comment out WebSocket initialization in `NutritionViewModel`
2. Implement polling after meal log submission
3. Document WebSocket as "Future Enhancement"

**Benefits:**
- ✅ Works immediately
- ✅ No backend changes needed
- ✅ Simple implementation
- ✅ Reliable (no WebSocket complexity)

**Drawbacks:**
- ❌ Not real-time (5-second delay)
- ❌ Extra API calls (polling)
- ❌ Battery usage (more network requests)

### Phase 2: Consultation-Based WebSocket (Future)

**Implement proper WebSocket architecture:**

1. Create consultation API client
2. Implement consultation creation/fetching
3. Update WebSocket to use consultation endpoint
4. Handle all message types (not just meal logs)
5. Implement reconnection logic with consultation context

**Benefits:**
- ✅ True real-time updates
- ✅ Efficient (one WebSocket connection)
- ✅ Supports AI consultation features
- ✅ Follows backend architecture

**Drawbacks:**
- ❌ More complex implementation
- ❌ Requires consultation management
- ❌ More testing needed

---

## Backend API Reference

### WebSocket Message Schemas

#### meal_log.completed
```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "raw_input": "120g chicken breast",
    "meal_type": "lunch",
    "status": "completed",
    "logged_at": "2024-01-15T12:30:00Z",
    "items": [
      {
        "id": "uuid",
        "meal_log_id": "uuid",
        "name": "Chicken Breast",
        "quantity": "120g",
        "unit": "grams",
        "calories": 198.0,
        "protein": 37.2,
        "carbohydrates": 0.0,
        "fat": 4.3,
        "fiber": 0.0,
        "sugar": 0.0,
        "confidence": 0.95,
        "notes": "Grilled, skinless"
      }
    ],
    "total_calories": 198.0,
    "total_protein": 37.2,
    "total_carbs": 0.0,
    "total_fat": 4.3,
    "total_fiber": 0.0,
    "total_sugar": 0.0,
    "processing_started_at": "2024-01-15T12:30:01Z",
    "processing_completed_at": "2024-01-15T12:30:04Z",
    "created_at": "2024-01-15T12:30:00Z",
    "updated_at": "2024-01-15T12:30:04Z"
  },
  "timestamp": "2024-01-15T12:30:04Z"
}
```

#### meal_log.failed
```json
{
  "type": "meal_log.failed",
  "data": {
    "meal_log_id": "uuid",
    "error": "Failed to parse meal input",
    "details": "Could not identify any food items in the input"
  },
  "timestamp": "2024-01-15T12:30:04Z"
}
```

---

## Files to Modify

### Option 1: Disable WebSocket (Quick Fix)

1. **`Presentation/ViewModels/NutritionViewModel.swift`**
   - Comment out `connectWebSocket()` call in `init`
   - Add polling method `pollMealLogStatus()`

2. **`config.plist`**
   - Add comment explaining WebSocket is disabled

### Option 2: Implement Consultation WebSocket (Proper Fix)

1. **`Domain/Ports/ConsultationRepositoryProtocol.swift`** (NEW)
   - Define consultation API interface

2. **`Infrastructure/Network/ConsultationAPIClient.swift`** (NEW)
   - Implement consultation creation/fetching

3. **`Infrastructure/Network/MealLogWebSocketClient.swift`**
   - Update `connect()` to accept `consultationID`
   - Update URL construction
   - Handle multiple message types

4. **`Infrastructure/Services/MealLogWebSocketService.swift`**
   - Add consultation management
   - Update connection flow

5. **`Presentation/ViewModels/NutritionViewModel.swift`**
   - Fetch/create consultation before connecting WebSocket
   - Pass consultation ID to WebSocket service

---

## Testing Plan

### Option 1: Polling (Immediate)

1. Save a meal log
2. ✅ Verify meal appears immediately (status: pending)
3. ✅ Wait 5 seconds
4. ✅ Verify meal updates to completed (with nutrition data)
5. ✅ Verify no WebSocket errors in console

### Option 2: Consultation WebSocket (Future)

1. Create/fetch consultation
2. ✅ Verify consultation ID received
3. Connect to WebSocket with consultation ID
4. ✅ Verify `connected` message received
5. Save a meal log
6. ✅ Verify meal appears immediately (status: pending)
7. ✅ Verify WebSocket notification received (< 5 seconds)
8. ✅ Verify meal updates to completed
9. ✅ Verify no polling API calls

---

## Recommendation

**For Current Sprint:** Use **Option 1 (Disable WebSocket + Polling)**

**Rationale:**
1. Works immediately without backend changes
2. Simple, reliable implementation
3. Provides good UX (5-second updates acceptable)
4. Can add proper WebSocket later without disrupting users
5. Aligns with MVP timeline

**For Next Sprint:** Plan **Option 2 (Consultation WebSocket)**

**Requirements:**
1. Backend consultation API documentation
2. Consultation lifecycle management design
3. Multi-purpose WebSocket message handling
4. Comprehensive testing

---

## Related Documentation

- [Backend API Spec](../be-api-spec/swagger.yaml) - Lines 9574-9620
- [Local-First Architecture](../architecture/LOCAL_FIRST_NUTRITION_PATTERN.md)
- [WebSocket Service Pattern](../architecture/WEBSOCKET_SERVICE_PATTERN.md)

---

**Status:** ⚠️ Blocked - Requires architecture decision  
**Priority:** Medium (Polling works as alternative)  
**Effort:** Option 1: 1-2 hours | Option 2: 1-2 days

---

**Decision Needed:** Choose between polling (quick) vs proper WebSocket (better long-term)