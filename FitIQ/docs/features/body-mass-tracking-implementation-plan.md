# Body Mass Tracking Implementation Plan

**Date:** 2025-01-27  
**Feature:** Complete body mass/weight tracking with HealthKit sync  
**Status:** 🚧 In Progress

---

## Overview

Implement complete body mass (weight) tracking with:
1. Save to HealthKit, local storage, and backend
2. Real-time UI updates across all views
3. Historical data loading from HealthKit (1 year)
4. Automatic sync when HealthKit data changes
5. Rich graph visualization in detail view

---

## Current State Analysis

### ✅ Already Implemented

1. **`SaveBodyMassUseCase`** - Saves to HealthKit only
   - File: `FitIQ/Presentation/UI/Summary/SaveBodyMassUseCase.swift`
   - Saves weight to HealthKit
   - Triggers `onDataUpdate` callback
   - ⚠️ Does NOT save to backend via `/progress` API

2. **`BodyMassEntryViewModel`** - Entry form logic
   - File: `FitIQ/Presentation/UI/Summary/BodyMassEntryViewModel.swift`
   - Loads last weight
   - Validates input
   - Saves via `SaveBodyMassUseCase`

3. **`BodyMassEntryView`** - Entry form UI
   - File: `FitIQ/Presentation/UI/Summary/BodyMassEntryView.swift`
   - Drag gesture + text input
   - Validation feedback
   - Save button

4. **`BodyMassDetailViewModel`** - Detail view logic (MOCK DATA)
   - File: `FitIQ/Presentation/ViewModels/BodyMassDetailViewModel.swift`
   - ⚠️ Currently uses mock data
   - ⚠️ No real HealthKit integration
   - Has time range filtering (30D, 6M, 1Y)

5. **`SummaryView`** - Summary card
   - Shows current weight
   - Shows mini line graph (last 7 entries)
   - Links to detail view

### ❌ Missing/Incomplete

1. **No backend sync for weight** - Weight not saved to `/api/v1/progress`
2. **No deduplication** - Similar to steps issue we just fixed
3. **No historical loading** - From HealthKit (1 year back)
4. **Mock data in detail view** - Not using real data
5. **No HealthKit observer** - For automatic updates
6. **No event-driven updates** - Views don't refresh when data changes

---

## Architecture Design

### Data Flow (Target State)

```
┌─────────────────────────────────────────────────────────────┐
│ User Enters Weight in BodyMassEntryView                     │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ SaveBodyMassProgressUseCase (NEW)                           │
│ - Check for existing entry (deduplication)                  │
│ - Save to HealthKit                                         │
│ - Save to local progress (SDProgressEntry)                  │
│ - Trigger sync to backend (/api/v1/progress)               │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ LocalDataChangeMonitor                                       │
│ - Publishes sync event                                      │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ RemoteSyncService                                            │
│ - Syncs to backend (/api/v1/progress)                      │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ ProgressEventPublisher (NEW)                                │
│ - Publishes "weight updated" event                          │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ SummaryViewModel + BodyMassDetailViewModel                  │
│ - Listen to events                                          │
│ - Refresh UI                                                │
└─────────────────────────────────────────────────────────────┘
```

### HealthKit Observer Flow

```
┌─────────────────────────────────────────────────────────────┐
│ HealthKit Data Changes (user adds weight in Health app)     │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ HKObserverQuery fires                                        │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ HealthDataSyncManager.handleHealthKitUpdate()                │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ ProcessDailyHealthDataUseCase                                │
│ - Fetches latest weight from HealthKit                      │
│ - Checks for duplicates                                     │
│ - Saves to local progress (SDProgressEntry)                 │
│ - Triggers sync event                                       │
└─────────────┬───────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ Same flow as manual entry (sync + event publish)            │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Tasks

### Phase 1: Backend Sync for Weight (HIGH PRIORITY)

#### Task 1.1: Create SaveWeightProgressUseCase

**File:** `FitIQ/Domain/UseCases/SaveWeightProgressUseCase.swift`

Similar to `SaveStepsProgressUseCase`, but for weight:

```swift
protocol SaveWeightProgressUseCase {
    func execute(weightKg: Double, date: Date) async throws -> UUID
}

