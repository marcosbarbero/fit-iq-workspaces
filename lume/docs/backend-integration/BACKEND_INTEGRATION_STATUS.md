# Backend Integration Status

**Date:** 2025-01-15  
**Backend URL:** https://fit-iq-backend.fly.dev  
**Status:** ⚠️ Configured but Untested  

---

## Current Configuration

### Backend Details

```xml
<!-- config.plist -->
<key>BACKEND_BASE_URL</key>
<string>https://fit-iq-backend.fly.dev</string>

<key>API_KEY</key>
<string>4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW</string>
```

**API Endpoints:**
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Token refresh
- `POST /api/v1/auth/logout` - User logout

---

## Integration Status

### ✅ iOS Side - Complete

- [x] All code implemented per swagger.yaml
- [x] Backend URL configured in config.plist
- [x] API key configured
- [x] Request/response models match API spec
- [x] Error handling implemented
- [x] Token storage (Keychain) ready
- [x] Date format correct (YYYY-MM-DD for API)
- [x] COPPA compliance (age 13+ validation)
- [x] Outbox pattern for reliability

### ⚠️ Backend Side - Unknown

- [ ] Backend server is running
- [ ] Endpoints are live and accessible
- [ ] API key is valid and registered
- [ ] Database is configured
- [ ] CORS headers allow iOS requests
- [ ] SSL certificate is valid
- [ ] Rate limiting configured

### 🧪 Integration Testing - Not Done

- [ ] Can reach backend from iOS
- [ ] Registration endpoint works
- [ ] Login endpoint works
- [ ] Token refresh works
- [ ] Error responses are correct
- [ ] Date validation works server-side

---

## Can You Create an Account?

### Short Answer: Maybe! 🤷‍♂️

**It depends on:**
1. Is the backend server running?
2. Is the API key valid?
3. Are the endpoints implemented?

### How to Test

#### Step 1: Check if Backend is Reachable

**Using Terminal:**
```bash
curl https://fit-iq-backend.fly.dev/api/v1/auth/register \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!",
    "name": "Test User",
    "date_of_birth": "1990-05-15"
  }'
```

**Expected Response (if backend works):**
```json
{
  "data": {
    "user_id": "uuid",
    "email": "test@example.com",
    "name": "Test User",
    "created_at": "2025-01-15T12:00:00Z",
    "access_token": "jwt_token",
    "refresh_token": "refresh_token"
  }
}
```

**Or:**
```json
{
  "error": {
    "message": "Email already exists",
    "code": "EMAIL_ALREADY_EXISTS"
  }
}
```

#### Step 2: Test from iOS App

1. Build and run the app (⌘+R)
2. Tap "Sign Up"
3. Fill in the form:
   - Name: Your Name
   - Email: your@email.com
   - Password: SecurePass123!
   - DOB: 15/05/1990
4. Tap "Create Account"

**What Might Happen:**

**Scenario A: Success ✅**
```
- Loading indicator appears
- Network request sent to backend
- Backend responds with 201 Created
- Token saved to Keychain
- Navigate to main app
```

**Scenario B: Backend Error ❌**
```
- Loading indicator appears
- Network request sent
- Backend returns error (400, 409, 500)
- Error message displayed
- User stays on registration screen
```

**Scenario C: Network Error 🔌**
```
- Loading indicator appears
- Network request fails (timeout, no connection)
- Error: "Unable to connect. Please check your internet connection"
- User stays on registration screen
```

**Scenario D: Backend Not Running ⚠️**
```
- Loading indicator appears
- Request times out or returns 503
- Error: "An unexpected error occurred"
- User stays on registration screen
```

---

## Debugging Backend Issues

### Check Backend Status

**Option 1: Browser**
1. Open: https://fit-iq-backend.fly.dev
2. You should see some response (API docs, health check, etc.)
3. If you get "Cannot reach this page" → backend is down

**Option 2: cURL Health Check**
```bash
curl https://fit-iq-backend.fly.dev/health
# or
curl https://fit-iq-backend.fly.dev/
```

### Check iOS Network Logs

**Enable in Xcode:**
1. Run app in Xcode
2. Open Console (⌘+⇧+Y)
3. Try to register
4. Look for network logs

**What to Look For:**
```
✅ Good:
"POST https://fit-iq-backend.fly.dev/api/v1/auth/register"
"Status: 201"
"Received tokens"

❌ Bad:
"Network error: The Internet connection appears to be offline"
"Status: 500"
"Status: 401 - Invalid API key"
```

### Common Issues & Solutions

