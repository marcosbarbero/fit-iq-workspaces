# Mood Tracking Redesign: HKStateOfMind Integration

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** 🎯 Proposed Design  
**iOS Requirement:** iOS 18.0+

---

## 📋 Executive Summary

Complete redesign of mood tracking to use Apple's modern `HKStateOfMind` API, replacing the current 1-10 numeric scale with a richer, more nuanced mood tracking system. The design includes bidirectional translation between HealthKit's valence-based model and the backend's 1-10 scale.

### Key Benefits
- ✅ Native iOS 18 HealthKit integration
- ✅ Richer mood data (valence + descriptive labels)
- ✅ Bidirectional sync (HealthKit ↔ Backend)
- ✅ Backward compatible with existing backend API
- ✅ Better user experience with mood labels

---

## 🧠 Understanding HKStateOfMind

### What is HKStateOfMind?

`HKStateOfMind` is Apple's iOS 18+ API for tracking mental state and mood. It replaces the deprecated `HKCategoryTypeIdentifier.moodChanges`.

### Data Model

```swift
HKStateOfMind(
    date: Date,                          // When the mood was recorded
    kind: HKStateOfMind.Kind,           // .dailyMood or .momentaryEmotion
    valence: Double,                     // -1.0 (very unpleasant) to +1.0 (very pleasant)
    labels: [HKStateOfMind.Label],      // Descriptive mood labels
    associations: [HKStateOfMind.Association]  // Context (health, fitness, weather, etc.)
)
```

### Valence Scale

The core metric is **valence**: a continuous scale from -1.0 to +1.0:

```
-1.0                    0.0                    +1.0
|--------------------------|--------------------------|
Very Unpleasant        Neutral              Very Pleasant

Examples:
-0.9: Severely depressed
-0.5: Anxious, worried
-0.1: Slightly uncomfortable
 0.0: Neutral, calm
+0.3: Content
+0.6: Happy
+0.9: Ecstatic, joyful
```

### Available Labels

Apple provides predefined mood labels (enum `HKStateOfMind.Label`):

**Unpleasant:**
- `.amazed` (context-dependent)
- `.angry`
- `.annoyed`
- `.anxious`
- `.ashamed`
- `.drained`
- `.embarrassed`
- `.frustrated`
- `.guilty`
- `.irritated`
- `.lonely`
- `.overwhelmed`
- `.sad`
- `.scared`
- `.stressed`
- `.worried`

**Neutral:**
- `.calm`
- `.content`
- `.indifferent`
- `.surprised` (context-dependent)

**Pleasant:**
- `.amazed` (context-dependent)
- `.amused`
- `.confident`
- `.excited`
- `.grateful`
- `.happy`
- `.hopeful`
- `.passionate`
- `.peaceful`
- `.proud`
- `.relaxed`

### Associations (Context)

Optional context tags:
- `.community`
- `.currentEvents`
- `.dating`
- `.education`
- `.family`
- `.fitness`
- `.friends`
- `.health`
- `.hobbies`
- `.identity`
- `.money`
- `.partner`
- `.selfCare`
- `.spirituality`
- `.tasks`
- `.travel`
- `.weather`
- `.work`

---

## 🔄 Bidirectional Translation Strategy

### 1. HKStateOfMind → 1-10 Scale (for Backend)

**Algorithm: Valence-Based Mapping with Label Adjustment**

```swift
func valenceTo110Scale(valence: Double, labels: [HKStateOfMind.Label]) -> Int {
    // Step 1: Map valence linearly from [-1.0, +1.0] to [1, 10]
    // Formula: score = round((valence + 1.0) * 4.5 + 1.0)
    var baseScore = Int(round((valence + 1.0) * 4.5 + 1.0))
    
    // Step 2: Adjust based on dominant label sentiment
    let adjustedScore = adjustForLabels(baseScore, labels: labels)
    
    // Step 3: Clamp to valid range [1, 10]
    return max(1, min(10, adjustedScore))
}
```

**Detailed Mapping Table:**

