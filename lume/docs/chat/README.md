# Chat Feature Documentation

**Last Updated:** 2025-01-30  
**Status:** ✅ Production Ready

---

## Overview

This directory contains all documentation related to the Lume iOS chat feature, including AI-powered wellness consultations, real-time messaging, conversation management, and goal generation integration.

---

## Quick Links

### Core Features
- [Goal Suggestions Integration](GOAL_SUGGESTIONS_INTEGRATION.md) - Generate personalized goals from chat conversations
- [Chat UI Enhancement](CHAT_UI_ENHANCEMENT.md) - Modern chat interface design
- [Chat UI Fixes](CHAT_UI_FIXES.md) - UI/UX improvements and polish

### Goals-Chat Integration (NEW - 2025-01-30)
- [Streaming Reliability Guide](STREAMING_RELIABILITY_GUIDE.md) - **Complete technical guide to streaming system**
- [Streaming UX Improvements](STREAMING_UX_IMPROVEMENTS.md) - Natural pacing and error handling
- [Goals Integration Debugging](../goals/GOALS_CHAT_INTEGRATION_DEBUGGING.md) - Problem/solution documentation

### Implementation Guides
- [Streaming Chat Summary](STREAMING_CHAT_SUMMARY.md) - WebSocket streaming implementation
- [Live Chat Implementation](LIVE_CHAT_FIX.md) - Real-time chat architecture
- [Consultation WebSocket Config](CONSULTATION_WS_CONFIG_FIX.md) - Backend WebSocket setup

### Fixes & Improvements
- [Chat Duplication Fix](CHAT_DUPLICATION_FIX.md) - Resolved message duplication issues
- [Chat Fixes Summary](CHAT_FIXES_SUMMARY.md) - Comprehensive fix documentation
- [Critical Fixes (2025-01-28)](CHAT_FIXES_2025_01_28.md) - Recent critical updates

### Testing
- [Chat Testing Steps](CHAT_TESTING_STEPS.md) - Test procedures and checklists
- [Live Chat Testing Guide](LIVE_CHAT_TESTING_GUIDE.md) - WebSocket testing procedures

### Status Reports
- [Live Chat Final Status](LIVE_CHAT_FINAL_STATUS.md) - Current production status
- [Live Chat Actor Fix](LIVE_CHAT_ACTOR_FIX.md) - Actor isolation improvements
- [Streaming Fixes](STREAMING_FIXES.md) - Stream handling updates

---

## Feature Capabilities

### 🤖 AI Wellness Consultations

**Personas Available:**
- General Wellness Coach
- Nutrition Expert
- Fitness Trainer
- Mental Health Supporter
- Sleep Coach

**Key Features:**
- Context-aware AI responses
- Multi-turn conversations
- Markdown rendering in messages
- Message persistence
- Conversation history

### 💬 Real-Time Messaging

**Communication Methods:**
- WebSocket streaming (primary)
- REST API fallback
- Automatic polling for offline resilience

**Message Features:**
- Real-time delivery
- Typing indicators
- Timestamp display
- Message read/unread status
- Automatic retry on failure

### 📁 Conversation Management

**Organization:**
- Active conversations
- Archived conversations
- Filter by persona
- Search functionality (planned)

**Actions:**
- Swipe to archive/unarchive
- Swipe to delete (with confirmation)
- Menu actions for bulk operations
- Auto-save on every message

### 🎯 Goal Generation & Integration

**From Conversation to Action:**
- AI analyzes chat context
- Generates 3 personalized goal suggestions
- One-tap goal creation
- Pre-populated with conversation insights
- Automatic conversation-goal linking

**Chat About Goals:**
- Contextual AI conversations about specific goals
- Seamless navigation from Goals tab
- Full goal context provided to AI
- Bidirectional goal-conversation linking

See [GOAL_SUGGESTIONS_INTEGRATION.md](GOAL_SUGGESTIONS_INTEGRATION.md) and [../goals/CHAT_INTEGRATION.md](../goals/CHAT_INTEGRATION.md) for complete details.

---

## Architecture

### Hexagonal Architecture Compliance

```
┌─────────────────────────────────────────────────┐
│         Presentation Layer (SwiftUI)             │
│                                                  │
│  • ChatView                                      │
│  • ChatListView                                  │
│  • ChatViewModel                                 │
│  • Goal Suggestion Components                    │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│            Domain Layer (Business Logic)         │
│                                                  │
│  • ChatMessage (Entity)                          │
│  • ChatConversation (Entity)                     │
│  • ChatRepositoryProtocol (Port)                 │
│  • ChatServiceProtocol (Port)                    │
│  • Use Cases:                                    │
│    - CreateConversationUseCase                   │
│    - SendChatMessageUseCase                      │
│    - FetchConversationsUseCase                   │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│      Infrastructure Layer (Implementation)       │
│                                                  │
│  • ChatRepository (SwiftData)                    │
│  • ChatService (WebSocket + REST)                │
│  • ChatBackendService (HTTP Client)              │
│  • ConsultationWebSocketManager                  │
│  • GoalAIService (Backend Integration)           │
└─────────────────────────────────────────────────┘
```

