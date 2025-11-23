# Lume Authentication Migration - Blocked Status

**Status:** 🚧 BLOCKED - Technical Limitation  
**Created:** 2025-01-27  
**Priority:** Medium (Can proceed with FitIQ first)

---

## Summary

Lume's authentication migration to FitIQCore is blocked by Xcode project file compatibility issues. The recommended path forward is to complete FitIQ's migration first, then address Lume separately.

---

## Issue Description

### Problem

Lume's Xcode project (`lume.xcodeproj`) requires a local Swift package reference to FitIQCore, but:

1. **Manual pbxproj editing fails** with runtime error:
   ```
   Exception: -[XCLocalSwiftPackageReference group]: unrecognized selector sent to instance
   ```

2. **Xcode GUI addition doesn't persist** - Package reference added but not properly linked

3. **Xcode version incompatibility** - The pbxproj format for local packages is version-specific (objectVersion = 77)

### Root Cause

- Xcode 26.0 (beta) uses newer pbxproj format
- FitIQ project was created/updated with compatible format
- Lume project format doesn't support manual XCLocalSwiftPackageReference editing
- Package dependencies require Xcode-internal validation that differs by version

---

## Attempted Solutions

### Attempt 1: Manual pbxproj Editing ❌
**Result:** `-[XCLocalSwiftPackageReference group]: unrecognized selector`

Added:
```xml
packageReferences = (
    8463D76F2ED20A770077D839 /* XCLocalSwiftPackageReference "../FitIQCore" */,
);
```

**Issue:** Xcode's internal consistency checks fail with manual edits

### Attempt 2: Xcode GUI Package Addition ❌
**Result:** Package added but not linked to target

**Issue:** Package reference created but missing proper linkage in pbxproj

### Attempt 3: Different UUID Format ❌
**Result:** Same runtime error

**Issue:** Format issue, not UUID issue

---

## Current Workarounds Evaluated

### Option A: Xcode Workspace (Recommended) ⭐
**Status:** Not yet attempted  
**Complexity:** Low  
**Risk:** Low

Create an Xcode workspace containing:
- FitIQ project
- Lume project  
- FitIQCore package

Benefits:
- Workspace manages cross-project dependencies
- No manual pbxproj editing required
- Proper Xcode validation
- Supports both projects sharing FitIQCore

Steps:
1. Create `FitIQ.xcworkspace`
2. Add all three components via Xcode GUI
3. Both projects reference FitIQCore through workspace

### Option B: Embedded Framework
**Status:** Possible but complex  
**Complexity:** High  
**Risk:** Medium

Build FitIQCore as a framework and embed in Lume.

Drawbacks:
- More complex build process
- Loses SPM benefits
- Harder to maintain
- Not recommended for local development

### Option C: Git Submodule + Remote Reference
**Status:** Possible  
**Complexity:** Medium  
**Risk:** Low

