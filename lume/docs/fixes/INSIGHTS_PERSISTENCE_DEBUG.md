# AI Insights Persistence Debugging Guide

**Date:** 2025-01-28  
**Version:** 1.0.0  
**Status:** 🔍 Debugging in Progress

---

## Issue Report

**Problem:** Insights are not being stored locally in SwiftData. Backend API calls are made every time the dashboard loads, indicating that insights are not persisting between sessions.

**Symptoms:**
- Backend `/insights/generate` API called on every dashboard load
- Insights disappear when navigating away and returning
- No cached insights found in local storage
- Performance degradation due to repeated API calls

---

## Debugging Steps Implemented

### Step 1: Fixed Task Block Running on Every Appearance

**Problem:** The `.task` modifier runs every time the view appears in the navigation stack.

**Fix Applied:**
```swift
@State private var hasLoadedInitially = false

.task {
    // Only load on first appearance
    if !hasLoadedInitially {
        print("📊 [Dashboard] Initial load")
        await viewModel.loadStatistics()
        await loadInsightsWithAutoGenerate()
        hasLoadedInitially = true
    } else {
        print("📊 [Dashboard] Returning to view - using cached data")
    }
}
```

**Impact:** Prevents redundant loads when returning to dashboard from other tabs.

---

### Step 2: Changed Load Strategy to Cache-First

**Problem:** `loadInsights()` was calling backend every time.

**Fix Applied:**
```swift
// In AIInsightsViewModel.loadInsights()
insights = try await fetchInsightsUseCase.execute(
    type: filterType,
    unreadOnly: showUnreadOnly,
    favoritesOnly: showFavoritesOnly,
    archivedStatus: showArchived ? true : nil,
    syncFromBackend: false  // ✅ Cache-first
)
```

**Impact:** Only loads from local SwiftData, never calls backend during normal load.

---

### Step 3: Added Comprehensive Logging

**Locations:**
1. **AIInsightsViewModel**
   - `loadInsights()` - Logs cache loads
   - `refreshFromBackend()` - Logs explicit syncs
   - `generateNewInsights()` - Logs generation

2. **GenerateInsightUseCase**
   - Start of generation
   - Type-specific generation
   - Save operations
   - Success/failure

3. **AIInsightRepository**
   - `fetchAll()` - Number of insights found
   - `save()` - Insert vs update
   - SwiftData operations

**Log Format:**
```
📊 [Dashboard] Initial load
📱 [AIInsightsViewModel] Loading insights from local cache
📥 [AIInsightRepository] Fetching all insights for user: <UUID>
   Found 0 insights in SwiftData
   ✅ Loaded 0 insight(s) from cache
📊 [Dashboard] No insights found and generation available - auto-generating
🤖 [GenerateInsightUseCase] Generating 1 insight(s)
   📝 Generating daily insight...
💾 [AIInsightRepository] Saving insight: <UUID>
   Type: daily, Title: Understanding Your Mood Patterns
   ✨ Creating new insight
   🔄 Converting domain insight to SwiftData
   ✅ Insight saved to SwiftData
```

---

## What to Check in Logs

### ✅ Expected Flow (Working Correctly)

**First Load:**
```
📊 [Dashboard] Initial load
📱 [AIInsightsViewModel] Loading insights from local cache
📥 [AIInsightRepository] Fetching all insights for user: <UUID>
   Found 0 insights in SwiftData
📊 [Dashboard] No insights found - auto-generating
🤖 [GenerateInsightUseCase] Generating 1 insight(s)
💾 [AIInsightRepository] Saving insight: <UUID>
   ✅ Insight saved to SwiftData
```

**Second Load (Next Day):**
```
📊 [Dashboard] Initial load
📱 [AIInsightsViewModel] Loading insights from local cache
📥 [AIInsightRepository] Fetching all insights for user: <UUID>
   Found 1 insights in SwiftData
   ✅ Loaded 1 insight(s) from cache
📊 [Dashboard] Found 1 existing insights - skipping auto-generation
```

**Navigation Return:**
```
📊 [Dashboard] Returning to view - using cached data
```

### ❌ Problem Indicators

**Insights Not Persisting:**
```
📥 [AIInsightRepository] Fetching all insights
   Found 0 insights in SwiftData  ← Always 0!
```

**Repeated Generation:**
```
🤖 [GenerateInsightUseCase] Generating 1 insight(s)
💾 [AIInsightRepository] Saving insight
   ✅ Insight saved to SwiftData

// Next load
📥 [AIInsightRepository] Fetching all insights
   Found 0 insights in SwiftData  ← Still 0! Not persisting!
```

**Backend Calls on Every Load:**
```
=== HTTP Request ===
URL: https://fit-iq-backend.fly.dev/api/v1/insights/generate
Method: POST
Status: 201  ← Should only see this once per day!
```

---

## Root Cause Analysis

### Hypothesis 1: ModelContext Not Persisting

**Symptom:** Insights saved but not found on next fetch.

**Possible Causes:**
- ModelContext not shared across views
- ModelContext not using persistent storage
- Container configuration issue

**Check:**
```swift
// In App initialization
@main
struct LumeApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: SDAIInsight.self,  // ✅ Check model is registered
                // ... other models
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
```

**Verification:**
- Ensure `SDAIInsight` is in the ModelContainer schema
- Verify SwiftData file location: `~/Library/Application Support/<app>/default.store`
- Check file permissions

---

### Hypothesis 2: User ID Mismatch

**Symptom:** Insights saved with one userId, fetched with another.

**Check Logs:**
```
💾 [AIInsightRepository] Saving insight
   User ID: <UUID-1>  ← Save with this ID

📥 [AIInsightRepository] Fetching all insights for user: <UUID-2>
   ← Fetch with different ID!
```

