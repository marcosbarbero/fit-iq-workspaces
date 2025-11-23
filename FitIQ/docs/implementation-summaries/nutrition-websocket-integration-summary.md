# Nutrition WebSocket Integration - Implementation Summary

**Date:** 2025-01-27  
**Status:** ✅ Complete  
**Version:** 1.0.0

---

## 🎯 Overview

Implemented end-to-end WebSocket integration for real-time meal log processing updates in the FitIQ iOS app. This allows users to receive instant status updates as the backend AI processes their meal logs, without requiring additional API calls.

---

## 📋 What Was Implemented

### 1. Schema Updates (SchemaV6)

**File:** `FitIQ/Infrastructure/Persistence/Schema/SchemaV6.swift`

- **Renamed:** `SDMealLog` → `SDMeal` (better naming convention)
- **Added new fields to `SDMeal`:**
  - `totalProteinG: Double?`
  - `totalCarbsG: Double?`
  - `totalFatG: Double?`
  - `totalFiberG: Double?`
  - `totalSugarG: Double?`
  - `processingStartedAt: Date?`
  - `processingCompletedAt: Date?`

- **Added new fields to `SDMealLogItem`:**
  - `fiberG: Double?`
  - `sugarG: Double?`
  - `parsingNotes: String?`
  - `orderIndex: Int`

**Why:** These fields match the WebSocket payload structure from the backend, enabling complete meal data to be received in real-time without additional API calls.

### 2. Domain Models Updated

**File:** `FitIQ/Domain/Entities/Nutrition/MealLogEntities.swift`

- Updated `MealLogItem` to use single `quantity: String` field (instead of separate quantity/unit)
- Added fiber, sugar, parsingNotes, and orderIndex fields
- Domain models now align perfectly with SwiftData schema and WebSocket payloads

### 3. WebSocket Protocol (Port)

**File:** `FitIQ/Domain/Ports/MealLogWebSocketProtocol.swift`

Created protocol defining WebSocket operations following Hexagonal Architecture:

```swift
public protocol MealLogWebSocketProtocol: AnyObject {
    var connectionState: MealLogWebSocketState { get }
    func connect(accessToken: String) async throws
    func disconnect()
    func subscribe(onUpdate: @escaping (MealLogStatusUpdate) -> Void) -> UUID
    func unsubscribe(_ subscriptionId: UUID)
    func sendPing()
}
```

**Key Types:**
- `MealLogStatusUpdate` - WebSocket payload structure
- `MealLogItemUpdate` - Individual food item structure
- `MealLogWebSocketState` - Connection state enum
- `MealLogWebSocketMessage` - Message envelope

### 4. WebSocket Client (Adapter)

**File:** `FitIQ/Infrastructure/Network/MealLogWebSocketClient.swift`

Implemented WebSocket client using `URLSessionWebSocketTask`:

**Features:**
- ✅ Automatic connection management
- ✅ JWT authentication via query parameter
- ✅ Subscriber pattern for multiple listeners
- ✅ Automatic ping/pong for keep-alive
- ✅ Message parsing and validation
- ✅ Error handling and reconnection logic
- ✅ Thread-safe subscriber management

**Connection Flow:**
```
1. Create WebSocket URL with token: wss://backend.com/ws?token=JWT
2. Establish connection
3. Start receiving messages
4. Start ping timer (every 30 seconds)
5. Notify subscribers on status updates
```

### 5. ViewModel Integration

**File:** `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`

Added WebSocket support to `NutritionViewModel`:

**New Dependencies:**
- `webSocketClient: MealLogWebSocketProtocol`
- `mealLogRepository: MealLogRepositoryProtocol`
- `authTokenPersistence: AuthTokenPersistencePortProtocol`

**New Methods:**
- `connectWebSocket()` - Establishes WebSocket connection on init
- `handleWebSocketUpdate()` - Processes incoming status updates
- `reconnectWebSocket()` - Manual reconnection for testing

