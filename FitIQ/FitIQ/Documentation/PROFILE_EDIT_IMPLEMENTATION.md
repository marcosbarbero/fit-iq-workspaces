# Profile Edit Implementation Plan

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** 🚧 Implementation Plan

---

## 📋 Overview

This document outlines the implementation plan for updating the Profile Edit functionality to:
1. Match the backend API structure (`/api/v1/users/me` and `/api/v1/users/me/physical`)
2. Implement offline-first architecture with event-driven sync
3. Properly integrate with HealthKit for relevant data
4. Follow UX guidelines (Ascend color profile)

---

## 🎯 Current State Analysis

### ❌ Issues in Current Implementation

1. **Fields that don't exist in backend:**
   - Weight (should be tracked via Progress API, not profile)
   - Activity Level (not in backend API at all)

2. **Missing backend fields:**
   - Bio (text field in profile metadata)
   - Preferred Unit System (metric/imperial)
   - Language Code
   - Date of Birth (editable via physical profile)

3. **Architecture issues:**
   - No domain events for profile updates
   - No offline-first sync mechanism
   - HealthKit not updated with profile changes

---

## 🏗️ Backend API Structure

### Profile Metadata Endpoint: `PUT /api/v1/users/me`

**Request Body (UserProfileRequest):**
```json
{
  "name": "John Doe",
  "bio": "Fitness enthusiast...",
  "preferred_unit_system": "metric",
  "language_code": "en"
}
```