final class SaveWeightProgressUseCaseImpl: SaveWeightProgressUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    func execute(weightKg: Double, date: Date) async throws -> UUID {
        // 1. Get user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveWeightProgressError.userNotAuthenticated
        }
        
        // 2. Check for existing entry (DEDUPLICATION)
        let existingEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .weight,
            syncStatus: nil
        )
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        // 3. Find entry for same date
        if let existingEntry = existingEntries.first(where: { entry in
            calendar.isDate(calendar.startOfDay(for: entry.date), inSameDayAs: targetDate)
        }) {
            // Check if quantity is the same
            if existingEntry.quantity == weightKg {
                // Skip duplicate
                return existingEntry.id
            } else {
                // Update quantity
                let updatedEntry = ProgressEntry(
                    id: existingEntry.id,
                    userID: userID,
                    type: .weight,
                    quantity: weightKg,
                    date: existingEntry.date,
                    notes: existingEntry.notes,
                    createdAt: existingEntry.createdAt,
                    updatedAt: Date(),
                    backendID: existingEntry.backendID,
                    syncStatus: .pending
                )
                return try await progressRepository.save(
                    progressEntry: updatedEntry, 
                    forUserID: userID
                )
            }
        }
        
        // 4. Create new entry
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .weight,
            quantity: weightKg,
            date: targetDate,
            notes: nil,
            createdAt: Date(),
            backendID: nil,
            syncStatus: .pending
        )
        
        return try await progressRepository.save(
            progressEntry: progressEntry, 
            forUserID: userID
        )
    }
}
```

**Key Features:**
- ✅ Deduplication by date
- ✅ Update if quantity changed
- ✅ Skip if identical
- ✅ Auto-syncs to backend via event system

#### Task 1.2: Update SaveBodyMassUseCase to Use Progress Tracking

**File:** `FitIQ/Presentation/UI/Summary/SaveBodyMassUseCase.swift`

Update to save to both HealthKit AND progress tracking:

```swift
public final class SaveBodyMassUseCase: SaveBodyMassUseCaseProtocol {
    private let healthRepository: HealthRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase  // NEW
    
    init(
        healthRepository: HealthRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManager,
        saveWeightProgressUseCase: SaveWeightProgressUseCase  // NEW
    ) {
        self.healthRepository = healthRepository
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager
        self.saveWeightProgressUseCase = saveWeightProgressUseCase  // NEW
    }
    
    public func execute(weightKg: Double, date: Date) async throws {
        guard let currentUserID = authManager.currentUserProfileID else {
            throw BodyMassError.userNotAuthenticated
        }
        
        // 1. Save to HealthKit
        try await healthRepository.saveQuantitySample(
            type: .bodyMass,
            quantity: weightKg,
            unit: .gramUnit(with: .kilo),
            date: date
        )
        
        // 2. Save to progress tracking (local + backend sync)
        let localID = try await saveWeightProgressUseCase.execute(
            weightKg: weightKg, 
            date: date
        )
        
        print("SaveBodyMassUseCase: Saved weight to HealthKit and progress tracking. Local ID: \(localID)")
        
        // 3. Trigger HealthKit observer (if needed)
        healthRepository.onDataUpdate?(.bodyMass)
    }
}
```

#### Task 1.3: Register in AppDependencies

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`

