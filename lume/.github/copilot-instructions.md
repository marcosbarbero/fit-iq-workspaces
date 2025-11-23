# Lume iOS App – AI Assistant Instructions

**Version:** 2.0.0  
**Last Updated:** 2025-01-15  
**Purpose:** Core architecture and design rules for Lume iOS wellness app

---

## ⚠️ Deferred Features (Check Before Implementing!)

**"Chat About Goal" Button** - Temporarily removed from UI (2025-01-15)
- **Status:** All functionality is implemented and working, button simply hidden
- **Location:** `GoalDetailView.swift` - see inline comment where button was removed
- **Reason:** Gathering user feedback on "Get AI Tips" feature first before offering chat option
- **Functions preserved:** `createGoalChat()`, `GoalChatView`, all goal conversation logic
- **Documentation:** `docs/design/GOAL_CHAT_FEATURE_DEFERRED.md`
- **To re-enable:** Restore button UI (see deferred features doc for exact implementation)

**Before adding similar features:** Check `README.md` "Deferred Features" section and `docs/design/` directory.

---

## Project Overview

Lume is a warm and calm wellness app focused on:

* User authentication and profile management  
* Mood tracking  
* Journaling  
* Goal tracking with AI consulting  

**Core Principle:** Everything must feel cozy, warm, and reassuring. No pressure mechanics.

**Core Technologies:**
* SwiftUI  
* SwiftData  
* Async/await  
* MVVM  
* Hexagonal Architecture  
* Outbox pattern for external communication  
* Dependency Injection via `AppDependencies`  

---

## Architecture Principles

### Hexagonal Architecture

```
Presentation (Views + ViewModels)
    ↓ depends on
Domain (Entities + Use Cases + Ports)
    ↓ depends on
Infrastructure (SwiftData + Repositories + External Services)
```

**Rules:**
* Domain owns business rules and defines ports (protocols)
* Infrastructure implements ports
* Presentation knows only the domain layer
* No SwiftUI in domain
* No SwiftData in domain or presentation
* Dependencies always point inward toward domain

### SOLID Principles

* **Single Responsibility:** Every type has one purpose
* **Open/Closed:** Extend via protocols, don't modify existing logic
* **Liskov Substitution:** Any implementation must work wherever the protocol is expected
* **Interface Segregation:** Keep protocols focused and minimal
* **Dependency Inversion:** Domain depends only on abstractions

---

## Documentation Organization

All project documentation must be organized under `docs/` in feature-specific subdirectories:

```
docs/
    architecture/           # Architecture decisions and patterns
    authentication/         # Auth flow and implementation
    backend-integration/    # API integration docs
    mood-tracking/          # Mood tracking feature docs
    design/                 # UI/UX design decisions
    fixes/                  # Bug fixes and improvements
    onboarding/            # User onboarding docs
```

**Rules:**
* Keep only `README.md` in project root
* All feature docs go in `docs/<feature-name>/`
* Use descriptive filenames (e.g., `MOOD_REDESIGN_SUMMARY.md`)
* Update docs when making significant changes
* Remove outdated documentation promptly

---

## Project Structure

```
LumeApp/
    Presentation/
        ViewModels/
        Views/
        Authentication/
    Domain/
        Entities/
        UseCases/
        Ports/
    Data/
        Persistence/
        Repositories/
    Services/
        OutboxProcessorService.swift
        Authentication/
    DI/
        AppDependencies.swift
    Core/
        Network/
        Security/
        Configuration/
    LumeApp.swift
    config.plist
```

---

## UX and Brand Foundations

### Emotional Feel
* Calm, warm, cozy, non-judgmental
* Minimal elements per screen
* Generous margins and soft corners
* Calm motion and gentle fades

### Color Palette

#### Core Colors

| Purpose | Hex | Usage |
|---------|-----|-------|
| App Background | `#F8F4EC` | Main screen background |
| Surface | `#E8DFD6` | Cards and elevated surfaces |
| Primary Accent | `#F2C9A7` | Primary buttons and highlights |
| Secondary Accent | `#D8C8EA` | Secondary elements |
| Primary Text | `#3B332C` | Headings and body text |
| Secondary Text | `#6E625A` | Supporting text |

