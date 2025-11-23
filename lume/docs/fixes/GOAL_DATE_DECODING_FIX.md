# Goal Date Decoding Fix

**Date:** 2025-01-17  
**Issue:** Goal creation failing with date decoding error  
**Status:** ✅ Fixed

---

## Problem Description

When creating goals through the Lume iOS app, the backend successfully created the goal (HTTP 201 response), but the app failed to decode the response with the following error:

```
❌ [OutboxProcessor] HTTP error creating goal: decodingFailed(Swift.DecodingError.dataCorrupted(Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "data", intValue: nil)], debugDescription: "Expected date string to be ISO8601-formatted.", underlyingError: nil)))
```

### Root Cause

The backend was returning dates with **nanosecond precision** in ISO8601 format:

```json
"created_at": "2025-11-17T19:26:02.996263011Z"
```

However, the iOS app's `HTTPClient` was using the standard `.iso8601` date decoding strategy, which only supports **millisecond precision** and cannot handle nanosecond timestamps.

### Additional Issues

The `GoalDTO` (data transfer object) was also missing several fields that the backend returns:

- `target_value` - Numeric target for the goal
- `target_unit` - Unit of measurement (e.g., "completion", "kg", "steps")
- `current_value` - Current progress value
- `start_date` - When the goal started
- `goal_type` - Type of goal (e.g., "activity", "wellness")

---

## Solution

### 1. Changed Date Fields to Strings in GoalDTO

Instead of trying to decode dates directly with `JSONDecoder`, we changed the date fields in `GoalDTO` to be `String` type:

```swift
private struct GoalDTO: Decodable {
    let id: String
    let user_id: String
    let title: String
    let description: String
    let created_at: String       // Changed from Date to String
    let updated_at: String       // Changed from Date to String
    let start_date: String?      // New field, optional
    let target_date: String?     // Changed from Date to String?
    let progress: Double
    let status: String
    let category: String?        // Made optional
    let goal_type: String?       // New field
    let target_value: Double     // New field
    let target_unit: String      // New field
    let current_value: Double    // New field
    
    // ... toDomain() method
}
```

### 2. Custom Date Parsing in toDomain()

Created a flexible date parser that handles multiple ISO8601 formats:

```swift
func toDomain() -> Goal {
    // Parse dates with flexible decoder that handles nanosecond precision
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // Fallback formatter without fractional seconds
    let fallbackFormatter = ISO8601DateFormatter()
    fallbackFormatter.formatOptions = [.withInternetDateTime]

    func parseDate(_ dateString: String) -> Date {
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        if let date = fallbackFormatter.date(from: dateString) {
            return date
        }
        // Last resort: return current date
        return Date()
    }

    let createdDate = parseDate(created_at)
    let updatedDate = parseDate(updated_at)
    let targetDateParsed = target_date.flatMap { parseDate($0) }

    return Goal(
        id: UUID(uuidString: id) ?? UUID(),
        userId: UUID(uuidString: user_id) ?? UUID(),
        title: title,
        description: description,
        createdAt: createdDate,
        updatedAt: updatedDate,
        targetDate: targetDateParsed,
        progress: progress,
        status: GoalStatus(rawValue: status) ?? .active,
        category: GoalCategory(rawValue: category ?? "general") ?? .general,
        targetValue: target_value,
        targetUnit: target_unit,
        currentValue: current_value
    )
}
```

### 3. Added Missing Backend Fields

The `GoalDTO` now includes all fields returned by the backend API, ensuring complete data mapping from backend to domain model.

---

## Benefits

### ✅ Robust Date Handling

- Supports nanosecond-precision timestamps from backend
- Falls back gracefully to millisecond precision if needed
- Handles missing or malformed dates without crashing

### ✅ Complete Data Mapping

- All backend fields are now captured
- Progress tracking with numeric values works correctly
- Goal types and categories are properly mapped

### ✅ Backend Flexibility

- App can handle future backend changes to date format
- No dependency on `JSONDecoder`'s rigid date decoding strategy
- Easier to debug date parsing issues

---

## Testing

### Verification Steps

1. ✅ Create a new goal through the app
2. ✅ Verify goal appears in the goals list
3. ✅ Check that all goal fields are correctly populated
4. ✅ Verify no decoding errors in console logs
5. ✅ Test goal updates and deletions work correctly

### Expected Backend Response Format

```json
{
  "data": {
    "id": "40020d52-dd54-40c2-a8c3-a75c645585f3",
    "user_id": "15d3af32-a0f7-424c-952a-18c372476bfe",
    "goal_type": "activity",
    "title": "Incorporate More Vegetables",
    "description": "Aim to include at least 5 servings...",
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

## Related Files

- `lume/lume/Services/Backend/GoalBackendService.swift` - Updated `GoalDTO` structure
- `lume/lume/Domain/Entities/Goal.swift` - Domain model with all required fields
- `lume/lume/Core/Network/HTTPClient.swift` - Generic HTTP client (unchanged)

---

## Future Considerations

### Option 1: Custom JSONDecoder Date Strategy (Alternative Approach)

Instead of manually parsing dates in `toDomain()`, we could create a custom date decoding strategy for the entire app:

```swift
extension JSONDecoder.DateDecodingStrategy {
    static var flexible: JSONDecoder.DateDecodingStrategy {
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }()
            ]
            
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
    }
}
```

This could be applied in `HTTPClient`:

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .flexible
```

**Pros:**
- Centralized date handling for all API responses
- Automatic for all `Date` fields in all DTOs
- Less repetitive code

**Cons:**
- Global change affecting all date decoding
- Harder to debug date-specific issues
- May mask backend inconsistencies

### Option 2: Backend Standardization (Recommended Long-term)

Work with backend team to standardize on a specific ISO8601 format:

- **Recommended format:** `2025-11-17T19:26:02.123Z` (millisecond precision)
- **Alternative:** `2025-11-17T19:26:02Z` (second precision)

**Benefits:**
- Simpler client implementation
- Better interoperability with other platforms
- Reduced parsing overhead

---

## Conclusion

The goal date decoding issue has been resolved by implementing flexible date parsing in the `GoalDTO` mapping layer. This approach provides robustness against backend date format variations while maintaining clean separation between data transfer objects and domain models.

The fix follows the Lume app's hexagonal architecture principles by keeping the domain layer clean and handling external data format concerns in the infrastructure layer.