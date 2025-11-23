# Profile Edit - Quick Start Guide

**Version:** 1.0.0  
**Date:** 2025-01-27  
**For:** iOS Developers working on FitIQ

---

## 🚀 Quick Start

This guide gets you up to speed on the new Profile Edit implementation in 5 minutes.

---

## 📦 What's New

### Backend-Aligned Fields

**Added:**
- ✅ Bio (multi-line text, 500 char max)
- ✅ Date of Birth (with graphical picker)
- ✅ Preferred Unit System (Metric/Imperial)
- ✅ Language (EN/ES/PT/FR/DE)
- ✅ Biological Sex (renamed from "Gender")

**Removed:**
- ❌ Weight (moved to progress tracking)
- ❌ Activity Level (not in backend API)

---

## 🎯 How to Use

### Load Profile Data

```swift
// In ProfileView or similar
Task {
    await profileViewModel.loadUserProfile()
}
```

### Save Profile Changes

```swift
// When user taps "Save Changes"
Task {
    await profileViewModel.saveProfile()
}
```

That's it! The ViewModel handles:
- Validation
- Local storage
- Event publishing
- Error handling
- Success messages

---

## 📋 ProfileViewModel Properties

### Personal Information
```swift
@Published var name: String = ""           // Required
@Published var bio: String = ""            // Optional, max 500 chars
@Published var dateOfBirth: Date           // Optional
```

### Physical Profile
```swift
@Published var heightCm: String = ""       // Optional, 50-300 cm
@Published var biologicalSex: String = ""  // "male", "female", "other"
```

### Preferences
```swift
@Published var preferredUnitSystem: String = "metric"  // "metric" or "imperial"
@Published var languageCode: String = "en"             // ISO 639-1 code
```

---

## 🏗️ Architecture Flow

```
User Edits → ProfileViewModel → Use Case → Local Storage → Event Published
                                                                ↓
                                                    (Future: Sync Service → Backend API)
```

### Offline-First ✅

All changes save locally **immediately**, then sync with backend when online (future implementation).

### Event-Driven ✅

Profile changes publish domain events:
- `ProfileEvent.metadataUpdated` - Name, bio, preferences changed
- `ProfileEvent.physicalProfileUpdated` - Height, sex, DOB changed

---

## 🎨 UI Components

### CustomDateField (Enhanced)

```swift
CustomDateField(
    placeholder: "Date of Birth",
    date: $viewModel.dateOfBirth,
    iconName: "calendar",
    dateRange: ...Date()  // Past dates only
)
```

Features:
- Shows placeholder when not selected
- Displays formatted date when selected
- Expands to graphical calendar picker on tap
- Smooth animations
- Ascend Blue accent color

### EditProfileSheet Structure

```
┌─────────────────────────────────────┐
│ Personal Information (Teal)         │
│  - Name                             │
│  - Bio (text editor)                │
│  - Date of Birth                    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Physical Profile (Blue)             │
│  - Height (cm)                      │
│  - Biological Sex                   │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Preferences (Lavender)              │
│  - Unit System                      │
│  - Language                         │
└─────────────────────────────────────┘
```

---

## ✅ Validation Rules

### Automatic Validation

The use cases validate automatically:

**Name:**
- Required, cannot be empty
- Max 100 characters

**Bio:**
- Optional
- Max 500 characters

**Height:**
- Optional
- Must be 50-300 cm if provided

**Biological Sex:**
- Optional
- Must be "male", "female", or "other" if provided

**Date of Birth:**
- Optional
- Cannot be in the future
- User must be at least 13 years old

**Unit System:**
- Must be "metric" or "imperial"

**Language Code:**
- Optional
- Must be 2-3 characters if provided

---

## 🔧 Dependency Injection

### AppDependencies Wiring

```swift
// Already configured in AppDependencies.build()
let profileEventPublisher = ProfileEventPublisher()

let updateProfileMetadataUseCase = UpdateProfileMetadataUseCaseImpl(
    userProfileStorage: userProfileStorageAdapter,
    eventPublisher: profileEventPublisher
)

let updatePhysicalProfileUseCase = UpdatePhysicalProfileUseCaseImpl(
    repository: physicalProfileRepository,
    userProfileStorage: userProfileStorageAdapter,
    eventPublisher: profileEventPublisher
)

let profileViewModel = ProfileViewModel(
    getPhysicalProfileUseCase: getPhysicalProfileUseCase,
    updateUserProfileUseCase: updateUserProfileUseCase,
    updateProfileMetadataUseCase: updateProfileMetadataUseCase,
    updatePhysicalProfileUseCase: updatePhysicalProfileUseCase,
    userProfileStorage: userProfileStorageAdapter,
    authManager: authManager,
    cloudDataManager: cloudDataManager,
    getLatestHealthKitMetrics: getLatestBodyMetricsUseCase
)
```

