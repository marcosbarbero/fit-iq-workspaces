# Documentation Organization Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Standard for organizing documentation across FitIQ workspace

---

## 📋 Overview

This workspace contains three main components:
- **FitIQ** - iOS fitness tracking app
- **Lume** - iOS mental wellness app  
- **FitIQCore** - Shared Swift package library

Each component has its own `docs/` directory, and the workspace root has a shared `docs/` directory for cross-cutting concerns.

---

## 🎯 Core Principle

**NEVER place documentation files (`.md` files) directly in project root directories.**

✅ **Correct:**
```
FitIQ/docs/fixes/CAMERA_FIX_V2.md
lume/docs/troubleshooting/WORKSPACE_PHANTOM_FILES_RESOLUTION.md
docs/split-strategy/IMPLEMENTATION_STATUS.md
FitIQ/README.md (exception)
```

❌ **Wrong:**
```
FitIQ/CAMERA_FIX_V2.md (root level)
lume/STATUS_REPORT.md (root level)
FitIQ/docs/STATUS.md (no subdirectory)
```

---

## 📁 Documentation Hierarchy

```
fit-iq-workspaces/
├── docs/                           # Workspace-level documentation
│   ├── split-strategy/             # FitIQCore extraction strategy
│   ├── workspace/                  # Workspace setup & configuration
│   └── DOCUMENTATION_ORGANIZATION.md (this file)
│
├── FitIQ/
│   ├── README.md                   # Project overview (REQUIRED)
│   └── docs/                       # FitIQ-specific documentation
│       ├── architecture/           # Architecture decisions & patterns
│       ├── features/               # Feature implementation docs
│       ├── fixes/                  # Bug fixes & solutions
│       ├── troubleshooting/        # Debugging guides
│       ├── api-integration/        # Backend API integration
│       ├── handoffs/               # Team handoff documents
│       └── archive/                # Historical/deprecated docs
│
├── lume/
│   ├── README.md                   # Project overview (REQUIRED)
│   └── docs/                       # Lume-specific documentation
│       ├── architecture/           # Architecture decisions & patterns
│       ├── features/               # Feature implementation docs
│       ├── fixes/                  # Bug fixes & solutions
│       ├── troubleshooting/        # Debugging guides
│       ├── backend-integration/    # Backend API integration
│       ├── ai-powered-features/    # AI-specific features
│       └── outbox-migration/       # Outbox Pattern migration docs
│
└── FitIQCore/
    ├── README.md                   # Package overview (REQUIRED)
    ├── CHANGELOG.md                # Version history (REQUIRED)
    └── docs/                       # FitIQCore-specific documentation
        ├── architecture/           # Package design & patterns
        ├── api/                    # Public API documentation
        └── migration/              # Migration guides
```

---

## 🗂️ Documentation Placement Rules

### Rule 1: Scope-Based Placement

**Question:** Where does this documentation belong?

| If documentation is about... | Place it in... | Example |
|------------------------------|----------------|---------|
| FitIQ-only feature/fix | `FitIQ/docs/[category]/` | `FitIQ/docs/fixes/CAMERA_FIX_V2.md` |
| Lume-only feature/fix | `lume/docs/[category]/` | `lume/docs/troubleshooting/WORKSPACE_PHANTOM_FILES_RESOLUTION.md` |
| FitIQCore package | `FitIQCore/docs/[category]/` | `FitIQCore/docs/architecture/OUTBOX_PATTERN.md` |
| Cross-project concerns | `docs/[category]/` | `docs/split-strategy/IMPLEMENTATION_STATUS.md` |
| Workspace setup | `docs/workspace/` | `docs/workspace/SETUP_GUIDE.md` |

### Rule 2: Category-Based Organization

Every documentation file must be in a descriptive subdirectory:

| Category | Purpose | Examples |
|----------|---------|----------|
| `architecture/` | Design decisions, patterns, ADRs | Architecture patterns, design docs |
| `features/` | Feature implementation details | Feature specs, implementation guides |
| `fixes/` | Bug fixes and solutions | Specific bug fix documentation |
| `troubleshooting/` | Debugging and problem-solving | Issue resolution, diagnostic guides |
| `api-integration/` | Backend API integration | API client docs, integration guides |
| `backend-integration/` | Backend service integration | Service setup, backend comms |
| `handoffs/` | Team communication | Status reports for other teams |
| `archive/` | Deprecated/historical docs | Old docs kept for reference |
| `migration/` | Migration guides | Version upgrade guides |
| `testing/` | Testing documentation | Test plans, testing guides |
| `status/` | Project status reports | Status updates, progress reports |

### Rule 3: README.md Exception

**Only exception to root-level rule:** Each project/package MUST have a `README.md` in its root:

