# 🍎 iOS WebSocket Implementation Status

**Last Updated:** 2025-01-29  
**Phase:** Planning / Ready for Implementation  
**Priority:** High  
**Estimated Effort:** 2-3 days

---

## 📊 Current Status

### ✅ Completed (Backend)

- [x] Backend WebSocket notifications send **complete meal log data**
- [x] All nutrition totals included (calories, protein, carbs, fat, fiber, sugar)
- [x] Individual food items with detailed macros
- [x] Confidence scores and parsing notes
- [x] Backend tests passing (100% coverage)
- [x] Documentation complete (`MEAL_LOG_INTEGRATION.md`)

### ⏳ Pending (iOS)

- [ ] WebSocket manager implementation
- [ ] Meal log service with WebSocket support
- [ ] Updated domain models (fiber/sugar support)
- [ ] ViewModel with real-time updates
- [ ] SwiftUI view integration
- [ ] Unit tests
- [ ] Integration tests

---

## 🎯 What Changed in Backend

### Before (Minimal Metadata)
```json
{
  "type": "meal_log.completed",
  "data": {
    "meal_log_id": "abc-123",
    "status": "completed",
    "total_calories": 330,
    "items_count": 1
  }
}
```

### After (Complete Meal Data) ✨
```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "abc-123",
    "user_id": "user-456",
    "raw_input": "grilled chicken breast",
    "meal_type": "lunch",
    "status": "completed",
    "total_calories": 330,
    "total_protein_g": 62.0,
    "total_carbs_g": 0.0,
    "total_fat_g": 7.2,
    "total_fiber_g": 0.0,
    "total_sugar_g": 0.0,
    "logged_at": "2024-01-15T12:30:00Z",
    "processing_started_at": "2024-01-15T12:30:02Z",
    "processing_completed_at": "2024-01-15T12:30:05Z",
    "created_at": "2024-01-15T12:30:00Z",
    "updated_at": "2024-01-15T12:30:05Z",
    "items": [
      {
        "id": "item-789",
        "meal_log_id": "abc-123",
        "food_name": "Grilled Chicken Breast",
        "quantity": 200.0,
        "unit": "g",
        "calories": 330,
        "protein_g": 62.0,
        "carbs_g": 0.0,
        "fat_g": 7.2,
        "fiber_g": 0.0,
        "sugar_g": 0.0,
        "confidence_score": 0.95,
        "parsing_notes": null,
        "order_index": 0,
        "created_at": "2024-01-15T12:30:05Z"
      }
    ]
  },
  "timestamp": "2024-01-15T12:30:05Z"
}
```

**Key Benefits:**
- ✅ **No second API call needed!**
- ✅ Instant UI updates with complete data
- ✅ 50% reduction in API requests
- ✅ Better offline support
- ✅ Improved UX (faster feedback)

---

## 📋 Implementation Checklist

### Phase 1: Domain Models (1-2 hours)

#### Update `MealLogEntities.swift`

**Current State:**
```swift
public struct MealLogItem: Identifiable, Codable {
    public let id: UUID
    public let mealLogID: UUID
    public let name: String
    public let quantity: String
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let confidence: Double?
    public let createdAt: Date
    public let backendID: String?
}
```

**Required Changes:**
```swift
public struct MealLogItem: Identifiable, Codable {
    public let id: UUID
    public let mealLogID: UUID
    public let name: String
    public let quantity: Double          // Changed from String to Double
    public let unit: String              // ✨ NEW
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double?            // ✨ NEW (optional)
    public let sugar: Double?            // ✨ NEW (optional)
    public let confidence: Double?
    public let parsingNotes: String?     // ✨ NEW (optional)
    public let orderIndex: Int?          // ✨ NEW (for display order)
    public let createdAt: Date
    public let backendID: String?
}
```

**Tasks:**
- [ ] Add `unit: String` field
- [ ] Change `quantity` from `String` to `Double`
- [ ] Add `fiber: Double?` field
- [ ] Add `sugar: Double?` field
- [ ] Add `parsingNotes: String?` field
- [ ] Add `orderIndex: Int?` field
- [ ] Update initializer
- [ ] Update `macrosDescription` extension to include fiber/sugar

---

### Phase 2: WebSocket Infrastructure (4-6 hours)

#### Create `WebSocketManager.swift`

**Location:** `FitIQ/Infrastructure/Network/WebSocketManager.swift`

**Responsibilities:**
- Manage WebSocket connection lifecycle
- Handle reconnection with exponential backoff
- Send/receive messages
- Publish messages via Combine

**Key Features:**
- `@Published var isConnected: Bool`
- `@Published var connectionError: Error?`
- `messagePublisher: AnyPublisher<WebSocketMessage, Never>`
- Auto-reconnect on disconnection
- Keep-alive ping/pong

