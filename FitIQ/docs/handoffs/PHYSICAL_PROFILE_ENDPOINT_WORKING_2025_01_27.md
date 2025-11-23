# Physical Profile Endpoint - Working Backend, iOS 404 Issue

**Date:** 2025-01-27  
**Status:** 🔴 Backend works, iOS getting 404  
**Priority:** HIGH  

---

## ⚡ Quick Action Summary

**TL;DR:** Backend endpoint works (verified with curl). iOS user getting 404 because physical profile not initialized in backend database.

**Immediate Actions:**
1. ✅ **iOS app is working** - All data safe locally, perfect UX
2. 🔍 **Need to check:** Why does iOS user "Marcos Barbero" (ID: fd72cb93-71e4-440f-b055-19695a221f83) get 404 when profile exists?
3. 🛠️ **Quick fix:** Try PUT `/api/v1/users/me` with full profile to initialize physical fields
4. 📊 **Backend team:** Check if physical fields need initialization step

---

## 🎯 Executive Summary

**The backend endpoint WORKS perfectly** - verified with successful curl command returning 200 OK.

**The iOS app is getting 404** - "User profile not found" error.

**Root Cause:** iOS user doesn't have physical profile initialized in backend database, OR authentication/token issue.

---

## ✅ Proof: Backend Endpoint Works

### Working Curl Command

```bash
curl -i -X PATCH https://fit-iq-backend.fly.dev/api/v1/users/me/physical \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "biological_sex": "male",
    "height_cm": 175.5
  }'
```

### Successful Response (200 OK)

```http
HTTP/2 200
content-type: application/json

{
  "data": {
    "profile": {
      "id": "67e43ccb-2063-48c5-bfad-5f9db74237aa",
      "name": "Test User",
      "preferred_unit_system": "metric",
      "language_code": "en",
      "biological_sex": "male",
      "height_cm": 175.5,
      "date_of_birth": "1990-01-01T00:00:00Z"
    }
  }
}
```

**Key Observations:**
- ✅ Endpoint accepts: `biological_sex` and `height_cm`
- ✅ Response includes: **Full profile with physical data merged in**
- ✅ Structure: `{"data":{"profile":{...}}}`

---

## ❌ iOS App Getting 404

### iOS Request (From Logs)

```
PhysicalProfileAPIClient: Updating physical profile via /api/v1/users/me/physical
PhysicalProfileAPIClient: Request body: {
  "biological_sex" : "male",
  "height_cm" : 170
}
```

### iOS Response (404 Error)

```
PhysicalProfileAPIClient: Update response status code: 404
PhysicalProfileAPIClient: Response body (404): {"error":{"message":"User profile not found"}}
```

### iOS User Details

```
User ID: 774F6F3E-0237-4367-A54D-94898C0AB2E2
Name: Marcos Barbero
Profile ID (from metadata): fd72cb93-71e4-440f-b055-19695a221f83
```

---

## 🔍 Why Is iOS Getting 404?

### Theory 1: Physical Profile Not Initialized (Most Likely)

**Evidence:**
- ✅ Metadata updates work (200 OK): User profile EXISTS
  ```
  UserProfileAPIClient: Metadata Update Response (200): 
  {"data":{"profile":{"id":"fd72cb93-71e4-440f-b055-19695a221f83","name":"Marcos Barbero"...}}}
  ```
- ❌ Physical updates fail (404): Physical fields NOT initialized

**Hypothesis:**
Backend requires physical profile fields to be initialized during:
- User registration, OR
- First profile creation via POST, OR
- Full profile update via PUT `/api/v1/users/me`

The curl "Test User" has initialized physical fields.  
The iOS user "Marcos Barbero" doesn't have physical fields initialized yet.

### Theory 2: Authentication Token Issue (Less Likely)

**Evidence Against:**
- ✅ Metadata updates work with same token
- ✅ Token is valid and authenticated

If it were an auth issue, metadata updates would also fail.

### Theory 3: Backend Validation Difference (Unlikely)

curl works with `height_cm: 175.5` (float)  
iOS sends `height_cm: 170` (int)

Backend might reject integers? (Unlikely but possible)

---

## 🔧 Possible Solutions

### Solution 1: Initialize Physical Profile via Full Profile Update

**Try updating via PUT `/api/v1/users/me` first:**

```swift
PUT /api/v1/users/me
Body: {
  "name": "Marcos Barbero",
  "preferred_unit_system": "metric",
  "language_code": "en",
  "biological_sex": "male",
  "height_cm": 170.0
}
```

This might initialize the physical fields, allowing subsequent PATCH requests to work.

### Solution 2: Ensure height_cm is Float

**Current iOS code:**
```swift
"height_cm": 170  // Integer
```

**Should be:**
```swift
"height_cm": 170.0  // Float/Double
```

Check JSON encoding to ensure Double is encoded as decimal, not integer.

### Solution 3: Backend - Allow PATCH to Create (Upsert)

**Backend team action:**
- Modify PATCH endpoint to create physical fields if they don't exist
- Or document that PUT `/api/v1/users/me` must be called first

---

## 📊 Comparison: curl vs iOS