**Fix:**
Ensure `getCurrentUserId()` returns consistent value:
```swift
private func getCurrentUserId() async throws -> UUID {
    // Must return same UUID across calls
    let token = try await tokenStorage.getToken()
    // Extract userId from token or user profile
}
```

---

### Hypothesis 3: Schema Migration Issue

**Symptom:** Old data incompatible with new schema.

**Check:**
- Recent schema changes to `SDAIInsight`
- Migration not applied
- Data corruption

**Fix:**
```swift
// Force fresh start (for debugging only!)
try? modelContainer.mainContext.delete(model: SDAIInsight.self)
try? modelContainer.mainContext.save()
```

---

### Hypothesis 4: Concurrent Context Issues

**Symptom:** ModelContext operations on wrong thread.

**Check:**
- All SwiftData operations on `@MainActor`
- No background thread access
- Proper async/await usage

**Current Implementation:**
```swift
// Repository init receives ModelContext from dependency injection
init(modelContext: ModelContext, ...) {
    self.modelContext = modelContext
}

// All operations use this shared context
func save(_ insight: AIInsight) async throws -> AIInsight {
    // Operations on shared modelContext
    try modelContext.save()
}
```

**Potential Issue:** If multiple repositories share the same context, concurrent saves might conflict.

---

## Testing Checklist

### Manual Testing

1. **Fresh Install Test**
   - [ ] Delete app
   - [ ] Reinstall
   - [ ] Log in
   - [ ] Generate insights
   - [ ] Check logs for save confirmation
   - [ ] Kill app
   - [ ] Reopen app
   - [ ] Check logs for cached insights

2. **Navigation Test**
   - [ ] Load dashboard (insights generated)
   - [ ] Navigate to Mood tab
   - [ ] Return to dashboard
   - [ ] Verify no new API calls
   - [ ] Verify insights still visible

3. **App Background Test**
   - [ ] Load dashboard (insights visible)
   - [ ] Background app (Home button)
   - [ ] Wait 30 seconds
   - [ ] Resume app
   - [ ] Verify insights still visible

4. **Logout/Login Test**
   - [ ] Load dashboard (insights generated)
   - [ ] Logout
   - [ ] Login with same account
   - [ ] Verify insights restored

---

## Debugging Commands

### Xcode Console Filters

**Show Only Insights Logs:**
```
Dashboard|AIInsightsViewModel|AIInsightRepository|GenerateInsightUseCase
```

**Show HTTP Requests:**
```
=== HTTP Request ===
```

**Show SwiftData Operations:**
```
AIInsightRepository.*SwiftData
```

### Breakpoints

Set breakpoints at:
1. `AIInsightRepository.save()` - Line after `modelContext.save()`
2. `AIInsightRepository.fetchAll()` - Line after `modelContext.fetch()`
3. `GenerateInsightUseCase.execute()` - Line calling `repository.save()`

---

## Quick Fix Attempts

### Attempt 1: Force Persistence
```swift
// In AIInsightRepository.save()
try modelContext.save()
try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
// Verify saved
let verification = try modelContext.fetch(descriptor)
print("   Verification: \(verification.count) insights in DB")
```

### Attempt 2: Use Main Actor Context
```swift
@MainActor
func save(_ insight: AIInsight) async throws -> AIInsight {
    // Ensure all operations on main thread
}
```

### Attempt 3: Explicit Container Persistence
```swift
try modelContext.save()
try modelContainer.mainContext.save() // Double save
```

---

## Expected Resolution

Once working, logs should show:

**Day 1 - First Load:**
```
📊 [Dashboard] Initial load
📱 Loading insights from cache
📥 Fetching all insights for user
   Found 0 insights in SwiftData
📊 No insights found - auto-generating
🤖 Generating 1 insight(s)
💾 Saving insight: <UUID>
   ✨ Creating new insight
   ✅ Insight saved to SwiftData
```

**Day 1 - Navigation Return:**
```
📊 [Dashboard] Returning to view - using cached data
(No fetch, no API call)
```

**Day 2 - App Restart:**
```
📊 [Dashboard] Initial load
📱 Loading insights from cache
📥 Fetching all insights for user
   Found 1 insights in SwiftData  ← ✅ Persisted!
   ✅ Loaded 1 insight(s) from cache
📊 Found 1 existing insights - skipping auto-generation
(No API call)
```

---

## Files Modified

1. `DashboardView.swift`
   - Added `hasLoadedInitially` flag
   - Task block runs once only

2. `AIInsightsViewModel.swift`
   - Cache-first loading
   - Comprehensive logging

3. `AIInsightRepository.swift`
   - Detailed save/fetch logging
   - Verification steps

4. `GenerateInsightUseCase.swift`
   - Type-specific generation logging
   - Save confirmation

---

## Next Steps

1. **Run app with new logging**
2. **Monitor console for persistence verification**
3. **Check specific hypothesis based on logs**
4. **Test navigation and app restart scenarios**
5. **Verify SwiftData file exists and grows**

---

## Success Criteria

- ✅ Insights generated once per day (not every load)
- ✅ Insights visible after navigation
- ✅ Insights survive app restart
- ✅ No backend calls on dashboard return
- ✅ Logs show "Found X insights in SwiftData" where X > 0

---

## Related Documentation

- `docs/architecture/HEXAGONAL_ARCHITECTURE.md` - Repository pattern
- `docs/backend-integration/AI_INSIGHTS_API_IMPLEMENTATION.md` - API contract
- SwiftData documentation - Apple Developer

---

**Status:** 🔍 Waiting for log analysis to identify root cause