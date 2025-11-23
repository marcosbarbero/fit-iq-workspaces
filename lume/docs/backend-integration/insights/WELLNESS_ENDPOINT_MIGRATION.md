# Wellness Endpoint Migration

**Created:** 2025-01-30  
**Status:** ✅ COMPLETE  
**Purpose:** Document migration from generic `/generate` to wellness-specific `/generate/wellness` endpoint

---

## Overview

The backend team has implemented a dedicated wellness insights endpoint to replace the generic generation endpoint. This provides better context-aware insights tailored specifically for wellness use cases.

---

## What Changed

### Old Endpoint (Generic)
```
POST /api/v1/insights/generate
```

**Purpose:** Generic insight generation for all use cases (fitness, wellness, nutrition, etc.)

**Issues:**
- Too broad for wellness-specific needs
- Mixed context from different domains
- Less accurate wellness recommendations

### New Endpoint (Wellness-Specific) ✅ RECOMMENDED
```
POST /api/v1/insights/generate/wellness
```

**Purpose:** Dedicated wellness insight generation optimized for mood, journaling, and goal tracking

**Benefits:**
- ✅ Context-aware wellness insights
- ✅ Better recommendations for mental health
- ✅ Optimized for mood patterns and journaling
- ✅ Improved AI prompting for wellness domain

---

## API Contract

Both endpoints share the same request/response structure, making migration seamless.

### Request Body (Identical)

```json
{
  "insight_type": "daily",
  "period_start": "2025-01-30T00:00:00Z",  // Optional - auto-calculated if omitted
  "period_end": "2025-01-30T23:59:59Z"     // Optional - auto-calculated if omitted
}
```

**Insight Types:**
- `daily` - Daily wellness summary
- `weekly` - Weekly wellness trends
- `monthly` - Monthly wellness overview
- `pattern` - Custom period pattern analysis
- `milestone` - Achievement and milestone celebration

