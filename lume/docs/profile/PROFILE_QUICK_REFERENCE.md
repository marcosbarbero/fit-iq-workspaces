# Profile Feature - Quick Reference Guide

**Last Updated:** 2025-01-30  
**Status:** ✅ Production Ready

---

## 🎯 Quick Overview

The Profile feature provides complete user profile management including:
- Personal information (name, bio, language, units)
- Physical attributes (date of birth, sex, height)
- Dietary preferences (allergies, restrictions, dislikes)
- Account actions (logout, deletion)

---

## 📁 File Locations

```
lume/lume/Presentation/Features/Profile/
├── ProfileViewModel.swift           # State management
├── ProfileDetailView.swift          # Main profile view
├── EditProfileView.swift            # Edit basic info
├── EditPhysicalProfileView.swift   # Edit physical attributes
└── EditPreferencesView.swift       # Edit dietary preferences
```

---

## 🚀 Usage

### Display Profile

```swift
// In MainTabView or any parent view
.sheet(isPresented: $showingProfile) {
    NavigationStack {
        ProfileDetailView(
            viewModel: dependencies.makeProfileViewModel(),
            dependencies: dependencies
        )
    }
    .presentationBackground(LumeColors.appBackground)
}
```

### Create ViewModel

```swift
// In AppDependencies
func makeProfileViewModel() -> ProfileViewModel {
    ProfileViewModel(repository: userProfileRepository)
}
```

---

## 🔄 Key Flows

### 1. Load Profile
```
User opens profile 
  → loadProfile() called
  → Fetch from cache or backend
  → Display data
```

### 2. Edit Profile
```
User taps Edit 
  → EditProfileView presented
  → User modifies fields
  → Save changes
  → Update backend & cache
  → Dismiss sheet
```

### 3. Logout
```
User taps Logout 
  → Confirmation alert
  → Clear tokens
  → Clear cache
  → End session
  → Return to auth
```

### 4. Delete Account
```
User taps Delete Account 
  → Strong confirmation
  → Backend delete
  → Clear all local data
  → End session
  → Return to auth
```

---

## 🎨 Design Specs

### Colors
- Background: `LumeColors.appBackground` (#F8F4EC)
- Surface: `LumeColors.surface` (#E8DFD6)
- Primary Text: `LumeColors.textPrimary` (#3B332C)
- Secondary Text: `LumeColors.textSecondary` (#6E625A)
- Accent: `LumeColors.accentSecondary` (#D8C8EA)

### Typography
- Title: SF Pro Rounded 20pt Semibold
- Body: SF Pro Rounded 17pt Regular
- Caption: SF Pro Rounded 13pt Regular

### Spacing
- Card padding: 20px
- Vertical spacing: 24px
- Corner radius: 12-16px

---

## 📊 State Management

### ProfileViewModel Properties

**Data:**
```swift
var profile: UserProfile?
var preferences: DietaryActivityPreferences?
```

**Loading:**
```swift
var isLoadingProfile: Bool
var isLoadingPreferences: Bool
var isSavingProfile: Bool
var isSavingPreferences: Bool
var isDeletingAccount: Bool
```

**Feedback:**
```swift
var errorMessage: String?
var showingError: Bool
var successMessage: String?
var showingSuccess: Bool
```

### Key Methods

```swift
// Profile
func loadProfile(forceRefresh: Bool = false) async
func updateProfile(...) async
func updatePhysicalProfile(...) async

// Preferences
func loadPreferences(forceRefresh: Bool = false) async
func updatePreferences(...) async
func deletePreferences() async

// Account
func deleteAccount() async -> Bool

// Utility
func refreshAll() async
func clearError()
func clearSuccess()
```

---

## 🔧 Configuration

### AppDependencies Setup

```swift
// Already configured
private(set) lazy var userProfileRepository: UserProfileRepositoryProtocol = {
    UserProfileRepository(
        modelContext: modelContext,
        backendService: userProfileBackendService,
        tokenStorage: tokenStorage
    )
}()

func makeProfileViewModel() -> ProfileViewModel {
    ProfileViewModel(repository: userProfileRepository)
}
```

---

## ✅ Features Checklist

### Personal Info
- [x] View name, email, bio
- [x] Edit name and bio
- [x] Unit system preference (Metric/Imperial)
- [x] Language preference

### Physical Profile
- [x] Date of birth with age calculation
- [x] Biological sex (optional)
- [x] Height with unit conversion
- [x] Empty state handling

### Dietary Preferences
- [x] Allergies management
- [x] Dietary restrictions
- [x] Food dislikes
- [x] Tag-based UI
- [x] Delete all preferences

### Account Management
- [x] Logout with confirmation
- [x] Account deletion with strong warning
- [x] GDPR compliance messaging

### UX Features
- [x] Pull-to-refresh
- [x] Loading states
- [x] Error handling
- [x] Success notifications
- [x] Form validation
- [x] Auto-dismiss on success

---

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Profile not loading | Check network, verify auth token |
| Changes not saving | Verify form validation passed |
| Height conversion wrong | Check unit system preference |
| Preferences not updating | Ensure backend connectivity |
| Logout fails | Check token storage access |

---

## 🔐 Security Notes

- ✅ Tokens stored in Keychain
- ✅ HTTPS-only communication
- ✅ No logging of sensitive data
- ✅ Proper token refresh handling
- ✅ GDPR-compliant deletion

---

## 📝 Testing

### Manual Testing Checklist

```
Profile Display:
[ ] Profile loads correctly
[ ] All fields display proper data
[ ] Empty states show appropriately
[ ] Pull-to-refresh works

Edit Profile:
[ ] Name validation works
[ ] Bio saves correctly
[ ] Unit system updates
[ ] Language changes persist

Physical Profile:
[ ] Date picker works
[ ] Age calculates correctly
[ ] Height conversion accurate
[ ] All fields optional

Preferences:
[ ] Can add items
[ ] Can remove items
[ ] Prevents duplicates
[ ] Delete all works

Account:
[ ] Logout clears data
[ ] Deletion shows warning
[ ] Deletion removes all data
[ ] Returns to auth correctly
```

---

## 🚧 Future Enhancements

### Phase 2 (Not Yet Implemented)
- Profile photo upload
- Email change flow
- Password change
- Settings screen
- Data export (GDPR)
- Activity history
- 2FA support

---

## 📚 Related Documentation

- **Backend Integration:** `docs/backend-integration/USER_PROFILE_BACKEND_INTEGRATION.md`
- **Full Implementation:** `docs/profile/PROFILE_UI_IMPLEMENTATION.md`
- **Architecture:** `docs/architecture/HEXAGONAL_ARCHITECTURE.md`
- **Design System:** `.github/copilot-instructions.md`

---

## 🎯 Key Takeaways

1. **Architecture:** Follows Hexagonal Architecture and SOLID principles
2. **State:** Uses Swift's @Observable for automatic UI updates
3. **Data:** Local-first with SwiftData caching
4. **Design:** Warm, calm, cozy - aligned with Lume brand
5. **Security:** Proper token management and GDPR compliance
6. **UX:** Loading states, error handling, success feedback

---

## 💡 Pro Tips

- **Force Refresh:** Pull down on profile view to force backend sync
- **Unit Conversion:** Height automatically converts between metric/imperial
- **Validation:** Name is the only required field
- **Preferences:** Use tag-based UI for better UX than lists
- **Logout vs Delete:** Logout preserves backend data, delete removes everything
- **Testing:** Use mock mode (`AppMode.useMockData = true`) for offline development

---

**Status:** ✅ Complete and Production Ready  
**Version:** 1.0.0  
**Contact:** Development Team