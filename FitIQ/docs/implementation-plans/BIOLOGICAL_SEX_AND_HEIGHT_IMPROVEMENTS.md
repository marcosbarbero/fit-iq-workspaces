# Biological Sex and Height Handling Improvements

## Overview

This document outlines the architectural improvements for handling biological sex and height data in the FitIQ iOS app.

**Date:** January 27, 2025  
**Status:** Implementation Plan  
**Priority:** Medium

---

## Requirements

### 1. Biological Sex
- **ALWAYS immutable** - Never editable by users, ever
- **HealthKit-only source** - ONLY comes from HealthKit, no other source
- **Update-triggered sync** - Only synced to backend when HealthKit data changes
- **No manual input** - Not even shown as an editable field in the UI
- **Display-only** - Shown as read-only information like date of birth

### 2. Height
- **Editable in UI** - Users can manually update their height
- **Time-series tracking** - Track height changes over time (growth, measurement corrections)
- **Progress endpoint** - Use `/api/v1/progress` POST endpoint for logging height changes
- **Historical data** - Maintain a history of height measurements with timestamps

---

## Current State

### Biological Sex
- ✅ Fetched from HealthKit
- ✅ Stored in local profile
- ❌ **Issue:** Synced to backend on every profile save (should only sync on HealthKit updates)
- ❌ **Issue:** User can edit it in the UI (should not be editable at all)
- ❌ **Issue:** No change detection - syncs even when value hasn't changed

### Height
- ✅ Fetched from HealthKit
- ✅ Stored in local profile
- ✅ Synced to backend via `/users/me/physical`
- ❌ **Issue:** Only stores latest value, no historical tracking
- ❌ **Issue:** Should use `/progress` endpoint for time-series data

---

## Proposed Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     BIOLOGICAL SEX                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  HealthKit (ONLY source)                                     │
│     ↓ (read-only, on change detection)                       │
│  Local Profile (SwiftData)                                   │
│     ↓ (sync ONLY when HealthKit value changes)               │
│  Backend /users/me/physical                                  │
│     ↓ (stored, updated only from HealthKit)                  │
│  UI (display-only, NOT in edit form)                         │
│                                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        HEIGHT                                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  HealthKit OR Manual Input                                   │
│     ↓                                                         │
│  Local Profile (SwiftData) - Latest value                    │
│     ↓                                                         │
│  Backend /users/me/physical - Current height                 │
│     ↓                                                         │
│  Backend /progress (type: height) - Historical entries       │
│     ↓                                                         │
│  UI (editable, shows current + history)                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Domain Layer (Use Cases & Ports)

#### 1.1 Create Height Progress Use Case

**File:** `Domain/UseCases/LogHeightProgressUseCase.swift`

```swift
protocol LogHeightProgressUseCase {
    func execute(
        userId: String,
        heightCm: Double,
        date: Date?,
        notes: String?
    ) async throws -> ProgressEntry
}

final class LogHeightProgressUseCaseImpl: LogHeightProgressUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    
    init(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }
    
    func execute(
        userId: String,
        heightCm: Double,
        date: Date?,
        notes: String?
    ) async throws -> ProgressEntry {
        // Validation
        guard heightCm > 0 && heightCm < 300 else {
            throw ValidationError.invalidHeight
        }
        
        // Log to progress endpoint
        return try await progressRepository.logProgress(
            type: "height",
            quantity: heightCm,
            date: date,
            time: nil,
            notes: notes
        )
    }
}
```

#### 1.2 Create Progress Repository Port

**File:** `Domain/Ports/ProgressRepositoryProtocol.swift`

```swift
protocol ProgressRepositoryProtocol {
    /// Log a single progress metric
    func logProgress(
        type: String,
        quantity: Double,
        date: Date?,
        time: String?,
        notes: String?
    ) async throws -> ProgressEntry
    
    /// Get current progress (latest value for each metric)
    func getCurrentProgress(type: String?) async throws -> [ProgressEntry]
    
    /// Get historical progress entries
    func getProgressHistory(
        type: String?,
        startDate: Date?,
        endDate: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry]
}
```

