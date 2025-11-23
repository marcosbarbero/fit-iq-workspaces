# FitIQ iOS Authentication Testing Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Step-by-step guide for testing authentication flows

---

## 🎯 Overview

This guide provides detailed steps for manually testing the authentication and registration flows in the FitIQ iOS app.

---

## 📋 Pre-Testing Checklist

### Environment Setup
- [ ] App built successfully in Xcode
- [ ] Running on iOS simulator or physical device
- [ ] Network connection available
- [ ] Backend API accessible at `https://fit-iq-backend.fly.dev`
- [ ] Console logs visible in Xcode

### Configuration Verification
- [ ] `config.plist` contains valid `BACKEND_BASE_URL`
- [ ] `config.plist` contains valid `API_KEY`
- [ ] Build configuration is correct (Debug/Release)

### Reset State (if needed)
```bash
# Clear app data between tests
# In Simulator: Device → Erase All Content and Settings
# Or: Delete app and reinstall
```

---

## 🧪 Test Scenarios

## Test 1: New User Registration (Happy Path)

### Objective
Verify that a new user can successfully register and is automatically logged in.

### Pre-conditions
- [ ] App freshly installed or data cleared
- [ ] Email address not previously registered

### Test Steps

1. **Launch App**
   - App should show LandingView (Login/Registration screen)
   - AuthState should be `.loggedOut`

2. **Navigate to Registration**
   - Tap "Register" or "Create Account" button
   - Registration form should appear

3. **Fill Registration Form**
   - **Email:** `testuser+${timestamp}@example.com`
   - **Password:** `Test123!@#`
   - **First Name:** `Test`
   - **Last Name:** `User`
   - **Date of Birth:** Select date (e.g., 1990-01-01)

4. **Submit Registration**
   - Tap "Register" button
   - Loading indicator should appear
   - **Watch Console Logs:**
     ```
     UserAuthAPIClient: Attempting to register user with email: testuser@example.com
     UserAuthAPIClient: User successfully registered on remote service.
     UserAuthAPIClient: Calling login to retrieve user profile...
     UserAuthAPIClient: Attempting to log in user with email: testuser@example.com
     UserAuthAPIClient: User successfully logged in on remote service.
     UserAuthAPIClient: Decoded user_id: {uuid}. Fetching user profile...
     CreateUserUseCase: Successfully saved UserProfile to local store
     AuthManager: User successfully authenticated
     ```

5. **Verify Success State**
   - [ ] Success message displayed
   - [ ] User navigated to onboarding or main app
   - [ ] AuthState changed to `.needsSetup` or `.loggedIn`
   - [ ] No error messages shown

### Expected Results
✅ User successfully registered  
✅ Tokens saved to Keychain  
✅ User profile saved to SwiftData  
✅ App navigated to next screen  
✅ AuthManager.isAuthenticated = true  

### Keychain Verification (Optional)
```swift
// Check Keychain contains tokens
let accessToken = try? KeychainAuthTokenAdapter().fetchAccessToken()
let refreshToken = try? KeychainAuthTokenAdapter().fetchRefreshToken()
print("Access Token: \(accessToken != nil)")
print("Refresh Token: \(refreshToken != nil)")
```

---

## Test 2: Registration with Validation Errors

### Objective
Verify that validation errors are properly displayed.

### Test Cases

#### 2A: Missing Required Fields
1. Leave email field empty
2. Tap "Register"
3. **Expected:** Error message "Please fill out all fields."

#### 2B: Invalid Email Format
1. Enter invalid email: `notanemail`
2. Fill other fields correctly
3. Tap "Register"
4. **Expected:** API validation error displayed

#### 2C: Weak Password (if implemented)
1. Enter weak password: `123`
2. Fill other fields correctly
3. Tap "Register"
4. **Expected:** Validation error displayed

#### 2D: Duplicate Email
1. Register with email: `test@example.com`
2. Complete registration successfully
3. Logout
4. Try to register again with same email: `test@example.com`
5. **Expected:** 409 Conflict error "Email already registered"

### Expected Results
✅ Appropriate error messages displayed  
✅ User remains on registration screen  
✅ No tokens saved  
✅ No navigation occurs  

---

## Test 3: User Login (Happy Path)

### Objective
Verify that an existing user can successfully log in.

### Pre-conditions
- [ ] User already registered (use Test 1 to create)
- [ ] App logged out or data cleared

### Test Steps

1. **Launch App**
   - App should show LandingView

2. **Navigate to Login**
   - If on registration screen, switch to login
   - Login form should appear

3. **Fill Login Form**
   - **Email:** Use email from Test 1
   - **Password:** Use password from Test 1

