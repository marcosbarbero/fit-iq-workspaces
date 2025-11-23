# Lume Implementation Guide

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Purpose:** Quick reference for implementing core features

---

## Registration Issue - RESOLVED ✅

### What Was Fixed

The registration flow now works correctly:

1. **Form fields clear after successful auth operations**
2. **Smooth transition to logged-in view after registration**
3. **Proper state management on logout**

### Files Modified

- `lume/lume/Presentation/Authentication/AuthViewModel.swift`
  - Added `clearFormFields()` method
  - Called after register, login, and logout

- `lume/lume/Presentation/Authentication/AuthCoordinatorView.swift`
  - Added `onChange` handler for auth state
  - Resets to login view on logout

### Testing the Fix

1. Build and run the app
2. Register a new user with unique email
3. Should immediately see MainTabView with tabs
4. Logout from Profile tab
5. Should return to login view (not registration)

---

## What's Ready

### ✅ Domain Layer Complete

**Entities:**
- `User` - User account information
- `AuthToken` - JWT tokens with expiration
- `MoodEntry` - Daily mood tracking with notes
- `JournalEntry` - Personal journaling
- `Goal` - Wellness goals with AI support

**Repository Protocols:**
- `AuthRepositoryProtocol` - Authentication operations
- `MoodRepositoryProtocol` - Mood CRUD operations
- `JournalRepositoryProtocol` - Journal CRUD operations
- `GoalRepositoryProtocol` - Goal management operations

**Use Cases (Auth Only):**
- `RegisterUserUseCase` - User registration
- `LoginUserUseCase` - User login
- `LogoutUserUseCase` - User logout
- `RefreshTokenUseCase` - Token refresh

### ✅ Presentation Layer (Auth)

- Modern, branded authentication UI
- COPPA-compliant registration (age 13+)
- International date format (DD/MM/YYYY)
- Accessible, high-contrast design
- Smooth animations and transitions

### ✅ Infrastructure

- SwiftData integration
- Keychain token storage
- Outbox pattern for resilience
- Backend configuration system
- Network layer foundation

---

## Next Steps - Priority Order

### 1️⃣ MOOD TRACKING (Start Here)

This is the simplest feature and will establish patterns for the rest.

#### Step 1: Create SwiftData Model

**File:** `lume/lume/Data/Persistence/SDMoodEntry.swift`

```swift
import Foundation
import SwiftData

@Model
final class SDMoodEntry {
    var id: UUID
    var userId: UUID
    var date: Date
    var mood: String  // Store enum as String
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        date: Date,
        mood: String,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.mood = mood
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Domain Conversion
extension SDMoodEntry {
    func toDomain() -> MoodEntry {
        MoodEntry(
            id: id,
            userId: userId,
            date: date,
            mood: MoodKind(rawValue: mood) ?? .ok,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    static func fromDomain(_ entry: MoodEntry) -> SDMoodEntry {
        SDMoodEntry(
            id: entry.id,
            userId: entry.userId,
            date: entry.date,
            mood: entry.mood.rawValue,
            note: entry.note,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }
}
```

#### Step 2: Update ModelContainer

**File:** `lume/lume/DI/AppDependencies.swift`

Find the `modelContainer` lazy var and add SDMoodEntry to schema:

```swift
private(set) lazy var modelContainer: ModelContainer = {
    let schema = Schema([
        SDOutboxEvent.self,
        SDMoodEntry.self  // ADD THIS LINE
    ])
    // ... rest of config
}()
```

#### Step 3: Create Repository Implementation

**File:** `lume/lume/Data/Repositories/MoodRepository.swift`

