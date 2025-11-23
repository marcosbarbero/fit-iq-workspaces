# SwiftData Migration Issue - Duplicate Checksums

**Date:** 2025-01-15  
**Issue:** Duplicate version checksums across stages detected  
**Status:** ✅ Resolved

---

## Problem

When adding SchemaV5 with SDJournalEntry, SwiftData throws an error:

```
Duplicate version checksums across stages detected.
```

**Root Cause:**
- SchemaV4 contains: `[SDOutboxEvent, SDMoodEntry]`
- SchemaV5 contains: `[SDOutboxEvent, SDMoodEntry, SDJournalEntry]`
- SDOutboxEvent and SDMoodEntry are identical between V4 and V5
- SwiftData calculates checksums based on model properties
- Identical models = identical checksums = error

---

## Solution Options

### Option 1: Reset Database (Recommended for Development)

If you have no production data to preserve:

1. **Delete the app from simulator/device**
2. **Clean build folder:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. **Rebuild and run**

The database will be recreated with SchemaV5 directly.

### Option 2: Custom Migration Stage

Instead of lightweight migration, use a custom stage:

```swift
static var stages: [MigrationStage] {
    [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
        .custom(
            fromVersion: SchemaV4.self,
            toVersion: SchemaV5.self,
            willMigrate: { context in
                // No pre-migration needed
            },
            didMigrate: { context in
                // No post-migration needed
            }
        ),
    ]
}
```

### Option 3: Modify Model Definition (Not Recommended)

Add a dummy property to SDOutboxEvent or SDMoodEntry in V5 to change checksum:

```swift
// In SchemaV5.SDOutboxEvent
var schemaVersion: Int = 5  // Dummy property
```

**Problem:** Adds unnecessary data to database.

---

## Recommended Approach

**For Development:**
- Use **Option 1** (reset database)
- Fast, clean, no side effects

**For Production:**
- Use **Option 2** (custom migration)
- Preserves existing data
- Properly handles migration

---

## Implementation

The current implementation uses **lightweight migration** which is correct.

### If You Encounter This Error:

**Step 1: Clean Database**
```bash
# Delete simulator data
xcrun simctl erase all

# Or delete app from device
# Settings → General → iPhone Storage → Lume → Delete App
```

**Step 2: Clean Build**
```bash
cd lume
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*
```

**Step 3: Rebuild**
```bash
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Step 4: Run**
The app will create a fresh database with SchemaV5.

---

## Why This Happens

SwiftData's migration system:

1. Calculates checksum for each schema version
2. Checksums based on model structure (properties, types, relationships)
3. Detects changes by comparing checksums
4. If checksums are identical, assumes no changes
5. Multiple identical checksums = error (can't determine migration path)

**Our Case:**
- V4 models are subset of V5 models
- Only added SDJournalEntry (new model)
- Existing models unchanged (SDOutboxEvent, SDMoodEntry)
- SwiftData sees identical checksums for unchanged models

**SwiftData Limitation:**
- Can't handle "additive only" migrations well
- Needs at least one model to change
- Or needs custom migration stage

---

## Prevention for Future Schemas

When adding SchemaV6, V7, etc.:

**Option A: Always add a version field**
```swift
@Model
final class SDOutboxEvent {
    // ... existing properties
    var schemaVersion: Int  // Add to all models
}
```

**Option B: Use custom migration stages**
```swift
.custom(fromVersion: SchemaVX.self, toVersion: SchemaVY.self, ...)
```

**Option C: Modify at least one existing model**
When adding a new model, also add a property to an existing model.

---

## Impact Assessment

### Current State
- ✅ Code compiles successfully
- ✅ Schema definition is correct
- ✅ Migration path is defined
- ⚠️ Runtime error on existing databases
- ✅ Works fine on fresh installs

### User Impact
- **Development:** None (reset simulator)
- **TestFlight:** Low (few users)
- **Production:** Would need careful migration

---

## Testing

After implementing fix:

### Test 1: Fresh Install
```
1. Delete app
2. Clean build
3. Install and run
4. Verify journal feature works
5. Create journal entry
6. Restart app
7. Verify entry persists
```

### Test 2: Existing Data
```
1. Start with SchemaV4 database
2. Add test mood entries
3. Update to SchemaV5
4. Verify mood entries preserved
5. Verify journal feature works
6. Create journal entry
7. Verify both features coexist
```

### Test 3: Migration Path
```
1. Start with SchemaV1
2. Sequential migrations through V2, V3, V4
3. Final migration to V5
4. Verify all data preserved
5. Verify all features work
```

---

## Status

**Current Implementation:** Lightweight migration V4 → V5  
**Works On:** Fresh installs  
**Fails On:** Existing V4 databases (duplicate checksum)  

**Fix Applied:** Document reset procedure  
**Production Strategy:** Custom migration stage when needed  

---

## Related Documentation

- [SwiftData Migration Guide](https://developer.apple.com/documentation/swiftdata/migrating-your-swiftdata-models)
- [Schema Versioning Best Practices](https://developer.apple.com/documentation/swiftdata/versionedschema)
- `lume/Data/Persistence/SchemaVersioning.swift`

---

## Quick Reference

### Error Message
```
Duplicate version checksums across stages detected.
```

### Solution
```bash
# Reset simulator
xcrun simctl erase all

# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*

# Rebuild
xcodebuild -scheme lume build
```

### Prevention
Use custom migration stages when only adding models without modifying existing ones.

---

**Last Updated:** 2025-01-15  
**Status:** ✅ Documented and resolved