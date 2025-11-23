# 🍎 FitIQ iOS Integration Guide

**Backend Version:** 0.22.0  
**API Base URL:** `https://fit-iq-backend.fly.dev`  
**Last Updated:** 2025-01-27  
**Status:** ✅ Production Ready

---

## 📋 Overview

Welcome to the FitIQ iOS integration documentation! This guide is organized into **bite-sized, focused documents** - one use case at a time.

**What's Available:**
- ✅ 119 REST API Endpoints
- ✅ WebSocket streaming for AI consultation
- ✅ 1,878+ passing tests (100% coverage)
- ✅ Complete Swift code examples
- ✅ Zero known bugs

---

## 🚀 Quick Start (Choose Your Path)

### Path 1: Complete Beginner
**Start here if this is your first time:**

1. Read: [`getting-started/01-setup.md`](getting-started/01-setup.md)
2. Implement: [`getting-started/02-authentication.md`](getting-started/02-authentication.md)
3. Build: Choose a feature from [`features/`](features/)

**Time: 3 days to working login**

### Path 2: I Know What I'm Doing
**Jump straight to what you need:**

- Need login? → [`getting-started/02-authentication.md`](getting-started/02-authentication.md)
- Need nutrition tracking? → [`features/nutrition-tracking.md`](features/nutrition-tracking.md)
- Need workouts? → [`features/workout-tracking.md`](features/workout-tracking.md)
- Need AI chat? → [`ai-consultation/`](ai-consultation/)

### Path 3: Advanced Features
**Already have basics working:**

- Goals & Progress → [`features/goals.md`](features/goals.md)
- Templates → [`features/templates.md`](features/templates.md)
- AI Consultation → [`ai-consultation/01-overview.md`](ai-consultation/01-overview.md)
- Analytics → [`features/analytics.md`](features/analytics.md)

---

## 📚 Documentation Structure

### 🎯 Getting Started (Must Read First)
*Foundation you need for everything else*

| Document | What You'll Learn | Time |
|----------|-------------------|------|
| [01-setup.md](getting-started/01-setup.md) | API key, base URL, project setup | 15 min |
| [02-authentication.md](getting-started/02-authentication.md) | Registration, login, JWT tokens, Keychain | 3 days |
| [03-error-handling.md](getting-started/03-error-handling.md) | Consistent error handling, retry logic | 1 day |

**Start with these 3 files. Everything else depends on authentication.**

---

### 🎨 Core Features (Pick What You Need)
*Independent use cases - implement in any order*

#### User Management
| Document | What You'll Build | Dependencies |
|----------|-------------------|--------------|
| [user-profile.md](features/user-profile.md) | Age, height, weight, BMI tracking | Auth |
| [user-preferences.md](features/user-preferences.md) | Units, themes, goals | Auth |

#### Tracking Features
| Document | What You'll Build | Dependencies |
|----------|-------------------|--------------|
| [nutrition-tracking.md](features/nutrition-tracking.md) | Food search, barcode scan, meal logging | Auth |
| [workout-tracking.md](features/workout-tracking.md) | Exercise search, workout logging | Auth |
| [sleep-tracking.md](features/sleep-tracking.md) | Sleep hours, quality tracking | Auth |
| [activity-snapshots.md](features/activity-snapshots.md) | HealthKit data sync | Auth |

#### Advanced Features
| Document | What You'll Build | Dependencies |
|----------|-------------------|--------------|
| [goals.md](features/goals.md) | Goal creation, progress tracking | Auth + Profile |
| [templates.md](features/templates.md) | Meal/workout templates | Auth + Nutrition/Workouts |
| [analytics.md](features/analytics.md) | Trends, insights, charts | Auth + Historical data |

---

### 🤖 AI Consultation (Most Complex)
*Real-time AI chat with WebSocket streaming*

| Document | What You'll Learn | Time |
|----------|-------------------|------|
| [01-overview.md](ai-consultation/01-overview.md) | Why WebSocket, when to use it | 10 min |
| [02-websocket-setup.md](ai-consultation/02-websocket-setup.md) | Starscream, connection management | 2 days |
| [03-chat-interface.md](ai-consultation/03-chat-interface.md) | SwiftUI chat UI, message bubbles | 2 days |
| [04-template-creation.md](ai-consultation/04-template-creation.md) | AI-created templates in chat | 1 day |

**Prerequisites:** Auth + Profile + at least one tracking feature (nutrition or workouts)

