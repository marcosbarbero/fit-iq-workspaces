# WebSocket Service Pattern

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Active

---

## Overview

This document describes the pattern for wrapping WebSocket infrastructure protocols in domain services, following Hexagonal Architecture principles and the established `AuthManager` pattern.

---

## Problem

**❌ Anti-Pattern: Direct Protocol Injection**

```swift
// ViewModels directly depending on infrastructure ports
class NutritionViewModel {
    private let webSocketClient: MealLogWebSocketProtocol  // ❌ Infrastructure port
    private let authTokenPersistence: AuthTokenPersistencePortProtocol  // ❌ Infrastructure port
}
```

**Issues:**
1. **Breaks Hexagonal Architecture**: Presentation layer depends directly on Infrastructure layer
2. **Inconsistent**: Doesn't follow existing `AuthManager` pattern
3. **Mixed Responsibilities**: ViewModel manages infrastructure concerns (connect, disconnect, lifecycle)
4. **Hard to Test**: Must mock infrastructure protocols
5. **Poor Encapsulation**: Infrastructure details leak into ViewModels

---

## Solution: Service Wrapper Pattern

**✅ Correct Pattern: Domain Service Wrapper**

```swift
// Service wraps infrastructure protocol
class MealLogWebSocketService {
    private let webSocketClient: MealLogWebSocketProtocol  // ✅ Hidden
    private let authManager: AuthManager  // ✅ Domain service
}

// ViewModel depends on domain service
class NutritionViewModel {
    private let webSocketService: MealLogWebSocketService  // ✅ Domain service
    private let authManager: AuthManager  // ✅ Domain service
}
```

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation Layer (ViewModels)                             │
│   - NutritionViewModel                                      │
│   - Depends on: MealLogWebSocketService (Domain Service)    │
└─────────────────────────────────────────────────────────────┘
                            ↓ depends on
┌─────────────────────────────────────────────────────────────┐
│ Domain Layer (Services, Use Cases)                          │
│   - MealLogWebSocketService (wraps protocol)                │
│   - AuthManager (wraps protocol)                            │
│   - SaveMealLogUseCase, GetMealLogsUseCase                  │
└─────────────────────────────────────────────────────────────┘
                            ↓ depends on
┌─────────────────────────────────────────────────────────────┐
│ Infrastructure Layer (Ports & Adapters)                     │
│   - MealLogWebSocketProtocol (port/interface)               │
│   - MealLogWebSocketClient (adapter/implementation)         │
│   - AuthTokenPersistencePortProtocol (port/interface)       │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Pattern

### 1. Service Structure

**Location:** `Infrastructure/Services/WebSocket/MealLogWebSocketService.swift`

```swift
import Foundation
import Combine

final class MealLogWebSocketService: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionError: String?
    
    // MARK: - Dependencies (Hidden from ViewModels)
    private let webSocketClient: MealLogWebSocketProtocol
    private let authManager: AuthManager
    
    // MARK: - Private State
    private var subscriptionId: UUID?
    private var updateHandler: ((MealLogStatusUpdate) async -> Void)?
    
    // MARK: - Initialization
    init(
        webSocketClient: MealLogWebSocketProtocol,
        authManager: AuthManager
    ) {
        self.webSocketClient = webSocketClient
        self.authManager = authManager
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Public API (Domain-Level Abstraction)
    
    func connect(onUpdate: @escaping (MealLogStatusUpdate) async -> Void) async throws {
        // 1. Get token from AuthManager (not direct port access)
        guard let accessToken = try? authManager.fetchAccessToken() else {
            throw MealLogWebSocketServiceError.missingAccessToken
        }
        
        // 2. Connect to WebSocket
        try await webSocketClient.connect(accessToken: accessToken)
        
        // 3. Subscribe to updates
        subscriptionId = webSocketClient.subscribe { update in
            Task { await onUpdate(update) }
        }
        
        isConnected = true
    }
    
    func disconnect() {
        if let id = subscriptionId {
            webSocketClient.unsubscribe(id)
            subscriptionId = nil
        }
        webSocketClient.disconnect()
        isConnected = false
    }
    
    func reconnect(onUpdate: @escaping (MealLogStatusUpdate) async -> Void) async throws {
        disconnect()
        try await connect(onUpdate: onUpdate)
    }
}
```

### 2. ViewModel Usage

