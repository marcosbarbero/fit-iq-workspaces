# Goals Feature Documentation

**Last Updated:** 2025-01-30  
**Status:** ✅ Production Ready  
**Feature Owner:** iOS Engineering Team

---

## Overview

The Goals feature enables users to set, track, and achieve wellness goals with AI-powered assistance. Goals can be created manually or from AI suggestions during chat conversations, and users can have contextual AI coaching sessions about specific goals.

---

## Key Features

### Core Functionality
- ✅ Create and manage wellness goals
- ✅ Track progress and status
- ✅ Set target dates and categories
- ✅ Swipe actions for quick access
- ✅ Goal detail views with full context

### AI Integration
- ✅ Create goals from chat suggestions
- ✅ Chat about specific goals with AI context
- ✅ AI-powered goal recommendations
- ✅ Progress tracking and insights

### Backend Sync
- ✅ Automatic synchronization to backend
- ✅ Offline support with local-first approach
- ✅ Outbox pattern for reliable communication
- ✅ Bidirectional goal-conversation linking

---

## Documentation

### Getting Started
- **[Goal Management Features](GOAL_MANAGEMENT_FEATURES.md)** - Overview of goal CRUD operations
- **[Swipe Actions & Chat](SWIPE_ACTIONS_AND_CHAT.md)** - Quick actions and chat integration

### Integration Guides
- **[Goals-Chat Integration](CHAT_INTEGRATION.md)** - How goals and chat work together
- **[Integration Debugging](GOALS_CHAT_INTEGRATION_DEBUGGING.md)** - Comprehensive technical guide
- **[Implementation Status](IMPLEMENTATION_COMPLETE.md)** - Feature completion summary

### Testing
- **[QA Testing Guide](GOALS_CHAT_TESTING_GUIDE.md)** - Complete testing scenarios and checklists

---

## Architecture

### Domain Model

```swift
struct Goal: Identifiable, Codable {
    let id: UUID              // Local SwiftData ID
    let backendId: String?    // Backend API ID
    var title: String
    var description: String
    var createdAt: Date
    var targetDate: Date
    var progress: Double      // 0.0 to 1.0
    var status: GoalStatus
    var userId: String?
    var conversationId: String? // Links to AI chat
    var category: String?
}

enum GoalStatus: String, Codable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case archived = "archived"
}
```

### Data Flow

```
User Action (Create/Edit/Delete Goal)
    ↓
GoalDetailViewModel
    ↓
ManageGoalUseCase
    ↓
GoalRepository (Domain Protocol)
    ↓
GoalRepositoryImpl (Infrastructure)
    ↓
SwiftData (SDGoal)
    ↓
Outbox Event (for backend sync)
    ↓
OutboxProcessor
    ↓
Backend API
```

---

## Key Components

### Presentation Layer
- `GoalListView.swift` - Main goals list with swipe actions
- `GoalDetailView.swift` - Goal details and editing
- `CreateGoalView.swift` - New goal creation
- `GoalListViewModel.swift` - List state management
- `GoalDetailViewModel.swift` - Detail and chat integration

### Domain Layer
- `Goal.swift` - Domain entity
- `GoalStatus.swift` - Status enumeration
- `ManageGoalUseCase.swift` - Business logic
- `GoalRepositoryProtocol.swift` - Repository interface

### Infrastructure Layer
- `GoalRepository.swift` - SwiftData implementation
- `SDGoal.swift` - SwiftData model
- `GoalSyncService.swift` - Backend synchronization
- `GoalAPIClient.swift` - API communication

---

## API Integration

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/goals` | POST | Create new goal |
| `/api/v1/goals` | GET | Fetch all goals |
| `/api/v1/goals/{id}` | GET | Fetch single goal |
| `/api/v1/goals/{id}` | PATCH | Update goal |
| `/api/v1/goals/{id}` | DELETE | Delete goal |
| `/api/v1/consultations/chat-about-goal` | POST | Create conversation for goal |

### Data Models

**Create Goal Request:**
```json
{
  "title": "Exercise 3x per week",
  "description": "Build a consistent workout habit",
  "targetDate": "2025-03-01T00:00:00Z",
  "category": "fitness"
}
```

**Goal Response:**
```json
{
  "id": "backend-goal-id",
  "userId": "user-id",
  "title": "Exercise 3x per week",
  "description": "Build a consistent workout habit",
  "status": "not_started",
  "progress": 0.0,
  "category": "fitness",
  "targetDate": "2025-03-01T00:00:00Z",
  "conversationId": null,
  "createdAt": "2025-01-30T10:00:00Z",
  "updatedAt": "2025-01-30T10:00:00Z"
}
```

---

## User Flows

### Flow 1: Create Goal Manually

```
User taps "+" in Goals tab
    ↓
CreateGoalView appears
    ↓
User fills in:
    - Title (required)
    - Description (optional)
    - Target Date (default: 30 days)
    - Category (optional)
    ↓
User taps "Create Goal"
    ↓
Goal saved locally (SwiftData)
    ↓
Outbox event created
    ↓
Background sync to backend
    ↓
Backend ID stored locally
    ↓
