# Local Sync Verification Guide

**Purpose:** Verify that local data is being synced to remote API for backup and AI analysis  
**Last Updated:** 2025-01-31  
**Status:** ✅ Active

---

## Overview

Since **local data is your source of truth** and remote is primarily for backup/AI analysis, you need ways to verify that:

1. ✅ Local entries are marked as "pending" when created
2. ✅ Background sync is picking them up
3. ✅ Remote API receives the data
4. ✅ Local entries are updated with backend IDs and marked as "synced"

---

## Quick Verification Methods

### Method 1: Watch Console Logs (Easiest)

**What to look for:**

```
RemoteSyncService: 📤 Processing progressEntry sync event for localID <UUID>
RemoteSyncService: Found progress entry to sync:
  - Type: weight
  - Quantity: 72.0
  - Date: 2025-01-31
  - Current sync status: pending
RemoteSyncService: Updated sync status to 'syncing'
RemoteSyncService: 🌐 Calling /api/v1/progress API to upload progress entry...
RemoteSyncService: ✅ /api/v1/progress API call successful!
  - Backend ID: c7fabe81-8e68-4742-9fb1-700ae5018e9e
RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry <UUID>. Type: weight, Quantity: 72.0, Backend ID: <UUID>
```

**Good signs:**
- ✅ Entries go from `pending` → `syncing` → `synced`
- ✅ Backend ID is received and saved
- ✅ API call returns 200 status

**Bad signs:**
- ❌ Entries stuck in `pending` forever
- ❌ `❌ /api/v1/progress API call FAILED!`
- ❌ No backend ID returned
- ❌ Entries marked as `failed`

---

### Method 2: Check Database Directly (Xcode)

**Steps:**

1. Run app in simulator/device
2. Add a weight entry (e.g., 72 kg)
3. Pause execution in Xcode
4. Open **Debug Memory Graph** (or use lldb)
5. Inspect SwiftData entries:

```lldb
po try? await progressRepository.fetchLocal(forUserID: "<user-id>", type: .weight, syncStatus: nil)
```

**What to check:**
- New entries should have `syncStatus = .pending`
- After a few seconds, should change to `syncStatus = .synced`
- `backendID` should be populated (not `nil`)

---

### Method 3: Use Debug View (Recommended for Development)

We've created a `SyncDebugViewModel` and `VerifyRemoteSyncUseCase` for this.

**Add to your app temporarily:**

```swift
import SwiftUI

struct SyncDebugView: View {
    @State private var viewModel: SyncDebugViewModel
    
    init(verifySyncUseCase: VerifyRemoteSyncUseCase) {
        _viewModel = State(initialValue: SyncDebugViewModel(verifySyncUseCase: verifySyncUseCase))
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Sync Status Section
                Section("Sync Health") {
                    if let status = viewModel.syncStatus {
                        LabeledContent("Total Entries", value: "\(status.totalEntries)")
                        LabeledContent("Pending", value: "\(status.pendingCount)")
                        LabeledContent("Synced", value: "\(status.syncedCount)")
                        LabeledContent("Failed", value: "\(status.failedCount)")
                        LabeledContent("Sync %", value: String(format: "%.1f%%", status.syncPercentage))
                        LabeledContent("Status", value: viewModel.syncHealthStatus)
                    }
                    
                    Button("Refresh Status") {
                        Task { await viewModel.loadSyncStatus() }
                    }
                }
                
                // Pending Entries Section
                Section("Pending Sync") {
                    if viewModel.pendingEntries.isEmpty {
                        Text("✅ No pending entries")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.pendingEntries, id: \.localID) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(entry.type.rawValue): \(entry.quantity)")
                                    .font(.headline)
                                Text("Created \(entry.ageDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Button("Refresh Pending") {
                        Task { await viewModel.loadPendingEntries() }
                    }
                }
                
                // Manual Sync Section
                Section("Manual Actions") {
                    Button("Trigger Manual Sync") {
                        Task { await viewModel.triggerManualSync() }
                    }
                    .disabled(viewModel.pendingEntries.isEmpty)
                    
                    if let result = viewModel.manualSyncResult {
                        Text("Triggered \(result.triggeredCount) entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Consistency Check Section
                Section("Consistency") {
                    Picker("Type", selection: $viewModel.selectedType) {
                        ForEach([ProgressType.weight, .steps, .heartRate], id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Button("Verify Consistency") {
                        Task { await viewModel.verifyConsistency() }
                    }
                    
                    if let report = viewModel.consistencyReport {
                        LabeledContent("Local Synced", value: "\(report.localSynced)")
                        LabeledContent("Remote Total", value: "\(report.remoteTotal)")
                        LabeledContent("Matching", value: "\(report.matchingCount)")
                        LabeledContent("Only Local", value: "\(report.onlyLocalCount)")
                        LabeledContent("Only Remote", value: "\(report.onlyRemoteCount)")
                        LabeledContent("Status", value: viewModel.consistencyStatus)
                    }
                }
            }
            .navigationTitle("Sync Debug")
            .toolbar {
                Button("Refresh All") {
                    Task { await viewModel.refreshAll() }
                }
            }
        }
        .task {
            await viewModel.refreshAll()
        }
    }
}
```

