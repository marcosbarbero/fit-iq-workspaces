# Summary Data Loading Pattern

**Version:** 1.0.0  
**Created:** 2025-01-27  
**Status:** ✅ Active Pattern  
**Architecture Layer:** Domain → Infrastructure → Presentation

---

## 🎯 Problem Statement

### The Challenge

When displaying summary cards on the main `SummaryView`, we need lightweight, summary-specific data that loads immediately. However, we were facing these issues:

1. **Lazy Loading Problem**: Data only loaded when detail views were opened
2. **Tight Coupling**: Summary cards depended on detail ViewModels
3. **Performance Issues**: Each card required its own ViewModel with full data loading
4. **Inconsistent State**: Multiple sources of truth for the same data
5. **Poor Scalability**: Adding new cards meant more ViewModels and dependencies

### Example of the Problem

```swift
// ❌ WRONG APPROACH - Summary card using detail ViewModel
struct SummaryView: View {
    let heartRateDetailViewModel: HeartRateDetailViewModel
    
    var body: some View {
        NavigationLink(value: "heartRateDetail") {
            FullWidthHeartRateStatCard(
                latestHeartRate: viewModel.formattedLatestHeartRate,
                hourlyData: heartRateDetailViewModel.last8HoursData  // ❌ Not loaded until detail view opens!
            )
        }
    }
}
```

**Issues:**
- `heartRateDetailViewModel.last8HoursData` is empty until `HeartRateDetailView.onAppear()` is called
- Summary card shows empty graph until user navigates to detail view
- Unnecessary dependency on detail-specific ViewModel
- Violates Single Responsibility Principle

---

## ✅ Solution: Summary-Specific Use Cases

### Architecture Pattern

We implement **dedicated, lightweight use cases** that fetch ONLY the data needed for summary cards:

```
┌─────────────────────────────────────────────────────────────────┐
│                         SummaryView                              │
│  (Displays summary cards with lightweight data)                 │
└───────────────────────────────┬─────────────────────────────────┘
                                │ uses
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SummaryViewModel                            │
│  - Orchestrates ALL summary data loading                        │
│  - Single source of truth for summary data                      │
│  - Loads data on .onAppear of SummaryView                       │
└───────────────────────────────┬─────────────────────────────────┘
                                │ uses
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│            Summary-Specific Use Cases (Domain Layer)             │
│  - GetLast8HoursHeartRateUseCase                                │
│  - GetLast8HoursStepsUseCase                                    │
│  - GetHistoricalWeightUseCase                                   │
│  - GetLatestMoodUseCase                                         │
│  (Each fetches ONLY what's needed for its summary card)         │
└───────────────────────────────┬─────────────────────────────────┘
                                │ uses
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│               Repository (Infrastructure Layer)                  │
│  - ProgressRepositoryProtocol                                   │
│  - HealthRepositoryProtocol                                     │
│  (Fetches data from SwiftData local storage)                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Implementation Structure

### 1. Use Cases (Domain Layer)

Location: `Domain/UseCases/Summary/`

**Purpose**: Define lightweight, summary-specific data fetching operations

```
Domain/UseCases/Summary/
├── GetLast8HoursHeartRateUseCase.swift
├── GetLast8HoursStepsUseCase.swift
└── (future: GetDailySleepSummaryUseCase.swift, etc.)
```

### 2. ViewModel Integration (Presentation Layer)

**SummaryViewModel** owns and loads ALL summary data:

```swift
@Observable
final class SummaryViewModel {
    // SUMMARY-SPECIFIC: Use cases for fetching only the data needed for summary cards
    private let getLast8HoursHeartRateUseCase: GetLast8HoursHeartRateUseCase
    private let getLast8HoursStepsUseCase: GetLast8HoursStepsUseCase
    
    // SUMMARY-SPECIFIC: Hourly data for summary cards
    var last8HoursHeartRateData: [(hour: Int, heartRate: Int)] = []
    var last8HoursStepsData: [(hour: Int, steps: Int)] = []
    
