# Offline-First Authentication

**Version:** 1.0.0  
**Last Updated:** 2025-01-16  
**Purpose:** Documentation for Lume's offline-first authentication strategy

---

## Overview

Lume implements an **offline-first authentication strategy** that allows users to continue using the app even when they don't have internet connectivity. This is critical for scenarios like:

- Long flights ✈️
- Remote areas with poor connectivity 🏔️
- Underground transit 🚇
- Data-saving mode 📱

Users should be able to log moods, write journal entries, and view their data offline. All changes are automatically queued and synced when connectivity returns.

---

## Core Principles

### 1. Local Session is Source of Truth

The `UserSession` singleton maintains the authenticated state locally using `UserDefaults`. This state persists across app restarts and doesn't require network access to verify.

```swift
// Check if user is authenticated (works offline)
if UserSession.shared.isAuthenticated {
    // User can access the app
}
```

### 2. Token Validation Only When Online

Token validation and refresh operations only happen when the device has internet connectivity. The `NetworkMonitor` detects connectivity status and gates network operations.

```swift
if networkMonitor.isConnected {
    // Validate and refresh token if needed
    await validateAndRefreshTokenIfNeeded()
} else {
    // Allow app usage with local session
    print("📴 Offline - using local session")
}
```

### 3. Graceful Degradation

When offline:
- ✅ Users can view existing data
- ✅ Users can create new entries (mood, journal, goals)
- ✅ All changes are queued for sync via Outbox pattern
- ❌ AI features that require backend may be unavailable
- ❌ Real-time sync is paused

When online:
- ✅ Tokens are validated and refreshed automatically
- ✅ Queued changes sync to backend
- ✅ All features available

---

## Architecture Components

### 1. NetworkMonitor

Monitors network connectivity using Apple's `Network` framework.

**Location:** `lume/Core/Network/NetworkMonitor.swift`

**Key Features:**
- Real-time connectivity detection
- Connection type identification (WiFi, Cellular, Ethernet)
- Published properties for SwiftUI observation
- Singleton pattern for app-wide access

**Usage:**
```swift
@StateObject private var networkMonitor = NetworkMonitor.shared

var body: some View {
    if networkMonitor.isConnected {
        Text("Online ✅")
    } else {
        Text("Offline 📴")
    }
}
```

### 2. UserSession

Manages authenticated user state locally.

**Location:** `lume/Core/UserSession.swift`

**Key Features:**
- Thread-safe session management
- Persists across app restarts
- No network dependency
- Stores user ID, email, name, date of birth

**Key Methods:**
```swift
// Start session (called after successful login/register)
UserSession.shared.startSession(
    userId: user.id,
    email: user.email,
    name: user.name,
    dateOfBirth: user.dateOfBirth
)

// Check authentication status
let isAuth = UserSession.shared.isAuthenticated

// Get current user ID
let userId = UserSession.shared.currentUserId

// End session (logout)
UserSession.shared.endSession()
```

### 3. RootView Authentication Flow

Implements the offline-first authentication checking logic.

**Location:** `lume/Presentation/RootView.swift`

**Authentication Steps:**

```
┌─────────────────────────────────────┐
│     App Launch / RootView.task      │
└──────────────┬──────────────────────┘
               │
               ▼
      ┌────────────────────┐
      │ Check UserSession  │
      │  .isAuthenticated  │
      └────────┬───────────┘
               │
        ┌──────┴───────┐
        │              │
    YES │              │ NO
        │              │
        ▼              ▼
┌──────────────┐  ┌───────────────┐
│ Authenticated│  │ Check Stored  │
│    State     │  │    Token      │
└──────┬───────┘  └───────┬───────┘
       │                  │
       │           ┌──────┴───────┐
       │           │              │
       │       YES │              │ NO
       │           │              │
       │           ▼              ▼
       │    ┌─────────────┐  ┌─────────┐
       │    │   Online?   │  │ Show    │
       │    └──────┬──────┘  │ Login   │
       │           │         └─────────┘
       │     ┌─────┴─────┐
       │     │           │
       │ YES │           │ NO
       │     │           │
       │     ▼           ▼
       │  ┌──────┐  ┌────────┐
       │  │Valid?│  │ Trust  │
       │  └──┬───┘  │ Token  │
       │     │      └───┬────┘
       │  ┌──┴──┐       │
       │  │     │       │
       │ YES   NO       │
       │  │     │       │
       ▼  ▼     ▼       ▼
    ┌────────────────────┐
    │   Show Main App    │
    └────────────────────┘
```