Reference FitIQCore as a remote package (even though it's local).

Drawbacks:
- Requires committing FitIQCore changes before testing
- Slower development cycle
- Not ideal for active development

---

## Recommended Path Forward

### Phase 1: Complete FitIQ Migration First ⭐ RECOMMENDED

**Why FitIQ First:**
1. ✅ FitIQCore package already working in FitIQ
2. ✅ 1/10 API clients migrated (UserAuthAPIClient complete)
3. ✅ Clear migration pattern established
4. ✅ No technical blockers
5. ✅ 9 API clients remaining (~450 lines to remove)

**Benefits:**
- Unblocked progress on authentication unification
- Removes ~630 lines of duplicated code from FitIQ
- Establishes proven migration patterns
- FitIQ is larger and more complex (better to tackle first)

**Timeline:** 2-3 days to complete all 10 API clients

### Phase 2: Create Workspace for Lume

After FitIQ migration is complete:
1. Create `FitIQ.xcworkspace`
2. Add FitIQ, Lume, and FitIQCore
3. Proceed with Lume migration

**Timeline:** 1 day setup + 1 day migration

---

## Migration Plan Adjustment

### Original Plan
```
Phase 1: FitIQ Migration (10 clients)
Phase 2: Lume Migration (3 files)
```

### Revised Plan
```
Phase 1: Complete FitIQ Migration
  - UserAuthAPIClient ✅ DONE (1/10)
  - NutritionAPIClient (next)
  - ProgressAPIClient
  - SleepAPIClient
  - WorkoutAPIClient
  - WorkoutTemplateAPIClient
  - PhotoRecognitionAPIClient
  - RemoteHealthDataSyncClient
  - UserProfileAPIClient
  - PhysicalProfileAPIClient
  
Phase 2: Setup Workspace
  - Create FitIQ.xcworkspace
  - Add all projects/packages
  - Verify builds
  
Phase 3: Complete Lume Migration
  - RemoteAuthService (~50 lines)
  - AuthRepository (~50 lines)
  - Delete local AuthToken (~25 lines)
```

---

## Current Progress

### FitIQ Status: ✅ In Progress (30% Complete)
- **Completed:**
  - FitIQCore package integrated
  - TokenRefreshClient added to DI
  - UserAuthAPIClient migrated (~80 lines removed)
  - Build successful
  
- **Remaining:**
  - 9/10 API clients to migrate
  - ~450 lines of code to remove
  - Estimated: 2-3 days

### Lume Status: 🚧 Blocked (0% Complete)
- **Blocker:** Package reference setup
- **Workaround:** Create workspace (1 day)
- **Ready:** Migration plan complete, code analyzed
- **Estimated After Unblocked:** 1 day migration

---

## Technical Details

### Lume's Current Authentication
- **Domain/Entities/AuthToken.swift** (25 lines) - Manual expiration tracking
- **Services/Authentication/RemoteAuthService.swift** (300 lines) - Manual JWT parsing
- **Data/Repositories/AuthRepository.swift** (200 lines) - Manual refresh logic
- **Total to Remove:** ~180 lines after migration

### Dependencies
```
Lume Migration BLOCKED BY:
  └── Package reference setup
      └── SOLUTION: Create workspace OR wait for Xcode update
```

---

## Action Items

### Immediate (Continue FitIQ Migration)
- [x] Document Lume blocker
- [ ] Migrate NutritionAPIClient (next)
- [ ] Continue with remaining 8 API clients
- [ ] Complete FitIQ migration (2-3 days)

### After FitIQ Complete
- [ ] Create FitIQ.xcworkspace
- [ ] Add FitIQ, Lume, FitIQCore to workspace
- [ ] Verify Lume can reference FitIQCore
- [ ] Proceed with Lume migration

### Alternative (If Urgent)
- [ ] Try workspace approach immediately
- [ ] Parallelize: FitIQ migration + Workspace setup
- [ ] Both projects use FitIQCore simultaneously

---

## Lessons Learned

1. **Xcode Version Matters:** Local package references are version-sensitive
2. **GUI is Safer:** Manual pbxproj editing is fragile across Xcode versions
3. **Workspaces for Multi-Project:** Better approach for shared dependencies
4. **Test Package Setup Early:** Catch integration issues before migration starts

---

## References

- [Lume Auth Migration Plan](./LUME_AUTH_MIGRATION.md) - Ready when unblocked
- [Lume Package Setup Instructions](./LUME_PACKAGE_SETUP_INSTRUCTIONS.md) - Manual approach (failed)
- [FitIQ Auth Migration](./FITIQ_AUTH_MIGRATION.md) - Working example (30% complete)
- [FitIQ Auth Migration Progress](./FITIQ_AUTH_MIGRATION_PROGRESS.md) - Current status

---

## Recommendation

**Proceed with FitIQ migration to completion.** 

Lume can follow after:
1. FitIQ establishes full migration pattern
2. Workspace approach resolves package reference issue
3. Proven patterns from FitIQ apply to Lume

**Timeline:**
- FitIQ completion: 2-3 days
- Workspace setup: 1 day
- Lume migration: 1 day
- **Total: 4-5 days to complete both**

vs. spending days debugging Xcode package issues.

---

**Status:** Lume migration postponed pending workspace setup  
**Next Step:** Continue with FitIQ NutritionAPIClient migration  
**Last Updated:** 2025-01-27