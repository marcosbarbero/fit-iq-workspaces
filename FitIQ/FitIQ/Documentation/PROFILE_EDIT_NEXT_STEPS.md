# Profile Edit Implementation - Next Steps

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Plan Complete - Ready for Implementation

---

## 📊 Summary of Changes Needed

Based on the backend API analysis (`/api/v1/users/me` and `/api/v1/users/me/physical`), we need to:

1. **Remove** fields that don't exist in the backend:
   - Weight (tracked via Progress API)
   - Activity Level (not in API)

2. **Add** missing backend fields:
   - Bio (text area)
   - Date of Birth (date picker)
   - Preferred Unit System (metric/imperial picker)
   - Language Code (language picker)

3. **Implement** offline-first architecture:
   - Domain events for profile changes
   - Local SwiftData storage
   - Event-driven sync with backend

4. **Update** HealthKit integration:
   - Write biological sex to HealthKit
   - Write date of birth to HealthKit
   - Write height to HealthKit

---

## ✅ Completed So Far

### Domain Events Layer
- ✅ Created `ProfileEvents.swift` - Domain event definitions
- ✅ Created `ProfileEventPublisherProtocol.swift` - Port for event publishing
- ✅ Created `ProfileEventPublisher.swift` - Concrete event publisher

### Documentation
- ✅ Created `PROFILE_EDIT_IMPLEMENTATION.md` - Comprehensive implementation plan
- ✅ This file - Next steps and summary

---

## 🚀 Implementation Priority Queue

### Priority 1: Core Use Cases (NEXT)

#### 1.1 Update Profile Metadata Use Case
**File:** `FitIQ/Domain/UseCases/UpdateProfileMetadataUseCase.swift`

**Changes needed:**
```swift
protocol UpdateProfileMetadataUseCaseProtocol {
    func execute(
        userId: String,
        name: String?,
        bio: String?,
        preferredUnitSystem: String?,
        languageCode: String?
    ) async throws -> UserProfile
}
```

**Key responsibilities:**
- Validate input (name not empty, unit system valid, etc.)
- Save to local SwiftData storage
- Publish `ProfileEvent.metadataUpdated`
- Queue sync for backend when online

#### 1.2 Create Physical Profile Use Case
**File:** `FitIQ/Domain/UseCases/UpdatePhysicalProfileUseCase.swift`

**New use case:**
```swift
protocol UpdatePhysicalProfileUseCaseProtocol {
    func execute(
        userId: String,
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile
}
```

**Key responsibilities:**
- Validate input (height range, date of birth in past, etc.)
- Save to local SwiftData storage
- Publish `ProfileEvent.physicalProfileUpdated`
- Update HealthKit with changes
- Queue sync for backend when online

### Priority 2: HealthKit Integration

#### 2.1 Update HealthKitAdapter
**File:** `FitIQ/Infrastructure/Integration/HealthKitAdapter.swift`

**Add new methods:**
```swift
// Write biological sex (HKCharacteristic)
func updateBiologicalSex(_ sex: String) async throws

// Write date of birth (HKCharacteristic)
func updateDateOfBirth(_ date: Date) async throws

// Write height (HKQuantitySample)
func updateHeight(_ heightCm: Double) async throws
```

**Implementation notes:**
- Biological sex maps: "male" → .male, "female" → .female, "other" → .other
- Date of birth stored as DateComponents
- Height stored as HKQuantity with unit .meterUnit(with: .centi)
- Request write permissions if not already granted
- Handle permission denied gracefully

### Priority 3: ViewModel Updates

#### 3.1 Update ProfileViewModel
**File:** `FitIQ/Presentation/ViewModels/ProfileViewModel.swift`

**Add new @Published properties:**
```swift
@Published var bio: String = ""
@Published var dateOfBirth: Date = Date()
@Published var preferredUnitSystem: String = "metric"
@Published var languageCode: String = "en"
```

**Remove:**
```swift
@Published var weightKg: String = "" // Move to separate progress tracking view
@Published var activityLevel: String = "" // Not in backend API
```

**Add new methods:**
```swift
@MainActor
func saveProfileMetadata() async {
    // Call UpdateProfileMetadataUseCase
    // Handle success/error
}

@MainActor
func savePhysicalProfile() async {
    // Call UpdatePhysicalProfileUseCase
    // Handle success/error
}
```

**Update existing methods:**
```swift
// Update loadUserProfile() to load new fields
// Update cancelEditing() to restore new fields
```

### Priority 4: UI Updates

#### 4.1 Update EditProfileSheet
**File:** `FitIQ/Presentation/UI/Profile/ProfileView.swift`

**New UI Structure:**

