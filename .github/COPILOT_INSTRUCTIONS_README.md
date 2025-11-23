# Copilot Instructions - Guide

**Version:** 1.1.0  
**Last Updated:** 2025-01-27  

This directory contains AI assistant instructions for working with the FitIQ workspace.

---

## 📚 Available Instructions

### 1. `copilot-instructions.md` (FitIQ-Specific)
**Purpose:** Detailed instructions for working on the FitIQ app  
**Scope:** FitIQ app only (fitness & nutrition features)  
**Size:** ~1,260+ lines  
**Use when:** Working exclusively on FitIQ app features

**Key Sections:**
- Related instruction documents (NEW)
- FitIQ project structure
- Hexagonal architecture implementation
- SwiftData schema with SD prefix
- Outbox Pattern for sync
- Repository and Use Case patterns
- Network client patterns
- Dependency injection
- Testing guidelines
- FitIQCore integration resources (NEW)

---

### 2. `copilot-instructions-workspace.md` (Workspace-Level)
**Purpose:** Instructions for working across the entire workspace  
**Scope:** FitIQ app + Lume app + FitIQCore package  
**Size:** ~713 lines  
**Use when:** Working on multi-project features or shared infrastructure

**Key Sections:**
- Workspace overview (3 projects)
- Determining which project to modify
- FitIQCore package guidelines
- Cross-app integration
- Backend unity (shared API)
- Design language differences
- Deep linking between apps
- Authentication flow (shared via FitIQCore)

---

### 3. `COPILOT_INSTRUCTIONS_UNIFIED.md` (Quick Reference)
**Purpose:** Unified reference combining all instructions  
**Scope:** All projects with clear distinctions  
**Size:** ~600+ lines  
**Use when:** Need a comprehensive overview or quick reference

**Key Sections:**
- Quick decision tree: Which project to modify?
- FitIQ app rules
- Lume app rules
- FitIQCore package rules
- Shared architecture principles
- Common patterns
- Critical rules (NEVER/ALWAYS)
- FitIQCore resources and links (NEW)

---

### 4. `COPILOT_INSTRUCTIONS_README.md` (This File)
**Purpose:** Guide to using instruction documents  
**Scope:** Meta-documentation  
**Use when:** Unsure which instruction file to consult

**Key Sections:**
- Available instructions overview
- Scenario-based recommendations
- Cross-references between documents
- Update guidelines

---

## 🎯 Which Instructions to Use?

### Scenario 1: Working on FitIQ App Only
**Use:** `copilot-instructions.md`  
**Example:** Adding nutrition tracking features, workout templates, body metrics

### Scenario 2: Working on Lume App Only
**Use:** `COPILOT_INSTRUCTIONS_UNIFIED.md` → Lume App Rules section  
**Example:** Adding mood tracking, wellness templates, mindfulness features  
**Status:** ⏳ Planned for Phase 4

### Scenario 3: Working on FitIQCore Shared Package
**Use:** `FitIQCore/README.md` + `COPILOT_INSTRUCTIONS_UNIFIED.md` → FitIQCore Rules  
**Example:** Authentication, networking, error handling, HealthKit (Phase 2)  
**Status:** ✅ Phase 1 Complete (Auth + Network)

### Scenario 4: Working on Shared Infrastructure
**Use:** `copilot-instructions-workspace.md`  
**Example:** Cross-project patterns, API client integration, profile sync

### Scenario 5: Integrating FitIQCore into FitIQ
**Use:** `docs/split-strategy/FITIQ_INTEGRATION_GUIDE.md` + `copilot-instructions.md`  
**Example:** Migrating auth to FitIQCore, removing duplicated code  
**Status:** ⏳ Next Phase (3-5 days)

### Scenario 6: Working Across Multiple Projects
**Use:** `copilot-instructions-workspace.md` OR `COPILOT_INSTRUCTIONS_UNIFIED.md`  
**Example:** Implementing cross-app features, deep linking, profile sync

### Scenario 7: Quick Reference
**Use:** `COPILOT_INSTRUCTIONS_UNIFIED.md`  
**Example:** Need to quickly understand project structure or critical rules

---

## 🔄 Instructions Hierarchy

```
.github/
├── COPILOT_INSTRUCTIONS_README.md (This file - Usage guide)
├── COPILOT_INSTRUCTIONS_UNIFIED.md (Quick reference, all projects)
├── copilot-instructions.md (FitIQ-specific, detailed)
└── copilot-instructions-workspace.md (Workspace-level, detailed)

FitIQCore/
├── README.md (Package documentation)
└── CHANGELOG.md (Version history)

docs/split-strategy/
├── FITIQCORE_PHASE1_COMPLETE.md (Implementation summary)
├── FITIQ_INTEGRATION_GUIDE.md (Integration steps)
├── IMPLEMENTATION_STATUS.md (Overall progress)
└── SHARED_LIBRARY_ASSESSMENT.md (Analysis & roadmap)
```