```swift
import Foundation
import SwiftData

final class MoodRepository: MoodRepositoryProtocol {
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol
    private let userId: UUID  // Get from auth
    
    init(
        modelContext: ModelContext,
        outboxRepository: OutboxRepositoryProtocol,
        userId: UUID
    ) {
        self.modelContext = modelContext
        self.outboxRepository = outboxRepository
        self.userId = userId
    }
    
    func save(mood: MoodKind, note: String?, date: Date) async throws -> MoodEntry {
        // Create domain entity
        let entry = MoodEntry(
            userId: userId,
            date: date,
            mood: mood,
            note: note
        )
        
        // Convert to SwiftData model
        let sdEntry = SDMoodEntry.fromDomain(entry)
        
        // Save to local database
        modelContext.insert(sdEntry)
        try modelContext.save()
        
        // Create outbox event for backend sync
        let payload = MoodPayload(entry: entry)
        let payloadData = try JSONEncoder().encode(payload)
        try await outboxRepository.createEvent(
            type: "mood.created",
            payload: payloadData
        )
        
        return entry
    }
    
    func fetchRecent(days: Int) async throws -> [MoodEntry] {
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) ?? Date()
        
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId &&
                entry.date >= startDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }
    
    // Implement other protocol methods...
}

private struct MoodPayload: Codable {
    let id: UUID
    let mood: String
    let note: String?
    let date: Date
    let timestamp: Date
    
    init(entry: MoodEntry) {
        self.id = entry.id
        self.mood = entry.mood.rawValue
        self.note = entry.note
        self.date = entry.date
        self.timestamp = Date()
    }
}
```

#### Step 4: Create Use Cases

**File:** `lume/lume/Domain/UseCases/SaveMoodUseCase.swift`

```swift
import Foundation

protocol SaveMoodUseCase {
    func execute(mood: MoodKind, note: String?, date: Date) async throws -> MoodEntry
}

final class SaveMoodUseCaseImpl: SaveMoodUseCase {
    private let repository: MoodRepositoryProtocol
    
    init(repository: MoodRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(mood: MoodKind, note: String?, date: Date) async throws -> MoodEntry {
        // Validate date is not in future
        guard date <= Date() else {
            throw MoodError.futureDate
        }
        
        // Trim note if provided
        let trimmedNote: String? = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = trimmedNote?.isEmpty == true ? nil : trimmedNote
        
        // Save via repository
        return try await repository.save(
            mood: mood,
            note: finalNote,
            date: date
        )
    }
}

enum MoodError: LocalizedError {
    case futureDate
    
    var errorDescription: String? {
        switch self {
        case .futureDate:
            return "Cannot log mood for a future date"
        }
    }
}
```

**File:** `lume/lume/Domain/UseCases/FetchMoodsUseCase.swift`

```swift
import Foundation

protocol FetchMoodsUseCase {
    func execute(days: Int) async throws -> [MoodEntry]
}

final class FetchMoodsUseCaseImpl: FetchMoodsUseCase {
    private let repository: MoodRepositoryProtocol
    
    init(repository: MoodRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(days: Int) async throws -> [MoodEntry] {
        // Validate days is positive
        guard days > 0 else {
            throw MoodError.invalidDaysRange
        }
        
        // Fetch from repository
        return try await repository.fetchRecent(days: days)
    }
}

extension MoodError {
    case invalidDaysRange
}
```

#### Step 5: Create ViewModel

**File:** `lume/lume/Presentation/ViewModels/MoodViewModel.swift`