**Add to your settings/profile screen:**

```swift
NavigationLink("🔧 Sync Debug") {
    SyncDebugView(verifySyncUseCase: dependencies.verifySyncUseCase)
}
```

---

### Method 4: Verify via API Directly (cURL)

**Get your auth token from console:**

```
ProgressAPIClient: Using access token: eyJhbGci...
```

**Query remote API:**

```bash
# Get your weight entries from remote
curl -X GET 'https://fit-iq-backend.fly.dev/api/v1/progress?type=weight&limit=10' \
  -H 'Authorization: Bearer YOUR_TOKEN_HERE' \
  -H 'X-API-Key: YOUR_API_KEY_HERE' \
  | jq '.data.entries'
```

**What to check:**
- Recent entries you just logged should appear
- `id` in response = `backendID` in local database
- `date` and `quantity` should match local entries

---

## Understanding Sync Flow

### Normal Flow (Happy Path)

```
1. User logs weight
   ↓
2. SaveWeightProgressUseCase saves to local SwiftData
   ↓ (status = .pending, backendID = nil)
   ↓
3. SaveWeightProgressUseCase publishes LocalDataNeedsSyncEvent
   ↓
4. RemoteSyncService listens for event
   ↓
5. RemoteSyncService picks up event
   ↓ (updates status to .syncing)
   ↓
6. RemoteSyncService calls POST /api/v1/progress
   ↓
7. Remote API responds with backend ID
   ↓
8. RemoteSyncService updates local entry:
   - backendID = <uuid>
   - status = .synced
   ↓
9. ✅ Sync complete!
```

**Timeline:**
- Step 1-3: Instant (< 100ms)
- Step 4-5: ~0.5s (rate limiting delay)
- Step 6-7: ~500-1000ms (network latency)
- Step 8-9: ~50ms (local update)

**Total:** 1-2 seconds from user action to sync complete

---

### Rate Limiting

RemoteSyncService has built-in rate limiting:

```swift
private let minimumProgressSyncInterval: TimeInterval = 0.5  // 0.5 seconds
```

**Why?**
- Prevents overwhelming the API with rapid entries
- Batches multiple entries if user logs quickly
- Still fast enough for good UX

**Visible in logs:**
```
RemoteSyncService: ⏱️ Rate limiting: Waiting 0.35s before next sync
```

---

## Common Issues & Fixes

### Issue 1: Entries Stuck in "Pending"

**Symptoms:**
- Entries have `syncStatus = .pending`
- No backend ID after several minutes
- Console shows no sync activity

**Possible Causes:**
1. RemoteSyncService not started
2. No internet connection
3. Auth token expired
4. API rate limit hit

**How to Fix:**

1. **Check RemoteSyncService is running:**
   ```
   // Look for this log on app start:
   RemoteSyncService: Starting to listen for local data sync events for user <UUID>
   ```

2. **Manually trigger sync:**
   ```swift
   // Use SyncDebugView → "Trigger Manual Sync"
   // Or programmatically:
   await verifySyncUseCase.triggerManualSync()
   ```

3. **Check network connectivity:**
   ```bash
   curl -I https://fit-iq-backend.fly.dev/health
   ```

4. **Check auth token:**
   ```
   // Look for 401 errors in console:
   ProgressAPIClient: Response status code: 401
   ```

---

### Issue 2: Entries Marked as "Failed"

**Symptoms:**
- Console shows `❌ /api/v1/progress API call FAILED!`
- Entries have `syncStatus = .failed`

**Common Errors:**

**A. Validation Error (400):**
```json
{"error": "Invalid quantity value"}
```
**Fix:** Check data validation logic in SaveWeightProgressUseCase

**B. Duplicate Entry (409):**
```json
{"error": "Entry already exists for this date"}
```
**Fix:** Backend deduplication - not an issue, just skip

**C. Network Error:**
```
Error: The Internet connection appears to be offline
```
**Fix:** Will auto-retry when connection restored

**How to Retry Failed Entries:**

```swift
// Get failed entries
let failed = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: nil,
    syncStatus: .failed
)

// Reset to pending
for entry in failed {
    try await progressRepository.updateSyncStatus(
        forLocalID: entry.id,
        status: .pending,
        forUserID: userID
    )
}

// Trigger manual sync
await verifySyncUseCase.triggerManualSync()
```

---

### Issue 3: Inconsistent Local vs Remote

**Symptoms:**
- Local has 100 entries, remote has 80
- Recent entries missing from remote
- Consistency check shows < 95%

**Possible Causes:**
1. Sync interrupted (app killed, network lost)
2. Some entries marked as failed
3. Rate limiting causing backlog

**How to Fix:**

1. **Check failed entries:**
   ```swift
   await viewModel.loadSyncStatus()
   // Look at failedCount
   ```

2. **Trigger bulk sync:**
   ```swift
   await verifySyncUseCase.triggerManualSync()
   // Wait 30 seconds
   await verifySyncUseCase.verifyConsistency(for: .weight)
   ```