| Valence Range | Base Score | Labels | Final Score | Description |
|---------------|-----------|--------|-------------|-------------|
| -1.0 to -0.8  | 1-2       | sad, depressed, lonely | 1 | Very unpleasant |
| -0.79 to -0.6 | 2-3       | anxious, worried, stressed | 2-3 | Quite unpleasant |
| -0.59 to -0.4 | 3-4       | frustrated, annoyed | 3-4 | Moderately unpleasant |
| -0.39 to -0.2 | 4-5       | irritated, overwhelmed | 4-5 | Slightly unpleasant |
| -0.19 to +0.19| 5-6       | calm, content, indifferent | 5-6 | Neutral |
| +0.2 to +0.39 | 6-7       | peaceful, relaxed | 6-7 | Slightly pleasant |
| +0.4 to +0.59 | 7-8       | happy, confident | 7-8 | Moderately pleasant |
| +0.6 to +0.79 | 8-9       | excited, grateful, proud | 8-9 | Quite pleasant |
| +0.8 to +1.0  | 9-10      | passionate, amazed, hopeful | 9-10 | Very pleasant |

**Label Adjustment Logic:**

```swift
func adjustForLabels(_ baseScore: Int, labels: [HKStateOfMind.Label]) -> Int {
    guard !labels.isEmpty else { return baseScore }
    
    // Define label sentiment weights
    let stronglyNegative: Set<HKStateOfMind.Label> = [.depressed, .overwhelmed, .ashamed, .scared]
    let stronglyPositive: Set<HKStateOfMind.Label> = [.passionate, .grateful, .proud, .hopeful]
    
    let hasStronglyNegative = labels.contains(where: stronglyNegative.contains)
    let hasStronglyPositive = labels.contains(where: stronglyPositive.contains)
    
    if hasStronglyNegative && baseScore > 3 {
        return baseScore - 1  // Pull down if labels indicate stronger negativity
    } else if hasStronglyPositive && baseScore < 8 {
        return baseScore + 1  // Pull up if labels indicate stronger positivity
    }
    
    return baseScore
}
```

### 2. 1-10 Scale → HKStateOfMind (for HealthKit)

**Algorithm: Score-to-Valence with Smart Label Selection**

```swift
func scaleToStateOfMind(score: Int, notes: String? = nil) -> HKStateOfMind {
    // Step 1: Map score to valence
    // Formula: valence = (score - 1) / 4.5 - 1.0
    let valence = (Double(score) - 1.0) / 4.5 - 1.0  // Range: [-1.0, +1.0]
    
    // Step 2: Select appropriate labels based on score
    let labels = labelsForScore(score, notes: notes)
    
    // Step 3: Extract associations from notes (optional)
    let associations = associationsFromNotes(notes)
    
    return HKStateOfMind(
        date: Date(),
        kind: .momentaryEmotion,  // Use .dailyMood for end-of-day summaries
        valence: valence,
        labels: labels,
        associations: associations
    )
}
```

**Score-to-Label Mapping:**

| Score | Valence | Primary Labels | Secondary Labels |
|-------|---------|----------------|------------------|
| 1     | -1.0    | sad, depressed | lonely, drained |
| 2     | -0.78   | anxious, worried | stressed, scared |
| 3     | -0.56   | frustrated, annoyed | irritated, overwhelmed |
| 4     | -0.33   | irritated | worried, stressed |
| 5     | -0.11   | calm, content | indifferent |
| 6     | +0.11   | content, calm | peaceful |
| 7     | +0.33   | happy, peaceful | relaxed, content |
| 8     | +0.56   | happy, confident | excited, grateful |
| 9     | +0.78   | excited, grateful | proud, hopeful |
| 10    | +1.0    | passionate, amazed | hopeful, proud |

**Smart Label Selection Logic:**

```swift
func labelsForScore(_ score: Int, notes: String?) -> [HKStateOfMind.Label] {
    var labels: [HKStateOfMind.Label] = []
    
    switch score {
    case 1:
        labels = [.sad, .depressed]
        if notes?.lowercased().contains("lonely") == true { labels.append(.lonely) }
    case 2:
        labels = [.anxious, .worried]
        if notes?.lowercased().contains("stress") == true { labels.append(.stressed) }
    case 3:
        labels = [.frustrated, .annoyed]
    case 4:
        labels = [.irritated]
    case 5:
        labels = [.calm, .content]
    case 6:
        labels = [.content, .peaceful]
    case 7:
        labels = [.happy, .peaceful]
    case 8:
        labels = [.happy, .confident]
        if notes?.lowercased().contains("excit") == true { labels.append(.excited) }
    case 9:
        labels = [.excited, .grateful]
    case 10:
        labels = [.passionate, .hopeful]
    default:
        labels = [.content]
    }
    
    return labels
}
```