```swift
import Foundation

@Observable
final class MoodViewModel {
    // State
    var selectedMood: MoodKind?
    var note: String = ""
    var selectedDate: Date = Date()
    var moodHistory: [MoodEntry] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Dependencies
    private let saveMoodUseCase: SaveMoodUseCase
    private let fetchMoodsUseCase: FetchMoodsUseCase
    
    init(
        saveMoodUseCase: SaveMoodUseCase,
        fetchMoodsUseCase: FetchMoodsUseCase
    ) {
        self.saveMoodUseCase = saveMoodUseCase
        self.fetchMoodsUseCase = fetchMoodsUseCase
    }
    
    @MainActor
    func saveMood() async {
        guard let mood = selectedMood else {
            errorMessage = "Please select a mood"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let entry = try await saveMoodUseCase.execute(
                mood: mood,
                note: note.isEmpty ? nil : note,
                date: selectedDate
            )
            
            // Add to history
            moodHistory.insert(entry, at: 0)
            
            // Clear form
            selectedMood = nil
            note = ""
            selectedDate = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func loadRecentMoods(days: Int = 30) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            moodHistory = try await fetchMoodsUseCase.execute(days: days)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

#### Step 6: Register Dependencies

**File:** `lume/lume/DI/AppDependencies.swift`

Add to the class:

```swift
// MARK: - Mood Dependencies

private(set) lazy var moodRepository: MoodRepositoryProtocol = {
    // TODO: Get userId from current user
    let userId = UUID() // Placeholder
    return MoodRepository(
        modelContext: modelContainer.mainContext,
        outboxRepository: outboxRepository,
        userId: userId
    )
}()

private(set) lazy var saveMoodUseCase: SaveMoodUseCase = {
    SaveMoodUseCaseImpl(repository: moodRepository)
}()

private(set) lazy var fetchMoodsUseCase: FetchMoodsUseCase = {
    FetchMoodsUseCaseImpl(repository: moodRepository)
}()

func makeMoodViewModel() -> MoodViewModel {
    MoodViewModel(
        saveMoodUseCase: saveMoodUseCase,
        fetchMoodsUseCase: fetchMoodsUseCase
    )
}
```

#### Step 7: Create UI

**File:** `lume/lume/Presentation/Features/Mood/MoodTrackingView.swift`

```swift
import SwiftUI

struct MoodTrackingView: View {
    @Bindable var viewModel: MoodViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Mood Selector
                        VStack(spacing: 16) {
                            Text("How are you feeling?")
                                .font(LumeTypography.titleMedium)
                                .foregroundColor(LumeColors.textPrimary)
                            
                            HStack(spacing: 20) {
                                ForEach(MoodKind.allCases, id: \.self) { mood in
                                    MoodButton(
                                        mood: mood,
                                        isSelected: viewModel.selectedMood == mood
                                    ) {
                                        viewModel.selectedMood = mood
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        
                        // Optional Note
                        if viewModel.selectedMood != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note (Optional)")
                                    .font(LumeTypography.bodySmall)
                                    .foregroundColor(LumeColors.textSecondary)
                                
                                TextField("How are you feeling?", text: $viewModel.note, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding()
                                    .foregroundColor(LumeColors.textPrimary)
                                    .background(LumeColors.surface)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Save Button
                        if viewModel.selectedMood != nil {
                            Button {
                                Task {
                                    await viewModel.saveMood()
                                }
                            } label: {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(LumeColors.textPrimary)
                                    } else {
                                        Text("Save Mood")
                                            .font(LumeTypography.body)
                                            .fontWeight(.medium)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(LumeColors.textPrimary)
                                .background(LumeColors.accentPrimary)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isLoading)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Error Message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(LumeTypography.bodySmall)
                                .foregroundColor(LumeColors.moodLow)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // History
                        if !viewModel.moodHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Moods")
                                    .font(LumeTypography.titleMedium)
                                    .foregroundColor(LumeColors.textPrimary)
                                
                                ForEach(viewModel.moodHistory) { entry in
                                    MoodHistoryRow(entry: entry)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadRecentMoods()
            }
            .animation(.easeInOut, value: viewModel.selectedMood)
        }
    }
}

struct MoodButton: View {
    let mood: MoodKind
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 48))
                
                Text(mood.displayName)
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)
            }
            .frame(width: 90, height: 90)
            .background(isSelected ? LumeColors.accentPrimary : LumeColors.surface)
            .cornerRadius(16)
            .shadow(
                color: isSelected ? LumeColors.accentPrimary.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
}

struct MoodHistoryRow: View {
    let entry: MoodEntry
    
