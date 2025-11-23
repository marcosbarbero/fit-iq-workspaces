# Lume Outbox Pattern Migration Plan

**Date:** 2025-01-27  
**Project:** Lume iOS App  
**Based On:** Successful FitIQ migration (completed 2025-01-27)  
**Status:** 📋 **PLANNED**

---

## Executive Summary

Migrate Lume's legacy, stringly-typed Outbox Pattern implementation to the unified, type-safe FitIQCore implementation. This migration will eliminate technical debt, improve type safety, and align Lume with FitIQ's proven architecture.

**Timeline:** 1-2 days  
**Risk:** Low (proven patterns from FitIQ)  
**Prerequisites:** FitIQ migration complete ✅

---

## Current State Analysis

### Lume's Current Outbox Implementation

**Location:** `lume/Data/Repositories/SwiftDataOutboxRepository.swift`

**Characteristics:**
- ✅ Basic outbox pattern implemented
- ❌ Stringly-typed (`eventType: String`, `status: String`)
- ❌ Binary payload (`payload: Data`)
- ❌ No structured metadata
- ❌ Simple implementation (lacks advanced features)
- ❌ Duplicated code (not shared with FitIQ)

**Schema:** `SchemaVersioning.swift` (V1, V2, V3)
```swift
@Model
final class SDOutboxEvent {
    var id: UUID
    var createdAt: Date
    var eventType: String        // ❌ Stringly-typed
    var payload: Data            // ❌ Binary blob
    var status: String           // ❌ Stringly-typed
    var retryCount: Int
    var lastAttemptAt: Date?
    var completedAt: Date?
    var errorMessage: String?
    // ...
}
```

### FitIQCore Target Implementation

**Characteristics:**
- ✅ Type-safe enums (`OutboxEventType`, `OutboxEventStatus`, `OutboxMetadata`)
- ✅ Structured metadata (no binary payloads)
- ✅ Comprehensive error handling
- ✅ Swift 6 compliant
- ✅ Production-tested (FitIQ)
- ✅ Shared across both apps

**Schema:** FitIQCore domain model
```swift
public struct OutboxEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let eventType: OutboxEventType        // ✅ Type-safe enum
    public let entityID: UUID
    public let userID: String
    public var status: OutboxEventStatus         // ✅ Type-safe enum
    public let createdAt: Date
    public var lastAttemptAt: Date?
    public var attemptCount: Int
    public let maxAttempts: Int
    public var errorMessage: String?
    public var completedAt: Date?
    public var metadata: OutboxMetadata?         // ✅ Type-safe enum
    public let priority: Int
    public let isNewRecord: Bool
}
```

---

## Migration Strategy

### Phase 1: Setup & Dependencies (30 minutes)

#### 1.1 Link FitIQCore to Lume Project
- Add FitIQCore as local Swift package dependency
- Verify FitIQCore builds for Lume
- Import FitIQCore in repository files

#### 1.2 Create Documentation Directory
```
lume/docs/
└── outbox-migration/
    ├── MIGRATION_PLAN.md (this file)
    ├── MIGRATION_LOG.md (track progress)
    └── DEVELOPER_GUIDE.md (post-migration)
```

---

### Phase 2: Adapter Pattern Implementation (1-2 hours)

#### 2.1 Create OutboxEventAdapter
**File:** `lume/Data/Persistence/Adapters/OutboxEventAdapter.swift`

**Purpose:** Convert between Lume's SwiftData models and FitIQCore domain models

**Pattern:** Exact same as FitIQ's adapter
```swift
struct OutboxEventAdapter {
    // Domain → SwiftData
    static func toSwiftData(_ domain: OutboxEvent) -> SDOutboxEvent
    
    // SwiftData → Domain
    static func toDomain(_ swiftData: SDOutboxEvent) throws -> OutboxEvent
    
    // Batch conversions
    static func toDomainArray(_ swiftDataEvents: [SDOutboxEvent]) -> [OutboxEvent]
    static func toSwiftDataArray(_ domainEvents: [OutboxEvent]) -> [SDOutboxEvent]
    
    // Update operations
    static func updateSwiftData(_ swiftData: SDOutboxEvent, from domain: OutboxEvent)
}
```

**Key Differences from FitIQ:**
- Lume uses `payload: Data` → Must convert to `metadata: OutboxMetadata?`
- Need migration strategy for existing events

