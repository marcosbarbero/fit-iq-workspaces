# Lume Architecture Overview

**Date:** 2025-01-15  
**Version:** 1.0.0  
**Purpose:** Document Lume's position in the broader solution landscape

---

## Solution Landscape

Lume is part of a comprehensive wellness and fitness solution ecosystem. The broader landscape includes:

### Backend Infrastructure
- **fit-iq-backend.fly.dev** - Shared backend infrastructure
- Provides authentication, data persistence, and API services
- Serves multiple client applications in the ecosystem
- Deployed on Fly.io for global availability

### Client Applications
- **Lume iOS App** - Wellness companion (mood, journal, goals)
- Other fitness and wellness applications (part of the ecosystem)
- Shared authentication and user management across applications

---

## Lume's Role

### Primary Purpose
Lume is a **wellness companion app** focused on:
- **Mood Tracking** - Daily emotional check-ins
- **Journaling** - Reflection and thought capture
- **Goal Setting** - Personal growth and achievement
- **AI Consulting** - Intelligent goal support and guidance

### Integration Strategy
- Uses shared backend infrastructure (fit-iq-backend)
- Shares authentication system with ecosystem applications
- Maintains independent wellness-focused UX
- Benefits from shared infrastructure reliability and scalability

---

## Backend Architecture

### Shared Services
The fit-iq backend provides:
- User authentication and authorization
- Token management (JWT with refresh tokens)
- Data persistence and retrieval
- API key authentication (`X-API-Key`)
- WebSocket support for real-time features

### API Integration
Lume connects to:
```
Base URL: https://fit-iq-backend.fly.dev
API Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW
```

Authentication endpoints:
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Token refresh
- `POST /api/v1/auth/logout` - User logout

Future endpoints (as implemented):
- `/api/v1/moods/*` - Mood tracking
- `/api/v1/journal/*` - Journal entries
- `/api/v1/goals/*` - Goal management
- `/api/v1/ai/*` - AI consulting services

---

## iOS App Architecture

### Hexagonal Architecture
Lume follows clean architecture principles:

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│    (SwiftUI Views & ViewModels)     │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│          Domain Layer                │
│  (Entities, Use Cases, Protocols)    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│       Infrastructure Layer           │
│  (Repositories, API Services,        │
│   SwiftData, Keychain, Outbox)       │
└──────────────────────────────────────┘
```

### Key Components

#### Presentation
- **SwiftUI Views** - Modern, declarative UI
- **ViewModels** - Observable state management
- **Design System** - Lume colors and typography
- Warm, calm, wellness-focused UX

#### Domain
- **Entities** - User, Mood, Journal, Goal, AuthToken
- **Use Cases** - Business logic (register, login, track mood)
- **Ports** - Protocol definitions for infrastructure
- Clean, testable, framework-independent

#### Infrastructure
- **Remote Services** - HTTP API communication with fit-iq backend
- **SwiftData** - Local persistence and caching
- **Keychain** - Secure token storage
- **Outbox Pattern** - Reliable external communication

---

## Data Flow

### Authentication Flow
```
User Action
    ↓
ViewModel
    ↓
Use Case (Domain)
    ↓
Repository (Infrastructure)
    ↓
Auth Service
    ↓
fit-iq Backend API
    ↓
Response → Token Storage (Keychain)
    ↓
User Authenticated → Main App
```

### Feature Data Flow (Mood, Journal, Goals)
```
User Input
    ↓
ViewModel
    ↓
Use Case
    ↓
Repository
    ↓
Outbox Event (pending)
    ↓
SwiftData (local save)
    ↓
Outbox Processor Service
    ↓
fit-iq Backend API
    ↓
Event marked completed
```

---

## Outbox Pattern

### Purpose
Ensures reliable communication with the shared backend:
- **Offline Support** - Data saved locally first
- **Guaranteed Delivery** - Retries on failure
- **No Data Loss** - Persisted before sending
- **Crash Resilience** - Survives app restarts

### Implementation
1. User action creates domain event
2. Event saved to outbox (SwiftData)
3. Outbox processor sends to backend
4. On success, event marked completed
5. On failure, event retried with backoff

---

## Configuration Management

### Environment Configuration
Centralized in `config.plist`:
```xml
<key>BACKEND_BASE_URL</key>
<string>https://fit-iq-backend.fly.dev</string>

