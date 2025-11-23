# Swagger Documentation Update - Generate Insight Endpoint

**Date:** January 30, 2025  
**Status:** ✅ **COMPLETE AND VALIDATED**  
**File:** `docs/swagger-insights.yaml`  
**Version Updated:** 0.34.0 → 0.35.0

---

## 🎯 What Was Updated

The `swagger-insights.yaml` file has been updated to include the new **`POST /api/v1/insights/generate`** endpoint.

---

## 📝 Changes Made

### 1. **Version Bump** ✅
- **Old:** `version: 0.34.0`
- **New:** `version: 0.35.0`

### 2. **New Endpoint Added** ✅
- **Path:** `/api/v1/insights/generate`
- **Method:** `POST`
- **Operation ID:** `generateInsight`
- **Authentication:** API Key + JWT required

### 3. **Request Body Schema** ✅
```yaml
{
  "insight_type": "daily|weekly|milestone|pattern",  # Required
  "period_start": "2025-01-30T00:00:00Z",            # Optional
  "period_end": "2025-01-30T23:59:59Z"               # Optional
}
```

### 4. **Response Schema** ✅
- **201 Created:** Returns generated `Insight` object
- **400 Bad Request:** Invalid insight type or request body
- **401 Unauthorized:** Missing/invalid authentication
- **500 Internal Server Error:** Generation failure

### 5. **Examples Included** ✅
- **DailyInsight:** Generate daily insight with auto period
- **WeeklyInsight:** Generate weekly insight with auto period
- **CustomPeriod:** Generate insight with custom date range
- **DailyInsightGenerated:** Full response example with all fields

---

## 📋 Endpoint Documentation

### Request Examples

**Daily Insight (Auto Period):**
```json
{
  "insight_type": "daily"
}
```

**Weekly Insight (Auto Period):**
```json
{
  "insight_type": "weekly"
}
```

**Custom Period:**
```json
{
  "insight_type": "pattern",
  "period_start": "2025-01-15T00:00:00Z",
  "period_end": "2025-01-30T23:59:59Z"
}
```

### Response Example

**201 Created:**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "insight_type": "daily",
    "title": "Great Progress Today!",
    "summary": "You logged 3 meals and completed a workout - excellent consistency!",
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
      "Try adding a vegetable to your next meal",
      "Aim for 8 hours of sleep tonight",
      "Log your mood in the evening to track patterns"
    ],
    "is_read": false,
    "is_favorite": false,
    "is_archived": false,
    "created_at": "2025-01-30T18:45:00Z",
    "updated_at": "2025-01-30T18:45:00Z"
  },
  "error": null
}
```

---

## ✅ Validation

```bash
npx @apidevtools/swagger-cli validate docs/swagger-insights.yaml
# ✅ docs/swagger-insights.yaml is valid
```

**Status:** OpenAPI 3.0.3 compliant ✅

---

## 🔄 Complete Endpoint List (Updated)

The Insights API now has **8 endpoints** (previously 7):

1. ✅ `GET /api/v1/insights` - List insights with filters
2. ✅ `GET /api/v1/insights/unread/count` - Count unread insights
3. ✅ **`POST /api/v1/insights/generate`** - **NEW: Generate insight**
4. ✅ `POST /api/v1/insights/{id}/read` - Mark as read
5. ✅ `POST /api/v1/insights/{id}/favorite` - Toggle favorite
6. ✅ `POST /api/v1/insights/{id}/archive` - Archive insight
7. ✅ `POST /api/v1/insights/{id}/unarchive` - Unarchive insight
8. ✅ `DELETE /api/v1/insights/{id}` - Delete insight

---

## 📊 Insight Types Documented

All four insight types are documented with auto-period behavior:

| Type | Description | Auto Period |
|------|-------------|-------------|
| `daily` | Today's summary | Today 00:00-23:59 UTC |
| `weekly` | Last 7 days analysis | Last 7 days |
| `milestone` | Achievement celebration | Last 30 days |
| `pattern` | Correlation discovery | Last 14 days |

---

## 🔐 Security

- **API Key:** Required via `X-API-Key` header
- **JWT Token:** Required via `Authorization: Bearer {token}` header
- **User Isolation:** Insights generated only for authenticated user
- **Encryption:** All sensitive fields automatically encrypted at rest

---

## 📝 Key Features Documented

1. **Auto Period Calculation:** If `period_start` and `period_end` are omitted, calculated based on `insight_type`
2. **Custom Periods:** Support for user-defined date ranges
3. **Deduplication:** System checks for existing insights before generating new ones
4. **AI-Powered:** Uses OpenAI (gpt-4o-mini) for generation
5. **Encrypted Storage:** Title, content, summary, suggestions encrypted at rest
6. **User Context:** Leverages mood, journal, goals, nutrition, and workout data

---

## 🎨 OpenAPI Features Used

- ✅ Request body schema with required fields
- ✅ Multiple request examples
- ✅ Detailed response schemas
- ✅ Response examples with full data
- ✅ Enum validation for insight types
- ✅ ISO 8601 date-time format
- ✅ Reference to shared schemas (`#/components/schemas/Insight`)
- ✅ Reference to shared responses (`#/components/responses/*`)
- ✅ Inline descriptions with markdown

---

## 📚 Related Files

- **Implementation:** `internal/application/insight/generate_insight_use_case.go`
- **Handler:** `internal/interfaces/rest/insight_handlers.go`
- **Router:** `internal/interfaces/rest/router.go`
- **Main:** `cmd/server/main.go`
- **Documentation:** `docs/ai-features-wellness/GENERATE_INSIGHT_ENDPOINT.md`

---

## 🚀 Deployment Notes

### For API Consumers (iOS/Frontend)

1. **New endpoint available:** `POST /api/v1/insights/generate`
2. **Breaking changes:** None - fully backward compatible
3. **New fields:** All optional `period_start` and `period_end`
4. **Response format:** Standard `Insight` object (same as list endpoint)

### Integration Example (Swift)

```swift
struct GenerateInsightRequest: Codable {
    let insightType: String // "daily", "weekly", "milestone", "pattern"
    let periodStart: Date?
    let periodEnd: Date?
    
    enum CodingKeys: String, CodingKey {
        case insightType = "insight_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

// Generate daily insight with auto period
let request = GenerateInsightRequest(
    insightType: "daily",
    periodStart: nil,
    periodEnd: nil
)

POST /api/v1/insights/generate
```

---

## ✅ Summary

- **File:** `docs/swagger-insights.yaml`
- **Lines Added:** ~115 lines
- **Version:** 0.35.0
- **Validation:** ✅ Valid OpenAPI 3.0.3
- **Endpoints:** 7 → 8
- **Breaking Changes:** None
- **Ready for:** Production deployment

The Swagger documentation now fully reflects the complete Insights API functionality, including the new manual generation endpoint. 🎉
