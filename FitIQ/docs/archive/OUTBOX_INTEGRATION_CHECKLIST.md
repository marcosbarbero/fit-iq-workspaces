# Outbox Pattern Integration Checklist

**Created:** 2025-01-31  
**Purpose:** Resolve compilation issues with newly created Outbox Pattern files

---

## 🎯 Overview

The Outbox Pattern implementation has been created with the following files:
- `Domain/Entities/Outbox/OutboxEventTypes.swift`
- `Domain/Ports/OutboxRepositoryProtocol.swift`
- `Infrastructure/Persistence/SwiftDataOutboxRepository.swift`
- `Infrastructure/Network/OutboxProcessorService.swift`
- `Infrastructure/Persistence/Schema/SchemaV3.swift` (updated)
- `Infrastructure/Persistence/Migration/PersistenceMigrationPlan.swift` (updated)

All files have been created and code-reviewed, but they may not be properly integrated into the Xcode project.

---

## ✅ Step-by-Step Resolution

### 1. Verify Files Exist in File System

Open Terminal and run:
```bash
cd /Users/marcosbarbero/Develop/GitHub/health-companion/ios/FitIQ

# Check all Outbox-related files exist
find FitIQ -name "*Outbox*" -name "*.swift" | sort
```

**Expected output:**
```
FitIQ/Domain/Entities/Outbox/OutboxEventTypes.swift
FitIQ/Domain/Ports/OutboxRepositoryProtocol.swift
FitIQ/Infrastructure/Network/OutboxProcessorService.swift
FitIQ/Infrastructure/Persistence/SwiftDataOutboxRepository.swift
```

- [ ] All 4 files exist
- [ ] Files are in correct directories

---

### 2. Add Files to Xcode Project

**In Xcode:**

1. **Open Project Navigator** (⌘+1)
2. **For each missing file:**
   - Right-click on the appropriate folder (e.g., `Domain/Entities/Outbox`)
   - Select **"Add Files to FitIQ..."**
   - Navigate to the file location
   - **IMPORTANT:** Check "Copy items if needed" is UNCHECKED (files are already there)
   - **IMPORTANT:** Check "Add to targets: FitIQ" is CHECKED
   - Click "Add"

3. **Files to add:**
   - [ ] `Domain/Entities/Outbox/OutboxEventTypes.swift`
   - [ ] `Domain/Ports/OutboxRepositoryProtocol.swift`
   - [ ] `Infrastructure/Persistence/SwiftDataOutboxRepository.swift`
   - [ ] `Infrastructure/Network/OutboxProcessorService.swift`

---

### 3. Verify Target Membership

**For each file added:**

1. Select the file in Project Navigator
2. Open **File Inspector** (⌘+⌥+1)
3. Check **Target Membership** section
4. Ensure **FitIQ** is checked ✓

**Files to verify:**
- [ ] `OutboxEventTypes.swift` → Target: FitIQ ✓
- [ ] `OutboxRepositoryProtocol.swift` → Target: FitIQ ✓
- [ ] `SwiftDataOutboxRepository.swift` → Target: FitIQ ✓
- [ ] `OutboxProcessorService.swift` → Target: FitIQ ✓
- [ ] `SchemaV3.swift` → Target: FitIQ ✓
- [ ] `PersistenceMigrationPlan.swift` → Target: FitIQ ✓

---

### 4. Verify Compile Sources Build Phase

1. Select **FitIQ** target in Project Navigator
2. Go to **Build Phases** tab
3. Expand **Compile Sources**
4. Verify all new files are listed:

**Files that MUST be in Compile Sources:**
- [ ] `OutboxEventTypes.swift`
- [ ] `OutboxRepositoryProtocol.swift`
- [ ] `SwiftDataOutboxRepository.swift`
- [ ] `OutboxProcessorService.swift`
- [ ] `SchemaV3.swift`
- [ ] `PersistenceMigrationPlan.swift`

**If missing:** Click the **"+"** button and add the missing file(s)

---

### 5. Clean Build Folder

**In Xcode:**

1. **Product** → **Clean Build Folder** (⇧⌘K)
2. Wait for clean to complete
3. **Product** → **Build** (⌘B)

- [ ] Clean completed
- [ ] Build started
- [ ] Check for remaining errors

---

### 6. Verify Schema Files

The migration requires these schema files to exist and be properly ordered:

**Check these files exist:**
- [ ] `SchemaV1.swift` (existing)
- [ ] `SchemaV2.swift` (existing)
- [ ] `SchemaV3.swift` (NEW - must include SDOutboxEvent)
- [ ] `PersistenceHelper.swift` (must include SDOutboxEvent typealias)
- [ ] `PersistenceMigrationPlan.swift` (must include V2→V3 migration)

