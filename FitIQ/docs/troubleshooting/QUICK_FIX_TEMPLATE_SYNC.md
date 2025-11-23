# Quick Fix: Workout Template Sync Errors

**Error:** `APIError error 4` when fetching template exercises  
**Context:** Sync fails at Step 2 (fetching individual templates)

---

## 🚀 Quick Diagnosis (30 seconds)

Run sync and check console logs for:

```
WorkoutTemplateAPIClient: Received response with status code: <NUMBER>
```

### Status Code = 401 (Unauthorized)
**Problem:** Token expired  
**Fix:** Logout and login again

```swift
// In app: Settings → Logout → Login
```

---

### Status Code = 404 (Not Found)
**Problem:** Template ID doesn't exist  
**Fix:** Backend data inconsistency - contact backend team

---

### Status Code = 500 (Server Error)
**Problem:** Backend crash  
**Fix:** Check backend status, retry later, or contact backend team

---

### Status Code = 200 (Success) but still errors
**Problem:** Decoding error - response doesn't match expected format  
**Fix:** Check response preview in logs:

```
WorkoutTemplateAPIClient: Response data preview: <JSON>
```

Compare with `WorkoutTemplateDTOs.swift` to find mismatch.

---

### No status code logged
**Problem:** Network error (timeout, no connection)  
**Fix:** 
1. Check internet connection
2. Try on different network
3. Check if backend is reachable

---

## 🔧 Universal Fixes (Try These First)

### 1. Logout/Login
```
Settings → Logout → Login with credentials
```
Fixes 90% of auth-related issues.

---

### 2. Clear Local Data
```
Settings → Advanced → Delete All Data → Logout
```
Then login and sync again. Fixes stale data issues.

---

### 3. Check Backend Status
Visit: https://fit-iq-backend.fly.dev/health

Expected response:
```json
{
  "status": "healthy"
}
```

---

## 🐛 Advanced Debugging

### Get Raw Error Details

Look for these log lines:

```
WorkoutTemplateAPIClient: ❌ APIError fetching template <UUID>: <ERROR>
WorkoutTemplateAPIClient: Error type: <TYPE>
WorkoutTemplateAPIClient: Error details: <DETAILS>
```

### Check Auth Token

Look for:
```
WorkoutTemplateAPIClient: ❌ No auth token available
```
→ User needs to login

```
WorkoutTemplateAPIClient: 🔄 Refreshing auth token...
```
→ Token refresh in progress (good)

```
WorkoutTemplateAPIClient: ❌ Token refresh failed
```
→ User needs to login again

---

## 📞 When to Contact Support

1. **Status code 500** - Backend issue
2. **Status code 404** - Data inconsistency
3. **Decoding errors with correct status 200** - API schema mismatch
4. **Token refresh fails repeatedly** - Auth service issue
5. **All templates fail consistently** - Systemic problem

---

## 🎯 Expected Success Pattern

```
SyncWorkoutTemplatesUseCase: [1/840] Fetching exercises for 'Full Body Blast'
WorkoutTemplateAPIClient: Received response with status code: 200
WorkoutTemplateAPIClient: ✅ Fetched template 'Full Body Blast' with 12 exercises

SyncWorkoutTemplatesUseCase: [2/840] Fetching exercises for 'Upper Body Focus'
WorkoutTemplateAPIClient: Received response with status code: 200
WorkoutTemplateAPIClient: ✅ Fetched template 'Upper Body Focus' with 8 exercises

...

SyncWorkoutTemplatesUseCase: ✅ Successfully synced 840 templates
```

---

## 🔍 Still Stuck?

Read full troubleshooting guide:
`docs/troubleshooting/workout-template-sync-errors.md`
