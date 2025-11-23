# Troubleshooting: Workout Template Sync Errors

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Issue:** "The data couldn't be read because it is missing"

---

## Error Description

```
WorkoutViewModel: ❌ Template sync failed: The data couldn't be read because it is missing.
```

This error occurs during workout template synchronization from the backend API.

---

## Root Cause

This is a **data decoding error** that occurs when:

1. The backend API response structure doesn't match the expected DTO structure
2. A required field is missing from the API response
3. A field has a different type than expected
4. The API response format has changed

---

## Investigation Steps

### Step 1: Enable Detailed Logging

The app already has detailed logging. Check the console for:

```
WorkoutTemplateAPIClient: Fetching public templates...
WorkoutTemplateAPIClient: Raw API response:
  - Total templates in response: X
  - Template 1: 'Name'
    - exercises field: present/nil
    - exercises count: X
    - exerciseCount field: X
```

### Step 2: Check API Response Format

The expected response format is:

```json
{
  "success": true,
  "data": {
    "templates": [
      {
        "id": "uuid",
        "user_id": "uuid" or null,
        "name": "Template Name",
        "description": "Description",
        "category": "strength",
        "difficulty_level": "beginner",
        "estimated_duration_minutes": 60,
        "is_public": true,
        "is_system": true,
        "status": "published",
        "exercise_count": 5,
        "exercises": [
          {
            "id": "uuid",
            "template_id": "uuid",
            "exercise_id": "uuid",
            "user_exercise_id": null,
            "exercise_name": "Bench Press",
            "order_index": 0,
            "technique": "standard",
            "technique_details": {},
            "sets": 3,
            "reps": 10,
            "weight_kg": 50.0,
            "duration_seconds": null,
            "rest_seconds": 60,
            "rir": 2,
            "tempo": null,
            "notes": null,
            "created_at": "2025-01-27T12:00:00Z",
            "backend_id": "uuid"
          }
        ],
        "created_at": "2025-01-27T12:00:00Z",
        "updated_at": "2025-01-27T12:00:00Z"
      }
    ],
    "total": 10
  },
  "error": null
}
```

### Step 3: Identify Missing/Mismatched Fields

Common issues:

**Issue 1: `exercises` field is `null` instead of empty array**
- **Symptom:** Decoding fails when `exercises` is null
- **Solution:** Make `exercises` optional in DTO: `let exercises: [TemplateExerciseResponse]?`
- **Status:** ✅ Already implemented

**Issue 2: Field name mismatch**
- **Symptom:** Snake_case vs camelCase mismatch
- **Solution:** Check `CodingKeys` enum matches backend exactly
- **Status:** ✅ Already implemented with `.convertToSnakeCase`

**Issue 3: Date format mismatch**
- **Symptom:** Date fields can't be parsed
- **Solution:** Ensure using `.iso8601` date decoding strategy
- **Status:** ✅ Already implemented

**Issue 4: Missing required field**
- **Symptom:** Backend doesn't send a field marked as non-optional
- **Solution:** Make field optional in DTO: `let field: Type?`

---

## Quick Fixes

### Fix 1: Make All Optional Fields Truly Optional

Check `WorkoutTemplateResponse` DTO in `Infrastructure/Network/DTOs/WorkoutTemplateDTOs.swift`:

```swift
public struct WorkoutTemplateResponse: Codable {
    let id: String
    let userId: String?                      // ✅ Optional
    let name: String
    let description: String?                 // ✅ Optional
    let category: String?                    // ✅ Optional
    let difficultyLevel: String?             // ✅ Optional
    let estimatedDurationMinutes: Int?       // ✅ Optional
    let isPublic: Bool
    let isSystem: Bool?                      // ✅ Optional
    let status: String?                      // ✅ Optional
    let exerciseCount: Int?                  // ✅ Optional
    let exercises: [TemplateExerciseResponse]? // ✅ Optional
    let createdAt: String
    let updatedAt: String
}
```

### Fix 2: Add Fallback Decoding

If a field is causing issues, provide a default value:

```swift
struct WorkoutTemplateResponse: Codable {
    // ... other fields ...
    let exercises: [TemplateExerciseResponse]?
    
    // Custom decoder with fallback
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode with fallback
        exercises = try? container.decodeIfPresent([TemplateExerciseResponse].self, forKey: .exercises)
        // ... decode other fields normally ...
    }
}
```

### Fix 3: Verify Backend API Version

Check that the backend is running the expected version:

```bash
# Check backend health endpoint
curl -X GET https://fit-iq-backend.fly.dev/health

# Check API version
curl -X GET https://fit-iq-backend.fly.dev/api/v1/version
```

---

## Testing the Fix

### Test 1: Test API Response Manually

```bash
# Test public templates endpoint
curl -X GET "https://fit-iq-backend.fly.dev/api/v1/workout-templates/public?limit=1&offset=0" \
  -H "X-API-Key: YOUR_API_KEY" \
  | jq '.'
```

Save the response and verify:
- All fields match the DTO structure
- No fields are unexpectedly null
- Array fields are arrays (not null)
- Date fields are ISO8601 format

### Test 2: Test Decoding in Playground

Create a Swift Playground to test decoding:

```swift
import Foundation

// Copy the exact JSON response from the API
let jsonString = """
{
  "success": true,
  "data": {
    "templates": [ /* paste response here */ ],
    "total": 1
  }
}
"""

let jsonData = jsonString.data(using: .utf8)!
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
decoder.keyDecodingStrategy = .convertFromSnakeCase

do {
    let response = try decoder.decode(StandardResponse<PublicTemplatesResponse>.self, from: jsonData)
    print("✅ Decoding successful")
} catch {
    print("❌ Decoding failed: \(error)")
}
```

