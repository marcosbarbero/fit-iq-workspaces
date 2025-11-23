# Mood Tracking Troubleshooting Guide

**Date:** 2025-01-27  
**Version:** 1.0.0  
**Purpose:** Debug guide for mood tracking issues

---

## 🐛 Issue: Mood Entry Not Saving

### Symptoms
- No UI errors when saving
- Entry doesn't appear in API response
- Empty state in mood history view
- No errors in console

### ✅ Resolution Applied

The issue was that `MoodEntryView` was using a callback pattern instead of the actual `MoodEntryViewModel`. 

**Fixed Files:**
1. `Presentation/UI/Mood/MoodDetailView.swift` - Now calls `moodEntryViewModel.saveMoodEntry()`
2. `Presentation/UI/Summary/SummaryView.swift` - Added `moodEntryViewModel` property
3. `Infrastructure/Configuration/ViewDependencies.swift` - Passes `moodEntryViewModel` to `SummaryView`

---

## 🔍 How to Verify It's Working

### 1. Check Console Logs

When saving a mood entry, you should see these logs:

```
SaveMoodProgressUseCase: Saving mood score 8 for user <user-id> on <date>
SaveMoodProgressUseCase: No existing entry found for <date>. Creating new entry.
SaveMoodProgressUseCase: Successfully saved new mood progress with local ID: <uuid>
MoodEntryViewModel: Successfully saved mood entry with local ID: <uuid>
```

### 2. Check Local Storage (SwiftData)

The entry should be saved to SwiftData with:
- `type`: "mood_score"
- `quantity`: Your score (1-10)
- `date`: Selected date
- `notes`: Your notes (if provided)
- `syncStatus`: `.pending`

### 3. Check Backend Sync

After a few seconds, check the RemoteSyncService logs:

```
RemoteSyncService: Syncing pending progress entries...
RemoteSyncService: Successfully synced mood_score entry <local-id> -> <backend-id>
```

### 4. Verify API Response

After sync completes, query the API:

```bash
curl -X GET https://fit-iq-backend.fly.dev/api/v1/progress?type=mood_score \
  -H "X-API-Key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN"
```

Expected response:
```json
{
  "data": {
    "entries": [
      {
        "id": "backend-uuid",
        "type": "mood_score",
        "quantity": 8.0,
        "date": "2025-01-27T00:00:00Z",
        "notes": "Feeling great!",
        "created_at": "2025-01-27T10:30:00Z"
      }
    ]
  }
}
```

---

## 🔧 Debugging Steps

### Step 1: Verify ViewModels Are Connected

Check that `MoodDetailView` receives both ViewModels:

```swift
// In SummaryView
MoodDetailView(
    viewModel: moodDetailViewModel,          // ✅ Should be passed
    moodEntryViewModel: moodEntryViewModel,  // ✅ Should be passed
    onSaveSuccess: { ... }
)
```

### Step 2: Verify Save Call

Add breakpoint or log in `MoodEntryView` save callback:

```swift
onSave: { moodScore, moodNotes in
    print("🔵 MoodEntryView onSave called: score=\(moodScore), notes=\(moodNotes ?? "nil")")
    Task {
        // This should execute
        moodEntryViewModel.moodScore = moodScore
        moodEntryViewModel.notes = moodNotes ?? ""
        await moodEntryViewModel.saveMoodEntry()
    }
}
```

### Step 3: Verify Use Case Execution

Check logs from `SaveMoodProgressUseCaseImpl.execute()`:

```swift
print("SaveMoodProgressUseCase: Saving mood score \(score) for user \(userID) on \(date)")
```

If this doesn't print, the use case isn't being called.

### Step 4: Verify Repository Save

Check logs from `ProgressRepository.save()`:

```swift
print("ProgressRepository: Saving progress entry type=\(entry.type), quantity=\(entry.quantity)")
```

### Step 5: Check Sync Status

Query local SwiftData to see if entry exists:

```swift
let entries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .moodScore,
    syncStatus: nil
)
print("Local mood entries: \(entries.count)")
```

### Step 6: Check Remote Sync

Look for sync service logs:

```
RemoteSyncService: Found \(count) pending progress entries to sync
```

If count is 0, local data isn't being picked up by sync service.

---

## 🚨 Common Issues

### Issue 1: ViewModel Not Injected

**Symptom:** Crash or nil reference error

**Cause:** `moodEntryViewModel` not passed through dependency injection

**Fix:** Verify in `ViewModelAppDependencies.build()`:
```swift
let moodEntryViewModel = MoodEntryViewModel(
    saveMoodProgressUseCase: appDependencies.saveMoodProgressUseCase
)
```

### Issue 2: Use Case Not Registered

**Symptom:** Crash when calling `saveMoodProgressUseCase.execute()`

**Cause:** Use case not created in `AppDependencies.build()`

**Fix:** Verify:
```swift
let saveMoodProgressUseCase = SaveMoodProgressUseCaseImpl(
    progressRepository: progressRepository,
    authManager: authManager
)
```

### Issue 3: Wrong Metric Type

**Symptom:** Entry saves but doesn't appear in mood history

**Cause:** Saved with wrong type (e.g., "mood" instead of "mood_score")

**Fix:** Verify `ProgressMetricType.moodScore.rawValue == "mood_score"`

