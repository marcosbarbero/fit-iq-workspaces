# Lume iOS App

A warm and calm wellness app focused on mood tracking, journaling, and goal tracking with AI support.

## 🌟 Overview

Lume is designed with one core principle: **Everything must feel cozy, warm, and reassuring. No pressure mechanics.**

### Features
- 🧘 **Mood Tracking** - Check in with yourself throughout the day
- 📝 **Journaling** - Reflect on your thoughts and experiences
- 🎯 **Goal Tracking** - Set and achieve personal goals with AI support
- 💬 **AI Chat** - Interactive conversations with quick action buttons for instant guidance
- ✨ **AI Insights** - Personalized wellness insights with favorites, filtering, and management
- 👤 **User Profile** - Complete profile management with dietary preferences and physical attributes
- 🔐 **Secure Authentication** - Safe and private user accounts

## 🚀 Quick Start

### Requirements
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### Running the App

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd lume
   ```

2. **Open in Xcode**
   ```bash
   open lume.xcodeproj
   ```

3. **Build and Run**
   - Select a simulator or device
   - Press `Cmd + R`

## ⚠️ Deferred Features

Some features are temporarily disabled pending user feedback:

- **"Chat About Goal" button** (Disabled 2025-01-15)
  - **Status:** Functionality complete, button hidden from UI
  - **Reason:** Gathering user feedback on "Get AI Tips" first
  - **Location:** `GoalDetailView.swift` (see inline comment)
  - **Details:** See [docs/design/GOAL_CHAT_FEATURE_DEFERRED.md](docs/design/GOAL_CHAT_FEATURE_DEFERRED.md)
  - **Re-enable:** All code is intact, can be restored when user feedback validates the approach

## 📚 Documentation

All documentation is organized in the `docs/` directory:

### Architecture & Core
- [Architecture Overview](docs/architecture/OVERVIEW.md) - Hexagonal architecture and SOLID principles
- [Quick Reference](docs/QUICK_REFERENCE.md) - Fast lookup for common patterns

### Features
- [Mood Tracking](docs/mood-tracking/) - Mood logging and visualization
- [Journaling](docs/journaling/) - Rich text journaling with backend sync
- [AI-Powered Features](docs/ai-powered-features/) - Goals, insights, and AI consultations
- [Chat](docs/chat/) - Real-time AI chat with streaming and WebSocket support
- [Dashboard](docs/dashboard/) - Analytics and insights display
- [User Profile](docs/profile/) - Comprehensive profile management with personal info, physical attributes, and dietary preferences

### Authentication & Backend
- [Authentication](docs/authentication/) - User registration, login, and token management
- [Backend Integration](docs/backend-integration/) - API specs, configuration, and endpoints
  - [Configuration Guide](docs/backend-integration/CONFIGURATION.md)
  - [Swagger Specs](docs/backend-integration/) - Complete API specifications

### Design & UX
- [Design System](docs/design/) - Colors, typography, and UI patterns
- [Deferred Features](docs/design/GOAL_CHAT_FEATURE_DEFERRED.md) - Features temporarily disabled
- [Dashboard Analysis](docs/design/DASHBOARD_ANALYSIS_AND_RECOMMENDATIONS.md) - Enhancement roadmap

### Development
- [Onboarding](docs/onboarding/) - Getting started guide
- [Fixes & Improvements](docs/fixes/) - Bug fixes and enhancements

### Distribution
- [TestFlight Guide](docs/distribution/TESTFLIGHT_GUIDE.md) - Complete TestFlight distribution guide
- [TestFlight Quick Start](docs/distribution/TESTFLIGHT_QUICKSTART.md) - Fast checklist for uploads

## 🏗️ Architecture

Lume follows **Hexagonal Architecture** with **SOLID principles**:

```
Presentation (SwiftUI Views + ViewModels)
    ↓
Domain (Entities + Use Cases + Ports)
    ↓
Infrastructure (SwiftData + Repositories + Services)
```

### Key Technologies
- **SwiftUI** - Modern declarative UI
- **SwiftData** - Local persistence
- **Async/await** - Concurrent operations
- **MVVM** - Clear separation of concerns
- **Dependency Injection** - Testable architecture

## 🎨 Design Philosophy

- **Calm & Warm** - Soft colors, generous spacing, gentle animations
- **Minimal** - One focused action per screen
- **Non-judgmental** - No pressure, no streaks, no guilt
- **Accessible** - Clear text, good contrast, VoiceOver support

## 🔒 Security

- Tokens stored securely in iOS Keychain
- HTTPS-only communication
- No plain-text password storage
- Automatic token refresh

## 📝 Contributing

When contributing to Lume:

1. Follow the architecture patterns (see [Architecture Overview](docs/architecture/ARCHITECTURE_OVERVIEW.md))
2. Keep UI calm and minimal (see [Design Guidelines](docs/design/))
3. Update documentation in `docs/` when adding features
4. Write tests for new functionality

## 📄 License

[Add your license here]

## 🤝 Support

For questions or issues, please refer to the documentation in the `docs/` directory.

---

**Remember:** Lume is all about warmth, calm, and care. Every line of code should reflect that. 🌟