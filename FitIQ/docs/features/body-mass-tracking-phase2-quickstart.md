# Body Mass Tracking - Phase 2 Quick Start Guide

**Phase:** 2 - Historical Data Loading (HIGH PRIORITY)  
**Estimated Time:** 2-3 hours  
**Date:** 2025-01-27

---

## 🎯 Goal

Replace mock data in the weight detail view with real historical data from backend API, with HealthKit fallback.

---

## 📋 What You'll Build

### GetHistoricalWeightUseCase
- Fetches weight history from backend API (primary source)
- Falls back to HealthKit if backend data missing
- Syncs HealthKit data to backend automatically
- Returns sorted list of weight entries

### Updated BodyMassDetailViewModel
- Loads real historical data
- Displays weight chart with actual data
- Supports time range filtering (7d, 30d, 90d, 1y, All)

---

## 🚀 Implementation Steps

### Step 1: Create GetHistoricalWeightUseCase (30 min)

**File:** `FitIQ/Domain/UseCases/GetHistoricalWeightUseCase.swift`

```swift
//
//  GetHistoricalWeightUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Protocol for fetching historical weight data
protocol GetHistoricalWeightUseCase {
    /// Fetches weight entries for a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Array of progress entries sorted by date (newest first)
    func execute(startDate: Date, endDate: Date) async throws -> [ProgressEntry]
}

/// Implementation following existing patterns
final class GetHistoricalWeightUseCaseImpl: GetHistoricalWeightUseCase {
    
    // MARK: - Dependencies
    
    private let progressRepository: ProgressRepositoryProtocol
    private let healthRepository: HealthRepositoryProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase
    
    // MARK: - Initialization
    
    init(
        progressRepository: ProgressRepositoryProtocol,
        healthRepository: HealthRepositoryProtocol,
        authManager: AuthManager,
        saveWeightProgressUseCase: SaveWeightProgressUseCase
    ) {
        self.progressRepository = progressRepository
        self.healthRepository = healthRepository
        self.authManager = authManager
        self.saveWeightProgressUseCase = saveWeightProgressUseCase
    }
    
    // MARK: - Execute
    
    func execute(startDate: Date, endDate: Date) async throws -> [ProgressEntry] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetHistoricalWeightError.userNotAuthenticated
        }
        
        print("GetHistoricalWeightUseCase: Fetching weight for user \(userID) from \(startDate) to \(endDate)")
        
        // 1. Try to fetch from backend first (primary source)
        do {
            let backendEntries = try await progressRepository.fetchRemote(
                forUserID: userID,
                type: .weight,
                startDate: startDate,
                endDate: endDate
            )
            
            if !backendEntries.isEmpty {
                print("GetHistoricalWeightUseCase: Found \(backendEntries.count) entries from backend")
                return backendEntries.sorted { $0.date > $1.date }
            }
            
            print("GetHistoricalWeightUseCase: No backend data found, falling back to HealthKit")
        } catch {
            print("GetHistoricalWeightUseCase: Backend fetch failed: \(error.localizedDescription), falling back to HealthKit")
        }
        
        // 2. Fallback to HealthKit if backend data missing or error
        do {
            let healthKitSamples = try await healthRepository.fetchBodyMassSamples(
                from: startDate,
                to: endDate
            )
            
            guard !healthKitSamples.isEmpty else {
                print("GetHistoricalWeightUseCase: No data found in HealthKit either")
                return []
            }
            
            print("GetHistoricalWeightUseCase: Found \(healthKitSamples.count) samples from HealthKit, syncing to backend")
            
            // 3. Sync HealthKit data to backend (background)
            var syncedEntries: [ProgressEntry] = []
            
            for sample in healthKitSamples {
                do {
                    let localID = try await saveWeightProgressUseCase.execute(
                        weightKg: sample.quantity,
                        date: sample.date
                    )
                    
                    // Fetch the saved entry to return it
                    if let entry = try? await progressRepository.fetchLocal(
                        forUserID: userID,
                        type: .weight,
                        syncStatus: nil
                    ).first(where: { $0.id == localID }) {
                        syncedEntries.append(entry)
                    }
                } catch {
                    print("GetHistoricalWeightUseCase: Failed to sync sample: \(error.localizedDescription)")
                    // Continue with other samples
                }
            }
            
            return syncedEntries.sorted { $0.date > $1.date }
            
        } catch {
            print("GetHistoricalWeightUseCase: HealthKit fetch failed: \(error.localizedDescription)")
            throw GetHistoricalWeightError.healthKitFetchFailed(error)
        }
    }
}

// MARK: - Errors

enum GetHistoricalWeightError: Error, LocalizedError {
    case userNotAuthenticated
    case healthKitFetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch weight history"
        case .healthKitFetchFailed(let error):
            return "Failed to fetch weight from HealthKit: \(error.localizedDescription)"
        }
    }
}
```