```
┌─────────────────────────────────────────────┐
│ Personal Information (Vitality Teal icon)   │
├─────────────────────────────────────────────┤
│ 👤 Name: [John Doe_____________]            │
│                                             │
│ 📝 Bio:                                     │
│    [Multi-line text editor                  │
│     for user bio and                        │
│     description...]                         │
│                                             │
│ 📅 Date of Birth: [Jan 15, 1990] 📆        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Physical Profile (Ascend Blue icon)         │
├─────────────────────────────────────────────┤
│ ↕️ Height: [180.5] cm                       │
│                                             │
│ ⚧ Biological Sex: [Male ▼]                 │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Preferences (Serenity Lavender icon)        │
├─────────────────────────────────────────────┤
│ 📏 Unit System: [Metric ▼]                 │
│                                             │
│ 🌐 Language: [English ▼]                   │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         [Save Changes] (Ascend Blue)        │
└─────────────────────────────────────────────┘
```

**New UI components needed:**
1. Multi-line text editor for bio
2. Date picker for date of birth
3. Picker for unit system (metric/imperial)
4. Picker for language (en/es/pt-BR/fr/de)

**Remove:**
- Weight field (move to progress tracking)
- Activity level field (not in API)

**UX Colors to use:**
- Personal Info header: Vitality Teal (#00C896)
- Physical Profile header: Ascend Blue (#007AFF)
- Preferences header: Serenity Lavender (#B58BEF)
- Save button: Ascend Blue (#007AFF)
- Cancel button: Secondary gray

### Priority 5: Offline Sync Service

#### 5.1 Create ProfileSyncService
**File:** `FitIQ/Infrastructure/Integration/ProfileSyncService.swift`

**Purpose:** Handle offline-first sync of profile changes with backend

```swift
final class ProfileSyncService {
    private let networkClient: NetworkClientProtocol
    private let eventPublisher: ProfileEventPublisherProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Queue for pending syncs
    private var pendingMetadataSync: Set<String> = []
    private var pendingPhysicalSync: Set<String> = []
    
    init(
        networkClient: NetworkClientProtocol,
        eventPublisher: ProfileEventPublisherProtocol
    ) {
        self.networkClient = networkClient
        self.eventPublisher = eventPublisher
        subscribeToEvents()
    }
    
    private func subscribeToEvents() {
        eventPublisher.publisher.sink { [weak self] event in
            Task {
                await self?.handleEvent(event)
            }
        }.store(in: &cancellables)
    }
    
    private func handleEvent(_ event: ProfileEvent) async {
        switch event {
        case .metadataUpdated(let userId, _):
            await syncMetadata(userId: userId)
        case .physicalProfileUpdated(let userId, _):
            await syncPhysicalProfile(userId: userId)
        }
    }
    
    private func syncMetadata(userId: String) async {
        // Try to sync with backend
        // If offline, add to pendingMetadataSync
        // If online and successful, remove from pending
    }
    
    private func syncPhysicalProfile(userId: String) async {
        // Try to sync with backend
        // If offline, add to pendingPhysicalSync
        // If online and successful, remove from pending
    }
    
    func syncAllPending() async throws {
        // Called when app comes back online
        // Process all pending syncs
    }
}
```

---

## 📝 Code Templates

### Template 1: Bio Text Editor Component

```swift
struct BioTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Text(placeholder)
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $text)
                .frame(minHeight: 100, maxHeight: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Character count
            Text("\(text.count)/500")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))
        }
    }
}
```

### Template 2: Date Picker Component

```swift
struct BirthDatePicker: View {
    @Binding var date: Date
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                DatePicker(
                    label,
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(.ascendBlue)
            }
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))
        }
    }
}
```

### Template 3: Unit System Picker

```swift
struct UnitSystemPicker: View {
    @Binding var selection: String
    
    let options = [
        ("metric", "Metric (kg, cm)"),
        ("imperial", "Imperial (lb, in)")
    ]
    
    var body: some View {
        ModernPicker(
            icon: "ruler",
            label: "Unit System",
            selection: $selection,
            options: options
        )
    }
}
```

### Template 4: Language Picker

```swift
struct LanguagePicker: View {
    @Binding var selection: String
    
    let options = [
        ("en", "English"),
        ("es", "Español"),
        ("pt-BR", "Português (BR)"),
        ("fr", "Français"),
        ("de", "Deutsch")
    ]
    
    var body: some View {
        ModernPicker(
            icon: "globe",
            label: "Language",
            selection: $selection,
            options: options
        )
    }
}
```

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] UpdateProfileMetadataUseCase validation
- [ ] UpdatePhysicalProfileUseCase validation
- [ ] Event publishing works correctly
- [ ] HealthKit write methods work
- [ ] Sync service queuing logic

### Integration Tests
- [ ] Save profile metadata → SwiftData → Event published
- [ ] Save physical profile → SwiftData → HealthKit → Event published
- [ ] Offline edit → Queue for sync → Online → Sync completes
- [ ] Conflict resolution (local vs server changes)

### UI Tests
- [ ] Edit each field and save successfully
- [ ] Validation errors display correctly
- [ ] Cancel restores original values
- [ ] Date picker date range works (can't select future dates)
- [ ] Pickers show correct options
- [ ] Bio character limit enforced

### Manual Tests
- [ ] Turn off network → Edit profile → Turn on network → Verify sync
- [ ] Verify HealthKit app shows updated data
- [ ] Verify backend API receives correct data format
- [ ] Test with each language option
- [ ] Test with each unit system option

---

## 🔄 Migration Steps for Existing Users

1. **Data migration:**
   - Existing users may have weight/activity level in local profile
   - Create migration script to move weight to progress logs
   - Remove activity level (not used)

2. **Default values:**
   - Set default unit system based on locale (US → imperial, others → metric)
   - Set default language based on device language
   - Bio defaults to empty string
   - Date of birth defaults to null (user must set)

3. **HealthKit sync:**
   - On first launch after update, prompt to sync profile to HealthKit
   - "We can now sync your profile data with HealthKit. Would you like to enable this?"

---

## 📚 Related Files to Update

### Domain Layer
- `FitIQ/Domain/Entities/Profile/UserProfile.swift` - Add bio, preferredUnitSystem, languageCode
- `FitIQ/Domain/Entities/Profile/PhysicalProfile.swift` - Already has needed fields ✅

### Infrastructure Layer
- `FitIQ/Infrastructure/Integration/HealthKitAdapter.swift` - Add write methods
- `FitIQ/Infrastructure/Network/DTOs/UserProfileDTOs.swift` - Add new fields to DTOs
- `FitIQ/Infrastructure/Persistence/SwiftDataUserProfileAdapter.swift` - Update save/fetch

### Presentation Layer
- `FitIQ/Presentation/ViewModels/ProfileViewModel.swift` - Add new fields and methods
- `FitIQ/Presentation/UI/Profile/ProfileView.swift` - Update UI sections

### DI Layer
- `FitIQ/DI/AppDependencies.swift` - Register ProfileEventPublisher and ProfileSyncService

---

## 🎯 Definition of Done

✅ Profile edit view matches backend API structure exactly
✅ All fields from `/api/v1/users/me` are editable
✅ All fields from `/api/v1/users/me/physical` are editable
✅ Weight and activity level removed from profile
✅ Offline-first: changes save locally immediately
✅ Event system publishes profile change events
✅ HealthKit updated with biological sex, date of birth, height
✅ Sync service queues changes when offline
✅ Sync service processes queue when back online
✅ UI follows UX color guidelines (Ascend Blue, Vitality Teal, etc.)
✅ All validation works correctly
✅ Unit tests pass
✅ Integration tests pass
✅ Manual testing checklist complete

---

## 🚦 Getting Started

**Start with Priority 1:** Create the use cases

1. Open `FitIQ/Domain/UseCases/UpdateProfileMetadataUseCase.swift`
2. Implement the protocol and class following the pattern in `UpdateUserProfileUseCase.swift`
3. Add event publishing after successful save
4. Add validation for all fields

**Then move to Priority 2:** HealthKit integration

**Then Priority 3:** ViewModel updates

**Then Priority 4:** UI updates

**Finally Priority 5:** Sync service

---

## 📞 Questions to Resolve

1. **Bio character limit:** 500 characters sufficient?
2. **Date of birth required?** Or can it be optional?
3. **Language switching:** Should app language change immediately or require restart?
4. **Unit system switching:** Should affect all existing progress data display?
5. **Conflict resolution:** If user edits offline and server has newer data, which wins?

---

## 🎉 Success Criteria

When done, the user should be able to:
- ✅ Edit their full name
- ✅ Add/edit a personal bio
- ✅ Set their date of birth
- ✅ Update their height
- ✅ Set their biological sex
- ✅ Choose metric or imperial units
- ✅ Select their preferred language
- ✅ Save changes offline
- ✅ See changes sync automatically when online
- ✅ View updated data in HealthKit app (for applicable fields)

And the system should:
- ✅ Store all data locally in SwiftData
- ✅ Publish events when profile changes
- ✅ Sync with backend when online
- ✅ Update HealthKit with relevant data
- ✅ Handle conflicts gracefully
- ✅ Provide clear error messages

---

**Ready to implement!** 🚀

Start with the use cases and work your way through the priority queue.