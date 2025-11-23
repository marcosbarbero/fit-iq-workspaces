# How to Fix Schema Mismatch (SchemaV2 vs SchemaV4)

## Problem
Your database contains SchemaV2 data, but the app expects SchemaV4.

## Solution Options

### Option 1: Delete App and Reinstall (Recommended for Development)

1. **Delete app from simulator/device:**
   ```bash
   # For simulator
   xcrun simctl uninstall booted com.yourdomain.FitIQ
   
   # Or manually: Long press app icon → Remove App
   ```

2. **Clean build folder:**
   ```bash
   cd /path/to/FitIQ
   xcodebuild clean
   rm -rf ~/Library/Developer/Xcode/DerivedData/FitIQ-*
   ```

3. **Rebuild and run:**
   - App will create fresh SchemaV4 database
   - All data will be V4 from the start

### Option 2: Delete All Data from Settings (Keeps App Installed)

1. **Run the app**
2. **Navigate to Settings → Data Management**
3. **Tap "Delete All Data"**
4. **Confirm deletion**
5. **App will recreate database with SchemaV4**

### Option 3: Manual Database Migration (Advanced)

If you need to preserve existing data:

1. **Check current schema version:**
   - Add logging in AppDependencies to show schema version
   - Look for: "PersistenceMigrationPlan: Current schema: V2"

2. **Trigger migration:**
   - The migration should happen automatically on next launch
   - Check logs for: "PersistenceMigrationPlan: Migrating V2 → V3 → V4"

3. **If migration doesn't trigger:**
   - There might be a ModelContainer configuration issue
   - Check that ModelContainer is using PersistenceMigrationPlan

## Verification

After deleting/migrating, verify schema version:

1. **Set breakpoint in SwiftDataProgressRepository.fetchLocal()**
2. **Inspect descriptor variable**
3. **Should show:** `SchemaV4.SDProgressEntry` ✅
4. **Should NOT show:** `SchemaV2.SDProgressEntry` ❌

## Why This Happens

- Your database was created with SchemaV2
- Code now uses SchemaV4
- Migration plan was missing (now fixed)
- But existing database hasn't migrated yet
- Need to either delete database or trigger migration

## For Production

In production, this won't be an issue because:
- New users get SchemaV4 from the start
- Existing users will auto-migrate V2 → V3 → V4
- Migration plan (now fixed) handles this automatically