**Reference:** See `MEAL_LOG_INTEGRATION.md` lines 353-547

**Tasks:**
- [ ] Create `WebSocketManager.swift`
- [ ] Implement connection management
- [ ] Add reconnection logic
- [ ] Add message parsing
- [ ] Add ping/pong keep-alive
- [ ] Add error handling

---

#### Create WebSocket DTOs

**Location:** `FitIQ/Infrastructure/Network/DTOs/MealLogWebSocketDTOs.swift`

**Required Structures:**
```swift
struct WebSocketMessage: Codable {
    let type: MessageType
    let data: Data?
    let timestamp: Date
    
    enum MessageType: String, Codable {
        case connected
        case mealLogCompleted = "meal_log.completed"
        case mealLogFailed = "meal_log.failed"
        case error
        case pong
    }
}

struct MealLogCompletedData: Codable {
    let id: String
    let userId: String
    let rawInput: String?
    let mealType: String
    let status: String
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let totalFiberG: Double?
    let totalSugarG: Double?
    let loggedAt: Date
    let processingStartedAt: Date?
    let processingCompletedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let items: [MealLogItemDTO]
    
    func toDomain() -> MealLog
}

struct MealLogItemDTO: Codable {
    let id: String
    let mealLogId: String
    let foodName: String
    let quantity: Double
    let unit: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let confidenceScore: Double?
    let parsingNotes: String?
    let orderIndex: Int
    let createdAt: Date
    
    func toDomain(mealLogID: UUID) -> MealLogItem
}

struct MealLogFailedData: Codable {
    let id: String
    let userId: String
    let rawInput: String?
    let mealType: String
    let status: String
    let errorMessage: String?
    let loggedAt: Date
    let createdAt: Date
    let updatedAt: Date
}
```

**Tasks:**
- [ ] Create `MealLogWebSocketDTOs.swift`
- [ ] Define all DTO structures
- [ ] Add CodingKeys for snake_case mapping
- [ ] Implement `toDomain()` methods
- [ ] Add ISO8601 date decoding strategy

---

### Phase 3: Meal Log Service Updates (2-3 hours)

#### Update `NutritionAPIClient.swift`

**Current State:**
- Only has HTTP methods
- No WebSocket integration

**Required Changes:**
```swift
final class NutritionAPIClient: MealLogRemoteAPIProtocol {
    // ... existing properties ...
    
    private let webSocketManager: WebSocketManager
    
    // ✨ NEW
    var webSocketMessages: AnyPublisher<WebSocketMessage, Never> {
        webSocketManager.messagePublisher
    }
    
    // ✨ NEW
    func connectWebSocket(consultationId: String) async throws {
        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        
        guard let token = try? authTokenPersistence.fetchAccessToken() else {
            throw NutritionAPIError.unauthorized
        }
        
        try await webSocketManager.connect(
            consultationId: consultationId,
            authToken: token,
            apiKey: apiKey
        )
    }
    
    // ✨ NEW
    func disconnectWebSocket() {
        webSocketManager.disconnect()
    }
}
```

**Tasks:**
- [ ] Add `WebSocketManager` dependency
- [ ] Add `webSocketMessages` publisher
- [ ] Add `connectWebSocket()` method
- [ ] Add `disconnectWebSocket()` method
- [ ] Update initializer

---

### Phase 4: ViewModel Implementation (3-4 hours)

#### Create `MealLogViewModel.swift`

**Location:** `FitIQ/Presentation/ViewModels/MealLogViewModel.swift`

**Key Features:**
```swift
@Observable
final class MealLogViewModel {
    // MARK: - State
    var mealInput: String = ""
    var selectedMealType: MealType = .lunch
    var isSubmitting: Bool = false
    var currentMealLog: MealLog?
    var processingStatus: ProcessingStatus = .idle
    var errorMessage: String?
    var showSuccessToast: Bool = false
    
    enum ProcessingStatus {
        case idle
        case submitting
        case processing
        case completed
        case failed
    }
    
    // MARK: - Dependencies
    private let apiClient: NutritionAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - WebSocket Handling
    private func setupWebSocketListener() {
        apiClient.webSocketMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case .mealLogCompleted:
            handleMealLogCompleted(message)
        case .mealLogFailed:
            handleMealLogFailed(message)
        default:
            break
        }
    }
    
    private func handleMealLogCompleted(_ message: WebSocketMessage) {
        // Decode complete meal data
        // Update currentMealLog with ALL data from WebSocket
        // NO NEED for second API call!
        processingStatus = .completed
        showSuccessToast = true
    }
    
    private func handleMealLogFailed(_ message: WebSocketMessage) {
        // Decode failure data
        processingStatus = .failed
        errorMessage = failedData.errorMessage ?? "Processing failed"
    }
    
    // MARK: - Actions
    func submitMealLog() async {
        // 1. Submit meal log via API
        // 2. Start processing status
        // 3. WebSocket will notify when complete
    }
}
```