---

### Step 2: Register in AppDependencies (10 min)

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`

#### 2.1: Add Property (around line 65)
```swift
let saveWeightProgressUseCase: SaveWeightProgressUseCase
let getHistoricalWeightUseCase: GetHistoricalWeightUseCase  // ADD THIS
```

#### 2.2: Add to Init Parameter (around line 115)
```swift
saveWeightProgressUseCase: SaveWeightProgressUseCase,
getHistoricalWeightUseCase: GetHistoricalWeightUseCase,  // ADD THIS
syncBiologicalSexFromHealthKitUseCase: SyncBiologicalSexFromHealthKitUseCase
```

#### 2.3: Add Assignment (around line 160)
```swift
self.saveWeightProgressUseCase = saveWeightProgressUseCase
self.getHistoricalWeightUseCase = getHistoricalWeightUseCase  // ADD THIS
self.syncBiologicalSexFromHealthKitUseCase = syncBiologicalSexFromHealthKitUseCase
```

#### 2.4: Create Instance in build() (after saveWeightProgressUseCase, around line 295)
```swift
// NEW: Save Weight Progress Use Case
let saveWeightProgressUseCase = SaveWeightProgressUseCaseImpl(
    progressRepository: progressRepository,
    authManager: authManager
)

// NEW: Get Historical Weight Use Case
let getHistoricalWeightUseCase = GetHistoricalWeightUseCaseImpl(
    progressRepository: progressRepository,
    healthRepository: healthRepository,
    authManager: authManager,
    saveWeightProgressUseCase: saveWeightProgressUseCase
)
```

#### 2.5: Pass to Init (around line 430)
```swift
saveWeightProgressUseCase: saveWeightProgressUseCase,
getHistoricalWeightUseCase: getHistoricalWeightUseCase,  // ADD THIS
syncBiologicalSexFromHealthKitUseCase: syncBiologicalSexFromHealthKitUseCase
```

---

### Step 3: Update BodyMassDetailViewModel (45 min)

**File:** `FitIQ/Presentation/ViewModels/BodyMassDetailViewModel.swift`

Find the existing ViewModel and update it:

```swift
import Foundation
import Observation
import Combine

@Observable
final class BodyMassDetailViewModel {
    
    // MARK: - Dependencies
    
    private let getHistoricalWeightUseCase: GetHistoricalWeightUseCase
    private let authManager: AuthManager
    
    // MARK: - Time Range
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7d"
        case month = "30d"
        case quarter = "90d"
        case year = "1y"
        case all = "All"
        