4. **Submit Login**
   - Tap "Login" button
   - Loading indicator should appear
   - **Watch Console Logs:**
     ```
     UserAuthAPIClient: Attempting to log in user with email: test@example.com
     UserAuthAPIClient: User successfully logged in on remote service.
     UserAuthAPIClient: Decoded user_id: {uuid}. Fetching user profile...
     AuthenticateUserUseCase: Successfully saved UserProfile to local store
     AuthManager: User successfully authenticated
     ```

5. **Verify Success State**
   - [ ] Success message displayed
   - [ ] User navigated to main app
   - [ ] AuthState changed to `.loggedIn`
   - [ ] User profile loaded correctly

### Expected Results
✅ User successfully logged in  
✅ Tokens saved to Keychain  
✅ User profile saved to SwiftData  
✅ App navigated to main app  
✅ AuthManager.isAuthenticated = true  

---

## Test 4: Login with Invalid Credentials

### Objective
Verify proper error handling for authentication failures.

### Test Cases

#### 4A: Wrong Password
1. Enter correct email
2. Enter wrong password: `WrongPassword123`
3. Tap "Login"
4. **Expected:** 401 error "Invalid credentials"

#### 4B: Non-existent User
1. Enter email not registered: `nonexistent@example.com`
2. Enter any password
3. Tap "Login"
4. **Expected:** 401 error "Invalid credentials"

#### 4C: Empty Fields
1. Leave email or password empty
2. Tap "Login"
3. **Expected:** Error message "Please enter your email and password."

### Expected Results
✅ Error messages displayed  
✅ User remains on login screen  
✅ No tokens saved  
✅ AuthManager.isAuthenticated = false  

---

## Test 5: Persistent Login (Session Persistence)

### Objective
Verify that user session persists across app restarts.

### Test Steps

1. **Complete Successful Login**
   - Follow Test 3 steps
   - Verify user is logged in

2. **Kill App Completely**
   - Close app from app switcher
   - Or restart device

3. **Relaunch App**
   - Open app again

4. **Verify Persistent Session**
   - [ ] App should NOT show login screen
   - [ ] User should go directly to main app
   - [ ] AuthState should be `.loggedIn`
   - [ ] Console shows: "User session checked: Authenticated from Keychain"

### Expected Results
✅ User remains authenticated  
✅ Tokens loaded from Keychain  
✅ Profile loaded from SwiftData  
✅ No login required  
✅ App navigates directly to main content  

---

## Test 6: Logout Flow

### Objective
Verify that logout properly clears all user data.

### Test Steps

1. **Login as User**
   - Follow Test 3 to log in

2. **Navigate to Profile/Settings**
   - Go to profile or settings screen
   - Find logout button

3. **Tap Logout**
   - Confirm logout if prompted

4. **Verify Logout State**
   - [ ] User navigated back to LandingView
   - [ ] AuthState changed to `.loggedOut`
   - [ ] Console shows: "User logged out. Routing to authentication view"

5. **Verify Data Cleared**
   - [ ] Tokens deleted from Keychain
   - [ ] User profile ID cleared
   - [ ] Onboarding flag reset

6. **Relaunch App**
   - Kill and reopen app
   - [ ] Should show login screen (not auto-login)

### Expected Results
✅ User logged out successfully  
✅ All tokens removed from Keychain  
✅ User profile ID cleared  
✅ App navigates to login screen  
✅ Session does NOT persist after logout  

---

## Test 7: Network Error Handling

### Objective
Verify proper handling of network-related errors.

### Test Cases

#### 7A: No Internet Connection
1. Disable WiFi and cellular data
2. Attempt to register or login
3. **Expected:** Network error message displayed

#### 7B: API Server Down
1. Modify `config.plist` with invalid URL
2. Attempt to register or login
3. **Expected:** Connection error displayed

#### 7C: Slow Network (Timeout)
1. Use network conditioner for slow connection
2. Attempt to register or login
3. **Expected:** Loading indicator, then timeout error

### Expected Results
✅ User-friendly error messages  
✅ No app crashes  
✅ Ability to retry  

---

## Test 8: JWT Token Validation

### Objective
Verify that JWT tokens are properly decoded and used.

### Test Steps

1. **Login Successfully**
   - Complete login flow

2. **Inspect Console Logs**
   - Look for: "Decoded user_id: {uuid}"
   - Verify UUID format is correct

3. **Verify Profile Fetch**
   - Confirm profile fetch uses correct user_id
   - Check API call: `GET /api/v1/users/{user_id}`

4. **Verify Token Usage**
   - Subsequent API calls should include token
   - Header: `Authorization: Bearer {token}`

### Expected Results
✅ user_id extracted from JWT  
✅ Profile fetched with correct ID  
✅ Token included in authenticated requests  

---

## Test 9: Onboarding State Management

### Objective
Verify correct navigation based on onboarding completion.