```swift
// Add property
let saveWeightProgressUseCase: SaveWeightProgressUseCase

// In build()
let saveWeightProgressUseCase = SaveWeightProgressUseCaseImpl(
    progressRepository: progressRepository,
    authManager: authManager
)

// Update SaveBodyMassUseCase instantiation
let saveBodyMassUseCase = SaveBodyMassUseCase(
    healthRepository: healthRepository,
    userProfileStorage: userProfileStorageAdapter,
    authManager: authManager,
    saveWeightProgressUseCase: saveWeightProgressUseCase  // NEW
)
```

**Testing:**
- ✅ Enter weight in app
- ✅ Check HealthKit (should appear)
- ✅ Check local SwiftData (should appear)
- ✅ Check backend (should sync)
- ✅ Re-open app (should not duplicate)

---

### Phase 2: Historical Data Loading (HIGH PRIORITY)

#### Task 2.1: Create GetHistoricalWeightUseCase

**File:** `FitIQ/Domain/UseCases/GetHistoricalWeightUseCase.swift`

```swift
protocol GetHistoricalWeightUseCase {
    func execute(
        startDate: Date,
        endDate: Date
    ) async throws -> [ProgressEntry]
}

final class GetHistoricalWeightUseCaseImpl: GetHistoricalWeightUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let healthRepository: HealthRepositoryProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase
    
    func execute(startDate: Date, endDate: Date) async throws -> [ProgressEntry] {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetHistoricalWeightError.userNotAuthenticated
        }
        
        // 1. Try to get from local storage first
        let localEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .weight,
            syncStatus: nil
        )
        
        // Filter by date range
        let filteredLocal = localEntries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }
        
        // 2. If we have recent local data, return it
        if !filteredLocal.isEmpty {
            print("GetHistoricalWeightUseCase: Returning \(filteredLocal.count) local entries")
            return filteredLocal.sorted { $0.date < $1.date }
        }
        
        // 3. Otherwise, fetch from HealthKit
        print("GetHistoricalWeightUseCase: No local data, fetching from HealthKit...")
        
        let healthKitSamples = try await healthRepository.fetchBodyMassSamples(
            from: startDate,
            to: endDate
        )
        
        // 4. Save HealthKit samples to local storage (with deduplication)
        var progressEntries: [ProgressEntry] = []
        
        for sample in healthKitSamples {
            let weightKg = sample.quantity
            let date = sample.date
            
            // Save via use case (handles deduplication)
            let localID = try await saveWeightProgressUseCase.execute(
                weightKg: weightKg,
                date: date
            )
            
            // Fetch the saved entry
            let savedEntries = try await progressRepository.fetchLocal(
                forUserID: userID,
                type: .weight,
                syncStatus: nil
            )
            
            if let savedEntry = savedEntries.first(where: { $0.id == localID }) {
                progressEntries.append(savedEntry)
            }
        }
        
        print("GetHistoricalWeightUseCase: Imported \(progressEntries.count) entries from HealthKit")
        
        return progressEntries.sorted { $0.date < $1.date }
    }
}
```

**Key Features:**
- ✅ Check local first (fast)
- ✅ Fall back to HealthKit (slow)
- ✅ Save HealthKit data to local storage
- ✅ Auto-deduplication
- ✅ Auto-sync to backend

#### Task 2.2: Add Initial Sync on First Launch

**File:** `FitIQ/Domain/UseCases/PerformInitialHealthKitSyncUseCase.swift`

Update to include weight:

```swift
func execute() async throws {
    // ... existing code ...
    
    // Sync weight for last year
    print("PerformInitialHealthKitSync: Syncing weight history...")
    let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
    
    let weightEntries = try await getHistoricalWeightUseCase.execute(
        startDate: oneYearAgo,
        endDate: now
    )
    
    print("PerformInitialHealthKitSync: Synced \(weightEntries.count) weight entries")
}
```

---

### Phase 3: Real Data in Detail View (MEDIUM PRIORITY)

#### Task 3.1: Update BodyMassDetailViewModel

**File:** `FitIQ/Presentation/ViewModels/BodyMassDetailViewModel.swift`

