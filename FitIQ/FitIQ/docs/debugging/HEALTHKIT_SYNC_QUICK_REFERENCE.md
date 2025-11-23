# HealthKit Sync Quick Reference Cheat Sheet

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Fast lookup for debugging HealthKit sync issues

---

## 🎯 Quick Lookup: Where's My Data?

| Symptom | Most Likely Entry Point | Check |
|---------|------------------------|-------|
| No data after login | #1 Initial Sync | `hasPerformedInitialHealthKitSync` flag |
| Data not updating | #3 Background Observations | Observer queries active? |
| Stale data (old values) | #2 Manual Refresh | Try pull-to-refresh |
| Missing yesterday's data | #5 Daily Consolidation | Check consolidation task ran |
| Background sync broken | #4 Background Tasks | Background refresh enabled? |
| Weight not saving | #6 Manual Weight Entry | HealthKit write permissions? |
| Completely broken | #7 Force Resync | Nuclear option: full resync |

---

## 📱 Entry Points At-a-Glance

```
1. Initial Sync          → RootTabView.onAppear
2. Manual Refresh        → SummaryView (pull-to-refresh)
3. Background Obs.       → HealthKit observer fires automatically
4. Background Task       → iOS scheduler (~15-30 min)
5. Daily Consolidation   → iOS scheduler (midnight)
6. Manual Weight Entry   → BodyMassEntryView.save
7. Force Resync          → Profile/Settings (user-triggered)
```

---

## 🔍 Console Log Search Patterns

### ✅ Success Indicators
```
"✅ HealthKit sync completed successfully"
"Historical sync completed successfully (90 days)"
"BGTask: HealthKit sync task completed comprehensive daily sync"
"Consolidated daily health data finalization for [date] complete"
```

### ⚠️ Warning Signs
```
"⚠️ HealthKit sync failed:"
"Database busy"
"User profile not found"
"HealthKit authorization denied"
```

### 🐛 Critical Errors
```
"BGTask: expiration handler called"
"Initial sync not yet completed"
"No user profile ID"
"Cannot determine initial sync status"
```

---

## 🎯 Core Components

| Component | Location | Role |
|-----------|----------|------|
| **HealthDataSyncManager** | `Infrastructure/Services/` | Central sync orchestrator |
| **HealthKitAdapter** | `Infrastructure/Repositories/` | HealthKit interface |
| **BackgroundSyncManager** | `Domain/UseCases/` | Background task handler |
| **PerformInitialHealthKitSyncUseCase** | `Infrastructure/Integration/` | Initial sync logic |
| **ProcessDailyHealthDataUseCase** | `Domain/UseCases/` | Daily sync trigger |

---

## 🔧 Key Methods in HealthDataSyncManager

```swift
// Sync today's data only (fast)
.syncAllDailyActivityData()

// Sync date range (historical)
.syncHistoricalHealthData(from:to:)

// Finalize previous day
.finalizeDailyActivityData(for:)

// Set user context (REQUIRED before sync)
.configure(withUserProfileID:)
```

---

## ⏱️ Performance Quick Reference

| Operation | Time | Notes |
|-----------|------|-------|
| First-time sync | 30-45s | 90 days historical |
| Daily refresh | 1-3s | Today only |
| Manual refresh | 1-3s | Today only |
| Background obs. | 1-2s | Single metric |
| Weight entry | <1s | Immediate |

---

## 🐛 Debugging Checklist

### Initial Sync Issues
- [ ] HealthKit permissions granted?
- [ ] `hasPerformedInitialHealthKitSync` = true?
- [ ] User ID configured correctly?
- [ ] Console shows "Historical sync completed"?

### Data Not Updating
- [ ] Observer queries active?
- [ ] `onDataUpdate` closure firing?
- [ ] App in foreground (for immediate sync)?
- [ ] Background refresh enabled in iOS Settings?

### Background Tasks Not Running
- [ ] BGTaskScheduler identifiers in `Info.plist`?
- [ ] Background refresh capability enabled?
- [ ] Tasks registered in `FitIQApp.swift`?
- [ ] Pending types being queued?

### Weight Not Saving
- [ ] HealthKit write permission granted?
- [ ] HealthKitAdapter.saveQuantitySample succeeds?
- [ ] Observer triggered after save?
- [ ] Data appears in Health app?

---

## 🧪 Debug Commands

### Test Background Task
```bash
# In Xcode debug console (lldb):
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.fitiq.healthkit.sync"]
```