### Test 3: Test in App with Breakpoint

1. Set breakpoint in `WorkoutTemplateAPIClient.fetchPublicTemplates` after receiving data
2. Inspect the raw `data` object
3. Print the JSON string:
   ```swift
   if let jsonString = String(data: data, encoding: .utf8) {
       print(jsonString)
   }
   ```
4. Copy the JSON and test in Playground

---

## Workarounds

### Workaround 1: Disable Template Sync Temporarily

In `WorkoutViewModel`:

```swift
func syncWorkoutTemplates() async {
    print("WorkoutViewModel: ⚠️ Template sync temporarily disabled")
    return
}
```

### Workaround 2: Use Mock Data

```swift
func syncWorkoutTemplates() async {
    print("WorkoutViewModel: Using mock templates")
    _realWorkoutTemplates = [
        // Add mock templates here
    ]
    _allWorkoutTemplates = _realWorkoutTemplates.map { /* convert */ }
}
```

### Workaround 3: Skip Failed Templates

Modify sync to continue on individual template failures:

```swift
// In SyncWorkoutTemplatesUseCase
for template in batch {
    do {
        try await repository.save(template: template)
    } catch {
        print("⚠️ Failed to save template \(template.id): \(error)")
        // Continue with next template
    }
}
```

---

## Common Scenarios

### Scenario 1: Backend Not Running

**Error:** Network error or timeout  
**Solution:** Verify backend is accessible:
```bash
curl https://fit-iq-backend.fly.dev/health
```

### Scenario 2: API Key Missing/Invalid

**Error:** 401 Unauthorized  
**Solution:** Check `config.plist` has valid `API_KEY`

### Scenario 3: New Field Added to Backend

**Error:** Decoding fails with "No value associated with key"  
**Solution:** Add field to DTO as optional:
```swift
let newField: String?  // ✅ Optional for backward compatibility
```

### Scenario 4: Field Type Changed

**Error:** "Expected to decode String but found Int"  
**Solution:** Update DTO to match backend type or add custom decoder

---

## Prevention

### For Future API Changes

1. **Make all optional fields truly optional in DTOs**
2. **Use `.decodeIfPresent()` for non-critical fields**
3. **Add unit tests for DTO decoding**
4. **Version the API and DTOs together**
5. **Document breaking changes in API spec**

### Testing Checklist

Before deploying API changes:

- [ ] Test with empty response
- [ ] Test with null fields
- [ ] Test with missing optional fields
- [ ] Test with extra fields (should be ignored)
- [ ] Test with old API version
- [ ] Test with new API version

---

## Contact Backend Team

If the issue persists, contact backend team with:

1. **Exact error message**
2. **API endpoint being called**
3. **Request parameters**
4. **Expected response format**
5. **Actual response (if available)**
6. **API version/commit hash**

---

## Resolution

Once identified, update:

1. **DTO structure** in `Infrastructure/Network/DTOs/WorkoutTemplateDTOs.swift`
2. **Decoding strategy** if needed
3. **This document** with the solution
4. **Add test case** to prevent regression

---

## Related Files

- `Infrastructure/Network/WorkoutTemplateAPIClient.swift` - API client
- `Infrastructure/Network/DTOs/WorkoutTemplateDTOs.swift` - Response DTOs
- `Domain/UseCases/Workout/SyncWorkoutTemplatesUseCase.swift` - Sync logic
- `Presentation/ViewModels/WorkoutViewModel.swift` - Sync caller
- `docs/be-api-spec/swagger.yaml` - API specification

---

## Status

**Current Status:** ✅ RESOLVED  
**Workaround Available:** ✅ Yes (disable sync temporarily)  
**Permanent Fix:** ✅ Applied

---

## Resolution Details

**Date Fixed:** 2025-01-27

**Root Cause:**
The backend API response structure didn't match the iOS DTO expectations:

1. **Missing Field:** Backend doesn't return `exercise_name` in template exercises
2. **Type Mismatch:** `technique_details` returns integers/numbers, not strings

**Changes Applied:**

1. **Removed `exerciseName` from `TemplateExerciseResponse` DTO**
   - Field doesn't exist in backend response
   - Using placeholder "Exercise" in domain conversion
   - TODO: Fetch actual exercise names using `exercise_id` lookup

2. **Changed `techniqueDetails` type from `[String: String]?` to `[String: AnyCodable]?`**
   - Backend returns mixed types (integers, strings, booleans)
   - Added `AnyCodable` helper struct to handle any JSON type
   - Convert to string dictionary in `toDomain()` method

3. **Fixed `toDomain()` conversion**
   - Convert `AnyCodable` values to strings
   - Handle missing `exerciseName` with placeholder
   - Properly initialize all required fields

**Files Modified:**
- `Infrastructure/Network/DTOs/WorkoutTemplateDTOs.swift`
  - Updated `TemplateExerciseResponse` struct
  - Added `AnyCodable` helper
  - Fixed `toDomain()` conversion logic

**Testing:**
- ✅ Code compiles without errors
- ✅ Matches actual backend response format
- ⚠️ Exercise names show as "Exercise" placeholder

**Known Limitation:**
Exercise names are not available in template exercise responses. Options:
1. Backend team adds `exercise_name` field to response
2. iOS app fetches exercise details separately using `exercise_id`
3. Keep placeholder "Exercise" for now

**Recommendation:**
Contact backend team to add `exercise_name` field to template exercise responses for better UX.

---

**Last Updated:** 2025-01-27 (Resolution Applied)  
**Created By:** AI Assistant  
**Fixed By:** AI Assistant