Replace mock data with real data:

```swift
@Observable
final class BodyMassDetailViewModel {
    
    // Dependencies
    private let getHistoricalWeightUseCase: GetHistoricalWeightUseCase
    private let authManager: AuthManager
    
    // UI State
    enum TimeRange: String, CaseIterable, Identifiable {
        case last30Days = "30D"
        case last6Months = "6M"
        case lastYear = "1Y"
        var id: String { rawValue }
    }
    
    var historicalData: [WeightRecord] = []
    var isLoading: Bool = false
    var selectedRange: TimeRange = .last30Days
    var errorMessage: String?
    
    init(
        getHistoricalWeightUseCase: GetHistoricalWeightUseCase,
        authManager: AuthManager
    ) {
        self.getHistoricalWeightUseCase = getHistoricalWeightUseCase
        self.authManager = authManager
    }
    
    @MainActor
    func loadHistoricalData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let now = Date()
            let calendar = Calendar.current
            
            let startDate: Date
            switch selectedRange {
            case .last30Days:
                startDate = calendar.date(byAdding: .day, value: -30, to: now)!
            case .last6Months:
                startDate = calendar.date(byAdding: .month, value: -6, to: now)!
            case .lastYear:
                startDate = calendar.date(byAdding: .year, value: -1, to: now)!
            }
            
            let entries = try await getHistoricalWeightUseCase.execute(
                startDate: startDate,
                endDate: now
            )
            
            // Convert to WeightRecord for UI
            self.historicalData = entries.map { entry in
                WeightRecord(date: entry.date, weightKg: entry.quantity)
            }
            
            print("BodyMassDetailViewModel: Loaded \(historicalData.count) weight entries")
            
        } catch {
            self.errorMessage = "Failed to load historical data: \(error.localizedDescription)"
            print("BodyMassDetailViewModel: Error loading data: \(error)")
        }
        
        isLoading = false
    }
}
```

#### Task 3.2: Update ViewModelAppDependencies

**File:** `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`

```swift
let bodyMassDetailViewModel = BodyMassDetailViewModel(
    getHistoricalWeightUseCase: appDependencies.getHistoricalWeightUseCase,
    authManager: authManager
)
```

---

### Phase 4: Event-Driven UI Updates (MEDIUM PRIORITY)

#### Task 4.1: Create ProgressEventPublisher

**File:** `FitIQ/Domain/Events/ProgressEventPublisher.swift`

```swift
import Combine
import Foundation

enum ProgressEvent {
    case weightUpdated(weightKg: Double, date: Date)
    case stepsUpdated(steps: Int, date: Date)
    case heightUpdated(heightCm: Double, date: Date)
}

protocol ProgressEventPublisherProtocol {
    var publisher: AnyPublisher<ProgressEvent, Never> { get }
    func publish(event: ProgressEvent)
}

final class ProgressEventPublisher: ProgressEventPublisherProtocol {
    private let _publisher = PassthroughSubject<ProgressEvent, Never>()
    
    var publisher: AnyPublisher<ProgressEvent, Never> {
        _publisher.eraseToAnyPublisher()
    }
    
    func publish(event: ProgressEvent) {
        _publisher.send(event)
        print("ProgressEventPublisher: Published event: \(event)")
    }
}
```

#### Task 4.2: Update SaveWeightProgressUseCase to Publish Events

```swift
final class SaveWeightProgressUseCaseImpl: SaveWeightProgressUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    private let eventPublisher: ProgressEventPublisherProtocol  // NEW
    
    func execute(weightKg: Double, date: Date) async throws -> UUID {
        // ... existing save logic ...
        
        let localID = try await progressRepository.save(
            progressEntry: progressEntry, 
            forUserID: userID
        )
        
        // Publish event
        eventPublisher.publish(event: .weightUpdated(weightKg: weightKg, date: date))
        
        return localID
    }
}
```