#### 1.3 Create Progress Domain Model

**File:** `Domain/Entities/Progress/ProgressEntry.swift`

```swift
struct ProgressEntry {
    let id: String
    let userId: String
    let type: String // "height", "weight", etc.
    let quantity: Double
    let date: Date
    let time: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}
```

---

### Phase 2: Infrastructure Layer (Network & Repositories)

#### 2.1 Create Progress API Client

**File:** `Infrastructure/Network/ProgressAPIClient.swift`

```swift
final class ProgressAPIClient: ProgressRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    
    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        authTokenPersistence: AuthTokenPersistencePortProtocol
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
    }
    
    func logProgress(
        type: String,
        quantity: Double,
        date: Date?,
        time: String?,
        notes: String?
    ) async throws -> ProgressEntry {
        // Implementation
    }
    
    func getCurrentProgress(type: String?) async throws -> [ProgressEntry] {
        // Implementation
    }
    
    func getProgressHistory(
        type: String?,
        startDate: Date?,
        endDate: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry] {
        // Implementation
    }
}
```

#### 2.2 Create Progress DTOs

**File:** `Infrastructure/Network/DTOs/ProgressDTOs.swift`

```swift
struct ProgressLogRequest: Encodable {
    let type: String
    let quantity: Double
    let date: String? // YYYY-MM-DD
    let time: String? // HH:MM:SS
    let notes: String?
}

struct ProgressEntryResponse: Decodable {
    let id: String
    let userId: String
    let type: String
    let quantity: Double
    let date: String
    let time: String?
    let notes: String?
    let createdAt: String
    let updatedAt: String
}

extension ProgressEntryResponse {
    func toDomain() throws -> ProgressEntry {
        // Map to domain model
    }
}
```

---

### Phase 3: Update Physical Profile Sync

#### 3.1 Update Physical Profile Use Case

**File:** `Domain/UseCases/UpdatePhysicalProfileUseCase.swift`

Update to **exclude biological sex** from user-editable updates:

```swift
func execute(
    userId: String,
    heightCm: Double?,
    dateOfBirth: Date?
) async throws -> PhysicalProfile {
    
    // Get current profile
    guard let currentProfile = try await userProfileStorage.fetch(forUserID: UUID(uuidString: userId)!) else {
        throw ProfileError.notFound
    }
    
    // Biological sex is NEVER updated here - only via HealthKit sync
    let currentBiologicalSex = currentProfile.physical?.biologicalSex
    
    // Height can be updated freely
    let finalHeight = heightCm ?? currentProfile.physical?.heightCm
    
    // Date of birth from current profile (set during registration)
    let finalDOB = currentProfile.physical?.dateOfBirth ?? dateOfBirth
    
    let updatedPhysical = PhysicalProfile(
        biologicalSex: currentBiologicalSex, // Keep existing value
        heightCm: finalHeight,
        dateOfBirth: finalDOB
    )
    
    // Save locally
    let updatedProfile = currentProfile.updatingPhysical(updatedPhysical)
    try await userProfileStorage.save(userProfile: updatedProfile)
    
    // If height changed, log to progress
    if let newHeight = heightCm,
       let oldHeight = currentProfile.physical?.heightCm,
       newHeight != oldHeight {
        print("UpdatePhysicalProfileUseCase: Height changed from \(oldHeight) to \(newHeight), logging to progress")
        try? await logHeightProgressUseCase.execute(
            userId: userId,
            heightCm: newHeight,
            date: Date(),
            notes: "Height updated in profile"
        )
    }
    
    // Sync to backend (only height and DOB, never biological sex from here)
    try await physicalProfileRepository.updatePhysicalProfile(
        userId: userId,
        biologicalSex: nil, // Never sync biological sex from user edits
        heightCm: finalHeight,
        dateOfBirth: finalDOB
    )
    
    return updatedPhysical
}
```

#### 3.2 Create HealthKit Sync Use Case for Biological Sex

**File:** `Domain/UseCases/SyncBiologicalSexFromHealthKitUseCase.swift`

