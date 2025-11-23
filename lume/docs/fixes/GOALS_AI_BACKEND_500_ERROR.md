# Goals AI Backend 500 Error - Debugging Guide

**Issue:** Backend returning 500 Internal Server Error on POST `/api/v1/goals/suggestions`

**Date:** 2025-01-28

---

## Problem Summary

When the iOS app calls the Goals AI suggestions endpoint, the backend returns a 500 error:

```
=== HTTP Request ===
URL: https://fit-iq-backend.fly.dev/api/v1/goals/suggestions
Method: POST
Status: 500
```

---

## Expected Behavior (per Swagger spec)

**Endpoint:** `POST /api/v1/goals/suggestions`

**Request:**
- Method: POST
- Headers:
  - `X-API-Key`: API key for client authentication
  - `Authorization: Bearer <JWT>`: User authentication token
  - `Content-Type: application/json`
- Body: **NONE** (backend should use authenticated user's existing data)

**Expected Response (200):**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "title": "Morning Meditation Practice",
        "description": "Start each day with 10 minutes of mindfulness...",
        "goal_type": "meditation",
        "target_value": 10,
        "target_unit": "minutes",
        "rationale": "Based on your recent mood patterns...",
        "estimated_duration": 30,
        "difficulty": 1
      }
    ],
    "count": 3
  }
}
```

---

## iOS Client Implementation (Correct)

The iOS app is correctly:
1. ✅ Using POST method
2. ✅ Sending X-API-Key header
3. ✅ Sending Authorization Bearer token
4. ✅ Not sending a request body (as per spec)
5. ✅ Setting Content-Type: application/json

**Code snippet:**
```swift
// GoalAIService.swift line 35
let response: GoalSuggestionsResponse = try await httpClient.post(
    path: "/api/v1/goals/suggestions",
    accessToken: token
)
```

---

## Possible Backend Issues

### 1. **User Data Not Found**
- Backend may be unable to fetch user's mood, journal, or goal data
- Check if user has sufficient data for AI analysis
- Verify database queries are working

### 2. **AI Service Integration Issue**
- Backend AI service may be unreachable
- API keys for AI provider may be invalid/expired
- Rate limits may be exceeded

### 3. **Database Connection**
- Database may be down or connection pool exhausted
- Queries may be timing out

### 4. **Missing Environment Variables**
- AI API keys not configured
- Database connection strings missing

### 5. **Request Parsing Error**
- Backend may be expecting a request body (incorrect per spec)
- Content-Type header handling issue

---

## Backend Debugging Steps

### Step 1: Check Backend Logs
Look for:
- Stack traces showing the exact error
- Database connection errors
- AI service API errors
- Authentication/authorization failures

### Step 2: Verify User Data
```sql
-- Check if authenticated user has data
SELECT COUNT(*) FROM mood_entries WHERE user_id = '<user_id>';
SELECT COUNT(*) FROM journal_entries WHERE user_id = '<user_id>';
SELECT COUNT(*) FROM goals WHERE user_id = '<user_id>';
```

### Step 3: Test Endpoint Manually
```bash
curl -X POST \
  https://fit-iq-backend.fly.dev/api/v1/goals/suggestions \
  -H "X-API-Key: <api-key>" \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json"
```

### Step 4: Check AI Service
- Verify AI service credentials are valid
- Test AI service independently
- Check rate limits and quotas

### Step 5: Review Recent Backend Changes
- Were there recent deployments?
- Did database migrations complete successfully?
- Were environment variables updated?

---

## Quick Fixes to Try

### Backend Side

1. **Add comprehensive error logging:**
```python
try:
    suggestions = generate_suggestions(user_id)
    return {"success": True, "data": suggestions}
except Exception as e:
    logger.error(f"Failed to generate suggestions: {str(e)}", exc_info=True)
    return {"success": False, "error": {"code": "GENERATION_FAILED", "message": str(e)}}
```

2. **Return meaningful errors instead of 500:**
```python
if not user_has_sufficient_data(user_id):
    return 400, {"success": False, "error": {"code": "INSUFFICIENT_DATA", "message": "Not enough user data to generate suggestions"}}
```

3. **Add health check endpoint:**
```python
@app.get("/api/v1/goals/health")
def goals_health_check():
    return {
        "ai_service": check_ai_service(),
        "database": check_database(),
        "status": "ok"
    }
```

### iOS Side (Temporary Workaround)

While backend is being fixed, use mock data:
```swift
// In AppDependencies.swift
lazy var goalAIService: GoalAIServiceProtocol = {
    InMemoryGoalAIService() // Use mock instead of real service
}()
```

---

## Response Format Requirements

The backend MUST return this structure:

```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "title": "string (max 200 chars)",
        "description": "string (100-200 words)",
        "goal_type": "enum: [meditation, exercise, nutrition, sleep, hydration]",
        "target_value": "number (float, min 0)",
        "target_unit": "string (max 50 chars)",
        "rationale": "string (50-100 words)",
        "estimated_duration": "integer (days, min 1)",
        "difficulty": "integer (1-5)"
      }
    ],
    "count": "integer"
  }
}
```

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

---

## Next Steps

1. **Backend team:** Check server logs for detailed error information
2. **Backend team:** Add comprehensive error handling and logging
3. **Backend team:** Test endpoint with various user scenarios
4. **iOS team:** Use mock data temporarily until backend is fixed
5. **Both teams:** Set up monitoring/alerting for this endpoint

---

## Contact

- iOS team: Check AppDependencies.swift to switch to mock data
- Backend team: Review `/api/v1/goals/suggestions` handler implementation
- Swagger spec: `docs/swagger-goals-ai.yaml`

---

## Status

- ❌ Backend endpoint returning 500
- ✅ iOS client implementation correct
- ⏳ Awaiting backend fix
- ✅ Mock data available as workaround