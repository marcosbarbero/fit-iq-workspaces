# Mood API Update - Quick Start Guide

**Date:** 2025-01-15  
**Status:** Ready to Test  
**Time to Complete:** 5 minutes

---

## TL;DR

The mood tracking backend API changed. The iOS app now transforms requests automatically. **No UI changes. No domain changes. Just service layer updates.**

---

## What Changed

### Endpoints
- ❌ ~~`POST /api/v1/moods`~~
- ✅ `POST /api/v1/wellness/mood-entries`

### Request Format
```json
// OLD (removed)
{ "id": "...", "user_id": "...", "mood": "happy", "note": "...", ... }

// NEW (automatic)
{ "mood_score": 8, "emotions": ["happy"], "notes": "...", "logged_at": "..." }
```

### What You Need to Know
- App's `MoodKind` enum automatically transforms to `mood_score` (1-10) + `emotions` array
- Backend now generates IDs and timestamps (proper REST design)
- Everything else works exactly the same

---

## Test It (3 Steps)

### 1. Run Unit Tests
```bash
# In Xcode
cmd + u

# Expected: All 15 tests pass ✅
```

### 2. Test Locally
```swift
// In LumeApp.swift
AppMode.current = .local  // No backend calls

// Create a mood entry in the app
// ✅ Should save locally
// ✅ Should NOT create outbox events
```

### 3. Test with Backend (When Available)
```swift
// In LumeApp.swift
AppMode.current = .production

// Create a mood entry
// ✅ Saves locally
// ✅ Creates outbox event
// ✅ POSTs to /api/v1/wellness/mood-entries
// ✅ Event completes successfully
```

---

## Expected Logs

### Successful Sync
```
✅ [MoodRepository] Saved mood locally: Happy
📦 [MoodRepository] Created outbox event 'mood.created'
✅ [MoodBackendService] Successfully synced mood entry: <uuid>
✅ [OutboxProcessor] Event completed: <uuid>
```

### 404 Error (Backend Not Ready)
```
❌ [OutboxProcessor] Failed to process event: 404 Not Found
🔄 [OutboxProcessor] Will retry event: <uuid>
```

**Solution:** Set `AppMode.current = .local` until backend endpoint is deployed.

---

## Transformation Quick Reference

| MoodKind | mood_score | emotions |
|----------|-----------|----------|
| anxious | 2 | ["anxious"] |
| stressed | 2 | ["stressed", "overwhelmed"] |
| sad | 2 | ["sad"] |
| tired | 4 | ["tired"] |
| calm | 6 | ["calm", "relaxed"] |
| peaceful | 6 | ["peaceful", "calm"] |
| content | 7 | ["content"] |
| happy | 8 | ["happy"] |
| energetic | 9 | ["energetic", "motivated"] |
| excited | 9 | ["excited", "happy"] |

---

## Files Changed

**Production:**
- `lume/Services/Backend/MoodBackendService.swift` - Added transformation

**Tests:**
- `lumeTests/MoodBackendServiceTests.swift` - 15 unit tests

**Docs:**
- `docs/mood-tracking/API_UPDATE_GUIDE.md` - Full implementation guide
- `docs/mood-tracking/API_UPDATE_CHANGELOG.md` - Detailed changelog
- `docs/mood-tracking/README.md` - Documentation index

---

## Common Issues

### Issue: Tests fail to compile
**Solution:** Make sure you're in the `lume` workspace, not individual projects.

### Issue: 404 Not Found when syncing
**Cause:** Backend endpoint not deployed yet  
**Solution:** Use `AppMode.local` or `.mockBackend` until backend is ready

### Issue: Outbox events stuck
**Solution:** Check token is valid, verify backend endpoint exists

---

## Need More Details?

- **Implementation Guide:** [API_UPDATE_GUIDE.md](API_UPDATE_GUIDE.md)
- **Changelog:** [API_UPDATE_CHANGELOG.md](API_UPDATE_CHANGELOG.md)
- **Full Summary:** [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

---

## Deployment Checklist

**Before Deploy:**
- [ ] All unit tests pass
- [ ] Manual testing complete
- [ ] Backend endpoint `/api/v1/wellness/mood-entries` is live
- [ ] Code reviewed and approved

**After Deploy:**
- [ ] Monitor logs for successful syncs
- [ ] Verify no 404 errors
- [ ] Check outbox clears properly

---

**That's it! The update is clean, tested, and ready.** ✅

**Questions?** See the full documentation in `docs/mood-tracking/`