**All documents are valid and complementary:**
- **README** (this file) = How to use instruction documents
- **Unified** = Quick reference, decision tree, all projects
- **FitIQ-specific** = Deep dive into FitIQ patterns
- **Workspace** = Multi-project coordination
- **FitIQCore docs** = Shared library documentation

---

## 🚨 Critical Rules (ALL Instructions)

These rules apply across ALL documents:

### ❌ NEVER
1. Create or update UI/Views without explicit request (except field bindings)
2. Hardcode configuration (use `config.plist`)
3. Modify `docs/api-spec.yaml` (read-only)
4. Create infrastructure before domain (domain-first)
5. Forget SD prefix on SwiftData models
6. Duplicate code between apps (use FitIQCore)
7. Break dependency direction (FitIQCore never depends on apps)

### ✅ ALWAYS
1. Examine existing code first
2. Use SD prefix for @Model classes
3. Use Outbox Pattern for outbound sync
4. Check FitIQCore before duplicating
5. Register dependencies in AppDependencies
6. Store configuration in config.plist
7. Follow Hexagonal Architecture

---

## 📋 Key Differences Between Projects

### FitIQ App
- **Focus:** Quantitative (numbers, measurements, goals)
- **Design:** Bold, energetic, performance-focused
- **Features:** Nutrition, workouts, body metrics, activity
- **Users:** Gym-goers, athletes, fitness enthusiasts

### Lume App
- **Focus:** Qualitative (feelings, states, habits)
- **Design:** Calm, soothing, mindfulness-focused
- **Features:** Mood, wellness, mindfulness, habits
- **Users:** Mindfulness seekers, wellness individuals

### FitIQCore Package
- **Focus:** Shared infrastructure
- **Contains:** Auth, API client, HealthKit, SwiftData utilities
- **Used by:** Both FitIQ and Lume

---

## 📝 Updating Instructions

When updating any instruction document:

1. **Update all three documents** if the change affects shared patterns
2. **Update specific document** if the change is project-specific
3. **Keep critical rules consistent** across all documents
4. **Update version and date** in the header
5. **Document the change** in the "Latest Change" section

---

## 🔗 Related Documentation

### Project-Specific
- **FitIQ Docs:** `FitIQ/docs/`
- **Lume Docs:** `lume/docs/`
- **FitIQCore Package:** `FitIQCore/README.md`

### FitIQCore Shared Library
- **[FitIQCore README](../FitIQCore/README.md)** - Package documentation and usage
- **[Phase 1 Complete](../docs/split-strategy/FITIQCORE_PHASE1_COMPLETE.md)** - Implementation summary
- **[Integration Guide](../docs/split-strategy/FITIQ_INTEGRATION_GUIDE.md)** - Step-by-step integration
- **[Implementation Status](../docs/split-strategy/IMPLEMENTATION_STATUS.md)** - Overall progress tracker
- **[CHANGELOG](../FitIQCore/CHANGELOG.md)** - Version history

### Split Strategy & Planning
- **[Shared Library Assessment](../docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md)** - Analysis & roadmap
- **[Split Strategy Cleanup](../docs/split-strategy/SPLIT_STRATEGY_CLEANUP_COMPLETE.md)** - Planning phase
- **Split Strategy Quickstart:** `SPLIT_STRATEGY_QUICKSTART.md`
- **Product Assessment:** `PRODUCT_ASSESSMENT.md`

### API Integration
- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **Integration Guides:** `FitIQ/docs/api-integration/`

---

## 🎓 Summary

**Three instruction documents, complementary purposes:**

| Document | Purpose | Best For |
|----------|---------|----------|
| `COPILOT_INSTRUCTIONS_UNIFIED.md` | Consolidated quick reference | Quick decisions, all projects |
| `copilot-instructions.md` | FitIQ deep dive | FitIQ-specific work |
| `copilot-instructions-workspace.md` | Workspace coordination | Multi-project features |

**All share the same core principles:**
- Hexagonal Architecture
- SD prefix for @Model classes
- Outbox Pattern for sync
- Domain-first approach
- Dependency injection

---

**Remember:** Choose the right instructions for your task, but all documents enforce the same critical rules!

---

**Version:** 1.1.0  
**Status:** ✅ Active  
**Last Updated:** 2025-01-27  
**Latest Change:** Added FitIQCore documentation references and updated scenarios with Phase 1 completion status