---

## 🏗️ Architecture Design

### Domain Layer Changes

#### 1. New Domain Entity: `MoodEntry`

```swift
// Domain/Entities/Mood/MoodEntry.swift

import Foundation

/// Domain model for mood tracking
/// Represents a single mood entry with both 1-10 scale and HealthKit-compatible data
struct MoodEntry: Identifiable, Equatable {
    let id: UUID
    let userID: String
    let date: Date
    
    // 1-10 scale (for backend compatibility)
    let score: Int  // 1-10
    
    // HKStateOfMind-compatible fields (iOS 18+)
    let valence: Double  // -1.0 to +1.0
    let labels: [MoodLabel]  // Descriptive mood labels
    let associations: [MoodAssociation]  // Context tags
    
    // Metadata
    let notes: String?
    let createdAt: Date
    let updatedAt: Date?
    let sourceType: MoodSourceType  // .userEntry, .healthKit, .backend
    
    // Sync tracking
    let backendID: String?
    let syncStatus: SyncStatus
}

/// Mood label (mirrors HKStateOfMind.Label)
enum MoodLabel: String, Codable, CaseIterable {
    case amazed, amused, angry, annoyed, anxious, ashamed
    case calm, confident, content
    case drained, depressed
    case embarrassed, excited
    case frustrated
    case grateful, guilty
    case happy, hopeful
    case indifferent, irritated
    case lonely
    case overwhelmed
    case passionate, peaceful, proud
    case relaxed
    case sad, scared, stressed, surprised
    case worried
}

/// Mood association/context (mirrors HKStateOfMind.Association)
enum MoodAssociation: String, Codable, CaseIterable {
    case community, currentEvents
    case dating
    case education
    case family, fitness, friends
    case health, hobbies
    case identity
    case money
    case partner
    case selfCare, spirituality
    case tasks, travel
    case weather, work
}

/// Source of mood entry
enum MoodSourceType: String, Codable {
    case userEntry    // User manually logged in app
    case healthKit    // Synced from HealthKit
    case backend      // Fetched from backend
}
```

#### 2. New Use Case: `SaveMoodUseCase`

```swift
// Domain/UseCases/Mood/SaveMoodUseCase.swift

import Foundation

protocol SaveMoodUseCase {
    /// Save mood entry with 1-10 score (converts to HKStateOfMind)
    func execute(score: Int, notes: String?, date: Date) async throws -> UUID
    
    /// Save mood entry from HealthKit (converts to 1-10 scale)
    @available(iOS 18.0, *)
    func execute(from stateOfMind: HKStateOfMind) async throws -> UUID
}
```

#### 3. New Use Case: `SyncMoodToHealthKitUseCase`

```swift
// Domain/UseCases/Mood/SyncMoodToHealthKitUseCase.swift

import Foundation
import HealthKit

@available(iOS 18.0, *)
protocol SyncMoodToHealthKitUseCase {
    /// Syncs a mood entry to HealthKit using HKStateOfMind
    func execute(moodEntry: MoodEntry) async throws
}
```

#### 4. New Port: `MoodRepositoryProtocol`

```swift
// Domain/Ports/MoodRepositoryProtocol.swift

protocol MoodRepositoryProtocol {
    // Local storage
    func save(moodEntry: MoodEntry, forUserID: String) async throws -> UUID
    func fetchLocal(forUserID: String, from: Date?, to: Date?) async throws -> [MoodEntry]
    func delete(id: UUID, forUserID: String) async throws
    
    // HealthKit integration (iOS 18+)
    @available(iOS 18.0, *)
    func saveToHealthKit(moodEntry: MoodEntry) async throws
    
    @available(iOS 18.0, *)
    func fetchFromHealthKit(from: Date, to: Date) async throws -> [MoodEntry]
}
```

### Infrastructure Layer Changes

#### 1. SwiftData Model: `SDMoodEntry`

