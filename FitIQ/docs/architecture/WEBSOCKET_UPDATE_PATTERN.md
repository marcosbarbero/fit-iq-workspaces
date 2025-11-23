# WebSocket Update Pattern Guide

**Date:** 2025-01-27  
**Purpose:** Standard pattern for handling real-time backend updates via WebSocket  
**Applies To:** All features using WebSocket notifications (Nutrition, Progress, etc.)

---

## Overview

When the backend completes asynchronous processing (AI parsing, analysis, etc.) and sends results via WebSocket, you **MUST** update local storage with the received data. Simply refreshing the UI from local storage will not work because the local data hasn't been updated yet.

---

## The Problem (Anti-Pattern ❌)

```swift
// ❌ WRONG: This will NOT show the updated data
private func handleWebSocketUpdate(_ payload: SomePayload) async {
    print("Received data: \(payload.someValue)")
    
    // Just refresh from local storage (which has no data!)
    await loadData()
}
```

**Why this fails:**
1. Local storage was saved BEFORE backend processing
2. WebSocket brings new data but we discard it
3. `loadData()` reads from local storage (still has old/empty data)
4. UI shows zeros or stale data

---

## The Solution (Correct Pattern ✅)

### Step 1: Create an Update Use Case

```swift
// Domain/UseCases/YourFeature/UpdateYourEntityStatusUseCase.swift

protocol UpdateYourEntityStatusUseCase {
    func execute(
        backendID: String,
        status: ProcessingStatus,
        data: [YourDataModel],
        // ... other fields from WebSocket payload
    ) async throws
}

final class UpdateYourEntityStatusUseCaseImpl: UpdateYourEntityStatusUseCase {
    private let repository: YourRepositoryProtocol
    private let authManager: AuthManager
    
    init(repository: YourRepositoryProtocol, authManager: AuthManager) {
        self.repository = repository
        self.authManager = authManager
    }
    
    func execute(
        backendID: String,
        status: ProcessingStatus,
        data: [YourDataModel],
        // ... other fields
    ) async throws {
        print("UpdateUseCase: Updating entity with backend ID: \(backendID)")
        
        // Get current user
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw UpdateError.userNotAuthenticated
        }
        
        // Find local entity by backend ID
        let entities = try await repository.fetchLocal(forUserID: userID, ...)
        guard let localEntity = entities.first(where: { $0.backendID == backendID }) else {
            throw UpdateError.entityNotFound
        }
        
        // Update local storage with WebSocket data
        try await repository.updateStatus(
            forLocalID: localEntity.id,
            status: status,
            data: data,
            forUserID: userID
        )
        
        print("UpdateUseCase: ✅ Entity updated successfully")
    }
}
```

### Step 2: Update ViewModel to Use the Use Case

```swift
// Presentation/ViewModels/YourViewModel.swift

@Observable
final class YourViewModel {
    private let updateUseCase: UpdateYourEntityStatusUseCase
    // ... other dependencies
    
    init(
        updateUseCase: UpdateYourEntityStatusUseCase,
        // ... other dependencies
    ) {
        self.updateUseCase = updateUseCase
        // ...
    }
    
    // ✅ CORRECT: Update local storage first, then refresh UI
    @MainActor
    private func handleWebSocketUpdate(_ payload: SomePayload) async {
        print("ViewModel: Received WebSocket update")
        print("ViewModel:    - Backend ID: \(payload.id)")
        print("ViewModel:    - Data count: \(payload.data.count)")
        
        // ✅ STEP 1: Update local storage with WebSocket data
        do {
            // Convert WebSocket payload to domain models
            let domainData = payload.data.map { /* convert */ }
            
            // Update local storage
            try await updateUseCase.execute(
                backendID: payload.id,
                status: .completed,
                data: domainData
            )
            
            print("ViewModel: ✅ Local storage updated with WebSocket data")
        } catch {
            print("ViewModel: ❌ Failed to update: \(error)")
            errorMessage = error.localizedDescription
            return
        }
        
        // ✅ STEP 2: Now refresh UI (will show updated data)
        await loadData()
        
        print("ViewModel: ✅ UI updated with new data")
    }
}
```

### Step 3: Register in Dependency Injection

```swift
// Infrastructure/Configuration/AppDependencies.swift

// Property
let updateYourEntityStatusUseCase: UpdateYourEntityStatusUseCase

// Init parameter
init(
    // ...
    updateYourEntityStatusUseCase: UpdateYourEntityStatusUseCase,
    // ...
)

// Assignment
self.updateYourEntityStatusUseCase = updateYourEntityStatusUseCase

// Factory method
static func build(authManager: AuthManager) -> AppDependencies {
    // ...
    
    let updateUseCase = UpdateYourEntityStatusUseCaseImpl(
        repository: yourRepository,
        authManager: authManager
    )
    
    // Pass to ViewModels, etc.
}
```

---

## Real Example: Meal Log Integration

