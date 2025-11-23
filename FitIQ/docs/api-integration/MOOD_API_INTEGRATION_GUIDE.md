# Mood API Integration Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**iOS Version:** 18.0+  
**API Endpoint:** `/api/v1/mood`

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [HKStateOfMind Integration](#hkstateofmind-integration)
3. [API Endpoints](#api-endpoints)
4. [Data Model](#data-model)
5. [iOS Implementation](#ios-implementation)
6. [Backend Integration](#backend-integration)
7. [Analytics & Insights](#analytics--insights)
8. [Migration Strategy](#migration-strategy)
9. [Best Practices](#best-practices)

---

## 🎯 Overview

The Mood API provides comprehensive mood tracking capabilities with first-class support for iOS 18+ `HKStateOfMind` while maintaining backward compatibility with legacy mood scoring systems.

### Key Features

- ✅ **HKStateOfMind Support**: Native integration with iOS 18+ HealthKit mood data
- ✅ **Valence-Based Tracking**: Continuous pleasantness scale (-1.0 to +1.0)
- ✅ **Categorical Labels**: Descriptive mood labels (e.g., "happy", "stressed")
- ✅ **Contextual Associations**: Environmental triggers (e.g., "work", "exercise")
- ✅ **Deduplication**: Source-based deduplication prevents HealthKit duplicates
- ✅ **Analytics**: Trend analysis, label frequency, association impact
- ✅ **Backward Compatibility**: Legacy 1-10 mood score support

### Design Philosophy

1. **HealthKit-First**: API designed around `HKStateOfMind` structure
2. **Flexibility**: Supports partial data (valence-only, labels-only, or combined)
3. **Idempotency**: Safe retry logic with source_id deduplication
4. **Read-Only HealthKit**: HealthKit entries cannot be modified/deleted to preserve data integrity
5. **Privacy**: User-specific data with proper authentication

---

## 🍎 HKStateOfMind Integration

### iOS 18+ API Mapping

The API directly maps to `HKStateOfMind` properties:

| HKStateOfMind Property | API Field | Description |
|------------------------|-----------|-------------|
| `valence` | `valence` | Float (-1.0 to +1.0) pleasantness scale |
| `labels` | `labels` | Array of mood descriptors |
| `associations` | `associations` | Array of contextual triggers |
| - | `logged_at` | Timestamp (from HKStateOfMind.startDate) |
| - | `source_id` | HKStateOfMind.uuid.uuidString for deduplication |

### Sample HKStateOfMind Data

```swift
// iOS 18+ HealthKit
let stateOfMind = HKStateOfMind(
    date: Date(),
    kind: .momentaryEmotion,
    valence: 0.65,
    labels: [.happy, .energetic, .content],
    associations: [.fitness, .socialInteraction]
)

// API Payload
{
  "valence": 0.65,
  "labels": ["happy", "energetic", "content"],
  "associations": ["exercise", "social"],
  "logged_at": "2024-01-15T14:30:00Z",
  "source": "healthkit",
  "source_id": "HK-MOOD-550e8400-e29b-41d4-a716-446655440000"
}
```

---

## 📡 API Endpoints

### 1. Create Mood Entry

**POST** `/api/v1/mood`

Create a new mood entry with valence, labels, and/or associations.

#### Request Body

```json
{
  "valence": 0.6,
  "labels": ["happy", "energetic"],
  "associations": ["exercise", "social"],
  "logged_at": "2024-01-15T14:30:00Z",
  "source": "healthkit",
  "source_id": "HK-MOOD-550e8400-e29b-41d4-a716-446655440000",
  "notes": "Felt great after morning workout"
}
```

#### Response (201 Created)

```json
{
  "success": true,
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "user-uuid",
    "valence": 0.6,
    "labels": ["happy", "energetic"],
    "associations": ["exercise", "social"],
    "logged_at": "2024-01-15T14:30:00Z",
    "source": "healthkit",
    "source_id": "HK-MOOD-550e8400-e29b-41d4-a716-446655440000",
    "notes": "Felt great after morning workout",
    "created_at": "2024-01-15T14:30:05Z",
    "updated_at": null
  }
}
```

#### Validation Rules

- At least one of `valence`, `labels`, or `mood_score` (legacy) must be provided
- `valence` must be between -1.0 and +1.0
- `labels` array must contain at least 1 item (if provided)
- `logged_at` defaults to current time if omitted
- `source_id` enables deduplication (recommended for HealthKit)

---

### 2. Get Mood Entries

**GET** `/api/v1/mood`

Retrieve mood entries with filtering and pagination.

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `from` | date | Start date (YYYY-MM-DD), defaults to 30 days ago |
| `to` | date | End date (YYYY-MM-DD), defaults to today |
| `source` | enum | Filter by source: `healthkit`, `manual`, `ai_analysis` |
| `label` | string | Filter by specific label (exact match) |
| `association` | string | Filter by specific association (exact match) |
| `min_valence` | float | Filter entries with valence >= this value |
| `max_valence` | float | Filter entries with valence <= this value |
| `limit` | int | Results per page (1-100, default: 30) |
| `offset` | int | Pagination offset (default: 0) |

#### Example Request

```
GET /api/v1/mood?from=2024-01-01&to=2024-01-31&label=happy&limit=20
```

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "entries": [
      {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "valence": 0.6,
        "labels": ["happy", "energetic"],
        "associations": ["exercise"],
        "logged_at": "2024-01-15T14:30:00Z",
        "source": "healthkit"
      }
    ],
    "total": 45,
    "limit": 20,
    "offset": 0,
    "has_more": true
  }
}
```

---

### 3. Get Daily Aggregate

**GET** `/api/v1/mood/daily/{date}`

Get aggregated mood data for a specific day.

#### Example Request

```
GET /api/v1/mood/daily/2024-01-15?include_entries=true
```

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "date": "2024-01-15",
    "entry_count": 5,
    "average_valence": 0.45,
    "valence_range": {
      "min": -0.2,
      "max": 0.8
    },
    "top_labels": [
      { "label": "happy", "count": 3 },
      { "label": "energetic", "count": 2 }
    ],
    "top_associations": [
      { "association": "exercise", "count": 2 },
      { "association": "social", "count": 2 }
    ],
    "entries": [...]
  }
}
```

---

### 4. Get Mood Trends

**GET** `/api/v1/mood/trends`

Retrieve daily mood aggregates over a date range for trend analysis.

#### Example Request

```
GET /api/v1/mood/trends?from=2024-01-01&to=2024-01-31
```

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "start_date": "2024-01-01",
    "end_date": "2024-01-31",
    "total_entries": 125,
    "average_valence": 0.35,
    "trend_direction": "improving",
    "valence_statistics": {
      "min": -0.8,
      "max": 0.9,
      "median": 0.4,
      "std_deviation": 0.32
    },
    "daily_data": [
      {
        "date": "2024-01-01",
        "entry_count": 3,
        "average_valence": 0.2,
        "top_labels": [...]
      }
    ]
  }
}
```

---

### 5. Label Analytics

**GET** `/api/v1/mood/analytics/labels`

Analyze label usage frequency and valence correlation.

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "period": {
      "from": "2024-01-01",
      "to": "2024-01-31"
    },
    "total_entries": 125,
    "unique_labels": 18,
    "top_labels": [
      {
        "label": "happy",
        "count": 45,
        "percentage": 36.0,
        "average_valence": 0.72
      },
      {
        "label": "stressed",
        "count": 32,
        "percentage": 25.6,
        "average_valence": -0.45
      }
    ]
  }
}
```

---

### 6. Association Analytics

**GET** `/api/v1/mood/analytics/associations`

Analyze association usage frequency and mood impact.

#### Response (200 OK)

```json
{
  "success": true,
  "data": {
    "period": {
      "from": "2024-01-01",
      "to": "2024-01-31"
    },
    "total_entries": 125,
    "unique_associations": 12,
    "top_associations": [
      {
        "association": "exercise",
        "count": 38,
        "percentage": 30.4,
        "average_valence": 0.68,
        "valence_impact": "positive"
      },
      {
        "association": "work",
        "count": 42,
        "percentage": 33.6,
        "average_valence": -0.22,
        "valence_impact": "negative"
      }
    ]
  }
}
```

---

## 💾 Data Model

### SwiftData Model (iOS)

```swift
@Model
final class SDMoodEntry {
    var id: UUID = UUID()
    var userProfile: SDUserProfile?
    var userID: String = ""
    
    // HKStateOfMind properties
    var valence: Double?  // -1.0 to +1.0
    var labels: [String] = []
    var associations: [String] = []
    
    // Metadata
    var date: Date = Date()
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date?
    
    // Backend sync
    var backendID: String?
    var syncStatus: String = "pending"
    
    // Deduplication
    var sourceID: String?
    
    init(
        id: UUID = UUID(),
        userProfile: SDUserProfile? = nil,
        userID: String,
        valence: Double?,
        labels: [String],
        associations: [String],
        date: Date = Date(),
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: String = "pending",
        sourceID: String? = nil
    ) {
        self.id = id
        self.userProfile = userProfile
        self.userID = userID
        self.valence = valence
        self.labels = labels
        self.associations = associations
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
        self.sourceID = sourceID
    }
}
```

### Domain Model (iOS)

```swift
struct MoodEntry {
    let id: UUID
    let userID: String
    let valence: Double?
    let labels: [String]
    let associations: [String]
    let date: Date
    let notes: String?
    let createdAt: Date
    let updatedAt: Date?
    let backendID: String?
    let syncStatus: SyncStatus
    let sourceID: String?
}
```

---

## 📱 iOS Implementation

### 1. HealthKit Authorization

```swift
// Request HKStateOfMind authorization
let moodType = HKObjectType.categoryType(forIdentifier: .stateOfMind)!

healthStore.requestAuthorization(toShare: [], read: [moodType]) { success, error in
    if success {
        // Start syncing mood data
    }
}
```

### 2. Fetch HKStateOfMind Data

```swift
import HealthKit

func fetchStateOfMind(from startDate: Date, to endDate: Date) async throws -> [HKStateOfMind] {
    guard let stateOfMindType = HKObjectType.categoryType(forIdentifier: .stateOfMind) else {
        throw HealthKitError.typeNotAvailable
    }
    
    let predicate = HKQuery.predicateForSamples(
        withStart: startDate,
        end: endDate,
        options: .strictStartDate
    )
    
    let sortDescriptor = NSSortDescriptor(
        key: HKSampleSortIdentifierStartDate,
        ascending: false
    )
    
    let query = HKSampleQuery(
        sampleType: stateOfMindType,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sortDescriptor]
    ) { query, samples, error in
        // Process samples
    }
    
    healthStore.execute(query)
}
```

### 3. Convert HKStateOfMind to API Payload

```swift
extension HKStateOfMind {
    func toMoodEntryRequest() -> MoodEntryRequest {
        MoodEntryRequest(
            valence: self.valence,
            labels: self.labels.map { label in
                // Convert HKStateOfMind.Label to string
                label.rawValue.lowercased()
            },
            associations: self.associations.map { association in
                // Convert HKStateOfMind.Association to string
                association.rawValue.lowercased()
            },
            loggedAt: self.startDate,
            source: "healthkit",
            sourceID: "HK-MOOD-\(self.uuid.uuidString)",
            notes: nil
        )
    }
}
```

### 4. Sync to Backend with Outbox Pattern

```swift
// Use Case: Save Mood Entry
final class SaveMoodEntryUseCase {
    private let moodRepository: MoodRepositoryProtocol
    private let authManager: AuthManagerProtocol
    
    func execute(
        valence: Double?,
        labels: [String],
        associations: [String],
        date: Date = Date(),
        sourceID: String? = nil,
        notes: String? = nil
    ) async throws -> UUID {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw MoodError.userNotAuthenticated
        }
        
        // Create mood entry with .pending sync status
        let moodEntry = MoodEntry(
            id: UUID(),
            userID: userID,
            valence: valence,
            labels: labels,
            associations: associations,
            date: date,
            notes: notes,
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending,
            sourceID: sourceID
        )
        
        // Save locally - this triggers Outbox Pattern automatically
        let localID = try await moodRepository.save(
            moodEntry: moodEntry,
            forUserID: userID
        )
        
        return localID
    }
}
```

### 5. Repository Implementation

```swift
final class SwiftDataMoodRepository: MoodRepositoryProtocol {
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol
    
    func save(moodEntry: MoodEntry, forUserID: String) async throws -> UUID {
        // 1. Convert to SwiftData model
        let sdEntry = SDMoodEntry(
            id: moodEntry.id,
            userID: forUserID,
            valence: moodEntry.valence,
            labels: moodEntry.labels,
            associations: moodEntry.associations,
            date: moodEntry.date,
            notes: moodEntry.notes,
            syncStatus: moodEntry.syncStatus.rawValue,
            sourceID: moodEntry.sourceID
        )
        
        // 2. Save to SwiftData
        modelContext.insert(sdEntry)
        try modelContext.save()
        
        // 3. ✅ OUTBOX PATTERN: Create outbox event for backend sync
        let outboxEvent = try await outboxRepository.createEvent(
            eventType: .moodCreated,
            entityID: moodEntry.id,
            userID: forUserID,
            isNewRecord: moodEntry.backendID == nil,
            metadata: nil,
            priority: 5
        )
        
        return moodEntry.id
    }
}
```

---

## 🔧 Backend Integration

### Database Schema (PostgreSQL)

```sql
CREATE TABLE mood_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    valence DOUBLE PRECISION CHECK (valence >= -1.0 AND valence <= 1.0),
    labels TEXT[] NOT NULL DEFAULT '{}',
    associations TEXT[] NOT NULL DEFAULT '{}',
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    source VARCHAR(50) DEFAULT 'manual',
    source_id VARCHAR(255) UNIQUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT at_least_one_data CHECK (
        valence IS NOT NULL OR 
        array_length(labels, 1) > 0
    ),
    
    CONSTRAINT valid_labels CHECK (
        array_length(labels, 1) <= 10
    ),
    
    CONSTRAINT valid_associations CHECK (
        array_length(associations, 1) <= 10
    )
);

CREATE INDEX idx_mood_user_logged_at ON mood_entries(user_id, logged_at DESC);
CREATE INDEX idx_mood_source_id ON mood_entries(source_id);
CREATE INDEX idx_mood_labels ON mood_entries USING GIN(labels);
CREATE INDEX idx_mood_associations ON mood_entries USING GIN(associations);
```

### Backend Handler (Go Example)

```go
func (h *MoodHandler) CreateMoodEntry(c *gin.Context) {
    var req MoodEntryRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, ErrorResponse{Error: err.Error()})
        return
    }
    
    userID := c.GetString("user_id")
    
    // Check for duplicate source_id (idempotency)
    if req.SourceID != nil {
        existing, err := h.moodRepo.FindBySourceID(*req.SourceID, userID)
        if err == nil && existing != nil {
            // Return existing entry
            c.JSON(200, StandardResponse{
                Success: true,
                Data: existing,
            })
            return
        }
    }
    
    // Validate
    if err := h.validateMoodEntry(&req); err != nil {
        c.JSON(400, ErrorResponse{Error: err.Error()})
        return
    }
    
    // Create entry
    entry := &MoodEntry{
        ID: uuid.New(),
        UserID: userID,
        Valence: req.Valence,
        Labels: req.Labels,
        Associations: req.Associations,
        LoggedAt: req.LoggedAt.Or(time.Now()),
        Source: req.Source.Or("manual"),
        SourceID: req.SourceID,
        Notes: req.Notes,
        CreatedAt: time.Now(),
    }
    
    if err := h.moodRepo.Create(entry); err != nil {
        c.JSON(500, ErrorResponse{Error: "Failed to create mood entry"})
        return
    }
    
    c.JSON(201, StandardResponse{
        Success: true,
        Data: entry,
    })
}
```

---

## 📊 Analytics & Insights

### Trend Analysis

The API provides trend direction based on valence changes:

- **Improving**: Average valence increasing over time
- **Stable**: Consistent valence with low variation
- **Declining**: Average valence decreasing over time
- **Insufficient Data**: Not enough entries to determine trend

### Label Correlation

Track which labels correlate with positive/negative mood:

```json
{
  "label": "exercise",
  "average_valence": 0.68,
  "interpretation": "Exercise strongly correlates with positive mood"
}
```

### Association Impact

Identify mood triggers:

```json
{
  "association": "work",
  "average_valence": -0.22,
  "valence_impact": "negative",
  "recommendation": "Consider stress management strategies for work-related situations"
}
```

---

## 🔄 Migration Strategy

### From Legacy Mood Score (1-10)

The API supports automatic conversion:

**Legacy Request:**
```json
{
  "mood_score": 8,
  "notes": "Feeling great"
}
```

**Conversion Formula:**
```
valence = (mood_score - 5.5) / 4.5

Examples:
- mood_score: 1  → valence: -1.0 (very unpleasant)
- mood_score: 5  → valence: -0.11 (slightly unpleasant)
- mood_score: 6  → valence: 0.11 (slightly pleasant)
- mood_score: 10 → valence: 1.0 (very pleasant)
```

### Migration Path

1. **Phase 1**: Support both `mood_score` and `valence` in API
2. **Phase 2**: iOS app migrates to HKStateOfMind (iOS 18+)
3. **Phase 3**: Convert existing mood scores to valence in database
4. **Phase 4**: Deprecate `mood_score` field (keep for read-only)

---

## ✅ Best Practices

### 1. Always Use source_id for HealthKit

```swift
// ✅ CORRECT - Prevents duplicates
let sourceID = "HK-MOOD-\(stateOfMind.uuid.uuidString)"
saveMoodUseCase.execute(sourceID: sourceID, ...)

// ❌ WRONG - Can create duplicates
saveMoodUseCase.execute(sourceID: nil, ...)
```

### 2. Trust the Outbox Pattern

```swift
// ✅ CORRECT - Repository handles sync automatically
try await moodRepository.save(moodEntry: entry, forUserID: userID)

// ❌ WRONG - Don't manually sync
try await moodRepository.save(...)
try await networkClient.syncMood(...)  // Outbox does this
```

### 3. Check Sync Status

```swift
// Monitor sync status
if moodEntry.syncStatus == .failed {
    // Outbox will retry automatically, but you can show UI feedback
    showSyncWarning()
}
```

### 4. Validate Labels & Associations

```swift
// ✅ CORRECT - Normalize and validate
let labels = rawLabels
    .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty && $0.count <= 50 }
    .prefix(10)  // Max 10 labels

// ❌ WRONG - Send raw input
let labels = userInput.split(separator: ",")  // Might be invalid
```

### 5. Handle iOS Version Compatibility

```swift
if #available(iOS 18.0, *) {
    // Use HKStateOfMind
    let stateOfMind = try await fetchStateOfMind()
    await syncMoodFromHealthKit(stateOfMind)
} else {
    // Fallback to manual entry or legacy system
    showManualMoodEntry()
}
```

### 6. Provide Meaningful Notes

```swift
// ✅ GOOD - Contextual notes
"Felt energized after 5K run and brunch with Sarah"

// ❌ POOR - Generic notes
"Good mood"
```

### 7. Batch Sync for Performance

```swift
// Fetch historical data in batches
let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
let stateOfMindEntries = try await fetchStateOfMind(from: thirtyDaysAgo, to: Date())

// Sync in background
for entry in stateOfMindEntries {
    try await saveMoodUseCase.execute(from: entry)
}
```

---

## 🔒 Security & Privacy

### Authentication

All endpoints require both:
- **X-API-Key** header (API key)
- **Authorization** header (Bearer JWT token)

### Data Privacy

- Users can only access their own mood data
- HealthKit entries are read-only (cannot be modified/deleted via API)
- Manual entries can be updated/deleted by the owner
- `source_id` is never exposed to other users

### Rate Limiting

Recommended rate limits:
- **POST /api/v1/mood**: 100 requests/hour
- **GET /api/v1/mood**: 500 requests/hour
- **Analytics endpoints**: 100 requests/hour

---

## 📚 Additional Resources

- [Apple HKStateOfMind Documentation](https://developer.apple.com/documentation/healthkit/hkstateofmind)
- [FitIQ API Specification](../be-api-spec/swagger.yaml)
- [iOS Integration Handoff](../IOS_INTEGRATION_HANDOFF.md)
- [Outbox Pattern Guide](../architecture/OUTBOX_PATTERN.md)

---

## 🤝 Support

For questions or issues:
1. Check the [API specification](./mood-api-spec.yaml)
2. Review existing patterns in `/api/v1/sleep` endpoint
3. Consult the iOS integration examples above
4. Contact the backend team for API changes

---

**Version:** 1.0.0  
**Status:** ✅ Ready for Implementation  
**Last Updated:** 2025-01-27