#### Task 4.3: Subscribe to Events in ViewModels

**SummaryViewModel:**
```swift
private var cancellables = Set<AnyCancellable>()

init(
    ...,
    progressEventPublisher: ProgressEventPublisherProtocol
) {
    // ... existing init ...
    
    subscribeToProgressEvents(publisher: progressEventPublisher)
}

private func subscribeToProgressEvents(publisher: ProgressEventPublisherProtocol) {
    publisher.publisher
        .sink { [weak self] event in
            guard let self = self else { return }
            
            switch event {
            case .weightUpdated(let weightKg, let date):
                print("SummaryViewModel: Received weight update: \(weightKg)kg on \(date)")
                Task { @MainActor in
                    await self.loadData()  // Refresh data
                }
            default:
                break
            }
        }
        .store(in: &cancellables)
}
```

**BodyMassDetailViewModel:**
```swift
private func subscribeToProgressEvents(publisher: ProgressEventPublisherProtocol) {
    publisher.publisher
        .sink { [weak self] event in
            guard let self = self else { return }
            
            switch event {
            case .weightUpdated:
                print("BodyMassDetailViewModel: Received weight update")
                Task { @MainActor in
                    await self.loadHistoricalData()  // Refresh graph
                }
            default:
                break
            }
        }
        .store(in: &cancellables)
}
```

---

### Phase 5: HealthKit Observer for Automatic Updates (LOW PRIORITY)

#### Task 5.1: Update HealthDataSyncManager

**File:** `FitIQ/Infrastructure/HealthKit/HealthDataSyncManager.swift`

Add observer for body mass:

```swift
func startObserving(for userProfileID: UUID) {
    // ... existing observers ...
    
    // Observe body mass
    observeBodyMass(for: userProfileID)
}

private func observeBodyMass(for userProfileID: UUID) {
    guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
        return
    }
    
    let query = HKObserverQuery(sampleType: bodyMassType, predicate: nil) { [weak self] query, completionHandler, error in
        guard let self = self else { return }
        
        if let error = error {
            print("HealthDataSyncManager: Body mass observer error: \(error)")
            return
        }
        
        print("HealthDataSyncManager: Body mass data changed in HealthKit")
        
        // Process the update
        Task {
            await self.handleBodyMassUpdate(for: userProfileID)
        }
        
        completionHandler()
    }
    
    healthStore.execute(query)
}

private func handleBodyMassUpdate(for userProfileID: UUID) async {
    do {
        // Fetch latest weight from HealthKit
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        let samples = try await healthRepository.fetchBodyMassSamples(
            from: yesterday,
            to: now
        )
        
        guard let latestSample = samples.max(by: { $0.date < $1.date }) else {
            return
        }
        
        // Save via use case (handles deduplication)
        let localID = try await saveWeightProgressUseCase.execute(
            weightKg: latestSample.quantity,
            date: latestSample.date
        )
        
        print("HealthDataSyncManager: Saved weight from HealthKit: \(latestSample.quantity)kg, Local ID: \(localID)")
        
    } catch {
        print("HealthDataSyncManager: Error processing body mass update: \(error)")
    }
}
```

---

## UI Updates Required

### 1. SummaryView - Body Mass Card

**Current:**
- Shows static/mock data
- Mini line graph (last 7 entries)

**Updates:**
- ✅ Subscribe to `ProgressEventPublisher`
- ✅ Refresh on weight update events
- ✅ Fetch real data from `GetHistoricalWeightUseCase`
- ✅ Update card with latest weight
- ✅ Update mini graph with real historical data

### 2. BodyMassDetailView - Graph View

**Current:**
- Mock data
- Time range selector (30D, 6M, 1Y)

**Updates:**
- ✅ Use `BodyMassDetailViewModel` with real data
- ✅ Subscribe to events for live updates
- ✅ Show loading state
- ✅ Show error state
- ✅ Rich graph with real data points

