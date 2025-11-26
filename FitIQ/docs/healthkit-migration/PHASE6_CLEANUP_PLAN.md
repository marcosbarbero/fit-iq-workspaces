# Phase 6: Cleanup Plan - HealthKit Migration

**Date:** 2025-01-27  
**Phase:** 6 (Post-Migration Cleanup)  
**Status:** 🚧 In Progress

---

## Overview

Now that Phase 5 (HealthKit Services Migration) is complete with all compilation errors resolved, Phase 6 focuses on cleaning up legacy code, unused files, and deprecated patterns while being conservative to avoid breaking anything.

---

## Cleanup Strategy

### ✅ Safe to Remove (Confirmed Unused)

1. **FitIQHealthKitBridge.swift**
   - Location: `FitIQ/Infrastructure/Integration/FitIQHealthKitBridge.swift`
   - Status: ✅ No references found in codebase
   - Purpose: Legacy bridge between old HealthRepository and FitIQCore
   - Action: **SAFE TO DELETE**
   - Reason: All code now uses FitIQCore directly

2. **HealthRepositoryProtocol** (if separate file exists)
   - Status: ✅ No references found in codebase
   - Purpose: Legacy protocol for HealthKit operations
   - Action: **SAFE TO DELETE** (if exists as separate file)
   - Reason: Replaced by FitIQCore's HealthKitServiceProtocol

### ⚠️ Investigate Before Removing

1. **Unused HealthKit Imports**
   - Action: Review files for unnecessary `import HealthKit`
   - Keep if: File uses HKHealthStore, HKQuantityType, or other HK types directly
   - Remove if: File only uses FitIQCore abstractions

2. **Deprecated Use Cases** (if any)
   - Check for duplicate or obsolete use case implementations
   - Verify they're not being used anywhere

3. **Old SwiftData Models** (pre-FitIQCore migration)
   - Check schema versions for deprecated models
   - Ensure they're not needed for migration

### 🔍 Review But Keep (Likely Still Needed)

1. **Background Sync Manager**
   - Location: `BackgroundSyncManager.swift`
   - Status: May still be using observer queries
   - Action: Keep for now, revisit architectural decision
   - Note: Consider migrating to FitIQCore's `observeChanges()` in future

2. **Diagnostic Use Cases**
   - `DiagnoseHealthKitAccessUseCase.swift`
   - Keep for debugging and support

3. **Migration Helper Files**
   - Keep schema migration files
   - Keep for backward compatibility

---

## Cleanup Checklist

### Phase 6.1: Safe Deletions

- [ ] Remove `FitIQHealthKitBridge.swift`
- [ ] Remove `HealthRepositoryProtocol.swift` (if exists)
- [ ] Remove any unused test mocks for old bridge
- [ ] Remove deprecated helper methods

### Phase 6.2: Import Cleanup

- [ ] Audit unnecessary `import HealthKit` statements
- [ ] Remove unused FitIQCore imports
- [ ] Organize imports consistently

### Phase 6.3: Code Simplification

- [ ] Remove commented-out legacy code
- [ ] Simplify error handling where bridge was used
- [ ] Remove deprecated documentation references

### Phase 6.4: Documentation Updates

- [ ] Update architecture diagrams (remove bridge layer)
- [ ] Update integration guides
- [ ] Mark deprecated files in docs
- [ ] Update README if needed

---

## Files to Remove (Confirmed Safe)

### 1. FitIQHealthKitBridge.swift

**Path:** `FitIQ/Infrastructure/Integration/FitIQHealthKitBridge.swift`

**Verification:**
```bash
# No references found
grep -r "FitIQHealthKitBridge" FitIQ/**/*.swift
# Result: No matches
```

**Size:** ~600+ lines  
**Purpose:** Legacy adapter bridging old HealthRepository to FitIQCore  
**Replacement:** Direct FitIQCore integration everywhere

**Action:**
```bash
rm FitIQ/FitIQ/Infrastructure/Integration/FitIQHealthKitBridge.swift
```

**Git Commit Message:**
```
chore: remove legacy FitIQHealthKitBridge adapter

- Removed FitIQHealthKitBridge.swift (unused after Phase 5 migration)
- All code now uses FitIQCore HealthKitServiceProtocol directly
- Part of Phase 6 cleanup
```

---

## Files to Keep (Still Needed)

### Infrastructure Services

✅ **Keep These:**
- `HealthDataSyncManager.swift` - Manages periodic sync
- `BackgroundSyncManager.swift` - Background data delivery (may refactor later)
- `HealthKitProfileSyncService.swift` - Profile sync to HealthKit
- `OutboxProcessorService.swift` - Outbox Pattern implementation
- `RemoteSyncService.swift` - Backend sync coordination

### Use Cases

✅ **Keep These:**
- All current use cases (verified in use)
- `DiagnoseHealthKitAccessUseCase.swift` - Debugging tool
- `ForceHealthKitResyncUseCase.swift` - User-triggered sync

### Domain Models

✅ **Keep These:**
- All SwiftData schema versions (needed for migrations)
- All current domain entities
- All progress tracking models

---

## Import Audit Results

### Files with Direct HealthKit Access (Keep Import)

These files need `import HealthKit` because they use HK types directly:

1. **HealthKitProfileSyncService.swift**
   - Uses: `HKHealthStore`, `HKBiologicalSex`
   - Reason: Fetching HealthKit characteristics (DOB, biological sex)
   - Status: ✅ Keep import

2. **ProfileViewModel.swift**
   - Uses: `HKHealthStore`, `HKBiologicalSex`
   - Reason: Same as above
   - Status: ✅ Keep import

