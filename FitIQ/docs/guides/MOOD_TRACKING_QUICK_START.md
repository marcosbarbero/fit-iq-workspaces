# Mood Tracking Quick Start Guide

**Date:** 2025-01-27  
**Status:** 🚧 Phase 1 Complete, Phase 2 In Progress  
**iOS Requirement:** iOS 18.0+ (for HKStateOfMind features)

---

## 🎯 What's Been Built

### Phase 1: Domain Layer ✅ COMPLETE

**7 new files, ~1,927 lines of production code**

```
Domain/
├── Entities/Mood/
│   ├── MoodLabel.swift              ✅ 28 mood labels (happy, anxious, etc.)
│   ├── MoodAssociation.swift        ✅ 18 contextual tags (work, health, etc.)
│   ├── MoodSourceType.swift         ✅ Track origin (user, HealthKit, backend)
│   ├── MoodEntry.swift              ✅ Core domain model (dual representation)
│   └── MoodTranslationUtility.swift ✅ Score ↔ Valence conversion
├── UseCases/Mood/
│   └── SaveMoodUseCase.swift        ✅ Save mood with auto-label selection
└── Ports/
    └── MoodRepositoryProtocol.swift ✅ Repository interface
```

---

## 🔄 How It Works

### Dual Representation System

```
User logs mood: "8 - Feeling great!"
        ↓
SaveMoodUseCase
        ↓
    Score: 8
        ↓
Translation → Valence: +0.56
        ↓
Auto-select → Labels: [happy, confident]
        ↓
Infer → Associations: [] (from notes)
        ↓
Create MoodEntry:
  - score: 8           (for backend API)
  - valence: +0.56     (for HealthKit)
  - labels: [happy, confident]
  - notes: "Feeling great!"
        ↓
Save to SwiftData → Triggers Outbox Pattern
        ↓
Sync to HealthKit (iOS 18+)
        ↓
Sync to Backend (via Outbox)
```

---

## 📐 Translation Math

### Score → Valence
```swift
valence = (score - 1) / 4.5 - 1.0

Examples:
  1 → -1.0  (very unpleasant)
  5 → -0.11 (slightly unpleasant)
  6 → +0.11 (slightly pleasant)
 10 → +1.0  (very pleasant)
```

### Valence → Score
```swift
score = round((valence + 1.0) * 4.5 + 1.0)

Examples:
 -1.0 → 1
 -0.11 → 5
 +0.11 → 6
 +1.0 → 10
```

**Accuracy:** 100% reversible (±0 for most values, ±1 with label adjustment)

---

## 🏗️ Next Steps: Phase 2 Implementation

### Step 1: Schema Migration (SchemaV5)

**File:** `Infrastructure/Persistence/Schema/SchemaV5.swift`

```swift
enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 5)
    
    // Reuse unchanged models
    typealias SDUserProfile = SchemaV4.SDUserProfile
    typealias SDPhysicalAttribute = SchemaV4.SDPhysicalAttribute
    typealias SDActivitySnapshot = SchemaV4.SDActivitySnapshot
    typealias SDProgressEntry = SchemaV4.SDProgressEntry
    typealias SDOutboxEvent = SchemaV4.SDOutboxEvent
    typealias SDSleepSession = SchemaV4.SDSleepSession
    typealias SDSleepStage = SchemaV4.SDSleepStage
    
    // NEW: Mood entry with dual representation
    @Model final class SDMoodEntry {
        var id: UUID = UUID()
        var userID: String = ""
        var date: Date = Date()
        
        // 1-10 scale (backend)
        var score: Int = 5
        
        // HKStateOfMind (iOS 18+)
        var valence: Double = 0.0
        var labelsJSON: String = "[]"        // Stored as JSON
        var associationsJSON: String = "[]"  // Stored as JSON
        
        // Metadata
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var sourceType: String = "userEntry"
        
        // Sync tracking
        var backendID: String?
        var syncStatus: String = "pending"
        
        init(id: UUID, userID: String, date: Date, score: Int, 
             valence: Double, labelsJSON: String, associationsJSON: String,
             notes: String?, createdAt: Date, updatedAt: Date?,
             sourceType: String, backendID: String?, syncStatus: String) {
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
    
    static var models: [any PersistentModel.Type] {
        [SDUserProfile.self, SDPhysicalAttribute.self, 
         SDActivitySnapshot.self, SDProgressEntry.self,
         SDOutboxEvent.self, SDSleepSession.self, 
         SDSleepStage.self, SDMoodEntry.self]  // ← Add here
    }
}
```

