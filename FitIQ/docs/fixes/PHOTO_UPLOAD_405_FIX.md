# Photo Upload Error Fix

**Date:** 2025-01-27  
**Status:** ✅ Fixed  
**Severity:** High (Feature Blocking)

---

## Problem

Photo-based meal logging was failing with multiple errors:
1. **405 Method Not Allowed** - Wrong JSON field name
2. **400 Bad Request** - Backend expects multipart/form-data, not JSON

```
UploadMealPhotoUseCase: Starting photo upload
UploadMealPhotoUseCase: Meal type: breakfast
UploadMealPhotoUseCase: Image size: 2590 KB
UploadMealPhotoUseCase: Base64 encoded, length: 3536932
PhotoRecognitionAPIClient: Uploading photo for meal recognition
PhotoRecognitionAPIClient: Meal type: breakfast
PhotoRecognitionAPIClient: Image size: 3536932 bytes
PhotoRecognitionAPIClient: POST https://fit-iq-backend.fly.dev/api/v1/meal-logs/photo
UploadMealPhotoUseCase: ❌ API error: Unknown error (status code: 405)
```

---

## Root Causes

### Issue 1: Wrong JSON Field Name (405 Error)

The `PhotoRecognitionAPIClient` was sending the wrong JSON field name for the image data:

**Incorrect:**
```swift
var requestBody: [String: Any] = [
    "image": imageData,  // ❌ Wrong field name
    "meal_type": mealType,
    "logged_at": ISO8601DateFormatter().string(from: loggedAt),
]
```

**According to API Spec:**
```yaml
PhotoRecognitionRequest:
  type: object
  required: [image_data, meal_type]  # ✅ Should be "image_data"
```

### Issue 2: Wrong Content Type (400 Error)

After fixing the field name, the backend returned:
```json
{"error":{"message":"Failed to parse form data"}}
```

**The backend expects `multipart/form-data` (file upload), not `application/json`.**

This is a **mismatch between the API spec (which says JSON) and the backend implementation (which expects multipart)**. The iOS client was implemented according to the spec, but the backend was implemented differently.

---

## Solution

### 1. Changed to Multipart/Form-Data Upload

**File:** `PhotoRecognitionAPIClient.swift`

Completely rewrote the upload method to use `multipart/form-data` format instead of JSON:

```swift
// Create multipart/form-data request
let boundary = "Boundary-\(UUID().uuidString)"
urlRequest.setValue(
    "multipart/form-data; boundary=\(boundary)", 
    forHTTPHeaderField: "Content-Type"
)

var body = Data()

// Add image file (binary data, not base64)
body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append(
    "Content-Disposition: form-data; name=\"photo\"; filename=\"meal.jpg\"\r\n"
        .data(using: .utf8)!)
body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
body.append(imageDataDecoded)  // Raw binary image data
body.append("\r\n".data(using: .utf8)!)

// Add meal_type field
body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append(
    "Content-Disposition: form-data; name=\"meal_type\"\r\n\r\n".data(using: .utf8)!)
body.append("\(mealType)\r\n".data(using: .utf8)!)

// Add logged_at field
body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append(
    "Content-Disposition: form-data; name=\"logged_at\"\r\n\r\n".data(using: .utf8)!)
body.append("\(ISO8601DateFormatter().string(from: loggedAt))\r\n".data(using: .utf8)!)

// Add notes field if present
if let notes = notes {
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append(
        "Content-Disposition: form-data; name=\"notes\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(notes)\r\n".data(using: .utf8)!)
}

// End boundary
body.append("--\(boundary)--\r\n".data(using: .utf8)!)

urlRequest.httpBody = body
```

**Key Changes:**
- Changed from `application/json` to `multipart/form-data`
- Send image as binary file part named `photo`, not base64 string
- Send other fields as separate form parts
- No base64 encoding in transit (more efficient)

### 2. Fixed Duplicate Error Enum Issue

Removed duplicate `PhotoRecognitionAPIError` enum from the client implementation. The client now uses the single enum definition from `PhotoRecognitionAPIProtocol.swift`.

**Before:** Two separate enum definitions (causing error handling to fail)
**After:** Single source of truth in the protocol file

### 3. Enhanced Error Logging

Added comprehensive logging for 400 Bad Request errors:

```swift
case 400:
    print("PhotoRecognitionAPIClient: ❌ 400 Bad Request")
    if let errorMessage = String(data: data, encoding: .utf8) {
        print("PhotoRecognitionAPIClient: Response body: \(errorMessage)")
    }
    print("PhotoRecognitionAPIClient: Request URL: ...")
    print("PhotoRecognitionAPIClient: Request headers: ...")
    print("PhotoRecognitionAPIClient: Request body preview: ...")
    throw PhotoRecognitionAPIError.invalidRequest
```

This logging revealed the backend error: `"Failed to parse form data"`, which led to discovering the multipart/form-data requirement.

### 4. Added Method Not Allowed Error Case

Added `methodNotAllowed` case to `PhotoRecognitionAPIError` enum for better error reporting.

---

## API Endpoint Specification

**Endpoint:** `POST /api/v1/meal-logs/photo`  
**Backend Version Required:** 0.32.0+  
**Authentication:** JWT Bearer Token + X-API-Key