```swift
// Infrastructure/Persistence/Schema/SchemaV5.swift (NEW VERSION)

@Model final class SDMoodEntry {
    var id: UUID = UUID()
    var userID: String = ""
    var date: Date = Date()
    
    // 1-10 scale
    var score: Int = 5
    
    // HKStateOfMind fields
    var valence: Double = 0.0
    var labelsJSON: String = "[]"  // Stored as JSON array
    var associationsJSON: String = "[]"  // Stored as JSON array
    
    // Metadata
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date?
    var sourceType: String = MoodSourceType.userEntry.rawValue
    
    // Sync tracking
    var backendID: String?
    var syncStatus: String = SyncStatus.pending.rawValue
    
    init(id: UUID, userID: String, date: Date, score: Int, valence: Double,
         labelsJSON: String, associationsJSON: String, notes: String?,
         createdAt: Date, updatedAt: Date?, sourceType: String,
         backendID: String?, syncStatus: String) {
        self.id = id
        self.userID = userID
        self.date = date
        self.score = score
        self.valence = valence
        self.labelsJSON = labelsJSON
        self.associationsJSON = associationsJSON
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceType = sourceType
        self.backendID = backendID
        self.syncStatus = syncStatus
    }
}
```

#### 2. Repository Implementation: `SwiftDataMoodRepository`

```swift
// Infrastructure/Repositories/SwiftDataMoodRepository.swift

final class SwiftDataMoodRepository: MoodRepositoryProtocol {
    private let modelContext: ModelContext
    private let healthKitAdapter: HealthKitAdapter
    private let outboxRepository: OutboxRepositoryProtocol
    
    init(modelContext: ModelContext,
         healthKitAdapter: HealthKitAdapter,
         outboxRepository: OutboxRepositoryProtocol) {
        self.modelContext = modelContext
        self.healthKitAdapter = healthKitAdapter
        self.outboxRepository = outboxRepository
    }
    
    func save(moodEntry: MoodEntry, forUserID: String) async throws -> UUID {
        // Convert domain model to SwiftData model
        let sdEntry = SDMoodEntry(
            id: moodEntry.id,
            userID: userID,
            date: moodEntry.date,
            score: moodEntry.score,
            valence: moodEntry.valence,
            labelsJSON: encodeLabels(moodEntry.labels),
            associationsJSON: encodeAssociations(moodEntry.associations),
            notes: moodEntry.notes,
            createdAt: moodEntry.createdAt,
            updatedAt: moodEntry.updatedAt,
            sourceType: moodEntry.sourceType.rawValue,
            backendID: moodEntry.backendID,
            syncStatus: moodEntry.syncStatus.rawValue
        )
        
        // Save to SwiftData
        modelContext.insert(sdEntry)
        try modelContext.save()
        
        // ✅ OUTBOX PATTERN: Create outbox event for backend sync
        if moodEntry.sourceType == .userEntry || moodEntry.sourceType == .healthKit {
            try await outboxRepository.createEvent(
                eventType: .moodCreated,
                entityID: moodEntry.id,
                userID: userID,
                isNewRecord: moodEntry.backendID == nil,
                metadata: nil,
                priority: 5
            )
        }
        
        return moodEntry.id
    }
    
    @available(iOS 18.0, *)
    func saveToHealthKit(moodEntry: MoodEntry) async throws {
        // Convert to HKStateOfMind
        let stateOfMind = moodEntry.toHKStateOfMind()
        
        // Save to HealthKit
        try await healthKitAdapter.saveStateOfMind(stateOfMind)
    }
    
    @available(iOS 18.0, *)
    func fetchFromHealthKit(from: Date, to: Date) async throws -> [MoodEntry] {
        // Fetch from HealthKit
        let statesOfMind = try await healthKitAdapter.fetchStatesOfMind(from: from, to: to)
        
        // Convert to domain models
        return statesOfMind.map { MoodEntry(from: $0) }
    }
    
    private func encodeLabels(_ labels: [MoodLabel]) -> String {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(labels.map(\.rawValue))
        return String(data: data ?? Data(), encoding: .utf8) ?? "[]"
    }
    
    private func encodeAssociations(_ associations: [MoodAssociation]) -> String {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(associations.map(\.rawValue))
        return String(data: data ?? Data(), encoding: .utf8) ?? "[]"
    }
}
```

#### 3. HealthKit Adapter Extension

