# Nutrition Logging - WebSocket Status

**Date:** 2025-01-27  
**Status:** ❌ **NOT IMPLEMENTED**  
**Priority:** MEDIUM (Optional Enhancement)

---

## 🔴 Current Status

The WebSocket handler for meal log status updates is **NOT implemented**. This was intentionally deferred as an optional enhancement during the initial implementation.

---

## ✅ What Works Without WebSocket

The nutrition logging feature is **fully functional** without WebSocket integration:

### Current Workflow (Polling-Based)

```
1. User saves meal log
   ↓
2. Saved locally with status: pending
   ↓
3. Outbox Pattern syncs to backend
   ↓
4. Backend returns initial response (status: processing)
   ↓
5. Backend processes asynchronously (AI parsing)
   ↓
6. User manually refreshes to see updated status
   ↓
7. App fetches updated meal log via GET /api/v1/meal-logs/{id}
   ↓
8. UI shows completed meal with nutrition data
```

**This works perfectly fine, but requires manual refresh.**

---

## 🎯 What WebSocket Would Add

### Enhanced Workflow (Real-Time Updates)

```
1. User saves meal log
   ↓
2. Saved locally with status: pending
   ↓
3. Outbox Pattern syncs to backend
   ↓
4. Backend returns initial response (status: processing)
   ↓
5. App subscribes to WebSocket for this meal log
   ↓
6. Backend processes asynchronously (AI parsing)
   ↓
7. WebSocket sends notification: meal_log.completed
   ↓
8. App automatically updates local meal log
   ↓
9. UI updates in real-time (no manual refresh needed)
```

**Benefits:**
- ✨ Real-time status updates (processing → completed)
- ✨ Immediate nutrition data display
- ✨ Better user experience (no manual refresh)
- ✨ Push notifications when processing completes
- ✨ Live updates for all connected devices

---

## 📋 Implementation Plan

### Phase 1: WebSocket Infrastructure (30 min)

**File:** `FitIQ/Infrastructure/Services/WebSocketManager.swift`

Create a generic WebSocket manager for the app:

```swift
import Foundation

protocol WebSocketManagerProtocol {
    func connect(url: URL)
    func disconnect()
    func send(message: String)
    func subscribe(to event: String, handler: @escaping (String) -> Void)
}

final class WebSocketManager: NSObject, WebSocketManagerProtocol {
    private var webSocketTask: URLSessionWebSocketTask?
    private var eventHandlers: [String: [(String) -> Void]] = [:]
    
    func connect(url: URL) {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessages()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    func send(message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    func subscribe(to event: String, handler: @escaping (String) -> Void) {
        eventHandlers[event, default: []].append(handler)
    }
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessages() // Continue listening
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            }
        }
    }
    
    private func handleMessage(_ message: String) {
        // Parse JSON message
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            return
        }
        
        // Notify subscribers
        eventHandlers[eventType]?.forEach { handler in
            handler(message)
        }
    }
}
```

### Phase 2: Meal Log WebSocket Handler (30 min)

**File:** `FitIQ/Infrastructure/Services/MealLogWebSocketHandler.swift`

