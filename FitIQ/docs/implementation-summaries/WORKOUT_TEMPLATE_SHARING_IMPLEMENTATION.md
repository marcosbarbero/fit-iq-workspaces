# Workout Template Sharing API Changes - Implementation Guide

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Completed

---

## Overview

This document summarizes the implementation of the new workout template sharing API changes, including bulk sharing, shared-with-me lists, template copying, and share revocation features.

---

## Summary of Changes

### 1. Backend API Updates (from swagger.yaml)

The backend API now supports the following new endpoints:

- **POST /api/v1/workout-templates/{id}/share** - Bulk share with multiple users
- **DELETE /api/v1/workout-templates/{id}/share/{userId}** - Revoke sharing for a specific user
- **GET /api/v1/workout-templates/shared-with-me** - List templates shared with authenticated user
- **POST /api/v1/workout-templates/{id}/copy** - Copy a template to user's personal library

### 2. Key Architectural Changes

#### From Single-User to Bulk Sharing
- **Old:** Share with one user at a time
- **New:** Share with multiple users in a single API call
- **Impact:** Breaking change - requires updating all sharing logic

#### New Professional Type System
- Templates can now be categorized by professional type
- Supported types: `personal_trainer`, `nutritionist`, `physical_therapist`, `sports_coach`
- Used for filtering and categorization

---

## Implementation Details

### Domain Models Added

#### File: `Domain/Entities/Workout/WorkoutTemplate.swift`

**New Models:**

1. **ProfessionalType (enum)**
   ```swift
   public enum ProfessionalType: String, Codable, CaseIterable {
       case personalTrainer = "personal_trainer"
       case nutritionist = "nutritionist"
       case physicalTherapist = "physical_therapist"
       case sportsCoach = "sports_coach"
   }
   ```

2. **SharedWithUserInfo**
   - Represents information about a user a template was shared with
   - Properties: `userId`, `shareId`, `sharedAt`

3. **ShareWorkoutTemplateResponse**
   - Response from sharing a template
   - Properties: `templateId`, `templateName`, `sharedWith`, `totalShared`, `professionalType`

4. **SharedTemplateInfo**
   - Information about a template shared with the user
   - Properties: `templateId`, `name`, `description`, `category`, `difficultyLevel`, `estimatedDurationMinutes`, `exerciseCount`, `professionalName`, `professionalType`, `sharedAt`, `notes`

5. **ListSharedTemplatesResponse**
   - Response from listing shared templates
   - Properties: `templates`, `total`, `limit`, `offset`, `hasMore`

6. **RevokeTemplateShareResponse**
   - Response from revoking a template share
   - Properties: `templateId`, `revokedFromUserId`, `revokedAt`

7. **CopyWorkoutTemplateResponse**
   - Response from copying a template
   - Properties: `originalTemplateId`, `newTemplate`

---

### API Client Updates

#### File: `Domain/UseCases/Workout/SyncWorkoutTemplatesUseCase.swift`

**WorkoutTemplateAPIClientProtocol - New Methods:**

```swift
// Bulk share with multiple users
func shareTemplate(
    id: UUID,
    userIds: [UUID],
    professionalType: ProfessionalType,
    notes: String?
) async throws -> ShareWorkoutTemplateResponse

// Revoke share from a specific user
func revokeTemplateShare(
    templateId: UUID,
    userId: UUID
) async throws -> RevokeTemplateShareResponse

// Fetch templates shared with authenticated user
func fetchSharedWithMeTemplates(
    professionalType: ProfessionalType?,
    limit: Int,
    offset: Int
) async throws -> ListSharedTemplatesResponse

// Copy a template to user's personal library
func copyTemplate(
    id: UUID,
    newName: String?
) async throws -> CopyWorkoutTemplateResponse
```

#### File: `Infrastructure/Network/WorkoutTemplateAPIClient.swift`

**Implementation Details:**

