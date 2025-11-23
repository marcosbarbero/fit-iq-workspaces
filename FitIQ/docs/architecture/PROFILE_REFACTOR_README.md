# 📚 FitIQ Profile Refactoring - Documentation Index

**Date:** 2025-01-27  
**Version:** 1.0.0  
**Status:** 📋 Ready for Implementation  
**Priority:** 🔴 Critical

---

## 🎯 Overview

This directory contains complete documentation for refactoring the FitIQ iOS app's profile structure to properly align with the backend API.

**The Problem:** App's profile model mixes concerns (auth + metadata + physical) and doesn't match backend API structure.

**The Solution:** Separate concerns into three distinct models that perfectly align with backend endpoints.

**Timeline:** 3 weeks (15 working days)

---

## 📖 Documentation Structure

### 🚀 Start Here

**If you're implementing this refactoring, read documents in this order:**

1. **[PROFILE_REFACTOR_QUICKSTART.md](./PROFILE_REFACTOR_QUICKSTART.md)** ⏱️ 10 min  
   **Purpose:** Get started quickly with setup and first steps  
   **Audience:** Developer doing the work  
   **Read:** First, before anything else

2. **[PROFILE_REFACTOR_SUMMARY.md](./PROFILE_REFACTOR_SUMMARY.md)** ⏱️ 15 min  
   **Purpose:** Executive summary of what, why, and timeline  
   **Audience:** Everyone (team leads, developers, stakeholders)  
   **Read:** Second, for context

3. **[PROFILE_REFACTOR_PLAN.md](./PROFILE_REFACTOR_PLAN.md)** ⏱️ 30 min  
   **Purpose:** Detailed technical plan with code examples  
   **Audience:** Engineers implementing the refactor  
   **Read:** Third, for deep understanding

### 📋 Reference Documents

**Use these during implementation:**

4. **[PROFILE_REFACTOR_CHECKLIST.md](./PROFILE_REFACTOR_CHECKLIST.md)** 📝  
   **Purpose:** Task-by-task implementation guide (48 tasks)  
   **Use:** Daily - check off tasks as you complete them  
   **Update:** Mark tasks complete, track time

5. **[PROFILE_REFACTOR_ARCHITECTURE.md](./PROFILE_REFACTOR_ARCHITECTURE.md)** 🏗️  
   **Purpose:** Visual diagrams and architecture explanation  
   **Use:** Reference when confused about structure  
   **Content:** Before/after diagrams, data flow, file structure

### 📄 Supporting Documents

6. **This File (PROFILE_REFACTOR_README.md)**  
   **Purpose:** Navigation and overview  
   **Use:** Find the right document for your need

---

## 🗺️ Quick Navigation

### By Role

**I'm the developer implementing this:**
1. Read: QUICKSTART → SUMMARY → PLAN (in that order)
2. Use: CHECKLIST (daily) + ARCHITECTURE (reference)
3. Update: CHECKLIST with progress

**I'm a technical lead reviewing this:**
- Read: SUMMARY → PLAN
- Review: ARCHITECTURE for soundness
- Monitor: CHECKLIST for progress

**I'm a product owner/stakeholder:**
- Read: SUMMARY (first 3 sections)
- Monitor: CHECKLIST progress tracking

**I'm QA/testing:**
- Read: SUMMARY + PLAN (testing sections)
- Focus: Phase 8 in CHECKLIST

### By Question

**"What's this all about?"** → SUMMARY  
**"How do I get started?"** → QUICKSTART  
**"What exactly do I need to build?"** → PLAN  
**"What's the next task?"** → CHECKLIST  
**"How does the architecture work?"** → ARCHITECTURE  
**"Where are all the docs?"** → This file (README)

---

## 📊 Document Comparison

| Document | Length | Purpose | When to Read | Update Frequency |
|----------|--------|---------|--------------|------------------|
| **QUICKSTART** | Short | Get started | Once (before starting) | Never |
| **SUMMARY** | Medium | Understand scope | Once (for context) | Never |
| **PLAN** | Long | Technical details | Once (reference often) | Rarely |
| **CHECKLIST** | Medium | Track progress | Daily | Daily |
| **ARCHITECTURE** | Medium | Visual reference | As needed | Never |
| **README** | Short | Navigation | Once | Never |