### Data Flow

**Message Sending:**
```
User Input → ViewModel → Use Case → Service → WebSocket/REST API → Backend
```

**Message Receiving:**
```
Backend → WebSocket → Service → ViewModel → SwiftUI (auto-updates)
```

**Persistence:**
```
New Message → Repository → SwiftData → Local Database
```

### Key Components

**ViewModels:**
- `ChatViewModel` - Main chat state management
  - Conversation list
  - Current conversation
  - Messages
  - WebSocket connection
  - Goal suggestions

**Services:**
- `ChatService` - WebSocket and REST communication
- `ChatBackendService` - HTTP API client
- `ConsultationWebSocketManager` - Real-time streaming
- `GoalAIService` - AI goal generation

**Repositories:**
- `ChatRepository` - SwiftData persistence
- Implements outbox pattern for resilience

**Use Cases:**
- `CreateConversationUseCase` - New conversation creation
- `SendChatMessageUseCase` - Message sending with retry
- `FetchConversationsUseCase` - Load conversation history

---

## Streaming Message System

### Architecture Overview

The chat feature uses a sophisticated streaming system for natural AI responses:

**Key Features:**
- 2-second polling interval for human-like pacing
- Single 30-second timeout as safety net (no resets)
- Graceful degradation on network issues
- Preserves partial content on timeout
- Automatic recovery from transient errors

**Design Principles:**
1. **Single Timeout Per Message** - Start once, never reset
2. **Natural Pacing** - 2-second updates feel thoughtful
3. **Preserve Partial Content** - Keep what's received on errors
4. **Continue Through Transients** - Don't stop on temporary network blips

See [STREAMING_RELIABILITY_GUIDE.md](STREAMING_RELIABILITY_GUIDE.md) for comprehensive technical details.

### Message Flow

```
User sends message
    ↓
Create streaming placeholder (isStreaming: true)
    ↓
Start 30s timeout (safety net)
    ↓
POST to backend
    ↓
Poll for updates (2s interval)
    ↓
Append chunks to message
    ↓
Backend signals completion
    ↓
Mark complete, cancel timeout
```

---

## UX Design Principles

### Warm & Welcoming
- Cozy color palette (`#F8F4EC` background)
- Soft rounded corners
- Generous spacing and padding
- Calm animations and transitions

### Clear Communication
- Easy-to-read typography (SF Pro Rounded)
- Markdown support for rich formatting
- Clear timestamp and status indicators
- Persona-specific colors and icons

### Resilient & Reliable
- Automatic reconnection on disconnect
- Message persistence across app launches
- Offline message queuing
- Clear error messages and recovery

### Intuitive Actions
- Familiar swipe gestures
- Confirmation for destructive actions
- Keyboard management (tap to dismiss)
- Smooth scrolling to latest message

---

## Testing Strategy

### Unit Tests
- ViewModel business logic
- Use case validation
- Message parsing and formatting
- Error handling paths

### Integration Tests
- WebSocket connection/disconnection
- Message persistence
- Conversation management
- Goal generation flow

### UI Tests
- Swipe actions
- Message sending
- Keyboard interactions
- Sheet presentations

### Manual Testing Checklist

See [CHAT_TESTING_STEPS.md](CHAT_TESTING_STEPS.md) and [../goals/GOALS_CHAT_TESTING_GUIDE.md](../goals/GOALS_CHAT_TESTING_GUIDE.md) for complete testing procedures.

**Critical Paths:**
- [ ] Send and receive messages
- [ ] Archive/unarchive conversations
- [ ] Delete conversations
- [ ] Generate goal suggestions
- [ ] Create goals from suggestions
- [ ] Chat about goals from Goals tab
- [ ] Streaming message reliability
- [ ] Markdown rendering (including horizontal rules)
- [ ] WebSocket reconnection
- [ ] Offline message queuing

---

## Known Issues & Limitations

### Current Limitations

1. **Fixed Polling Interval:**
   - 2-second interval for all messages
   - Could be adaptive based on message length or connection speed
   - Current implementation works well for typical conversations

2. **Limited Markdown Support:**
   - Supports: headers, bold, italic, lists, horizontal rules
   - Missing: code blocks, block quotes, tables, images
   - Sufficient for wellness conversations

3. **No Message Editing:**
   - Sent messages cannot be edited
   - Consider adding edit functionality

4. **No Message Search:**
   - Cannot search within conversations
   - Planned for future release

5. **No Voice Input:**
   - Text-only communication
   - Voice input planned for accessibility

### Future Enhancements

- Adaptive streaming speed based on context
- WebSocket upgrade (eliminate polling)
- Richer markdown support (code blocks, tables)
- Backend sync for archive/unarchive actions
- Conversation search functionality
- Message reactions/emoji support
- Conversation export feature

