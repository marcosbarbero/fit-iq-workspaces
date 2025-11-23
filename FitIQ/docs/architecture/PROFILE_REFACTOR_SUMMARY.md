# 🎯 FitIQ iOS Profile Refactoring - Executive Summary

**Date:** 2025-01-27  
**Version:** 1.0.0  
**Status:** 📋 Ready for Implementation  
**Priority:** 🔴 Critical

---

## 🚨 The Problem

The FitIQ iOS app's profile structure is **fundamentally misaligned** with the backend API. This causes:

- ❌ **API Integration Failures** - Sending wrong fields to backend
- ❌ **Data Model Confusion** - Mixing authentication, profile metadata, and physical attributes
- ❌ **Missing Features** - Can't access backend fields like `bio`, `language_code`
- ❌ **Wrong Endpoints** - Using incorrect API endpoints for profile updates
- ❌ **Architecture Violation** - Breaking Hexagonal Architecture principles

### Current State vs. Backend Reality

**What the app thinks:**
```swift
UserProfile {
    username, email, firstName, lastName,  // ❌ Wrong!
    weight, activityLevel,                 // ❌ Don't exist in backend!
    gender, height                         // ❌ Wrong endpoint!
}
```

**What the backend actually provides:**
```
Profile Metadata (/api/v1/users/me):
  name, bio, preferred_unit_system, language_code, date_of_birth

Physical Profile (/api/v1/users/me/physical):
  biological_sex, height_cm, date_of_birth

Auth (/api/v1/auth/login):
  access_token, refresh_token
```

---

## ✅ The Solution

**Separate concerns properly** by creating three distinct domain models:

### 1. UserProfileMetadata
- From: `GET/PUT /api/v1/users/me`
- Contains: name, bio, preferences, language
- Purpose: User's profile information

### 2. PhysicalProfile
- From: `GET/PATCH /api/v1/users/me/physical`
- Contains: biological_sex, height_cm, date_of_birth
- Purpose: Physical attributes for health tracking

### 3. UserProfile (Refactored)
- Composition of: metadata + physical
- Purpose: Complete user profile for app use
- Clean separation of concerns

---

## 📋 What We're Changing

### Domain Layer (Core Business Logic)
```
BEFORE:
UserProfile.swift (monolithic, mixed concerns)

AFTER:
Profile/
  ├── UserProfileMetadata.swift  ✨ NEW
  ├── PhysicalProfile.swift      ✨ NEW
  └── UserProfile.swift          🔄 REFACTORED
Auth/
  └── AuthToken.swift            ✨ NEW
```

### Infrastructure Layer (API Integration)
```
BEFORE:
UserProfileAPIClient.swift (mixed metadata + physical)

AFTER:
UserProfileAPIClient.swift       🔄 REFACTORED (metadata only)
PhysicalProfileAPIClient.swift   ✨ NEW (physical data)
UserAuthAPIClient.swift          🔄 UPDATED (auth only)
```

### Use Cases Layer (Business Operations)
```
NEW USE CASES:
GetUserProfileUseCase          - Fetch complete profile
UpdateProfileMetadataUseCase   - Update profile info
UpdatePhysicalProfileUseCase   - Update physical data
```

### Presentation Layer (UI)
```
ProfileViewModel.swift         🔄 REFACTORED
  - Separate state for metadata vs physical
  - Separate save methods
  - New dependencies

ProfileView.swift             🔄 UPDATED
  - Split edit form into sections
  - Better UX with clear separation
```

---

## 📊 Implementation Plan

### Timeline: 3 Weeks (15 Working Days)

| Week | Focus | Deliverables |
|------|-------|--------------|
| **Week 1** | Foundation | New domain models, DTOs, repositories |
| **Week 2** | Integration | Use cases, ViewModels, UI updates |
| **Week 3** | Validation | Migration, testing, deployment |

### Detailed Breakdown

**Week 1: Foundation**
- Day 1-2: Create new domain models (metadata, physical, auth)
- Day 3-4: Update DTOs and mapping logic
- Day 5 - Week 2 Day 1: Create/update API clients

**Week 2: Integration**
- Day 2-3: Create new use cases
- Day 4-5: Update presentation layer (ViewModels, Views)

**Week 3: Validation**
- Day 1: Wire up dependency injection
- Day 2: Handle data migration
- Day 3-5: Comprehensive testing and validation

---

## 🎯 Success Criteria

### Technical Goals
- ✅ 100% alignment with backend API structure
- ✅ Clean separation of concerns (metadata, physical, auth)
- ✅ 90%+ test coverage on new code
- ✅ Zero data loss during migration
- ✅ All existing features continue working

### User Experience Goals
- ✅ Profile loads correctly
- ✅ Profile updates work reliably
- ✅ Clear UI sections for different data types
- ✅ Better error handling
- ✅ No breaking changes for users

### Architecture Goals
- ✅ Pure Hexagonal Architecture
- ✅ Domain layer independent of infrastructure
- ✅ Clean dependency injection
- ✅ Testable, maintainable code

---

## 📈 Impact Analysis

### What Changes
1. **Domain Models** - New structure, backward-compatible computed properties
2. **API Clients** - Split into metadata and physical clients
3. **Use Cases** - New use cases for separated concerns
4. **ViewModels** - Updated to use new models and use cases
5. **UI** - Enhanced edit form with sections

