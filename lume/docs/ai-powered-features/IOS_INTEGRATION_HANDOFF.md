# 🍎 FitIQ iOS Integration Handoff

**Date:** 2025-01-27  
**API Version:** 0.22.0  
**Purpose:** Complete iOS integration guide (backend-agnostic)  
**Status:** ✅ Ready for Integration

---

## 📋 Executive Summary

Your iOS app is ready to integrate with the FitIQ health & fitness API. This document provides:

- ✅ **What's available** - 119 REST endpoints + WebSocket
- ✅ **What you need** - API key, base URL, dependencies
- ✅ **How to integrate** - Step-by-step with Swift examples
- ✅ **Where to start** - Prioritized implementation order
- ✅ **Complete documentation** - Bite-sized, focused guides

**Everything you need is in this document and the `docs/ios-integration/` folder.**

---

## 🚀 Quick Start (5 Minutes)

### 1. Get Your Credentials

**API Key:** Contact backend administrator  
**Base URL:** `https://fit-iq-backend.fly.dev/api/v1`  
**WebSocket URL:** `wss://fit-iq-backend.fly.dev/ws`

### 2. Verify API is Live

```bash
curl https://fit-iq-backend.fly.dev/health
# Expected: {"status":"ok"}
```

### 3. Copy Integration Docs

```bash
# In your iOS project root
cp -r /path/to/fitiq-backend/docs/ios-integration ./docs/api-integration

# Symlink API spec (reference only)
ln -s /path/to/fitiq-backend/docs/swagger.yaml ./docs/api-spec.yaml
```

### 4. Start Here

1. Read: `docs/api-integration/getting-started/01-setup.md` (15 min)
2. Implement: `docs/api-integration/getting-started/02-authentication.md` (3 days)
3. Build: Choose features from `docs/api-integration/features/`

---

## 🎯 What's Available

### API Capabilities (119 Endpoints)

| Category | Endpoints | Complexity | Time Estimate |
|----------|-----------|------------|---------------|
| **Authentication** | 4 | ⭐ Simple | 3 days |
| **User Profile** | 4 | ⭐ Simple | 1 day |
| **Nutrition Tracking** | 28 | ⭐⭐ Medium | 5 days |
| **Workout Tracking** | 22 | ⭐⭐ Medium | 5 days |
| **Goals & Progress** | 10 | ⭐⭐ Medium | 2 days |
| **Templates** | 25 | ⭐⭐ Medium | 3 days |
| **Sleep Tracking** | 2 | ⭐ Simple | 1 day |
| **Activity Snapshots** | 6 | ⭐ Simple | 1 day |
| **Analytics** | 4 | ⭐⭐ Medium | 2 days |
| **AI Consultation** | 6 + WebSocket | ⭐⭐⭐ Complex | 5 days |

**Total: 119 endpoints, all production-ready**

### Key Features

✅ **Authentication:** JWT tokens, refresh flow, secure Keychain storage  
✅ **Food Database:** 4,389 foods, barcode scanning, custom foods  
✅ **Exercise Database:** 100+ exercises, custom exercises  
✅ **Meal Templates:** 500+ pre-built templates  
✅ **AI Coaching:** Real-time chat with template creation  
✅ **HealthKit Ready:** Activity snapshots, sleep data sync  
✅ **Comprehensive Analytics:** Nutrition & workout insights  

---

## 📚 Documentation Structure

All guides are in `docs/api-integration/` (organized, bite-sized):

### 🎯 Getting Started (Must Read First)
**Location:** `getting-started/`

| File | What You'll Learn | Time |
|------|-------------------|------|
| 01-setup.md | API key, base URL, Config.swift | 15 min |
| 02-authentication.md | Registration, login, JWT, Keychain | 3 days |
| 03-error-handling.md | Consistent error handling, retries | 1 day |

**Start with these 3 files.** Authentication is mandatory for everything else.

### 🎨 Features (Pick What You Need)
**Location:** `features/`

Each file is **self-contained** and covers one feature:

- `user-profile.md` - Age, height, weight, BMI
- `user-preferences.md` - Units, themes, goals
- `nutrition-tracking.md` - Food search, logging, macros
- `workout-tracking.md` - Exercise search, logging, sets/reps
- `sleep-tracking.md` - Sleep hours, quality
- `activity-snapshots.md` - HealthKit data sync
- `goals.md` - Goal creation, progress tracking
- `templates.md` - Meal/workout templates
- `analytics.md` - Trends, insights, charts

**Choose based on your app's focus.**

### 🤖 AI Consultation (Advanced)
**Location:** `ai-consultation/`

Real-time AI chat with WebSocket streaming:

1. `01-overview.md` - Why WebSocket, when to use
2. `02-websocket-setup.md` - Starscream, connection
3. `03-chat-interface.md` - SwiftUI chat UI
4. `04-template-creation.md` - AI creates templates