        var id: String { rawValue }
    }
    
    // MARK: - State
    
    var historicalData: [WeightRecord] = []
    var isLoading: Bool = false
    var selectedRange: TimeRange = .month
    var errorMessage: String?
    
    // MARK: - Initialization
    
    init(
        getHistoricalWeightUseCase: GetHistoricalWeightUseCase,
        authManager: AuthManager
    ) {
        self.getHistoricalWeightUseCase = getHistoricalWeightUseCase
        self.authManager = authManager
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadHistoricalData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate date range based on selected range
            let endDate = Date()
            let startDate = calculateStartDate(for: selectedRange, from: endDate)
            
            print("BodyMassDetailViewModel: Loading weight data from \(startDate) to \(endDate)")
            
            // Fetch historical weight
            let entries = try await getHistoricalWeightUseCase.execute(
                startDate: startDate,
                endDate: endDate
            )
            
            // Convert to WeightRecord for UI
            historicalData = entries.map { entry in
                WeightRecord(
                    date: entry.date,
                    weightKg: entry.quantity
                )
            }
            
            print("BodyMassDetailViewModel: Loaded \(historicalData.count) weight records")
            
        } catch {
            errorMessage = error.localizedDescription
            print("BodyMassDetailViewModel: Failed to load weight data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func onRangeChanged(_ newRange: TimeRange) {
        selectedRange = newRange
        Task {
            await loadHistoricalData()
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateStartDate(for range: TimeRange, from endDate: Date) -> Date {
        let calendar = Calendar.current
        
        switch range {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        case .quarter:
            return calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            // Go back 5 years for "all"
            return calendar.date(byAdding: .year, value: -5, to: endDate) ?? endDate
        }
    }
}

// MARK: - WeightRecord

struct WeightRecord: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}
```

---

### Step 4: Update ViewModelAppDependencies (10 min)

**File:** `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`

Find the section where ViewModels are created (around line 90) and add:

```swift
// NEW: Body Mass Detail ViewModel
let bodyMassDetailViewModel = BodyMassDetailViewModel(
    getHistoricalWeightUseCase: appDependencies.getHistoricalWeightUseCase,
    authManager: authManager
)
```

Add property to class:
```swift
let bodyMassDetailViewModel: BodyMassDetailViewModel
```

Add to init:
```swift
self.bodyMassDetailViewModel = bodyMassDetailViewModel
```

Add to return statement:
```swift
return ViewModelAppDependencies(
    // ... existing
    bodyMassDetailViewModel: bodyMassDetailViewModel
)
```

---

### Step 5: Update Initial Sync (Optional but Recommended) (15 min)

**File:** `FitIQ/Domain/UseCases/PerformInitialHealthKitSyncUseCase.swift`

Add weight sync to the `execute()` method:

```swift
// Sync historical weight from last 90 days
print("PerformInitialHealthKitSyncUseCase: Syncing historical weight from last 90 days")

let weightEndDate = Date()
let weightStartDate = calendar.date(byAdding: .day, value: -90, to: weightEndDate)!

do {
    let weightSamples = try await healthRepository.fetchBodyMassSamples(
        from: weightStartDate,
        to: weightEndDate
    )
    
    print("PerformInitialHealthKitSyncUseCase: Found \(weightSamples.count) weight samples to sync")
    
    for sample in weightSamples {
        do {
            _ = try await saveWeightProgressUseCase.execute(
                weightKg: sample.quantity,
                date: sample.date
            )
        } catch {
            print("PerformInitialHealthKitSyncUseCase: Failed to sync weight sample: \(error)")
            // Continue with other samples
        }
    }
    
    print("PerformInitialHealthKitSyncUseCase: Weight sync complete")
} catch {
    print("PerformInitialHealthKitSyncUseCase: Failed to fetch weight from HealthKit: \(error)")
    // Don't throw, continue with other syncs
}
```

Add dependency:
```swift
private let saveWeightProgressUseCase: SaveWeightProgressUseCase

init(
    // ... existing params
    saveWeightProgressUseCase: SaveWeightProgressUseCase
) {
    // ... existing assignments
    self.saveWeightProgressUseCase = saveWeightProgressUseCase
}
```

Update AppDependencies to inject it (around line 255):
```swift
let performInitialHealthKitSyncUseCase = PerformInitialHealthKitSyncUseCase(
    healthKitAuthorizationUseCase: healthKitAuthorizationUseCase,
    healthRepository: healthRepository,
    authManager: authManager,
    saveWeightProgressUseCase: saveWeightProgressUseCase  // ADD THIS
)
```

---

## ✅ Testing Checklist

### Manual Testing

1. **Empty State**
   - [ ] Fresh install → no weight data
   - [ ] Detail view shows empty state
   - [ ] No errors displayed

2. **Manual Entry**
   - [ ] Enter weight manually
   - [ ] Save weight
   - [ ] Navigate to detail view
   - [ ] Weight appears in chart
   - [ ] Weight appears in list

3. **Time Range Filtering**
   - [ ] Switch to 7d → shows last week
   - [ ] Switch to 30d → shows last month
   - [ ] Switch to 90d → shows last quarter
   - [ ] Switch to 1y → shows last year
   - [ ] Switch to All → shows all data

4. **Historical Sync**
   - [ ] Add weight in Apple Health app
   - [ ] Force initial sync (or restart app)
   - [ ] Weight from Health app appears in FitIQ

5. **Backend Sync**
   - [ ] Enter weight
   - [ ] Check backend (via API or web)
   - [ ] Weight synced to backend
   - [ ] Refresh detail view
   - [ ] Data loads from backend

6. **Offline Mode**
   - [ ] Turn off network
   - [ ] Enter weight
   - [ ] Weight saved locally
   - [ ] Turn on network
   - [ ] Weight syncs to backend

---

## 🐛 Common Issues & Solutions

### Issue: "Cannot find type 'GetHistoricalWeightUseCase'"
**Solution:** Make sure the protocol and class are in the same file, and the file is added to the Xcode project target.

### Issue: "No weight data showing in detail view"
**Solution:** 
1. Check if `loadHistoricalData()` is called in view's `onAppear`
2. Check console logs for errors
3. Verify backend API is returning data

### Issue: "Weight not syncing to backend"
**Solution:**
1. Check `RemoteSyncService` is running
2. Check network connectivity
3. Verify API token is valid
4. Check for entries with `syncStatus: .pending` in local storage

### Issue: "Duplicate weights appearing"
**Solution:** Deduplication should handle this. If not:
1. Check `SaveWeightProgressUseCase` logic
2. Verify dates are normalized to start of day
3. Check floating-point comparison tolerance

---

## 📊 Expected Results

### After Implementation

1. **Detail View Shows Real Data**
   - Weight chart displays actual weight entries
   - List view shows all weight records
   - Time range filtering works

2. **Backend Sync Works**
   - Weights saved locally sync to backend
   - Backend weights load on app launch
   - Deduplication prevents duplicates

3. **HealthKit Integration**
   - Initial sync loads last 90 days
   - Manual entries go to HealthKit and backend
   - HealthKit changes eventually sync to backend

---

## 🎯 Success Criteria

- [ ] GetHistoricalWeightUseCase created and registered
- [ ] BodyMassDetailViewModel updated with real data loading
- [ ] ViewModelAppDependencies wired correctly
- [ ] Initial sync loads historical weight
- [ ] Detail view shows real weight chart
- [ ] Time range filtering works
- [ ] Backend sync confirmed working
- [ ] HealthKit fallback tested
- [ ] Documentation updated

---

## 📝 Next Steps After Phase 2

### Phase 3: UI Polish
- Improve chart styling
- Add loading indicators
- Better empty states
- Pull-to-refresh

### Phase 4: Event-Driven Updates
- Create ProgressEventPublisher
- Real-time UI updates
- Subscribe to weight events

### Phase 5: HealthKit Observer
- Automatic background sync
- Observer query for weight changes
- No manual refresh needed

---

**Estimated Total Time:** 2-3 hours  
**Priority:** HIGH  
**Complexity:** Medium

**Ready to code!** 🚀 Follow the steps above and refer to Phase 1 code for patterns.