### What Stays the Same
1. **User Experience** - Same functionality, better organization
2. **Local Storage** - SwiftData continues to work (with migration)
3. **HealthKit Integration** - No changes needed
4. **Authentication Flow** - Continues to work
5. **Existing Features** - Summary, metrics, etc. all work

### Breaking Changes
- `UserProfile` structure changes internally
- Use computed properties for backward compatibility where possible
- Migration handles local data transformation

---

## 🚧 Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss during migration | 🔴 High | Thorough testing, backup strategy, rollback plan |
| Regression in features | 🟡 Medium | Comprehensive test suite, manual QA |
| Backend API changes | 🟡 Medium | Use API spec as contract, version control |
| Timeline slippage | 🟢 Low | Buffer time built in, clear milestones |

---

## 📚 Documentation

Three key documents guide this refactoring:

### 1. This Document (Executive Summary)
- **Purpose:** High-level overview
- **Audience:** Team leads, stakeholders
- **Content:** Problem, solution, timeline

### 2. `PROFILE_REFACTOR_PLAN.md`
- **Purpose:** Detailed technical plan
- **Audience:** Engineers implementing the refactor
- **Content:** Architecture, code examples, decisions

### 3. `PROFILE_REFACTOR_CHECKLIST.md`
- **Purpose:** Task-by-task implementation guide
- **Audience:** Developer doing the work
- **Content:** 48 tasks with time estimates, dependencies

---

## 🚀 Next Steps

### Immediate Actions (This Week)

1. **Review & Approve** ✋
   - Team reviews this summary and detailed plan
   - Technical lead approves approach
   - Product owner aware of timeline

2. **Prepare Environment** 🛠️
   - Create feature branch: `feature/profile-refactor-v2`
   - Set up test backend environment
   - Backup current codebase

3. **Begin Phase 1** 🏗️
   - Create new domain models
   - Set up test suite
   - Start checking off tasks in checklist

### Week 1 Goals
- [ ] All domain models created and tested
- [ ] DTOs updated and tested
- [ ] API clients working

---

## 📞 Team Responsibilities

### Development Team
- Implement according to plan and checklist
- Write comprehensive tests
- Document code changes
- Communicate blockers early

### QA Team
- Review test coverage
- Manual testing on devices
- Regression testing
- Edge case validation

### Technical Lead
- Code reviews
- Architecture guidance
- Unblock technical issues
- Approve key decisions

### Product Owner
- Review UI changes
- Approve timeline
- Manage stakeholder expectations
- Prioritize if scope needs adjustment

---

## 💡 Key Insights

### Why This Matters
1. **Correctness:** App must match backend API exactly
2. **Maintainability:** Proper separation makes future changes easier
3. **Scalability:** Clean architecture supports growth
4. **Quality:** Better code = fewer bugs = better UX

### What We Learned
1. **Previous Fix Insufficient:** Quick fix solved immediate issue but revealed deeper problem
2. **API Spec is Truth:** Backend defines contract, app must conform
3. **Separation of Concerns:** Mixing different data types causes confusion
4. **Architecture Matters:** Hexagonal Architecture guides proper design

### What's Next After This
1. Continue implementing missing API features
2. Add new features (nutrition, workouts, AI)
3. Enhanced UI/UX with proper data structure
4. Better error handling and offline support

---

## 📖 Quick Reference

### Key Files to Know

**Planning Documents:**
- `docs/PROFILE_REFACTOR_SUMMARY.md` - This document
- `docs/PROFILE_REFACTOR_PLAN.md` - Detailed technical plan
- `docs/PROFILE_REFACTOR_CHECKLIST.md` - Implementation tasks

**Domain Models (New/Updated):**
- `Domain/Entities/Profile/UserProfileMetadata.swift`
- `Domain/Entities/Profile/PhysicalProfile.swift`
- `Domain/Entities/UserProfile.swift`

**API Clients:**
- `Infrastructure/Network/UserProfileAPIClient.swift`
- `Infrastructure/Network/PhysicalProfileAPIClient.swift`

**Use Cases:**
- `Domain/UseCases/Profile/GetUserProfileUseCase.swift`
- `Domain/UseCases/Profile/UpdateProfileMetadataUseCase.swift`
- `Domain/UseCases/Profile/UpdatePhysicalProfileUseCase.swift`

**ViewModels:**
- `Presentation/ViewModels/ProfileViewModel.swift`

### Helpful Commands

```bash
# Run tests
cmd + U in Xcode

# Build project
cmd + B in Xcode

# Check diagnostics
Use Xcode Issue Navigator

# View test coverage
Product > Test > Show Code Coverage
```

---

## ✨ Expected Outcome

After completing this refactoring:

✅ **Profile structure perfectly matches backend API**  
✅ **Clean separation of metadata, physical data, and auth**  
✅ **All endpoints used correctly**  
✅ **New fields (bio, language) accessible**  
✅ **Better maintainability and testability**  
✅ **Foundation for future features**  
✅ **Zero data loss for existing users**  
✅ **All existing features continue working**

---

**Status:** 📋 Planning Complete - Ready to Begin  
**Start Date:** TBD  
**Target Completion:** 3 weeks from start  
**Owner:** TBD  
**Reviewers:** TBD

---

*For detailed implementation guidance, see `PROFILE_REFACTOR_PLAN.md` and `PROFILE_REFACTOR_CHECKLIST.md`*