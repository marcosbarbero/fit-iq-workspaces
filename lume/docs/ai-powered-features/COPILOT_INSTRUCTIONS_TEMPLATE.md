# FitIQ iOS App - AI Assistant Instructions

**Version:** 2.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Guidelines for AI assistants working on iOS integration

---

## 🎯 Project Overview

This is an iOS app integrating with the FitIQ health & fitness API. The app follows **Hexagonal Architecture** (Ports & Adapters) with clean separation between Presentation, Domain, and Infrastructure layers.

**Key Technologies:**
- SwiftUI for UI
- SwiftData for local persistence
- HealthKit integration
- Async/await for concurrency
- Dependency Injection via AppDependencies

---

## 🏗️ Architecture Principles

### Hexagonal Architecture (Ports & Adapters)

```
Presentation Layer (ViewModels/Views)
    ↓ depends on ↓
Domain Layer (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure Layer (Repositories, Network, Services)
```

**Key Principles:**
- Domain layer is pure business logic (no external dependencies)
- Domain defines interfaces (ports via protocols)
- Infrastructure implements interfaces (adapters)
- Presentation depends only on domain abstractions
- Use dependency injection (via AppDependencies)

---

## 📁 Project Structure (Exact)

```
FitIQ-iOS/
├── Presentation/
│   ├── ViewModels/        # @Observable ViewModels
│   │   ├── SummaryViewModel.swift
│   │   ├── ProfileViewModel.swift
│   │   └── BodyMassEntryViewModel.swift
│   └── Views/             # SwiftUI Views
│       └── ...            # ContentView.swift, SummaryView.swift, etc.
├── Domain/
│   ├── Entities/          # SwiftData @Model entities (prefix: SD) + domain models
│   │   ├── CurrentSchema.swift
│   │   ├── BodyMass.swift
│   │   └── ActivitySnapshot.swift
│   ├── UseCases/          # Primary ports (protocols) + implementations
│   │   ├── CreateUserUseCase.swift
│   │   ├── AuthenticateUserUseCase.swift
│   │   ├── HealthKitAuthorizationUseCase.swift
│   │   ├── GetLatestBodyMetricsUseCase.swift
│   │   ├── GetHistoricalBodyMassUseCase.swift
│   │   ├── GetLatestActivitySnapshotUseCase.swift
│   │   ├── UserHasHealthKitAuthorizationUseCase.swift
│   │   ├── PerformInitialHealthKitSyncUseCase.swift
│   │   ├── ProcessDailyHealthDataUseCase.swift
│   │   ├── ProcessConsolidatedDailyHealthDataUseCase.swift
│   │   └── SaveBodyMassUseCase.swift
│   ├── Ports/             # Secondary ports (protocols)
│   │   ├── AuthRepositoryProtocol.swift
│   │   ├── HealthRepositoryProtocol.swift
│   │   ├── UserProfileStoragePortProtocol.swift
│   │   ├── AuthTokenPersistencePortProtocol.swift
│   │   ├── NetworkClientProtocol.swift
│   │   ├── BackgroundOperationsProtocol.swift
│   │   ├── BackgroundSyncManagerProtocol.swift
│   │   ├── ActivitySnapshotRepositoryProtocol.swift
│   │   ├── LocalHealthDataStorePort.swift
│   │   ├── ActivitySnapshotEventPublisherProtocol.swift
│   │   ├── LocalDataChangePublisherProtocol.swift
│   │   ├── RemoteSyncServiceProtocol.swift
│   │   └── AuthManagerProtocol.swift
│   └── Events/            # Domain events
│       └── ...            # e.g., HealthDataProcessedEvent.swift
├── Infrastructure/
│   ├── Repositories/      # Concrete implementations
│   │   ├── SwiftDataUserProfileAdapter.swift
│   │   ├── HealthKitAdapter.swift
│   │   ├── SwiftDataActivitySnapshotRepository.swift
│   │   └── SwiftDataLocalHealthDataStore.swift
│   ├── Network/           # Network implementations
│   │   ├── URLSessionNetworkClient.swift
│   │   ├── UserAuthAPIClient.swift
│   │   └── RemoteHealthDataSyncClient.swift
│   └── Services/          # Infrastructure services
│       ├── KeychainAuthTokenAdapter.swift
│       ├── HealthDataSyncManager.swift
│       ├── BackgroundOperations.swift
│       ├── BackgroundSyncManager.swift
│       ├── LocalDataChangeMonitor.swift
│       ├── RemoteSyncService.swift
│       ├── CloudDataManager.swift
│       ├── AuthManager.swift
│       ├── ActivitySnapshotEventPublisher.swift
│       └── LocalDataChangePublisher.swift
├── DI/
│   └── AppDependencies.swift # Dependency injection container
├── Resources/
│   └── config.plist       # Configuration (API key, etc.)
└── FitIQApp.swift         # Main application entry point
```