Goal appears in list
```

### Flow 2: Create Goal from Chat

```
User chats with AI about wellness
    ↓
AI suggests a goal
    ↓
Goal suggestion card appears in chat
    ↓
User taps "Create Goal"
    ↓
Goal sent to backend immediately
    ↓
Backend returns goal with ID
    ↓
Goal saved locally with backend ID
    ↓
Conversation ID linked to goal
    ↓
Goal appears in Goals tab
    ↓
User can tap "Chat About This Goal"
```

### Flow 3: Chat About Goal

```
User in Goals tab
    ↓
Swipes left on goal
    ↓
Taps "Chat" action
    ↓
Check: Does goal have backend ID?
    ├─ NO → Sync to backend first
    └─ YES → Continue
    ↓
Check: Does goal have conversation ID?
    ├─ NO → Create new conversation
    └─ YES → Load existing conversation
    ↓
Navigate to ChatView with goal context
    ↓
AI has full goal context for conversation
```

---

## Features in Detail

### Goal Status Tracking
- **Not Started** - Goal created but no progress yet
- **In Progress** - User actively working on goal
- **Completed** - Goal achieved (progress = 100%)
- **Archived** - Goal no longer active (hidden from main list)

### Progress Tracking
- Progress represented as 0.0 to 1.0 (0% to 100%)
- Manual updates through goal detail view
- Future: Automatic tracking from user activity

### Categories
- fitness
- nutrition
- sleep
- mindfulness
- social
- personal_growth
- (custom categories supported)

### Swipe Actions
- **Chat** (purple) - Start AI conversation about goal
- **Edit** (blue) - Edit goal details
- **Delete** (red) - Remove goal (with confirmation)

---

## Sync Strategy

### Local-First Approach
1. All goal operations work offline
2. Changes saved to local SwiftData immediately
3. Outbox events created for backend sync
4. Background processor syncs when online
5. Backend ID stored after successful sync

### Conflict Resolution
- Last-write-wins for simple updates
- Backend is source of truth for conversationId
- Local changes preserved during offline periods
- Sync retries on failure (exponential backoff)

---

## Error Handling

### Common Errors

**Missing Backend ID**
- **Cause:** Goal not yet synced to backend
- **Solution:** Automatic sync before chat creation
- **User Message:** "Preparing goal for chat..."

**Network Timeout**
- **Cause:** Slow or lost connection
- **Solution:** Retry with exponential backoff
- **User Message:** "Connection issues. Retrying..."

**Goal Not Found (404)**
- **Cause:** Goal deleted on backend
- **Solution:** Prompt user to refresh or remove local copy
- **User Message:** "This goal is no longer available."

**Sync Failure**
- **Cause:** Backend error or validation failure
- **Solution:** Keep in outbox for retry
- **User Message:** "Changes will sync when connection improves"

---

## Testing

### Unit Tests
- Goal repository CRUD operations
- Domain model validation
- Use case business logic
- ViewModel state management

### Integration Tests
- End-to-end goal creation flow
- Backend sync verification
- Chat integration flow
- Offline/online transitions

### Manual Testing
See [Goals-Chat Testing Guide](GOALS_CHAT_TESTING_GUIDE.md) for comprehensive test scenarios.

---

## Performance Considerations

### Optimization Strategies
- Lazy loading of goal details
- Efficient SwiftData queries with predicates
- Background sync doesn't block UI
- Image/avatar caching (future feature)

### Metrics
- Goal creation: <100ms local save
- Goal list load: <200ms for 100 goals
- Backend sync: <2s per goal
- Chat navigation: <500ms

---

## Accessibility

### VoiceOver Support
- All buttons and actions labeled
- Goal titles announced clearly
- Progress values spoken as percentages
- Status changes announced

### Dynamic Type
- All text scales with system font size
- Layout adapts to larger text
- No text clipping or overlap

### Color Contrast
- All text meets WCAG AA standards
- Status colors distinguishable
- Action buttons high contrast

---

## Future Enhancements

### Short Term
- [ ] Goal templates for common wellness goals
- [ ] Progress charts and visualizations
- [ ] Goal reminders and notifications
- [ ] Share goals with friends/family

### Medium Term
- [ ] Habit tracking integration
- [ ] HealthKit data integration
- [ ] Goal streaks and milestones
- [ ] AI proactive check-ins

### Long Term
- [ ] Community goal challenges
- [ ] Goal accountability partners
- [ ] Rewards and achievements
- [ ] Goal analytics and insights

---

## Related Documentation

- **[Chat Integration Details](../chat/STREAMING_RELIABILITY_GUIDE.md)**
- **[Backend API Contracts](../backend-integration/GOAL_CONVERSATION_LINKING.md)**
- **[Architecture Overview](../ARCHITECTURE_OVERVIEW.md)**
- **[Executive Summary](../GOALS_CHAT_INTEGRATION_SUMMARY.md)**

---

## Support

**Technical Questions:** iOS Engineering Team  
**Bug Reports:** Use bug report template in testing guide  
**Feature Requests:** Product Team  
**API Issues:** Backend Team

---

**Feature Status:** ✅ Production Ready  
**Documentation Version:** 1.0.0  
**Last Verified:** 2025-01-30