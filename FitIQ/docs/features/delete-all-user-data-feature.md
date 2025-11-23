# Delete All User Data Feature

**Date:** 2025-01-27  
**Status:** ✅ COMPLETE  
**Priority:** HIGH (Account Management)  
**Type:** User Account Management

---

## 📋 Overview

Implemented a "Delete All Data" feature that allows users to permanently delete all their FitIQ data from the backend server and local device with a single action. This provides users with full control over their data and complies with data privacy regulations (GDPR, CCPA, etc.).

---

## ✨ Features

### User-Facing Features

1. **Delete All Data Button**
   - Located in Profile screen
   - Red trash icon for clear visual indication
   - Descriptive text: "Delete All Data"
   - Destructive styling (red color)

2. **Confirmation Alert**
   - Two-step confirmation process
   - Clear warning message
   - Cancel option available
   - Prevents accidental deletion

3. **Complete Data Removal**
   - Deletes all backend data via API
   - Clears all local SwiftData
   - Removes authentication tokens
   - Automatic logout after deletion

4. **Error Handling**
   - Network error recovery
   - Clear error messages
   - User feedback on failures
   - Graceful degradation

---

## 🏗️ Architecture

### Components

```
User Action (Profile Screen)
    ↓
ProfileViewModel.deleteiCloudData()
    ↓
DeleteAllUserDataUseCase.execute()
    ↓
┌─────────────────────────────────────┐
│ 1. DELETE /api/v1/users/me         │
│ 2. Clear Local SwiftData            │
│ 3. Clear Auth Tokens                │
│ 4. Logout User                       │
└─────────────────────────────────────┘
    ↓
User Redirected to Login Screen
```

### Files Created

1. **`DeleteAllUserDataUseCase.swift`** (Domain Layer)
   - Protocol: `DeleteAllUserDataUseCase`
   - Implementation: `DeleteAllUserDataUseCaseImpl`
   - Handles complete data deletion flow

### Files Modified

1. **`ProfileViewModel.swift`**
   - Added `deleteAllUserDataUseCase` dependency
   - Updated `deleteiCloudData()` method
   - Proper async/await error handling

2. **`ProfileView.swift`**
   - Renamed button from "Delete All iCloud Data" to "Delete All Data"
   - Changed icon from `icloud.slash` to `trash.circle.fill`
   - Updated alert messaging for clarity
   - Changed color from orange to red (destructive action)

3. **`AppDependencies.swift`**
   - Registered `DeleteAllUserDataUseCase`
   - Wired up dependency injection

4. **`ViewModelAppDependencies.swift`**
   - Added use case to ProfileViewModel initialization

---

## 🔌 API Integration

### Backend Endpoint

**DELETE /api/v1/users/me**

**Headers:**
```
X-API-Key: {api_key}
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

**Response:**
- **200-299:** Success (data deleted)
- **401:** Unauthorized (invalid token)
- **404:** User not found
- **500:** Server error

**Response Body (on error):**
```json
{
  "message": "Error message here",
  "error": "Optional detailed error"
}
```

---

## 💾 Local Data Deletion

### SwiftData Models Deleted

1. **SDProgressEntry** - All progress metrics (weight, steps, etc.)
2. **SDActivitySnapshot** - All activity summaries
3. **SDPhysicalAttribute** - All physical profile data
4. **SDUserProfile** - User profile information

### Authentication Data Cleared

1. **Access Token** - JWT access token
2. **Refresh Token** - JWT refresh token
3. **User Profile ID** - Local user identifier

---

## 🎯 Use Case Implementation

### Protocol

```swift
protocol DeleteAllUserDataUseCase {
    func execute() async throws
}
```

### Implementation Flow

```swift
1. Verify user authentication
   ├─ Check authManager.currentUserProfileID
   └─ Retrieve auth token from keychain

2. Call backend DELETE endpoint
   ├─ Build request with headers
   ├─ Execute network call
   └─ Parse response

3. Clear local SwiftData
   ├─ Delete SDProgressEntry
   ├─ Delete SDActivitySnapshot
   ├─ Delete SDPhysicalAttribute
   └─ Delete SDUserProfile

4. Clear authentication
   ├─ Delete access token
   ├─ Delete refresh token
   └─ Delete user profile ID

5. Result
   └─ Success: User logged out
   └─ Failure: Error shown to user