---

### 📖 Guides (Reusable Patterns)
*Copy-paste solutions for common problems*

| Document | What You'll Get |
|----------|-----------------|
| [pagination.md](guides/pagination.md) | Reusable pagination helper class |
| [date-handling.md](guides/date-handling.md) | UTC dates, formatting, parsing |
| [healthkit-integration.md](guides/healthkit-integration.md) | Sync steps, calories, sleep |
| [testing.md](guides/testing.md) | Unit tests, mocks, integration tests |
| [common-patterns.md](guides/common-patterns.md) | Retry logic, batching, caching |

---

## 🎯 Recommended Implementation Order

### Week 1: Foundation ✅ MANDATORY
1. Setup → [`getting-started/01-setup.md`](getting-started/01-setup.md)
2. Authentication → [`getting-started/02-authentication.md`](getting-started/02-authentication.md)
3. Error Handling → [`getting-started/03-error-handling.md`](getting-started/03-error-handling.md)

**Deliverable:** Users can register and login

### Week 2: Profile & Preferences
4. User Profile → [`features/user-profile.md`](features/user-profile.md)
5. User Preferences → [`features/user-preferences.md`](features/user-preferences.md)

**Deliverable:** Users can complete onboarding

### Week 3-4: Choose Your Focus

**Option A - Nutrition App:**
- Nutrition Tracking → [`features/nutrition-tracking.md`](features/nutrition-tracking.md)

**Option B - Fitness App:**
- Workout Tracking → [`features/workout-tracking.md`](features/workout-tracking.md)

**Option C - Both:**
- Do both in parallel (requires more time)

**Deliverable:** Core tracking functionality

### Week 5-6: Enhancement
- Goals → [`features/goals.md`](features/goals.md)
- Templates → [`features/templates.md`](features/templates.md)
- Sleep → [`features/sleep-tracking.md`](features/sleep-tracking.md)
- Analytics → [`features/analytics.md`](features/analytics.md)

**Deliverable:** Full-featured app

### Week 7-8: AI Features (Optional)
- AI Consultation → [`ai-consultation/`](ai-consultation/)

**Deliverable:** AI-powered coaching

---

## 🚨 Critical Rules

### Must-Have Dependencies
```
Registration → Login → Token Management
         ↓
    Everything Else
```

**You CANNOT skip authentication.** Everything requires a valid JWT token.

### Feature Dependencies
- **Goals** require Profile + Tracking data
- **Templates** require Nutrition and/or Workouts
- **Analytics** require historical data
- **AI Chat** requires Profile + at least one tracking feature

---

## 📊 What's Available (119 Endpoints)

| Category | Endpoints | Complexity | Guide |
|----------|-----------|------------|-------|
| **Authentication** | 4 | Simple | [getting-started/02-authentication.md](getting-started/02-authentication.md) |
| **User Management** | 4 | Simple | [features/user-profile.md](features/user-profile.md) |
| **Nutrition** | 28 | Medium | [features/nutrition-tracking.md](features/nutrition-tracking.md) |
| **Workouts** | 22 | Medium | [features/workout-tracking.md](features/workout-tracking.md) |
| **Goals** | 10 | Medium | [features/goals.md](features/goals.md) |
| **Templates** | 25 | Medium | [features/templates.md](features/templates.md) |
| **Sleep** | 2 | Simple | [features/sleep-tracking.md](features/sleep-tracking.md) |
| **Activity** | 6 | Simple | [features/activity-snapshots.md](features/activity-snapshots.md) |
| **Analytics** | 4 | Medium | [features/analytics.md](features/analytics.md) |
| **AI Chat** | 6 + WS | Complex | [ai-consultation/](ai-consultation/) |
| **Progress** | 4 | Medium | [features/goals.md](features/goals.md) |

---

## 🎓 How to Use This Documentation

### For First-Time Integration
1. Read guides **in order** (getting-started → features → ai)
2. Don't skip authentication
3. Test each feature before moving to next
4. Use guides for common patterns

### For Specific Feature
1. Check **dependencies** (does it require auth? profile? other features?)
2. Read **only that feature's guide**
3. Copy Swift code examples
4. Test against production backend

### For Troubleshooting
1. Check [getting-started/03-error-handling.md](getting-started/03-error-handling.md)
2. Review [guides/common-patterns.md](guides/common-patterns.md)
3. Test endpoint in Swagger UI: `https://fit-iq-backend.fly.dev/swagger/index.html`