- **Bulk Sharing:** Accepts array of user IDs and professional type
- **Authentication:** All endpoints require Bearer token authentication
- **Error Handling:** Proper handling of 401, 403, 404 status codes
- **Response Parsing:** DTOs for parsing backend responses with snake_case to camelCase conversion

**New Private DTOs Added:**
- `ShareWorkoutTemplateResponseDTO`
- `SharedWithUserInfoDTO`
- `SharedTemplateInfoDTO`
- `ListSharedTemplatesResponseDTO`
- `RevokeTemplateShareResponseDTO`
- `CopyWorkoutTemplateResponseDTO`

---

### Use Cases Created

#### 1. ShareWorkoutTemplateUseCase

**File:** `Domain/UseCases/Workout/ShareWorkoutTemplateUseCase.swift`

**Purpose:** Share a workout template with multiple users (bulk sharing)

**Validation:**
- Ensures at least one user is specified
- Verifies user is authenticated
- Checks template exists locally
- Verifies user owns the template
- Ensures template is published before sharing

**Errors:**
- `noUsersSpecified`
- `notAuthenticated`
- `templateNotFound`
- `notAuthorized`
- `templateNotPublished`

---

#### 2. RevokeTemplateShareUseCase

**File:** `Domain/UseCases/Workout/RevokeTemplateShareUseCase.swift`

**Purpose:** Revoke a workout template share from a specific user

**Validation:**
- Verifies user is authenticated
- Checks template exists locally
- Verifies user owns the template

**Errors:**
- `notAuthenticated`
- `templateNotFound`
- `notAuthorized`

---

#### 3. FetchSharedWithMeTemplatesUseCase

**File:** `Domain/UseCases/Workout/FetchSharedWithMeTemplatesUseCase.swift`

**Purpose:** Fetch workout templates shared with the authenticated user

**Features:**
- Optional filtering by professional type
- Pagination support (limit, offset)
- Parameter validation (limit: 1-100, offset: ≥0)

**Errors:**
- `notAuthenticated`
- `invalidLimit`
- `invalidOffset`

---

#### 4. CopyWorkoutTemplateUseCase

**File:** `Domain/UseCases/Workout/CopyWorkoutTemplateUseCase.swift`

**Purpose:** Copy a template to user's personal library

**Features:**
- Optional new name for the copy
- Validates new name if provided
- Saves copied template locally after successful API call
- Handles local save failures gracefully (template exists on backend)

**Errors:**
- `notAuthenticated`
- `invalidName`
- `templateNotFound`
- `notAccessible`

---

### Dependency Injection

#### File: `Infrastructure/Configuration/AppDependencies.swift`

**Changes Made:**

1. **Added Properties:**
   ```swift
   let shareWorkoutTemplateUseCase: ShareWorkoutTemplateUseCase
   let revokeTemplateShareUseCase: RevokeTemplateShareUseCase
   let fetchSharedWithMeTemplatesUseCase: FetchSharedWithMeTemplatesUseCase
   let copyWorkoutTemplateUseCase: CopyWorkoutTemplateUseCase
   ```

2. **Initialized in build() method:**
   ```swift
   let shareWorkoutTemplateUseCase = ShareWorkoutTemplateUseCaseImpl(
       apiClient: workoutTemplateAPIClient,
       repository: workoutTemplateRepository,
       authManager: authManager
   )
   
   let revokeTemplateShareUseCase = RevokeTemplateShareUseCaseImpl(
       apiClient: workoutTemplateAPIClient,
       repository: workoutTemplateRepository,
       authManager: authManager
   )
   
   let fetchSharedWithMeTemplatesUseCase = FetchSharedWithMeTemplatesUseCaseImpl(
       apiClient: workoutTemplateAPIClient,
       authManager: authManager
   )
   
   let copyWorkoutTemplateUseCase = CopyWorkoutTemplateUseCaseImpl(
       apiClient: workoutTemplateAPIClient,
       repository: workoutTemplateRepository,
       authManager: authManager
   )
   ```

