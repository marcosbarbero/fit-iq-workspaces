# 🚀 FitIQ Profile Refactoring - Quick Start Guide

**Date:** 2025-01-27  
**Version:** 1.0.0  
**For:** Developer implementing the refactoring  
**Time to Read:** 10 minutes

---

## 🎯 What You're About to Do

You're going to refactor the FitIQ iOS app's profile structure to properly align with the backend API. This guide gets you started quickly.

---

## 📚 Read These First (in order)

1. **This document** (10 min) - Quick overview and setup
2. `PROFILE_REFACTOR_SUMMARY.md` (15 min) - What and why
3. `PROFILE_REFACTOR_PLAN.md` (30 min) - Detailed technical plan
4. `PROFILE_REFACTOR_CHECKLIST.md` (reference) - Task list
5. `PROFILE_REFACTOR_ARCHITECTURE.md` (reference) - Visual diagrams

**Total reading time: ~1 hour before you write any code**

---

## 🏁 Before You Start

### ✅ Prerequisites

- [ ] Read and understand the documents above
- [ ] Have Xcode 15+ installed
- [ ] Project compiles without errors
- [ ] Familiar with Hexagonal Architecture (see `.github/copilot-instructions.md`)
- [ ] Access to backend API documentation
- [ ] Test backend environment available

### 🛠️ Setup Your Environment

```bash
# 1. Create feature branch
git checkout -p
git checkout -b feature/profile-refactor-v2

# 2. Backup current state
git tag backup-pre-profile-refactor

# 3. Pull latest changes
git pull origin main

# 4. Build to ensure everything works
# Open in Xcode, then: cmd + B
```

### 📋 Tools You'll Need

- **Xcode:** For development
- **Terminal:** For Git commands
- **API Testing Tool:** Postman/Insomnia (optional)
- **Backend Access:** Test environment credentials
- **This Checklist:** `PROFILE_REFACTOR_CHECKLIST.md`

---

## 🎯 The 3-Week Plan at a Glance

### Week 1: Foundation (Domain & Infrastructure)
**Goal:** New models and API clients working

- Day 1-2: Create domain models
- Day 3-4: Update DTOs
- Day 5 - Week 2 Day 1: Create/update API clients

**Deliverable:** Backend integration working at infrastructure level

### Week 2: Integration (Use Cases & Presentation)
**Goal:** Business logic and UI updated

- Day 2-3: Create use cases
- Day 4-5: Update ViewModels and UI

**Deliverable:** Complete user flow working

### Week 3: Polish (Migration & Testing)
**Goal:** Production-ready code

- Day 1: Dependency injection
- Day 2: Data migration
- Day 3-5: Comprehensive testing

**Deliverable:** Tested, documented, ready to merge

---

## 🏗️ Phase 1: Your First Day (Create Domain Models)

### What You'll Build Today

Three new domain models that separate concerns properly:

1. `UserProfileMetadata` - Profile info (name, bio, preferences)
2. `PhysicalProfile` - Physical attributes (sex, height, DOB)
3. `UserProfile` - Composition of both (refactored)

### Step-by-Step: First 2 Hours

#### 1. Create Directory Structure (5 min)

```
FitIQ/Domain/Entities/
├── Profile/          # CREATE THIS
│   ├── UserProfileMetadata.swift
│   ├── PhysicalProfile.swift
│   └── (UserProfile.swift moves here)
└── Auth/             # CREATE THIS
    └── AuthToken.swift
```

In Xcode:
- Right-click `Domain/Entities` → New Group → "Profile"
- Right-click `Domain/Entities` → New Group → "Auth"

#### 2. Create UserProfileMetadata.swift (30 min)

**File:** `Domain/Entities/Profile/UserProfileMetadata.swift`

```swift
import Foundation

/// Profile metadata from GET/PUT /api/v1/users/me
/// This contains user's profile information (name, bio, preferences)
/// Separate from physical attributes and authentication data.
public struct UserProfileMetadata: Identifiable, Equatable {
    // MARK: - Properties
    
    /// Profile ID (from backend)
    public let id: UUID
    
    /// User ID (from JWT/auth)
    public let userId: UUID
    
    /// Full name (REQUIRED by backend)
    public let name: String
    
    /// Biography/description (optional)
    public let bio: String?
    
    /// Unit preference: "metric" or "imperial" (REQUIRED by backend)
    public let preferredUnitSystem: String
    
    /// Language preference: "en", "pt", etc. (optional)
    public let languageCode: String?
    
    /// Date of birth (optional, may also be in physical profile)
    public let dateOfBirth: Date?
    
    /// Profile creation timestamp
    public let createdAt: Date
    
    /// Last update timestamp
    public let updatedAt: Date
    
    // MARK: - Initializer
    
    public init(
        id: UUID,
        userId: UUID,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?,
        dateOfBirth: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.bio = bio
        self.preferredUnitSystem = preferredUnitSystem
        self.languageCode = languageCode
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

**Test it compiles:** `cmd + B`

#### 3. Create PhysicalProfile.swift (20 min)

**File:** `Domain/Entities/Profile/PhysicalProfile.swift`

```swift
import Foundation