<key>API_KEY</key>
<string>4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW</string>
```

### Benefits
- Easy environment switching (dev, staging, production)
- Secure API key management
- No hardcoded URLs in source code
- Shared with partner ecosystem

---

## Security Architecture

### Authentication
- **JWT Tokens** - Access and refresh tokens
- **Keychain Storage** - iOS secure enclave
- **Automatic Refresh** - Seamless token renewal
- **Shared Auth** - Single sign-on across ecosystem apps

### API Security
- **HTTPS** - Encrypted communication
- **API Key** - Backend authentication (`X-API-Key` header)
- **Token Validation** - Backend verifies JWT on each request
- **Secure Storage** - No credentials in UserDefaults or plain files

### Data Privacy
- **Local-First** - Data saved locally before sync
- **User-Controlled** - Clear data ownership
- **Encrypted Transit** - All API calls over HTTPS
- **Secure Keychain** - iOS-level encryption for tokens

---

## Partner Integration Benefits

### Shared Infrastructure
- ✅ Proven, reliable backend
- ✅ Scalable to ecosystem growth
- ✅ Consistent authentication across apps
- ✅ Shared user management
- ✅ Cost-effective infrastructure sharing

### Independence
- ✅ Lume-specific UI/UX
- ✅ Wellness-focused features
- ✅ Independent release cycle
- ✅ Dedicated brand identity
- ✅ Specialized user experience

---

## Technology Stack

### iOS App
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Persistence:** SwiftData
- **Architecture:** Hexagonal (Clean Architecture)
- **Patterns:** MVVM, Repository, Outbox, Dependency Injection
- **Minimum iOS:** 17.0

### Backend (Partner Infrastructure)
- **Platform:** Fly.io
- **Domain:** fit-iq-backend.fly.dev
- **Protocol:** HTTPS / WSS (WebSocket)
- **Authentication:** JWT + API Key
- **API Style:** RESTful JSON

---

## Future Capabilities

### Planned Features
- **Real-Time Sync** - WebSocket connection for live updates
- **Cross-App Data** - Share insights across ecosystem apps
- **Unified Profile** - Single user profile across applications
- **Shared Analytics** - Ecosystem-wide health insights
- **Partner Features** - Integration with other wellness services

### WebSocket Support
Already configured for future use:
```
WebSocketURL: wss://fit-iq-backend.fly.dev/ws/meal-logs
```

Ready for real-time features when implemented.

---

## Development Workflow

### Local Development
1. Backend: `https://fit-iq-backend.fly.dev` (shared)
2. iOS Simulator: Uses remote backend
3. Local testing: SwiftData in-memory mode
4. Mock services: For UI-only testing

### Staging/Production
- Same backend infrastructure
- Environment-specific API keys
- Configuration via `config.plist`
- Coordinated releases with partner team

---

## Team Collaboration

### Responsibilities

**Lume iOS Team:**
- iOS app development and maintenance
- Wellness-focused features
- UI/UX design for Lume brand
- Client-side data management
- App Store submission

**fit-iq Backend Team (Partner):**
- Backend API development
- Database and infrastructure
- Authentication system
- API security and rate limiting
- Shared services for ecosystem

---

## Communication Protocols

### API Contract
- RESTful JSON APIs
- Snake_case for JSON keys
- ISO 8601 for dates
- UUID for IDs
- HTTP status codes for responses

### Error Handling
Backend returns:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

iOS handles errors gracefully with user-friendly messages.

---

## Monitoring and Analytics

### App-Level Monitoring
- User authentication success/failure rates
- API response times
- Offline operation statistics
- Crash reporting

### Backend-Level Monitoring (Partner)
- API endpoint performance
- Database query efficiency
- Token refresh patterns
- System health and uptime

---

## Deployment Strategy

### iOS App
- **Distribution:** Apple App Store
- **Release Cycle:** Independent of backend
- **Version Strategy:** Semantic versioning
- **Testing:** TestFlight beta program

### Backend (Partner)
- **Platform:** Fly.io managed hosting
- **Deployment:** Continuous deployment
- **Availability:** Global edge locations
- **Monitoring:** Partner team responsibility

---

## Documentation

### Lume-Specific Docs
- `.github/copilot-instructions.md` - Architecture and design rules
- `docs/BACKEND_CONFIGURATION.md` - Backend setup
- `docs/MODERN_AUTH_UI.md` - UI design guide
- `docs/ADD_FILES_TO_XCODE.md` - Development setup

### Shared Documentation
- Partner backend API documentation
- Authentication flow specifications
- Data model schemas
- Integration guidelines

---

## Summary

Lume is a **wellness companion iOS app** that:
- Operates within a broader solution landscape
- Uses shared backend infrastructure (fit-iq-backend)
- Maintains independent wellness-focused identity
- Follows clean architecture principles
- Provides reliable offline-first experience
- Benefits from ecosystem collaboration

The architecture is designed for:
- ✅ **Reliability** - Outbox pattern, offline support
- ✅ **Security** - Keychain, HTTPS, JWT tokens
- ✅ **Maintainability** - Hexagonal architecture, SOLID principles
- ✅ **Scalability** - Shared infrastructure, proven backend
- ✅ **User Experience** - Calm, warm, wellness-focused design

**Lume provides a specialized wellness experience while leveraging robust shared infrastructure.**