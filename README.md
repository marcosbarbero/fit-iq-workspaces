# FitIQ Workspace

A comprehensive health and fitness platform consisting of two specialized iOS applications sharing a common infrastructure.

---

## 🎯 Overview

This workspace contains:
- **FitIQ** - Fitness & Nutrition Intelligence app
- **Lume** - Wellness & Mood Intelligence app (planned)
- **FitIQCore** - Shared infrastructure package (planned)

---

## 📱 Applications

### FitIQ - Fitness & Nutrition Intelligence
**Status:** ✅ Production  
**Focus:** Quantitative health metrics

**Features:**
- 📊 Activity tracking (steps, heart rate)
- ⚖️ Body metrics (weight, BMI)
- 🍎 Nutrition tracking (4,389+ foods, AI parsing)
- 💪 Workout management (100+ exercises)
- 😴 Sleep tracking
- 🎯 Goal management
- 🤖 AI Coach (fitness-focused)

**Target Users:** Gym-goers, athletes, fitness enthusiasts

### Lume - Wellness & Mood Intelligence
**Status:** 🚧 Phase 3 (Planned)  
**Focus:** Qualitative mental health

**Features:**
- 😊 Mood tracking (iOS 18 HealthKit)
- 🧘 Wellness templates
- 🌊 Stress management
- ⏸️ Mindfulness practices
- 📝 Daily habits tracking
- 💤 Recovery optimization

**Target Users:** Mindfulness seekers, wellness-focused individuals

### FitIQCore - Shared Infrastructure
**Status:** 🚧 Phase 1 (Planned)  
**Purpose:** Common code shared by both apps

**Components:**
- Authentication (JWT, Keychain)
- API client foundation
- HealthKit integration framework
- SwiftData persistence utilities
- Common UI components
- Error handling & validation

---

## 🏗️ Architecture

All projects follow **Hexagonal Architecture** (Ports & Adapters):

```
Presentation Layer (ViewModels/Views)
    ↓ depends on ↓
Domain Layer (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure Layer (Repositories, Network, Services)
```

**Key Principles:**
- Domain layer is pure business logic
- Domain defines interfaces (ports via protocols)
- Infrastructure implements interfaces (adapters)
- Dependency injection via AppDependencies

---

## 📁 Repository Structure

```
fit-iq/
├── README.md                    # This file
├── docs/                        # Workspace-level documentation
│   └── split-strategy/          # Split strategy documents
├── .github/                     # GitHub configuration & copilot instructions
├── FitIQ/                       # FitIQ app
│   ├── README.md
│   └── docs/                    # FitIQ-specific documentation
├── lume/                        # Lume app (Phase 3)
│   └── docs/                    # Lume-specific documentation
└── FitIQCore/                   # Shared package (Phase 1)
    └── docs/                    # FitIQCore documentation
```

---

## 📚 Documentation

### Workspace-Level
- **Split Strategy:** [docs/split-strategy/](./docs/split-strategy/)
- **Shared Library Assessment:** [docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md](./docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md)

### Project-Specific
- **FitIQ Documentation:** [FitIQ/docs/](./FitIQ/docs/)
- **Lume Documentation:** [lume/docs/](./lume/docs/)

### For AI Assistants
- **Copilot Instructions:** [.github/](./.github/)
  - Quick Reference: [COPILOT_INSTRUCTIONS_UNIFIED.md](./.github/COPILOT_INSTRUCTIONS_UNIFIED.md)
  - Usage Guide: [COPILOT_INSTRUCTIONS_README.md](./.github/COPILOT_INSTRUCTIONS_README.md)

---

## 🚀 Getting Started

### FitIQ App
```bash
cd FitIQ
# Open FitIQ.xcodeproj in Xcode
```

See [FitIQ/README.md](./FitIQ/README.md) for detailed setup instructions.

### Lume App (Phase 3)
Coming soon - See [docs/split-strategy/](./docs/split-strategy/) for roadmap.

---

## 🔗 Backend

**API:** https://fit-iq-backend.fly.dev/api/v1  
**Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html  
**Authentication:** JWT tokens (shared across both apps)

Both FitIQ and Lume use the same backend API with a single user account.

---

## 🤝 Contributing

### Documentation Standards
- **All markdown files MUST be in `./docs` directories**
- Organize by domain/feature in subdirectories
- No markdown files in project root folders (except README.md)
- See [.github/COPILOT_INSTRUCTIONS_README.md](./.github/COPILOT_INSTRUCTIONS_README.md)

### Code Standards
- Follow Hexagonal Architecture
- Use SD prefix for SwiftData @Model classes
- Domain-first approach (entities → use cases → infrastructure)
- Use Outbox Pattern for reliable sync
- See copilot instructions in `.github/` for detailed guidelines

---

## 📊 Project Status

| Project | Status | Phase | Documentation |
|---------|--------|-------|---------------|
| **FitIQ** | ✅ Production | Phase 2 Complete | [FitIQ/docs/](./FitIQ/docs/) |
| **FitIQCore** | 🚧 Planned | Phase 1 | [docs/split-strategy/](./docs/split-strategy/) |
| **Lume** | 🚧 Planned | Phase 3 | [lume/docs/](./lume/docs/) |

---

## 🎯 Roadmap

### Phase 1: FitIQCore Creation (2-3 weeks)
Extract shared infrastructure:
- Authentication & JWT management
- Network client foundation
- HealthKit framework
- Error handling

### Phase 2: FitIQ Refinement (1-2 weeks)
- Integrate FitIQCore
- Remove duplicated code
- Add Lume cross-promotion

### Phase 3: Lume Creation (3-4 weeks)
- Build wellness & mood app
- Use FitIQCore for infrastructure
- Implement calm, mindfulness-focused UX

See [docs/split-strategy/](./docs/split-strategy/) for detailed implementation plans.

---

## 📄 License

[License information to be added]

---

## 👥 Team

[Team information to be added]

---

**Version:** 1.0  
**Last Updated:** 2025-11-22  
**Status:** Active Development
