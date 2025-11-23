# Troubleshooting: Workout Template Sync Errors

**Last Updated:** 2025-01-27  
**Issue:** Failed to fetch exercises for workout templates during sync  
**Error Pattern:** `APIError error 5` (wrappedError) when fetching individual templates

---

## 🔍 Problem Overview

During the workout template sync process, the app successfully fetches the list of templates from `/api/v1/workout-templates/public`, but then fails when fetching individual template details from `/api/v1/workout-templates/{id}` to retrieve exercise data.

### Symptoms

```
SyncWorkoutTemplatesUseCase: [18/840] Fetching exercises for 'Active Recovery - Beginner'
WorkoutTemplateAPIClient: Fetching template 000EF05E-C56D-4F95-B343-88F1B8AC0837
  - ⚠️ Failed to fetch exercises, using template without exercises: The operation couldn't be completed. (FitIQ.APIError error 4.)
```

---

## 🏗️ Architecture Context

### Sync Flow

```
SyncWorkoutTemplatesUseCase.execute()
    ↓
Step 1: Fetch list of templates (paginated)
GET /api/v1/workout-templates/public
    ↓
Step 2: For each template, fetch full details with exercises
GET /api/v1/workout-templates/{id}
    ↓
Step 3: Save to local SwiftData storage
```

### Why Two Steps?

The backend API **intentionally** excludes exercises from the list endpoint for performance:
- `/api/v1/workout-templates/public` - Returns basic info (no exercises)
- `/api/v1/workout-templates/{id}` - Returns full template with exercises

This is documented in the API spec and previous thread conversations.

---

## 🐛 Error Analysis

### APIError Enum Cases

```swift
enum APIError: Error {
    case invalidURL           // 0
    case invalidResponse      // 1
    case decodingError(Error) // 2
    case apiError(statusCode: Int, message: String) // 3
    case apiError(Error)      // 4 - API error with wrapped error
    case wrappedError(Error)  // 5 ← The error we're seeing
    case unauthorized         // 6
    case notFound             // 7
    case invalidUserId        // 8
}
```

**Error 5** = `case wrappedError(Error)` - Generic network/wrapped error

### Possible Root Causes

1. **Authentication Issue**
   - Access token expired
   - Refresh token failed
   - Missing or invalid auth header

2. **Network Error**
   - Request timeout
   - Connection lost
   - DNS resolution failure

