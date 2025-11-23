# FitIQ Workspace Documentation

This directory contains workspace-level documentation that applies to the entire FitIQ ecosystem (FitIQ app, Lume app, and FitIQCore package).

---

## 📁 Directory Structure

```
docs/
├── README.md              # This file
└── split-strategy/        # Split strategy documentation
```

---

## 📚 Documentation Categories

### Split Strategy
**Location:** [split-strategy/](./split-strategy/)  
**Purpose:** Documentation related to splitting the monolithic app into FitIQ + Lume + FitIQCore

**Key Documents:**
- **SPLIT_STRATEGY_QUICKSTART.md** - Implementation plan (moved from FitIQ root)
- **SHARED_LIBRARY_ASSESSMENT.md** - FitIQCore extraction analysis
- **SPLIT_STRATEGY_CLEANUP_COMPLETE.md** - Completion summary

**Topics Covered:**
- Rationale for split (2 focused apps vs 1 monolithic)
- Phase-by-phase implementation plan
- Shared library (FitIQCore) design
- Code reuse strategy (~15K lines shared)
- Timeline & resource estimates

---

## 🎯 Purpose

This workspace-level documentation serves multiple purposes:

### 1. Architecture Decisions
- Overall system design across all projects
- Cross-app integration patterns
- Shared infrastructure decisions

### 2. Project Strategy
- Product roadmap and phasing
- Resource allocation
- Success metrics

### 3. Cross-Project Coordination
- How FitIQ, Lume, and FitIQCore interact
- Shared backend integration
- Authentication flow across apps
- Deep linking patterns

---

## 📋 Documentation Standards

### Where to Place Documentation

**Workspace-Level (`/docs/`):**
- ✅ Overall architecture affecting all projects
- ✅ Split strategy and project organization
- ✅ Cross-project integration patterns
- ✅ Workspace-wide decisions

**Project-Specific:**
- ❌ FitIQ-only features → `FitIQ/docs/`
- ❌ Lume-only features → `lume/docs/`
- ❌ FitIQCore-only docs → `FitIQCore/docs/`

### File Organization
- **All markdown files MUST be in subdirectories** (no loose files in `/docs`)
- Group by domain/feature (e.g., `split-strategy/`, `architecture/`, etc.)
- Use clear, descriptive filenames

---

## 🔗 Related Documentation

### Project-Specific Documentation
- **FitIQ:** [../FitIQ/docs/](../FitIQ/docs/) - Fitness & nutrition app docs
- **Lume:** [../lume/docs/](../lume/docs/) - Wellness & mood app docs

### For AI Assistants
- **Copilot Instructions:** [../.github/](../.github/)
  - Quick Reference: [COPILOT_INSTRUCTIONS_UNIFIED.md](../.github/COPILOT_INSTRUCTIONS_UNIFIED.md)
  - Usage Guide: [COPILOT_INSTRUCTIONS_README.md](../.github/COPILOT_INSTRUCTIONS_README.md)

### Backend API
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **API Spec:** [../FitIQ/docs/be-api-spec/swagger.yaml](../FitIQ/docs/be-api-spec/swagger.yaml)

---

## 🎓 Quick Links

| Document | Purpose |
|----------|---------|
| [Split Strategy Quickstart](./split-strategy/SPLIT_STRATEGY_QUICKSTART.md) | Phase-by-phase implementation plan |
| [Shared Library Assessment](./split-strategy/SHARED_LIBRARY_ASSESSMENT.md) | FitIQCore extraction roadmap |
| [Cleanup Complete Summary](./split-strategy/SPLIT_STRATEGY_CLEANUP_COMPLETE.md) | Documentation organization summary |

---

## 📝 Contributing

When adding new workspace-level documentation:

1. **Determine scope:** Is it workspace-level or project-specific?
2. **Choose category:** Create or use existing subdirectory (e.g., `split-strategy/`, `architecture/`)
3. **No loose files:** All markdown files must be in subdirectories
4. **Update this README:** Add links to new categories/documents

---

**Last Updated:** 2025-11-22  
**Status:** Active