New use case specifically for HealthKit-triggered biological sex updates:

```swift
protocol SyncBiologicalSexFromHealthKitUseCase {
    func execute(userId: String, biologicalSex: String) async throws
}

final class SyncBiologicalSexFromHealthKitUseCaseImpl: SyncBiologicalSexFromHealthKitUseCase {
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let physicalProfileRepository: PhysicalProfileRepositoryProtocol
    
    init(
        userProfileStorage: UserProfileStoragePortProtocol,
        physicalProfileRepository: PhysicalProfileRepositoryProtocol
    ) {
        self.userProfileStorage = userProfileStorage
        self.physicalProfileRepository = physicalProfileRepository
    }
    
    func execute(userId: String, biologicalSex: String) async throws {
        print("SyncBiologicalSexFromHealthKitUseCase: HealthKit update detected")
        
        guard let currentProfile = try await userProfileStorage.fetch(forUserID: UUID(uuidString: userId)!) else {
            throw ProfileError.notFound
        }
        
        let currentSex = currentProfile.physical?.biologicalSex
        
        // Only update if value actually changed
        guard currentSex != biologicalSex else {
            print("SyncBiologicalSexFromHealthKitUseCase: No change detected, skipping sync")
            return
        }
        
        print("SyncBiologicalSexFromHealthKitUseCase: Updating from '\(currentSex ?? "nil")' to '\(biologicalSex)'")
        
        // Update local profile
        let updatedPhysical = PhysicalProfile(
            biologicalSex: biologicalSex,
            heightCm: currentProfile.physical?.heightCm,
            dateOfBirth: currentProfile.physical?.dateOfBirth
        )
        
        let updatedProfile = currentProfile.updatingPhysical(updatedPhysical)
        try await userProfileStorage.save(userProfile: updatedProfile)
        
        print("SyncBiologicalSexFromHealthKitUseCase: Saved to local storage")
        
        // Sync to backend (only biological sex, don't touch other fields)
        try await physicalProfileRepository.updatePhysicalProfile(
            userId: userId,
            biologicalSex: biologicalSex,
            heightCm: currentProfile.physical?.heightCm,
            dateOfBirth: currentProfile.physical?.dateOfBirth
        )
        
        print("SyncBiologicalSexFromHealthKitUseCase: ✅ Synced to backend")
    }
}
```

---

### Phase 4: UI Updates (View Bindings Only)

**IMPORTANT:** Per project rules, we can ONLY add field bindings, NOT change layout/styling.

#### 4.1 Remove Biological Sex from Edit Form

**File:** `Presentation/UI/Profile/ProfileView.swift`

**ACTION:** Remove the biological sex picker from the edit form entirely.

Since biological sex is NEVER editable by users (only from HealthKit), it should not appear in the edit form at all. It can be displayed elsewhere as read-only information (e.g., in the main profile view, not the edit sheet).

```swift
// REMOVE THIS SECTION from EditProfileSheet:
ModernPicker(
    icon: "person.2",
    label: "Biological Sex",
    selection: $viewModel.biologicalSex,
    options: [
        ("", "Select"),
        ("male", "Male"),
        ("female", "Female"),
        ("other", "Other"),
    ]
)

// Biological sex can be displayed in the main ProfileView as read-only info:
// (This goes outside the edit sheet, in the profile display)
if !viewModel.biologicalSex.isEmpty {
    SettingRow(
        icon: "person.2",
        title: "Biological Sex: \(viewModel.biologicalSex.capitalized)",
        color: .gray
    ) {}
}
```

**Note:** Since we cannot change UI layout per project rules, this is a **recommendation** for the next UI update. For now, the picker can remain but should be `.disabled(true)` with a note "Managed by HealthKit".

---

### Phase 5: ViewModel Updates

#### 5.1 Update ProfileViewModel

**File:** `Presentation/ViewModels/ProfileViewModel.swift`