```swift
// Infrastructure/Integration/HealthKitAdapter+Mood.swift

@available(iOS 18.0, *)
extension HealthKitAdapter {
    
    func saveStateOfMind(_ stateOfMind: HKStateOfMind) async throws {
        try await withCheckedThrowingContinuation { continuation in
            store.save(stateOfMind) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.saveFailed(error.localizedDescription))
                } else if !success {
                    continuation.resume(throwing: HealthKitError.saveFailed("Unknown error"))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func fetchStatesOfMind(from startDate: Date, to endDate: Date) async throws -> [HKStateOfMind] {
        guard let stateOfMindType = HKObjectType.stateOfMindType() else {
            throw HealthKitError.invalidType("HKStateOfMind not available")
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = SortDescriptor(\HKStateOfMind.startDate, order: .reverse)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stateOfMindType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error.localizedDescription))
                } else {
                    let statesOfMind = (samples as? [HKStateOfMind]) ?? []
                    continuation.resume(returning: statesOfMind)
                }
            }
            
            store.execute(query)
        }
    }
}
```

#### 4. Backend API Client

```swift
// Infrastructure/Network/MoodAPIClient.swift

protocol MoodAPIClientProtocol {
    func saveMood(score: Int, notes: String?, loggedAt: Date) async throws -> MoodEntry
    func fetchMoodHistory(from: Date?, to: Date?) async throws -> [MoodEntry]
}

final class MoodAPIClient: MoodAPIClientProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    
    init(networkClient: NetworkClientProtocol, baseURL: String) {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }
    
    func saveMood(score: Int, notes: String?, loggedAt: Date) async throws -> MoodEntry {
        // Uses existing /api/v1/progress endpoint
        let endpoint = "\(baseURL)/progress"
        
        let body: [String: Any] = [
            "type": "mood_score",
            "quantity": Double(score),
            "logged_at": ISO8601DateFormatter().string(from: loggedAt),
            "notes": notes as Any
        ]
        
        let request = NetworkRequest(
            endpoint: endpoint,
            method: .post,
            body: body
        )
        
        let response: ProgressEntryResponse = try await networkClient.request(request)
        return MoodEntry(from: response)  // Convert ProgressEntry to MoodEntry
    }
    
    func fetchMoodHistory(from: Date?, to: Date?) async throws -> [MoodEntry] {
        let endpoint = "\(baseURL)/progress"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "type", value: "mood_score")
        ]
        
        if let from = from {
            queryItems.append(URLQueryItem(name: "from", value: formatDate(from)))
        }
        if let to = to {
            queryItems.append(URLQueryItem(name: "to", value: formatDate(to)))
        }
        
        let request = NetworkRequest(
            endpoint: endpoint,
            method: .get,
            queryItems: queryItems
        )
        
        let response: ProgressListResponse = try await networkClient.request(request)
        return response.entries.map { MoodEntry(from: $0) }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
```

### Presentation Layer Changes

#### Updated ViewModel

```swift
// Presentation/ViewModels/MoodEntryViewModel.swift

@Observable
final class MoodEntryViewModel {
    
    // State
    var selectedScore: Int = 5
    var notes: String = ""
    var selectedLabels: Set<MoodLabel> = []
    var selectedAssociations: Set<MoodAssociation> = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showingSuccess: Bool = false
    
    // Computed valence for preview
    var currentValence: Double {
        return (Double(selectedScore) - 1.0) / 4.5 - 1.0
    }
    
    // Dependencies
    private let saveMoodUseCase: SaveMoodUseCase
    private let syncMoodToHealthKitUseCase: SyncMoodToHealthKitUseCase?
    
    init(saveMoodUseCase: SaveMoodUseCase,
         syncMoodToHealthKitUseCase: SyncMoodToHealthKitUseCase?) {
        self.saveMoodUseCase = saveMoodUseCase
        self.syncMoodToHealthKitUseCase = syncMoodToHealthKitUseCase
    }
    
    @MainActor
    func saveMood() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Save to local storage and backend (via Outbox Pattern)
            let moodID = try await saveMoodUseCase.execute(
                score: selectedScore,
                notes: notes.isEmpty ? nil : notes,
                date: Date()
            )
            
            // Sync to HealthKit if available (iOS 18+)
            if #available(iOS 18.0, *),
               let syncUseCase = syncMoodToHealthKitUseCase {
                // Create mood entry with selected labels/associations
                let moodEntry = MoodEntry(
                    id: moodID,
                    userID: "", // Populated by use case
                    date: Date(),
                    score: selectedScore,
                    valence: currentValence,
                    labels: Array(selectedLabels),
                    associations: Array(selectedAssociations),
                    notes: notes.isEmpty ? nil : notes,
                    createdAt: Date(),
                    updatedAt: nil,
                    sourceType: .userEntry,
                    backendID: nil,
                    syncStatus: .pending
                )
                
                try await syncUseCase.execute(moodEntry: moodEntry)
            }
            
            showingSuccess = true
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func resetForm() {
        selectedScore = 5
        notes = ""
        selectedLabels = []
        selectedAssociations = []
    }
}
```