**Graph Features:**
- Line chart with data points
- Y-axis: Weight (kg)
- X-axis: Date
- Zoom/pan gestures
- Data point labels on tap
- Trend line (optional)
- Min/max indicators
- Average line (optional)

---

## Testing Plan

### Manual Testing

#### Test 1: Save Weight (Manual Entry)
```
1. Open app → Tap weight card
2. Enter weight: 75.5 kg
3. Save
4. ✅ Should appear in HealthKit
5. ✅ Should appear in local storage
6. ✅ Should sync to backend
7. ✅ Should update Summary view
8. ✅ Should update Detail view
```

#### Test 2: Deduplication
```
1. Enter weight: 75.5 kg
2. Save
3. Re-open entry form
4. Enter same weight: 75.5 kg
5. Save
6. ✅ Should NOT create duplicate
7. ✅ Should return existing entry
8. ✅ Should NOT sync again
```

#### Test 3: Update Weight
```
1. Enter weight: 75.5 kg
2. Save
3. Re-open entry form
4. Enter new weight: 76.0 kg
5. Save
6. ✅ Should update existing entry
7. ✅ Should trigger re-sync to backend
8. ✅ Should update all views
```

#### Test 4: Historical Load
```
1. Add weight entries in Health app (past dates)
2. Open FitIQ app
3. Navigate to Body Mass Detail view
4. ✅ Should load historical data from HealthKit
5. ✅ Should save to local storage
6. ✅ Should sync to backend
7. ✅ Should display in graph
```

#### Test 5: HealthKit Observer
```
1. Open FitIQ app
2. Add weight in Health app
3. Return to FitIQ app
4. ✅ Should auto-update Summary view
5. ✅ Should auto-update Detail view
6. ✅ Should sync to backend
```

#### Test 6: Time Range Filtering
```
1. Open Detail view
2. Select "30D"
3. ✅ Should show last 30 days
4. Select "6M"
5. ✅ Should show last 6 months
6. Select "1Y"
7. ✅ Should show last year
```

### Automated Testing

```swift
// Test deduplication
func testSaveWeightProgressDeduplication() async throws {
    // Given: Existing entry
    let existingEntry = ProgressEntry(
        id: UUID(),
        userID: "user-123",
        type: .weight,
        quantity: 75.5,
        date: Date(),
        ...
    )
    try await repository.save(progressEntry: existingEntry, forUserID: "user-123")
    
    // When: Save same weight again
    let resultID = try await useCase.execute(weightKg: 75.5, date: Date())
    
    // Then: Should return existing ID
    XCTAssertEqual(resultID, existingEntry.id)
    XCTAssertEqual(repository.saveCallCount, 1)  // No second save
}

// Test update
func testSaveWeightProgressUpdate() async throws {
    // Given: Existing entry
    let existingEntry = ProgressEntry(
        id: UUID(),
        userID: "user-123",
        type: .weight,
        quantity: 75.5,
        date: Date(),
        ...
    )
    try await repository.save(progressEntry: existingEntry, forUserID: "user-123")
    
    // When: Save different weight
    let resultID = try await useCase.execute(weightKg: 76.0, date: Date())
    
    // Then: Should update entry
    XCTAssertEqual(resultID, existingEntry.id)
    XCTAssertEqual(repository.saveCallCount, 2)  // Initial + update
    
    let updatedEntry = try await repository.fetchLocal(...).first
    XCTAssertEqual(updatedEntry.quantity, 76.0)
    XCTAssertEqual(updatedEntry.syncStatus, .pending)
}

// Test historical load
func testGetHistoricalWeightFromHealthKit() async throws {
    // Given: Empty local storage
    // When: Execute use case
    let entries = try await useCase.execute(
        startDate: oneYearAgo,
        endDate: Date()
    )
    
    // Then: Should return HealthKit data
    XCTAssertFalse(entries.isEmpty)
    XCTAssertTrue(entries.allSatisfy { $0.type == .weight })
}
```