**Prerequisites:** Auth + Profile + one tracking feature

### 📖 Guides (Reusable Patterns)
**Location:** `guides/`

Copy-paste solutions:

- `pagination.md` - Handle paginated lists
- `date-handling.md` - UTC dates, formatting
- `healthkit-integration.md` - Sync health data
- `testing.md` - Unit tests, mocks
- `common-patterns.md` - Retry logic, caching

---

## 🗺️ Implementation Roadmap

### Phase 1: Foundation (Week 1) ✅ MANDATORY

**You cannot skip this. Everything depends on it.**

```
Day 1: Setup (15 min) + Authentication Start
Day 2-3: Complete Authentication (register, login, token refresh)
Day 4: Error Handling
Day 5: Testing & Integration
```

**Deliverable:** Users can register, login, and stay authenticated

**Guides:**
- `getting-started/01-setup.md`
- `getting-started/02-authentication.md`
- `getting-started/03-error-handling.md`

### Phase 2: Profile Setup (Week 2)

```
Day 1: User Profile (age, height, weight)
Day 2: User Preferences (units, goals)
Day 3-5: Testing & Polish
```

**Deliverable:** Users can complete onboarding

**Guides:**
- `features/user-profile.md`
- `features/user-preferences.md`

### Phase 3: Core Tracking (Week 3-4)

**Priority:** Based on project requirements, implement in this order:

1. **Nutrition Tracking** (Week 3)
   - Food search and logging (primary focus)
   - Daily summaries and macro tracking
   - Custom food creation

2. **Workout Tracking** (Week 4)
   - Exercise search and logging
   - Workout history
   - Custom exercises

**Guides:**
- `features/nutrition-tracking.md`
- `features/workout-tracking.md`

**Deliverable:** Core tracking functionality working

### Phase 4: Enhancement (Week 5-6)

Add supporting features:

```
Week 5:
- Goals & Progress Tracking (2 days)
- Templates (3 days)

Week 6:
- Sleep Tracking (1 day)
- Activity Snapshots (1 day)
- Analytics (2 days)
```

**Guides:**
- `features/goals.md`
- `features/templates.md`
- `features/sleep-tracking.md`
- `features/activity-snapshots.md`
- `features/analytics.md`

### Phase 5: AI Features (Week 7-8) - Optional

Most complex, highest value:

```
Week 7:
- WebSocket setup (2 days)
- Chat interface (3 days)

Week 8:
- Template creation in chat (2 days)
- Testing & polish (3 days)
```

**Guides:**
- `ai-consultation/01-overview.md`
- `ai-consultation/02-websocket-setup.md`
- `ai-consultation/03-chat-interface.md`
- `ai-consultation/04-template-creation.md`

---

## 🔑 Critical Dependencies

### Mandatory Path (Cannot Skip)

```
API Key → Setup → Authentication → Everything Else
```

**You cannot call any endpoint without:**
1. Valid API key
2. Valid JWT token (from login)

### Feature Dependencies

```
Authentication (Day 1-3)
    ↓
Profile (Day 4-5)
    ↓
┌───────────┴───────────┐
↓                       ↓
Nutrition          Workouts
    ↓                   ↓
    └────────┬──────────┘
             ↓
      Goals/Templates
             ↓
         Analytics
             ↓
       AI Consultation
```

**Rules:**
- Goals require Profile + tracking data
- Templates require Nutrition and/or Workouts
- Analytics require historical data
- AI requires Profile + at least one tracking feature

---

## 🛠️ Technical Requirements

### iOS Requirements
- iOS 15.0+ (for async/await)
- Swift 5.5+
- Xcode 13+

### Recommended Dependencies

**Networking (Choose One):**
- ✅ **URLSession** (native, recommended) - No dependencies
- 🔶 **Alamofire** (optional) - If you prefer third-party

**WebSocket (AI Chat Only):**
- ✅ **Starscream 4.0+** (required for AI consultation)

**Keychain (Token Storage):**
- ✅ **Security framework** (native)
- 🔶 **KeychainAccess** (optional wrapper)

### Installation

**URLSession:** Already included in iOS  
**Starscream:** 
```swift
// Package.swift or Xcode → Add Packages
.package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
```

---

## 📡 API Standards (All Endpoints)

### Request Format

**Headers (required for all requests):**
```
X-API-Key: {your_api_key}              // Always required
Authorization: Bearer {jwt_token}      // Required except auth endpoints
Content-Type: application/json         // For POST/PUT with body
```

**Example Request:**
```swift
var request = URLRequest(url: url)
request.setValue("YOUR_API_KEY", forHTTPHeaderField: "X-API-Key")
request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

### Response Format

**Success Response:**
```json
{
  "success": true,
  "data": { /* actual data here */ },
  "error": null
}
```

**Error Response:**
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "details": { }
  }
}
```

### HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success (GET, PUT, DELETE) | Parse data |
| 201 | Created (POST) | Parse data |
| 400 | Validation error | Show error.message to user |
| 401 | Unauthorized (token expired) | Refresh token or re-login |
| 403 | Forbidden | User lacks permission |
| 404 | Not found | Resource doesn't exist |
| 500 | Server error | Retry with exponential backoff |

---

## 🎯 Minimal Viable Product (MVP)

### MVP 1: Nutrition App (3 Weeks)

**Week 1:** Authentication (3 days) + Profile (2 days)  
**Week 2:** Nutrition tracking (5 days)  
**Week 3:** Testing & polish (5 days)

**Result:** Users can log meals and track macros

### MVP 2: Fitness App (3 Weeks)

**Week 1:** Authentication (3 days) + Profile (2 days)  
**Week 2:** Workout tracking (5 days)  
**Week 3:** Testing & polish (5 days)

**Result:** Users can log workouts and track exercises

### MVP 3: Full App (6 Weeks)

**Week 1-2:** Foundation + Profile  
**Week 3-4:** Nutrition + Workouts  
**Week 5-6:** Goals, Templates, Analytics

**Result:** Complete health & fitness tracking app

---

## 🎓 How to Use This Documentation

### First-Time Integration

1. **Read guides in order** (getting-started → features → ai)
2. **Don't skip authentication** (everything depends on it)
3. **Implement one feature at a time** (test before moving on)
4. **Use guides for common patterns** (pagination, dates, etc.)

### Quick Reference

**Need specific feature?**
1. Check dependencies (auth? profile? other features?)
2. Read that feature's guide (only one file)
3. Copy Swift code examples
4. Test against production API

**Stuck on something?**
1. Check `getting-started/03-error-handling.md`
2. Review `guides/common-patterns.md`
3. Test endpoint in Swagger UI: https://fit-iq-backend.fly.dev/swagger/index.html

### Testing Endpoints

**Before implementing in iOS, test via Swagger:**
1. Open: https://fit-iq-backend.fly.dev/swagger/index.html
2. Find endpoint (e.g., POST /auth/register)
3. Click "Try it out"
4. Fill in parameters
5. Execute
6. Verify response

**This helps you understand the API before writing code.**

---

## ✅ Pre-Integration Checklist

Before starting implementation:

- [ ] API key obtained from backend admin
- [ ] API key added to `config.plist` (not hardcoded)
- [ ] Health endpoint returns 200 (`curl https://fit-iq-backend.fly.dev/health`)
- [ ] Swagger UI loads (https://fit-iq-backend.fly.dev/swagger/index.html)
- [ ] Integration docs copied to iOS project
- [ ] API spec symlinked for reference
- [ ] `.github/copilot-instructions.md` created (if using AI assistant)
- [ ] Reviewed existing codebase patterns (Hexagonal Architecture, SwiftData models)

---

## 🚨 Critical Rules

### Security

**✅ DO:**
- Store API key in `config.plist` (excluded from git)
- Store JWT tokens in Keychain (never UserDefaults)
- Use HTTPS for all requests (production enforces this)
- Implement token refresh flow
- Clear tokens on logout

**❌ DON'T:**
- Hardcode API key in code
- Store tokens in UserDefaults or files
- Ignore 401 errors (token expired)
- Skip token refresh implementation
- Log sensitive data (tokens, passwords)

### Error Handling

**✅ DO:**
- Implement consistent error handling across all calls
- Retry on 500 errors (exponential backoff)
- Show user-friendly error messages
- Log errors for debugging
- Handle offline scenarios

**❌ DON'T:**
- Retry on 400 errors (client fault, won't succeed)
- Show raw API error codes to users
- Ignore network errors
- Block UI thread on network calls
- Skip error handling "for now"

### Performance

**✅ DO:**
- Use pagination for all list endpoints
- Cache static data (food/exercise databases)
- Debounce search queries
- Use async/await for all network calls
- Implement pull-to-refresh

**❌ DON'T:**
- Load all items at once (lists can be large)
- Fetch same data repeatedly
- Make network calls on main thread
- Block UI during loading
- Ignore loading states

---

## 📞 Resources

### API Documentation
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **Health Check:** https://fit-iq-backend.fly.dev/health
- **OpenAPI Spec:** `docs/api-spec.yaml` (symlinked)

### Integration Guides
- **All Guides:** `docs/api-integration/`
- **Start Here:** `docs/api-integration/getting-started/01-setup.md`

### Testing
- Test endpoints via Swagger UI before implementing
- All endpoints return consistent response format
- Full test coverage on backend (1,878+ tests passing)

---

## 🎯 Next Steps

### Immediate Actions (Day 1)

1. ✅ **Get API Key** - Contact backend admin
2. ✅ **Add to config.plist** - Store API key securely
3. ✅ **Verify API Access** - Test health endpoint
4. ✅ **Copy Docs** - Integration guides to your project
5. ✅ **Review Existing Code** - Understand Hexagonal Architecture patterns
6. ✅ **Read Setup Guide** - `getting-started/01-setup.md`
7. ✅ **Start Authentication** - `getting-started/02-authentication.md`

### This Week (Week 1)

- [ ] Complete authentication (register, login, token management)
- [ ] Implement error handling
- [ ] Test auth flow end-to-end
- [ ] Store tokens securely in Keychain
- [ ] Verify token refresh works

### Next Week (Week 2)

- [ ] Implement user profile
- [ ] Implement user preferences
- [ ] Complete onboarding flow
- [ ] Test profile updates

### Follow Integration Priority (Week 3+)

**Priority order (based on project requirements):**
1. **Nutrition Tracking** → `features/nutrition-tracking.md` (Week 3)
2. **Workout Tracking** → `features/workout-tracking.md` (Week 4)
3. **Goals & Templates** → Advanced features (Week 5-6)

---

## 💡 Pro Tips

### 1. Follow Existing Patterns
Examine the codebase first. Follow Hexagonal Architecture, SwiftData models, and existing domain patterns.

### 2. Config from Plist
Store API key and configuration in `config.plist`, not hardcoded. Load at runtime.

### 3. Create Domain Models
For API responses, create domain entities for local storage using SwiftData `@Model` where appropriate.

### 4. Don't Create UI
Focus on domain logic, use cases, repositories, and networking. UI/Views are handled separately.

### 5. Test Early, Test Often
Test each endpoint via Swagger UI before implementing in Swift. Understand the API before writing code.

### 6. Use Pagination
Almost all list endpoints support pagination. Implement it from day 1.

### 7. Handle Dates Properly
API uses UTC timezone with ISO 8601 format. Use `guides/date-handling.md` for proper conversion.

### 8. Cache Wisely with SwiftData
Food/exercise databases don't change often. Cache them using SwiftData. User data changes frequently - invalidate properly.

### 9. Think Offline
Network failures happen. Queue requests, show cached data using SwiftData persistence.

### 10. Monitor Token Expiry
Access tokens expire in 24 hours. Implement proactive refresh before they expire.

---

## 📝 Summary

### What You Have
- ✅ 119 production-ready API endpoints
- ✅ Complete Swift integration guides (bite-sized, focused)
- ✅ WebSocket for real-time AI chat
- ✅ 4,389 foods, 100+ exercises in databases
- ✅ 500+ pre-built meal templates
- ✅ Zero known bugs
- ✅ 1,878+ tests passing

### What You Need
- API key in `config.plist`
- Understanding of existing Hexagonal Architecture
- 3 days for authentication implementation
- Follow integration priority: Nutrition → Workouts → Advanced
- Follow the guides in `docs/api-integration/`

### Where to Start
1. Read: `getting-started/01-setup.md` (15 minutes)
2. Implement: `getting-started/02-authentication.md` (3 days)
3. Build: Choose features from `features/` directory

---

**The API is stable, tested, and ready. Follow the guides, integrate incrementally, and you'll have a full-featured health & fitness app! 🚀**

---

## 📋 Appendix: File Manifest

### Getting Started
```
docs/api-integration/getting-started/
├── 01-setup.md               # API key, Config.swift, verification
├── 02-authentication.md      # Register, login, JWT, Keychain
└── 03-error-handling.md      # Consistent error handling, retries
```

### Features
```
docs/api-integration/features/
├── user-profile.md           # Age, height, weight, BMI
├── user-preferences.md       # Units, themes, goals
├── nutrition-tracking.md     # Food search, logging, macros
├── workout-tracking.md       # Exercise search, logging
├── sleep-tracking.md         # Sleep hours, quality
├── activity-snapshots.md     # HealthKit sync
├── goals.md                  # Goal creation, progress
├── templates.md              # Meal/workout templates
└── analytics.md              # Trends, insights
```

### AI Consultation
```
docs/api-integration/ai-consultation/
├── 01-overview.md            # Why WebSocket, when to use
├── 02-websocket-setup.md     # Starscream, connection
├── 03-chat-interface.md      # SwiftUI chat UI
└── 04-template-creation.md   # AI creates templates
```

### Guides
```
docs/api-integration/guides/
├── pagination.md             # Handle paginated lists
├── date-handling.md          # UTC dates, formatting
├── healthkit-integration.md  # Sync health data
├── testing.md                # Unit tests, mocks
└── common-patterns.md        # Retry logic, caching
```

---

**Document Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Ready for iOS Integration

**This is a complete, self-contained integration guide. Everything you need is here. Start with `getting-started/01-setup.md` and build incrementally! Good luck! 🍀**