### Response Format (Identical)

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "550e8400-e29b-41d4-a716-446655440001",
    "insight_type": "daily",
    "title": "Great Progress Today!",
    "summary": "You've been consistently tracking your mood and reflecting on your experiences.",
    "content": "Today was a solid day for your wellness journey...",
    "period_start": "2025-01-30T00:00:00Z",
    "period_end": "2025-01-30T23:59:59Z",
    "metrics": {
      "mood_entries_count": 2,
      "journal_entries_count": 1,
      "goals_active": 3,
      "goals_completed": 0
    },
    "suggestions": [
      "Try morning journaling to start your day with intention",
      "Consider setting a small goal for better sleep"
    ],
    "is_read": false,
    "is_favorite": false,
    "is_archived": false,
    "created_at": "2025-01-30T08:00:00Z",
    "updated_at": "2025-01-30T08:00:00Z"
  }
}
```

---

## iOS Implementation Changes

### Files Modified

#### 1. `AIInsightBackendService.swift`

**Before:**
```swift
let response: GenerateInsightResponse = try await httpClient.post(
    path: "/api/v1/insights/generate",
    body: requestBody,
    accessToken: accessToken
)
```

**After:**
```swift
let response: GenerateInsightResponse = try await httpClient.post(
    path: "/api/v1/insights/generate/wellness",
    body: requestBody,
    accessToken: accessToken
)
```

**Protocol Documentation Updated:**
```swift
/// Generate a new wellness-specific insight
/// Uses the `/api/v1/insights/generate/wellness` endpoint (recommended for wellness use cases)
/// - Parameters:
///   - insightType: Type of insight to generate (daily, weekly, monthly, milestone, pattern)
///   - periodStart: Optional custom period start date (ISO 8601 with timezone). If omitted, backend calculates automatically.
///   - periodEnd: Optional custom period end date (ISO 8601 with timezone). If omitted, backend calculates automatically.
///   - accessToken: User's access token
/// - Returns: Newly generated AIInsight with wellness-specific content
/// - Throws: HTTPError if request fails
func generateInsight(
    insightType: InsightType,
    periodStart: Date?,
    periodEnd: Date?,
    accessToken: String
) async throws -> AIInsight
```

---

## Migration Impact

### Breaking Changes
**None** - The endpoints are API-compatible.

### Behavioral Changes
- ✅ Insights now optimized for wellness context
- ✅ Better recommendations for mood and journaling
- ✅ Improved pattern recognition for wellness goals

### Testing Required
- ✅ Generate daily wellness insight
- ✅ Generate weekly wellness insight
- ✅ Generate custom period insight
- ✅ Verify insight quality and relevance
- ✅ Confirm suggestions are wellness-focused

---

## Backwards Compatibility

### Generic Endpoint Status
The generic `/api/v1/insights/generate` endpoint remains available but is **NOT recommended** for wellness use cases.

**Use Cases for Generic Endpoint:**
- Fitness-specific insights (if app expands to fitness)
- Nutrition-specific insights (if app expands to nutrition)
- Cross-domain insights (if combining multiple health domains)

**For Lume (Wellness App):**
Always use `/api/v1/insights/generate/wellness` ✅

---

## Verification Checklist

### Backend
- ✅ `/api/v1/insights/generate/wellness` endpoint available
- ✅ Swagger documentation updated (v0.37.0)
- ✅ Wellness-specific AI prompting implemented
- ✅ Mood, journal, and goal context properly utilized

### iOS App
- ✅ Endpoint URL updated in `AIInsightBackendService`
- ✅ Protocol documentation updated
- ✅ Logging messages updated for clarity
- ✅ No changes required to request/response models
- ✅ Existing tests remain valid

### Testing
- ✅ Daily insight generation works
- ✅ Weekly insight generation works
- ✅ Insights contain wellness-specific content
- ✅ Suggestions are relevant to mood/journal/goals
- ✅ No regressions in existing functionality

---

## Examples

### Daily Wellness Insight

**Request:**
```json
{
  "insight_type": "daily"
}
```

**Response (wellness-optimized):**
```json
{
  "data": {
    "title": "Steady Progress in Your Wellness Journey",
    "summary": "You logged 2 moods and reflected in your journal today.",
    "content": "Today shows consistent engagement with your wellness practices. Your mood tracking reveals a positive trend, and your journal entry demonstrates thoughtful self-reflection. Keep building on these healthy habits.",
    "suggestions": [
      "Consider adding a morning gratitude practice",
      "Your evening mood entries show consistency - great work!"
    ]
  }
}
```

### Weekly Wellness Pattern

**Request:**
```json
{
  "insight_type": "weekly"
}
```

**Response (wellness-optimized):**
```json
{
  "data": {
    "title": "Your Week in Wellness",
    "summary": "You've shown strong commitment with 14 mood entries and 5 journal reflections this week.",
    "content": "This week highlights your dedication to self-awareness. Your mood patterns suggest better emotional regulation on days when you journal. Consider making journaling a daily practice to maintain this positive momentum.",
    "suggestions": [
      "Your Tuesday and Thursday entries show the most depth - what made those days special?",
      "Try journaling before bed to process the day's emotions"
    ]
  }
}
```

---

## Related Documentation

- [Swagger Specification](../swagger-insights.yaml) - Official API documentation (v0.37.0)
- [API Contract](../INSIGHTS_API_CONTRACT.md) - Complete API reference
- [Backend Integration Status](../BACKEND_INTEGRATION_STATUS.md) - Overall integration status

---

## Version History

- **2025-01-30** - Initial migration from `/generate` to `/generate/wellness`
- **2025-01-30** - Updated protocol documentation and logging
- **2025-01-30** - Verified wellness-specific content quality

---

**Status:** ✅ **MIGRATION COMPLETE**  
**Endpoint:** `/api/v1/insights/generate/wellness`  
**Swagger Version:** 0.37.0  
**iOS Status:** ✅ Updated and verified  
**Production Ready:** 🎉 YES