---

## 🚨 CRITICAL: Read This First

### ⚠️ NEVER Do These Things

1. **❌ NEVER create or update UI/Views**
   - Focus only on Domain, UseCases, Repositories, Network, Services
   - **EXCEPTION:** Binding fields from view to save/persist/remote calls is ALLOWED
   - ViewModels are OK to create/modify
   - UI layout, styling, navigation = OFF LIMITS

2. **❌ NEVER hardcode configuration**
   - API key MUST be in `config.plist`
   - Base URLs MUST be in `config.plist`
   - No hardcoded secrets in code

3. **❌ NEVER modify `docs/api-spec.yaml`**
   - This file is symlinked to backend project (read-only)
   - It's the source of truth for API contracts
   - Reference it, don't change it

4. **❌ NEVER create infrastructure before domain**
   - Always start with domain entities and use cases
   - Then create ports (protocols)
   - Then create infrastructure implementations
   - Presentation depends on domain abstractions

5. **❌ NEVER skip examining existing code**
   - Review existing patterns before implementing
   - Follow established naming conventions
   - Maintain consistency with codebase

6. **❌ NEVER forget the SD prefix for SwiftData models**
   - All `@Model` classes MUST use prefix `SD`
   - Example: `SDMeal`, `SDFood`, `SDWorkout`
   - This is MANDATORY for schema clarity

7. **❌ NEVER create new schema versions without updating PersistenceHelper**
   - Update typealiases in `PersistenceHelper` for new versions
   - Document schema changes properly

---

## ✅ ALWAYS Do These Things

### 1. Examine Existing Codebase First

Before implementing anything:
- Review existing entities, use cases, repositories
- Check `Domain/UseCases/` for similar patterns
- Look at existing ports in `Domain/Ports/`
- Review infrastructure adapters in `Infrastructure/`
- Follow the same structure and naming
- Maintain architectural consistency

**Examples to examine:**
- `SaveBodyMassUseCase.swift` - Example use case
- `SwiftDataActivitySnapshotRepository.swift` - Example repository
- `HealthKitAdapter.swift` - Example external adapter
- `AppDependencies.swift` - How dependencies are wired

### 2. Follow Hexagonal Architecture

**Implementation Order:**
```
1. Domain Entities (SwiftData @Model with SD prefix)
2. Domain Use Cases (protocols + implementations)
3. Domain Ports (protocols)
4. Infrastructure Adapters (concrete implementations)
5. Network Clients (if API integration needed)
6. Services (if external system integration needed)
7. ViewModels (@Observable, depends on use cases)
8. Register in AppDependencies
```

### 3. SwiftData Schema Requirements

#### CRITICAL: Naming Convention
**All SwiftData `@Model` classes MUST use the `SD` prefix**