    var body: some View {
        HStack(spacing: 16) {
            Text(entry.mood.emoji)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mood.displayName)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary)
                
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)
                
                if let note = entry.note {
                    Text(note)
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(LumeColors.surface)
        .cornerRadius(12)
    }
}
```

#### Step 8: Update MainTabView

**File:** `lume/lume/Presentation/MainTabView.swift`

Replace the `MoodPlaceholderView()` with:

```swift
MoodTrackingView(viewModel: dependencies.makeMoodViewModel())
    .tabItem {
        Label("Mood", systemImage: "sun.max.fill")
    }
    .tag(0)
```

---

### 2️⃣ JOURNAL (After Mood)

Follow the same pattern:
1. Create `SDJournalEntry` SwiftData model
2. Create `JournalRepository`
3. Create use cases
4. Create `JournalViewModel`
5. Create UI views
6. Update `MainTabView`

Key differences:
- Text editor instead of buttons
- Auto-save functionality
- Search capability

---

### 3️⃣ GOALS (After Journal)

Follow the same pattern:
1. Create `SDGoal` SwiftData model
2. Create `GoalRepository`
3. Create use cases
4. Create `GoalViewModel`
5. Create UI views (list, detail, create, progress)
6. Update `MainTabView`

Key features:
- Progress tracking
- Categories with colors
- Target dates
- Status management

---

## Key Patterns to Follow

### 1. Architecture Flow

```
View → ViewModel → Use Case → Repository → SwiftData
                                    ↓
                              Outbox Pattern → Backend
```

### 2. Error Handling

```swift
@MainActor
func someAction() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    
    do {
        let result = try await useCase.execute(...)
        // Handle success
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 3. SwiftData Conversion

Always keep domain and SwiftData separate:

```swift
// SwiftData model
@Model
final class SDEntity {
    var id: UUID
    var data: String
    
    func toDomain() -> Entity {
        Entity(id: id, data: data)
    }
    
    static func fromDomain(_ entity: Entity) -> SDEntity {
        SDEntity(id: entity.id, data: entity.data)
    }
}
```

### 4. Outbox Pattern

For every persistence operation that should sync to backend:

```swift
// Save locally
modelContext.insert(sdEntity)
try modelContext.save()

// Create outbox event
let payload = MyPayload(from: entity)
let payloadData = try JSONEncoder().encode(payload)
try await outboxRepository.createEvent(
    type: "entity.created",
    payload: payloadData
)
```

---

## Testing Checklist

For each feature:

- [ ] Can create new entries
- [ ] Can view existing entries
- [ ] Can update entries
- [ ] Can delete entries
- [ ] Loading states show correctly
- [ ] Errors display properly
- [ ] Works offline (local storage)
- [ ] Outbox events created
- [ ] UI follows Lume design (warm, calm)
- [ ] Animations are smooth
- [ ] Accessibility labels present

---

## Getting Help

### Architecture Questions
- Review `.github/copilot-instructions.md`
- Check existing `AuthRepository` implementation
- Follow Hexagonal Architecture principles

### UI/UX Questions
- Use `LumeColors` for all colors
- Use `LumeTypography` for all fonts
- Keep it minimal and calm
- Generous spacing and rounded corners

### Backend Questions
- Check `swagger.yaml` for API spec
- Use `config.plist` for configuration
- Implement backend services later (local-first)

---

## Current Status

✅ **Working:**
- Authentication (register, login, logout)
- Token management
- Outbox pattern
- Domain entities
- Repository protocols

🚧 **Ready to Implement:**
- Mood tracking (start here)
- Journal entries
- Goal management

📋 **Future:**
- Backend synchronization
- AI consulting features
- Advanced analytics
- Export/import data

---

**Good luck! Start with Mood Tracking and follow the pattern.** 🌟