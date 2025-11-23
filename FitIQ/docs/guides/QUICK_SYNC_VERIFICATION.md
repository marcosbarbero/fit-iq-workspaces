# Quick Sync Verification Guide

**TL;DR:** How to verify local → remote sync is working

---

## 🚀 Quick Check (30 seconds)

1. **Log a weight entry** (e.g., 72 kg)
2. **Watch Xcode console** for:
   ```
   RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry
   ```
3. **Within 2 seconds**, you should see ✅ = sync working!

---

## 📋 Console Logs to Watch

### ✅ Good (Sync Working)
```
RemoteSyncService: 📤 Processing progressEntry sync event for localID <UUID>
RemoteSyncService: Found progress entry to sync:
  - Type: weight
  - Quantity: 72.0
  - Current sync status: pending
RemoteSyncService: Updated sync status to 'syncing'
RemoteSyncService: 🌐 Calling /api/v1/progress API to upload progress entry...
RemoteSyncService: ✅ /api/v1/progress API call successful!
  - Backend ID: c7fabe81-8e68-4742-9fb1-700ae5018e9e
RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry <UUID>
```

### ❌ Bad (Sync Failing)
```
RemoteSyncService: ❌ /api/v1/progress API call FAILED!
  - Error: ...
RemoteSyncService: Marked ProgressEntry as 'failed' for retry
```

---

## 🔍 Verify via API

**Get your auth token from console:**
```
ProgressAPIClient: Using access token: eyJhbGci...
```

**Query remote API:**
```bash
curl -X GET 'https://fit-iq-backend.fly.dev/api/v1/progress?type=weight&limit=10' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'X-API-Key: YOUR_API_KEY' | jq
```

**Check:**
- Recent entries appear in response
- `id` matches local `backendID`
- `quantity` and `date` match

---

## 🐛 Debug Use Case (Recommended)

**Add to your project:**

1. Copy `VerifyRemoteSyncUseCase.swift` to your Domain/UseCases/Debug/
2. Copy `SyncDebugViewModel.swift` to Presentation/ViewModels/Debug/
3. Add to AppDependencies:

```swift
// In AppDependencies.swift
lazy var verifySyncUseCase: VerifyRemoteSyncUseCase = VerifyRemoteSyncUseCaseImpl(
    progressRepository: progressRepository,
    authManager: authManager,
    localDataChangePublisher: localDataChangePublisher
)
```

4. Create debug view in your settings:

```swift
NavigationLink("🔧 Sync Debug") {
    SyncDebugView(verifySyncUseCase: dependencies.verifySyncUseCase)
}
```

**Use it to:**
- ✅ Check pending entry count
- ✅ Manually trigger sync
- ✅ Verify local vs remote consistency
- ✅ Monitor sync health

---

## 📊 What to Check

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Pending Entries | 0-5 | 5-20 | >20 |
| Failed Entries | 0 | 1-5 | >5 |
| Sync % | >95% | 90-95% | <90% |
| Consistency | >95% | 90-95% | <90% |
| Sync Time | <2s | 2-5s | >5s |

---

## 🔧 Common Issues

### Issue: Entries stuck in "pending"
**Check:**
- RemoteSyncService started? (look for startup log)
- Network connectivity? (try curl command)
- Auth token valid? (check for 401 errors)

**Fix:**
- Manually trigger sync via debug view
- Or restart app

### Issue: Entries marked as "failed"
**Check console for:**
- 400 = Validation error (check data format)
- 401 = Auth issue (token expired)
- 409 = Duplicate (not an issue, skip)
- 500 = Backend error (retry later)

**Fix:**
- Reset failed entries to pending
- Trigger manual sync

### Issue: Local vs remote inconsistent
**Check:**
- How many entries are synced vs total?
- Any failed entries blocking queue?

**Fix:**
- Run consistency check in debug view
- Trigger manual sync for pending
- Check backend logs if still inconsistent

---

## ⏱️ Expected Timeline

**Normal flow:**
```
0.0s: User logs weight → Local saved (pending)
0.5s: Sync event picked up (rate limiting)
1.5s: API call complete → Backend ID received
2.0s: Local updated (synced)
```

**Bulk sync (e.g., 50 entries):**
```
0s: 50 entries pending
0-25s: Sync with rate limiting (0.5s per entry)
25s: All synced
```

---

## 🎯 Quick Verification Script

Add this to your test suite or run in lldb:

```swift
// In your test or debug code
func verifySyncWorking() async throws {
    // 1. Create test entry
    let testWeight = 72.0
    let testDate = Date()
    
    _ = try await saveWeightProgressUseCase.execute(
        weight: testWeight,
        date: testDate
    )
    
    // 2. Wait for sync
    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
    
    // 3. Check sync status
    let status = try await verifySyncUseCase.getSyncStatus()
    
    // 4. Verify
    assert(status.pendingCount == 0, "❌ Entries still pending")
    assert(status.failedCount == 0, "❌ Sync failed")
    print("✅ Sync verification passed!")
}
```

---

## 📱 Monitor in Production

**Key things to log/alert:**

1. **High pending count** (>20 entries)
   - Indicates sync backlog
   - Check network/API health

2. **High failure rate** (>5%)
   - Indicates systemic issue
   - Check backend logs

3. **Slow sync times** (>5s per entry)
   - Check API latency
   - May need to adjust rate limiting

4. **Low consistency** (<90%)
   - Data loss risk
   - Investigate immediately

---

## 🎓 Remember

1. **Local is source of truth** → Remote is backup
2. **Sync is asynchronous** → Don't block UI
3. **Rate limiting is good** → Prevents API overload
4. **Failed entries retry** → Via manual trigger (for now)
5. **Console logs = best friend** → Watch for ✅✅✅

---

## 📚 Full Documentation

For detailed info, see:
- `LOCAL_SYNC_VERIFICATION_GUIDE.md` - Comprehensive guide
- `PERFORMANCE_FIX_LOCAL_FIRST.md` - Architecture details
- `VerifyRemoteSyncUseCase.swift` - Debug use case code
- `RemoteSyncService.swift` - Core sync logic

---

**Last Updated:** 2025-01-31  
**Status:** ✅ Ready to use