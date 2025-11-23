# Goals API Contract

**Version:** 1.0.0  
**Last Updated:** 2025-01-17  
**Backend Host:** `fit-iq-backend.fly.dev`

---

## Overview

This document describes the complete API contract for the Goals feature in the Lume iOS app. It includes all endpoints, request/response formats, field requirements, and data types.

---

## Base Configuration

**Base URL:** `https://fit-iq-backend.fly.dev`  
**API Version:** `v1`  
**Authentication:** Bearer token in `Authorization` header

```
Authorization: Bearer {access_token}
```

---

## Endpoints

### 1. Create Goal

**Endpoint:** `POST /api/v1/goals`  
**Authentication:** Required  
**Purpose:** Create a new goal for the authenticated user

#### Request Body

```json
{
  "title": "string (required)",
  "description": "string (required)",
  "start_date": "YYYY-MM-DD (required)",
  "target_date": "YYYY-MM-DD (required)",
  "goal_type": "string (required)",
  "target_value": "number (required, >0)",
  "target_unit": "string (required)"
}
```

**Field Definitions:**

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `title` | String | ✅ Yes | Goal title | "Incorporate More Vegetables" |
| `description` | String | ✅ Yes | Detailed description | "Aim to include at least 5 servings..." |
| `start_date` | String | ✅ Yes | Start date (YYYY-MM-DD) | "2025-11-17" |
| `target_date` | String | ✅ Yes | Target completion date (YYYY-MM-DD) | "2026-01-16" |
| `goal_type` | String | ✅ Yes | Type of goal | "activity", "wellness", "nutrition" |
| `target_value` | Number | ✅ Yes | Numeric target (must be >0) | 1.0 |
| `target_unit` | String | ✅ Yes | Unit of measurement | "completion", "kg", "steps", "servings" |

**Valid Goal Types:**
- `activity` - Physical activity goals
- `wellness` - General wellness goals
- `nutrition` - Diet and nutrition goals
- `sleep` - Sleep-related goals
- `mindfulness` - Mental health goals

**Common Target Units:**
- `completion` - Binary completion (0 or 1)
- `kg` - Kilograms (weight)
- `steps` - Step count
- `minutes` - Time duration
- `servings` - Food servings
- `hours` - Time duration
- `sessions` - Activity sessions

#### Response (201 Created)

```json
{
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "goal_type": "string",
    "title": "string",
    "description": "string",
    "target_value": "number",
    "target_unit": "string",
    "current_value": "number",
    "progress": "number (0-1)",
    "start_date": "YYYY-MM-DD",
    "target_date": "YYYY-MM-DD",
    "status": "string",
    "is_overdue": "boolean",
    "days_remaining": "number",
    "created_at": "ISO8601 timestamp with nanoseconds",
    "updated_at": "ISO8601 timestamp with nanoseconds",
    "is_recurring": "boolean"
  }
}
```

**Example Response:**

```json
{
  "data": {
    "id": "40020d52-dd54-40c2-a8c3-a75c645585f3",
    "user_id": "15d3af32-a0f7-424c-952a-18c372476bfe",
    "goal_type": "activity",
    "title": "Incorporate More Vegetables",
    "description": "Aim to include at least 5 servings of vegetables...",
    "target_value": 1,
    "target_unit": "completion",
    "current_value": 0,
    "progress": 0,
    "start_date": "2025-11-17",
    "target_date": "2026-01-16",
    "status": "active",
    "is_overdue": false,
    "days_remaining": 59,
    "created_at": "2025-11-17T19:26:02.996263011Z",
    "updated_at": "2025-11-17T19:26:02.996263011Z",
    "is_recurring": false
  }
}
```

---

### 2. Update Goal

**Endpoint:** `PUT /api/v1/goals/{goal_id}`  
**Authentication:** Required  
**Purpose:** Update an existing goal

#### Request Body

```json
{
  "title": "string (required)",
  "description": "string (required)",
  "target_date": "YYYY-MM-DD (optional)",
  "progress": "number (0-1, required)",
  "status": "string (required)",
  "goal_type": "string (required)",
  "target_value": "number (required)",
  "target_unit": "string (required)",
  "current_value": "number (required)"
}
```

**Status Values:**
- `active` - Goal is active and in progress
- `completed` - Goal has been completed
- `paused` - Goal is temporarily paused
- `archived` - Goal is archived (no longer active)

#### Response (200 OK)

Same structure as Create Goal response.

---

### 3. Delete Goal

**Endpoint:** `DELETE /api/v1/goals/{goal_id}`  
**Authentication:** Required  
**Purpose:** Delete a goal permanently

#### Response (204 No Content)

No response body.

---

### 4. Fetch All Goals

**Endpoint:** `GET /api/v1/goals`  
**Authentication:** Required  
**Purpose:** Retrieve all goals for the authenticated user

#### Response (200 OK)

