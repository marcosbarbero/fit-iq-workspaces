# Git Commit Message

## Commit Title (50 chars max)
```
fix(schema): resolve V10 migration crashes
```

## Commit Body
```
Fix critical schema migration issues in V9→V10 upgrade

This commit resolves two fatal crashes that occurred during the V9 to V10
schema migration:

ISSUE #1: Relationship Keypath Ambiguity
- SDDietaryAndActivityPreferences was incorrectly reused from V9 via typealias
- Model still referenced SDUserProfileV9, causing keypath resolution errors
- Resulted in "KeyPath does not appear to relate" fatal error on save operations

FIX #1:
- Redefined SDDietaryAndActivityPreferences in SchemaV10 with correct V10 relationships
- Updated inverse relationship to use fully qualified keypath
- Changed migration from lightweight to custom to force metadata update

ISSUE #2: Missing Field Reference in SDSleepSession
- Initial V10 implementation renamed fields (date → startDate, etc.)
- Repository code still referenced old 'date' field
- Resulted in "keypath date not found" fatal error

FIX #2:
- Restored original V9 field names in SDSleepSession (date, startTime, endTime)
- Maintained backward compatibility with existing queries and repositories

BREAKING CHANGE:
Users with existing V9 databases must delete and reinstall the app once due to
corrupted relationship metadata. All data is safely stored in backend/HealthKit
and will re-sync automatically. This is a ONE-TIME requirement; all future
schema updates will use automatic migrations.

Files Modified:
- SchemaV10.swift: Redefined models, fixed relationships, restored field names
- PersistenceMigrationPlan.swift: Changed V9→V10 to custom migration

Documentation:
- Added comprehensive schema migration best practices guide
- Added user reinstall instructions
- Added technical deep dive and lessons learned
- Added deployment plan and communication templates
```

## Short Version (if needed)
```
fix(schema): resolve V10 migration crashes

Fix two critical issues in V9→V10 migration:
1. Redefined SDDietaryAndActivityPreferences to reference V10 user profile
2. Restored original field names in SDSleepSession for compatibility

Changed to custom migration to force metadata update.

BREAKING: Users must reinstall app once (data safe, will re-sync).
```

## Tag Version
```
v1.0.1-migration-fix
```

## GitHub Release Notes
```markdown
## 🔧 Critical Fix: Schema Migration

### What's Fixed
- ✅ Resolved "KeyPath does not appear to relate" crash when saving data
- ✅ Resolved "keypath date not found" crash when fetching sleep data
- ✅ All write operations now working correctly

### ⚠️ Important: One-Time Reinstall Required

**For existing users:**
1. Delete the FitIQ app from your device
2. Reinstall from TestFlight/App Store
3. Sign in with your existing credentials
4. Your data will automatically re-sync (1-2 minutes)

**Why is this necessary?**
We fixed a critical database issue that requires a fresh installation. Your data
is safely stored in our cloud and Apple Health—nothing will be lost.

**Will this happen again?**
No! This is a ONE-TIME requirement. All future updates will install seamlessly.

### 📚 For Developers
- Added comprehensive schema migration best practices documentation
- See `docs/schema/` for detailed guides and lessons learned

### 🙏 Thank You
We apologize for the inconvenience. This one-time reinstall ensures a reliable
experience going forward.
```