---

## 🔄 Sync Flows

### Flow 1: User Logs Mood in App

```
User enters mood (score 8)
    ↓
MoodEntryViewModel.saveMood()
    ↓
SaveMoodUseCase.execute(score: 8, notes: "Feeling great!", date: Date())
    ↓
├─→ Convert score to valence: (8-1)/4.5-1.0 = +0.56
├─→ Select labels: [.happy, .confident]
├─→ Create MoodEntry with both representations
    ↓
SwiftDataMoodRepository.save()
    ↓
├─→ Save to SwiftData (SDMoodEntry)
├─→ ✅ Create OutboxEvent for backend sync
    ↓
SyncMoodToHealthKitUseCase.execute() [iOS 18+]
    ↓
├─→ Convert MoodEntry to HKStateOfMind
├─→ HealthKitAdapter.saveStateOfMind()
├─→ Save to HealthKit
    ↓
OutboxProcessorService (background)
    ↓
└─→ Sync to backend: POST /api/v1/progress
    └─→ { type: "mood_score", quantity: 8, notes: "Feeling great!" }
```

### Flow 2: User Logs Mood in Apple Health

```
User logs mood in Apple Health app
    ↓
Creates HKStateOfMind(valence: +0.6, labels: [.happy, .excited])
    ↓
HealthKit triggers observation callback
    ↓
HealthDataSyncManager detects new HKStateOfMind
    ↓
SaveMoodUseCase.execute(from: stateOfMind)
    ↓
├─→ Convert valence to score: round((0.6+1.0)*4.5+1.0) = 8
├─→ Extract labels and associations
├─→ Create MoodEntry with both representations
    ↓
SwiftDataMoodRepository.save()
    ↓
├─→ Save to SwiftData (SDMoodEntry)
├─→ ✅ Create OutboxEvent for backend sync
    ↓
OutboxProcessorService (background)
    ↓
└─→ Sync to backend: POST /api/v1/progress
    └─→ { type: "mood_score", quantity: 8 }
```

### Flow 3: Backend Has New Mood Data

```
Backend returns mood entry: { type: "mood_score", quantity: 7 }
    ↓
RemoteSyncService fetches progress entries
    ↓
Convert ProgressEntry to MoodEntry
    ↓
├─→ score = 7
├─→ valence = (7-1)/4.5-1.0 = +0.33
├─→ labels = labelsForScore(7) = [.happy, .peaceful]
    ↓
SwiftDataMoodRepository.save()
    ↓
├─→ Save to SwiftData with sourceType = .backend
├─→ Mark syncStatus = .synced
    ↓
[iOS 18+] Optionally sync to HealthKit
    ↓
└─→ HealthKitAdapter.saveStateOfMind()
```

---

## 📱 UI/UX Recommendations

### Option 1: Score-Based Entry (Simple)

Keep the current 1-10 slider but show suggested labels:

```
┌──────────────────────────────────┐
│  How are you feeling?            │
├──────────────────────────────────┤
│  Mood Score: [====●====] 8       │
│  (Moderately Pleasant)           │
│                                  │
│  Suggested labels:               │
│  [●] Happy   [●] Confident       │
│  [ ] Excited [ ] Grateful        │
│                                  │
│  Context (optional):             │
│  [ ] Work   [ ] Health           │
│  [ ] Fitness [ ] Friends         │
│                                  │
│  Notes: [Text field...]          │
│                                  │
│  [Save]                          │
└──────────────────────────────────┘
```

### Option 2: Label-First Entry (Rich)

Start with label selection, auto-calculate score:

```
┌──────────────────────────────────┐
│  How are you feeling?            │
├──────────────────────────────────┤
│  Select your mood:               │
│                                  │
│  Pleasant:                       │
│  [●] Happy   [ ] Excited         │
│  [ ] Grateful [ ] Peaceful       │
│                                  │
│  Unpleasant:                     │
│  [ ] Anxious [ ] Frustrated      │
│  [ ] Sad     [ ] Stressed        │
│                                  │
│  Neutral:                        │
│  [ ] Calm    [ ] Content         │
│                                  │
│  → Mood Score: 8/10              │
│    (Calculated from labels)      │
│                                  │
│  [Save]                          │
└──────────────────────────────────┘
```

### Option 3: Hybrid (Best UX)

Score slider + optional label refinement:

```
┌──────────────────────────────────┐
│  How are you feeling?            │
├──────────────────────────────────┤
│  [====●====] 8                   │
│  Moderately Pleasant             │
│                                  │
│  ▼ Refine with labels (optional) │
│                                  │
│  [Expanded section shows labels] │
│                                  │
│  Notes: [Text field...]          │
│                                  │
│  [Save to App & HealthKit]       │
└──────────────────────────────────┘
```

**Recommendation:** Start with **Option 1** (simple), then add **Option 3** (hybrid) in a future iteration.

---

## 🚀 Implementation Plan

### Phase 1: Foundation (1-2 days)

1. **Create Domain Models**
   - [ ] `MoodEntry` entity
   - [ ] `MoodLabel` enum
   - [ ] `MoodAssociation` enum
   - [ ] Translation utility functions

2. **Create Use Cases**
   - [ ] `SaveMoodUseCase` (with both overloads)
   - [ ] `SyncMoodToHealthKitUseCase`
   - [ ] `GetHistoricalMoodUseCase`

3. **Create Ports**
   - [ ] `MoodRepositoryProtocol`

### Phase 2: Infrastructure (2-3 days)

4. **Schema Migration**
   - [ ] Create SchemaV5 with `SDMoodEntry`
   - [ ] Migration from V4 to V5 (convert existing mood data)
   - [ ] Update `PersistenceHelper`

5. **Repository Implementation**
   - [ ] `SwiftDataMoodRepository`
   - [ ] Label/association JSON encoding/decoding
   - [ ] Outbox Pattern integration

6. **HealthKit Integration**
   - [ ] `HealthKitAdapter+Mood.swift` extension
   - [ ] `saveStateOfMind()` implementation
   - [ ] `fetchStatesOfMind()` implementation
   - [ ] Authorization update (add `HKStateOfMind` permissions)

7. **Backend Integration**
   - [ ] `MoodAPIClient` (reuse existing `/api/v1/progress` endpoint)
   - [ ] Translation between `ProgressEntry` and `MoodEntry`

### Phase 3: Presentation (1-2 days)

8. **ViewModel Updates**
   - [ ] Update `MoodEntryViewModel` with label selection
   - [ ] Add valence preview
   - [ ] Add association selection

9. **View Updates** (OPTIONAL - only if redesigning UI)
   - [ ] Add label selection UI
   - [ ] Add association selection UI
   - [ ] Add valence indicator

### Phase 4: Sync & Testing (2-3 days)

10. **Background Sync**
    - [ ] Update `HealthDataSyncManager` to observe `HKStateOfMind`
    - [ ] Add mood sync to daily background task
    - [ ] Test Outbox Pattern with mood entries

11. **Testing**
    - [ ] Unit tests for translation functions
    - [ ] Unit tests for use cases
    - [ ] Integration tests for HealthKit sync
    - [ ] Integration tests for backend sync
    - [ ] Manual testing on iOS 18 device

### Phase 5: Migration & Deployment (1 day)

12. **Data Migration**
    - [ ] Migrate existing `SDProgressEntry` mood records to `SDMoodEntry`
    - [ ] Calculate valence for existing scores
    - [ ] Assign default labels based on scores

13. **Deployment**
    - [ ] Update minimum iOS version to 18.0 (if required)
    - [ ] OR: Add fallback for iOS 17 and below
    - [ ] Release notes explaining new mood tracking

---

## 🧪 Testing Strategy

### Unit Tests