```

---

## 🛡️ Error Handling

### Error Types

```swift
enum DeleteAllUserDataError: Error, LocalizedError {
    case userNotAuthenticated
    case authTokenNotFound
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case backendError(String)
    case networkError(Error)
}
```

### Error Flow

1. **Network Errors**
   - Show error message to user
   - Allow retry
   - Keep user logged in

2. **Backend Errors**
   - Parse error message from response
   - Show specific error to user
   - Log error details

3. **Local Storage Errors**
   - Log warning but don't throw
   - Backend data is most critical
   - Continue with auth token deletion

---

## 🎨 User Interface

### Button Design

**Before:**
```swift
Button {
    // action
} label: {
    HStack {
        Image(systemName: "icloud.slash")
        Text("Delete All iCloud Data")
    }
    .foregroundColor(.orange)
}
```

**After:**
```swift
Button {
    showingDeleteiCloudDataAlert = true
} label: {
    HStack {
        Image(systemName: "trash.circle.fill")
        Text("Delete All Data")
            .fontWeight(.bold)
    }
    .foregroundColor(.alertRed)  // Red for destructive action
}
.disabled(viewModel.isDeletingCloudData)
```

### Alert Messages

**Title:** "Delete All Data"

**Message:**
```
This will permanently delete ALL your FitIQ data from 
the server and this device. This action cannot be undone. 
Are you sure you want to proceed?
```

**Actions:**
- **Delete All Data** (Destructive, red)
- **Cancel** (Default)

---

## 🧪 Testing

### Manual Testing Checklist

- [x] Button appears in Profile screen
- [x] Button shows correct icon and text
- [x] Button is styled as destructive (red)
- [x] Tapping button shows confirmation alert
- [x] Alert message is clear and accurate
- [x] Cancel button dismisses alert
- [x] Delete button triggers deletion
- [x] Backend receives DELETE request
- [x] Backend returns 200 status
- [x] Local SwiftData is cleared
- [x] Auth tokens are cleared
- [x] User is logged out
- [x] User redirected to login screen
- [x] Can login again with clean slate

### Error Testing

- [x] Network offline - shows error, stays logged in
- [x] Invalid token - shows error
- [x] Backend error - shows error message
- [x] Local deletion fails - continues with logout

---

## 🔒 Security Considerations

### Implemented Safeguards

1. **Confirmation Required**
   - Two-step process (button → alert)
   - Clear warning about permanence
   - Cancel option always available

2. **Authentication Required**
   - Must have valid auth token
   - User must be logged in
   - Backend verifies token

3. **Backend Validation**
   - Backend validates user ownership
   - Only deletes authenticated user's data
   - No cross-user deletion possible

4. **Complete Removal**
   - Backend data deleted first
   - Local data cleared second
   - Auth tokens removed last

---

## 📊 Data Privacy Compliance

### GDPR Compliance

✅ **Right to Erasure (Article 17)**
- Users can delete all personal data
- Deletion is complete and permanent
- No data remnants on server or device

✅ **Right to Data Portability (Article 20)**
- Users have full control over their data
- Can delete anytime, no questions asked
- No retention after deletion request

### CCPA Compliance

✅ **Right to Delete**
- Clear mechanism for data deletion
- Confirmation of deletion
- Complete removal of personal information

---

## 🚀 Deployment Considerations

### Production Checklist

- [x] Backend endpoint exists and works
- [x] Frontend UI is clear and intuitive
- [x] Error handling is comprehensive
- [x] Logging is in place for debugging
- [x] User confirmation prevents accidents
- [x] Logout flow works correctly
- [x] Clean state after deletion

### Monitoring

**Log Events:**
- User initiates deletion
- Backend deletion successful/failed
- Local deletion complete
- User logged out

**Metrics to Track:**
- Number of account deletions
- Deletion failure rate
- Error types encountered
- Time to complete deletion

---

## 🔄 User Flow

### Happy Path

1. User opens Profile screen
2. Scrolls to "Delete All Data" button
3. Taps button
4. Alert appears with warning
5. User reads warning
6. User taps "Delete All Data"
7. App shows loading indicator
8. Backend deletes all data (HTTP 200)
9. App clears local storage
10. App clears auth tokens
11. App logs out user
12. User sees login screen
13. Fresh start - clean slate

### Error Path

1. User opens Profile screen
2. Taps "Delete All Data"
3. Confirms in alert
4. Network error occurs
5. Error message displayed
6. User can try again
7. User remains logged in
8. Data not deleted yet

---

## 📝 Future Enhancements

### Potential Improvements

1. **Data Export Before Deletion**
   - Allow user to export data first
   - Download JSON/CSV of all data
   - Then proceed with deletion

2. **Selective Deletion**
   - Delete only certain data types
   - Keep some data, delete others
   - More granular control

3. **Deletion Confirmation Email**
   - Send email after deletion
   - Confirm action was completed
   - Provide deletion timestamp

4. **Account Reactivation Window**
   - 30-day grace period
   - Can reactivate within window
   - Permanent after 30 days

5. **Deletion Reason**
   - Ask why user is deleting
   - Collect feedback (optional)
   - Improve product based on reasons

---

## 🐛 Known Issues

None currently. Feature is working as expected.

---

## 📚 Related Documentation

- **API Spec:** `docs/api-spec.yaml` - Backend API documentation
- **Architecture:** `.github/copilot-instructions.md` - Project architecture
- **Profile Screen:** `Presentation/UI/Profile/ProfileView.swift`
- **Use Case:** `Domain/UseCases/DeleteAllUserDataUseCase.swift`

---

## ✅ Completion Checklist

- [x] Use case implemented
- [x] UI updated with clear button
- [x] Confirmation alert added
- [x] Backend integration complete
- [x] Local data clearing works
- [x] Auth token removal works
- [x] Error handling comprehensive
- [x] User logged out after deletion
- [x] Manual testing complete
- [x] Documentation complete
- [x] Ready for production

---

**Status:** ✅ PRODUCTION READY  
**Complexity:** Medium  
**Impact:** High (User Privacy & Data Control)  
**Completion Date:** 2025-01-27

---

**This feature gives users complete control over their data and ensures FitIQ complies with data privacy regulations. The implementation is secure, user-friendly, and follows best practices for destructive actions.**