| Aspect | curl (Works) | iOS (404) |
|--------|-------------|-----------|
| **Endpoint** | `/api/v1/users/me/physical` | `/api/v1/users/me/physical` |
| **Method** | PATCH | PATCH |
| **Headers** | ✅ Correct | ✅ Correct (assumed) |
| **Body Fields** | `biological_sex`, `height_cm` | `biological_sex`, `height_cm` |
| **User** | Test User (profile exists) | Marcos Barbero (profile exists) |
| **Physical Fields** | ✅ Initialized | ❌ Not initialized? |
| **height_cm Type** | 175.5 (float) | 170 (int?) |
| **Response** | 200 OK | 404 Not Found |

---

## 🧪 Debug Steps

### Step 1: Verify iOS Request Format

**Add logging to see exact HTTP request:**

```swift
// In PhysicalProfileAPIClient
print("Full request URL: \(request.url?.absoluteString ?? "nil")")
print("Headers: \(request.allHTTPHeaderFields ?? [:])")
print("Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")
```

**Expected:**
```
URL: https://fit-iq-backend.fly.dev/api/v1/users/me/physical
Headers: {
  "Content-Type": "application/json",
  "X-API-Key": "4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW",
  "Authorization": "Bearer <token>"
}
Body: {"biological_sex":"male","height_cm":170}
```

### Step 2: Check Token Validity

**Test token with working endpoint:**

```bash
# Extract token from iOS app logs
# Then test with curl:
curl -i https://fit-iq-backend.fly.dev/api/v1/users/me \
  -H "Authorization: Bearer $IOS_TOKEN" \
  -H "X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW"

# Expected: 200 OK with user profile
# If 401: Token expired/invalid
# If 200: Token is fine
```

### Step 3: Initialize Physical Profile

**Try full profile update from iOS:**

```swift
// Try PUT /api/v1/users/me instead
let url = "\(baseURL)/api/v1/users/me"
request.httpMethod = "PUT"
request.httpBody = try encoder.encode([
    "name": "Marcos Barbero",
    "biological_sex": "male",
    "height_cm": 170.0,
    "preferred_unit_system": "metric",
    "language_code": "en"
])
```

### Step 4: Ensure Float Encoding

**Check PhysicalProfileUpdateRequest DTO:**

```swift
struct PhysicalProfileUpdateRequest: Encodable {
    let biologicalSex: String?
    let heightCm: Double?  // Must be Double, not Int
    let dateOfBirth: String?
}
```

**Verify encoding:**
```swift
let dto = PhysicalProfileUpdateRequest(
    biologicalSex: "male",
    heightCm: 170.0,  // Not 170
    dateOfBirth: nil
)
```

---

## 🎯 Recommended Actions

### Immediate (iOS Team)

1. **Verify heightCm is encoded as Double**
   - Check `PhysicalProfileUpdateRequest` uses `Double?`
   - Ensure JSON encoding produces `170.0` not `170`

2. **Add detailed request logging**
   - Log complete URL, headers, body
   - Verify matches curl format exactly

3. **Try initializing via PUT `/api/v1/users/me`**
   - Update full profile with physical fields
   - Then retry PATCH

### Backend Team

1. **Check why "Marcos Barbero" returns 404**
   - User exists (metadata updates work)
   - Profile ID: `fd72cb93-71e4-440f-b055-19695a221f83`
   - Why can't physical fields be updated?

2. **Consider upsert behavior**
   - Allow PATCH to create physical fields if they don't exist
   - Or document initialization requirement

3. **Clarify initialization**
   - Document when physical fields are created
   - Provide error message guidance (404 vs 400)

---

## 📝 Key Insights

### What We Know

1. ✅ **Backend endpoint is fully functional**
   - curl returns 200 OK
   - Accepts `biological_sex` and `height_cm`
   - Returns full profile with physical data

2. ✅ **iOS authentication works**
   - Metadata updates succeed
   - Same token, same user

3. ❌ **iOS physical updates fail**
   - 404 "User profile not found"
   - Same endpoint, same format

4. 🤔 **Possible causes:**
   - Physical fields not initialized for iOS user
   - height_cm encoding difference (int vs float)
   - Backend requires initialization step

### What We Don't Know

- Why does "Test User" have physical profile but "Marcos Barbero" doesn't?
- Is there a registration step that was skipped?
- Does backend require specific initialization?

---

## 📊 Next Steps Checklist

- [ ] Verify iOS encodes `height_cm` as Double (170.0 not 170)
- [ ] Add detailed request logging in iOS
- [ ] Compare iOS logs with curl command exactly
- [ ] Try PUT `/api/v1/users/me` to initialize physical fields
- [ ] Test with same token from iOS app in curl
- [ ] Backend team: Check database for user fd72cb93-71e4-440f-b055-19695a221f83
- [ ] Backend team: Document physical profile initialization
- [ ] Consider switching to PUT `/api/v1/users/me` for all updates

---

## 🔗 Related Documentation

- **Backend 400 Error:** `docs/fixes/BACKEND_400_PHYSICAL_PROFILE_2025_01_27.md`
- **iOS Fix:** `docs/fixes/CRITICAL_FIX_BIOLOGICAL_SEX_HEIGHT_2025_01_27.md`
- **Workaround Applied:** `docs/handoffs/BACKEND_400_ERROR_SUMMARY_2025_01_27.md`

---

**Status:** Investigation in progress  
**Blocker:** Need to understand why iOS user gets 404 when endpoint works  
**Workaround:** iOS app continues working with local storage  
**Impact:** Low - User experience unaffected, data safe locally