**Request Format:** `multipart/form-data`

**Form Fields:**
- `photo` (file): Binary image data (JPEG, PNG, or WebP)
- `meal_type` (text): breakfast, lunch, dinner, or snack
- `logged_at` (text): ISO8601 datetime (optional)
- `notes` (text): Optional meal notes (optional)

**Note:** The API spec documentation says `application/json`, but the backend implementation expects `multipart/form-data`. The iOS client now uses multipart to match the backend.

**Response (201 Created):**
```json
{
  "data": {
    "id": "photo-rec-123",
    "user_id": "user-456",
    "image_url": "/uploads/photos/user-456/photo-rec-123.jpg",
    "meal_type": "breakfast",
    "status": "processing",
    "logged_at": "2024-01-15T12:30:00Z",
    "created_at": "2024-01-15T12:30:05Z",
    "updated_at": "2024-01-15T12:30:05Z"
  }
}
```

---

## Testing

After the fix:

- ✅ Request uses `multipart/form-data` format (matches backend implementation)
- ✅ Image sent as binary file, not base64 (more efficient)
- ✅ All form fields properly formatted
- ✅ Error handling works correctly (no duplicate enum issues)
- ✅ Comprehensive error logging for debugging
- ✅ All HTTP status codes properly handled (400, 401, 404, 405, 413)

---

## Prevention Guidelines

### 1. Test Against Actual Backend, Not Just Spec

**Important Lesson:** The API spec can differ from backend implementation. Always:
- Test with the actual backend endpoint
- Check error messages carefully
- Look for clues like "Failed to parse form data"
- Be prepared to adapt if spec doesn't match implementation

### 2. Add Comprehensive Error Logging

Always log:
- HTTP status code
- Response body
- Request URL
- Request method
- Request headers
- Request body preview

This helps diagnose mismatches quickly.

### 3. Avoid Duplicate Type Definitions

- Define error enums in protocol files (domain layer)
- Don't duplicate them in implementation files
- Use a single source of truth for shared types

### 3. Add Comprehensive Error Handling

Always handle all expected HTTP status codes:
- **200-299**: Success
- **400**: Bad Request (invalid format)
- **401**: Unauthorized (refresh token)
- **403**: Forbidden
- **404**: Not Found
- **405**: Method Not Allowed (endpoint not implemented)
- **413**: Payload Too Large
- **500+**: Server Error

### 4. Log Request Details for Debugging

When debugging API issues, log:
- Full endpoint URL
- HTTP method
- Request headers
- Request body (sanitized if needed)
- Response status code
- Response body

---

## Related Files

- `PhotoRecognitionAPIClient.swift` - Network client (fixed)
- `UploadMealPhotoUseCase.swift` - Use case orchestration
- `docs/be-api-spec/swagger.yaml` - API specification (source of truth)
- `docs/api-integration/features/photo-meal-logging.md` - Integration guide

---

## Backend Version Check

**Required Backend Version:** 0.32.0+

The photo recognition endpoint was added in version 0.32.0. If you receive a 405 error after this fix, verify the backend version:

1. Check `swagger.yaml` version in API spec
2. Verify backend deployment version
3. Confirm endpoint is implemented in backend codebase

**API Version History:**
- **0.32.0**: Added photo-based meal logging (4 new endpoints)
- **0.31.0**: Added dedicated meal log WebSocket
- **0.30.0**: Enhanced WebSocket notifications
- **0.29.0**: Added meal logs API with natural language parsing

---

## Key Takeaways

1. **API specs can diverge from implementation** - Always test against the actual backend, not just the documentation.

2. **Error messages provide clues** - "Failed to parse form data" indicated the backend expected multipart, not JSON.

3. **Multipart/form-data is better for file uploads** - More efficient than base64-encoding in JSON (saves ~33% bandwidth).

4. **Single source of truth for types** - Don't duplicate enums across files; it breaks error handling.

5. **Comprehensive logging saves time** - Detailed error logs helped identify the root cause quickly.

---

**Status:** 🟢 **Fixed - Photo upload now uses multipart/form-data format matching backend implementation**

---

## Technical Details

### Multipart/Form-Data Format

The multipart format sends data as a series of parts separated by boundaries:

```
--Boundary-ABC123
Content-Disposition: form-data; name="photo"; filename="meal.jpg"
Content-Type: image/jpeg

[binary image data]
--Boundary-ABC123
Content-Disposition: form-data; name="meal_type"

breakfast
--Boundary-ABC123
Content-Disposition: form-data; name="logged_at"

2024-01-27T12:30:00Z
--Boundary-ABC123--
```

### Benefits Over JSON + Base64

1. **Smaller payload**: No base64 encoding (saves ~33% size)
2. **Native file upload**: Standard HTTP file upload mechanism
3. **Better for large files**: More efficient for binary data
4. **Server-side parsing**: Most frameworks handle multipart natively

### API Spec vs. Implementation

**API Spec Says:** `application/json` with `image_data` field  
**Backend Expects:** `multipart/form-data` with `photo` file part

**Resolution:** iOS client now matches backend implementation. The API spec should be updated to reflect the actual implementation.