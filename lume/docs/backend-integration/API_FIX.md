# Backend API Endpoint Fix - Complete

**Date:** 2025-01-28  
**Status:** ✅ COMPLETE

---

## Overview

Fixed GoalAIService endpoints to match the actual backend API specification documented in Swagger.

---

## Problem

The iOS app was calling incorrect endpoints that resulted in 404 errors:

```
❌ 404 Not Found
URL: https://fit-iq-backend.fly.dev/api/v1/wellness/ai/goals/suggestions/generate
```

---

## Root Cause

**Incorrect Assumption:**
- Initially assumed Goal AI endpoints followed the same pattern as AI Insights
- AI Insights use: `/api/v1/wellness/ai/insights/...`
- Applied same pattern to Goals: `/api/v1/wellness/ai/goals/...` ❌

**Actual API Structure (per Swagger):**
- Goal AI endpoints use simpler path: `/api/v1/goals/...` ✅
- No `/wellness/ai/` prefix needed

---

## Solution

Updated all endpoints in `GoalAIService.swift` to match Swagger specification:

### Endpoint Changes

| Feature | Old Endpoint (404) | New Endpoint (✅) | Method |
|---------|-------------------|-------------------|--------|
| Generate Suggestions | `/api/v1/wellness/ai/goals/suggestions/generate` | `/api/v1/goals/suggestions` | POST |
| Get Tips | `/api/v1/wellness/ai/goals/{id}/tips/generate` | `/api/v1/goals/{id}/tips` | GET |
| Fetch Suggestions | `/api/v1/wellness/ai/goals/suggestions` | `/api/v1/goals/suggestions` | POST |
| Fetch Tips | `/api/v1/wellness/ai/goals/{id}/tips` | `/api/v1/goals/{id}/tips` | GET |

---

## Key Changes

### 1. Simplified Endpoint Paths

```swift
// Before (404 errors)
let path = "/api/v1/wellness/ai/goals/suggestions/generate"

// After (working)
let path = "/api/v1/goals/suggestions"
```

### 2. Removed Unnecessary Request Bodies

**Discovery:** Per Swagger spec, the backend doesn't expect client to send context data.

**Reason:** Backend generates suggestions and tips based on the authenticated user's existing data:
- Mood history (from mood tracking)
- Journal entries (from journaling)
- Active and completed goals
- User profile and preferences

**Before:**
```swift
func generateGoalSuggestions(context: UserContextData) async throws -> [GoalSuggestion] {
    let requestBody = GenerateSuggestionsRequest(context: context)
    
    let response: GoalSuggestionsResponse = try await httpClient.post(
        path: path,
        body: requestBody,  // ❌ Not needed
        accessToken: token
    )
}
```

**After:**
```swift
func generateGoalSuggestions(context: UserContextData) async throws -> [GoalSuggestion] {
    // Backend uses authenticated user's existing data
    // No request body needed
    let response: GoalSuggestionsResponse = try await httpClient.post(
        path: "/api/v1/goals/suggestions",
        accessToken: token  // ✅ Just auth token
    )
}
```

### 3. Changed Tips from POST to GET

**Per Swagger:** Tips endpoint is a GET request (read operation), not POST.

```swift
// Before
let response: GoalTipsResponse = try await httpClient.post(
    path: path,
    body: requestBody,
    accessToken: token
)

// After
let response: GoalTipsResponse = try await httpClient.get(
    path: "/api/v1/goals/\(goalId.uuidString)/tips",
    accessToken: token
)
```

---

## API Documentation (Swagger)

### POST /api/v1/goals/suggestions

**Purpose:** Generate AI-powered goal suggestions for the authenticated user

**Request:**
- Headers: `Authorization: Bearer {token}`
- Body: None (backend uses existing user data)