#### 2.2 Data Migration Strategy

**Challenge:** Convert existing `payload: Data` to `OutboxMetadata`

**Options:**

**Option A: Lossy Migration (Recommended)**
- Mark all existing events as generic metadata
- Process and complete existing events quickly
- New events use type-safe metadata
```swift
// Migration helper
private static func migratePayload(_ payload: Data, eventType: String) -> OutboxMetadata? {
    // Try to decode as JSON if possible
    if let json = try? JSONSerialization.jsonObject(with: payload) as? [String: String] {
        return .generic(json)
    }
    return nil  // Legacy events processed without metadata
}
```

**Option B: Best-Effort Migration**
- Attempt to parse payload based on event type
- Fall back to generic metadata if parsing fails
- More complex but preserves more data

**Recommendation:** Start with Option A, add Option B if needed

---

### Phase 3: Schema Migration (1 hour)

#### 3.1 Create New Schema Version

**File:** `lume/Data/Persistence/SchemaVersioning.swift`

Add `SchemaV4` with updated `SDOutboxEvent`:
```swift
enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 4)
    
    // Reuse unchanged models
    typealias SDJournalEntry = SchemaV3.SDJournalEntry
    typealias SDMoodEntry = SchemaV3.SDMoodEntry
    // ... other models
    
    // NEW: Updated SDOutboxEvent
    @Model
    final class SDOutboxEvent {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var eventType: String = ""           // Still string (adapter converts)
        var entityID: UUID = UUID()          // NEW
        var userID: String = ""              // NEW
        var status: String = "pending"       // Still string (adapter converts)
        var lastAttemptAt: Date?
        var attemptCount: Int = 0            // RENAMED from retryCount
        var maxAttempts: Int = 5             // NEW
        var errorMessage: String?
        var completedAt: Date?
        var metadata: String?                // NEW (JSON string)
        var priority: Int = 0                // NEW
        var isNewRecord: Bool = true         // NEW
        
        init(
            id: UUID = UUID(),
            eventType: String,
            entityID: UUID,
            userID: String,
            status: String = "pending",
            createdAt: Date = Date(),
            lastAttemptAt: Date? = nil,
            attemptCount: Int = 0,
            maxAttempts: Int = 5,
            errorMessage: String? = nil,
            completedAt: Date? = nil,
            metadata: String? = nil,
            priority: Int = 0,
            isNewRecord: Bool = true
        ) {
            self.id = id
            self.eventType = eventType
            self.entityID = entityID
            self.userID = userID
            self.status = status
            self.createdAt = createdAt
            self.lastAttemptAt = lastAttemptAt
            self.attemptCount = attemptCount
            self.maxAttempts = maxAttempts
            self.errorMessage = errorMessage
            self.completedAt = completedAt
            self.metadata = metadata
            self.priority = priority
            self.isNewRecord = isNewRecord
        }
    }
    
    static var models: [any PersistentModel.Type] {
        [
            SDJournalEntry.self,
            SDMoodEntry.self,
            SDOutboxEvent.self,
            // ... other models
        ]
    }
}
```

#### 3.2 Update Current Schema Alias
```swift
// Change from SchemaV3 to SchemaV4
typealias CurrentSchema = SchemaV4
```

#### 3.3 Add Migration Plan
```swift
enum SchemaVersioning {
    static var versionedSchema: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    }
    
    static var migrationPlan: SchemaMigrationPlan {
        SchemaMigrationPlan([
            // ... existing migrations
            MigrateV3toV4()
        ])
    }
}

// Migration from V3 to V4
struct MigrateV3toV4: SchemaMigrationStage {
    var label: String { "Migrate outbox to type-safe format" }
    
    func willMigrate(_ context: ModelContext) throws {
        // Optional: Clean up old events before migration
        print("Starting V3→V4 migration: Outbox Pattern upgrade")
    }
    
    func didMigrate(_ context: ModelContext) throws {
        // Optional: Validate migration
        print("Completed V3→V4 migration")
    }
}
```

---

### Phase 4: Repository Migration (2 hours)

#### 4.1 Update SwiftDataOutboxRepository

**File:** `lume/Data/Repositories/SwiftDataOutboxRepository.swift`

**Changes:**
1. Import FitIQCore
2. Change protocol to match FitIQCore's `OutboxRepositoryProtocol`
3. Use adapter for all conversions
4. Update method signatures
5. Add proper error handling