**Response (UserProfileResponseData):**
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "John Doe",
  "bio": "Fitness enthusiast...",
  "preferred_unit_system": "metric",
  "language_code": "en",
  "date_of_birth": "1990-01-15",
  "created_at": "2025-01-01T00:00:00Z",
  "updated_at": "2025-01-27T10:30:00Z"
}
```

### Physical Profile Endpoint: `PATCH /api/v1/users/me/physical`

**Request Body (UpdatePhysicalProfileRequest):**
```json
{
  "biological_sex": "male",
  "height_cm": 180.5,
  "date_of_birth": "1990-01-15"
}
```

---

## 📦 Implementation Steps

### Step 1: Create Domain Events

**File:** `FitIQ/Domain/Events/ProfileEvents.swift`

```swift
// Events for profile changes
public enum ProfileEvent {
    case metadataUpdated(userId: String, timestamp: Date)
    case physicalProfileUpdated(userId: String, timestamp: Date)
}
```

### Step 2: Create Event Publisher Protocol

**File:** `FitIQ/Domain/Ports/ProfileEventPublisherProtocol.swift`

```swift
public protocol ProfileEventPublisherProtocol {
    var publisher: AnyPublisher<ProfileEvent, Never> { get }
    func publish(event: ProfileEvent)
}
```

### Step 3: Update Use Cases

#### A. Update Profile Metadata Use Case

**File:** `FitIQ/Domain/UseCases/UpdateProfileMetadataUseCase.swift`

- Remove weight, activityLevel parameters
- Add bio, preferredUnitSystem, languageCode parameters
- Publish ProfileEvent.metadataUpdated
- Save to local storage (SwiftData)
- Queue sync event for when online

#### B. Create Update Physical Profile Use Case

**File:** `FitIQ/Domain/UseCases/UpdatePhysicalProfileUseCase.swift`

- Parameters: biologicalSex, heightCm, dateOfBirth
- Publish ProfileEvent.physicalProfileUpdated
- Save to local storage (SwiftData)
- Update HealthKit with relevant data
- Queue sync event for when online

### Step 4: HealthKit Integration

**Update:** `FitIQ/Infrastructure/Services/HealthKitAdapter.swift`

Add methods to write profile data to HealthKit:

```swift
func updateBiologicalSex(_ sex: String) async throws
func updateDateOfBirth(_ date: Date) async throws
func updateHeight(_ heightCm: Double) async throws
```

**HealthKit Mappings:**
- `biological_sex` → `HKCharacteristicType.biologicalSex()`
- `date_of_birth` → `HKCharacteristicType.dateOfBirth()`
- `height_cm` → `HKQuantityType(.height)` (stored as HKQuantitySample)

**Note:** Bio, language, unit system are NOT HealthKit data.

### Step 5: Update ProfileViewModel

**File:** `FitIQ/Presentation/ViewModels/ProfileViewModel.swift`

**New Published Properties:**
```swift
@Published var bio: String = ""
@Published var dateOfBirth: Date = Date()
@Published var preferredUnitSystem: String = "metric"
@Published var languageCode: String = "en"
```

**Remove:**
```swift
@Published var weightKg: String = "" // Move to progress tracking
@Published var activityLevel: String = "" // Not in API
```

**New Methods:**
```swift
func saveProfileMetadata() async
func savePhysicalProfile() async
func updateHealthKitData() async
```

### Step 6: Update ProfileView UI

**File:** `FitIQ/Presentation/UI/Profile/ProfileView.swift`

**New Structure:**

```
┌─────────────────────────────────────┐
│ Section 1: Personal Information     │
│ - Name (text field)                 │
│ - Bio (multi-line text field)       │
│ - Date of Birth (date picker)       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Section 2: Physical Profile         │
│ - Height (text field with unit)     │
│ - Biological Sex (picker)           │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Section 3: Preferences              │
│ - Unit System (picker)              │
│ - Language (picker)                 │
└─────────────────────────────────────┘
```

**UX Considerations:**
- Use **Ascend Blue** (#007AFF) for primary actions
- Use **Vitality Teal** (#00C896) for physical stats icon
- Use **Serenity Lavender** (#B58BEF) for preferences icon
- Maintain modern card-based design
- Use SF Symbols for icons

### Step 7: Offline Sync Implementation

**File:** `FitIQ/Infrastructure/Services/ProfileSyncService.swift`

```swift
final class ProfileSyncService {
    func queueProfileMetadataSync(userId: String)
    func queuePhysicalProfileSync(userId: String)
    func syncPendingChanges() async throws
}
```

**Flow:**
1. User edits profile → Save to SwiftData
2. Publish domain event
3. If online → sync immediately
4. If offline → queue for later sync
5. On reconnect → process queued syncs

### Step 8: Local Storage (SwiftData)

**Update:** `FitIQ/Domain/Entities/Profile/UserProfile.swift`

Ensure the domain model includes:
- `bio: String?`
- `preferredUnitSystem: String` (default "metric")
- `languageCode: String?`

**Update:** `FitIQ/Domain/Entities/Profile/PhysicalProfile.swift`

Already has:
- `biologicalSex: String?`
- `heightCm: Double?`
- `dateOfBirth: Date?`

---

## 🔄 Data Flow Diagram

```
┌──────────────┐
│   User Edit  │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  ProfileViewModel    │
│  - Validates input   │
│  - Calls use case    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────────────┐
│  UpdateProfileMetadataUseCase│
│  or UpdatePhysicalProfile    │
│  - Save to SwiftData         │
│  - Publish event             │
│  - Queue sync                │
└──────┬───────────────────────┘
       │
       ├─────────────────┬──────────────────┐
       │                 │                  │
       ▼                 ▼                  ▼
┌─────────────┐   ┌──────────┐   ┌────────────────┐
│  SwiftData  │   │  Events  │   │  HealthKit     │
│  (Local DB) │   │  Bus     │   │  (if relevant) │
└─────────────┘   └────┬─────┘   └────────────────┘
                       │
                       ▼
                ┌──────────────┐
                │  Sync Service│
                │  (when online)│
                └──────┬───────┘
                       │
                       ▼
                ┌──────────────┐
                │  Backend API │
                └──────────────┘