---

## Implementation Order (Priority)

### Sprint 1 (High Priority - Core Functionality)
1. ✅ Create `SaveWeightProgressUseCase` with deduplication
2. ✅ Update `SaveBodyMassUseCase` to use progress tracking
3. ✅ Register in `AppDependencies`
4. ✅ Test manual entry flow
5. ✅ Test deduplication
6. ✅ Verify backend sync

### Sprint 2 (High Priority - Historical Data)
1. ✅ Create `GetHistoricalWeightUseCase`
2. ✅ Update `PerformInitialHealthKitSyncUseCase`
3. ✅ Test historical data loading
4. ✅ Verify 1-year sync on first launch

### Sprint 3 (Medium Priority - Real UI)
1. ✅ Update `BodyMassDetailViewModel` with real data
2. ✅ Register in `ViewModelAppDependencies`
3. ✅ Test detail view with real data
4. ✅ Verify time range filtering

### Sprint 4 (Medium Priority - Events)
1. ✅ Create `ProgressEventPublisher`
2. ✅ Update use cases to publish events
3. ✅ Subscribe in `SummaryViewModel`
4. ✅ Subscribe in `BodyMassDetailViewModel`
5. ✅ Test live updates

### Sprint 5 (Low Priority - HealthKit Observer)
1. ✅ Update `HealthDataSyncManager` with body mass observer
2. ✅ Test automatic updates from Health app
3. ✅ Verify deduplication works with observer

---

## Files to Create/Modify

### New Files
- ✅ `FitIQ/Domain/UseCases/SaveWeightProgressUseCase.swift`
- ✅ `FitIQ/Domain/UseCases/GetHistoricalWeightUseCase.swift`
- ✅ `FitIQ/Domain/Events/ProgressEventPublisher.swift`
- ✅ `FitIQ/Domain/Events/ProgressEvent.swift`

### Modified Files
- ✅ `FitIQ/Presentation/UI/Summary/SaveBodyMassUseCase.swift`
- ✅ `FitIQ/Presentation/ViewModels/BodyMassDetailViewModel.swift`
- ✅ `FitIQ/Infrastructure/Configuration/AppDependencies.swift`
- ✅ `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`
- ✅ `FitIQ/Domain/UseCases/PerformInitialHealthKitSyncUseCase.swift`
- ✅ `FitIQ/Infrastructure/HealthKit/HealthDataSyncManager.swift`
- ✅ `FitIQ/Presentation/ViewModels/SummaryViewModel.swift`
- ⚠️ `FitIQ/Presentation/UI/Summary/BodyMassEntryView.swift` (minimal - just callback)
- ⚠️ `FitIQ/Presentation/UI/Summary/SummaryView.swift` (minimal - refresh)

---

## Success Criteria

### Functional
- ✅ Weight saved to HealthKit, local, and backend
- ✅ No duplicate entries
- ✅ Historical data loaded from HealthKit (1 year)
- ✅ Real data in all views
- ✅ Live updates when data changes
- ✅ Automatic sync from Health app changes

### Non-Functional
- ✅ Fast UI updates (< 1s)
- ✅ No duplicate backend API calls
- ✅ Proper error handling
- ✅ Loading states
- ✅ Consistent with existing patterns (steps)

---

## Notes

1. **Reuse Patterns:** Follow the exact same patterns as `SaveStepsProgressUseCase`
2. **Deduplication:** Critical - must check before saving
3. **Events:** Enable reactive UI updates
4. **HealthKit Observer:** Nice-to-have, not critical for MVP
5. **Graph Library:** Consider using Swift Charts for iOS 16+ or custom implementation

---

**Status:** Ready for implementation  
**Estimated Effort:** 2-3 days (all phases)  
**Dependencies:** None (all fixes from today are complete)