    func reloadAllData() async {
        await fetchLast8HoursHeartRate()
        await fetchLast8HoursSteps()
        // ... other summary data
    }
}
```

### 3. View Usage (Presentation Layer)

**SummaryView** uses data directly from `SummaryViewModel`:

```swift
struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    
    var body: some View {
        NavigationLink(value: "heartRateDetail") {
            FullWidthHeartRateStatCard(
                latestHeartRate: viewModel.formattedLatestHeartRate,
                hourlyData: viewModel.last8HoursHeartRateData  // ✅ Loaded immediately!
            )
        }
    }
}
```

---

## 🔨 How to Add a New Summary Card

Follow this step-by-step guide to add a new card with summary-specific data:

### Step 1: Create Summary-Specific Use Case

**File**: `Domain/UseCases/Summary/GetLast8HoursSleepUseCase.swift`

```swift
import Foundation

// MARK: - Protocol (Port)

/// Use case for fetching the last 8 hours of sleep data for summary display
protocol GetLast8HoursSleepUseCase {
    func execute() async throws -> [(hour: Int, sleepMinutes: Int)]
}

// MARK: - Implementation

final class GetLast8HoursSleepUseCaseImpl: GetLast8HoursSleepUseCase {
    
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }
    
    func execute() async throws -> [(hour: Int, sleepMinutes: Int)] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLast8HoursSleepError.userNotAuthenticated
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Fetch sleep entries from local storage
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .sleepHours,
            syncStatus: nil
        )
        
        // Filter to last 8 hours
        let last8HoursStart = calendar.date(byAdding: .hour, value: -7, to: now)!
        let recentEntries = allEntries.filter { entry in
            entry.date >= last8HoursStart && entry.time != nil
        }
        
        // Process and aggregate data...
        // Return lightweight summary data
        
        return result
    }
}

enum GetLast8HoursSleepError: Error, LocalizedError {
    case userNotAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        }
    }
}
```

### Step 2: Register in AppDependencies

**File**: `Infrastructure/Configuration/AppDependencies.swift`

```swift
final class AppDependencies {
    // Add property
    let getLast8HoursSleepUseCase: GetLast8HoursSleepUseCase
    
    init(
        // ... other params
        getLast8HoursSleepUseCase: GetLast8HoursSleepUseCase
    ) {
        // ... other assignments
        self.getLast8HoursSleepUseCase = getLast8HoursSleepUseCase
    }
    
    static func build(authManager: AuthManager) -> AppDependencies {
        // Instantiate use case
        let getLast8HoursSleepUseCase = GetLast8HoursSleepUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )
        
        return AppDependencies(
            // ... other params
            getLast8HoursSleepUseCase: getLast8HoursSleepUseCase
        )
    }
}
```

### Step 3: Add to SummaryViewModel

**File**: `Presentation/ViewModels/SummaryViewModel.swift`

```swift
@Observable
final class SummaryViewModel {
    // Add use case dependency
    private let getLast8HoursSleepUseCase: GetLast8HoursSleepUseCase
    
    // Add data property
    var last8HoursSleepData: [(hour: Int, sleepMinutes: Int)] = []
    
    init(
        // ... other params
        getLast8HoursSleepUseCase: GetLast8HoursSleepUseCase
    ) {
        // ... other assignments
        self.getLast8HoursSleepUseCase = getLast8HoursSleepUseCase
    }
    
    func reloadAllData() async {
        // ... other data loading
        await fetchLast8HoursSleep()
    }
    