✅ **Required:**
- `FitIQ/README.md` - Overview of FitIQ app
- `lume/README.md` - Overview of Lume app
- `FitIQCore/README.md` - Overview of shared package
- `fit-iq-workspaces/README.md` - Overview of entire workspace

These are the ONLY files allowed at root level.

---

## ✅ Examples: Correct Placement

### FitIQ-Specific Documentation

```
✅ FitIQ/docs/fixes/CAMERA_FIX_V2.md
✅ FitIQ/docs/features/NUTRITION_LOGGING_PHASE1_SUMMARY.md
✅ FitIQ/docs/architecture/OUTBOX_PATTERN_COMPLETE_SUMMARY.md
✅ FitIQ/docs/troubleshooting/HEALTHKIT_DEDUPLICATION_FIX.md
✅ FitIQ/docs/handoffs/ACTION_SUMMARY_FOR_BACKEND_TEAM.md
```

### Lume-Specific Documentation

```
✅ lume/docs/troubleshooting/WORKSPACE_PHANTOM_FILES_RESOLUTION.md
✅ lume/docs/outbox-migration/MIGRATION_COMPLETE.md
✅ lume/docs/features/MOOD_TRACKING_COMPLETE.md
✅ lume/docs/backend-integration/OUTBOX_IMPLEMENTATION_SUMMARY.md
✅ lume/docs/ai-powered-features/AI_FEATURES_STATUS.md
```

### Cross-Project Documentation

```
✅ docs/split-strategy/IMPLEMENTATION_STATUS.md
✅ docs/split-strategy/FITIQCORE_PHASE1_COMPLETE.md
✅ docs/workspace/WORKSPACE_CLEANUP_GUIDE.md
```

### FitIQCore Documentation

```
✅ FitIQCore/docs/architecture/AUTHENTICATION_DESIGN.md
✅ FitIQCore/docs/api/TOKEN_REFRESH_CLIENT.md
✅ FitIQCore/docs/migration/UPGRADING_TO_V2.md
```

---

## ❌ Examples: Incorrect Placement

### Root-Level Files (NEVER)

```
❌ FitIQ/STATUS_REPORT.md                    → Use: FitIQ/docs/status/STATUS_REPORT.md
❌ lume/MIGRATION_COMPLETE.md                → Use: lume/docs/outbox-migration/MIGRATION_COMPLETE.md
❌ FitIQ/CAMERA_FIX.md                       → Use: FitIQ/docs/fixes/CAMERA_FIX.md
❌ lume/TROUBLESHOOTING.md                   → Use: lume/docs/troubleshooting/SPECIFIC_ISSUE.md
```

### No Subdirectory (NEVER)

```
❌ FitIQ/docs/STATUS.md                      → Use: FitIQ/docs/status/STATUS.md
❌ lume/docs/OUTBOX_MIGRATION.md             → Use: lume/docs/outbox-migration/MIGRATION_GUIDE.md
❌ docs/IMPLEMENTATION.md                    → Use: docs/split-strategy/IMPLEMENTATION_STATUS.md
```

### Wrong Scope

```
❌ docs/CAMERA_FIX_V2.md                     → Use: FitIQ/docs/fixes/CAMERA_FIX_V2.md (FitIQ-specific)
❌ FitIQ/docs/LUME_OUTBOX_MIGRATION.md       → Use: lume/docs/outbox-migration/MIGRATION_PLAN.md (Lume-specific)
❌ lume/docs/SHARED_LIBRARY_ASSESSMENT.md    → Use: docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md (cross-project)
```

---

## 🔍 Decision Tree: Where Should This Doc Go?

```
START: I need to create documentation
│
├─ Is it ONLY about FitIQ?
│  └─ YES → FitIQ/docs/[category]/filename.md
│
├─ Is it ONLY about Lume?
│  └─ YES → lume/docs/[category]/filename.md
│
├─ Is it ONLY about FitIQCore?
│  └─ YES → FitIQCore/docs/[category]/filename.md
│
├─ Is it about workspace setup or cross-project concerns?
│  └─ YES → docs/[category]/filename.md
│
└─ Is it a project overview README?
   └─ YES → [project]/README.md (ONLY exception to root rule)

Then choose appropriate category:
- Bug fix → fixes/
- Feature → features/
- Architecture → architecture/
- Debugging → troubleshooting/
- API integration → api-integration/ or backend-integration/
- Status update → status/ or handoffs/
- Migration guide → migration/ or outbox-migration/
- Testing → testing/
- Old docs → archive/
```

---

## 📝 Naming Conventions

### File Names

- Use `SCREAMING_SNAKE_CASE` for documentation files
- Be descriptive and specific
- Include relevant identifiers (dates, versions, issue numbers)