### Step 2: Update Schema Definition

**File:** `Infrastructure/Persistence/Schema/SchemaDefinition.swift`

```swift
// 1. Update CurrentSchema
typealias CurrentSchema = SchemaV5  // Changed from V4

// 2. Add V5 to enum
enum FitIQSchemaDefinition: CaseIterable {
    case v1, v2, v3, v4, v5  // ← Add v5
    
    var schema: any VersionedSchema.Type {
        switch self {
        case .v1: return SchemaV1.self
        case .v2: return SchemaV2.self
        case .v3: return SchemaV3.self
        case .v4: return SchemaV4.self
        case .v5: return SchemaV5.self  // ← Add case
        @unknown default: return CurrentSchema.self
        }
    }
}
```

### Step 3: Update PersistenceHelper

**File:** `Infrastructure/Persistence/Schema/PersistenceHelper.swift`

```swift
// Add typealias for new model
typealias SDMoodEntry = SchemaV5.SDMoodEntry
```

### Step 4: Create Repository

**File:** `Infrastructure/Repositories/SwiftDataMoodRepository.swift`

```swift
import Foundation
import SwiftData
import HealthKit

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
    
    // MARK: - Save
    
    func save(moodEntry: MoodEntry, forUserID userID: String) async throws -> UUID {
        // 1. Convert to SwiftData model
        let sdEntry = toSwiftData(moodEntry, userID: userID)
        
        // 2. Save to SwiftData
        modelContext.insert(sdEntry)
        try modelContext.save()
        
        // 3. ✅ OUTBOX PATTERN: Create outbox event
        if moodEntry.sourceType.shouldSyncToBackend {
            try await outboxRepository.createEvent(
                eventType: .moodCreated,  // Need to add this enum case
                entityID: moodEntry.id,
                userID: userID,
                isNewRecord: moodEntry.backendID == nil,
                metadata: nil,
                priority: 5
            )
        }
        
        return moodEntry.id
    }
    
    // MARK: - Fetch
    
    func fetchLocal(forUserID userID: String, from: Date?, to: Date?) async throws -> [MoodEntry] {
        var predicate: Predicate<SDMoodEntry>
        
        if let from = from, let to = to {
            predicate = #Predicate<SDMoodEntry> { entry in
                entry.userID == userID && entry.date >= from && entry.date <= to
            }
        } else {
            predicate = #Predicate<SDMoodEntry> { entry in
                entry.userID == userID
            }
        }
        
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let sdEntries = try modelContext.fetch(descriptor)
        return sdEntries.map { fromSwiftData($0) }
    }
    
    // MARK: - HealthKit (iOS 18+)
    
    @available(iOS 18.0, *)
    func saveToHealthKit(moodEntry: MoodEntry) async throws {
        let stateOfMind = moodEntry.toHKStateOfMind()
        try await healthKitAdapter.saveStateOfMind(stateOfMind)
    }
    
    @available(iOS 18.0, *)
    func fetchFromHealthKit(from: Date, to: Date) async throws -> [MoodEntry] {
        let statesOfMind = try await healthKitAdapter.fetchStatesOfMind(from: from, to: to)
        // Need userID - get from authManager or pass as parameter
        return statesOfMind.map { MoodEntry(from: $0, userID: "TODO") }
    }
    
    // MARK: - Conversion Helpers
    
    private func toSwiftData(_ entry: MoodEntry, userID: String) -> SDMoodEntry {
        return SDMoodEntry(
            id: entry.id,
            userID: userID,
            date: entry.date,
            score: entry.score,
            valence: entry.valence,
            labelsJSON: encodeLabels(entry.labels),
            associationsJSON: encodeAssociations(entry.associations),
            notes: entry.notes,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            sourceType: entry.sourceType.rawValue,
            backendID: entry.backendID,
            syncStatus: entry.syncStatus.rawValue
        )
    }
    
    private func fromSwiftData(_ sd: SDMoodEntry) -> MoodEntry {
        return MoodEntry(
            id: sd.id,
            userID: sd.userID,
            date: sd.date,
            score: sd.score,
            valence: sd.valence,
            labels: decodeLabels(sd.labelsJSON),
            associations: decodeAssociations(sd.associationsJSON),
            notes: sd.notes,
            createdAt: sd.createdAt,
            updatedAt: sd.updatedAt,
            sourceType: MoodSourceType(rawValue: sd.sourceType) ?? .userEntry,
            backendID: sd.backendID,
            syncStatus: SyncStatus(rawValue: sd.syncStatus) ?? .pending
        )
    }
    
    private func encodeLabels(_ labels: [MoodLabel]) -> String {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(labels.map(\.rawValue))
        return String(data: data ?? Data(), encoding: .utf8) ?? "[]"
    }
    
    private func decodeLabels(_ json: String) -> [MoodLabel] {
        guard let data = json.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let rawValues = try? decoder.decode([String].self, from: data)
        return rawValues?.compactMap { MoodLabel(rawValue: $0) } ?? []
    }
    
    private func encodeAssociations(_ associations: [MoodAssociation]) -> String {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(associations.map(\.rawValue))
        return String(data: data ?? Data(), encoding: .utf8) ?? "[]"
    }
    
    private func decodeAssociations(_ json: String) -> [MoodAssociation] {
        guard let data = json.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let rawValues = try? decoder.decode([String].self, from: data)
        return rawValues?.compactMap { MoodAssociation(rawValue: $0) } ?? []
    }
}
```