3. **Updated init() parameters** to accept new use cases

---

## Architecture Compliance

✅ **Hexagonal Architecture Maintained:**
- Domain layer defines interfaces (protocols)
- Infrastructure implements adapters (API client)
- Use cases orchestrate business logic
- No direct dependencies on external systems in domain

✅ **Dependency Injection:**
- All use cases registered in AppDependencies
- Proper dependency flow maintained

✅ **Error Handling:**
- Custom error types for each use case
- Localized error messages
- Proper error propagation

---

## API Endpoint Mapping

| Feature | Method | Endpoint | Use Case | Status |
|---------|--------|----------|----------|--------|
| **Bulk Share** | POST | `/api/v1/workout-templates/{id}/share` | ShareWorkoutTemplateUseCase | ✅ |
| **Revoke Share** | DELETE | `/api/v1/workout-templates/{id}/share/{userId}` | RevokeTemplateShareUseCase | ✅ |
| **Shared With Me** | GET | `/api/v1/workout-templates/shared-with-me` | FetchSharedWithMeTemplatesUseCase | ✅ |
| **Copy Template** | POST | `/api/v1/workout-templates/{id}/copy` | CopyWorkoutTemplateUseCase | ✅ |

---

## Usage Examples

### 1. Share a Template with Multiple Users

```swift
let shareUseCase = appDependencies.shareWorkoutTemplateUseCase

let response = try await shareUseCase.execute(
    templateId: templateUUID,
    userIds: [user1UUID, user2UUID, user3UUID],
    professionalType: .personalTrainer,
    notes: "Custom program designed for your goals"
)

print("Shared with \(response.totalShared) users")
```

### 2. Revoke a Template Share

```swift
let revokeUseCase = appDependencies.revokeTemplateShareUseCase

let response = try await revokeUseCase.execute(
    templateId: templateUUID,
    userId: userUUID
)

print("Revoked access at \(response.revokedAt)")
```

### 3. Fetch Templates Shared With Me

```swift
let fetchUseCase = appDependencies.fetchSharedWithMeTemplatesUseCase

let response = try await fetchUseCase.execute(
    professionalType: .personalTrainer, // Optional filter
    limit: 20,
    offset: 0
)

print("Found \(response.templates.count) shared templates")
```

### 4. Copy a Template

```swift
let copyUseCase = appDependencies.copyWorkoutTemplateUseCase

let response = try await copyUseCase.execute(
    templateId: templateUUID,
    newName: "My Custom Push Day"
)

print("Created copy with ID: \(response.newTemplate.id)")
```

---

## Testing Considerations

### Unit Tests Needed

1. **ShareWorkoutTemplateUseCaseTests**
   - Test bulk sharing with multiple users
   - Test validation (empty user list, not authenticated, not owner, not published)
   - Test successful sharing

2. **RevokeTemplateShareUseCaseTests**
   - Test revoking access
   - Test validation (not authenticated, not owner)
   - Test successful revocation

3. **FetchSharedWithMeTemplatesUseCaseTests**
   - Test fetching with/without professional type filter
   - Test pagination
   - Test validation (invalid limit/offset)
   - Test successful fetch

4. **CopyWorkoutTemplateUseCaseTests**
   - Test copying with/without new name
   - Test validation (empty name)
   - Test local save success/failure
   - Test successful copy

5. **WorkoutTemplateAPIClientTests**
   - Mock network responses for new endpoints
   - Test response parsing
   - Test error handling (401, 403, 404)
   - Test token refresh on 401

---

## Migration Notes

### Breaking Changes

⚠️ **Sharing is now bulk operation:**
- Old code sharing with single users will need updates
- Any UI/ViewModels calling old sharing methods must be updated

### Backward Compatibility

❌ **No backward compatibility:**
- The new API is a breaking change
- Old single-user sharing endpoints may be deprecated
- Check with backend team for deprecation timeline

---

## Next Steps

### Required for Production