**Examples:**
```
✅ CAMERA_FIX_V2.md
✅ WORKSPACE_PHANTOM_FILES_RESOLUTION.md
✅ OUTBOX_MIGRATION_STATUS.md
✅ IMPLEMENTATION_STATUS.md
✅ HEALTHKIT_DEDUPLICATION_FIX.md
✅ AI_FEATURES_STATUS_2025_01_27.md
```

### Category Names

- Use lowercase with hyphens
- Be descriptive and consistent

**Examples:**
```
✅ architecture/
✅ api-integration/
✅ backend-integration/
✅ ai-powered-features/
✅ split-strategy/
✅ outbox-migration/
```

---

## 🔄 Moving Existing Documentation

If you find documentation in the wrong location:

### Step 1: Identify Correct Location

Use the decision tree above to determine the correct path.

### Step 2: Move the File

```bash
# Example: Moving FitIQ root-level doc to proper location
mv FitIQ/STATUS_REPORT.md FitIQ/docs/status/STATUS_REPORT.md

# Example: Moving Lume root-level doc to proper location
mv lume/TROUBLESHOOTING.md lume/docs/troubleshooting/SPECIFIC_ISSUE.md
```

### Step 3: Update References

Search for references to the old path and update them:

```bash
# Find references to old path
grep -r "STATUS_REPORT.md" .

# Update references in other docs, README files, etc.
```

### Step 4: Commit Changes

```bash
git add .
git commit -m "docs: Move STATUS_REPORT.md to proper location per DOCUMENTATION_ORGANIZATION.md"
```

---

## 🤖 For AI Assistants

When creating documentation:

1. **NEVER** place `.md` files directly in project root (except README.md)
2. **ALWAYS** determine correct scope (FitIQ, Lume, FitIQCore, or workspace)
3. **ALWAYS** place in appropriate category subdirectory
4. **ALWAYS** use descriptive, specific file names
5. **CHECK** this guide if unsure about placement

### Quick Reference

```markdown
# Template for AI assistants:

✅ CORRECT PATTERN:
[scope]/docs/[category]/DESCRIPTIVE_NAME.md

Where:
- scope = FitIQ | lume | FitIQCore | docs (workspace root)
- category = architecture | fixes | features | troubleshooting | etc.
- DESCRIPTIVE_NAME = Clear, specific name in SCREAMING_SNAKE_CASE

❌ NEVER DO THIS:
[scope]/FILENAME.md (root level)
[scope]/docs/FILENAME.md (no subdirectory)
```

---

## 📊 Documentation Audit

Periodically audit documentation placement:

```bash
# Find all .md files in project roots (except README.md)
find . -maxdepth 2 -name "*.md" ! -name "README.md" -type f

# Expected: Only workspace-level docs/ and project README.md files
```

If this command returns files, they need to be moved to proper subdirectories.

---

## 🎓 Best Practices

1. **Be Specific:** Use descriptive names that explain the content
2. **Keep Related Docs Together:** Group related docs in the same subdirectory
3. **Archive Old Docs:** Move outdated docs to `archive/` instead of deleting
4. **Cross-Reference:** Link to related docs using relative paths
5. **Update TOCs:** Keep README.md files updated with links to important docs

### Example README Structure

```markdown
# FitIQ iOS App

## Documentation

- [Architecture](docs/architecture/) - Design patterns and decisions
- [Features](docs/features/) - Feature implementation guides
- [Fixes](docs/fixes/) - Bug fix documentation
- [Troubleshooting](docs/troubleshooting/) - Debugging guides
- [API Integration](docs/api-integration/) - Backend integration docs

## Key Documents

- [Outbox Pattern Architecture](docs/architecture/OUTBOX_PATTERN_COMPLETE_SUMMARY.md)
- [Camera Fix V2](docs/fixes/CAMERA_FIX_V2.md)
- [Nutrition Logging Phase 1](docs/features/NUTRITION_LOGGING_PHASE1_SUMMARY.md)
```

---

## ✅ Enforcement

This documentation organization standard is **mandatory** for:

- ✅ All new documentation
- ✅ All AI-generated documentation
- ✅ All team-created documentation
- ✅ All migration/refactoring work

Violations should be caught in code review and fixed before merging.

---

## 📚 Related Documents

- [copilot-instructions.md](../.github/copilot-instructions.md) - AI assistant guidelines
- [COPILOT_INSTRUCTIONS_UNIFIED.md](../.github/COPILOT_INSTRUCTIONS_UNIFIED.md) - Quick reference for all projects
- [copilot-instructions-workspace.md](../.github/copilot-instructions-workspace.md) - Multi-project workspace guidelines

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Maintained By:** Engineering Team  
**Status:** ✅ Active Standard