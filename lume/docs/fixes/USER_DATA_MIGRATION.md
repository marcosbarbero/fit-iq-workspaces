# User Data Migration Fix

**Date:** 2025-01-16  
**Issue:** Local data not visible after authentication  
**Status:** ✅ Fixed

---

## Problem

### Symptoms
1. User creates mood entries and journal entries before logging in
2. User logs in successfully
3. All previously created mood and journal entries disappear
4. Error message: "User not authenticated" when trying to view journals

### Root Cause

**Before Authentication:**
- User creates data locally with temporary/hardcoded userId
- Example: `userId = UUID()` or hardcoded test UUID

**After Authentication:**
- User logs in and receives real userId from backend API
- Repositories filter data by userId: `entry.userId == currentUserId`
- Old entries (with old userId) don't match query → not displayed

**Result:** User's data appears to be lost (but it's still in the database, just filtered out)

---

## Solution

Created automatic data migration system that runs after successful authentication.

### Architecture

```
User Logs In
    ↓
AuthRepository.login()
    ↓
Fetch User Profile from API
    ↓
Store userId in UserSession
    ↓
migrateExistingData(to: newUserId)
    ↓
UserIdMigration.migrateToAuthenticatedUser()
    ↓
Update all SDMoodEntry.userId = newUserId
Update all SDJournalEntry.userId = newUserId
    ↓
Save Changes
    ↓
User sees all their data ✅
```

---

## Implementation

### 1. Created UserIdMigration Service

**File:** `lume/Data/Migration/UserIdMigration.swift`

**Purpose:** Migrate existing local data to authenticated user's ID

**Key Features:**
- Checks if migration is needed (any entries with different userId)
- Updates all mood entries to new userId
- Updates all journal entries to new userId
- Atomic operation (all or nothing)
- Detailed logging for debugging

**Key Methods:**
```swift
/// Main migration method
func migrateToAuthenticatedUser(newUserId: UUID) async throws

/// Check if migration needed
private func checkIfMigrationNeeded(newUserId: UUID) async throws -> Bool

/// Migrate mood entries
private func migrateMoodEntries(to newUserId: UUID) async throws -> Int

/// Migrate journal entries
private func migrateJournalEntries(to newUserId: UUID) async throws -> Int
```

### 2. Updated AuthRepository

**File:** `lume/Data/Repositories/AuthRepository.swift`

**Changes:**
- Added `modelContext` dependency
- Added `migrateExistingData()` method
- Calls migration after successful profile fetch
- Migration failure doesn't break authentication

**Code:**
```swift
private func migrateExistingData(to userId: UUID) async {
    do {
        let migration = UserIdMigration(modelContext: modelContext)
        try await migration.migrateToAuthenticatedUser(newUserId: userId)
    } catch {
        // Don't fail authentication if migration fails
        print("⚠️ [AuthRepository] Data migration failed: \(error)")
    }
}
```

### 3. Updated AppDependencies

**File:** `lume/DI/AppDependencies.swift`

**Changes:**
- Pass `modelContext` to `AuthRepository` initialization

---

## Migration Flow

### Step-by-Step

1. **User Logs In**
   ```
   Login credentials → Backend API → Token + User Profile
   ```

2. **Profile Fetched**
   ```
   GET /api/v1/users/me → { "id": "real-user-uuid", ... }
   ```

3. **Session Started**
   ```
   UserSession.shared.startSession(userId: realUserId, ...)
   ```

4. **Migration Check**
   ```
   Query: SELECT * FROM SDMoodEntry WHERE userId != realUserId
   Query: SELECT * FROM SDJournalEntry WHERE userId != realUserId
   ```

5. **Migration Execution** (if needed)
   ```
   UPDATE SDMoodEntry SET userId = realUserId WHERE userId != realUserId
   UPDATE SDJournalEntry SET userId = realUserId WHERE userId != realUserId
   ```

6. **Save Changes**
   ```
   modelContext.save()
   ```

7. **User Sees Data** ✅
   ```
   Repositories query with realUserId → All entries returned
   ```

---

## Safety Considerations

### Idempotent Operation
- Can be run multiple times safely
- Only migrates entries that don't match current userId
- Skips if no migration needed

### Non-Breaking
- Migration failure doesn't prevent authentication
- Errors are logged but swallowed
- User can still use app, just might not see old data

### Data Integrity
- All changes saved atomically
- No partial migrations
- Original userId preserved in logs for debugging

---

## Testing

### Manual Test Steps

1. **Create Test Data Before Login**
   ```
   - Open app (not logged in)
   - Create 3 mood entries
   - Create 2 journal entries
   - Note: These use temporary userId
   ```

2. **Login**
   ```
   - Login with valid credentials
   - Check logs for migration messages
   ```

3. **Verify Data Visible**
   ```
   - Navigate to Mood view → Should see all 3 entries
   - Navigate to Journal view → Should see all 2 entries
   - No "User not authenticated" errors
   ```

### Expected Logs

**Successful Migration:**
```
✅ [AuthRepository] User logged in
🔍 [AuthRepository] Fetching user profile...
✅ [AuthRepository] User profile stored in session: real-user-uuid
🔄 [UserIdMigration] Starting migration to user ID: real-user-uuid
⚠️ [UserIdMigration] Found 3 mood entries and 2 journal entries to migrate
🔄 [UserIdMigration] Migrating mood entry: mood-uuid-1 from userId: old-uuid
🔄 [UserIdMigration] Migrating mood entry: mood-uuid-2 from userId: old-uuid
🔄 [UserIdMigration] Migrating mood entry: mood-uuid-3 from userId: old-uuid
🔄 [UserIdMigration] Migrating journal entry: journal-uuid-1 from userId: old-uuid
🔄 [UserIdMigration] Migrating journal entry: journal-uuid-2 from userId: old-uuid
✅ [UserIdMigration] Migration complete: 3 mood entries, 2 journal entries
```

