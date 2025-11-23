# Lume iOS Documentation

**Last Updated:** January 30, 2025  
**Version:** 2.0.0

Welcome to the Lume iOS documentation! This directory contains all technical documentation, API specs, and guides for the Lume wellness app.

---

## 📚 Quick Navigation

### Getting Started
- **[Quick Reference](QUICK_REFERENCE.md)** - Fast lookup for common patterns and code examples
- **[Architecture Overview](architecture/OVERVIEW.md)** - Understand Hexagonal Architecture and SOLID principles
- **[Onboarding Guide](onboarding/)** - New developer setup and orientation

### Core Features
- **[Mood Tracking](mood-tracking/)** - Emotion logging with warm, non-judgmental UX
- **[Journaling](journaling/)** - Rich text entries with backend sync and offline support
- **[AI-Powered Features](ai-powered-features/)** - Goals, insights, and AI consultations
- **[Chat](chat/)** - Real-time AI conversations with streaming responses
- **[Dashboard](dashboard/)** - Analytics, insights, and wellness metrics

### Backend & APIs
- **[Backend Integration](backend-integration/)** - API configuration and endpoints
  - [Configuration Guide](backend-integration/CONFIGURATION.md)
  - [Swagger Specs](backend-integration/) - Complete API documentation
    - `swagger-insights.yaml` - AI Insights API
    - `swagger-goals.yaml` - Goals Management API
    - `swagger-consultations.yaml` - AI Chat/Consultation API
    - `swagger-users.yaml` - User Management API

### Authentication & Security
- **[Authentication](authentication/)** - User registration, login, token management
  - [Implementation Guide](authentication/IMPLEMENTATION.md)
  - [Modern UI Design](authentication/MODERN_UI.md)

### Design & UX
- **[Design System](design/)** - Colors, typography, and UI patterns
- **[Deferred Features](design/GOAL_CHAT_FEATURE_DEFERRED.md)** - Temporarily disabled features
- **[Dashboard Analysis](design/DASHBOARD_ANALYSIS_AND_RECOMMENDATIONS.md)** - Enhancement roadmap

### Bug Fixes & Improvements
- **[Fixes](fixes/)** - Documented bug fixes and improvements

---

## 🏗️ Documentation Organization

All documentation follows this structure:

```
docs/
├── README.md (this file)           # Documentation index
├── QUICK_REFERENCE.md              # Fast code lookup
│
├── architecture/                   # Architecture decisions
│   └── OVERVIEW.md                 # Hexagonal + SOLID principles
│
├── authentication/                 # Auth system
│   ├── IMPLEMENTATION.md           # Auth flow details
│   └── MODERN_UI.md                # Auth UI design
│
├── backend-integration/            # API integration
│   ├── CONFIGURATION.md            # Setup guide
│   ├── swagger-insights.yaml       # Insights API spec
│   ├── swagger-goals.yaml          # Goals API spec
│   ├── swagger-consultations.yaml  # Chat API spec
│   └── swagger-users.yaml          # Users API spec
│
├── mood-tracking/                  # Mood feature docs
├── journaling/                     # Journaling feature docs
├── ai-powered-features/            # AI features (goals, insights, chat)
├── chat/                           # Chat feature specifics
├── dashboard/                      # Dashboard feature docs
├── design/                         # UX and design decisions
├── onboarding/                     # Getting started guides
└── fixes/                          # Bug fixes and improvements
```

---

## 📖 Documentation Standards

### When to Create Documentation

1. **Architecture decisions** → `architecture/`
2. **New features** → Feature-specific directory
3. **API changes** → Update swagger specs in `backend-integration/`
4. **Bug fixes** → `fixes/` with date and description
5. **Design decisions** → `design/`

### Documentation Best Practices

✅ **DO:**
- Keep docs in feature-specific subdirectories
- Use descriptive filenames (e.g., `MOOD_REDESIGN_SUMMARY.md`)
- Update docs when making significant changes
- Include code examples and diagrams where helpful
- Remove outdated documentation promptly

❌ **DON'T:**
- Create files in `docs/` root (only `README.md` and `QUICK_REFERENCE.md` allowed)
- Create multi-iteration documents (consolidate instead)
- Leave outdated docs lying around
- Duplicate information across multiple files

### File Naming Convention

- `README.md` - Directory overview
- `FEATURE_NAME_IMPLEMENTATION.md` - Implementation details
- `FEATURE_NAME_GUIDE.md` - How-to guides
- `FEATURE_NAME_FIX.md` - Bug fix documentation
- `FEATURE_NAME_ANALYSIS.md` - Analysis and recommendations

---

## 🔍 Find What You Need

### "I want to understand the architecture"
→ Read [Architecture Overview](architecture/OVERVIEW.md)

### "I need to integrate a backend API"
→ Check [Backend Integration](backend-integration/) and relevant swagger spec

### "I want to implement a new feature"
→ Review [Architecture Overview](architecture/OVERVIEW.md), then check similar feature docs

### "I'm fixing a bug"
→ Check [Fixes](fixes/) for similar issues, document your fix there

### "I need quick code examples"
→ See [Quick Reference](QUICK_REFERENCE.md)

### "I'm new to the project"
→ Start with [Onboarding Guide](onboarding/)

### "I want to see what's been deferred"
→ Check [Deferred Features](design/GOAL_CHAT_FEATURE_DEFERRED.md)

---

## 🎯 Key Principles (Reminder)

Every feature in Lume must follow these principles:

### Architecture
- **Hexagonal Architecture** - Domain independent of infrastructure
- **SOLID Principles** - Single responsibility, clean abstractions
- **Outbox Pattern** - All external calls through outbox for resilience
- **Dependency Injection** - Via `AppDependencies`

### Design
- **Warm & Calm** - Cozy, non-judgmental, reassuring
- **Minimal** - One clear action per screen
- **Generous Spacing** - Soft corners, calm animations
- **Design System** - Always use defined colors and typography

### Security
- **Keychain Storage** - All tokens and sensitive data
- **HTTPS Only** - No plain HTTP
- **No Hardcoded Secrets** - Use configuration system
- **Proper Validation** - All user inputs

---

## 📝 Contributing to Documentation

When you make changes:

1. **Update relevant docs** in feature directory
2. **Add to fixes/** if bug fix
3. **Update swagger specs** if API changes
4. **Update this README** if adding new top-level sections
5. **Keep it concise** - consolidate instead of creating iteration docs

---

## 🚀 Status Summary

### ✅ Complete
- Architecture and patterns established
- Authentication system (registration, login, tokens)
- Mood tracking with redesigned UX
- Journaling with rich text and backend sync
- Goals management with AI suggestions
- AI chat with streaming and WebSocket support
- AI insights management (Phase 1)
- Dashboard with analytics

### 🔄 In Progress
- AI Insights API integration (swagger-insights.yaml implementation)
- Backend insight generation

### 📋 Planned
- Phase 2 AI Insights features (search, sorting, bulk actions)
- Additional dashboard enhancements
- Advanced analytics

---

## 📞 Need Help?

1. Check this documentation index
2. Review feature-specific docs
3. Check [Quick Reference](QUICK_REFERENCE.md)
4. Review [Architecture Overview](architecture/OVERVIEW.md)
5. Check `.github/copilot-instructions.md` for AI assistant rules

---

**Remember:** Lume is about creating warmth, calm, and care. Every line of code—and every line of documentation—should reflect that. 🌟