---

## 🔧 Prerequisites

### Backend
- ✅ API Key (get from backend admin)
- ✅ Production URL: `https://fit-iq-backend.fly.dev`
- ✅ Internet connectivity

### iOS
- iOS 15.0+ (recommended for async/await)
- Swift 5.5+
- Xcode 13+

### Recommended Libraries
```swift
// Networking
- URLSession (native, recommended)

// WebSocket (for AI chat only)
- Starscream 4.0+

// JSON
- Codable (native)

// Keychain
- KeychainAccess or Security framework
```

---

## 📖 API Documentation

### Interactive Documentation
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **Health Check:** https://fit-iq-backend.fly.dev/health
- **OpenAPI Spec:** [`../swagger.yaml`](../swagger.yaml)

### Test Endpoints
All endpoints can be tested via Swagger UI before implementing in iOS.

---

## 🎯 Minimal Viable Product (MVP)

### MVP 1: Nutrition App (3 weeks)
```
✅ Authentication (3 days)
✅ User Profile (1 day)
✅ Nutrition Tracking (5 days)
✅ Testing & Polish (3 days)
```

### MVP 2: Fitness App (3 weeks)
```
✅ Authentication (3 days)
✅ User Profile (1 day)
✅ Workout Tracking (5 days)
✅ Testing & Polish (3 days)
```

### MVP 3: Full App (6 weeks)
```
✅ Authentication + Profile (4 days)
✅ Nutrition (5 days)
✅ Workouts (5 days)
✅ Goals (2 days)
✅ Templates (3 days)
✅ Testing & Polish (5 days)
```

---

## 🚀 Quick Links

### Essential Reading (Start Here)
1. [Setup Guide](getting-started/01-setup.md)
2. [Authentication Guide](getting-started/02-authentication.md)
3. [Error Handling](getting-started/03-error-handling.md)

### Popular Features
- [Nutrition Tracking](features/nutrition-tracking.md) - Most requested
- [Workout Tracking](features/workout-tracking.md) - Second most requested
- [AI Consultation](ai-consultation/01-overview.md) - Most complex, highest value

### Helpful Guides
- [Pagination](guides/pagination.md) - All list endpoints
- [Date Handling](guides/date-handling.md) - UTC timezone required
- [HealthKit Integration](guides/healthkit-integration.md) - Sync health data

---

## 💬 Support

### Questions?
1. Check the specific feature guide
2. Review common patterns guide
3. Test endpoint in Swagger UI
4. Check OpenAPI spec for schemas

### Found an Issue?
- Backend bugs → Report to backend team
- Documentation unclear → Suggest improvements
- API questions → Check Swagger documentation

---

## 🎉 Ready to Start?

### Next Steps:
1. **Read:** [Setup Guide](getting-started/01-setup.md) (15 minutes)
2. **Implement:** [Authentication](getting-started/02-authentication.md) (3 days)
3. **Build:** Choose your first feature from [features/](features/)
4. **Test:** Against production: `https://fit-iq-backend.fly.dev`

---

**The backend is stable, tested, and ready. Each guide is focused on ONE use case. Pick a guide and start building! 🚀**

---

## 📝 Document Index

### Getting Started
- [01-setup.md](getting-started/01-setup.md)
- [02-authentication.md](getting-started/02-authentication.md)
- [03-error-handling.md](getting-started/03-error-handling.md)

### Features
- [user-profile.md](features/user-profile.md)
- [user-preferences.md](features/user-preferences.md)
- [nutrition-tracking.md](features/nutrition-tracking.md)
- [workout-tracking.md](features/workout-tracking.md)
- [sleep-tracking.md](features/sleep-tracking.md)
- [activity-snapshots.md](features/activity-snapshots.md)
- [goals.md](features/goals.md)
- [templates.md](features/templates.md)
- [analytics.md](features/analytics.md)

### AI Consultation
- [01-overview.md](ai-consultation/01-overview.md)
- [02-websocket-setup.md](ai-consultation/02-websocket-setup.md)
- [03-chat-interface.md](ai-consultation/03-chat-interface.md)
- [04-template-creation.md](ai-consultation/04-template-creation.md)

### Guides
- [pagination.md](guides/pagination.md)
- [date-handling.md](guides/date-handling.md)
- [healthkit-integration.md](guides/healthkit-integration.md)
- [testing.md](guides/testing.md)
- [common-patterns.md](guides/common-patterns.md)