### Step 5: Extend HealthKitAdapter

**File:** `Infrastructure/Integration/HealthKitAdapter+Mood.swift`

```swift
import HealthKit

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
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stateOfMindType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
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

### Step 6: Update HealthKit Authorization

**File:** `Domain/UseCases/HealthKit/RequestHealthKitAuthorizationUseCase.swift`

```swift
// In the write types array, add (iOS 18+):
if #available(iOS 18.0, *) {
    writeTypes.append(HKObjectType.stateOfMindType())
}

// In the read types array, add (iOS 18+):
if #available(iOS 18.0, *) {
    readTypes.append(HKObjectType.stateOfMindType())
}
```

### Step 7: Register in AppDependencies

**File:** `Infrastructure/Configuration/AppDependencies.swift`

```swift
// 1. Add property
let moodRepository: MoodRepositoryProtocol
let saveMoodUseCase: SaveMoodUseCase

// 2. In init, add parameters
// 3. In init body, assign dependencies

// 4. In build() method, create instances:
let moodRepository = SwiftDataMoodRepository(
    modelContext: modelContext,
    healthKitAdapter: healthRepository as! HealthKitAdapter,
    outboxRepository: outboxRepository
)

let saveMoodUseCase = SaveMoodUseCaseImpl(
    moodRepository: moodRepository,
    authManager: authManager
)
```

### Step 8: Add Outbox Event Type

**File:** `Domain/Entities/Outbox/OutboxEventType.swift` (or wherever it's defined)

```swift
enum OutboxEventType: String, Codable {
    case progressCreated
    case sleepCreated
    case moodCreated  // ← Add this
    // ... existing cases
}
```

---

## 🧪 Testing the Translation

```swift
import XCTest
@testable import FitIQ

final class MoodTranslationTests: XCTestCase {
    
    func testScoreToValence() {
        XCTAssertEqual(MoodTranslationUtility.scoreToValence(1), -1.0, accuracy: 0.01)
        XCTAssertEqual(MoodTranslationUtility.scoreToValence(5), -0.11, accuracy: 0.01)
        XCTAssertEqual(MoodTranslationUtility.scoreToValence(6), 0.11, accuracy: 0.01)
        XCTAssertEqual(MoodTranslationUtility.scoreToValence(10), 1.0, accuracy: 0.01)
    }
    
    func testValenceToScore() {
        XCTAssertEqual(MoodTranslationUtility.valenceToScore(-1.0), 1)
        XCTAssertEqual(MoodTranslationUtility.valenceToScore(-0.11), 5)
        XCTAssertEqual(MoodTranslationUtility.valenceToScore(0.11), 6)
        XCTAssertEqual(MoodTranslationUtility.valenceToScore(1.0), 10)
    }
    