**Reference:** See `MEAL_LOG_INTEGRATION.md` lines 729-924

**Tasks:**
- [ ] Create `MealLogViewModel.swift`
- [ ] Add state properties
- [ ] Add WebSocket listener setup
- [ ] Implement `handleMealLogCompleted()` with complete data decoding
- [ ] Implement `handleMealLogFailed()`
- [ ] Implement `submitMealLog()`
- [ ] Add `reset()` method

---

### Phase 5: SwiftUI View (2-3 hours)

#### Create `MealLogView.swift`

**Location:** `FitIQ/Presentation/Views/Nutrition/MealLogView.swift`

**Key Features:**
- Real-time status updates
- Nutrition card with complete macros
- Individual items list
- Success/failure states
- Loading indicators

**Reference:** See `MEAL_LOG_INTEGRATION.md` lines 937-1274

**Tasks:**
- [ ] Create `MealLogView.swift`
- [ ] Add input section (text field + meal type picker)
- [ ] Add status card (shows processing/completed/failed)
- [ ] Add meal log card with nutrition totals
- [ ] Add items list with individual macros
- [ ] Add success toast notification
- [ ] Add error handling UI

---

### Phase 6: Dependency Injection (1 hour)

#### Update `AppDependencies.swift`

**Current State:**
```swift
lazy var nutritionAPIClient: NutritionAPIClient = NutritionAPIClient(
    baseURL: Config.baseURL,
    apiKey: Config.apiKey,
    authTokenPersistence: keychainAuthTokenAdapter,
    authManager: authManager
)
```

**Required Changes:**
```swift
lazy var webSocketManager: WebSocketManager = WebSocketManager(
    baseURL: Config.baseURL
)

lazy var nutritionAPIClient: NutritionAPIClient = NutritionAPIClient(
    webSocketManager: webSocketManager,  // ✨ NEW
    baseURL: Config.baseURL,
    apiKey: Config.apiKey,
    authTokenPersistence: keychainAuthTokenAdapter,
    authManager: authManager
)

lazy var mealLogViewModel: MealLogViewModel = MealLogViewModel(
    apiClient: nutritionAPIClient
)
```

**Tasks:**
- [ ] Create `webSocketManager` lazy property
- [ ] Inject `webSocketManager` into `nutritionAPIClient`
- [ ] Create `mealLogViewModel` lazy property
- [ ] Update view injection

---

### Phase 7: Testing (4-6 hours)

#### Unit Tests

**File:** `FitIQTests/ViewModels/MealLogViewModelTests.swift`

**Test Cases:**
- [ ] `testSubmitMealLog_Success()`
- [ ] `testSubmitMealLog_Failure()`
- [ ] `testWebSocketNotification_Completed()`
- [ ] `testWebSocketNotification_Failed()`
- [ ] `testWebSocketReconnection()`
- [ ] `testDataMapping_CompletePayload()`

**Reference:** See `MEAL_LOG_INTEGRATION.md` lines 1392-1471

#### Integration Tests

**File:** `FitIQTests/Integration/MealLogIntegrationTests.swift`

**Test Cases:**
- [ ] `testE2EFlow_SubmitAndReceiveWebSocket()`
- [ ] `testOfflineScenario_FallbackToPolling()`
- [ ] `testConcurrentMealLogs()`

**Reference:** See `MEAL_LOG_INTEGRATION.md` lines 1482-1517

---