    @MainActor
    private func fetchLast8HoursSleep() async {
        do {
            last8HoursSleepData = try await getLast8HoursSleepUseCase.execute()
            print("SummaryViewModel: ✅ Fetched \(last8HoursSleepData.count) hours of sleep data")
        } catch {
            print("SummaryViewModel: ❌ Error fetching sleep data - \(error.localizedDescription)")
            last8HoursSleepData = []
        }
    }
}
```

### Step 4: Update ViewModelAppDependencies

**File**: `Infrastructure/Configuration/ViewModelAppDependencies.swift`

```swift
static func build(authManager: AuthManager, appDependencies: AppDependencies) -> ViewModelAppDependencies {
    let summaryViewModel = SummaryViewModel(
        // ... other params
        getLast8HoursSleepUseCase: appDependencies.getLast8HoursSleepUseCase
    )
    
    // ... rest of initialization
}
```

### Step 5: Use in SummaryView

**File**: `Presentation/UI/Summary/SummaryView.swift`

```swift
struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    
    var body: some View {
        NavigationLink(value: "sleepDetail") {
            FullWidthSleepStatCard(
                latestSleepHours: viewModel.formattedLatestSleep,
                hourlyData: viewModel.last8HoursSleepData  // ✅ Summary-specific data!
            )
        }
    }
}
```

---

## ✅ Pattern Benefits

### 1. **Immediate Data Loading**
- Summary data loads on `SummaryView.onAppear()`
- No waiting for detail views to open
- Better user experience

### 2. **Single Source of Truth**
- `SummaryViewModel` owns all summary data
- No confusion about where data comes from
- Easier to debug and maintain

### 3. **Performance & Scalability**
- Each use case fetches ONLY what's needed
- Lightweight queries (e.g., last 8 hours vs. full historical data)
- Adding new cards doesn't add complexity

### 4. **Clean Architecture**
- Follows Hexagonal Architecture principles
- Domain defines ports (use case protocols)
- Infrastructure implements adapters
- Presentation depends only on domain abstractions

### 5. **Separation of Concerns**
- **SummaryViewModel**: Orchestrates summary-specific data
- **DetailViewModels**: Handle detail-specific data and interactions
- **Use Cases**: Encapsulate single data-fetching responsibilities

### 6. **Testability**
- Easy to mock use cases for testing
- Can test SummaryViewModel in isolation
- Can test each use case independently

---

## 📊 Example: Heart Rate Implementation

### Use Case (Domain Layer)

```swift
// Domain/UseCases/Summary/GetLast8HoursHeartRateUseCase.swift

protocol GetLast8HoursHeartRateUseCase {
    func execute() async throws -> [(hour: Int, heartRate: Int)]
}

final class GetLast8HoursHeartRateUseCaseImpl: GetLast8HoursHeartRateUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }
    
    func execute() async throws -> [(hour: Int, heartRate: Int)] {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLast8HoursHeartRateError.userNotAuthenticated
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        
        // Fetch from local storage
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .restingHeartRate,
            syncStatus: nil
        )
        
        // Filter to last 8 hours
        let last8HoursStart = calendar.date(byAdding: .hour, value: -7, to: now)!
        let recentEntries = allEntries.filter { entry in
            entry.date >= last8HoursStart && entry.time != nil
        }
        
        // Group by hour and calculate averages
        var hourlyData: [Int: [Double]] = [:]
        for entry in recentEntries {
            let hour = calendar.component(.hour, from: entry.date)
            hourlyData[hour, default: []].append(entry.quantity)
        }
        
        // Build result array for last 8 hours
        var result: [(hour: Int, heartRate: Int)] = []
        for i in 0..<8 {
            let hour = (currentHour - 7 + i + 24) % 24
            
            if let values = hourlyData[hour], !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                result.append((hour: hour, heartRate: Int(avg)))
            } else {
                result.append((hour: hour, heartRate: 0))
            }
        }
        
        return result
    }
}
```

### ViewModel Integration

```swift
// Presentation/ViewModels/SummaryViewModel.swift

@Observable
final class SummaryViewModel {
    private let getLast8HoursHeartRateUseCase: GetLast8HoursHeartRateUseCase
    
    var last8HoursHeartRateData: [(hour: Int, heartRate: Int)] = []
    
    func reloadAllData() async {
        await fetchLast8HoursHeartRate()
    }
    