### Test Scenarios

#### 9A: New User (No Onboarding)
1. Register new user
2. **Expected:** Navigate to onboarding setup
3. AuthState should be `.needsSetup`

#### 9B: Returning User (Onboarding Complete)
1. Complete onboarding for a user
2. Logout and login again
3. **Expected:** Navigate directly to main app
4. AuthState should be `.loggedIn`

#### 9C: Complete Onboarding
1. Register and reach onboarding
2. Complete all onboarding steps
3. **Expected:** Navigate to main app
4. Flag saved: `hasFinishedOnboardingSetup = true`

### Expected Results
✅ Correct navigation based on onboarding state  
✅ Onboarding flag persists  
✅ AuthState transitions correctly  

---

## 🐛 Common Issues & Troubleshooting

### Issue 1: Registration Fails with "Invalid Response"
**Possible Causes:**
- Backend API format changed
- JSON decoding error
- Missing required fields

**Debug Steps:**
1. Check console for detailed error
2. Verify API response format in Swagger
3. Compare with `CreateUserRequest` DTO
4. Check network response in console logs

### Issue 2: "Failed to decode user_id from JWT"
**Possible Causes:**
- Invalid JWT format
- Incorrect base64 decoding
- Missing user_id in token payload

**Debug Steps:**
1. Print raw JWT token
2. Verify token format (3 parts separated by dots)
3. Decode JWT manually at jwt.io
4. Check if payload contains `user_id` field

### Issue 3: Tokens Not Persisting
**Possible Causes:**
- Keychain access denied
- Keychain service not configured
- Save operation failing silently

**Debug Steps:**
1. Check Keychain entitlements
2. Look for Keychain error logs
3. Verify `KeychainAuthTokenAdapter` configuration
4. Test Keychain access directly

### Issue 4: Profile Not Loading After Login
**Possible Causes:**
- Profile fetch API failing
- Invalid user_id
- SwiftData save error

**Debug Steps:**
1. Check profile fetch API call logs
2. Verify GET /api/v1/users/{id} endpoint
3. Check SwiftData context initialization
4. Look for persistence error logs

---

## 📊 Testing Checklist Summary

### Registration
- [ ] Valid registration succeeds
- [ ] Missing fields show error
- [ ] Invalid email shows error
- [ ] Duplicate email shows 409 error
- [ ] Tokens saved to Keychain
- [ ] Profile saved to SwiftData
- [ ] Navigation to onboarding/main app

### Login
- [ ] Valid login succeeds
- [ ] Invalid credentials show 401 error
- [ ] Missing fields show error
- [ ] Tokens saved to Keychain
- [ ] Profile saved and loaded
- [ ] Navigation to main app

### Session Management
- [ ] Session persists across app restarts
- [ ] Logout clears all data
- [ ] No auto-login after logout
- [ ] Onboarding state managed correctly

### Error Handling
- [ ] Network errors handled gracefully
- [ ] API errors display user-friendly messages
- [ ] Validation errors clear and actionable
- [ ] No app crashes on errors

### Security
- [ ] Tokens stored in Keychain (not UserDefaults)
- [ ] HTTPS used for all API calls
- [ ] API key not hardcoded in source
- [ ] Sensitive data not logged

---

## 🔍 Console Log Keywords to Monitor

**Success Indicators:**
- `"User successfully registered on remote service"`
- `"User successfully logged in on remote service"`
- `"Decoded user_id: {uuid}"`
- `"Successfully saved UserProfile to local store"`
- `"User successfully authenticated"`

**Error Indicators:**
- `"Failed to register user"`
- `"Failed to log in user"`
- `"Failed to decode user_id from JWT"`
- `"Failed to save UserProfile"`
- `"ERROR: AuthManager failed to save"`

---

## 📝 Test Report Template

```
Test Date: _______________
Tester: _______________
Device/Simulator: _______________
iOS Version: _______________
App Version: _______________

Test Results:
[ ] Test 1: Registration (Happy Path) - PASS / FAIL
[ ] Test 2: Registration Validation - PASS / FAIL
[ ] Test 3: Login (Happy Path) - PASS / FAIL
[ ] Test 4: Login with Invalid Credentials - PASS / FAIL
[ ] Test 5: Persistent Login - PASS / FAIL
[ ] Test 6: Logout Flow - PASS / FAIL
[ ] Test 7: Network Error Handling - PASS / FAIL
[ ] Test 8: JWT Token Validation - PASS / FAIL
[ ] Test 9: Onboarding State - PASS / FAIL

Issues Found:
1. _______________
2. _______________
3. _______________

Notes:
_______________________________________________
_______________________________________________
```

---

**Version:** 1.0.0  
**Status:** Ready for Use  
**Last Updated:** 2025-01-27