**Key Logic:**

1. **Check Local Session First**
   - If `UserSession.isAuthenticated` is true, allow app access
   - Only validate token if online (background operation)

2. **No Local Session**
   - Check for stored token in Keychain
   - If no token → show login screen
   - If token exists and online → validate it
   - If token exists and offline → trust it and allow access

3. **Background Token Refresh**
   - When online with active session, validate token
   - If expired, refresh automatically
   - If refresh fails, user stays logged in (offline mode)

---

## Outbox Pattern and Offline Sync

### How It Works

All data changes are written to a local `SDOutboxEvent` queue before attempting backend sync.

**Location:** `lume/Services/Outbox/OutboxProcessorService.swift`

**Offline Behavior:**

```swift
// OutboxProcessorService checks network before syncing
guard networkMonitor.isConnected else {
    print("📴 Offline - skipping sync (events queued)")
    return
}

// Only process when online
await processOutboxEvents()
```

**Event Flow:**

```
User Action (Create Mood, Journal Entry, etc.)
    ↓
Write to SwiftData (Local DB)
    ↓
Create SDOutboxEvent (status: pending)
    ↓
OutboxProcessor checks network
    ↓
    ├─ OFFLINE → Event stays in queue
    │
    └─ ONLINE → Send to backend
              ↓
              ├─ SUCCESS → Mark event as completed
              │
              └─ FAILURE → Retry with backoff
```

**Benefits:**
- ✅ No data loss
- ✅ Automatic retry
- ✅ Works offline
- ✅ Resilient to crashes

---

## Implementation Checklist

When implementing features that require authentication:

- [ ] Check `UserSession.shared.isAuthenticated` for auth state
- [ ] Don't force logout if token refresh fails when offline
- [ ] Use Outbox pattern for all backend writes
- [ ] Check `NetworkMonitor.shared.isConnected` before network calls
- [ ] Handle offline state gracefully in UI
- [ ] Queue operations when offline, sync when online
- [ ] Test offline scenarios thoroughly

---

## Testing Offline Scenarios

### Simulator Testing

1. **Enable Airplane Mode:**
   ```
   Settings → Toggle Airplane Mode ON
   ```

2. **Network Link Conditioner:**
   ```
   Additional Tools for Xcode → Network Link Conditioner
   Select "100% Loss" profile
   ```

3. **Xcode Network Debugging:**
   ```
   Run Scheme → Options → Network Conditioning
   Select "Very Bad Network" or "Extremely Bad Network"
   ```

### Test Cases

#### ✅ Offline Login Prevention
1. Launch app while offline
2. User has valid local session
3. **Expected:** App opens to main screen
4. **Verify:** No "Please log in" error

#### ✅ Offline Data Creation
1. Open app while offline
2. Create mood entry
3. Write journal entry
4. **Expected:** All actions succeed locally
5. **Verify:** Outbox events created

#### ✅ Automatic Sync on Reconnection
1. Create data while offline (queued in outbox)
2. Turn on internet connection
3. **Expected:** Data automatically syncs to backend
4. **Verify:** Outbox events marked as completed

#### ✅ Background Token Refresh
1. User authenticated with expiring token
2. Come back online after offline period
3. **Expected:** Token refreshes automatically
4. **Verify:** No logout, seamless experience

#### ❌ Token Refresh Failure (Offline)
1. User has expired token
2. App tries to refresh while offline
3. **Expected:** Refresh fails gracefully
4. **Verify:** User NOT logged out, can still use app

---

## Security Considerations