**Before (Legacy):**
```swift
func createEvent(type: String, payload: Data) async throws {
    let event = SDOutboxEvent(
        eventType: type,
        payload: payload,
        status: OutboxEventStatus.pending.rawValue
    )
    modelContext.insert(event)
    try modelContext.save()
}
```

**After (Type-Safe):**
```swift
func createEvent(
    eventType: FitIQCore.OutboxEventType,
    entityID: UUID,
    userID: String,
    isNewRecord: Bool,
    metadata: FitIQCore.OutboxMetadata?,
    priority: Int
) async throws -> FitIQCore.OutboxEvent {
    let sdEvent = SDOutboxEvent(
        eventType: eventType.rawValue,
        entityID: entityID,
        userID: userID,
        status: FitIQCore.OutboxEventStatus.pending.rawValue,
        metadata: encodeMetadata(metadata),
        priority: priority,
        isNewRecord: isNewRecord
    )
    
    modelContext.insert(sdEvent)
    try modelContext.save()
    
    return try sdEvent.toDomain()
}
```

#### 4.2 Update All Call Sites

**Files to Update:**
- `MoodRepository.swift` - Mood entry creation
- `SwiftDataJournalRepository.swift` - Journal entry creation
- `GoalRepository.swift` - Goal creation/updates
- Any other repositories using outbox

**Pattern:**
```swift
// ❌ OLD
try await outboxRepository.createEvent(
    type: "mood_created",
    payload: try JSONEncoder().encode(moodData)
)

// ✅ NEW
try await outboxRepository.createEvent(
    eventType: .moodEntry,
    entityID: mood.id,
    userID: userID,
    isNewRecord: true,
    metadata: .moodEntry(
        valence: mood.valence,
        labels: mood.emotions
    ),
    priority: 0
)
```

---

### Phase 5: Testing & Verification (1 hour)

#### 5.1 Compilation
- [ ] Clean build succeeds
- [ ] Zero compilation errors
- [ ] Zero warnings (stretch goal)

#### 5.2 Unit Tests
- [ ] Adapter tests (toSwiftData/toDomain)
- [ ] Repository tests (createEvent, fetchPending, etc.)
- [ ] Error handling tests

#### 5.3 Integration Tests
- [ ] Create mood entry → Verify outbox event
- [ ] Create journal entry → Verify outbox event
- [ ] Process outbox events → Verify sync

#### 5.4 Manual Testing
- [ ] Fresh install (no existing data)
- [ ] Upgrade from previous version (existing outbox events)
- [ ] Create new entries
- [ ] Trigger sync
- [ ] Verify data in database

---

## Risk Mitigation

### Risk 1: Breaking Schema Changes
**Mitigation:** 
- Add new schema version (V4)
- Provide migration path from V3
- Test with existing data

### Risk 2: Data Loss During Migration
**Mitigation:**
- Migration is additive (new fields)
- Old fields retained during transition
- Backup strategy for production

### Risk 3: Performance Impact
**Mitigation:**
- Adapter conversions are lightweight
- No additional database queries
- Benchmark before/after

### Risk 4: Existing Outbox Events
**Mitigation:**
- Option A: Process and complete all pending events before migration
- Option B: Migrate with generic metadata (recommended)
- Option C: Provide best-effort parsing

---

## Implementation Checklist

### Pre-Migration
- [ ] Review FitIQ migration documentation
- [ ] Backup Lume database
- [ ] Create feature branch
- [ ] Link FitIQCore to Lume project

### Phase 1: Setup
- [ ] Add FitIQCore dependency
- [ ] Verify FitIQCore builds
- [ ] Create docs directory structure

### Phase 2: Adapter
- [ ] Create OutboxEventAdapter.swift
- [ ] Implement toSwiftData()
- [ ] Implement toDomain()
- [ ] Implement batch conversions
- [ ] Add error handling

### Phase 3: Schema
- [ ] Create SchemaV4
- [ ] Update SDOutboxEvent model
- [ ] Add migration plan
- [ ] Update CurrentSchema alias
- [ ] Test schema migration

### Phase 4: Repository
- [ ] Update SwiftDataOutboxRepository
- [ ] Update MoodRepository
- [ ] Update JournalRepository
- [ ] Update GoalRepository
- [ ] Update all other call sites