### Use Case
```swift
// Domain/UseCases/Nutrition/UpdateMealLogStatusUseCase.swift
func execute(
    backendID: String,
    status: MealLogStatus,
    items: [MealLogItem],
    totalCalories: Int?,
    totalProteinG: Double?,
    totalCarbsG: Double?,
    totalFatG: Double?,
    // ...
) async throws
```

### ViewModel Handler
```swift
// Presentation/ViewModels/NutritionViewModel.swift
private func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
    // Convert payload items to domain items
    let domainItems = payload.items.map { /* convert */ }
    
    // ✅ Update local storage
    try await updateMealLogStatusUseCase.execute(
        backendID: payload.id,
        status: .completed,
        items: domainItems,
        totalCalories: payload.totalCalories,
        totalProteinG: payload.totalProteinG,
        totalCarbsG: payload.totalCarbsG,
        totalFatG: payload.totalFatG
    )
    
    // ✅ Refresh UI
    await loadDataForSelectedDate()
}
```

---

## Checklist for WebSocket Integrations

When adding a new WebSocket notification handler:

- [ ] **Create Update Use Case** in `Domain/UseCases/YourFeature/`
  - Protocol defines interface
  - Implementation finds local entity by backend ID
  - Implementation updates local storage with WebSocket data

- [ ] **Update Repository** (if needed)
  - Ensure `updateStatus()` or similar method exists
  - Method should update all relevant fields
  - Should use SwiftData/persistence layer

- [ ] **Update ViewModel Handler**
  - Call update use case with WebSocket payload data
  - Handle errors gracefully
  - Refresh UI after update completes

- [ ] **Register in DI**
  - Add property to `AppDependencies`
  - Add parameter to `init()`
  - Assign in initializer
  - Create instance in `build()` method
  - Pass to ViewModels

- [ ] **Update View Init** (if needed)
  - Add parameter for new use case
  - Pass through dependency chain

- [ ] **Test End-to-End**
  - Submit data that triggers async processing
  - Verify WebSocket notification received
  - Verify local storage updated (check logs)
  - Verify UI shows updated values

---

## Common Mistakes

### ❌ Mistake 1: Only Logging WebSocket Data
```swift
private func handleUpdate(_ payload: SomePayload) async {
    print("Received: \(payload.data)") // ❌ Data is lost!
    await loadData()
}
```

### ❌ Mistake 2: Using WebSocket Data Directly
```swift
private func handleUpdate(_ payload: SomePayload) async {
    self.items = payload.items // ❌ Not persisted!
    // If app crashes, data is lost
}
```

### ❌ Mistake 3: Not Converting Data Types
```swift
try await updateUseCase.execute(
    items: payload.items // ❌ Wrong type! Convert first
)
```

### ✅ Correct: Update Local Storage, Then Refresh
```swift
private func handleUpdate(_ payload: SomePayload) async {
    let domainItems = payload.items.map { convertToDomain($0) }
    try await updateUseCase.execute(items: domainItems)
    await loadData() // Now shows updated data!
}
```

---

## Architecture Benefits

### Why This Pattern Works

1. **Single Source of Truth**
   - Local storage (SwiftData) is always the source of truth
   - UI always reads from local storage
   - WebSocket updates sync to local storage

2. **Crash Resistant**
   - Data is persisted before UI updates
   - Survives app crashes/restarts

3. **Offline Compatible**
   - Works with or without network
   - Polling fallback can also update local storage

4. **Testable**
   - Use cases can be unit tested
   - ViewModels can be tested with mock use cases

5. **Follows Hexagonal Architecture**
   - Domain layer (use case) is pure business logic
   - Infrastructure layer (repository) handles persistence
   - Presentation layer (ViewModel) orchestrates

---

## Related Documentation

- [Meal Log Zero Values Fix](./MEAL_LOG_ZERO_VALUES_FIX.md) - Real bug fix example
- [Outbox Pattern](./NUTRITION_LOGGING_COMPLETION_SUMMARY.md) - Outbound sync pattern
- [Copilot Instructions](./.github/copilot-instructions.md) - Architecture guidelines
- [WebSocket Ping/Pong](./docs/troubleshooting/WEBSOCKET_NOT_DETECTED_BY_BACKEND.md) - Connection health

---

## Summary

**Golden Rule:** When WebSocket notifications arrive with processed data:

1. ✅ **UPDATE** local storage with the new data (via use case + repository)
2. ✅ **THEN** refresh UI from local storage

**Never:**
- ❌ Just log the data and discard it
- ❌ Update UI directly from WebSocket payload
- ❌ Skip persisting to local storage

**Always:**
- ✅ Create an update use case
- ✅ Update local storage first
- ✅ Refresh UI after update
- ✅ Handle errors gracefully
- ✅ Follow dependency injection patterns

---

**Remember:** WebSocket notifications are ephemeral. If you don't persist the data, it's lost forever. Always update local storage first!