```swift
@Observable
final class NutritionViewModel {
    
    // MARK: - Dependencies (Domain Services Only)
    private let saveMealLogUseCase: SaveMealLogUseCase
    private let getMealLogsUseCase: GetMealLogsUseCase
    private let webSocketService: MealLogWebSocketService  // ✅ Service
    private let authManager: AuthManager  // ✅ Service
    
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
        
        Task { await connectWebSocket() }
    }
    
    deinit {
        webSocketService.disconnect()
    }
    
    @MainActor
    private func connectWebSocket() async {
        do {
            try await webSocketService.connect { [weak self] update in
                await self?.handleWebSocketUpdate(update)
            }
        } catch {
            errorMessage = "Failed to connect to real-time updates"
        }
    }
}
```

### 3. Dependency Injection

**AppDependencies.swift:**

```swift
// MARK: - WebSocket Client (Infrastructure Port)
let webSocketURL = ConfigurationProperties.value(for: "WebSocketURL") ?? ""
let mealLogWebSocketClient = MealLogWebSocketClient(webSocketURL: webSocketURL)

// MARK: - WebSocket Service (Domain Service - wraps protocol)
let mealLogWebSocketService = MealLogWebSocketService(
    webSocketClient: mealLogWebSocketClient,
    authManager: authManager
)
```

**ViewDependencies.swift:**

```swift
let nutritionView = NutritionView(
    saveMealLogUseCase: appDependencies.saveMealLogUseCase,
    getMealLogsUseCase: appDependencies.getMealLogsUseCase,
    webSocketService: appDependencies.mealLogWebSocketService,  // ✅ Service
    authManager: authManager,  // ✅ Service
    addMealViewModel: addMealViewModel,
    quickSelectViewModel: quickSelectViewModel
)
```

---

## Benefits

### 1. **Clean Architecture Compliance**
- ✅ Presentation depends on Domain services
- ✅ Domain defines interfaces (ports)
- ✅ Infrastructure implements interfaces (adapters)

### 2. **Consistency with Existing Patterns**
- ✅ Mirrors `AuthManager` approach
- ✅ Follows established conventions
- ✅ Predictable for developers

### 3. **Single Responsibility Principle**
- ✅ Service: Manages WebSocket lifecycle
- ✅ ViewModel: Manages UI state and logic
- ✅ Clear separation of concerns

### 4. **Testability**
- ✅ Easy to mock `MealLogWebSocketService`
- ✅ No need to mock infrastructure protocols
- ✅ Test domain logic without infrastructure

### 5. **Reusability**
- ✅ Multiple ViewModels can use same service
- ✅ Centralized connection management
- ✅ Consistent error handling

### 6. **Encapsulation**
- ✅ Infrastructure details hidden
- ✅ Clean API surface
- ✅ No protocol leakage

---

## When to Use This Pattern

**✅ Use Service Wrapper When:**

1. **Infrastructure Protocol** - Wrapping infrastructure ports (WebSocket, Bluetooth, etc.)
2. **Stateful Operations** - Managing long-lived connections or resources
3. **Cross-Cutting Concerns** - Authentication, logging, monitoring
4. **Multiple Consumers** - Multiple ViewModels need same infrastructure
5. **Complex Lifecycle** - Connect, disconnect, reconnect logic

**Example Services:**
- `AuthManager` (wraps `AuthTokenPersistencePortProtocol`)
- `MealLogWebSocketService` (wraps `MealLogWebSocketProtocol`)
- `BluetoothService` (wraps `BluetoothProtocol`)
- `LocationService` (wraps `LocationProviderProtocol`)

**❌ Don't Use When:**

1. **Pure Use Cases** - Simple, stateless operations
2. **Repository Pattern** - Already follows correct abstraction
3. **One-Time Operations** - No lifecycle management needed

---

## Comparison with Other Patterns

### vs. Direct Protocol Injection

| Aspect | Direct Protocol | Service Wrapper |
|--------|----------------|-----------------|
| **Architecture** | ❌ Breaks layers | ✅ Follows Hexagonal |
| **Testability** | ❌ Must mock protocol | ✅ Mock service |
| **Consistency** | ❌ Inconsistent | ✅ Follows AuthManager |
| **Encapsulation** | ❌ Leaks details | ✅ Hides infrastructure |
| **Reusability** | ❌ Duplicated logic | ✅ Centralized |

### vs. Use Cases