### Check User Profile
```swift
// In ViewModelBase or ViewModel:
print("User ID: \(authManager.currentUserProfileID)")
print("Has synced: \(userProfile.hasPerformedInitialHealthKitSync)")
```

### Force Immediate Sync
```swift
// In Xcode debug console:
po await deps.processDailyHealthDataUseCase.execute()
```

---

## 📊 Data Flow Quick Map

```
HealthKit → HealthKitAdapter → HealthDataSyncManager → Repositories → SwiftData → UI

Sync Trigger → Use Case → Sync Manager → Adapter → HealthKit API
```

---

## 🚨 Common Gotchas

### 1. User ID Not Configured
**Symptom:** Sync completes but no data appears  
**Fix:** Ensure `HealthDataSyncManager.configure(withUserProfileID:)` called first  
**Check:** Console log "Configured HealthDataSyncManager with user ID"

### 2. Initial Sync Flag Not Set
**Symptom:** Repeated full syncs on every app open  
**Fix:** Verify `hasPerformedInitialHealthKitSync` set to true after first sync  
**Check:** User profile in SwiftData

### 3. Background Refresh Disabled
**Symptom:** No automatic updates  
**Fix:** Settings → General → Background App Refresh → On  
**Check:** iOS Settings, not app setting

### 4. Database Busy Warnings
**Symptom:** "Database busy" in console  
**Fix:** Use shared ModelContext (fixed in current version)  
**Check:** Ensure all repos use same context

### 5. Observer Queries Not Active
**Symptom:** No automatic updates when HealthKit changes  
**Fix:** Check observer setup in `HealthKitAdapter`  
**Check:** Console log "Starting observer query for"

### 6. Today Marked As Synced (Old Bug)
**Symptom:** Heart rate/steps stuck at 4 AM value  
**Fix:** Ensure sync logic NEVER marks "today" as fully synced  
**Check:** Current code handles this correctly (fixed)

---

## 🎯 First Steps for Any Sync Issue

1. **Check Console Logs**
   - Look for success/error messages
   - Identify which entry point is involved
   - Note timestamps of sync attempts

2. **Verify Initial Sync**
   ```swift
   print("Has synced: \(userProfile.hasPerformedInitialHealthKitSync)")
   ```

3. **Check HealthKit Permissions**
   - Settings → Privacy & Security → Health → FitIQ
   - Verify read/write permissions for all types

4. **Try Manual Refresh**
   - Pull down on SummaryView
   - Watch console for sync messages
   - Check if UI updates

5. **Verify Data Source**
   - Open Health app
   - Check if data exists for today
   - If no data in Health, can't show in FitIQ

6. **Last Resort: Force Resync**
   - Profile → Developer Options → Force Resync
   - Or delete/reinstall app

---

## 📞 When to Check Each Entry Point

| Time/Trigger | Entry Point | Expected Behavior |
|--------------|-------------|-------------------|
| After login | #1 Initial Sync | 90-day historical sync |
| User pulls down | #2 Manual Refresh | Immediate today sync |
| New HR reading | #3 Background Obs. | Auto-sync in foreground |
| Every ~15-30 min | #4 Background Task | Background sync |
| Around midnight | #5 Daily Consolidation | Finalize yesterday |
| User logs weight | #6 Manual Weight Entry | Instant save + sync |
| Debugging | #7 Force Resync | Full re-sync |

---

## 🔗 Related Documentation

- **Full Guide:** `HEALTHKIT_SYNC_ENTRY_POINTS.md`
- **Flow Diagrams:** `HEALTHKIT_SYNC_FLOW_DIAGRAM.md`
- **Architecture:** `../../.github/copilot-instructions.md`

---

## 💡 Pro Tips

1. **Always check console logs first** - 90% of issues are visible there
2. **Verify data in Health app** - If not there, FitIQ can't show it
3. **Use pull-to-refresh often** - Forces immediate sync for debugging
4. **Test background tasks manually** - Don't wait for iOS scheduler
5. **Check user ID everywhere** - Most sync issues are configuration bugs
6. **Monitor timestamps** - Helps identify which entry point triggered
7. **Force resync is safe** - It's designed for recovery scenarios

---

**Quick Help:**  
- No data? → Check Entry Point #1
- Stale data? → Check Entry Point #3
- Background broken? → Check Entry Point #4
- Still stuck? → Entry Point #7 (Force Resync)

---

**Status:** ✅ Ready for debugging  
**Print this page** and keep it handy! 📄