3. **BodyMassDetailViewModel.swift**
   - Uses: `HKHealthStore`, `HKQuantityType`
   - Reason: Diagnostic/debug methods
   - Status: ✅ Keep import

4. **DiagnoseHealthKitAccessUseCase.swift** (if uses HK types)
   - Reason: Diagnostic tool
   - Status: ✅ Keep import

### Files with FitIQCore Only (Verify Import Needed)

These files might not need `import HealthKit`:
- Review each to confirm they only use FitIQCore abstractions
- Remove HealthKit import if not directly accessing HK types

---

## Architecture After Cleanup

### Before (Phase 1-4)
```
┌─────────────────────────────────────┐
│         FitIQ App Layer             │
│  (ViewModels, Use Cases, Views)     │
└─────────────────┬───────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│    FitIQHealthKitBridge (LEGACY)    │ ← TO BE REMOVED
│   (Adapts old API to FitIQCore)     │
└─────────────────┬───────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│          FitIQCore Library          │
│  (HealthKitServiceProtocol, etc.)   │
└─────────────────┬───────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│       Apple HealthKit Framework     │
└─────────────────────────────────────┘
```

### After Phase 6 Cleanup
```
┌─────────────────────────────────────┐
│         FitIQ App Layer             │
│  (ViewModels, Use Cases, Views)     │
└─────────────────┬───────────────────┘
                  │
                  ↓ (Direct dependency)
┌─────────────────────────────────────┐
│          FitIQCore Library          │
│  (HealthKitServiceProtocol, etc.)   │
└─────────────────┬───────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│       Apple HealthKit Framework     │
└─────────────────────────────────────┘

Note: Some ViewModels may still access
HKHealthStore directly for characteristics
(DOB, biological sex) as these aren't
exposed through FitIQCore yet.
```

---

## Conservative Approach Notes

### Why Being Conservative?

User noted: "there are still places with errors, however, it might be simpler to clean later"

**Our Strategy:**
1. ✅ Remove only files with **zero references** (confirmed safe)
2. ⚠️ Keep files that might be used (even if uncertain)
3. 🔍 Document questionable files for future review
4. 📋 Create technical debt tickets for larger refactors

### What We're NOT Doing (Yet)

❌ **Not removing BackgroundSyncManager** - May still be using observer queries  
❌ **Not refactoring background delivery** - Architectural decision needed  
❌ **Not removing all HK imports** - Some needed for characteristics  
❌ **Not touching schema versions** - Needed for migrations  
❌ **Not removing diagnostic tools** - Useful for support

### Future Cleanup (Phase 6.5 or Later)

Items to revisit after full testing:
- BackgroundSyncManager architecture
- Observer query patterns vs FitIQCore's `observeChanges()`
- Consolidate biological sex/DOB access
- Consider exposing characteristics through FitIQCore
- Remove any remaining commented code

---

## Execution Plan

### Step 1: Safe Deletions (This Phase)

```bash
# Remove confirmed-unused files
rm FitIQ/FitIQ/Infrastructure/Integration/FitIQHealthKitBridge.swift

# Commit
git add -A
git commit -m "chore(phase6): remove legacy FitIQHealthKitBridge adapter"
```

### Step 2: Documentation Updates

- Update architecture docs
- Remove bridge references
- Document what was removed and why

### Step 3: Verify Build

```bash
# Ensure no new errors introduced
xcodebuild -scheme FitIQ clean build
```

### Step 4: Create Technical Debt Tickets

For items deferred to future cleanup:
- "Consider migrating BackgroundSyncManager to FitIQCore patterns"
- "Evaluate exposing HealthKit characteristics through FitIQCore"
- "Audit all HealthKit imports for necessity"

---

## Success Criteria

✅ **Phase 6 Complete When:**
1. Legacy bridge file removed
2. No compilation errors introduced
3. Build remains clean (0 errors, 0 warnings)
4. Documentation updated
5. Cleanup plan documented for future reference

---

## Risk Assessment

### Low Risk (Safe)
- ✅ Removing FitIQHealthKitBridge.swift (no references)
- ✅ Updating documentation

### Medium Risk (Test After)
- ⚠️ Removing unused imports (verify build)
- ⚠️ Simplifying code that referenced bridge

### High Risk (Defer)
- ❌ Refactoring BackgroundSyncManager
- ❌ Changing observer query patterns
- ❌ Modifying schema versions

---

## Rollback Plan

If cleanup causes issues:

```bash
# Rollback git commit
git revert HEAD

# Or restore specific file
git checkout HEAD~1 -- FitIQ/FitIQ/Infrastructure/Integration/FitIQHealthKitBridge.swift
```

---

## Post-Cleanup Testing

After cleanup, verify:
- [ ] App builds successfully
- [ ] HealthKit authorization works
- [ ] Weight logging works
- [ ] Historical data loads
- [ ] Background sync works (if applicable)
- [ ] Profile sync works
- [ ] No crashes or runtime errors

---

## Related Documentation

- [Phase 5 Completion Report](../fixes/HEALTHKIT_MIGRATION_PHASE5_FINAL_FIXES.md)
- [FitIQCore Integration Guide](../../docs/split-strategy/FITIQ_INTEGRATION_GUIDE.md)
- [Architecture Overview](../architecture/)

---

**Status:** 📋 Plan Created - Ready for Execution  
**Next Step:** Execute safe deletions (Step 1)  
**Estimated Time:** 15-30 minutes (conservative cleanup only)