| Aspect | Use Case | Service |
|--------|----------|---------|
| **State** | ❌ Stateless | ✅ Stateful |
| **Lifecycle** | ❌ No lifecycle | ✅ Manages lifecycle |
| **Purpose** | ✅ Business logic | ✅ Infrastructure wrapper |
| **Dependencies** | ✅ Domain + Ports | ✅ Domain + Ports |

---

## Examples in Codebase

### 1. AuthManager (Existing Pattern)

**Wraps:** `AuthTokenPersistencePortProtocol`

```swift
class AuthManager: ObservableObject {
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    
    @Published var isAuthenticated: Bool = false
    @Published var currentAuthState: AuthState = .checkingAuthentication
    
    func handleSuccessfulAuth(userProfileID: UUID?) { /* ... */ }
    func logout() { /* ... */ }
}
```

**Usage:** ViewModels and Use Cases depend on `AuthManager`, not `AuthTokenPersistencePortProtocol`

### 2. MealLogWebSocketService (New Pattern)

**Wraps:** `MealLogWebSocketProtocol`

```swift
final class MealLogWebSocketService: ObservableObject {
    private let webSocketClient: MealLogWebSocketProtocol
    private let authManager: AuthManager
    
    @Published private(set) var isConnected: Bool = false
    
    func connect(onUpdate: @escaping (MealLogStatusUpdate) async -> Void) async throws
    func disconnect()
    func reconnect(onUpdate: @escaping (MealLogStatusUpdate) async -> Void) async throws
}
```

**Usage:** ViewModels depend on `MealLogWebSocketService`, not `MealLogWebSocketProtocol`

---

## Migration Checklist

When migrating from direct protocol injection to service wrapper:

- [ ] **Create Service**
  - [ ] Create service class in `Infrastructure/Services/`
  - [ ] Inject infrastructure protocol into service (private)
  - [ ] Inject other domain services (e.g., AuthManager)
  - [ ] Define clean public API
  - [ ] Add `@Observable` if state needs publishing

- [ ] **Update Dependencies**
  - [ ] Register service in `AppDependencies`
  - [ ] Inject protocol into service, not ViewModel
  - [ ] Pass service to ViewModels/Views

- [ ] **Update ViewModels**
  - [ ] Replace protocol dependency with service
  - [ ] Update initialization
  - [ ] Simplify lifecycle management (service handles it)

- [ ] **Update Tests**
  - [ ] Create mock service
  - [ ] Update test initialization
  - [ ] Verify service behavior

- [ ] **Verify Architecture**
  - [ ] Run diagnostics
  - [ ] Check dependency graph
  - [ ] Ensure no protocol leakage to Presentation

---

## Best Practices

### 1. **Service Naming**
- Pattern: `{Feature}{Technology}Service`
- Examples: `MealLogWebSocketService`, `BluetoothDeviceService`
- Consistent with `AuthManager` (also a service)

### 2. **State Publishing**
- Use `ObservableObject` with `@Published` for SwiftUI integration
- Publish connection state (`isConnected`, `connectionError`)
- Keep state minimal and domain-focused

### 3. **Error Handling**
- Define service-specific error types
- Provide user-friendly error messages
- Include recovery suggestions

### 4. **Lifecycle Management**
- Service owns resource lifecycle
- Clean up in `deinit`
- Provide explicit `connect()` and `disconnect()` methods

### 5. **Authentication Integration**
- Always use `AuthManager` for tokens
- Never access `AuthTokenPersistencePortProtocol` directly
- Handle authentication failures gracefully

---

## Related Documentation

- `docs/.github/copilot-instructions.md` - Project architecture guidelines
- `Infrastructure/Security/AuthManager.swift` - Reference implementation
- `Domain/Ports/MealLogWebSocketProtocol.swift` - Infrastructure port definition
- `Infrastructure/Services/WebSocket/MealLogWebSocketService.swift` - Service implementation

---

## Summary

**Key Principles:**
1. ✅ Wrap infrastructure protocols in domain services
2. ✅ Follow the `AuthManager` pattern
3. ✅ ViewModels depend on services, not protocols
4. ✅ Services manage infrastructure lifecycle
5. ✅ Maintain Hexagonal Architecture boundaries

**Benefits:**
- Clean architecture compliance
- Consistent patterns
- Better testability
- Improved encapsulation
- Centralized lifecycle management

---

**Version History:**
- 1.0.0 (2025-01-27): Initial documentation after MealLogWebSocketService refactoring