## 📐 Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                  iOS App Layer                      │
│                                                     │
│  ┌──────────────┐                                  │
│  │ MealLogView  │ ← SwiftUI View                   │
│  │  (SwiftUI)   │                                   │
│  └──────┬───────┘                                   │
│         │ @Observable                               │
│  ┌──────▼────────────┐                              │
│  │ MealLogViewModel  │ ← Presentation Layer         │
│  │  (@Observable)    │                              │
│  └──────┬───────┬────┘                              │
│         │       │                                    │
│         │       └─────────────┐                      │
│         │                     │                      │
│  ┌──────▼─────────┐    ┌──────▼────────┐            │
│  │ NutritionAPI   │    │  WebSocket    │            │
│  │ Client         │◄───┤  Manager      │            │
│  └──────┬─────────┘    └──────┬────────┘            │
│         │ Infrastructure       │                     │
└─────────┼──────────────────────┼─────────────────────┘
          │                      │
          │ HTTPS                │ WSS
          │ (POST /meal-logs)    │ (WS /consultations/*/ws)
          │                      │
    ┌─────▼──────────────────────▼──────┐
    │       FitIQ Backend API            │
    │                                    │
    │  - REST endpoints                  │
    │  - WebSocket notifications         │
    │  - AI meal processing              │
    └────────────────────────────────────┘
```

---

## 🎯 Success Criteria

### Functional Requirements

- [x] Backend sends complete meal log data via WebSocket ✅
- [ ] iOS receives and decodes WebSocket messages
- [ ] iOS updates UI in real-time without second API call
- [ ] Fiber and sugar values displayed when available
- [ ] Items displayed in correct order (`order_index`)
- [ ] Confidence scores shown for AI-parsed items
- [ ] Error handling for processing failures
- [ ] Automatic reconnection on disconnection

### Non-Functional Requirements

- [ ] Test coverage ≥ 80%
- [ ] Build with zero warnings
- [ ] UI responsive (60 FPS)
- [ ] Memory efficient (no leaks)
- [ ] Network efficient (no redundant calls)

---

## 📊 Estimated Performance Impact

### Before Implementation
- **API Calls per Meal Log:** 2 (POST + GET)
- **Network Round-trips:** 2
- **Latency to Display:** ~500-800ms
- **Daily Requests (10k users, 3 meals):** 60,000

### After Implementation
- **API Calls per Meal Log:** 1 (POST only)
- **Network Round-trips:** 1
- **Latency to Display:** ~200-300ms
- **Daily Requests (10k users, 3 meals):** 30,000

**Savings:** 50% reduction in API requests! 🎉

---

## 🚀 Implementation Timeline

### Day 1: Foundation
- [ ] Morning: Update domain models (Phase 1)
- [ ] Afternoon: Create WebSocket manager (Phase 2, Part 1)
- [ ] Evening: Create WebSocket DTOs (Phase 2, Part 2)

### Day 2: Integration
- [ ] Morning: Update NutritionAPIClient (Phase 3)
- [ ] Afternoon: Implement ViewModel (Phase 4)
- [ ] Evening: Start SwiftUI view (Phase 5)

### Day 3: Polish & Testing
- [ ] Morning: Finish SwiftUI view (Phase 5)
- [ ] Afternoon: Dependency injection (Phase 6) + Unit tests (Phase 7)
- [ ] Evening: Integration tests + Bug fixes

---

## 📚 Reference Documentation

### Internal Docs (iOS)
- **Integration Guide:** `docs/nutrition/MEAL_LOG_INTEGRATION.md` (COMPLETE)
- **Current Status:** This file
- **Domain Models:** `FitIQ/Domain/Entities/Nutrition/MealLogEntities.swift`
- **API Client:** `FitIQ/Infrastructure/Network/NutritionAPIClient.swift`

### Backend Docs
- **Enhancement Report:** `docs/nutrition/WEBSOCKET_NOTIFICATION_ENHANCEMENT.md`
- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **WebSocket Schema:** Lines 2904-3208 in `swagger.yaml`

### External
- **Apple URLSessionWebSocketTask:** https://developer.apple.com/documentation/foundation/urlsessionwebsockettask
- **Combine Framework:** https://developer.apple.com/documentation/combine
- **Swift Concurrency:** https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/

---

## ⚠️ Known Risks & Mitigations

### Risk 1: WebSocket Connection Stability
**Mitigation:** Implement auto-reconnect with exponential backoff

### Risk 2: Large Payload Sizes (>10 items)
**Mitigation:** Monitor payload sizes, consider pagination if needed

### Risk 3: Offline Scenarios
**Mitigation:** Gracefully degrade to polling if WebSocket unavailable

### Risk 4: Token Expiration During WebSocket
**Mitigation:** Refresh token and reconnect automatically

---

## ✅ Definition of Done

- [ ] All code files created and integrated
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Build with zero warnings
- [ ] Documentation updated
- [ ] Code reviewed and approved
- [ ] Merged to main branch
- [ ] Deployed to TestFlight (beta)

---

## 🎓 Next Steps

1. **Review this document** with team
2. **Create GitHub issue** with checklist
3. **Assign developer** to implementation
4. **Start with Phase 1** (domain models)
5. **Iterate through phases** with daily check-ins
6. **Test thoroughly** before merge
7. **Deploy to beta** for user testing

---

**Status:** 📋 **READY FOR IMPLEMENTATION**

**Created By:** AI Engineering Assistant  
**Reviewed By:** _Pending_  
**Approved By:** _Pending_

**Version:** 1.0.0  
**Last Updated:** 2025-01-29