```swift
// Tests/Domain/UseCases/SaveMoodUseCaseTests.swift

func testScoreToValenceConversion() {
    XCTAssertEqual(scoreToValence(1), -1.0, accuracy: 0.01)
    XCTAssertEqual(scoreToValence(5), -0.11, accuracy: 0.01)
    XCTAssertEqual(scoreToValence(6), 0.11, accuracy: 0.01)
    XCTAssertEqual(scoreToValence(10), 1.0, accuracy: 0.01)
}

func testValenceToScoreConversion() {
    XCTAssertEqual(valenceToScore(-1.0), 1)
    XCTAssertEqual(valenceToScore(-0.11), 5)
    XCTAssertEqual(valenceToScore(0.11), 6)
    XCTAssertEqual(valenceToScore(1.0), 10)
}

func testLabelSelectionForScore() {
    let labels1 = labelsForScore(1, notes: nil)
    XCTAssertTrue(labels1.contains(.sad))
    XCTAssertTrue(labels1.contains(.depressed))
    
    let labels8 = labelsForScore(8, notes: nil)
    XCTAssertTrue(labels8.contains(.happy))
    XCTAssertTrue(labels8.contains(.confident))
}

func testRoundTripConversion() {
    // Score → Valence → Score should be ~same
    for score in 1...10 {
        let valence = scoreToValence(score)
        let convertedScore = valenceToScore(valence)
        XCTAssertEqual(convertedScore, score, "Score \(score) should round-trip")
    }
}
```

### Integration Tests

```swift
func testSaveAndSyncToHealthKit() async throws {
    let moodID = try await saveMoodUseCase.execute(
        score: 8,
        notes: "Feeling great!",
        date: Date()
    )
    
    // Verify saved locally
    let localEntry = try await moodRepository.fetchLocal(forUserID: userID, from: nil, to: nil)
    XCTAssertEqual(localEntry.first?.score, 8)
    XCTAssertEqual(localEntry.first?.valence, 0.56, accuracy: 0.01)
    
    // Verify synced to HealthKit (iOS 18+)
    if #available(iOS 18.0, *) {
        let healthKitEntries = try await moodRepository.fetchFromHealthKit(
            from: Date().addingTimeInterval(-3600),
            to: Date()
        )
        XCTAssertTrue(healthKitEntries.contains(where: { $0.id == moodID }))
    }
}
```

---

## 🎯 Success Metrics

- [ ] All existing mood data successfully migrated
- [ ] Score ↔ Valence conversion is reversible (within ±0.5 score points)
- [ ] HealthKit sync works bidirectionally
- [ ] Backend API continues to receive 1-10 scores
- [ ] No data loss during migration
- [ ] Outbox Pattern ensures reliable sync
- [ ] Unit test coverage > 80%

---

## 📚 Resources

### Apple Documentation
- [HKStateOfMind](https://developer.apple.com/documentation/healthkit/hkstateofmind)
- [Mental Health](https://developer.apple.com/documentation/healthkit/mental_health)
- [State of Mind Labels](https://developer.apple.com/documentation/healthkit/hkstateofmind/label)
- [State of Mind Associations](https://developer.apple.com/documentation/healthkit/hkstateofmind/association)

### Internal Documentation
- [Outbox Pattern Architecture](../OUTBOX_PATTERN_ARCHITECTURE.md)
- [Progress API Migration Summary](../PROGRESS_API_MIGRATION_SUMMARY.md)
- [Backend API Spec](../be-api-spec/swagger.yaml) - `/api/v1/progress` endpoint

---

## ❓ FAQ

### Q: What happens on iOS 17 and below?
**A:** Two options:
1. Require iOS 18+ (simplest, cleanest)
2. Use fallback: Store score only, skip HealthKit sync on older iOS

### Q: What if HealthKit has conflicting mood data?
**A:** Use timestamp as tie-breaker. Most recent entry wins. User can manually delete duplicates in HealthKit.

### Q: Can users edit labels after saving?
**A:** Yes! Fetch from local storage, update labels/associations, recalculate valence, save again.

### Q: How accurate is the valence ↔ score conversion?
**A:** Linear mapping ensures reversibility within ±0.5 score points. Labels provide additional context.

### Q: What about privacy?
**A:** Mood data follows same privacy model as other health metrics:
- Stored locally in SwiftData (encrypted)
- Synced to HealthKit (user controls permissions)
- Synced to backend via authenticated API (JWT + API key)

---

**Status:** ✅ Design Complete, Ready for Implementation  
**Estimated Effort:** 7-11 days  
**Risk Level:** Medium (requires iOS 18+, data migration)  
**Business Value:** High (richer mood tracking, native HealthKit integration)