### Phase 5: Testing
- [ ] Write adapter unit tests
- [ ] Write repository unit tests
- [ ] Run integration tests
- [ ] Manual testing (fresh install)
- [ ] Manual testing (upgrade path)

### Post-Migration
- [ ] Update documentation
- [ ] Code review
- [ ] Merge to main
- [ ] Deploy to TestFlight
- [ ] Monitor for issues

---

## Success Criteria

- ✅ Build succeeds with zero errors
- ✅ All tests pass
- ✅ Type-safe metadata everywhere
- ✅ No stringly-typed outbox code
- ✅ Schema migration works
- ✅ Existing events migrate successfully
- ✅ New events use type-safe format
- ✅ FitIQCore shared across both apps

---

## Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| **Phase 1: Setup** | 30 min | None |
| **Phase 2: Adapter** | 1-2 hours | Phase 1 |
| **Phase 3: Schema** | 1 hour | Phase 2 |
| **Phase 4: Repository** | 2 hours | Phase 3 |
| **Phase 5: Testing** | 1 hour | Phase 4 |
| **TOTAL** | **5.5-6.5 hours** | - |

**Realistic Timeline:** 1-2 days (including testing, review, documentation)

---

## Key Differences from FitIQ Migration

| Aspect | FitIQ | Lume |
|--------|-------|------|
| **Outbox Complexity** | High (30+ warnings) | Low (simpler implementation) |
| **Schema Version** | V11 | V3 → V4 |
| **Payload Format** | Some structured | Binary `Data` |
| **Metadata Migration** | Minimal | Required (Data → OutboxMetadata) |
| **Event Types** | Progress, sleep, mood | Mood, journal, goals |
| **Call Sites** | ~10-15 files | ~5-8 files |
| **Risk** | Medium | Low (lessons from FitIQ) |

---

## Lessons from FitIQ Migration

### What Worked Well ✅
1. Adapter Pattern provided clean separation
2. Type-safe enums eliminated runtime errors
3. Systematic approach (phase by phase)
4. Comprehensive documentation helped
5. ID-based duplicate checks prevented crashes

### Challenges Encountered ⚠️
1. Duplicate registration errors (fixed with ID check)
2. Metadata dictionary → enum conversion
3. Multiple schema versions to update
4. 100+ compilation errors to fix

### Apply to Lume 📋
1. Implement ID-based duplicate check from start
2. Use FitIQ's adapter as template
3. Plan metadata migration strategy early
4. Start with simpler schema (fewer versions)
5. Test duplicate scenarios thoroughly

---

## Documentation Deliverables

### During Migration
1. **MIGRATION_LOG.md** - Real-time progress tracking
2. **ERROR_LOG.md** - Compilation errors and fixes
3. **DECISIONS.md** - Architectural decisions

### Post-Migration
1. **MIGRATION_COMPLETION_REPORT.md** - Final summary
2. **DEVELOPER_GUIDE.md** - Usage guide
3. **COMPARISON_REPORT.md** - FitIQ vs Lume lessons

---

## References

### FitIQ Migration Documentation
- `FitIQ/docs/outbox-migration/MIGRATION_COMPLETION_REPORT.md`
- `FitIQ/docs/outbox-migration/DEVELOPER_QUICK_GUIDE.md`
- `FitIQ/docs/outbox-migration/FINAL_SUMMARY.md`

### FitIQCore Documentation
- `FitIQCore/Sources/FitIQCore/Sync/Domain/OutboxEvent.swift`
- `FitIQCore/Sources/FitIQCore/Sync/Protocols/OutboxRepositoryProtocol.swift`

### FitIQ Reference Implementation
- `FitIQ/Infrastructure/Persistence/Adapters/OutboxEventAdapter.swift`
- `FitIQ/Infrastructure/Persistence/SwiftDataOutboxRepository.swift`

---

## Next Steps

1. **Review this plan** with team
2. **Get approval** for migration
3. **Schedule migration** (1-2 day sprint)
4. **Create feature branch** (`feature/lume-outbox-migration`)
5. **Begin Phase 1** (Setup & Dependencies)

---

**Plan Author:** AI Assistant  
**Based On:** FitIQ migration (completed 2025-01-27)  
**Status:** 📋 Ready for implementation  
**Approval:** Pending

---

**END OF MIGRATION PLAN**