```json
{
  "data": {
    "goals": [
      {
        "id": "uuid",
        "user_id": "uuid",
        "goal_type": "string",
        "title": "string",
        "description": "string",
        "target_value": "number",
        "target_unit": "string",
        "current_value": "number",
        "progress": "number",
        "start_date": "YYYY-MM-DD",
        "target_date": "YYYY-MM-DD",
        "status": "string",
        "is_overdue": "boolean",
        "days_remaining": "number",
        "created_at": "ISO8601 timestamp",
        "updated_at": "ISO8601 timestamp",
        "is_recurring": "boolean"
      }
    ],
    "total": "number",
    "has_more": "boolean"
  }
}
```

---

### 5. Get AI Suggestions

**Endpoint:** `POST /api/v1/goals/{goal_id}/suggestions`  
**Authentication:** Required  
**Purpose:** Get AI-powered suggestions for achieving a goal

⚠️ **Important:** `{goal_id}` must be the **backend-assigned ID** (returned in the `id` field from goal creation), NOT the local iOS app UUID.

#### Response (200 OK)

```json
{
  "data": {
    "goal_id": "uuid",
    "suggestions": ["string"],
    "next_steps": ["string"],
    "motivational_message": "string",
    "generated_at": "ISO8601 timestamp"
  }
}
```

---

### 6. Get AI Tips

**Endpoint:** `POST /api/v1/goals/{goal_id}/tips`  
**Authentication:** Required  
**Purpose:** Get AI-powered tips for a goal

⚠️ **Important:** `{goal_id}` must be the **backend-assigned ID** (returned in the `id` field from goal creation), NOT the local iOS app UUID.

#### Response (200 OK)

```json
{
  "data": {
    "goal_id": "uuid",
    "tips": [
      "Start with a quick win by committing to a 10-minute walk after lunch each day this week",
      "Incorporate a 'walking meeting' once a week where you discuss work matters while strolling",
      "Download a step-tracking app and set a daily reminder to check your progress"
    ],
    "count": 3
  }
}
```

**Note:** The backend returns tips as a simple **array of strings**, not objects. The iOS app automatically converts these strings to `GoalTip` domain objects with inferred categories and priorities based on:
- **Priority**: Earlier tips = higher priority (first 2 are high, next 3 are medium, rest are low)
- **Category**: Inferred from tip content keywords (exercise, nutrition, sleep, mindset, habit)

---

### 7. Get Progress Analysis

**Endpoint:** `POST /api/v1/goals/{goal_id}/analysis`  
**Authentication:** Required  
**Purpose:** Get AI-powered progress analysis

⚠️ **Important:** `{goal_id}` must be the **backend-assigned ID** (returned in the `id` field from goal creation), NOT the local iOS app UUID.

#### Response (200 OK)

```json
{
  "data": {
    "goal_id": "uuid",
    "current_progress": "number",
    "projected_completion": "ISO8601 timestamp",
    "analysis": "string",
    "recommendations": ["string"],
    "strengths": ["string"],
    "challenges": ["string"],
    "generated_at": "ISO8601 timestamp"
  }
}
```

---

## Backend ID vs Local ID

### Understanding the Two IDs

The Lume iOS app uses two different IDs for goals:

1. **Local UUID** - Generated by the iOS app when a goal is created locally
   - Used for SwiftData persistence (`SDGoal.id`)
   - Used for local operations and UI state
   - Example: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

2. **Backend ID** - Assigned by the backend when the goal is synced
   - Returned in the `id` field of the API response
   - Stored in `SDGoal.backendId` field
   - Used for all backend API calls
   - Example: `40020d52-dd54-40c2-a8c3-a75c645585f3`

### When to Use Which ID

| Operation | ID Type | Field Name |
|-----------|---------|------------|
| SwiftData queries | Local UUID | `SDGoal.id` |
| Domain model | Local UUID | `Goal.id` |
| Goal creation API | N/A | Backend assigns ID |
| Goal update API | Backend ID | `SDGoal.backendId` |
| Goal deletion API | Backend ID | `SDGoal.backendId` |
| Suggestions API | Backend ID | `SDGoal.backendId` |
| Tips API | Backend ID | `SDGoal.backendId` |
| Analysis API | Backend ID | `SDGoal.backendId` |

### Outbox Pattern Sync Flow

1. User creates a goal → Local UUID assigned
2. Goal saved to SwiftData with `backendId = nil`
3. Outbox event created for sync
4. `OutboxProcessorService` calls backend API
5. Backend returns goal with backend-assigned ID
6. Local goal updated: `backendId = "<backend-uuid>"`
7. All subsequent API calls use the `backendId`

### Example: Calling AI Tips

```swift
// ❌ WRONG - Using local UUID
let localId = goal.id  // Local UUID from domain model
try await backendService.getAITips(for: localId, accessToken: token)

// ✅ CORRECT - Using backend ID
guard let backendId = sdGoal.backendId else {
    throw GoalError.notSynced  // Goal hasn't been synced yet
}
try await backendService.getAITips(for: backendId, accessToken: token)
```