1. **UI Updates** (Outside scope of this implementation):
   - Update sharing UI to support multiple user selection
   - Add "Shared With Me" section
   - Add template copy functionality
   - Add share revocation UI

2. **ViewModel Updates** (If needed):
   - Create ViewModels that use the new use cases
   - Handle loading states
   - Handle errors with user-friendly messages

3. **Integration Testing**:
   - Test against live backend API
   - Verify authentication flows
   - Test edge cases (network failures, token expiration)

4. **Analytics** (Optional):
   - Track sharing events
   - Monitor copy template usage
   - Track revocation events

### Optional Enhancements

- Add local caching for shared templates
- Add push notifications when templates are shared
- Add search/filtering for shared templates
- Add template preview before copying

---

## Files Changed/Created

### Created Files (7)

1. `FitIQ/Domain/UseCases/Workout/ShareWorkoutTemplateUseCase.swift`
2. `FitIQ/Domain/UseCases/Workout/RevokeTemplateShareUseCase.swift`
3. `FitIQ/Domain/UseCases/Workout/FetchSharedWithMeTemplatesUseCase.swift`
4. `FitIQ/Domain/UseCases/Workout/CopyWorkoutTemplateUseCase.swift`
5. `FitIQ/docs/WORKOUT_TEMPLATE_SHARING_IMPLEMENTATION.md` (this file)

### Modified Files (3)

1. `FitIQ/Domain/Entities/Workout/WorkoutTemplate.swift`
   - Added 7 new domain models for sharing/copying
   - Added `ProfessionalType` enum

2. `FitIQ/Domain/UseCases/Workout/SyncWorkoutTemplatesUseCase.swift`
   - Updated `WorkoutTemplateAPIClientProtocol` with 4 new methods

3. `FitIQ/Infrastructure/Network/WorkoutTemplateAPIClient.swift`
   - Implemented 4 new API methods
   - Added 6 new private DTOs for response parsing

4. `FitIQ/Infrastructure/Configuration/AppDependencies.swift`
   - Added 4 new use case properties
   - Initialized 4 new use cases in build method
   - Updated init parameters

---

## Compliance Checklist

- ✅ Follows Hexagonal Architecture pattern
- ✅ Domain layer is pure business logic
- ✅ Infrastructure implements domain ports
- ✅ Use cases registered in AppDependencies
- ✅ No hardcoded configuration
- ✅ Proper error handling with custom errors
- ✅ Snake_case to camelCase conversion
- ✅ Consistent naming conventions
- ✅ DTOs for API response parsing
- ✅ Authentication handled properly
- ✅ No UI changes made (as required)
- ✅ Documentation created

---

## Troubleshooting

### Common Issues

**Issue:** 401 Unauthorized when sharing
- **Solution:** Verify user is authenticated and token is valid

**Issue:** 403 Forbidden when sharing
- **Solution:** Verify user owns the template and is a professional

**Issue:** Template not found when copying
- **Solution:** Verify template is accessible (public, system, or shared)

**Issue:** Empty user list when sharing
- **Solution:** Use case validation will throw `noUsersSpecified` error

---

## References

- **Backend API Spec:** `FitIQ/docs/be-api-spec/swagger.yaml` (lines 9024-9200)
- **Hexagonal Architecture Guide:** `FitIQ/.github/copilot-instructions.md`
- **Existing Use Case Pattern:** `Domain/UseCases/Workout/CreateWorkoutTemplateUseCase.swift`
- **Existing API Client Pattern:** `Infrastructure/Network/WorkoutTemplateAPIClient.swift`

---

## Conclusion

The workout template sharing API changes have been successfully implemented following the hexagonal architecture pattern. All new functionality is accessible through well-defined use cases, properly registered in the dependency injection container, and ready for UI integration.

**Status:** ✅ Ready for UI/ViewModel integration and testing

---

**Last Updated:** 2025-01-27  
**Implemented By:** AI Assistant  
**Reviewed By:** Pending