```swift
// Update save method to exclude biological sex and log height changes
@MainActor
func savePhysicalProfile() async {
    guard let userId = authManager.currentUserProfileID else {
        profileUpdateMessage = "No user ID found"
        return
    }
    
    isSavingProfile = true
    profileUpdateMessage = nil
    
    let height = Double(heightCm)
    
    do {
        // Save WITHOUT biological sex (that's only updated from HealthKit)
        let updatedPhysical = try await updatePhysicalProfileUseCase.execute(
            userId: userId.uuidString,
            heightCm: height,
            dateOfBirth: dateOfBirth
        )
        
        self.physicalProfile = updatedPhysical
        self.profileUpdateMessage = "Physical profile updated successfully!"
        
        print("ProfileViewModel: ✅ Physical profile saved")
    } catch {
        profileUpdateMessage = "Failed to update: \(error.localizedDescription)"
        print("ProfileViewModel: ❌ Save failed: \(error.localizedDescription)")
    }
    
    isSavingProfile = false
}

// Add method for HealthKit biological sex sync
@MainActor
func syncBiologicalSexFromHealthKit() async {
    guard let userId = authManager.currentUserProfileID else {
        print("ProfileViewModel: No user ID for biological sex sync")
        return
    }
    
    // Fetch from HealthKit
    do {
        let hkBiologicalSex = try await healthRepository.fetchBiologicalSex()
        
        guard let hkSex = hkBiologicalSex else {
            print("ProfileViewModel: No biological sex in HealthKit")
            return
        }
        
        let sexString: String
        switch hkSex {
        case .female:
            sexString = "female"
        case .male:
            sexString = "male"
        case .other:
            sexString = "other"
        case .notSet:
            return // Not set, nothing to sync
        @unknown default:
            return
        }
        
        // Sync to backend via dedicated use case
        try await syncBiologicalSexFromHealthKitUseCase.execute(
            userId: userId.uuidString,
            biologicalSex: sexString
        )
        
        // Update local state
        self.biologicalSex = sexString
        
        print("ProfileViewModel: ✅ Biological sex synced from HealthKit: \(sexString)")
    } catch {
        print("ProfileViewModel: ❌ Failed to sync biological sex: \(error.localizedDescription)")
    }
}
```

---

### Phase 6: Dependency Injection

#### 6.1 Update AppDependencies

**File:** `DI/AppDependencies.swift`

```swift
// Add progress client and use case
lazy var progressAPIClient: ProgressRepositoryProtocol = ProgressAPIClient(
    networkClient: networkClient,
    authTokenPersistence: keychainAuthTokenAdapter
)

lazy var logHeightProgressUseCase: LogHeightProgressUseCase = LogHeightProgressUseCaseImpl(
    progressRepository: progressAPIClient
)

// Update physical profile use case with progress logging
lazy var updatePhysicalProfileUseCase: UpdatePhysicalProfileUseCase = UpdatePhysicalProfileUseCaseImpl(
    userProfileStorage: swiftDataUserProfileAdapter,
    physicalProfileRepository: physicalProfileAPIClient,
    logHeightProgressUseCase: logHeightProgressUseCase
)

lazy var syncBiologicalSexFromHealthKitUseCase: SyncBiologicalSexFromHealthKitUseCase = SyncBiologicalSexFromHealthKitUseCaseImpl(
    userProfileStorage: swiftDataUserProfileAdapter,
    physicalProfileRepository: physicalProfileAPIClient
)
```

---

## Testing Plan

### Test Case 1: Biological Sex HealthKit-Only

- [ ] Fresh install (no biological sex set)
- [ ] Grant HealthKit permissions
- [ ] HealthKit provides biological sex: "male"
- [ ] Verify `syncBiologicalSexFromHealthKit()` is called
- [ ] Check logs: should sync to backend only when value changes
- [ ] Open Edit Profile
- [ ] Verify biological sex is NOT editable (removed from form or disabled)
- [ ] Change height and save
- [ ] Verify biological sex is NOT included in the save request
- [ ] Check backend: biological sex remains "male" (not overwritten)

### Test Case 2: Height Time-Series Tracking