```swift
// ✅ CORRECT
@Model
final class SDMeal {
    var id: String
    var name: String
    var calories: Double
    var loggedAt: Date
    
    init(id: String, name: String, calories: Double, loggedAt: Date) {
        self.id = id
        self.name = name
        self.calories = calories
        self.loggedAt = loggedAt
    }
}

// ❌ WRONG - Missing SD prefix
@Model
final class Meal { /* ... */ }
```

#### Schema Versioning
When creating new schema versions:

1. **Update CurrentSchema.swift:**
```swift
// Add new version to VersionedSchema
enum CurrentSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 1)
    
    static var models: [any PersistentModel.Type] {
        [SDMeal.self, SDFood.self, SDWorkout.self]
    }
}
```

2. **Update PersistenceHelper:**
```swift
// Update typealiases for latest models
typealias Meal = CurrentSchema.SDMeal
typealias Food = CurrentSchema.SDFood
```

3. **Document in Domain/Entities/Schema/:**
- Create schema definition file
- Document changes from previous version
- Include migration strategy if needed

### 4. Repository Pattern (Following Existing Style)

```swift
// 1. Domain Port (in Domain/Ports/)
protocol MealRepositoryProtocol {
    func save(_ meal: SDMeal) async throws
    func fetchAll() async throws -> [SDMeal]
    func fetchByID(_ id: String) async throws -> SDMeal?
    func delete(_ meal: SDMeal) async throws
}

// 2. Infrastructure Implementation (in Infrastructure/Repositories/)
final class SwiftDataMealRepository: MealRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(_ meal: SDMeal) async throws {
        modelContext.insert(meal)
        try modelContext.save()
    }
    
    func fetchAll() async throws -> [SDMeal] {
        let descriptor = FetchDescriptor<SDMeal>(
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchByID(_ id: String) async throws -> SDMeal? {
        var descriptor = FetchDescriptor<SDMeal>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    func delete(_ meal: SDMeal) async throws {
        modelContext.delete(meal)
        try modelContext.save()
    }
}
```

### 5. Use Case Pattern (Following Existing Style)

```swift
// Domain/UseCases/SaveMealUseCase.swift

// Protocol
protocol SaveMealUseCase {
    func execute(
        name: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) async throws -> SDMeal
}

// Implementation
final class SaveMealUseCaseImpl: SaveMealUseCase {
    private let repository: MealRepositoryProtocol
    
    init(repository: MealRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(
        name: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) async throws -> SDMeal {
        // Validation
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard calories >= 0 else {
            throw ValidationError.negativeCalories
        }
        
        // Create entity
        let meal = SDMeal(
            id: UUID().uuidString,
            name: name,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            loggedAt: Date()
        )
        
        // Persist
        try await repository.save(meal)
        
        return meal
    }
}

enum ValidationError: Error, LocalizedError {
    case emptyName
    case negativeCalories
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Meal name cannot be empty"
        case .negativeCalories:
            return "Calories cannot be negative"
        }
    }
}
```

### 6. Network Client Pattern (Following Existing Style)

```swift
// Domain/Ports/FoodAPIClientProtocol.swift
protocol FoodAPIClientProtocol {
    func searchFoods(query: String, page: Int) async throws -> FoodSearchResponse
    func getFoodByID(_ id: String) async throws -> FoodResponse
}

// Infrastructure/Network/FoodAPIClient.swift
final class FoodAPIClient: FoodAPIClientProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    
    init(networkClient: NetworkClientProtocol, baseURL: String) {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }
    
    func searchFoods(query: String, page: Int) async throws -> FoodSearchResponse {
        let endpoint = "\(baseURL)/foods/search"
        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        let request = NetworkRequest(
            endpoint: endpoint,
            method: .get,
            queryItems: queryItems
        )
        
        return try await networkClient.request(request)
    }
    
    func getFoodByID(_ id: String) async throws -> FoodResponse {
        let endpoint = "\(baseURL)/foods/\(id)"
        let request = NetworkRequest(endpoint: endpoint, method: .get)
        return try await networkClient.request(request)
    }
}
```