**Lifecycle:**
```
Init → Connect WebSocket → Subscribe to updates → Handle updates → Refresh UI
                                                                     ↓
Deinit → Unsubscribe → Disconnect                                   ↓
                                                 Update local data ← ┘
```

### 6. Dependency Injection

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`

Added WebSocket client to dependency container:

```swift
// Property
let mealLogWebSocketClient: MealLogWebSocketProtocol

// Initialization in build()
let webSocketURL = configuration["WebSocketURL"] as? String 
    ?? "wss://fit-iq-backend.fly.dev/ws"
let mealLogWebSocketClient = MealLogWebSocketClient(webSocketURL: webSocketURL)
```

**File:** `FitIQ/Infrastructure/Configuration/ViewDependencies.swift`

Updated `NutritionView` initialization to pass WebSocket dependencies:

```swift
let nutritionView = NutritionView(
    saveMealLogUseCase: ...,
    getMealLogsUseCase: ...,
    webSocketClient: viewModelDependencies.appDependencies.mealLogWebSocketClient,
    mealLogRepository: viewModelDependencies.appDependencies.mealLogRepository,
    authTokenPersistence: viewModelDependencies.appDependencies.authTokenPersistence,
    ...
)
```

### 7. Persistence Helper Updates

**File:** `FitIQ/Infrastructure/Persistence/Schema/PersistenceHelper.swift`

- Updated typealias: `SDMealLog` → `SDMeal`
- Updated `toDomain()` conversion methods to include new fields
- Added computed `totalCalories` from items

---

## 🔄 Complete Data Flow

### Meal Logging Flow with WebSocket

```
1. User enters meal: "2 eggs, toast with butter, coffee"
   ↓
2. ViewModel calls SaveMealLogUseCase
   ↓
3. Use Case creates MealLog (status: pending, syncStatus: pending)
   ↓
4. Repository saves to SwiftData
   ↓
5. Repository creates Outbox event (triggers sync)
   ↓
6. OutboxProcessorService syncs to POST /api/v1/meal-logs/natural
   ↓
7. Backend responds with meal log ID (status: pending)
   ↓
8. Repository updates local entry with backend ID
   ↓
9. Backend AI processes meal asynchronously
   ↓
10. WebSocket sends status update: { status: "processing" }
    ↓
11. ViewModel.handleWebSocketUpdate() receives update
    ↓
12. Repository updates local meal log status
    ↓
13. UI automatically refreshes (via loadDataForSelectedDate)
    ↓
14. WebSocket sends completion: { 
        status: "completed", 
        items: [...],
        totalProteinG: 25.0,
        totalCarbsG: 30.0,
        ...
    }
    ↓
15. ViewModel updates local data with parsed items
    ↓
16. UI shows completed meal with nutritional breakdown
```

---

## 🏗️ Architecture Compliance

### ✅ Hexagonal Architecture (Ports & Adapters)

```
Presentation Layer (NutritionViewModel, NutritionView)
    ↓ depends on ↓
Domain Layer (MealLogWebSocketProtocol, MealLog, MealLogItem)
    ↑ implemented by ↑
Infrastructure Layer (MealLogWebSocketClient, SwiftDataMealLogRepository)
```

**Principles Followed:**
- Domain layer defines interfaces (MealLogWebSocketProtocol)
- Infrastructure implements interfaces (MealLogWebSocketClient)
- Presentation depends only on domain abstractions
- Dependency injection via AppDependencies

### ✅ SwiftData Schema Requirements

- All `@Model` classes use `SD` prefix (SDMeal, SDMealLogItem)
- Schema versioning properly maintained (SchemaV6)
- PersistenceHelper typealiases updated
- Models properly defined in schema

### ✅ Outbox Pattern

- Meal logs use Outbox Pattern for reliable sync
- WebSocket provides real-time status updates
- Local-first storage ensures offline capability
- Eventually consistent with backend

---

## 🧪 Testing Considerations

### Unit Tests Needed

1. **MealLogWebSocketClient Tests:**
   - Connection establishment
   - Message parsing
   - Subscriber notifications
   - Error handling
   - Reconnection logic

2. **NutritionViewModel Tests:**
   - WebSocket connection on init
   - Status update handling
   - UI refresh on updates
   - Error handling

3. **Domain Model Tests:**
   - WebSocket payload to domain model conversion
   - Field validation
   - Edge cases (missing fields, invalid data)

### Integration Tests Needed

1. **End-to-End Flow:**
   - Submit meal log
   - Receive WebSocket updates
   - Verify local data updates
   - Verify UI updates

2. **Network Scenarios:**
   - Offline → Online transition
   - WebSocket disconnect/reconnect
   - Token refresh during WebSocket session
   - Multiple simultaneous updates

---

## 📝 Configuration

### WebSocket URL

Configured in `config.plist`:

```xml
<key>WebSocketURL</key>
<string>wss://fit-iq-backend.fly.dev/ws</string>
```

Fallback default: `wss://fit-iq-backend.fly.dev/ws`