    @MainActor
    private func fetchLast8HoursHeartRate() async {
        do {
            last8HoursHeartRateData = try await getLast8HoursHeartRateUseCase.execute()
            print("SummaryViewModel: ✅ Fetched \(last8HoursHeartRateData.count) hours of heart rate data")
        } catch {
            print("SummaryViewModel: ❌ Error fetching hourly heart rate data - \(error.localizedDescription)")
            last8HoursHeartRateData = []
        }
    }
}
```

### View Usage

```swift
// Presentation/UI/Summary/SummaryView.swift

struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    
    var body: some View {
        NavigationLink(value: "heartRateDetail") {
            FullWidthHeartRateStatCard(
                latestHeartRate: viewModel.formattedLatestHeartRate,
                lastRecordedTime: viewModel.lastHeartRateRecordedTime,
                hourlyData: viewModel.last8HoursHeartRateData  // ✅ Loaded immediately!
            )
        }
    }
}
```

---

## 🧪 Testing Pattern

### Test Use Case

```swift
import XCTest
@testable import FitIQ

final class GetLast8HoursHeartRateUseCaseTests: XCTestCase {
    var sut: GetLast8HoursHeartRateUseCase!
    var mockRepository: MockProgressRepository!
    var mockAuthManager: MockAuthManager!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockProgressRepository()
        mockAuthManager = MockAuthManager()
        sut = GetLast8HoursHeartRateUseCaseImpl(
            progressRepository: mockRepository,
            authManager: mockAuthManager
        )
    }
    
    func testExecute_ReturnsLast8Hours() async throws {
        // Arrange
        mockAuthManager.currentUserProfileID = UUID()
        mockRepository.mockEntries = createMockHeartRateEntries()
        
        // Act
        let result = try await sut.execute()
        
        // Assert
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(mockRepository.fetchLocalCallCount, 1)
    }
    
    func testExecute_UserNotAuthenticated_ThrowsError() async {
        // Arrange
        mockAuthManager.currentUserProfileID = nil
        
        // Act & Assert
        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch let error as GetLast8HoursHeartRateError {
            XCTAssertEqual(error, .userNotAuthenticated)
        }
    }
}
```

---

## 📝 Naming Conventions

### Use Case Files
- Pattern: `Get{TimeRange}{MetricName}UseCase.swift`
- Examples:
  - `GetLast8HoursHeartRateUseCase.swift`
  - `GetLast8HoursStepsUseCase.swift`
  - `GetDailySleepSummaryUseCase.swift`

### Use Case Protocols
- Pattern: `Get{TimeRange}{MetricName}UseCase`
- Examples:
  - `GetLast8HoursHeartRateUseCase`
  - `GetLast8HoursStepsUseCase`

### Use Case Implementations
- Pattern: `Get{TimeRange}{MetricName}UseCaseImpl`
- Examples:
  - `GetLast8HoursHeartRateUseCaseImpl`
  - `GetLast8HoursStepsUseCaseImpl`

### ViewModel Properties
- Pattern: `last{TimeRange}{MetricName}Data`
- Examples:
  - `last8HoursHeartRateData`
  - `last8HoursStepsData`
  - `dailySleepSummaryData`

### ViewModel Methods
- Pattern: `fetch{TimeRange}{MetricName}()`
- Examples:
  - `fetchLast8HoursHeartRate()`
  - `fetchLast8HoursSteps()`
  - `fetchDailySleepSummary()`

---

## 🚨 Common Pitfalls to Avoid

### ❌ Don't Fetch Too Much Data

```swift
// ❌ BAD - Fetching all historical data for a summary card
func execute() async throws -> [(hour: Int, heartRate: Int)] {
    let allEntries = try await progressRepository.fetchLocal(
        forUserID: userID,
        type: .restingHeartRate,
        syncStatus: nil
    )
    // This could be thousands of entries!
    return processAllData(allEntries)
}
```

```swift
// ✅ GOOD - Fetch only what's needed
func execute() async throws -> [(hour: Int, heartRate: Int)] {
    let allEntries = try await progressRepository.fetchLocal(
        forUserID: userID,
        type: .restingHeartRate,
        syncStatus: nil
    )
    
    // Filter to last 8 hours immediately
    let last8HoursStart = calendar.date(byAdding: .hour, value: -7, to: now)!
    let recentEntries = allEntries.filter { $0.date >= last8HoursStart }
    
    return processRecentData(recentEntries)
}
```

### ❌ Don't Couple Summary to Detail ViewModels

```swift
// ❌ BAD - Summary depending on detail ViewModel
struct SummaryView: View {
    let heartRateDetailViewModel: HeartRateDetailViewModel
    
