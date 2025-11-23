# Outbox Processor Login Integration

**Created:** 2025-01-31  
**Status:** ✅ Complete  
**Purpose:** Document how OutboxProcessorService starts on user authentication

---

## 🎯 Problem

The `OutboxProcessorService` needs a user ID to process events. However, `AppDependencies.build()` is called at app launch, which happens **before** the user logs in.

**Initial approach (incorrect):**
```swift
// ❌ WRONG - User might not be authenticated yet
let outboxProcessor = OutboxProcessorService(...)
if let currentUserID = authManager.currentUserProfileID {
    outboxProcessor.startProcessing(forUserID: currentUserID)
}
```

**Problem:**
- App launches → `AppDependencies.build()` called
- User not logged in yet → `currentUserProfileID` is nil
- Processor never starts!

---

## ✅ Solution: Observe Authentication State

The `OutboxProcessorService` is **created at app init** but **started on login** by observing `AuthManager.currentUserProfileID`.

### Implementation

```swift
// In AppDependencies.build()

// 1. Create processor (but don't start it)
let outboxProcessorService = OutboxProcessorService(
    outboxRepository: outboxRepository,
    progressRepository: progressRepository,
    localHealthDataStore: swiftDataLocalHealthDataStore,
    activitySnapshotRepository: swiftDataActivitySnapshotRepository,
    remoteDataSync: remoteHealthDataSyncClient,
    authManager: authManager
)

// 2. Observe authentication state changes
Task { @MainActor in
    // Check if user is already authenticated (e.g., app reopened)
    if let currentUserID = authManager.currentUserProfileID {
        print("AppDependencies: User already authenticated, starting OutboxProcessorService for user \(currentUserID)")
        outboxProcessorService.startProcessing(forUserID: currentUserID)
    }

    // Observe future authentication state changes (login/logout)
    for await userID in authManager.$currentUserProfileID.values {
        if let userID = userID {
            print("AppDependencies: User logged in, starting OutboxProcessorService for user \(userID)")
            outboxProcessorService.startProcessing(forUserID: userID)
        } else {
            print("AppDependencies: User logged out, stopping OutboxProcessorService")
            outboxProcessorService.stopProcessing()
        }
    }
}
```

---

## 🔄 Flow Diagram

### Scenario 1: Fresh App Launch (User Not Logged In)

```
App Launch
    ↓
AppDependencies.build()
    ↓
OutboxProcessorService created (NOT started)
    ↓
Task starts observing authManager.$currentUserProfileID
    ↓
currentUserProfileID = nil (no action)
    ↓
User navigates to login screen and logs in
    ↓
AuthManager.handleSuccessfulAuth(userID: UUID)
    ↓
authManager.currentUserProfileID = userID
    ↓
Observer detects change
    ↓
outboxProcessorService.startProcessing(forUserID: userID)
    ↓
✅ Processor is now running!
```

### Scenario 2: App Reopened (User Already Logged In)

```
App Launch
    ↓
AppDependencies.build()
    ↓
OutboxProcessorService created (NOT started)
    ↓
Task starts observing authManager.$currentUserProfileID
    ↓
currentUserProfileID = UUID (from saved session)
    ↓
outboxProcessorService.startProcessing(forUserID: UUID)
    ↓
✅ Processor starts immediately!
```

### Scenario 3: User Logs Out

```
User clicks logout
    ↓
AuthManager.logout()
    ↓
authManager.currentUserProfileID = nil
    ↓
Observer detects change
    ↓
outboxProcessorService.stopProcessing()
    ↓
✅ Processor stopped (no more sync attempts)
```

---

## 🔍 Technical Details

### Why Use Combine Publisher?

`AuthManager` has a `@Published` property:

```swift
class AuthManager: ObservableObject {
    @Published var currentUserProfileID: UUID?
}
```

The `@Published` property wrapper automatically creates a Combine publisher that emits values whenever the property changes.

We can observe it using:
```swift
for await userID in authManager.$currentUserProfileID.values {
    // React to changes
}
```

**Benefits:**
- ✅ Automatic - No manual registration needed
- ✅ Reactive - Responds immediately to state changes
- ✅ Lifecycle-aware - Task can be cancelled if needed
- ✅ Clean - No callbacks or delegates

---

## 📝 Key Properties in AppDependencies

The outbox components are now exposed as properties:

```swift
class AppDependencies: ObservableObject {
    // ... other properties ...
    
    // NEW: Outbox Pattern
    let outboxRepository: OutboxRepositoryProtocol
    let outboxProcessorService: OutboxProcessorService
    
    init(
        // ... other params ...
        outboxRepository: OutboxRepositoryProtocol,
        outboxProcessorService: OutboxProcessorService
    ) {
        // ... initialization ...
        self.outboxRepository = outboxRepository
        self.outboxProcessorService = outboxProcessorService
    }
}
```

