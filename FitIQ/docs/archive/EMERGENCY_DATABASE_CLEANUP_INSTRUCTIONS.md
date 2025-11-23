# Emergency Database Cleanup Instructions

**Date:** 2025-01-27  
**Issue:** Database has grown to 150MB (expected: 8-12MB)  
**Cause:** Likely data duplication from progressive sync running multiple times  
**Status:** 🚨 URGENT - Action Required

---

## 🚨 Immediate Actions Required

### Step 1: Stop Progressive Sync from Re-Running

The progressive sync may be running every time `RootTabView` appears, causing massive duplication.

**File:** `FitIQ/FitIQ/Presentation/UI/Shared/RootTabView.swift`

**Find this code (around line 156):**
```swift
// Start progressive historical sync in background (90 days total)
print("\n🚀 RootTabView: Starting progressive historical sync (7-90 days)...")
deps.progressiveHistoricalSyncService.startProgressiveSync(forUserID: userID)
print("✓ RootTabView: Progressive sync started in background\n")
```

**Replace with:**
```swift
// ONLY start progressive sync if it hasn't run before
let hasCompletedProgressiveSync = UserDefaults.standard.bool(forKey: "hasCompletedProgressiveSync_\(userID)")

if !hasCompletedProgressiveSync && !deps.progressiveHistoricalSyncService.isSyncing {
    print("\n🚀 RootTabView: Starting progressive historical sync (7-90 days)...")
    deps.progressiveHistoricalSyncService.startProgressiveSync(forUserID: userID)
    print("✓ RootTabView: Progressive sync started in background\n")
    
    // Mark as started (will be marked complete when done)
    UserDefaults.standard.set(true, forKey: "hasStartedProgressiveSync_\(userID)")
} else {
    print("⏭️ RootTabView: Progressive sync already completed or in progress - skipping")
}
```

**And in ProgressiveHistoricalSyncService.swift, after sync completes (around line 168):**
```swift
print("📊 Progressive Historical Sync Complete")
print("   ✅ Successful chunks: \(syncedChunks)/\(numberOfChunks)")

// Mark sync as completed for this user
if let userID = self.currentUserID {
    await MainActor.run {
        UserDefaults.standard.set(true, forKey: "hasCompletedProgressiveSync_\(userID)")
    }
}
```

---

### Step 2: Run Emergency Cleanup

#### Option A: Via Code (Recommended)

**1. Register the use case in AppDependencies.swift:**

Find the section around line 706 where services are created, add:

```swift
// MARK: - Emergency Database Cleanup Use Case
let emergencyDatabaseCleanupUseCase = EmergencyDatabaseCleanupUseCaseImpl(
    modelContext: sharedContext,
    outboxRepository: outboxRepository,
    authManager: authManager
)
```

Then add it to the init parameters (around line 774):

```swift
emergencyDatabaseCleanupUseCase: emergencyDatabaseCleanupUseCase,
```

And add the property declaration (around line 113):

```swift
let emergencyDatabaseCleanupUseCase: EmergencyDatabaseCleanupUseCase
```

And in the init signature (around line 185):

```swift
emergencyDatabaseCleanupUseCase: EmergencyDatabaseCleanupUseCase,
```

And in the init body (around line 255):

```swift
self.emergencyDatabaseCleanupUseCase = emergencyDatabaseCleanupUseCase
```

**2. Add a debug button to ProfileView or AppSettingsView:**

```swift
Section("Database Management") {
    Button("🚨 Emergency Cleanup (Removes Duplicates)") {
        Task {
            do {
                let stats = try await deps.emergencyDatabaseCleanupUseCase.execute()
                print("Cleanup completed! Removed \(stats.duplicatesRemoved) duplicates")
            } catch {
                print("Cleanup failed: \(error)")
            }
        }
    }
    .foregroundColor(.red)
}
```

**3. Launch the app and tap the button**

#### Option B: Via Script (Nuclear Option)