    var body: some View {
        FullWidthHeartRateStatCard(
            hourlyData: heartRateDetailViewModel.last8HoursData  // ❌ Wrong!
        )
    }
}
```

```swift
// ✅ GOOD - Summary has its own data source
struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    
    var body: some View {
        FullWidthHeartRateStatCard(
            hourlyData: viewModel.last8HoursHeartRateData  // ✅ Correct!
        )
    }
}
```

### ❌ Don't Mix Summary and Detail Logic

```swift
// ❌ BAD - Use case doing too much
protocol GetHeartRateDataUseCase {
    func getSummaryData() async throws -> [(hour: Int, heartRate: Int)]
    func getDetailedData() async throws -> [HeartRateRecord]
    func getStatistics() async throws -> HeartRateStats
}
```

```swift
// ✅ GOOD - Separate use cases for different purposes
protocol GetLast8HoursHeartRateUseCase {  // For summary only
    func execute() async throws -> [(hour: Int, heartRate: Int)]
}

protocol GetHistoricalHeartRateUseCase {  // For detail view only
    func execute(timeRange: TimeRange) async throws -> [HeartRateRecord]
}
```

---

## 📚 Related Patterns

### 1. **Outbox Pattern**
- Summary data is loaded from local SwiftData storage
- Data syncs to backend via Outbox Pattern
- Summary always shows latest local data

### 2. **Repository Pattern**
- Use cases depend on repository protocols (ports)
- Repositories implement data access (adapters)
- Clean separation of concerns

### 3. **CQRS (Command Query Responsibility Segregation)**
- Summary use cases are **queries** (read-only)
- They don't modify data
- Optimized for lightweight reads

---

## 🎯 Summary Checklist

When implementing a new summary card:

- [ ] Created summary-specific use case in `Domain/UseCases/Summary/`
- [ ] Use case fetches ONLY lightweight, summary-specific data
- [ ] Use case follows naming convention: `GetLast8Hours{Metric}UseCase`
- [ ] Registered use case in `AppDependencies`
- [ ] Added use case dependency to `SummaryViewModel`
- [ ] Added data property to `SummaryViewModel`
- [ ] Added fetch method to `SummaryViewModel.reloadAllData()`
- [ ] Updated `ViewModelAppDependencies` to pass use case
- [ ] Updated `SummaryView` to use data from `viewModel`
- [ ] Summary card does NOT depend on detail ViewModel
- [ ] Added unit tests for use case

---

## 📖 References

- **Hexagonal Architecture**: `/docs/architecture/HEXAGONAL_ARCHITECTURE.md`
- **Outbox Pattern**: `/docs/architecture/OUTBOX_PATTERN.md`
- **Repository Pattern**: `/docs/architecture/REPOSITORY_PATTERN.md`
- **Copilot Instructions**: `/.github/copilot-instructions.md`

---

**Remember**: Summary cards should load immediately on `SummaryView.onAppear()`. Each card should have a dedicated, lightweight use case that fetches ONLY what's needed for display. Detail views can load comprehensive data separately.

**Version:** 1.0.0  
**Status:** ✅ Active Pattern  
**Last Updated:** 2025-01-27