### Issue 4: Auth Token Missing

**Symptom:** Local save works, but remote sync fails

**Cause:** User not authenticated or token expired

**Fix:** Check `authManager.currentUserProfileID` is not nil

### Issue 5: Sync Service Not Running

**Symptom:** Entries stay in `.pending` status forever

**Cause:** RemoteSyncService not picking up changes

**Fix:** Check `LocalDataChangeMonitor` is publishing events

---

## 🧪 Test Checklist

Run through these tests to verify everything works:

- [ ] Open MoodDetailView
- [ ] Tap "Log Mood" button
- [ ] Set mood score (e.g., 8)
- [ ] Add notes (e.g., "Feeling great!")
- [ ] Tap "Log Mood" button to save
- [ ] Check console for save logs
- [ ] Verify entry appears in MoodDetailView history
- [ ] Wait 5-10 seconds for sync
- [ ] Query API to verify entry synced
- [ ] Close and reopen app
- [ ] Verify entry still appears in history
- [ ] Try saving duplicate (same date)
- [ ] Verify duplicate detection works
- [ ] Try invalid score (e.g., 11)
- [ ] Verify validation error shown
- [ ] Try notes >500 chars
- [ ] Verify validation error shown

---

## 📊 Expected Data Flow

```
User taps "Log Mood" in MoodEntryView
    ↓
onSave callback fires
    ↓
Sets moodEntryViewModel.moodScore, .notes, .selectedDate
    ↓
Calls moodEntryViewModel.saveMoodEntry()
    ↓
MoodEntryViewModel validates input
    ↓
Calls saveMoodProgressUseCase.execute()
    ↓
SaveMoodProgressUseCaseImpl validates & creates ProgressEntry
    ↓
Calls progressRepository.save()
    ↓
SwiftDataProgressRepository saves to SwiftData
    ↓
LocalDataChangeMonitor publishes change event
    ↓
RemoteSyncService picks up .pending entry
    ↓
Calls ProgressAPIClient.logProgress()
    ↓
POST /api/v1/progress with type="mood_score"
    ↓
Backend returns success with ID
    ↓
Repository updates local entry with backend ID
    ↓
Entry status changes to .synced
    ↓
MoodDetailView refreshes and shows entry
```

---

## 🔑 Key Debug Points

### 1. ViewModel Injection
```swift
// In ViewModelAppDependencies
print("🟢 Created MoodEntryViewModel")

// In MoodDetailView.init
print("🟢 MoodDetailView received moodEntryViewModel: \(moodEntryViewModel)")
```

### 2. Save Call
```swift
// In MoodEntryViewModel.saveMoodEntry()
print("🟢 Starting save: score=\(moodScore), notes=\(notes)")
```

### 3. Use Case Execution
```swift
// In SaveMoodProgressUseCaseImpl.execute()
print("🟢 SaveMoodProgressUseCase executing")
```

### 4. Repository Save
```swift
// In ProgressRepository.save()
print("🟢 Saving to SwiftData: \(progressEntry)")
```

### 5. Sync Trigger
```swift
// After repository save
print("🟢 Triggering sync for entry: \(localID)")
```

### 6. Remote Sync
```swift
// In RemoteSyncService
print("🟢 Syncing mood_score entry to backend")
```

---

## 📝 Quick Diagnostic Script

Add this to `MoodDetailViewModel.loadHistoricalData()` for debugging:

```swift
do {
    let allEntries = try await progressRepository.fetchLocal(
        forUserID: userID,
        type: .moodScore,
        syncStatus: nil
    )
    
    print("📊 Mood Entries Diagnostic:")
    print("   Total entries: \(allEntries.count)")
    print("   Date range: \(startDate) to \(endDate)")
    
    for (index, entry) in allEntries.enumerated() {
        print("   [\(index + 1)] Score: \(Int(entry.quantity)), Date: \(entry.date), Status: \(entry.syncStatus), Backend ID: \(entry.backendID ?? "nil")")
    }
    
    let filteredCount = allEntries.filter { $0.date >= startDate && $0.date <= endDate }.count
    print("   Filtered count: \(filteredCount)")
} catch {
    print("❌ Error fetching mood entries: \(error)")
}
```

---

## 🆘 Still Not Working?

If mood entries still aren't saving after these fixes, check:

1. **Xcode Console** - Look for errors or exceptions
2. **SwiftData Logs** - Check if persistence is failing
3. **Network Logs** - Verify API calls are being made
4. **Auth Status** - Ensure user is logged in
5. **Backend Logs** - Check if API is receiving requests

### Get More Help

1. Check `MOOD_TRACKING_IMPLEMENTATION.md` for architecture details
2. Review `SaveBodyMassUseCase.swift` for working reference
3. Compare with weight tracking (which works) to find differences
4. Add more detailed logging at each step of the flow

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ Console shows save logs
2. ✅ MoodDetailView shows entry immediately
3. ✅ API returns entry after sync
4. ✅ Entry persists after app restart
5. ✅ Historical chart updates
6. ✅ Statistics calculate correctly
7. ✅ No duplicate entries created
8. ✅ Validation errors display properly

---

**Last Updated:** 2025-01-27  
**Status:** ✅ Fixed - Connect MoodEntryViewModel to MoodEntryView callback