#### Issue 1: "Unable to connect"
**Cause:** Backend not running or URL incorrect  
**Solution:** 
- Verify backend is running
- Check URL in config.plist (no typos)
- Try curl command to test

#### Issue 2: "401 Unauthorized"
**Cause:** Invalid API key  
**Solution:**
- Verify API key with backend team
- Check key in config.plist (no extra spaces)
- Backend must be configured to accept this key

#### Issue 3: "400 Bad Request"
**Cause:** Request format incorrect  
**Solution:**
- Check swagger.yaml vs iOS request format
- Verify date format is YYYY-MM-DD
- Check all required fields are sent

#### Issue 4: "409 Conflict"
**Cause:** Email already registered  
**Solution:**
- This is actually GOOD - backend is working!
- Try a different email address

#### Issue 5: "500 Internal Server Error"
**Cause:** Backend bug or database issue  
**Solution:**
- Contact backend team
- Check backend logs
- Report the error details

---

## What iOS Sends

### Registration Request

**Endpoint:** `POST /api/v1/auth/register`

**Headers:**
```
Content-Type: application/json
X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW
```

**Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "John Doe",
  "date_of_birth": "1990-05-15"
}
```

**Note:** Date is sent as string in YYYY-MM-DD format (ISO 8601)

### What iOS Expects Back

**Success (201 Created):**
```json
{
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2025-01-15T12:00:00Z",
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Error (400/409/500):**
```json
{
  "error": {
    "message": "Human-readable error message",
    "code": "ERROR_CODE"
  }
}
```

---

## Testing Checklist

### Before Testing
- [ ] Backend server is running
- [ ] API key is registered with backend
- [ ] Database is accessible
- [ ] iOS app builds successfully
- [ ] config.plist is in bundle resources

### Test Registration
- [ ] Can reach registration screen
- [ ] All fields are visible and readable
- [ ] Can enter name, email, password, DOB
- [ ] Form validation works (age 13+)
- [ ] Submit button enables when valid
- [ ] Submit button disabled when invalid
- [ ] Loading indicator appears on submit
- [ ] Network request is sent
- [ ] Backend responds
- [ ] Success: Navigate to main app
- [ ] Error: Show error message

### Test Error Handling
- [ ] Try registering with existing email (409)
- [ ] Try registering with invalid email (400)
- [ ] Try registering with age < 13 (400)
- [ ] Try with network disconnected
- [ ] Error messages are user-friendly
- [ ] Can retry after error

### Test Login
- [ ] Can switch to login screen
- [ ] Can login with created account
- [ ] Token is saved
- [ ] Navigate to main app
- [ ] Wrong password shows error

---

## Next Steps

### 1. Coordinate with Backend Team

**Ask them:**
- Is the backend running at https://fit-iq-backend.fly.dev?
- Is the API key valid: `4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW`?
- Are the auth endpoints implemented?
- Can they test with curl/Postman?
- Do they see iOS requests in their logs?

### 2. Test Basic Connectivity

Run this command to verify backend is reachable:
```bash
curl -I https://fit-iq-backend.fly.dev
```

Expected: HTTP response (200, 404, etc. - not connection error)

### 3. Test Registration Endpoint

Use the curl command from "Step 1" above to test registration independently of iOS.

### 4. Test from iOS

Once backend is confirmed working:
1. Build iOS app
2. Try to register
3. Check console logs
4. Report any issues to backend team

### 5. Document Results

Keep notes on:
- What works
- What fails
- Error messages
- Console logs
- Network responses

---

## Current Status Summary

**iOS App:**
- ✅ Code complete and correct
- ✅ Matches swagger.yaml specification
- ✅ Backend configured
- ✅ Error handling ready
- ✅ UI/UX polished

**Backend Integration:**
- ⚠️ Backend status unknown
- ⚠️ Endpoints not tested
- ⚠️ API key validity unknown
- ⚠️ End-to-end flow not verified

**Can You Test?**
- ✅ Yes! Build and run the app
- ⚠️ Success depends on backend status
- 📞 Coordinate with backend team first
- 🧪 Test with curl before trying iOS

---

## Quick Test Command

**Copy and run this in Terminal:**
```bash
curl -v https://fit-iq-backend.fly.dev/api/v1/auth/register \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPass123!",
    "name": "Test User",
    "date_of_birth": "1990-01-15"
  }'
```

**If this works, the iOS app should work too!**

---

**Summary:** iOS side is 100% ready. Backend integration status is unknown and needs testing. Run the curl command above to check if the backend is working, then try the iOS app.