### Handling Unsynced Goals

If a goal hasn't been synced yet (i.e., `backendId` is `nil`), AI features should:

1. Show a "Syncing..." state in the UI
2. Wait for the outbox processor to sync the goal
3. Retry once `backendId` is available

```swift
func fetchAITips(for goal: Goal) async throws {
    // Fetch the SDGoal from SwiftData
    let sdGoal = try await repository.fetchSDGoal(id: goal.id)
    
    guard let backendId = sdGoal.backendId else {
        // Goal not synced yet
        throw GoalError.notSynced
    }
    
    // Now safe to call backend
    let tips = try await backendService.getAITips(
        for: backendId, 
        accessToken: accessToken
    )
}
```

---

## Date Formats

### Backend Returns

The backend returns dates in **ISO8601 format with nanosecond precision**:

```
2025-11-17T19:26:02.996263011Z
```

**Format:** `YYYY-MM-DDTHH:MM:SS.nnnnnnnnnZ`

**Components:**
- `YYYY-MM-DD` - Date
- `T` - Separator
- `HH:MM:SS` - Time
- `.nnnnnnnnn` - Nanoseconds (9 digits)
- `Z` - UTC timezone

### iOS App Sends

The iOS app sends dates in **YYYY-MM-DD format** for date-only fields:

```
2025-11-17
```

For timestamps, use **ISO8601 with fractional seconds**:

```
2025-11-17T19:26:02.996Z
```

---

## Error Responses

All error responses follow this format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Common Error Codes

| Status | Code | Description |
|--------|------|-------------|
| 400 | `INVALID_REQUEST` | Missing or invalid required fields |
| 400 | `INVALID_TARGET_VALUE` | target_value must be >0 |
| 401 | `UNAUTHORIZED` | Invalid or missing auth token |
| 403 | `FORBIDDEN` | User doesn't have access to this goal |
| 404 | `GOAL_NOT_FOUND` | Goal ID doesn't exist |
| 500 | `INTERNAL_ERROR` | Server error |

---

## iOS Implementation

### Date Handling

The iOS app uses **custom date parsing** to handle nanosecond precision:

```swift
private struct GoalDTO: Decodable {
    let created_at: String  // Parse manually
    let updated_at: String  // Parse manually
    let target_date: String? // Parse manually
    
    func toDomain() -> Goal {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        
        func parseDate(_ dateString: String) -> Date {
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            return Date() // Fallback
        }
        
        // Parse and map to domain model
    }
}
```

### Required Field Validation

Before sending to backend:

```swift
// Must be provided by user
title: String (non-empty)
description: String

// Generated by app
start_date: Date (formatted as YYYY-MM-DD)
target_date: Date (formatted as YYYY-MM-DD)
goal_type: String (default: "activity")
target_value: Double (default: 1.0, must be >0)
target_unit: String (default: "completion")
```

---

## Testing Checklist

### Goal Creation
- [ ] Create goal with all required fields
- [ ] Verify 201 response with complete goal data
- [ ] Verify dates are parsed correctly
- [ ] Verify target_value and target_unit are present
- [ ] Verify current_value starts at 0

### Goal Update
- [ ] Update goal status (active → completed)
- [ ] Update progress value
- [ ] Update current_value
- [ ] Verify dates remain intact

### Goal Deletion
- [ ] Delete goal successfully
- [ ] Verify 204 No Content response
- [ ] Verify goal no longer appears in list

### Error Handling
- [ ] Missing required fields returns 400
- [ ] Invalid target_value (≤0) returns 400
- [ ] Invalid auth token returns 401
- [ ] Non-existent goal ID returns 404

---

## Related Documentation

- [Goal Date Decoding Fix](../fixes/GOAL_DATE_DECODING_FIX.md) - Details on date parsing implementation
- [Goals Feature](../goals/README.md) - Complete goals feature documentation
- [Backend Configuration](../BACKEND_CONFIGURATION.md) - Backend setup guide

---

## Changelog

### 2025-01-17 (v1.0.3)
- Updated tips endpoint response format documentation
- Backend returns tips as array of strings, not objects
- iOS app infers category and priority from tip content

### 2025-01-17 (v1.0.2)
- Corrected API endpoint paths (removed `/ai/` prefix)
- Actual paths: `/suggestions`, `/tips`, `/analysis` (not `/ai/suggestions`, etc.)

### 2025-01-17 (v1.0.1)
- Added "Backend ID vs Local ID" section
- Clarified that AI endpoints require backend-assigned IDs
- Added examples for proper ID usage
- Added guidance for handling unsynced goals

### 2025-01-17 (v1.0.0)
- Initial documentation
- Documented date format with nanosecond precision
- Added all CRUD endpoints
- Added AI endpoints (suggestions, tips, analysis)
- Added error response formats
- Added iOS implementation notes

---

## Contact

For backend API questions or issues:
- Check backend logs at `fit-iq-backend.fly.dev`
- Review Swagger documentation (if available)
- Contact backend team for API changes