    func testRoundTrip() {
        for score in 1...10 {
            let valence = MoodTranslationUtility.scoreToValence(score)
            let converted = MoodTranslationUtility.valenceToScore(valence)
            XCTAssertEqual(converted, score, "Score \(score) should round-trip")
        }
    }
    
    func testLabelSelection() {
        let labels1 = MoodTranslationUtility.labelsForScore(1, notes: nil)
        XCTAssertTrue(labels1.contains(.sad))
        
        let labels8 = MoodTranslationUtility.labelsForScore(8, notes: nil)
        XCTAssertTrue(labels8.contains(.happy))
    }
    
    func testAssociationInference() {
        let associations = MoodTranslationUtility.associationsFromNotes("Great workout today!")
        XCTAssertTrue(associations.contains(.fitness))
    }
}
```

---

## 📱 Example Usage

### Save mood from user input:

```swift
let saveMoodUseCase = dependencies.saveMoodUseCase

// Simple: Just score and notes
let id = try await saveMoodUseCase.execute(
    score: 8,
    labels: nil,  // Auto-selected: [.happy, .confident]
    associations: nil,  // Auto-inferred from notes
    notes: "Great workout today!",
    date: Date()
)

// Advanced: With custom labels and associations
let id = try await saveMoodUseCase.execute(
    score: 8,
    labels: [.excited, .grateful],
    associations: [.fitness, .selfCare],
    notes: "Great workout today!",
    date: Date()
)
```

### Save mood from HealthKit (iOS 18+):

```swift
if #available(iOS 18.0, *) {
    let stateOfMind = HKStateOfMind(
        date: Date(),
        kind: .momentaryEmotion,
        valence: 0.6,
        labels: [.happy, .confident],
        associations: [.fitness]
    )
    
    let id = try await saveMoodUseCase.execute(from: stateOfMind)
    // Automatically converts valence to score: 0.6 → 8
}
```

---

## 🎨 UI Integration (Phase 3)

Will create a modern SwiftUI interface:

```swift
struct MoodEntryView: View {
    @State private var selectedScore: Int = 5
    @State private var notes: String = ""
    @State private var selectedLabels: Set<MoodLabel> = []
    
    var body: some View {
        VStack {
            // Score slider with emoji
            MoodSlider(score: $selectedScore)
            
            // Label picker (optional)
            MoodLabelPicker(
                score: selectedScore,
                selectedLabels: $selectedLabels
            )
            
            // Notes field
            TextField("How are you feeling?", text: $notes)
            
            Button("Save") {
                Task {
                    await viewModel.saveMood(
                        score: selectedScore,
                        labels: Array(selectedLabels),
                        notes: notes
                    )
                }
            }
        }
    }
}
```

---

## 📊 Backend API Integration

Uses existing `/api/v1/progress` endpoint:

```bash
# Save mood
POST /api/v1/progress
{
  "type": "mood_score",
  "quantity": 8,
  "logged_at": "2025-01-27T10:30:00Z",
  "notes": "Feeling great today!"
}

# Fetch mood history
GET /api/v1/progress?type=mood_score&from=2025-01-01&to=2025-01-31
```

Backend receives 1-10 score (no changes needed on backend).

---

## 🚀 Deployment Checklist

- [ ] Phase 2 complete (infrastructure)
- [ ] Unit tests passing (translation, use cases)
- [ ] Integration tests passing (SwiftData, HealthKit)
- [ ] Schema migration tested (V4 → V5)
- [ ] HealthKit authorization working (iOS 18+)
- [ ] Outbox Pattern processing mood events
- [ ] Backend sync verified
- [ ] UI implemented and tested
- [ ] Update minimum iOS version if required
- [ ] Release notes written

---

## 📚 Resources

- **Design Doc:** `docs/features/MOOD_TRACKING_HKSTATEOFMIND_REDESIGN.md`
- **Phase 1 Summary:** `docs/implementation-summaries/MOOD_TRACKING_PHASE1_COMPLETE.md`
- **Apple HKStateOfMind:** https://developer.apple.com/documentation/healthkit/hkstateofmind
- **Backend API:** `docs/be-api-spec/swagger.yaml`

---

**Ready to continue with Phase 2! 🚀**