**⚠️ WARNING: This deletes ALL local data. User will need to re-sync from HealthKit.**

**1. Stop the app completely**

**2. Delete the database file manually:**

The database is located at:
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Library/Application Support/default.store
```

Or use this script:

```bash
#!/bin/bash
# EMERGENCY_DELETE_DATABASE.sh

echo "🚨 EMERGENCY: Deleting SwiftData database..."

# Find the app's container
APP_BUNDLE_ID="com.yourcompany.FitIQ"  # Replace with actual bundle ID

# Kill the app if running
killall "FitIQ" 2>/dev/null

# Find and delete the database
find ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Application\ Support/ -name "*.store*" -type f -delete

echo "✅ Database deleted. Launch app to recreate."
echo "⚠️  All local data is lost. User will re-sync from HealthKit."
```

**3. Launch the app - it will create a fresh database**

---

### Step 3: Add Database Indexes (Performance Fix)

Indexes will speed up queries and reduce future bloat.

**Create new schema version (V5) with indexes:**

**File:** `FitIQ/FitIQ/Infrastructure/Persistence/Schema/SchemaV5.swift`

```swift
import Foundation
import SwiftData

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 5)

    // Reuse V4 models except SDProgressEntry (we're adding indexes)
    typealias SDUserProfile = SchemaV4.SDUserProfile
    typealias SDPhysicalAttribute = SchemaV4.SDPhysicalAttribute
    typealias SDActivitySnapshot = SchemaV4.SDActivitySnapshot
    typealias SDDietaryAndActivityPreferences = SchemaV4.SDDietaryAndActivityPreferences
    typealias SDOutboxEvent = SchemaV4.SDOutboxEvent
    typealias SDSleepSession = SchemaV4.SDSleepSession
    typealias SDSleepStage = SchemaV4.SDSleepStage

    // NEW: SDProgressEntry with indexes
    @Model final class SDProgressEntry {
        var id: UUID = UUID()

        @Attribute(.indexed)  // ✅ INDEX
        var userID: String = ""

        @Attribute(.indexed)  // ✅ INDEX
        var type: String = ""

        var quantity: Double = 0.0

        @Attribute(.indexed)  // ✅ INDEX
        var date: Date = Date()

        var time: String?
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?

        @Attribute(.indexed)  // ✅ INDEX
        var syncStatus: String = "pending"

        @Relationship
        var userProfile: SDUserProfile?

        init(
            id: UUID = UUID(),
            userID: String,
            type: String,
            quantity: Double,
            date: Date,
            time: String? = nil,
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            userProfile: SDUserProfile? = nil
        ) {
            self.id = id
            self.userID = userID
            self.type = type
            self.quantity = quantity
            self.date = date
            self.time = time
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.userProfile = userProfile
        }
    }

    static var models: [any PersistentModel.Type] {
        [
            SDUserProfile.self,
            SDPhysicalAttribute.self,
            SDActivitySnapshot.self,
            SDDietaryAndActivityPreferences.self,
            SDProgressEntry.self,
            SDOutboxEvent.self,
            SDSleepSession.self,
            SDSleepStage.self
        ]
    }
}
```

**Update SchemaDefinition.swift:**

```swift
typealias CurrentSchema = SchemaV5  // Change from V4 to V5

enum FitIQSchemaDefinitition: CaseIterable {
    case v1, v2, v3, v4, v5  // Add v5
    