```swift
import Foundation

protocol MealLogWebSocketHandlerProtocol {
    func startListening()
    func stopListening()
}

final class MealLogWebSocketHandler: MealLogWebSocketHandlerProtocol {
    
    // MARK: - Dependencies
    private let webSocketManager: WebSocketManagerProtocol
    private let mealLogRepository: MealLogLocalStorageProtocol
    private let authManager: AuthManager
    private let baseURL: String
    
    // MARK: - Initialization
    init(
        webSocketManager: WebSocketManagerProtocol,
        mealLogRepository: MealLogLocalStorageProtocol,
        authManager: AuthManager,
        baseURL: String
    ) {
        self.webSocketManager = webSocketManager
        self.mealLogRepository = mealLogRepository
        self.authManager = authManager
        self.baseURL = baseURL
    }
    
    // MARK: - Public Methods
    func startListening() {
        guard let userID = authManager.currentUserProfileID else {
            print("MealLogWebSocketHandler: No authenticated user, cannot start listening")
            return
        }
        
        // Connect to WebSocket
        let wsURL = baseURL.replacingOccurrences(of: "https://", with: "wss://")
        let url = URL(string: "\(wsURL)/ws/meal-logs")!
        webSocketManager.connect(url: url)
        
        // Subscribe to meal log events
        webSocketManager.subscribe(to: "meal_log.completed") { [weak self] message in
            self?.handleMealLogCompleted(message: message)
        }
        
        webSocketManager.subscribe(to: "meal_log.failed") { [weak self] message in
            self?.handleMealLogFailed(message: message)
        }
        
        print("MealLogWebSocketHandler: Started listening for meal log events")
    }
    
    func stopListening() {
        webSocketManager.disconnect()
        print("MealLogWebSocketHandler: Stopped listening")
    }
    
    // MARK: - Private Methods
    private func handleMealLogCompleted(message: String) {
        Task {
            do {
                // Parse WebSocket message
                guard let data = message.data(using: .utf8),
                      let json = try? JSONDecoder().decode(MealLogCompletedEvent.self, from: data) else {
                    print("MealLogWebSocketHandler: Failed to parse completed event")
                    return
                }
                
                print("MealLogWebSocketHandler: Meal log completed: \(json.mealLogID)")
                
                // Update local meal log
                guard let userID = authManager.currentUserProfileID?.uuidString else { return }
                
                // Convert WebSocket items to domain items
                let items = json.items.map { wsItem in
                    MealLogItem(
                        id: UUID(),
                        mealLogID: json.mealLogID,
                        name: wsItem.foodName,
                        quantity: "\(wsItem.quantity) \(wsItem.unit)",
                        calories: wsItem.calories,
                        protein: wsItem.proteinG,
                        carbs: wsItem.carbsG,
                        fat: wsItem.fatG,
                        confidence: wsItem.confidence,
                        createdAt: Date()
                    )
                }
                
                try await mealLogRepository.updateStatus(
                    forLocalID: json.mealLogID,
                    status: .completed,
                    items: items,
                    errorMessage: nil,
                    forUserID: userID
                )
                
                print("MealLogWebSocketHandler: Successfully updated meal log")
                
            } catch {
                print("MealLogWebSocketHandler: Error handling completed event: \(error)")
            }
        }
    }
    
    private func handleMealLogFailed(message: String) {
        Task {
            do {
                // Parse WebSocket message
                guard let data = message.data(using: .utf8),
                      let json = try? JSONDecoder().decode(MealLogFailedEvent.self, from: data) else {
                    print("MealLogWebSocketHandler: Failed to parse failed event")
                    return
                }
                
                print("MealLogWebSocketHandler: Meal log failed: \(json.mealLogID)")
                
                // Update local meal log
                guard let userID = authManager.currentUserProfileID?.uuidString else { return }
                
                try await mealLogRepository.updateStatus(
                    forLocalID: json.mealLogID,
                    status: .failed,
                    items: nil,
                    errorMessage: json.errorMessage,
                    forUserID: userID
                )
                
                print("MealLogWebSocketHandler: Marked meal log as failed")
                
            } catch {
                print("MealLogWebSocketHandler: Error handling failed event: \(error)")
            }
        }
    }
}

// MARK: - WebSocket Event DTOs

struct MealLogCompletedEvent: Codable {
    let type: String
    let mealLogID: UUID
    let status: String
    let items: [WebSocketMealLogItem]
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    
    enum CodingKeys: String, CodingKey {
        case type
        case mealLogID = "meal_log_id"
        case status
        case items
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
    }
}

struct WebSocketMealLogItem: Codable {
    let foodName: String
    let quantity: Double
    let unit: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case quantity
        case unit
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case confidence
    }
}

struct MealLogFailedEvent: Codable {
    let type: String
    let mealLogID: UUID
    let status: String
    let errorMessage: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case mealLogID = "meal_log_id"
        case status
        case errorMessage = "error_message"
    }
}
```

### Phase 3: Protocol Definition (10 min)

**File:** `FitIQ/Domain/Ports/MealLogWebSocketHandlerProtocol.swift`