#### Mood Colors (Positive Emotions)

| Mood | Hex | Description |
|------|-----|-------------|
| Amazed | `#E8D4F0` | Light purple - wonder and awe |
| Grateful | `#FFD4E5` | Light rose - warmth and appreciation |
| Happy | `#F5DFA8` | Bright yellow - joy and positivity |
| Proud | `#D4B8F0` | Soft purple - achievement and confidence |
| Hopeful | `#B8E8D4` | Light mint - optimism and encouragement |
| Content | `#D8E8C8` | Sage green - peace and satisfaction |
| Peaceful | `#C8D8EA` | Soft sky blue - calm and serenity |
| Excited | `#FFE4B5` | Light orange - energy and enthusiasm |
| Joyful | `#F5E8A8` | Bright lemon - delight and cheerfulness |

#### Mood Colors (Challenging Emotions)

| Mood | Hex | Description |
|------|-----|-------------|
| Sad | `#C8D4E8` | Light blue - melancholy and down |
| Angry | `#F0B8A4` | Soft coral - frustration and upset |
| Stressed | `#E8C4B4` | Soft peach - tension and overwhelm |
| Anxious | `#E8E4D8` | Light tan - unease and worry |
| Frustrated | `#F0C8A4` | Light terracotta - irritation and annoyance |
| Overwhelmed | `#D4C8E8` | Light purple-gray - too much to handle |
| Lonely | `#B8C8E8` | Cool lavender-blue - isolation and disconnection |
| Scared | `#E8D4C8` | Warm beige - fear and apprehension |
| Worried | `#D8C8D8` | Light mauve - concern and trouble |

#### Legacy Mood Colors (for backward compatibility)

| Purpose | Hex | Usage |
|---------|-----|-------|
| Mood Positive | `#F5DFA8` | High mood indicator |
| Mood Neutral | `#D8E8C8` | Neutral mood indicator |
| Mood Low | `#F0B8A4` | Low mood indicator |

### Typography
* Use SF Pro Rounded family
* Comfortable spacing and readable line heights
* Size scale: Title Large (28pt), Title Medium (22pt), Body (17pt), Body Small (15pt), Caption (13pt)

### Authentication UI
* Clean, modern design with subtle branding
* Small icon with app name at top
* Single clear heading per screen
* Direct-to-auth flow (no landing page friction)
* Minimal form fields with clear labels

---

## Backend Configuration

### Infrastructure
Lume uses shared backend infrastructure as part of a broader wellness solution ecosystem.

**Backend Host:** `fit-iq-backend.fly.dev`

### Configuration Management

Backend settings are stored in `config.plist`:

```xml
<key>Backend</key>
<dict>
    <key>BaseURL</key>
    <string>https://fit-iq-backend.fly.dev</string>
    <key>APIKey</key>
    <string>your-api-key</string>
    <key>WebSocketURL</key>
    <string>wss://fit-iq-backend.fly.dev/ws</string>
</dict>
```

Access via centralized `AppConfiguration` system for type-safe, secure config access.

### Authentication Endpoints

* `POST /api/v1/auth/register` - User registration
* `POST /api/v1/auth/login` - User login
* `POST /api/v1/auth/refresh` - Token refresh
* `POST /api/v1/auth/logout` - User logout

### Registration API Contract

**Request Fields (required):**
* `name` - User's full name
* `email` - User's email address
* `password` - User's password (minimum 8 characters)
* `date_of_birth` - User's date of birth in YYYY-MM-DD format

**Note:** `date_of_birth` is REQUIRED for COPPA compliance. Backend validates that users must be 13+ years old.

**Response Format:**
```json
{
    "user": {
        "id": "uuid",
        "email": "user@example.com",
        "name": "User Name"
    },
    "token": {
        "access_token": "jwt_token",
        "refresh_token": "refresh_token",
        "expires_at": "ISO8601_date"
    }
}
```

### Error Handling

Standard error format:
```json
{
    "error": {
        "code": "ERROR_CODE",
        "message": "Human readable message"
    }
}
```

Common codes:
* `INVALID_CREDENTIALS` - Wrong email/password
* `USER_ALREADY_EXISTS` - Email already registered
* `TOKEN_EXPIRED` - Refresh needed
* `INVALID_TOKEN` - Re-authentication required

