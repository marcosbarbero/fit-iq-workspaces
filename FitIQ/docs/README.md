# FitIQ Documentation

**App:** FitIQ - Fitness Intelligence Quotient  
**Focus:** Quantitative health metrics and fitness tracking

---

## 📚 Documentation Structure

This directory contains all documentation related to the FitIQ fitness app.

### Directories

- **analysis/** - Product assessments, comparisons, and decision documents
- **api-integration/** - API integration guides and patterns
- **architecture/** - Architecture diagrams, patterns, and refactoring plans
- **bugfixes/** - Bug fix documentation and issue resolutions
- **debugging/** - Debug tools and procedures
- **explanations/** - Detailed explanations of features and concepts
- **features/** - Feature-specific documentation and implementation guides
- **fixes/** - Historical fixes and resolutions
- **guides/** - Quick start guides, checklists, and reference materials
- **handoffs/** - Session handoffs, progress reports, and status updates
- **implementation-plans/** - Detailed implementation plans
- **implementation-summaries/** - Implementation completion summaries
- **issues/** - Issue tracking and resolution documentation
- **nutrition/** - Nutrition-specific documentation
- **performance/** - Performance optimization documentation
- **product-assessment/** - Product assessment documents (PRODUCT_ASSESSMENT.md, ASSESSMENT_README.md)
- **proposals/** - Feature proposals and enhancement ideas
- **refactoring/** - Code refactoring documentation
- **schema/** - Database schema and migration guides
- **split-strategy/** - Split strategy documentation (SPLIT_STRATEGY_QUICKSTART.md)
- **troubleshooting/** - Debug guides and verification procedures
- **ui-components/** - UI component documentation
- **ux/** - UX/UI design decisions and improvements
- **be-api-spec/** - Backend API specification (swagger.yaml)
- **archive/** - Archived documentation

---

## 🎯 FitIQ App Overview

### Core Features
- 📊 Activity tracking (steps, heart rate)
- ⚖️ Body metrics (weight, BMI)
- 🍎 Nutrition tracking (4,389+ foods, AI parsing)
- 💪 Workout management (100+ exercises)
- 😴 Sleep tracking
- 🎯 Goal management
- 🤖 AI Coach (fitness-focused)

### Target Users
Gym-goers, athletes, fitness enthusiasts

### Design Language
- **Colors:** Bold blues, energetic oranges, performance-focused
- **Typography:** San Francisco (system), bold weights
- **Mood:** Energetic, motivational, goal-driven
- **Icons:** SF Symbols fitness/nutrition icons
- **Animations:** Quick, snappy, responsive

---

## 🏗️ Architecture

FitIQ follows Hexagonal Architecture (Ports & Adapters) with clean separation:

\`\`\`
Presentation Layer (ViewModels/Views)
    ↓ depends on ↓
Domain Layer (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure Layer (Repositories, Network, Services)
    ↑ depends on ↑
FitIQCore (Shared Package)
\`\`\`

### Key Principles
- Domain layer is pure business logic (no external dependencies)
- Domain defines interfaces (ports via protocols)
- Infrastructure implements interfaces (adapters)
- Presentation depends only on domain abstractions
- Use dependency injection (via AppDependencies)

---

## 🔗 Related Projects

- **Lume App** - Wellness & mood tracking (sister app)
- **FitIQCore** - Shared infrastructure package (authentication, API, HealthKit)
- **Backend** - Unified backend API for both apps

---

## 📝 Contributing

When adding documentation:
1. **All markdown files MUST be in subdirectories** (no files directly in /docs)
2. Place files in the appropriate subdirectory by domain/feature
3. Use clear, descriptive filenames
4. Follow existing naming conventions
5. Update this README if adding new categories

---

## 🚀 Quick Links

- **Architecture Guide:** `architecture/SPLIT_ARCHITECTURE_DIAGRAM.md`
- **API Integration:** `api-integration/`
- **Backend API Spec:** `be-api-spec/swagger.yaml`
- **Split Strategy:** `split-strategy/SPLIT_STRATEGY_QUICKSTART.md`
- **Product Assessment:** `product-assessment/PRODUCT_ASSESSMENT.md`

---

**Status:** ✅ FitIQ app is production-ready (Phase 2 complete per SPLIT_STRATEGY_QUICKSTART.md)