### 7. Configuration from config.plist

```swift
// Load configuration at runtime
enum Config {
    private static let bundle = Bundle.main
    
    static var apiKey: String {
        guard let key = bundle.object(forInfoPlistKey: "APIKey") as? String,
              !key.isEmpty else {
            fatalError("API Key not configured in config.plist")
        }
        return key
    }
    
    static var baseURL: String {
        guard let url = bundle.object(forInfoPlistKey: "BaseURL") as? String,
              !url.isEmpty else {
            fatalError("Base URL not configured in config.plist")
        }
        return url
    }
    
    static var websocketURL: String {
        bundle.object(forInfoPlistKey: "WebSocketURL") as? String ?? ""
    }
}
```

**config.plist structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>APIKey</key>
    <string>YOUR_API_KEY_HERE</string>
    <key>BaseURL</key>
    <string>https://fit-iq-backend.fly.dev/api/v1</string>
    <key>WebSocketURL</key>
    <string>wss://fit-iq-backend.fly.dev/ws</string>
</dict>
</plist>
```

### 8. Dependency Injection in AppDependencies

```swift
// DI/AppDependencies.swift
final class AppDependencies {
    // MARK: - Persistence
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    // MARK: - Infrastructure - Network
    lazy var networkClient: NetworkClientProtocol = URLSessionNetworkClient(
        apiKey: Config.apiKey
    )
    
    lazy var foodAPIClient: FoodAPIClientProtocol = FoodAPIClient(
        networkClient: networkClient,
        baseURL: Config.baseURL
    )
    
    // MARK: - Infrastructure - Repositories
    lazy var mealRepository: MealRepositoryProtocol = SwiftDataMealRepository(
        modelContext: modelContext
    )
    
    // MARK: - Domain - Use Cases
    lazy var saveMealUseCase: SaveMealUseCase = SaveMealUseCaseImpl(
        repository: mealRepository
    )
    
    lazy var searchFoodsUseCase: SearchFoodsUseCase = SearchFoodsUseCaseImpl(
        apiClient: foodAPIClient,
        localRepository: mealRepository
    )
    
    // MARK: - Presentation - ViewModels
    lazy var nutritionViewModel: NutritionViewModel = NutritionViewModel(
        saveMealUseCase: saveMealUseCase,
        searchFoodsUseCase: searchFoodsUseCase
    )
    