---

## Domain Layer

### Core Entities

```swift
struct User: Identifiable, Codable {
    let id: UUID
    let email: String
    let name: String
    let createdAt: Date
}

struct AuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mood: MoodKind // high, ok, low
    let notePreview: String
}

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var text: String
}

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var createdAt: Date
    var targetDate: Date
    var progress: Double
}
```

### Port Examples (Domain Interfaces)

```swift
protocol AuthRepositoryProtocol {
    func register(email: String, password: String, name: String) async throws -> User
    func login(email: String, password: String) async throws -> User
    func refreshToken() async throws -> AuthToken
    func logout() async throws
}

protocol TokenStorageProtocol {
    func saveToken(_ token: AuthToken) async throws
    func getToken() async throws -> AuthToken?
    func deleteToken() async throws
}

protocol MoodRepositoryProtocol {
    func save(_ entry: MoodEntry) async throws
    func fetchRecent(days: Int) async throws -> [MoodEntry]
}

protocol GoalRepositoryProtocol {
    func save(_ goal: Goal) async throws
    func update(_ goal: Goal) async throws
    func fetchAll() async throws -> [Goal]
}
```

---

## Outbox Pattern

**Rule:** All external communication (authentication, AI, cloud sync) MUST use the Outbox pattern.

### Flow

1. Use case creates event
2. Repository saves `SDOutboxEvent` (status: pending)
3. `OutboxProcessorService` fetches pending events
4. Processor sends to external service
5. Event marked completed or failed

### Benefits
* Offline support
* No data loss on crashes
* Automatic retry capability
* Resilient external communication

### Outbox Model

```swift
@Model
final class SDOutboxEvent {
    var id: UUID
    var createdAt: Date
    var eventType: String
    var payload: Data
    var status: String // pending, completed, failed
    var retryCount: Int
}
```

---

## Security Requirements

### Token Management
* Store tokens in iOS Keychain via `TokenStorageProtocol`
* Never log tokens or passwords
* Implement automatic token refresh before expiration
* Clear tokens on logout

### Password Handling
* Never store passwords in plain text
* Use secure text entry fields in UI
* Clear password fields after submission

### API Communication
* HTTPS only for backend communication
* Include auth tokens in request headers
* Handle token expiration gracefully
* Consider certificate pinning for production

### Error Messages
* Never expose sensitive information in errors
* Provide user-friendly messages
* Log failures without sensitive details

---

## AI Consulting Integration

AI assists users in achieving their goals through:
* Friendly check-ins
* Motivational suggestions
* Context awareness via mood and journal history

**Rule:** AI features must be accessed only through use cases and ports, never directly from ViewModels.

---

## Implementation Checklist

**Architecture:**
- [ ] Follow Hexagonal Architecture
- [ ] Apply SOLID principles everywhere
- [ ] Use domain entities and use cases
- [ ] Define repository protocols in domain
- [ ] Implement repositories in infrastructure
- [ ] Use Outbox pattern for all external calls

**Data:**
- [ ] Place SwiftData only in infrastructure layer
- [ ] Keep domain clean of persistence details
- [ ] Translate between domain and SwiftData models

**UI/UX:**
- [ ] Keep UI calm and minimal
- [ ] Follow brand colors and typography
- [ ] Use modern, clean authentication design
- [ ] Single clear heading per screen
- [ ] Generous margins and soft corners

**Security:**
- [ ] Store tokens securely in Keychain
- [ ] Never expose sensitive data in logs or errors
- [ ] Implement proper token refresh flow
- [ ] Handle authentication errors gracefully

**Backend:**
- [ ] Use `config.plist` for backend configuration
- [ ] Access config via `AppConfiguration` system
- [ ] Match registration API contract (name, email, password only)
- [ ] Handle standard error response format

---

## Summary

Lume must remain warm, calm, and grounded in every interaction.

The architecture must stay clean through Hexagonal Architecture and SOLID principles.

External communication uses the Outbox pattern for resilience and offline support.

Authentication provides secure access while maintaining a welcoming feel.

Security is paramount but never compromises the warm user experience.

Backend integration uses shared infrastructure with type-safe configuration management.