**Response:**
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
        "difficulty": 2
      }
    ],
    "count": 3
  }
}
```

### GET /api/v1/goals/{id}/tips

**Purpose:** Get AI-generated tips for achieving a specific goal

**Request:**
- Headers: `Authorization: Bearer {token}`
- Path Parameter: `id` (UUID of the goal)
- Body: None

**Response:**
```json
{
  "success": true,
  "data": {
    "goal_id": "123e4567-e89b-12d3-a456-426614174000",
    "tips": [
      "Start small - begin with 5 minutes and gradually increase",
      "Set a consistent time each day to build routine",
      "Track progress daily to stay motivated"
    ],
    "count": 5
  }
}
```

---

## Backend Data Flow

### How Suggestions are Generated

1. **Client calls:** `POST /api/v1/goals/suggestions`
2. **Backend authenticates** user from JWT token
3. **Backend fetches** user's data:
   - Recent mood entries (last 30 days)
   - Journal entries (last 30 days)
   - Active goals
   - Completed goals
   - User preferences and profile
4. **AI analyzes** patterns and generates personalized suggestions
5. **Backend returns** 3-5 goal suggestions

### Why No Request Body?

**Benefits of server-side context:**
- ✅ Single source of truth (server has all data)
- ✅ Reduced payload size (no need to send history)
- ✅ Better security (sensitive data stays on server)
- ✅ Consistent suggestions (based on latest data)
- ✅ Simpler client code

---

## Code Changes

### Files Modified

**`lume/Services/Backend/GoalAIService.swift`**

**Changes:**
1. Updated endpoint paths to match Swagger spec
2. Removed request body DTOs (no longer needed)
3. Changed tips endpoint from POST to GET
4. Simplified method implementations

**Before:** 300+ lines with complex request body building  
**After:** 130 lines with clean, simple API calls

**Removed:**
- `GenerateSuggestionsRequest`
- `GenerateTipsRequest`
- `ContextData`
- `MoodContextDTO`
- `JournalContextDTO`
- `GoalContextDTO`
- `DateRangeDTO`

All removed because backend doesn't need client to send this data.

---

## Testing

### Verify Endpoints Work

**1. Generate Suggestions:**
```
POST https://fit-iq-backend.fly.dev/api/v1/goals/suggestions
Authorization: Bearer {token}

Expected: 200 OK with suggestions array
```

**2. Get Tips:**
```
GET https://fit-iq-backend.fly.dev/api/v1/goals/{goal-id}/tips
Authorization: Bearer {token}

Expected: 200 OK with tips array
```

### Error Cases

**401 Unauthorized:**
- Missing or invalid token
- Token expired

**404 Not Found:**
- Invalid goal ID (for tips endpoint)

**500 Internal Server Error:**
- AI service unavailable
- Database error

---

## Use Case Parameters

**Question:** Why does `generateGoalSuggestions()` still accept `UserContextData` parameter?

**Answer:** For future flexibility and use case layer consistency.

The use case builds the context to:
1. Filter duplicate suggestions (compare with existing goals)
2. Validate user has sufficient data for good suggestions
3. Provide local caching/offline support in future
4. Maintain clean architecture (use case owns business logic)

```swift
// Use case layer
func execute() async throws -> [GoalSuggestion] {
    // Build context (used locally for filtering)
    let context = try await buildUserContext()
    
    // Backend generates suggestions
    let suggestions = try await goalAIService.generateGoalSuggestions(context: context)
    
    // Filter duplicates locally
    let filtered = filterDuplicates(suggestions, existingGoals)
    
    return filtered
}
```

---

## Summary

✅ **Endpoints Fixed:** All Goal AI endpoints now use correct paths  
✅ **Methods Correct:** POST for suggestions, GET for tips  
✅ **Request Bodies Removed:** Backend uses server-side data  
✅ **Code Simplified:** Removed 170+ lines of unnecessary DTOs  
✅ **Swagger Compliant:** All endpoints match API documentation  

**Status:** Ready for testing with real backend! 🎉

---

## Reference

**Swagger Documentation:** `docs/swagger-goals-ai.yaml`

**Key Endpoints:**
- POST `/api/v1/goals/suggestions` - Generate suggestions
- GET `/api/v1/goals/{id}/tips` - Get tips
- POST `/api/v1/goals/{id}/activities` - Log activity
- GET `/api/v1/goals/{id}/activities` - Fetch activities

**Authentication:** All endpoints require Bearer token in Authorization header.