No manual setup needed - it's all wired up!

---

## 🐛 Debugging

### Check if Profile is Loading

```swift
print("Profile: \(profileViewModel.userProfile?.name ?? "nil")")
print("Physical: \(profileViewModel.physicalProfile?.heightCm ?? 0)")
```

### Check if Events are Publishing

```swift
// Events are logged automatically:
// "ProfileEventPublisher: Published event - ProfileEvent.metadataUpdated(...)"
```

### Check Validation Errors

```swift
if let error = profileViewModel.profileUpdateMessage {
    print("Validation error: \(error)")
}
```

---

## 📚 Key Files

### Domain Layer
- `Domain/UseCases/UpdateProfileMetadataUseCase.swift` - NEW
- `Domain/UseCases/UpdatePhysicalProfileUseCase.swift` - ENHANCED
- `Domain/Events/ProfileEvents.swift` - Events
- `Domain/Ports/ProfileEventPublisherProtocol.swift` - Protocol

### Infrastructure Layer
- `Infrastructure/Integration/ProfileEventPublisher.swift` - Publisher
- `Infrastructure/Configuration/AppDependencies.swift` - DI setup

### Presentation Layer
- `Presentation/ViewModels/ProfileViewModel.swift` - ViewModel
- `Presentation/UI/Profile/ProfileView.swift` - UI
- `Presentation/UI/Landing/SignUpHelpers.swift` - CustomDateField

---

## 🎯 Common Tasks

### Add a New Profile Field

1. **Add to Domain Entity** (`UserProfileMetadata` or `PhysicalProfile`)
2. **Add to Use Case** validation and parameters
3. **Add to ViewModel** as `@Published` property
4. **Add to UI** in `EditProfileSheet`
5. **Update** backend DTO mapping (when backend integration is added)

### Listen to Profile Events

```swift
// Subscribe to profile events
profileEventPublisher.publisher
    .sink { event in
        switch event {
        case .metadataUpdated(let userId, let timestamp):
            print("Metadata updated for user \(userId) at \(timestamp)")
            // Trigger sync, update UI, etc.
            
        case .physicalProfileUpdated(let userId, let timestamp):
            print("Physical profile updated for user \(userId) at \(timestamp)")
            // Update HealthKit, trigger sync, etc.
        }
    }
    .store(in: &cancellables)
```

---

## ⏭️ What's Next?

### Phase 2: Backend Sync (Future)

1. Create `ProfileSyncService`
2. Listen to `ProfileEvent.metadataUpdated` and `ProfileEvent.physicalProfileUpdated`
3. Queue API calls when offline
4. Sync when connection restored
5. Handle conflicts

### Phase 3: HealthKit Integration (Future)

1. Update `HealthKitAdapter` to write profile data
2. Write date of birth to HealthKit
3. Write biological sex to HealthKit
4. Write height to HealthKit
5. Handle permissions gracefully

---

## 💡 Tips

1. **Always validate in the Use Case** - Never trust UI input
2. **Save locally first** - Offline-first pattern
3. **Publish events after save** - Let subscribers react
4. **Use computed properties** - Keep ViewModel clean
5. **Follow existing patterns** - Consistency is key

---

## 🆘 Getting Help

### Documentation
- `PROFILE_EDIT_IMPLEMENTATION_COMPLETE.md` - Full implementation details
- `PROFILE_EDIT_IMPLEMENTATION.md` - Original plan
- `.github/copilot-instructions.md` - Project architecture guidelines

### Code Examples
- `SaveBodyMassUseCase.swift` - Similar use case pattern
- `SummaryViewModel.swift` - Similar ViewModel pattern
- `BodyMassEntryView.swift` - Similar UI pattern

---

**Happy Coding! 🚀**

---

**Version:** 1.0.0  
**Status:** ✅ Ready for Use  
**Last Updated:** 2025-01-27