---

## Backend API Reference

### Base URL
```
https://fit-iq-backend.fly.dev/api/v1
```

### Endpoints

**Create Consultation:**
```
POST /consultations
Body: { "persona": "general_wellness", "context": {...} }
Response: { "id": "uuid", "status": "active", ... }
```

**Send Message (REST):**
```
POST /consultations/{id}/messages
Body: { "content": "Hello", "role": "user" }
Response: { "message": {...}, "response": {...} }
```

**WebSocket Streaming:**
```
WS wss://fit-iq-backend.fly.dev/ws
Message: { "type": "consultation", "consultation_id": "uuid", "content": "..." }
```

**Generate Goal Suggestions:**
```
POST /consultations/{id}/suggest-goals
Body: { "max_suggestions": 3 }
Response: { "suggestions": [...] }
```

See backend documentation for complete API reference.

---

## Troubleshooting

### Messages Not Appearing

**Symptoms:** Messages sent but not displayed in UI

**Solutions:**
1. Check WebSocket connection status
2. Verify message persistence in local database
3. Review console logs for errors
4. Restart app to force reload

### WebSocket Connection Failures

**Symptoms:** Cannot connect to live chat

**Solutions:**
1. Check network connectivity
2. Verify auth token is valid
3. Check backend health status
4. Fall back to REST API mode

### Streaming Messages Get Stuck

**Symptoms:** Message shows "..." indefinitely

**Solutions:**
1. Wait for 30-second timeout (automatic recovery)
2. Check network connectivity
3. Verify polling is active
4. Review console logs for errors
5. If persistent, restart app

### Messages Split into Multiple Bubbles

**Symptoms:** Each word appears as separate message

**Solutions:**
1. This should not happen in current implementation
2. If it does, it's a critical bug - report immediately
3. Check that timeout is NOT being reset on chunk updates
4. Verify single timeout strategy is in place

### Goal Suggestions Not Generating

**Symptoms:** Prompt appears but suggestions fail

**Solutions:**
1. Verify conversation has backend ID
2. Check auth token validity
3. Ensure minimum message count met
4. Review backend logs for errors

---

## Migration Notes

### From Legacy Chat to Current System

**Breaking Changes:**
- WebSocket protocol updated to match backend guide
- Message model includes new metadata fields
- Conversation model requires backend ID

**Migration Steps:**
1. Clear old local conversations (if needed)
2. Update SwiftData models
3. Re-authenticate to get fresh tokens
4. Create new conversations with updated flow

---

## Performance Metrics

### Streaming Reliability
- **Polling Rate:** 30 requests/minute (2s interval)
- **Timeout Safety Net:** 30 seconds
- **Message Splitting:** 0% (eliminated)
- **Stuck Messages:** <5% (timeout recovery)
- **Network Efficiency:** 50% reduction vs 1s polling

### User Experience
- **Streaming Speed:** Natural 2s pacing
- **Response Time:** <2s for first chunk
- **Error Recovery:** Automatic on transient errors
- **Partial Content:** Preserved on timeout

---

## Contributing

### Adding New Features

1. **Follow Architecture:**
   - Domain first (entities, use cases, ports)
   - Infrastructure second (implementations)
   - Presentation last (UI, ViewModels)

2. **Maintain UX Principles:**
   - Warm and welcoming design
   - Clear communication
   - Resilient error handling

3. **Document Everything:**
   - Update README
   - Add inline code comments
   - Create feature-specific docs

4. **Test Thoroughly:**
   - Unit tests for business logic
   - Integration tests for flows
   - Manual testing for UX

### Code Style

- Follow Swift API Design Guidelines
- Use `async/await` for asynchronous code
- Apply `@MainActor` for UI updates
- Document public APIs with DocC comments

---

## Version History

### v2.1.0 (2025-01-30) - Current
- ✅ Goals-Chat integration complete
- ✅ Streaming reliability improvements (2s pacing, single timeout)
- ✅ Markdown horizontal rules support
- ✅ Chat about specific goals from Goals tab
- ✅ Goal-conversation bidirectional linking
- ✅ UI polish (no flickering, high-contrast icons)
- ✅ Comprehensive documentation added

### v2.0.0 (2025-01-29)
- ✅ Goal suggestions integration
- ✅ Swipe actions (archive, delete)
- ✅ Markdown rendering
- ✅ Keyboard management improvements
- ✅ WebSocket streaming stability

### v1.5.0 (2025-01-28)
- ✅ Live chat with WebSocket
- ✅ Message persistence
- ✅ Conversation management
- ✅ Multi-persona support

### v1.0.0 (Initial Release)
- Basic REST API chat
- Single conversation support
- Simple message display

---

## Support & Contact

For technical issues or questions:
- Review documentation in this directory
- Check [GitHub Issues](../../issues)
- Contact development team

For UX feedback:
- Submit feature requests
- Report usability issues
- Share improvement ideas

---

## License

© 2025 Lume Wellness. All rights reserved.