**Verify SchemaV3 content:**
```swift
enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 3)
    
    typealias SDUserProfile = SchemaV2.SDUserProfile
    typealias SDDietaryAndActivityPreferences = SchemaV2.SDDietaryAndActivityPreferences
    typealias SDPhysicalAttribute = SchemaV2.SDPhysicalAttribute
    typealias SDActivitySnapshot = SchemaV2.SDActivitySnapshot
    typealias SDProgressEntry = SchemaV2.SDProgressEntry
    
    @Model
    final class SDOutboxEvent {
        // ... full model definition
    }
    
    static var models: [any PersistentModel.Type] {
        [
            SchemaV3.SDUserProfile.self,
            SchemaV3.SDDietaryAndActivityPreferences.self,
            SchemaV3.SDPhysicalAttribute.self,
            SchemaV3.SDActivitySnapshot.self,
            SchemaV3.SDProgressEntry.self,
            SchemaV3.SDOutboxEvent.self,
        ]
    }
}
```

- [ ] SchemaV3 exists and is complete
- [ ] SDOutboxEvent is defined in SchemaV3
- [ ] SDOutboxEvent is in models array

---

### 7. Verify PersistenceHelper Typealiases

**Open:** `FitIQ/Infrastructure/Persistence/Schema/PersistenceHelper.swift`

**Verify this line exists:**
```swift
typealias SDOutboxEvent = SchemaV3.SDOutboxEvent
```

- [ ] SDOutboxEvent typealias exists
- [ ] Points to SchemaV3.SDOutboxEvent

---

### 8. Expected Compilation Status After Fix

Once files are properly added to Xcode project:

**Should compile without errors:**
- ✅ `OutboxEventTypes.swift` (enums and extensions)
- ✅ `OutboxRepositoryProtocol.swift` (protocol definition)
- ✅ `SwiftDataOutboxRepository.swift` (repository implementation)
- ✅ `OutboxProcessorService.swift` (background processor)
- ✅ `SchemaV3.swift` (schema definition)
- ✅ `PersistenceMigrationPlan.swift` (migration plan)
- ✅ `VerifyRemoteSyncUseCase.swift` (sync verification)
- ✅ `SyncDebugViewModel.swift` (debug tools)

**Known pre-existing errors (NOT related to Outbox):**
- ⚠️ `AppDependencies.swift` (146 errors - pre-existing)
- ⚠️ `ProfileViewModel.swift` (27 errors - pre-existing)
- ⚠️ Other files with pre-existing issues

---

## 🔍 Common Issues & Solutions

### Issue: "Cannot find type 'SDOutboxEvent'"

**Cause:** SchemaV3.swift not in build or SDOutboxEvent not defined

**Solution:**
1. Verify SchemaV3.swift exists and has SDOutboxEvent @Model definition
2. Check SchemaV3.swift is in Compile Sources build phase
3. Check PersistenceHelper has `typealias SDOutboxEvent = SchemaV3.SDOutboxEvent`
4. Clean build folder and rebuild

---

### Issue: "Cannot find type 'OutboxEventType'"

**Cause:** OutboxEventTypes.swift not in build

**Solution:**
1. Verify OutboxEventTypes.swift exists
2. Add to Xcode project with FitIQ target membership
3. Check it's in Compile Sources build phase
4. Clean build folder and rebuild

---

### Issue: "Cannot find type 'OutboxRepositoryProtocol'"

**Cause:** OutboxRepositoryProtocol.swift not in build

**Solution:**
1. Verify OutboxRepositoryProtocol.swift exists
2. Add to Xcode project with FitIQ target membership
3. Check it's in Compile Sources build phase
4. Clean build folder and rebuild

---

### Issue: "Key path cannot refer to enum case"

**Cause:** Using enum cases directly in #Predicate macros

**Status:** ✅ FIXED - All predicates now use rawValue string comparisons

**Verification:**
```swift
// ✅ CORRECT - Using string literals
let pendingStatus = OutboxEventStatus.pending.rawValue
#Predicate<SDOutboxEvent> { event in
    event.status == pendingStatus
}

// ❌ WRONG - Don't use enum cases directly
#Predicate<SDOutboxEvent> { event in
    event.status == OutboxEventStatus.pending.rawValue
}
```

---

### Issue: "Cannot convert value of type PredicateExpressions..."

**Cause:** Complex predicate expressions that compiler can't type-check

