# Summary Data Loading Pattern - Quick Reference

**Quick guide for adding new summary cards**

---

## 🚀 Quick Start: Add a New Summary Card in 5 Steps

### Step 1: Create Use Case

**File**: `Domain/UseCases/Summary/GetLast8Hours{Metric}UseCase.swift`

```swift
protocol GetLast8Hours{Metric}UseCase {
    func execute() async throws -> [(hour: Int, {metric}: Int)]
}

final class GetLast8Hours{Metric}UseCaseImpl: GetLast8Hours{Metric}UseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }
    
    func execute() async throws -> [(hour: Int, {metric}: Int)] {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLast8Hours{Metric}Error.userNotAuthenticated
        }
        
        let calendar = Calendar.current
        let now = Date()
        let last8HoursStart = calendar.date(byAdding: .hour, value: -7, to: now)!
        
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .{metricType},  // e.g., .steps, .restingHeartRate
            syncStatus: nil
        )
        
        let recentEntries = allEntries.filter { 
            $0.date >= last8HoursStart && $0.time != nil 
        }
        
        // Process and return data
        return processData(recentEntries)
    }
}

enum GetLast8Hours{Metric}Error: Error, LocalizedError {
    case userNotAuthenticated
    
    var errorDescription: String? {
        "User is not authenticated"
    }
}
```

### Step 2: Register in AppDependencies

**File**: `Infrastructure/Configuration/AppDependencies.swift`

```swift
// Add property
let getLast8Hours{Metric}UseCase: GetLast8Hours{Metric}UseCase

// Add to init parameters
init(
    // ... other params
    getLast8Hours{Metric}UseCase: GetLast8Hours{Metric}UseCase
) {
    self.getLast8Hours{Metric}UseCase = getLast8Hours{Metric}UseCase
}

// Add to build method
static func build(authManager: AuthManager) -> AppDependencies {
    let getLast8Hours{Metric}UseCase = GetLast8Hours{Metric}UseCaseImpl(
        progressRepository: progressRepository,
        authManager: authManager
    )
    
    return AppDependencies(
        // ... other params
        getLast8Hours{Metric}UseCase: getLast8Hours{Metric}UseCase
    )
}
```

### Step 3: Add to SummaryViewModel

**File**: `Presentation/ViewModels/SummaryViewModel.swift`

```swift
// Add use case dependency
private let getLast8Hours{Metric}UseCase: GetLast8Hours{Metric}UseCase

// Add data property
var last8Hours{Metric}Data: [(hour: Int, {metric}: Int)] = []

// Add to init
init(
    // ... other params
    getLast8Hours{Metric}UseCase: GetLast8Hours{Metric}UseCase
) {
    self.getLast8Hours{Metric}UseCase = getLast8Hours{Metric}UseCase
}

// Add to reloadAllData
func reloadAllData() async {
    await fetchLast8Hours{Metric}()
}

// Add fetch method
@MainActor
private func fetchLast8Hours{Metric}() async {
    do {
        last8Hours{Metric}Data = try await getLast8Hours{Metric}UseCase.execute()
        print("SummaryViewModel: ✅ Fetched \(last8Hours{Metric}Data.count) hours")
    } catch {
        print("SummaryViewModel: ❌ Error - \(error.localizedDescription)")
        last8Hours{Metric}Data = []
    }
}
```

### Step 4: Update ViewModelAppDependencies

**File**: `Infrastructure/Configuration/ViewModelAppDependencies.swift`

```swift
static func build(authManager: AuthManager, appDependencies: AppDependencies) 
    -> ViewModelAppDependencies 
{
    let summaryViewModel = SummaryViewModel(
        // ... other params
        getLast8Hours{Metric}UseCase: appDependencies.getLast8Hours{Metric}UseCase
    )
    
    return ViewModelAppDependencies(/* ... */)
}
```

### Step 5: Use in SummaryView

**File**: `Presentation/UI/Summary/SummaryView.swift`

```swift
NavigationLink(value: "{metric}Detail") {
    FullWidth{Metric}StatCard(
        latest{Metric}: viewModel.formattedLatest{Metric},
        hourlyData: viewModel.last8Hours{Metric}Data  // ✅ Summary data!
    )
}
```

---

## ✅ Checklist

- [ ] Created `GetLast8Hours{Metric}UseCase.swift` in `Domain/UseCases/Summary/`
- [ ] Registered in `AppDependencies` (property, init, build)
- [ ] Added to `SummaryViewModel` (dependency, property, init, fetch method)
- [ ] Updated `ViewModelAppDependencies.build()`
- [ ] Updated `SummaryView` to use `viewModel.last8Hours{Metric}Data`
- [ ] Verified card does NOT depend on detail ViewModel