3. **If still inconsistent, check backend logs:**
   - Are entries reaching the API?
   - Is API rejecting them?
   - Check backend DB directly

---

## Testing Sync Locally

### Test Case 1: Single Entry Sync

**Steps:**
1. Open app
2. Navigate to weight detail view
3. Log a new weight (e.g., 72 kg)
4. Watch console for sync logs
5. After 2-3 seconds, check:
   - Console shows `✅✅✅ Successfully synced`
   - Entry has backend ID
   - Status is `synced`

**Expected Timeline:**
- 0s: Entry created (pending)
- 0.5s: Sync event triggered
- 1-2s: API call complete
- 2s: Status updated to synced

---

### Test Case 2: Bulk Sync (Historical Data)

**Steps:**
1. Open app
2. Trigger HealthKit sync (if you have historical data)
3. Watch console for:
   ```
   GetHistoricalWeightUseCase: [Background] ✅ Found 44 HealthKit samples
   GetHistoricalWeightUseCase: [Background] ✅ Sync complete: 5 new, 39 duplicates
   ```
4. Open SyncDebugView
5. Check pending count (should be 5 from above)
6. Click "Trigger Manual Sync"
7. Watch console for bulk sync activity
8. After 10-20 seconds, refresh status
9. Pending count should be 0

**Expected Timeline:**
- 0s: 5 entries pending
- 0-10s: Rate-limited sync (0.5s per entry)
- 10s: All synced

---

### Test Case 3: Offline → Online

**Steps:**
1. Enable airplane mode
2. Log a weight entry
3. Check console - should see retry errors
4. Entry should be marked as `failed` or stay `pending`
5. Disable airplane mode
6. Wait 30 seconds
7. Check if entry auto-retries

**Current Behavior:**
- Entries will remain `failed` until manually retried
- No auto-retry on network restore (yet)

**Future Enhancement:**
- Add network reachability observer
- Auto-retry failed entries when network restored

---

## Monitoring in Production

### Key Metrics to Track

1. **Sync Success Rate**
   - Target: > 95% of entries successfully synced within 5s
   - Alert if: < 90% or > 10 failed entries

2. **Pending Backlog**
   - Target: < 5 pending entries under normal operation
   - Alert if: > 20 pending entries for > 1 minute

3. **API Error Rate**
   - Target: < 1% 5xx errors
   - Alert if: > 5% errors in 5-minute window

4. **Consistency Check**
   - Target: > 95% consistency between local synced and remote
   - Alert if: < 90% consistency

---

## Debug Checklist

When debugging sync issues, check:

- [ ] RemoteSyncService is running (check startup logs)
- [ ] User is authenticated (auth token present)
- [ ] Network connectivity (can reach API)
- [ ] No pending entries older than 1 minute
- [ ] No failed entries (or < 5% failure rate)
- [ ] Backend IDs are being saved to local entries
- [ ] Consistency check shows > 95%
- [ ] Console shows successful sync logs
- [ ] API returns 200 status codes
- [ ] Rate limiting is not causing excessive delays

---

## Useful Console Commands

### Filter for sync logs only:
```
RemoteSyncService
```

### Filter for specific entry:
```
localID <paste-uuid-here>
```

### Filter for errors:
```
❌|FAILED|Error
```

### Filter for progress sync:
```
progressEntry sync event
```

---

## Future Enhancements

### 1. Auto-Retry on Network Restore
```swift
// Add NetworkMonitor
class NetworkMonitor {
    func onNetworkRestored() {
        // Retry all failed entries
    }
}
```

### 2. Background Sync Status Widget
```swift
// Show sync status in app badge or widget
"Syncing 5 entries..."
```

### 3. Bulk Sync Progress
```swift
// Show progress bar for bulk syncs
"Syncing 44/50 entries..."
```

### 4. Sync History View
```swift
// Show last 20 sync operations
"72 kg synced at 14:32"
```

---

## Related Files

- `RemoteSyncService.swift` - Core sync logic
- `VerifyRemoteSyncUseCase.swift` - Sync verification
- `SyncDebugViewModel.swift` - Debug UI
- `LocalDataChangePublisher.swift` - Event system
- `ProgressRepositoryProtocol.swift` - Data access

---

## Conclusion

**Key Takeaways:**

1. ✅ **Local is source of truth** - remote is backup
2. ✅ **Sync happens in background** - non-blocking
3. ✅ **Rate limiting prevents API overload** - 0.5s delay
4. ✅ **Console logs are your friend** - watch for ✅✅✅
5. ✅ **SyncDebugView for testing** - add to dev builds
6. ✅ **Verify consistency periodically** - local vs remote

**Most Important:**

Watch for this log pattern - it means everything is working:

```
RemoteSyncService: 📤 Processing progressEntry sync event
RemoteSyncService: 🌐 Calling /api/v1/progress API
RemoteSyncService: ✅ /api/v1/progress API call successful!
RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry
```

If you see this, your local → remote sync is working perfectly! 🎉

---

**Last Updated:** 2025-01-31  
**Status:** Ready for use in development/testing