    var schema: any VersionedSchema.Type {
        switch self {
        case .v1: return SchemaV1.self
        case .v2: return SchemaV2.self
        case .v3: return SchemaV3.self
        case .v4: return SchemaV4.self
        case .v5: return SchemaV5.self  // Add this
        @unknown default: return CurrentSchema.self
        }
    }
}
```

**Update PersistenceHelper.swift:**

```swift
// Change all typealiases to use SchemaV5
typealias SDProgressEntry = SchemaV5.SDProgressEntry
typealias SDUserProfile = SchemaV5.SDUserProfile
// etc...
```

---

## 📊 Expected Results After Cleanup

### Before Cleanup
- Database size: **150 MB** 🚨
- Thousands of duplicate entries
- Slow queries
- Frequent PostSaveMaintenance warnings

### After Cleanup
- Database size: **8-15 MB** ✅
- No duplicates
- Fast queries (< 100ms)
- Rare PostSaveMaintenance warnings

---

## 🔍 How to Verify

### Check Database Size

**In ProfileView or Debug Settings, add:**

```swift
Section("Database Info") {
    Button("Check Database Size") {
        if let url = modelContext.container.configurations.first?.url {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attributes[.size] as? Int64 ?? 0
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                let sizeStr = formatter.string(fromByteCount: size)
                print("📊 Database size: \(sizeStr)")
            } catch {
                print("❌ Could not get size: \(error)")
            }
        }
    }
}
```

### Check for Duplicates

**Add debug code:**

```swift
Button("Check for Duplicates") {
    Task {
        let descriptor = FetchDescriptor<SDProgressEntry>(
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.type)]
        )
        let entries = try modelContext.fetch(descriptor)
        
        var seen = Set<String>()
        var dupes = 0
        
        for entry in entries {
            let key = "\(entry.type)_\(entry.date.timeIntervalSince1970)"
            if seen.contains(key) {
                dupes += 1
            } else {
                seen.insert(key)
            }
        }
        
        print("📊 Total entries: \(entries.count)")
        print("🔍 Duplicates found: \(dupes)")
    }
}
```

---

## 🚀 Prevention: Don't Let This Happen Again

### 1. Track Sync Completion

Use `UserDefaults` to track if progressive sync has completed:

```swift
// Mark sync as complete
UserDefaults.standard.set(true, forKey: "hasCompletedProgressiveSync_\(userID)")

// Check before starting
let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedProgressiveSync_\(userID)")
if hasCompleted {
    print("Sync already completed - skipping")
    return
}
```

### 2. Add Deduplication Guard

Already implemented in `SwiftDataProgressRepository.swift`, but verify it's working.

### 3. Monitor Database Size

Add periodic size checks (daily):

```swift
// In BackgroundSyncManager or similar
func checkDatabaseHealth() {
    let size = getDatabaseSize()
    if size > 50_000_000 { // 50 MB
        print("⚠️ Database size is \(size / 1_000_000)MB - may need cleanup")
    }
}
```

### 4. Periodic Cleanup

Run `OptimizeDatabaseUseCase` weekly:

```swift
// Check last cleanup date
let lastCleanup = UserDefaults.standard.object(forKey: "lastDatabaseCleanup") as? Date
let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

if lastCleanup == nil || lastCleanup! < weekAgo {
    try await optimizeDatabaseUseCase.execute()
    UserDefaults.standard.set(Date(), forKey: "lastDatabaseCleanup")
}
```

---

## 📝 Checklist

- [ ] Stop progressive sync from re-running (Step 1)
- [ ] Register EmergencyDatabaseCleanupUseCase in AppDependencies
- [ ] Add emergency cleanup button to UI
- [ ] Run emergency cleanup
- [ ] Verify database size reduced to < 20 MB
- [ ] Create SchemaV5 with indexes
- [ ] Update SchemaDefinition and PersistenceHelper
- [ ] Test that queries are faster
- [ ] Add sync completion tracking
- [ ] Add periodic cleanup schedule
- [ ] Monitor database size going forward

---

## 🆘 If All Else Fails

**Nuclear option: Delete app and reinstall**

1. Delete app from simulator/device
2. Clean build folder in Xcode (Cmd+Shift+K)
3. Rebuild and install
4. Complete onboarding
5. Let initial sync complete (7 days only - should be ~2-3 MB)
6. Verify progressive sync runs ONCE and stops

---

**Status:** 🚨 URGENT - Follow Steps 1-2 Immediately  
**Priority:** P0 - Database bloat affects all users  
**Time to Fix:** 30-60 minutes  

---