---

## 🎯 The Refactoring at a Glance

### Current State ❌

```
UserProfile (monolithic)
  ├── Auth: username, email
  ├── Profile: firstName, lastName
  ├── Physical: height, weight, gender
  ├── Preferences: preferredUnitSystem
  └── ❌ activityLevel (doesn't exist in backend!)
```

One model, mixed concerns, wrong fields, wrong endpoint.

### Target State ✅

```
UserProfileMetadata (from /api/v1/users/me)
  ├── name, bio, preferredUnitSystem, languageCode
  └── From profile endpoint

PhysicalProfile (from /api/v1/users/me/physical)
  ├── biologicalSex, heightCm, dateOfBirth
  └── From physical endpoint

UserProfile (composition)
  ├── metadata: UserProfileMetadata
  └── physical: PhysicalProfile?
```

Three models, clean separation, correct fields, correct endpoints.

---

## 📅 Timeline Overview

```
Week 1: Foundation
├── Day 1-2: Domain models
├── Day 3-4: DTOs
└── Day 5 - Week 2 Day 1: API clients

Week 2: Integration
├── Day 2-3: Use cases
└── Day 4-5: ViewModels & UI

Week 3: Validation
├── Day 1: Dependency injection
├── Day 2: Data migration
└── Day 3-5: Testing
```

**Total:** 15 working days

---

## ✅ Success Criteria

After completion:

- ✅ Profile structure matches backend API exactly
- ✅ Clean separation: metadata, physical, auth
- ✅ All endpoints used correctly
- ✅ 90%+ test coverage
- ✅ Zero data loss
- ✅ All features still work

---

## 🚀 Getting Started

### For Implementers

```bash
# 1. Read documentation
- QUICKSTART.md    (10 min)
- SUMMARY.md       (15 min)
- PLAN.md          (30 min)

# 2. Set up environment
git checkout -b feature/profile-refactor-v2
git tag backup-pre-profile-refactor

# 3. Start Phase 1
Open CHECKLIST.md
Begin with task 1.1
```

### For Reviewers

```bash
# 1. Understand scope
Read SUMMARY.md

# 2. Review technical approach
Read PLAN.md (focus on architecture sections)

# 3. Check architecture soundness
Review ARCHITECTURE.md diagrams

# 4. Approve or request changes
Provide feedback on approach
```

---

## 📝 Key Principles

### Architecture

- **Hexagonal Architecture** - Domain defines ports, infrastructure implements
- **Separation of Concerns** - Each model has one responsibility
- **Backend First** - Backend API is source of truth
- **Clean Dependencies** - Presentation → Domain ← Infrastructure

### Implementation

- **Test First** - Write tests before implementation
- **Small Commits** - Commit frequently with clear messages
- **Follow Patterns** - Examine existing code, maintain consistency
- **Document as You Go** - Update code comments

### Quality

- **90%+ Test Coverage** - New code must be well tested
- **Zero Warnings** - No compiler warnings allowed
- **SwiftLint Clean** - Linting must pass
- **Manual QA** - Test on real devices

---

## 🔗 Related Resources

### Project Documents

- **Architecture Guide:** `.github/copilot-instructions.md`
- **Integration Handoff:** `docs/IOS_INTEGRATION_HANDOFF.md`
- **API Integration:** `docs/api-integration/`

### Existing Code Patterns

- **Use Case Pattern:** `Domain/UseCases/SaveBodyMassUseCase.swift`
- **Repository Pattern:** `Infrastructure/Repositories/SwiftDataActivitySnapshotRepository.swift`
- **API Client Pattern:** `Infrastructure/Network/UserAuthAPIClient.swift`
- **ViewModel Pattern:** `Presentation/ViewModels/BodyMassEntryViewModel.swift`

### Backend Resources

