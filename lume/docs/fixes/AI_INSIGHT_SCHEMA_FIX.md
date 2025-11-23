# AI Insight Schema Fix

**Date:** 2025-01-28  
**Type:** Schema Update  
**Severity:** Critical  
**Status:** ✅ Resolved

---

## Problem

The `AIInsightRepository` had 27 compilation errors due to missing properties in the SwiftData schema model `SDAIInsight` (SchemaV3). The repository was trying to access properties that existed in the domain model but were missing from the persistence layer.

### Error Summary

All errors were variations of:
- `Value of type 'SDAIInsight' has no member 'generatedAt'`
- `Value of type 'SDAIInsight' has no member 'isArchived'`
- `Value of type 'SDAIInsight' has no member 'readAt'`
- `Value of type 'SDAIInsight' has no member 'archivedAt'`
- `Generic parameter 'T' could not be inferred` (in FetchDescriptor sort descriptors)

### Affected Files
- `lume/Data/Repositories/AIInsightRepository.swift` (27 errors)
- `lume/Data/Persistence/SchemaVersioning.swift` (missing properties)

---

## Root Cause

The domain model `AIInsight` (located in `Domain/Entities/AIInsight.swift`) included four properties that were missing from the SwiftData schema model `SDAIInsight` in `SchemaV3`:

**Domain Model Properties:**
```swift
struct AIInsight {
    // ... other properties
    var isArchived: Bool
    let generatedAt: Date
    var readAt: Date?
    var archivedAt: Date?
}
```

**Original Schema Model (Missing Properties):**
```swift
@Model
final class SDAIInsight {
    // ... other properties
    var isRead: Bool
    var isFavorite: Bool
    // ❌ Missing: isArchived, generatedAt, readAt, archivedAt
    var backendId: String?
    var createdAt: Date
    var updatedAt: Date
}
```

This mismatch violated the **Hexagonal Architecture** principle that infrastructure must fully support domain requirements.

---

## Solution

Updated `SchemaV3.SDAIInsight` in `SchemaVersioning.swift` to include all missing properties:

### Changes Made

**Added Properties:**
```swift
@Model
final class SDAIInsight {
    // ... existing properties
    var isArchived: Bool       // Track archive status
    var generatedAt: Date      // When insight was generated
    var readAt: Date?          // When insight was read
    var archivedAt: Date?      // When insight was archived
    // ... rest of properties
}
```

**Updated Initializer:**
```swift
init(
    // ... existing parameters
    isArchived: Bool = false,
    generatedAt: Date = Date(),
    readAt: Date? = nil,
    archivedAt: Date? = nil,
    // ... rest of parameters
)
```

### Complete Updated Schema

```swift
@Model
final class SDAIInsight {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var insightType: String
    var title: String
    var content: String
    var summary: String?
    var suggestions: [String]
    var dataContextData: Data?
    var isRead: Bool
    var isFavorite: Bool
    var isArchived: Bool          // ✅ NEW
    var generatedAt: Date         // ✅ NEW
    var readAt: Date?             // ✅ NEW
    var archivedAt: Date?         // ✅ NEW
    var backendId: String?
    var createdAt: Date
    var updatedAt: Date
}
```

---

## Impact

### Before Fix
- ❌ 27 compilation errors in `AIInsightRepository`
- ❌ Cannot build or run the app
- ❌ Schema mismatch between domain and infrastructure
- ❌ Missing critical insight metadata

### After Fix
- ✅ All compilation errors resolved
- ✅ Schema matches domain model requirements
- ✅ Full support for insight lifecycle (generate, read, archive)
- ✅ Repository can properly map between domain and persistence layers
- ✅ Ready for UI implementation (Phase 5)

---

## Architecture Compliance

This fix restores compliance with the project's core architectural principles:

### Hexagonal Architecture
- **Domain** defines requirements through entities (`AIInsight`)
- **Infrastructure** implements full support in persistence layer (`SDAIInsight`)
- **Repository** correctly translates between layers

### SOLID Principles
- **Single Responsibility:** Schema model now fully represents insight persistence needs
- **Interface Segregation:** All required properties available for repository operations

### Data Flow
```
Domain (AIInsight)
    ↓ Repository translates
Infrastructure (SDAIInsight)
    ↓ SwiftData persists
Database
```

---

## Testing Recommendations

### Unit Tests
- Verify all repository CRUD operations work correctly
- Test domain ↔ SwiftData mapping functions
- Validate archive/unarchive workflows

### Integration Tests
- Test insight generation with all new properties
- Verify read tracking updates correctly
- Confirm archive operations persist properly

### Migration Tests
- Ensure existing insights migrate safely (if any exist)
- Verify default values applied to new properties
- Test data integrity after migration

---

## Related Features

This fix enables proper functionality for:

1. **Insight Generation**
   - Track when insights are generated (`generatedAt`)
   - Differentiate from creation time (`createdAt`)

2. **Read Tracking**
   - Mark insights as read
   - Track exact read timestamp (`readAt`)

3. **Archive Management**
   - Archive old or dismissed insights
   - Track archive timestamp (`archivedAt`)
   - Support unarchive operations

4. **Filtering & Sorting**
   - Fetch unread insights
   - Sort by generation date
   - Filter out archived insights
   - Retrieve archived insights separately

---

## Future Considerations

### Schema Evolution
- This is a **backward-incompatible** change to SchemaV3
- If production data exists, will need migration from previous schema
- Consider adding migration tests before deployment

### Additional Properties (Future)
Consider adding in future schema versions:
- `priority: Int?` - Insight importance
- `expiresAt: Date?` - Insight relevance window
- `actionedAt: Date?` - When user acted on suggestions
- `dismissedAt: Date?` - When user dismissed insight

### Performance
- Add indexes on `userId` + `generatedAt` for common queries
- Consider composite index on `userId` + `isArchived` + `isRead`

---

## Verification

### Files Modified
- ✅ `lume/Data/Persistence/SchemaVersioning.swift`
  - Updated `SchemaV3.SDAIInsight` properties
  - Updated initializer
  - Updated property assignments

### Files Fixed
- ✅ `lume/Data/Repositories/AIInsightRepository.swift`
  - All 27 errors resolved
  - No code changes needed in repository
  - Mapping functions work correctly with updated schema

### Compilation Status
```
Before: 27 errors
After:  0 errors
Status: ✅ PASSED
```

---

## Lessons Learned

1. **Schema-First Design:** When creating new features, define SwiftData schema alongside domain models to catch mismatches early

2. **Property Parity:** Infrastructure models must include all properties needed for domain operations, not just minimal persistence

3. **Semantic Meaning:** Differentiate between administrative timestamps (`createdAt`, `updatedAt`) and business logic timestamps (`generatedAt`, `readAt`)

4. **Architecture Testing:** Regular architecture compliance checks would have caught this mismatch before implementation

---

## Conclusion

This fix resolves a critical schema mismatch that prevented the AI Insights feature from compiling. The updated schema now fully supports the domain model's requirements, enabling proper insight lifecycle management (generation, reading, archiving) and making the feature ready for UI implementation in Phase 5.

**Status:** ✅ All AI Insight backend errors resolved  
**Next Step:** Proceed with Phase 5 (Presentation Layer)