**Why expose them?**
- Allows manual control if needed
- Enables debugging/monitoring
- Could be used by ViewModels for sync status UI
- Future-proof for advanced use cases

---

## 🧪 Testing the Integration

### Test 1: Fresh Login

1. **Clean install** - Delete app and reinstall
2. **Launch app** - Should see:
   ```
   AppDependencies: OutboxProcessorService created but not started (no authenticated user)
   ```
3. **Login** - Should see:
   ```
   AuthManager: User successfully authenticated. User ID: XXX
   AppDependencies: User logged in, starting OutboxProcessorService for user XXX
   OutboxProcessor: Started processing for user XXX
   ```
4. **Save weight** - Should see:
   ```
   SwiftDataProgressRepository: ✅ Created outbox event YYY
   OutboxProcessor: Processing event YYY (type: progressEntry)
   OutboxProcessor: ✅ Successfully synced progressEntry
   ```

### Test 2: App Reopen (Already Logged In)

1. **Close app** (swipe away from app switcher)
2. **Reopen app** - Should see:
   ```
   AppDependencies: User already authenticated, starting OutboxProcessorService for user XXX
   OutboxProcessor: Started processing for user XXX
   ```
3. **Verify** - Processor should immediately start processing any pending events

### Test 3: Logout

1. **While logged in** - Processor should be running
2. **Logout** - Should see:
   ```
   AuthManager: User logged out
   AppDependencies: User logged out, stopping OutboxProcessorService
   OutboxProcessor: Stopped processing
   ```
3. **Verify** - No more sync attempts in logs

---

## 🚨 Common Issues

### Issue: Processor never starts

**Symptom:**
```
AppDependencies: OutboxProcessorService created but not started
// ... no "User logged in" message after login
```

**Cause:** Observer Task not running or cancelled

**Fix:** Check if Task is properly created in `AppDependencies.build()`

---

### Issue: Processor starts multiple times

**Symptom:**
```
OutboxProcessor: Started processing for user XXX
OutboxProcessor: Started processing for user XXX  // duplicate!
```

**Cause:** Multiple instances of AppDependencies or multiple observer Tasks

**Fix:** Ensure `AppDependencies.build()` is only called once

---

### Issue: Processor doesn't stop on logout

**Symptom:**
```
AuthManager: User logged out
// ... but no "stopping OutboxProcessorService" message
```

**Cause:** Observer not detecting nil value change

**Fix:** Verify `stopProcessing()` method exists and is called in the observer

---

## 📊 Comparison: Before vs After

### Before (Manual Start in AppDependencies)

```swift
// ❌ Problem: User might not be logged in yet
if let currentUserID = authManager.currentUserProfileID {
    outboxProcessorService.startProcessing(forUserID: currentUserID)
}
```

**Issues:**
- ❌ Only checks once at app init
- ❌ Doesn't react to login events
- ❌ Doesn't handle logout
- ❌ Requires user to be already logged in at app start

---

### After (Reactive Observer)

```swift
// ✅ Reactive: Responds to login/logout automatically
Task { @MainActor in
    if let currentUserID = authManager.currentUserProfileID {
        outboxProcessorService.startProcessing(forUserID: currentUserID)
    }
    
    for await userID in authManager.$currentUserProfileID.values {
        if let userID = userID {
            outboxProcessorService.startProcessing(forUserID: userID)
        } else {
            outboxProcessorService.stopProcessing()
        }
    }
}
```

**Benefits:**
- ✅ Checks at app init (for existing sessions)
- ✅ Reacts to login events
- ✅ Reacts to logout events
- ✅ Works for fresh installs and app reopens
- ✅ Automatic lifecycle management

---

## 🎯 Best Practices

1. **Don't start processor at init** - Always wait for authentication
2. **Observe authentication state** - Use Combine publisher for reactive behavior
3. **Handle both login and logout** - Clean up resources on logout
4. **Check existing session** - Start immediately if user already logged in
5. **Log state transitions** - Makes debugging much easier

---

## 📚 Related Files

- **`AppDependencies.swift`** - Outbox initialization and observer setup
- **`AuthManager.swift`** - Authentication state management
- **`OutboxProcessorService.swift`** - Background event processor
- **`SwiftDataProgressRepository.swift`** - Creates outbox events

---

## 🔄 Future Enhancements

### Potential Improvements

1. **Multiple user support** - Switch processor when user switches accounts
2. **Background app refresh** - Resume processing when app comes to foreground
3. **Network-aware scheduling** - Pause on no internet, resume when online
4. **Battery-aware processing** - Reduce frequency on low battery
5. **Sync status UI** - Show user when sync is active/paused

---

**Status:** ✅ Production Ready  
**Tested:** Login, logout, app reopen scenarios  
**Version:** 1.0  
**Last Updated:** 2025-01-31