### Token Storage
- ✅ Tokens stored in iOS Keychain (secure)
- ✅ Tokens never logged or exposed
- ✅ Automatic cleanup on logout

### Offline Trust Model
When offline, we **trust the local session** because:
1. Session was validated when user logged in (online)
2. Device is physically secured by user's passcode/biometrics
3. Alternative would be to lock user out (bad UX)

### Session Expiry
Sessions remain valid indefinitely when offline. When online:
- Token expiry is enforced
- Expired tokens are refreshed or user is logged out
- This prevents stale sessions from persisting forever

---

## Edge Cases and Handling

### 1. Token Expires While Offline
**Scenario:** User goes offline for 7+ days, token expires  
**Handling:** Trust local session until online, then refresh token  
**Outcome:** Seamless experience, no data loss

### 2. User Changes Password on Another Device
**Scenario:** User changes password on web, then opens iOS app offline  
**Handling:** App works offline with old session, fails to sync when online  
**Outcome:** User prompted to re-authenticate when sync fails

### 3. App Crash During Sync
**Scenario:** App crashes while syncing outbox events  
**Handling:** Outbox events remain in "pending" state  
**Outcome:** Next sync attempt retries pending events

### 4. Account Deleted on Backend
**Scenario:** Account deleted on web, user opens iOS app offline  
**Handling:** App works offline, API returns 404 when online  
**Outcome:** User prompted to log in, local data cleared

---

## Monitoring and Debugging

### Logs to Watch

**Network Status Changes:**
```
🌐 [NetworkMonitor] Network status: connected via WiFi
🌐 [NetworkMonitor] Network status: disconnected via Unknown
```

**Authentication Flow:**
```
✅ [RootView] User has active local session
📴 [RootView] Offline - allowing app usage with local session
🌐 [RootView] Online - validating token in background
```

**Outbox Processing:**
```
📴 [OutboxProcessor] Offline - skipping sync (events queued)
✅ [OutboxProcessor] Online - processing 5 pending events
```

**Session Management:**
```
✅ [UserSession] Session started for user: user@example.com
✅ [UserSession] Session ended for user ID: uuid-here
```

---

## Performance Considerations

### Battery Life
- Network monitoring has minimal battery impact
- Outbox processor uses configurable intervals (default: 30s)
- Consider increasing interval to 60s+ for battery savings

### Data Usage
- Sync only when online
- Consider implementing WiFi-only sync option for users
- Batch outbox events to reduce network calls

### Storage
- Outbox events stored locally until synced
- Implement cleanup for old completed events
- Monitor SwiftData storage growth

---

## Future Enhancements

### Planned Features
1. **Connectivity Banner**
   - Show subtle indicator when offline
   - Notify user when sync resumes

2. **WiFi-Only Sync Option**
   - Let users disable cellular sync
   - Battery and data savings

3. **Manual Sync Button**
   - Force sync attempt
   - Show sync progress

4. **Conflict Resolution**
   - Handle data conflicts when same entry edited on multiple devices
   - Last-write-wins strategy

5. **Offline Indicator in UI**
   - Badge on entries not yet synced
   - Visual feedback for pending sync

---

## Resources

### Apple Documentation
- [Network Framework](https://developer.apple.com/documentation/network)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Background Tasks](https://developer.apple.com/documentation/backgroundtasks)

### Related Docs
- `docs/architecture/HEXAGONAL_ARCHITECTURE.md`
- `docs/backend-integration/OUTBOX_PATTERN.md`
- `docs/authentication/USER_SESSION_IMPLEMENTATION.md`

---

## Summary

Lume's offline-first authentication ensures users can always access their wellness data, regardless of connectivity. By using local session state as the source of truth and only validating tokens when online, we provide a seamless experience that respects the user's context and needs.

**Key Takeaways:**
- 🔐 Local session = source of truth
- 🌐 Network validation only when online
- 📦 Outbox pattern queues all changes
- 🔄 Automatic sync on reconnection
- 💪 Resilient to network failures

This approach aligns with Lume's core principle: **warm, calm, and always available when you need it.**