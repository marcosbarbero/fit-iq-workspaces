# Hexagonal Architecture: Mood Sync Refactoring

**Date:** 2025-01-15  
**Status:** ✅ Completed

---

## Problem

The `AppDependencies` class was directly calling infrastructure code (`MoodSyncService`), violating Hexagonal Architecture principles:

```swift
// ❌ WRONG: AppDependencies calling infrastructure directly
let restoredCount = try await moodSyncService.restoreFromBackend()
```

This created a dependency from the application layer directly to infrastructure, bypassing the domain layer entirely.

---

## Solution: Proper Hexagonal Architecture

We refactored to follow the dependency rule:

```
Presentation → Domain ← Infrastructure
```

### 1. Domain Layer (Ports & Use Cases)

**Created `MoodSyncPort` (Domain Port):**
```swift
// Domain/UseCases/SyncMoodEntriesUseCase.swift
protocol MoodSyncPort {
    func restoreFromBackend() async throws -> Int
    func performFullSync() async throws -> MoodSyncResult
}
```

**Created `SyncMoodEntriesUseCase` (Domain Use Case):**
```swift
protocol SyncMoodEntriesUseCase {
    func execute() async throws -> MoodSyncResult
}

final class SyncMoodEntriesUseCaseImpl: SyncMoodEntriesUseCase {
    private let syncPort: MoodSyncPort
    
    func execute() async throws -> MoodSyncResult {
        return try await syncPort.performFullSync()
    }
}
```

**Created `MoodSyncResult` (Domain Model):**
```swift
struct MoodSyncResult {
    let entriesRestored: Int
    let entriesPushed: Int
    
    var totalSynced: Int { ... }
    var description: String { ... }
}
```

### 2. Infrastructure Layer (Adapters)

**Updated `MoodSyncService` to implement the port:**
```swift
// Services/Sync/MoodSyncService.swift
@MainActor
final class MoodSyncService: MoodSyncPort {
    // Implements the domain port
    // Has all SwiftData and backend service dependencies
}
```

**Updated `MockMoodSyncService`:**
```swift
@MainActor
final class MockMoodSyncService: MoodSyncPort {
    // Mock implementation for testing
}
```

### 3. Presentation Layer

**Updated `MoodViewModel`:**
```swift
final class MoodViewModel {
    private let syncMoodEntriesUseCase: SyncMoodEntriesUseCase
    
    func syncWithBackend() async {
        let result = try await syncMoodEntriesUseCase.execute()
        // ...
    }
}
```

### 4. Application Layer

**Updated `AppDependencies`:**
```swift
// DI/AppDependencies.swift
private(set) lazy var syncMoodEntriesUseCase: SyncMoodEntriesUseCase = {
    SyncMoodEntriesUseCaseImpl(syncPort: moodSyncService)
}()

func restoreMoodDataIfNeeded() async {
    let result = try await syncMoodEntriesUseCase.execute()
    // ✅ Calls use case, not infrastructure
}
```

---

## Architecture Layers

```
┌─────────────────────────────────────────────────┐
│           Presentation Layer                     │
│  (MoodViewModel, MoodTrackingView)              │
│           ↓ depends on ↓                        │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│              Domain Layer                        │
│  ┌───────────────────────────────────────────┐ │
│  │ Use Cases                                  │ │
│  │  - SyncMoodEntriesUseCase                 │ │
│  └───────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────┐ │
│  │ Ports (Interfaces)                        │ │
│  │  - MoodSyncPort                           │ │
│  └───────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────┐ │
│  │ Models                                     │ │
│  │  - MoodSyncResult                         │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
                    ↑
                    │ implements
                    │
┌─────────────────────────────────────────────────┐
│          Infrastructure Layer                    │
│  ┌───────────────────────────────────────────┐ │
│  │ Adapters (implement ports)                │ │
│  │  - MoodSyncService: MoodSyncPort          │ │
│  │  - MockMoodSyncService: MoodSyncPort      │ │
│  └───────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────┐ │
│  │ External Dependencies                     │ │
│  │  - SwiftData (ModelContext)               │ │
│  │  - Backend Service                        │ │
│  │  - Token Storage                          │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

---

## Benefits

### 1. **Dependency Inversion Principle**
- High-level modules (use cases) don't depend on low-level modules (services)
- Both depend on abstractions (ports)

### 2. **Testability**
- Easy to mock the sync port for testing
- Use cases can be tested without infrastructure
- ViewModels can be tested with mock use cases

### 3. **Flexibility**
- Can swap sync implementations without changing domain
- Can add new sync strategies (offline-first, real-time, etc.)

### 4. **Clear Responsibilities**
- **Domain** defines WHAT to do (business logic)
- **Infrastructure** defines HOW to do it (technical implementation)
- **Presentation** defines WHEN to do it (user interaction)

### 5. **Maintainability**
- Changes to backend API only affect infrastructure layer
- Business logic changes only affect domain layer
- UI changes only affect presentation layer

---

## File Structure

```
lume/
├── Domain/
│   └── UseCases/
│       └── SyncMoodEntriesUseCase.swift    # Port + Use Case
├── Services/
│   └── Sync/
│       ├── MoodSyncService.swift           # Real adapter
│       └── MockMoodSyncService.swift       # Mock adapter
├── Presentation/
│   └── ViewModels/
│       └── MoodViewModel.swift             # Uses use case
└── DI/
    └── AppDependencies.swift               # Wires everything
```

---

## Migration Checklist

- [x] Created `MoodSyncPort` in Domain
- [x] Created `SyncMoodEntriesUseCase` in Domain
- [x] Created `MoodSyncResult` domain model
- [x] Updated `MoodSyncService` to implement port
- [x] Updated `MockMoodSyncService` to implement port
- [x] Updated `MoodViewModel` to use use case
- [x] Updated `AppDependencies` to wire use case
- [x] Updated preview code
- [x] Verified no compilation errors

---

## Summary

This refactoring properly implements Hexagonal Architecture by:

1. ✅ **Defining ports in the domain** - `MoodSyncPort`
2. ✅ **Creating use cases that orchestrate** - `SyncMoodEntriesUseCase`
3. ✅ **Implementing ports in infrastructure** - `MoodSyncService`
4. ✅ **Presentation depends only on domain** - `MoodViewModel` uses use case
5. ✅ **Infrastructure depends on domain** - Services implement ports

Now the architecture follows the dependency rule and is properly layered! 🎉