/// Physical profile data from PATCH /api/v1/users/me/physical
/// This contains physical attributes separate from profile metadata.
public struct PhysicalProfile: Equatable {
    // MARK: - Properties
    
    /// Biological sex: "male", "female", "other" (optional)
    public let biologicalSex: String?
    
    /// Height in centimeters (optional)
    public let heightCm: Double?
    
    /// Date of birth (optional, may differ from profile DOB)
    public let dateOfBirth: Date?
    
    // MARK: - Initializer
    
    public init(
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) {
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.dateOfBirth = dateOfBirth
    }
}
```

**Test it compiles:** `cmd + B`

#### 4. Create AuthToken.swift (15 min)

**File:** `Domain/Entities/Auth/AuthToken.swift`

```swift
import Foundation

/// Authentication tokens separate from profile data
public struct AuthToken: Equatable {
    // MARK: - Properties
    
    /// JWT access token
    public let accessToken: String
    
    /// Refresh token for getting new access tokens
    public let refreshToken: String
    
    /// Optional expiration time (can be parsed from JWT)
    public let expiresAt: Date?
    
    // MARK: - Initializer
    
    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
```

**Test it compiles:** `cmd + B`

#### 5. Refactor UserProfile.swift (1 hour)

**File:** `Domain/Entities/UserProfile.swift` → Move to `Domain/Entities/Profile/UserProfile.swift`

Key changes:
- Use composition (metadata + physical)
- Add computed properties for convenience
- Maintain backward compatibility where possible

See `PROFILE_REFACTOR_PLAN.md` section "3. UserProfile (REFACTORED)" for complete code.

**Test it compiles:** `cmd + B`

### ✅ End of Day 1 Checklist

- [ ] Directory structure created
- [ ] `UserProfileMetadata.swift` created
- [ ] `PhysicalProfile.swift` created
- [ ] `AuthToken.swift` created
- [ ] `UserProfile.swift` refactored
- [ ] Project compiles without errors
- [ ] Committed changes to Git

```bash
git add .
git commit -m "Phase 1 Day 1: Create new domain models for profile refactoring"
```

---

## 📝 Daily Workflow

### Every Morning

1. **Review progress**
   - Check `PROFILE_REFACTOR_CHECKLIST.md`
   - Mark completed tasks with `[x]`
   - Identify today's tasks

2. **Pull latest changes**
   ```bash
   git pull origin feature/profile-refactor-v2
   ```

3. **Review plan**
   - Read relevant section in `PROFILE_REFACTOR_PLAN.md`
   - Understand what you're building today

### During Development

1. **Follow the checklist** - Work through tasks sequentially
2. **Write tests first** - TDD approach preferred
3. **Commit frequently** - Small, focused commits
4. **Document as you go** - Update code comments
5. **Test continuously** - `cmd + B` and `cmd + U` regularly

### Every Evening

1. **Update checklist** - Mark completed tasks
2. **Commit work**
   ```bash
   git add .
   git commit -m "Phase X Day Y: [brief description]"
   git push origin feature/profile-refactor-v2
   ```

3. **Update progress table** in `PROFILE_REFACTOR_CHECKLIST.md`
4. **Note any blockers** for next day

---

## 🚨 Common Pitfalls to Avoid

### ❌ DON'T

1. **Skip reading the plan** - You'll make mistakes
2. **Change multiple layers at once** - Do domain, then infrastructure, then presentation
3. **Forget the SD prefix** - SwiftData models MUST have `SD` prefix
4. **Hardcode configuration** - Use `config.plist`
5. **Modify UI layout** - Only add field bindings (see copilot instructions)
6. **Skip tests** - Tests prevent regressions
7. **Rush through DTOs** - They're critical for backend alignment

### ✅ DO

1. **Examine existing code first** - Follow established patterns
2. **Work in phases** - Complete one layer before moving to next
3. **Test incrementally** - Test after each major change
4. **Commit frequently** - Small commits are easier to review/revert
5. **Ask questions early** - Don't waste time stuck
6. **Document decisions** - Update plan if you deviate
7. **Keep copilot instructions open** - Reference frequently

---

## 🧪 Testing Strategy

### Unit Tests (Write First!)

Before implementing each component:

```swift
// 1. Write the test
func testUserProfileMetadataInitialization() {
    let metadata = UserProfileMetadata(
        id: UUID(),
        userId: UUID(),
        name: "John Doe",
        bio: "Test bio",
        preferredUnitSystem: "metric",
        languageCode: "en",
        dateOfBirth: Date(),
        createdAt: Date(),
        updatedAt: Date()
    )
    
    XCTAssertEqual(metadata.name, "John Doe")
    XCTAssertEqual(metadata.preferredUnitSystem, "metric")
}

// 2. Watch it fail (no implementation yet)
// 3. Implement the code
// 4. Watch it pass
```

### Integration Tests (After API Clients Work)

Test real API calls:

```swift
func testFetchProfileMetadata() async throws {
    let client = UserProfileAPIClient(/* ... */)
    let metadata = try await client.getProfileMetadata()
    XCTAssertFalse(metadata.name.isEmpty)
}
```

### Manual Testing (Daily)

Build and run on device:
- Profile loads
- Edit works
- Save succeeds
- Errors display correctly

---

## 📞 Getting Help

### Resources

1. **Architecture Questions:** `.github/copilot-instructions.md`
2. **Backend API:** Check Swagger or API spec
3. **Existing Patterns:** Look at `SaveBodyMassUseCase.swift`, `HealthKitAdapter.swift`
4. **Swift/SwiftUI:** Apple documentation

### When Stuck

1. **Read the relevant plan section** again
2. **Check existing similar code** in the project
3. **Review test cases** - they show expected behavior
4. **Ask specific questions** with context

### Escalation Path

1. Check documentation (this guide, plan, architecture)
2. Review existing code for patterns
3. Ask team member
4. Escalate to technical lead

---

## 🎯 Success Indicators

### You're On Track If...

- [ ] Checklist tasks completed daily
- [ ] All tests passing (`cmd + U`)
- [ ] Project builds without errors (`cmd + B`)
- [ ] Git commits daily
- [ ] Following architecture patterns
- [ ] No force unwraps (`!`) in new code
- [ ] Documentation updated

### You're Behind If...

- Tasks taking 2x+ estimated time
- Multiple test failures
- Compiler errors accumulating
- Skipping tests to save time
- Deviating from plan without documenting

**Action:** Review approach, ask for help, adjust timeline

---

## 📅 Milestones

### Week 1 End
- [ ] All domain models created and tested
- [ ] DTOs updated and tested
- [ ] API clients working and tested
- [ ] Can fetch profile from backend successfully

### Week 2 End
- [ ] All use cases implemented and tested
- [ ] ViewModels updated
- [ ] UI updated with sections
- [ ] Can save profile successfully

### Week 3 End
- [ ] Dependencies wired correctly
- [ ] Data migration working
- [ ] All tests passing (unit, integration, UI)
- [ ] Manual QA complete
- [ ] Documentation updated
- [ ] Ready to merge

---

## 🚀 Let's Go!

### Your Action Plan Right Now

1. **Read all planning documents** (~1 hour)
2. **Set up your environment** (30 min)
3. **Start Phase 1** - Create domain models (rest of day)
4. **Commit your work** (end of day)
5. **Update checklist** (5 min)

### Tomorrow Morning

1. Pull latest changes
2. Review Phase 1 Day 2 tasks
3. Continue with DTOs and mapping
4. Keep building!

---

## 💪 You Got This!

This is a well-planned, structured refactoring. Follow the plan, work methodically, test thoroughly, and you'll have clean, maintainable code that perfectly aligns with the backend API.

**The refactoring might seem big, but you're eating the elephant one bite at a time. Each phase builds on the previous one. Stay focused, follow the checklist, and you'll succeed!**

---

**Questions? Check the other docs. Stuck? Ask for help. Making progress? Update the checklist!**

**Good luck! 🚀**

---

**Last Updated:** 2025-01-27  
**Next Action:** Read planning documents, then start Phase 1  
**Estimated Start Time:** [Your start time]  
**Estimated Completion:** 3 weeks from start