```swift
import Foundation

/// Port for WebSocket meal log status updates
protocol MealLogWebSocketHandlerProtocol {
    /// Start listening for meal log WebSocket events
    func startListening()
    
    /// Stop listening for meal log WebSocket events
    func stopListening()
}
```

### Phase 4: AppDependencies Registration (10 min)

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`

Add to the build() method:

```swift
// MARK: - WebSocket Infrastructure
let webSocketManager = WebSocketManager()

// MARK: - Meal Log WebSocket Handler
let mealLogWebSocketHandler = MealLogWebSocketHandler(
    webSocketManager: webSocketManager,
    mealLogRepository: mealLogLocalRepository,
    authManager: authManager,
    baseURL: baseURL
)

// Start listening when user is authenticated
Task { @MainActor in
    for await userID in authManager.$currentUserProfileID.values {
        if userID != nil {
            mealLogWebSocketHandler.startListening()
        } else {
            mealLogWebSocketHandler.stopListening()
        }
    }
}
```

### Phase 5: UI Updates (Optional) (20 min)

Add real-time UI updates when WebSocket events arrive:

```swift
// In NutritionViewModel
func subscribeToRealTimeUpdates() {
    // Subscribe to local data changes
    // When meal log is updated, refresh the list
    NotificationCenter.default.addObserver(
        forName: .mealLogUpdated,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.loadDataForSelectedDate()
        }
    }
}
```

---

## 📊 Estimated Implementation Time

| Phase | Description | Time |
|-------|-------------|------|
| 1 | WebSocket Infrastructure | 30 min |
| 2 | Meal Log Handler | 30 min |
| 3 | Protocol Definition | 10 min |
| 4 | AppDependencies | 10 min |
| 5 | UI Updates (Optional) | 20 min |
| **Total** | **Complete WebSocket Integration** | **~2 hours** |

---

## 🧪 Testing Checklist

After implementation:

- [ ] WebSocket connects on app launch
- [ ] WebSocket reconnects after network loss
- [ ] meal_log.completed events update local storage
- [ ] meal_log.failed events update local storage
- [ ] UI refreshes automatically on WebSocket events
- [ ] WebSocket disconnects on logout
- [ ] Multiple devices receive updates simultaneously

---

## ⚠️ Important Considerations

### 1. Backend WebSocket Endpoint
Verify the backend has implemented:
- `ws://backend/ws/meal-logs` or similar endpoint
- Authentication via JWT token
- Events: `meal_log.completed`, `meal_log.failed`

### 2. Reconnection Strategy
- Handle network interruptions
- Auto-reconnect with exponential backoff
- Resume subscription after reconnection

### 3. Authentication
- Pass JWT token in WebSocket connection
- Handle token refresh
- Reconnect with new token

### 4. Performance
- Don't block UI thread with WebSocket operations
- Use background queue for message parsing
- Batch UI updates if multiple events arrive

---

## 🎯 Recommended Approach

### Option A: Implement Now (If Real-Time is Critical)
- Follow the implementation plan above
- Estimated effort: 2 hours
- Benefit: Better UX with instant updates

### Option B: Defer (Current Approach) ✅ RECOMMENDED
- Current polling-based approach works fine
- Users can manually refresh to see updates
- Implement WebSocket later as enhancement
- Focus on testing core functionality first

**Current Status: Option B (Deferred) ✅**

---

## 📚 Related Documentation

- **Backend API Spec:** `docs/be-api-spec/swagger.yaml`
- **WebSocket Format:** See backend documentation
- **Implementation Progress:** `NUTRITION_LOGGING_HANDOFF.md`

---

## ✅ Conclusion

**WebSocket is NOT implemented, but it's NOT required for the feature to work.**

The nutrition logging feature is fully functional without WebSocket. Users can:
- ✅ Save meal logs (works perfectly)
- ✅ View meal logs (works perfectly)
- ✅ See nutrition data (after manual refresh)

WebSocket would add:
- ✨ Real-time status updates (nice to have)
- ✨ Better UX (no manual refresh)
- ✨ Push notifications (bonus feature)

**Recommendation:** Ship the feature without WebSocket first, then add it as an enhancement based on user feedback.

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27  
**Status:** Not Implemented (Intentional)