- [ ] Open Edit Profile
- [ ] Change height from 175cm to 180cm
- [ ] Save profile
- [ ] Check logs: should POST to `/api/v1/progress` with type "height"
- [ ] Verify backend response includes progress entry ID
- [ ] Change height again to 178cm
- [ ] Save and verify another progress entry is created
- [ ] Check backend: should have 2 height entries with different timestamps

### Test Case 3: HealthKit Biological Sex Change Detection

- [ ] User has biological sex set to "male" from HealthKit
- [ ] User changes biological sex in Apple Health app to "other"
- [ ] App detects HealthKit change (via background sync or app launch)
- [ ] Verify change is detected: "male" → "other"
- [ ] Verify local profile is updated
- [ ] Verify backend is synced with new value
- [ ] Check logs: should show "Updating from 'male' to 'other'"
- [ ] Edit and save height in profile
- [ ] Verify biological sex remains "other" (not affected by profile save)

### Test Case 4: Height History Retrieval

- [ ] Log multiple height entries over time
- [ ] Call GET `/api/v1/progress?type=height`
- [ ] Verify all height entries are returned
- [ ] Verify entries are ordered by date/time
- [ ] Display in UI (future enhancement)

---

## Migration Considerations

### Existing Users

For users who have already manually edited biological sex:
1. **Keep their current value** initially (don't force overwrite)
2. On next HealthKit sync, detect if HealthKit value differs
3. If different, log a warning and sync HealthKit value (HealthKit is source of truth)
4. Add migration note in app: "Biological sex is now managed by Apple Health"

### Height Data

For existing height values in `/users/me/physical`:
1. **Create initial progress entry** with current height
2. Use profile's `created_at` or `updated_at` as the entry date
3. Add note: "Initial height from profile"

---

## API Endpoints Used

### Physical Profile (Current)
- **PATCH** `/api/v1/users/me/physical`
  - Body: `{ "biological_sex": "male", "height_cm": 175.0 }`
  - Purpose: Store current/latest values

### Progress (New)
- **POST** `/api/v1/progress`
  - Body: `{ "type": "height", "quantity": 175.0, "date": "2025-01-27", "notes": "Updated in profile" }`
  - Purpose: Track height changes over time

- **GET** `/api/v1/progress?type=height`
  - Purpose: Retrieve height history

- **GET** `/api/v1/progress/history?type=height&start_date=2024-01-01&end_date=2025-01-27`
  - Purpose: Retrieve height history within date range

---

## Future Enhancements

### Phase 7: Height History UI (Future)
- Add "View Height History" button in profile
- Show line chart of height changes over time
- Allow adding manual height entries with dates
- Show growth rate (cm/year for children/teens)

### Phase 8: Weight Progress Integration
- Similar pattern for weight tracking
- Use `/progress` endpoint for weight time-series
- Keep latest weight in `/users/me/physical` for quick access

### Phase 9: Progress Dashboard
- Unified view of all progress metrics
- Height, weight, body fat %, BMI trends
- Export data as CSV

---

## Summary

**Key Changes:**

1. ✅ **Biological Sex:** ALWAYS immutable, ONLY from HealthKit, ONLY synced on HealthKit updates
2. ✅ **Height:** Editable in UI, tracked as time-series via `/progress` endpoint
3. ✅ **Dual Storage:** Current values in `/users/me/physical`, history in `/progress`
4. ✅ **Clean Architecture:** New use cases, ports, and adapters following existing patterns
5. ✅ **Change Detection:** Biological sex only synced when HealthKit value actually changes

**Benefits:**

- **Maximum data integrity** (biological sex NEVER editable by users, strictly from HealthKit)
- **Reduced backend traffic** (only sync biological sex when it actually changes)
- **Historical tracking** for height (growth patterns, measurement corrections)
- **Scalable architecture** for other progress metrics (weight, body fat %, etc.)
- **Consistent with backend API design** (progress tracking)
- **Clear separation of concerns** (HealthKit-only data vs user-editable data)

**Status:** Ready for implementation
**Priority:** Medium
**Estimated Effort:** 2-3 days