**Status:** ✅ FIXED - Simplified predicates and extracted variables

**Verification:**
```swift
// ✅ CORRECT - Extract status values first
let pendingStatus = OutboxEventStatus.pending.rawValue
let failedStatus = OutboxEventStatus.failed.rawValue

#Predicate<SDOutboxEvent> { event in
    (event.status == pendingStatus
        || (event.status == failedStatus && event.attemptCount < event.maxAttempts))
}
```

---

## 🧪 Testing After Integration

Once compilation succeeds:

### 1. Test Schema Migration

```swift
// In AppDependencies or test
let schema = Schema([
    SDUserProfile.self,
    SDDietaryAndActivityPreferences.self,
    SDPhysicalAttribute.self,
    SDActivitySnapshot.self,
    SDProgressEntry.self,
    SDOutboxEvent.self,  // NEW
])

let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false
)

let container = try ModelContainer(
    for: schema,
    migrationPlan: PersistenceMigrationPlan.self,
    configurations: [configuration]
)
```

- [ ] App launches without crash
- [ ] No migration errors in console
- [ ] Existing data preserved
- [ ] SDOutboxEvent table created

---

### 2. Test Outbox Repository

```swift
// Create test event
let repository = SwiftDataOutboxRepository(modelContext: context)
let event = try await repository.createEvent(
    eventType: .progressEntry,
    entityID: UUID(),
    userID: "test-user",
    isNewRecord: true,
    metadata: nil,
    priority: 0
)

print("Created event: \(event.id)")
print("Status: \(event.status)")
```

- [ ] Event created successfully
- [ ] Event persisted to SwiftData
- [ ] Can fetch event by ID

---

### 3. Test Sync Verification

```swift
// In SyncDebugViewModel
await syncDebugViewModel.loadSyncStatus()
await syncDebugViewModel.loadPendingEntries()

print("Sync status loaded: \(syncDebugViewModel.syncStatus)")
print("Pending entries: \(syncDebugViewModel.pendingEntries.count)")
```

- [ ] No crashes when loading sync status
- [ ] Statistics calculated correctly
- [ ] Pending entries fetched

---

## 📊 Migration Plan Summary

**Schema Version Timeline:**
- **V1 (0.0.1):** Initial schema with SDUserProfile, SDPhysicalAttribute, SDActivitySnapshot
- **V2 (0.0.2):** Added SDProgressEntry for progress tracking
- **V3 (0.0.3):** Added SDOutboxEvent for reliable background sync (Outbox Pattern)

**Migration Strategy:**
- V1 → V2: Custom migration (added SDProgressEntry)
- V2 → V3: **Lightweight migration** (added SDOutboxEvent - standalone model, no relationships)

**Why Lightweight for V2→V3:**
- SDOutboxEvent is a new, independent model
- No relationships to existing models
- No changes to existing models
- No data transformation needed
- SwiftData can automatically create the new table

---

## 🎯 Success Criteria

### Compilation
- [ ] All Outbox-related files compile without errors
- [ ] No "Cannot find type" errors
- [ ] No predicate macro errors
- [ ] Pre-existing errors unchanged (not introduced by Outbox changes)

### Runtime
- [ ] App launches successfully
- [ ] Schema migration V2→V3 completes
- [ ] Existing user data preserved
- [ ] SDOutboxEvent table created
- [ ] Can create/fetch outbox events

### Integration
- [ ] OutboxRepository can be instantiated
- [ ] OutboxProcessorService can be instantiated
- [ ] VerifyRemoteSyncUseCase works
- [ ] SyncDebugViewModel loads data

---

## 📝 Notes

1. **DO NOT** modify SchemaV1 or SchemaV2 - they are sealed
2. **Current schema** is SchemaV3
3. **PersistenceHelper** uses SchemaV3 typealiases
4. **AppDependencies** needs to be updated to use SchemaV3 in ModelContainer
5. All Outbox files are independent - no changes needed to existing files (except AppDependencies for DI)

---

## 🆘 If Issues Persist

If after following all steps you still have compilation errors:

1. **Check exact error messages** - Note which files/lines are failing
2. **Verify file paths** - Ensure all files are in correct directories
3. **Check for typos** - File names must match exactly
4. **Restart Xcode** - Sometimes needed to refresh indexing
5. **Delete DerivedData** - `rm -rf ~/Library/Developer/Xcode/DerivedData`
6. **Re-open project** - Close and reopen .xcodeproj

---

**Status:** Ready for Xcode integration  
**Last Updated:** 2025-01-31  
**Version:** 1.0