    init() {
        // Initialize ModelContainer
        let schema = Schema([
            SDMeal.self,
            SDFood.self,
            // Add all @Model types here
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            self.modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
```

### 9. ViewModel Pattern (Following Existing Style)

```swift
// Presentation/ViewModels/NutritionViewModel.swift
import Foundation
import Observation

@Observable
final class NutritionViewModel {
    // MARK: - State
    var meals: [SDMeal] = []
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    private let saveMealUseCase: SaveMealUseCase
    private let searchFoodsUseCase: SearchFoodsUseCase
    
    // MARK: - Init
    init(
        saveMealUseCase: SaveMealUseCase,
        searchFoodsUseCase: SearchFoodsUseCase
    ) {
        self.saveMealUseCase = saveMealUseCase
        self.searchFoodsUseCase = searchFoodsUseCase
    }
    
    // MARK: - Actions
    @MainActor
    func saveMeal(
        name: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let meal = try await saveMealUseCase.execute(
                name: name,
                calories: calories,
                proteinG: proteinG,
                carbsG: carbsG,
                fatG: fatG
            )
            meals.append(meal)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func searchFoods(query: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let results = try await searchFoodsUseCase.execute(query: query)
            // Handle results
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

---

## 🔌 API Integration

### Reference Documentation

- **API Spec:** `docs/api-spec.yaml` (symlinked, read-only)
- **Integration Guide:** `docs/IOS_INTEGRATION_HANDOFF.md` (START HERE)
- **Detailed Guides:** `docs/api-integration/` (bite-sized, organized)
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html

### API Standards

**All endpoints require these headers:**
```swift
request.setValue(Config.apiKey, forHTTPHeaderField: "X-API-Key")
request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

**Response format:**
```json
{
  "success": true,
  "data": { /* actual data */ },
  "error": null
}
```

---

## 🎨 UI Binding Exception

### When You CAN Touch Views

**ALLOWED:** Binding fields from view to save/persist/remote calls

```swift
// ✅ ALLOWED - Adding @State bindings and calling ViewModel methods
struct MealLogView: View {
    @State private var mealName = ""
    @State private var calories = ""
    
    let viewModel: NutritionViewModel
    
    var body: some View {
        Form {
            TextField("Meal Name", text: $mealName)
            TextField("Calories", text: $calories)
            
            Button("Save") {
                Task {
                    await viewModel.saveMeal(
                        name: mealName,
                        calories: Double(calories) ?? 0,
                        proteinG: 0,
                        carbsG: 0,
                        fatG: 0
                    )
                }
            }
        }
    }
}
```

### What You CANNOT Touch

**NOT ALLOWED:** UI layout, styling, navigation, new views

```swift
// ❌ NOT ALLOWED - Changing layout, adding sections, styling
struct MealLogView: View {
    var body: some View {
        VStack { // ❌ Don't change layout structure
            HStack { // ❌ Don't add new containers
                Image(systemName: "fork.knife") // ❌ Don't add icons
                    .foregroundColor(.blue) // ❌ Don't add styling
                Text("Meals")
                    .font(.title) // ❌ Don't change fonts
            }
            // ... existing form
        }
        .navigationTitle("Log Meal") // ❌ Don't add navigation
    }
}
```

---

## 🧪 Testing Guidelines

### Test Structure (Following Existing Patterns)

```swift
import XCTest
@testable import FitIQ

final class SaveMealUseCaseTests: XCTestCase {
    var sut: SaveMealUseCase!
    var mockRepository: MockMealRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockMealRepository()
        sut = SaveMealUseCaseImpl(repository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testExecute_ValidInput_SavesMeal() async throws {
        // Arrange
        let name = "Chicken Breast"
        let calories = 165.0
        
        // Act
        let result = try await sut.execute(
            name: name,
            calories: calories,
            proteinG: 31.0,
            carbsG: 0.0,
            fatG: 3.6
        )
        
        // Assert
        XCTAssertEqual(result.name, name)
        XCTAssertEqual(result.calories, calories)
        XCTAssertEqual(mockRepository.saveCallCount, 1)
    }
    
    func testExecute_EmptyName_ThrowsValidationError() async {
        // Arrange
        let name = ""
        
        // Act & Assert
        do {
            _ = try await sut.execute(
                name: name,
                calories: 100,
                proteinG: 0,
                carbsG: 0,
                fatG: 0
            )
            XCTFail("Expected validation error")
        } catch let error as ValidationError {
            XCTAssertEqual(error, .emptyName)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// Mock
final class MockMealRepository: MealRepositoryProtocol {
    var saveCallCount = 0
    var savedMeals: [SDMeal] = []
    
    func save(_ meal: SDMeal) async throws {
        saveCallCount += 1
        savedMeals.append(meal)
    }
    
    func fetchAll() async throws -> [SDMeal] {
        return savedMeals
    }
    
    func fetchByID(_ id: String) async throws -> SDMeal? {
        return savedMeals.first { $0.id == id }
    }
    
    func delete(_ meal: SDMeal) async throws {
        savedMeals.removeAll { $0.id == meal.id }
    }
}
```

---

## 📝 Naming Conventions

### Files (Following Existing Pattern)
- Entities: `BodyMass.swift`, `ActivitySnapshot.swift`
- Schema: `CurrentSchema.swift`
- Use Cases: `SaveBodyMassUseCase.swift`, `GetLatestActivitySnapshotUseCase.swift`
- Ports: `AuthRepositoryProtocol.swift`, `HealthRepositoryProtocol.swift`
- Repositories: `SwiftDataActivitySnapshotRepository.swift`
- Adapters: `HealthKitAdapter.swift`, `KeychainAuthTokenAdapter.swift`
- Clients: `UserAuthAPIClient.swift`, `RemoteHealthDataSyncClient.swift`
- Services: `HealthDataSyncManager.swift`, `BackgroundSyncManager.swift`
- ViewModels: `SummaryViewModel.swift`, `ProfileViewModel.swift`

### Classes/Protocols
- SwiftData Models: `SDMeal`, `SDFood`, `SDWorkout` (MUST have SD prefix)
- Protocols: `MealRepositoryProtocol`, `SaveMealUseCase`
- Implementations: `SwiftDataMealRepository`, `SaveMealUseCaseImpl`
- ViewModels: `NutritionViewModel` (with `@Observable`)

### Methods
- Use cases: `execute(...)` for main action
- Repositories: `save`, `fetch`, `delete`, `update`
- Descriptive names: `fetchMealsByDate`, not `getMeals`

---

## 🚀 When Helping with Integration

### 1. Always Examine Existing Code First

Before suggesting any implementation:
```
"Let me examine the existing code first..."
- Check Domain/UseCases/ for similar patterns
- Review Domain/Ports/ for protocol definitions
- Look at Infrastructure/ for adapter examples
- Check AppDependencies for DI patterns
```

### 2. Follow Existing Patterns Precisely

```swift
// ✅ CORRECT - Following SaveBodyMassUseCase pattern
protocol SaveMealUseCase {
    func execute(...) async throws -> SDMeal
}

final class SaveMealUseCaseImpl: SaveMealUseCase {
    private let repository: MealRepositoryProtocol
    
    init(repository: MealRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(...) async throws -> SDMeal {
        // Implementation
    }
}
```

### 3. Always Use SD Prefix for SwiftData Models

```swift
// ✅ CORRECT
@Model
final class SDMeal {
    var id: String
    var name: String
    // ...
}

// ❌ WRONG - Missing SD prefix
@Model
final class Meal { /* ... */ }
```

### 4. Reference Specific Guides

Instead of making up implementations:
```
"Check docs/api-integration/features/nutrition-tracking.md for the 
complete nutrition integration pattern. I'll follow the existing patterns 
from SaveBodyMassUseCase.swift and adapt them for nutrition."
```

### 5. Don't Make Up API Endpoints

Always verify endpoints in:
- `docs/api-spec.yaml` (symlinked)
- Swagger UI: https://fit-iq-backend.fly.dev/swagger/index.html
- Integration guides in `docs/api-integration/`

### 6. Update Schema Properly

When adding new SwiftData models:
1. Create entity with SD prefix
2. Add to CurrentSchema.swift models array
3. Update PersistenceHelper typealiases
4. Document in schema definitions
5. Consider migration if needed

---

## 🎯 Implementation Checklist

When implementing a new feature:

- [ ] Examined existing codebase for similar patterns
- [ ] Created domain entity with SD prefix (if SwiftData model)
- [ ] Created use case protocol (in Domain/UseCases/)
- [ ] Created use case implementation
- [ ] Created port protocol (in Domain/Ports/) if needed
- [ ] Implemented infrastructure adapter (in Infrastructure/)
- [ ] Created network client (in Infrastructure/Network/) if API integration
- [ ] Created service (in Infrastructure/Services/) if external integration
- [ ] Registered dependencies in AppDependencies
- [ ] Created/updated ViewModel (in Presentation/ViewModels/)
- [ ] Added field bindings to View (ONLY if needed for save/persist)
- [ ] Updated CurrentSchema.swift (if new model added)
- [ ] Updated PersistenceHelper (if new model added)
- [ ] Added unit tests
- [ ] Verified configuration in config.plist
- [ ] No hardcoded secrets or config
- [ ] No UI layout/styling changes

---

## 📚 Key Resources

### Must-Read Documents
1. **Integration Handoff:** `docs/IOS_INTEGRATION_HANDOFF.md`
2. **This File:** Project structure and patterns
3. **API Spec:** `docs/api-spec.yaml`

### Existing Code to Study
- `Domain/UseCases/SaveBodyMassUseCase.swift` - Use case pattern
- `Domain/Ports/ActivitySnapshotRepositoryProtocol.swift` - Port pattern
- `Infrastructure/Repositories/SwiftDataActivitySnapshotRepository.swift` - Repository pattern
- `Infrastructure/Network/UserAuthAPIClient.swift` - API client pattern
- `Infrastructure/Services/HealthDataSyncManager.swift` - Service pattern
- `Presentation/ViewModels/BodyMassEntryViewModel.swift` - ViewModel pattern
- `DI/AppDependencies.swift` - Dependency injection

### Integration Guides
- **Getting Started:** `docs/api-integration/getting-started/`
- **Features:** `docs/api-integration/features/`
- **AI Consultation:** `docs/api-integration/ai-consultation/`
- **Patterns:** `docs/api-integration/guides/`

---

## 💬 Communication Protocol

### When Stuck
1. Examine existing code for similar implementations
2. Check existing use cases in Domain/UseCases/
3. Review existing ports in Domain/Ports/
4. Review relevant integration guide
5. Verify endpoint in api-spec.yaml or Swagger UI
6. Ask specific questions with context

### When Suggesting Code
1. Show which layer (Domain/Infrastructure/Presentation)
2. Reference similar existing file
3. Follow exact naming conventions
4. Use SD prefix for SwiftData models
5. Provide complete, working examples
6. Include where to register in AppDependencies

### When Uncertain
- Ask for clarification
- Don't make assumptions
- Reference existing code
- Suggest checking with team

---

## 🎓 Summary

### Core Principles
1. **Hexagonal Architecture** - Domain defines interfaces, infrastructure implements
2. **SwiftData with SD prefix** - All @Model classes use SD prefix
3. **config.plist** - All configuration stored here
4. **UI binding only** - Can add field bindings, not layout/styling
5. **Examine first** - Review existing patterns before implementing
6. **Schema versioning** - Update CurrentSchema and PersistenceHelper

### Implementation Flow
```
Examine Existing Code
    ↓
Create Domain Entity (SD prefix if @Model)
    ↓
Create Use Case Protocol (Domain/UseCases/)
    ↓
Implement Use Case
    ↓
Create Port Protocol (Domain/Ports/) if needed
    ↓
Implement Infrastructure Adapter
    ↓
Create Network Client (Infrastructure/Network/) if API
    ↓
Create Service (Infrastructure/Services/) if needed
    ↓
Register in AppDependencies
    ↓
Create/Update ViewModel (Presentation/ViewModels/)
    ↓
Add Field Bindings (if needed for save/persist)
    ↓
Update Schema (if new @Model added)
```

### Critical Rules
- ✅ Always use SD prefix for @Model classes
- ✅ Always examine existing code first
- ✅ Always follow existing patterns exactly
- ✅ Can add field bindings to views
- ❌ Never change UI layout/styling/navigation
- ❌ Never forget SD prefix on SwiftData models
- ❌ Never skip updating PersistenceHelper
- ❌ Never hardcode configuration

---

**Remember: Examine existing code, follow established patterns precisely, use SD prefix for @Model classes, and only add field bindings to views when needed for save/persist/remote calls!**

**Version:** 2.0.0  
**Status:** ✅ Active  
**Last Updated:** 2025-01-27