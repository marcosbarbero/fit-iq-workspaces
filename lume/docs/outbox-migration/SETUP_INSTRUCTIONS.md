# Lume Outbox Migration - Setup Instructions

**Date:** 2025-01-27  
**Status:** 🔧 Setup Required  
**Estimated Time:** 5 minutes

---

## Prerequisites

- ✅ Xcode 15.0 or later
- ✅ FitIQCore package available at `../FitIQCore`
- ✅ Lume project open in Xcode

---

## Step 1: Link FitIQCore Package to Lume

### Option A: Using Xcode UI (Recommended)

1. **Open Lume Project**
   ```bash
   cd /Users/marcosbarbero/Develop/GitHub/fit-iq/lume
   open lume.xcodeproj
   ```

2. **Add Local Package Dependency**
   - In Xcode, select the `lume` project in the navigator
   - Go to the `lume` target → **General** tab
   - Scroll down to **Frameworks, Libraries, and Embedded Content**
   - Click the **+** button

3. **Add FitIQCore**
   - Click **Add Other...** → **Add Package Dependency...**
   - Click **Add Local...**
   - Navigate to: `/Users/marcosbarbero/Develop/GitHub/fit-iq/FitIQCore`
   - Click **Add Package**

4. **Select Product**
   - In the "Choose Package Products" dialog:
   - Check ✅ **FitIQCore**
   - Click **Add Package**

5. **Verify Installation**
   - In Project Navigator, expand `lume` → `Swift Packages`
   - You should see `FitIQCore (Local)` listed

### Option B: Manual Package.swift Edit (Alternative)

If using SPM directly, add to `Package.swift`:

```swift
dependencies: [
    .package(path: "../FitIQCore")
]

targets: [
    .target(
        name: "lume",
        dependencies: ["FitIQCore"]
    )
]
```

---

## Step 2: Verify FitIQCore Import

1. **Clean Build Folder**
   - In Xcode: **Product** → **Clean Build Folder** (⇧⌘K)

2. **Build Project**
   - In Xcode: **Product** → **Build** (⌘B)

3. **Check for Errors**
   - Should see: "Build Succeeded"
   - If you see "No such module 'FitIQCore'", restart Xcode

---

## Step 3: Verify Schema Migration

The schema has been updated from V6 → V7 with the new OutboxEvent structure.

**Check:**
1. Open `lume/Data/Persistence/SchemaVersioning.swift`
2. Verify line 16 shows: `static let current = SchemaV7.self`
3. Verify `SchemaV7` exists with new `SDOutboxEvent` structure

**If migration fails:**
- Delete app from simulator
- Clean build folder
- Rebuild and run

---

## Step 4: Test Migration

1. **Run App in Simulator**
   ```bash
   # Or use Xcode: Product → Run (⌘R)
   ```

2. **Check Console for Schema Migration**
   Look for log messages like:
   ```
   Starting V6→V7 migration: Outbox Pattern upgrade
   Completed V6→V7 migration
   ```

3. **Create Test Event**
   - Log a mood or journal entry
   - Check console for:
   ```
   📦 [OutboxRepository] Event created - EventID: ... | Type: [Mood Entry]
   ```

---

## Step 5: Verify Adapter Pattern

1. **Check Files Exist**
   ```bash
   ls -la lume/Data/Persistence/Adapters/OutboxEventAdapter.swift
   ls -la lume/Data/Repositories/SwiftDataOutboxRepository.swift
   ls -la lume/Domain/Ports/OutboxRepositoryProtocol.swift
   ```

2. **All files should exist and contain FitIQCore imports**

---

## Troubleshooting

### Error: "No such module 'FitIQCore'"

**Solution:**
1. Restart Xcode (⌘Q then reopen)
2. Clean build folder (⇧⌘K)
3. Rebuild (⌘B)

### Error: "Missing package product 'FitIQCore'"

**Solution:**
1. Remove FitIQCore from project
2. Re-add using Step 1 above
3. Make sure you're pointing to the correct directory

### Error: "Duplicate symbol" or "Redeclaration"

**Solution:**
- Check that old `OutboxEvent` struct is removed from `OutboxRepositoryProtocol.swift`
- Should only have `typealias` declarations

### Error: Schema migration fails

**Solution:**
1. Delete app from simulator
2. Clean build folder
3. Rebuild
4. If still fails, check `SchemaVersioning.swift` has `SchemaV7` correctly defined

### Build succeeds but imports fail

**Solution:**
- Language server cache issue
- Restart Xcode completely
- Build should still succeed even if editor shows error

---

## Verification Checklist

- [ ] FitIQCore package added to Xcode project
- [ ] Build succeeds (⌘B)
- [ ] No "module not found" errors
- [ ] Schema shows V7 as current
- [ ] App runs without crashes
- [ ] Can create mood/journal entries
- [ ] Outbox events are created (check console logs)

---

## Next Steps

Once setup is complete:

1. **Update Call Sites** - See `CALL_SITES_MIGRATION.md`
2. **Test Thoroughly** - See `TESTING_GUIDE.md`
3. **Review Changes** - See `MIGRATION_SUMMARY.md`

---

## Support

**Issues?**
- Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Review [FitIQ Migration Docs](../../FitIQ/docs/outbox-migration/)
- Ask in team channel with error message

---

**Setup Time:** ~5 minutes  
**Complexity:** Low  
**Risk:** Low (proven patterns from FitIQ)

---

**END OF SETUP INSTRUCTIONS**