3. **Backend Error**
   - 500 Internal Server Error
   - 400 Bad Request
   - 404 Not Found (template ID doesn't exist)

4. **Decoding Error**
   - Malformed JSON response
   - Schema mismatch between backend and iOS app
   - Missing required fields

5. **Rate Limiting**
   - Too many requests in short time
   - Backend throttling

---

## 🔧 Debugging Steps

### 1. Enable Enhanced Logging

The updated code now includes comprehensive logging. Run the sync and check console for:

```
WorkoutTemplateAPIClient: Fetching template <UUID>
WorkoutTemplateAPIClient: Received response with status code: <CODE>
WorkoutTemplateAPIClient: Response data preview: <JSON>
```

### 2. Check HTTP Status Code

Look for the status code in logs:
- **200** - Success (shouldn't error)
- **401** - Unauthorized (token issue)
- **404** - Not Found (bad template ID)
- **500** - Server error
- **Other** - Check API spec

### 3. Inspect Response Body

The enhanced logging now prints the first 500 characters of the response. Look for:
- Error messages from backend
- Validation errors
- Unexpected JSON structure

### 4. Verify Auth Token

Check if token refresh is working:

```
WorkoutTemplateAPIClient: 🔄 Received 401, attempting token refresh (retry 1/2)
WorkoutTemplateAPIClient: 🔄 Refreshing auth token...
WorkoutTemplateAPIClient: ✅ Token refreshed successfully
```

If you see:
```
WorkoutTemplateAPIClient: ❌ No auth token available
```
The user needs to log in again.

### 5. Test Single Template Fetch

Try fetching a single known template ID manually:

```swift
// In debug console or test
let template = try await apiClient.fetchTemplate(id: UUID(uuidString: "000EF05E-C56D-4F95-B343-88F1B8AC0837")!)
print("Fetched: \(template.name)")
print("Exercises: \(template.exercises.count)")
```

### 6. Check Backend API Directly

Use curl or Postman to test the endpoint:

```bash
# Get auth token first
TOKEN="<your_access_token>"
API_KEY="<your_api_key>"

# Test template fetch
curl -X GET \
  "https://fit-iq-backend.fly.dev/api/v1/workout-templates/000EF05E-C56D-4F95-B343-88F1B8AC0837" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "message": "Workout template retrieved successfully",
  "data": {
    "id": "000EF05E-C56D-4F95-B343-88F1B8AC0837",
    "name": "Active Recovery - Beginner",
    "exercises": [
      {
        "id": "...",
        "name": "...",
        ...
      }
    ],
    ...
  }
}
```

---

## 🛠️ Common Fixes

### Fix 1: Token Expired

**Symptom:** All template fetches fail after the first few

**Solution:**
```swift
// Token refresh should happen automatically
// If not working, try manual logout/login
await authManager.logout()
await authManager.login(email: "...", password: "...")
```

### Fix 2: Rate Limiting

**Symptom:** First N templates succeed, then all fail

**Solution:** Add delay between fetches
```swift
// In SyncWorkoutTemplatesUseCase.swift
for (index, template) in allTemplates.enumerated() {
    // Add small delay to avoid rate limiting
    if index > 0 && index % 10 == 0 {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    let fullTemplate = try await apiClient.fetchTemplate(id: template.id)
    templatesWithExercises.append(fullTemplate)
}
```

### Fix 3: Decoding Error

**Symptom:** Status code 200 but still fails

**Solution:** Check response format matches DTO
```swift
// In WorkoutTemplateAPIClient.swift
// Enhanced logging now shows:
print("WorkoutTemplateAPIClient: Response data preview: ...")

// Compare with WorkoutTemplateDTOs.swift
struct WorkoutTemplateResponse: Decodable {
    let id: UUID
    let name: String
    let exercises: [TemplateExerciseResponse]?  // ← Check this matches backend
    ...
}
```

### Fix 4: Backend Error

**Symptom:** Status code 500 or 400

**Solution:** Check backend logs, may be a backend bug

### Fix 5: Network Timeout

**Symptom:** Intermittent failures, especially on slow network

**Solution:** Increase timeout in `URLSessionNetworkClient`
```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30 // Increase from default 60
configuration.timeoutIntervalForResource = 300
```

---

## 🔬 Advanced Debugging

### Enable Network Traffic Logging

Add to `URLSessionNetworkClient`:
```swift
configuration.urlCache = nil
configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

// Add logging
let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

// Implement URLSessionTaskDelegate
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error {
        print("URLSession Error: \(error)")
    }
}
```

### Capture Full Response

Temporarily log entire response:
```swift
if let responseString = String(data: data, encoding: .utf8) {
    print("FULL RESPONSE: \(responseString)")
}
```

### Test with Charles Proxy

1. Install Charles Proxy
2. Configure iOS device to use proxy
3. Trust Charles SSL certificate
4. Watch actual HTTP traffic

---

## 📊 Expected Behavior

### Successful Sync

```
SyncWorkoutTemplatesUseCase: Starting template sync from backend...
SyncWorkoutTemplatesUseCase: Step 1 - Fetching template list...
SyncWorkoutTemplatesUseCase: Fetching batch - offset: 0, limit: 100
WorkoutTemplateAPIClient: ✅ Fetched 100 public templates
SyncWorkoutTemplatesUseCase: Fetching batch - offset: 100, limit: 100
WorkoutTemplateAPIClient: ✅ Fetched 100 public templates
...
SyncWorkoutTemplatesUseCase: Step 2 - Fetching exercises for each template...
SyncWorkoutTemplatesUseCase: [1/840] Fetching exercises for 'Full Body Blast'
WorkoutTemplateAPIClient: Fetching template <UUID>
WorkoutTemplateAPIClient: Received response with status code: 200
WorkoutTemplateAPIClient: ✅ Fetched template 'Full Body Blast' with 12 exercises
...
SyncWorkoutTemplatesUseCase: ✅ Successfully synced 840 templates
```

### Fallback Behavior

If individual template fetch fails, the use case **gracefully falls back**:
```swift
do {
    let fullTemplate = try await apiClient.fetchTemplate(id: template.id)
    templatesWithExercises.append(fullTemplate)
} catch {
    // Fall back to template without exercises
    templatesWithExercises.append(template)
}
```

This ensures sync completes even if some templates fail.

---

## 🚨 When to Escalate

Contact backend team if:

1. **Status code 500** - Backend crash or bug
2. **Status code 404** - Template IDs from list endpoint don't exist in detail endpoint
3. **Response schema mismatch** - Fields don't match API spec
4. **Rate limiting too aggressive** - Can't fetch 840 templates
5. **Authentication issues** - Token refresh not working

---

## 📋 Checklist

Before reporting a bug, verify:

- [ ] Enabled enhanced logging (updated code)
- [ ] Checked console for status code
- [ ] Inspected response body preview
- [ ] Verified auth token is present
- [ ] Tested with single template ID
- [ ] Checked backend API directly with curl
- [ ] Tried manual logout/login
- [ ] Ruled out network/connectivity issues
- [ ] Checked backend status page
- [ ] Reviewed API spec for changes

---

## 📚 Related Files

- **Use Case:** `FitIQ/Domain/UseCases/Workout/SyncWorkoutTemplatesUseCase.swift`
- **API Client:** `FitIQ/Infrastructure/Network/WorkoutTemplateAPIClient.swift`
- **DTOs:** `FitIQ/Infrastructure/Network/DTOs/WorkoutTemplateDTOs.swift`
- **Error Types:** `FitIQ/Infrastructure/Network/DTOs/StandardBackendResponseDTOs.swift`
- **API Spec:** `docs/be-api-spec/swagger.yaml`

---

## 🎯 Next Steps

1. **Run sync with enhanced logging** - Gather detailed error information
2. **Analyze status code and response** - Identify root cause
3. **Apply appropriate fix** - Based on diagnosis
4. **Test with small batch** - Verify fix works
5. **Run full sync** - Confirm all 840 templates sync successfully

---

**Need Help?** Check the conversation thread for full context and previous fixes.