- **API Spec:** Contact backend team (should be symlinked)
- **Swagger UI:** `https://fit-iq-backend.fly.dev/swagger/index.html`
- **Base URL:** `https://fit-iq-backend.fly.dev/api/v1`

---

## 📞 Support

### Questions About...

**Setup & Getting Started** → Check QUICKSTART.md  
**What to build** → Check PLAN.md  
**Next task** → Check CHECKLIST.md  
**Architecture** → Check ARCHITECTURE.md + copilot-instructions.md  
**Backend API** → Check API spec or Swagger UI  
**Existing patterns** → Examine similar files in project

### Escalation

1. **Check documentation** (this folder)
2. **Review existing code** (similar patterns)
3. **Ask team member** (specific question with context)
4. **Escalate to tech lead** (blocker or major decision)

---

## 📈 Progress Tracking

### Current Status

**Phase:** Not Started  
**Progress:** 0/48 tasks complete  
**Updated:** 2025-01-27

### Tracking Progress

Update these sections in **CHECKLIST.md**:

- Mark completed tasks with `[x]`
- Update "Phase Completion" table
- Update "Task Summary" counts
- Note blockers or issues
- Log actual time vs. estimates

### Reporting

**Daily:** Update checklist, commit progress  
**Weekly:** Review with team, adjust timeline if needed  
**Phase Complete:** Verify deliverables, celebrate! 🎉

---

## ⚠️ Important Notes

### Critical Rules

1. **Read Before Coding** - Don't skip documentation
2. **Follow Hexagonal Architecture** - Domain is pure, infrastructure implements
3. **SD Prefix Required** - All SwiftData @Model classes use `SD` prefix
4. **Backend Is Truth** - API spec defines contracts
5. **Test Everything** - 90%+ coverage on new code

### Don't Forget

- ✅ Update CHECKLIST daily
- ✅ Commit frequently
- ✅ Write tests first
- ✅ Follow existing patterns
- ✅ Document decisions
- ✅ Ask questions early

---

## 🎓 Learning Resources

### New to Hexagonal Architecture?

- Read: `.github/copilot-instructions.md`
- Review: Existing use cases and repositories
- Understand: Ports (protocols) and Adapters (implementations)

### New to This Codebase?

- Explore: `Domain/`, `Infrastructure/`, `Presentation/` structure
- Study: Existing use cases like `SaveBodyMassUseCase.swift`
- Review: Dependency injection in `AppDependencies.swift`

### New to SwiftData?

- Check: `Domain/Entities/CurrentSchema.swift`
- Remember: All @Model classes need `SD` prefix
- Review: `PersistenceHelper.swift` for schema management

---

## 🎯 Final Checklist Before Starting

Before you begin Phase 1:

- [ ] Read QUICKSTART.md
- [ ] Read SUMMARY.md
- [ ] Read PLAN.md
- [ ] Scanned CHECKLIST.md
- [ ] Reviewed ARCHITECTURE.md
- [ ] Understand Hexagonal Architecture
- [ ] Have Xcode set up
- [ ] Created feature branch
- [ ] Have backend API access
- [ ] Ready to write tests first
- [ ] Know where to get help

**All checked?** Great! Start with Phase 1, Task 1.1 in CHECKLIST.md

---

## 📄 Document Changelog

| Date | Document | Change |
|------|----------|--------|
| 2025-01-27 | All | Initial creation |

---

## 🏆 Completion Celebration

When all tasks are done:

- [ ] All tests passing
- [ ] Zero warnings
- [ ] Documentation complete
- [ ] Code reviewed
- [ ] Merged to main
- [ ] Deployed to production

**Then:** Celebrate! 🎉 You've successfully refactored a critical part of the app with clean architecture!

---

**Ready to begin? Start with [PROFILE_REFACTOR_QUICKSTART.md](./PROFILE_REFACTOR_QUICKSTART.md)!**

---

**Version:** 1.0.0  
**Created:** 2025-01-27  
**Status:** ✅ Complete & Ready  
**Next Action:** Read QUICKSTART.md and begin implementation