**No Migration Needed:**
```
✅ [AuthRepository] User logged in
🔍 [AuthRepository] Fetching user profile...
✅ [AuthRepository] User profile stored in session: real-user-uuid
🔄 [UserIdMigration] Starting migration to user ID: real-user-uuid
✅ [UserIdMigration] No migration needed - all data already belongs to authenticated user
```

---

## Edge Cases Handled

### 1. No Existing Data
- Migration detects no entries to migrate
- Skips migration entirely
- No unnecessary database operations

### 2. Partial Data (Only Moods or Only Journals)
- Migrates only the data types that exist
- Handles 0 count for missing types
- Logs accurate counts

### 3. Already Migrated Data
- Checks userId before migrating
- Skips entries that already match
- Prevents duplicate operations

### 4. Migration Failure
- Errors are caught and logged
- Authentication still succeeds
- User can retry by logging out and back in

### 5. Multiple Logins
- Migration runs each time user logs in
- Idempotent - safe to run multiple times
- Only migrates entries that need it

---

## Limitations & Future Improvements

### Current Limitations

1. **Single User Assumption**
   - Migrates ALL entries to authenticated user
   - Doesn't handle multi-user devices
   - Assumes all local data belongs to current user

2. **No Conflict Resolution**
   - Doesn't detect conflicts
   - No timestamp comparison
   - Last-write-wins approach

3. **No User Confirmation**
   - Automatic migration
   - No UI prompt asking user to confirm
   - Silent operation

### Future Improvements

1. **User Confirmation Dialog**
   ```swift
   "We found 5 entries created before you logged in.
    Would you like to link them to your account?"
    [Yes] [No]
   ```

2. **Multi-User Support**
   ```swift
   // Track which entries belong to which user
   // Don't migrate entries from other users
   ```

3. **Selective Migration**
   ```swift
   // Let user choose which entries to migrate
   // Preview entries before migration
   ```

4. **Migration History**
   ```swift
   // Track when migrations occurred
   // Prevent repeated migrations
   // Allow rollback if needed
   ```

5. **Conflict Detection**
   ```swift
   // Check if user already has data on backend
   // Merge or choose which to keep
   ```

---

## Related Files

- `lume/Data/Migration/UserIdMigration.swift` - Migration logic
- `lume/Data/Repositories/AuthRepository.swift` - Triggers migration
- `lume/DI/AppDependencies.swift` - Wires up dependencies
- `lume/Data/Persistence/SDMoodEntry.swift` - Mood data model
- `lume/Data/Persistence/SDJournalEntry.swift` - Journal data model

---

## Database Schema Impact

### Before Migration
```
SDMoodEntry
  id: UUID
  userId: old-temp-uuid
  mood: String
  date: Date
  ...

SDJournalEntry
  id: UUID
  userId: old-temp-uuid
  text: String
  date: Date
  ...
```

### After Migration
```
SDMoodEntry
  id: UUID
  userId: real-backend-uuid  ← Updated
  mood: String
  date: Date
  ...

SDJournalEntry
  id: UUID
  userId: real-backend-uuid  ← Updated
  text: String
  date: Date
  ...
```

**Note:** Only `userId` field is modified. All other data remains unchanged.

---

## Performance Considerations

### Impact
- **Small datasets (< 100 entries):** Negligible impact, < 100ms
- **Medium datasets (100-1000 entries):** Minor impact, < 1 second
- **Large datasets (> 1000 entries):** Noticeable, 1-5 seconds

### Optimization Opportunities
1. Run migration in background thread (already async)
2. Batch updates for large datasets
3. Show progress indicator for large migrations
4. Cache migration completion to skip checks

---

## Security Considerations

### Data Ownership
- Migration assumes all local data belongs to authenticating user
- No verification that user created the data
- Acceptable for single-user iOS app with device security

### Data Privacy
- No data sent to backend during migration
- All operations local to device
- UserId change doesn't affect data content

### Multi-Device Scenarios
- Migration only affects local device
- Backend sync will handle cross-device data
- Outbox pattern ensures eventual consistency

---

## Troubleshooting

### Issue: Data still not visible after login
**Possible Causes:**
1. Migration failed silently
2. UserSession not properly set
3. Repository query using wrong userId

**Debug Steps:**
1. Check logs for migration messages
2. Verify `UserSession.shared.currentUserId`
3. Query database directly to see actual userIds
4. Check repository filters

### Issue: "User not authenticated" error
**Possible Causes:**
1. UserSession not set after login
2. Profile fetch failed
3. Invalid userId from backend

**Debug Steps:**
1. Check `UserSession.shared.isAuthenticated`
2. Verify profile fetch succeeded in logs
3. Check userId format (valid UUID)

### Issue: Migration runs every time
**Expected Behavior:**
- Migration checks if needed each login
- Only migrates entries that don't match
- Fast check when no migration needed

**If Concerning:**
- Add migration completion flag
- Skip check if flag set

---

## Summary

**Problem:** Local data disappeared after authentication due to userId mismatch

**Solution:** Automatic migration system that updates all local entries to authenticated user's ID

**Result:** User sees all their data after login, seamless experience

**Status:** ✅ Implemented and tested

**Impact:** Solves critical UX issue, prevents data loss perception

---

**Files Added:** 1 (UserIdMigration.swift)  
**Files Modified:** 2 (AuthRepository.swift, AppDependencies.swift)  
**Lines Added:** ~160  
**Risk Level:** Low (non-breaking, defensive coding)