### Authentication

WebSocket uses JWT access token passed as query parameter:
```
wss://backend.com/ws?token=<JWT_ACCESS_TOKEN>
```

Token automatically refreshed by `AuthManager` when expired.

---

## 🚀 Usage Example

### ViewModel automatically handles WebSocket

```swift
// ViewModel automatically connects on init
let viewModel = NutritionViewModel(
    saveMealLogUseCase: saveMealLogUseCase,
    getMealLogsUseCase: getMealLogsUseCase,
    webSocketClient: webSocketClient,
    mealLogRepository: repository,
    authTokenPersistence: tokenPersistence
)

// Submit meal log
await viewModel.saveMealLog(
    rawInput: "2 eggs, toast, coffee",
    mealType: "breakfast",
    loggedAt: Date()
)

// WebSocket automatically receives updates:
// 1. status: "pending"
// 2. status: "processing"
// 3. status: "completed" (with parsed items)

// UI automatically refreshes with updates
```

---

## 🔍 Debugging

### Enable WebSocket Logs

WebSocket client prints detailed logs:

```
MealLogWebSocketClient: Connecting to wss://...
MealLogWebSocketClient: ✅ Connected successfully
MealLogWebSocketClient: 📩 Received message: {...}
MealLogWebSocketClient: ✅ Status update for meal log ABC123: completed
MealLogWebSocketClient: 📢 Notifying subscriber ...
```

### Manual Reconnection

For testing/debugging:

```swift
await viewModel.reconnectWebSocket()
```

---

## ✅ Verification Checklist

- [x] Schema updated with new fields (SchemaV6)
- [x] Domain models updated and aligned
- [x] WebSocket protocol defined (MealLogWebSocketProtocol)
- [x] WebSocket client implemented (MealLogWebSocketClient)
- [x] ViewModel integrated with WebSocket
- [x] Dependency injection configured
- [x] PersistenceHelper updated
- [x] No compilation errors
- [x] Follows Hexagonal Architecture
- [x] Follows SwiftData naming conventions
- [x] Uses Outbox Pattern for sync
- [x] Configuration from config.plist
- [x] Thread-safe implementation
- [x] Error handling in place
- [x] Automatic reconnection logic

---

## 📚 Related Documentation

- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Architecture:** `.github/copilot-instructions.md`
- **Schema Versioning:** `Infrastructure/Persistence/Schema/SchemaDefinition.swift`
- **Outbox Pattern:** `.github/copilot-instructions.md` (Outbox Pattern section)

---

## 🎉 Summary

The nutrition WebSocket integration is **fully implemented** and follows all architectural principles:

1. ✅ **Real-time updates** - Users see meal processing status instantly
2. ✅ **Local-first** - Works offline, syncs when available
3. ✅ **Crash-resistant** - Outbox Pattern ensures reliability
4. ✅ **Clean architecture** - Hexagonal Architecture with proper separation
5. ✅ **Type-safe** - Swift's type system prevents errors
6. ✅ **Testable** - All components can be unit tested
7. ✅ **Maintainable** - Clear separation of concerns

The implementation eliminates the need for additional API calls after meal submission, providing a seamless user experience with instant feedback during AI processing.