```

---

## ✅ Checklist

### Domain Layer
- [ ] Create ProfileEvents.swift
- [ ] Create ProfileEventPublisherProtocol.swift
- [ ] Create ProfileEventPublisher.swift
- [ ] Create UpdateProfileMetadataUseCase.swift
- [ ] Create UpdatePhysicalProfileUseCase.swift
- [ ] Update UserProfile entity with new fields
- [ ] Update PhysicalProfile validation

### Infrastructure Layer
- [ ] Update HealthKitAdapter with profile write methods
- [ ] Create ProfileSyncService.swift
- [ ] Update UserProfileRepository for new fields
- [ ] Update SwiftData models for offline storage

### Presentation Layer
- [ ] Update ProfileViewModel properties
- [ ] Update ProfileViewModel methods
- [ ] Update EditProfileSheet UI structure
- [ ] Add bio text editor
- [ ] Add date of birth picker
- [ ] Add unit system picker
- [ ] Add language picker
- [ ] Remove weight field
- [ ] Remove activity level field
- [ ] Update color scheme per UX guidelines

### Testing
- [ ] Unit tests for UpdateProfileMetadataUseCase
- [ ] Unit tests for UpdatePhysicalProfileUseCase
- [ ] Integration tests for offline sync
- [ ] UI tests for profile editing flow
- [ ] Test HealthKit integration
- [ ] Test offline-first behavior

---

## 🎨 UI Mockup

### Personal Information Section
```
┌─────────────────────────────────────────┐
│ 👤 Personal Information [Vitality Teal] │
├─────────────────────────────────────────┤
│ 👤  [John Doe________________]          │
│                                         │
│ 📝  [Bio text area...                   │
│      Multi-line text field              │
│      for user bio...]                   │
│                                         │
│ 📅  [January 15, 1990_______] 📆        │
└─────────────────────────────────────────┘
```

### Physical Profile Section
```
┌─────────────────────────────────────────┐
│ 🏃 Physical Profile [Ascend Blue]       │
├─────────────────────────────────────────┤
│ ↕️  [180.5] cm                          │
│                                         │
│ ⚧  [Male ▼]                             │
│     Options: Male, Female, Other        │
└─────────────────────────────────────────┘
```

### Preferences Section
```
┌─────────────────────────────────────────┐
│ ⚙️  Preferences [Serenity Lavender]     │
├─────────────────────────────────────────┤
│ 📏  Unit System                         │
│     [Metric ▼]                          │
│     Options: Metric, Imperial           │
│                                         │
│ 🌐  Language                            │
│     [English ▼]                         │
│     Options: EN, ES, PT-BR, FR, DE      │
└─────────────────────────────────────────┘
```

---

## 🔐 Security & Privacy

1. **HealthKit Permissions:**
   - Request write permission for height, date of birth, biological sex
   - Show clear permission rationale to user

2. **Data Sync:**
   - Encrypt sensitive data in transit
   - Use JWT authentication for API calls
   - Handle sync conflicts gracefully

3. **Offline Storage:**
   - Use SwiftData encryption if available
   - Clear sensitive data on logout

---

## 📱 Edge Cases to Handle

1. **Offline editing:**
   - Multiple edits before sync
   - Conflict resolution with server

2. **HealthKit write failures:**
   - User denies permission
   - HealthKit unavailable
   - Show appropriate error messages

3. **Validation:**
   - Empty required fields
   - Invalid date ranges
   - Invalid height values

4. **Sync failures:**
   - Network errors
   - Server validation errors
   - Retry logic with exponential backoff

---

## 🚀 Migration Strategy

### Phase 1: Backend Alignment (Current)
1. Update domain models
2. Create new use cases
3. Update ProfileViewModel
4. Update UI

### Phase 2: Event System
1. Implement event publisher
2. Wire up event listeners
3. Test event flow

### Phase 3: Offline Sync
1. Implement sync service
2. Add queue mechanism
3. Test offline scenarios

### Phase 4: HealthKit Integration
1. Add write capabilities
2. Handle permissions
3. Test data sync

---

## 📚 References

- Backend API: `docs/be-api-spec/swagger.yaml`
- UX Guidelines: `docs/ux/COLOR_PROFILE.md`
- Current Implementation: `FitIQ/Presentation/UI/Profile/ProfileView.swift`
- Domain Models: `FitIQ/Domain/Entities/Profile/`

---

**Next Steps:** Begin implementation with Step 1 (Domain Events)