---

## 📋 Naming Conventions

| Item | Pattern | Example |
|------|---------|---------|
| **Use Case File** | `GetLast8Hours{Metric}UseCase.swift` | `GetLast8HoursHeartRateUseCase.swift` |
| **Protocol** | `GetLast8Hours{Metric}UseCase` | `GetLast8HoursHeartRateUseCase` |
| **Implementation** | `GetLast8Hours{Metric}UseCaseImpl` | `GetLast8HoursHeartRateUseCaseImpl` |
| **ViewModel Property** | `last8Hours{Metric}Data` | `last8HoursHeartRateData` |
| **Fetch Method** | `fetchLast8Hours{Metric}()` | `fetchLast8HoursHeartRate()` |

---

## 🔍 Real Examples

### Heart Rate
```swift
// Use Case
GetLast8HoursHeartRateUseCase

// ViewModel
var last8HoursHeartRateData: [(hour: Int, heartRate: Int)] = []
private func fetchLast8HoursHeartRate() async { /* ... */ }

// View
hourlyData: viewModel.last8HoursHeartRateData
```

### Steps
```swift
// Use Case
GetLast8HoursStepsUseCase

// ViewModel
var last8HoursStepsData: [(hour: Int, steps: Int)] = []
private func fetchLast8HoursSteps() async { /* ... */ }

// View
hourlyData: viewModel.last8HoursStepsData
```

### Body Mass (Weight Mini-Graph)
```swift
// Use Case
GetLast5WeightsForSummaryUseCase

// ViewModel
var historicalWeightData: [Double] = []
private func fetchLast5WeightsForSummary() async { /* ... */ }

// View
historicalWeightData: viewModel.historicalWeightData
```

---

## ❌ Common Mistakes

### 1. Using Detail ViewModel in Summary

```swift
// ❌ WRONG
NavigationLink(value: "heartRateDetail") {
    FullWidthHeartRateStatCard(
        hourlyData: heartRateDetailViewModel.last8HoursData  // ❌ Wrong!
    )
}

// ✅ CORRECT
NavigationLink(value: "heartRateDetail") {
    FullWidthHeartRateStatCard(
        hourlyData: viewModel.last8HoursHeartRateData  // ✅ From SummaryViewModel
    )
}
```

### 2. Fetching Too Much Data

```swift
// ❌ WRONG - Fetching all data
let allEntries = try await progressRepository.fetchLocal(...)
return allEntries  // Could be thousands!

// ✅ CORRECT - Filter early
let allEntries = try await progressRepository.fetchLocal(...)
let recent = allEntries.filter { $0.date >= last8HoursStart }
return processRecent(recent)
```

### 3. Forgetting AuthManager

```swift
// ❌ WRONG - Missing auth check
func execute() async throws -> [(hour: Int, heartRate: Int)] {
    let entries = try await progressRepository.fetchLocal(...)
    // Missing userID!
}

// ✅ CORRECT - Check auth first
func execute() async throws -> [(hour: Int, heartRate: Int)] {
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        throw GetLast8HoursHeartRateError.userNotAuthenticated
    }
    let entries = try await progressRepository.fetchLocal(forUserID: userID, ...)
}
```

---

## 🎯 Key Principles

1. **Lightweight**: Fetch ONLY data needed for summary card
2. **Immediate**: Load on `SummaryView.onAppear()`
3. **Decoupled**: Summary and detail ViewModels are independent
4. **Single Source**: `SummaryViewModel` owns all summary data
5. **Scalable**: Easy to add new cards without complexity
6. **Handle Empty Data**: Show placeholder bars/indicators for missing data

---

## 💡 Handling Empty Data in Graphs

When displaying hourly/time-series data, handle missing data gracefully:

```swift
// ✅ GOOD - Show placeholder for empty data
Rectangle()
    .fill(item.steps > 0 ? color : Color.gray.opacity(0.2))
    .frame(
        width: barWidth,
        height: item.steps > 0
            ? CGFloat(item.steps) / CGFloat(maxSteps) * geometry.size.height
            : 4  // Small placeholder bar
    )
```

This prevents:
- Graph showing very tiny bars that are hard to see
- Confusion about whether data is missing or just very low
- Inconsistent visual appearance

---

## 📚 Full Documentation

See `SUMMARY_DATA_LOADING_PATTERN.md` for:
- Complete architecture explanation
- Testing patterns
- Step-by-step guides
- Common pitfalls
- Related patterns

---

**Quick Tip**: When in doubt, look at `GetLast8HoursHeartRateUseCase.swift`, `GetLast8HoursStepsUseCase.swift`, and `GetLast5WeightsForSummaryUseCase.swift` as reference implementations!