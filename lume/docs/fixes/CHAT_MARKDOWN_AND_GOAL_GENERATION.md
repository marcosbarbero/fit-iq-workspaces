# Chat Markdown Rendering & Goal Generation from Consultations

**Date:** 2025-01-29  
**Status:** In Progress  
**Components:** ChatView, MessageBubble, Goal Generation, Consultation AI

---

## Issue 1: Markdown Not Rendering in Chat Messages

### Problem

AI responses contain markdown formatting (bold, italic, lists, code blocks), but the chat view displays them as raw markdown syntax instead of rendering them properly.

**Example:**
- AI sends: `**Take 10 deep breaths** and focus on _mindfulness_`
- User sees: `**Take 10 deep breaths** and focus on _mindfulness_` (raw text)
- Expected: **Take 10 deep breaths** and focus on _mindfulness_ (formatted)

### Root Cause

The `MessageBubble` component used `Text()` to display all messages, which doesn't support markdown rendering in SwiftUI.

### Solution

Implemented conditional rendering using the `MarkdownUI` package:
- **User messages:** Plain `Text()` (no markdown needed)
- **AI messages:** `Markdown()` component with custom styling

### Implementation

#### Changes to ChatView.swift

```swift
import MarkdownUI  // Added package

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        Group {
            if message.isAssistantMessage {
                // Render markdown for AI messages
                Markdown(message.content)
                    .markdownTextStyle(\.text) {
                        FontFamily(.custom("SF Pro Rounded"))
                        FontSize(17)
                        ForegroundColor(LumeColors.textPrimary)
                    }
                    .markdownTextStyle(\.strong) {
                        FontWeight(.semibold)
                    }
                    .markdownTextStyle(\.emphasis) {
                        FontStyle(.italic)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamily(.monospaced)
                        FontSize(15)
                        BackgroundColor(Color.black.opacity(0.05))
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        configuration.label
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    }
            } else {
                // Plain text for user messages
                Text(message.content)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    message.isUserMessage
                        ? Color(hex: "#F2C9A7").opacity(0.3)
                        : Color.white.opacity(0.5)
                )
        )
    }
}
```

### Package Dependency

**Required:** Add `swift-markdown-ui` package to Xcode project

```
https://github.com/gonzalezreal/swift-markdown-ui
```

**Version:** Use latest stable version (2.x recommended)

### Supported Markdown Features

| Feature | Syntax | Rendered |
|---------|--------|----------|
| Bold | `**text**` | **text** |
| Italic | `_text_` | _text_ |
| Inline Code | `` `code` `` | `code` |
| Code Block | ` ```code``` ` | Code block with background |
| Lists | `- item` | • item |
| Links | `[text](url)` | Clickable link |
| Headers | `# Heading` | Larger, bold text |

### Testing

1. **Test Bold Text:**
   - User: "How can I improve my sleep?"
   - AI: "Try these **important** tips..."
   - Verify: "important" appears bold

2. **Test Lists:**
   - AI sends numbered or bulleted lists
   - Verify: Lists render with proper bullets/numbers

3. **Test Code:**
   - AI sends inline code or code blocks
   - Verify: Code appears in monospace with background

4. **Test User Messages:**
   - User sends markdown syntax
   - Verify: Displays as plain text (no rendering)

---

## Issue 2: Goal Generation from Chat Consultations

### Question

Can the AI chatbot generate goals based on conversation context, and if so, how is it implemented?

### Answer: Yes, with Existing Infrastructure

The app already has robust goal generation capabilities that **can be integrated** with chat consultations.

### Current Architecture

#### 1. Goal Suggestion System (Already Implemented)

**Location:** `Domain/UseCases/Goals/GenerateGoalSuggestionsUseCase.swift`

**How it works:**
1. Collects user context (mood, journal, existing goals)
2. Sends context to backend AI service
3. Backend returns 3-5 personalized goal suggestions
4. Suggestions filtered against existing goals (avoid duplicates)

**API Endpoint:** `POST /api/v1/goals/suggestions`

**Response Format:**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "title": "Walk 10,000 steps daily",
        "description": "Increase daily activity by walking...",
        "goal_type": "activity",
        "target_value": 10000,
        "target_unit": "steps",
        "rationale": "Based on your current activity level...",
        "estimated_duration": 30,
        "difficulty": 2
      }
    ],
    "count": 3
  }
}
```

#### 2. Consultation Context System (Implemented)

**Location:** Consultations can be linked to goals via `context_type` and `context_id`

**Create Consultation with Goal Context:**
```swift
// Example: Start consultation about a specific goal
let request = CreateConsultationRequest(
    persona: "general_wellness",
    context_type: "goal",
    context_id: goalId.uuidString,
    initial_message: "Help me achieve this goal"
)
```

### Proposed Integration: Chat-to-Goal Flow

#### Option 1: Add "Generate Goal" Button in Chat

**User Flow:**
1. User has conversation with AI about wellness
2. AI suggests creating a goal
3. User taps "Generate Goal from Conversation" button
4. System triggers goal suggestion API with conversation context
5. Show goal suggestions view
6. User selects/customizes and creates goal

**Implementation:**

```swift
// Add to ChatViewModel
func generateGoalFromConversation() async {
    guard let conversation = currentConversation else { return }
    
    // Build context from conversation messages
    let conversationContext = buildContextFromMessages()
    
    // Trigger goal suggestion
    let suggestions = try await generateGoalSuggestionsUseCase.execute()
    
    // Show suggestions UI
    showGoalSuggestions = true
}

private func buildContextFromMessages() -> UserContextData {
    // Extract topics, user concerns, and AI recommendations from messages
    let recentMessages = messages.suffix(10) // Last 10 messages
    
    // Parse conversation for wellness insights
    let topics = extractTopics(from: recentMessages)
    let concerns = extractConcerns(from: recentMessages)
    
    // Build context
    return UserContextData(
        topics: topics,
        userConcerns: concerns,
        conversationHistory: recentMessages.map { $0.content }
    )
}
```

**UI Addition to ChatView:**

```swift
// Add toolbar button
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
            Task {
                await viewModel.generateGoalFromConversation()
            }
        }) {
            Label("Generate Goal", systemImage: "target")
        }
        .disabled(viewModel.messages.count < 3) // Need conversation first
    }
}
```

#### Option 2: AI-Initiated Goal Generation (Backend Required)

**Concept:** Backend AI detects when conversation leads to actionable goal and offers to create it.

**Backend Changes Needed:**
1. Add function calling capability to consultation AI
2. Define `create_goal_suggestion` function
3. AI calls function when conversation warrants goal creation

**Function Definition (Backend):**
```json
{
  "name": "create_goal_suggestion",
  "description": "Generate a goal suggestion based on conversation",
  "parameters": {
    "type": "object",
    "properties": {
      "title": {"type": "string"},
      "description": {"type": "string"},
      "goal_type": {"type": "string", "enum": ["activity", "nutrition", "weight", "wellness", "custom"]},
      "target_value": {"type": "number"},
      "target_unit": {"type": "string"},
      "estimated_duration": {"type": "integer"}
    }
  }
}
```

**WebSocket Message Format:**
```json
{
  "type": "function_call",
  "function_name": "create_goal_suggestion",
  "function_args": {
    "title": "Walk 10,000 steps daily",
    "description": "Based on our conversation...",
    "goal_type": "activity",
    "target_value": 10000,
    "target_unit": "steps",
    "estimated_duration": 30
  },
  "consultation_id": "uuid"
}
```

**iOS Handling:**

```swift
// In ConsultationWebSocketManager
private func processMessage(_ message: IncomingConsultationMessage) async {
    switch message.type {
    case "function_call":
        if message.function_name == "create_goal_suggestion" {
            // Parse goal suggestion from function args
            if let argsData = message.function_args?.data(using: .utf8),
               let suggestion = try? JSONDecoder().decode(GoalSuggestion.self, from: argsData) {
                
                // Show goal creation prompt to user
                showGoalSuggestionPrompt(suggestion)
            }
        }
    // ... other cases
    }
}
```

#### Option 3: Quick Action for Goal Generation

**Already Partially Implemented:**

The consultation system supports `quick_action` parameter. We can add a goal-focused quick action.

**Add Quick Action:**
```json
{
  "id": "create-wellness-goal",
  "title": "Create a Wellness Goal",
  "prompt": "I'd like to create a new wellness goal. Can you help me identify what would be most beneficial for me right now?",
  "icon": "target",
  "context_type": "general",
  "persona": "general_wellness"
}
```

**Usage:**
```swift
// User taps "Create Goal" from quick actions
let consultation = try await createConsultationUseCase.execute(
    persona: .generalWellness,
    quickAction: "create-wellness-goal"
)

// AI conversation guides user through goal creation
// At end, triggers goal suggestion API
```

### Comparison of Options

| Option | Complexity | User Control | AI Intelligence | Backend Changes |
|--------|------------|--------------|-----------------|-----------------|
| Button in Chat | Low | High | Medium | None |
| AI-Initiated | High | Medium | High | Significant |
| Quick Action | Low | Medium | Medium | Minor (add action) |

### Recommended Approach

**Phase 1: Quick Win (1-2 days)**
- Add "Generate Goal from Chat" button in chat toolbar
- Use existing goal suggestion API
- Context = recent conversation + user data
- Show `GoalSuggestionsView` with generated suggestions

**Phase 2: Enhanced UX (1 week)**
- Add quick action "Let's create a goal together"
- AI guides user through goal definition
- Triggers goal suggestion at appropriate time
- User approves and creates goal

**Phase 3: Full AI Integration (2-3 weeks)**
- Backend adds function calling for goal creation
- AI detects goal-worthy conversations automatically
- Seamless goal creation within chat flow
- User just approves AI-generated goals

### Implementation Checklist

**Phase 1 (Immediate):**
- [ ] Add toolbar button to ChatView
- [ ] Implement `generateGoalFromConversation()` in ChatViewModel
- [ ] Parse conversation messages for context
- [ ] Call existing goal suggestion API
- [ ] Navigate to GoalSuggestionsView
- [ ] Test goal creation flow

**Phase 2 (Short-term):**
- [ ] Add "Create Goal" quick action to backend
- [ ] Update quick actions list in app
- [ ] Test quick action flow
- [ ] Add analytics tracking

**Phase 3 (Long-term):**
- [ ] Backend: Implement function calling for consultations
- [ ] Backend: Add `create_goal_suggestion` function
- [ ] iOS: Handle `function_call` WebSocket messages
- [ ] iOS: Show goal approval UI in chat
- [ ] iOS: Create goal from AI suggestion
- [ ] Test end-to-end flow

---

## Related Files

**Markdown Rendering:**
- `lume/Presentation/Features/Chat/ChatView.swift`
- Package: `swift-markdown-ui`

**Goal Generation:**
- `lume/Domain/UseCases/Goals/GenerateGoalSuggestionsUseCase.swift`
- `lume/Domain/Entities/GoalSuggestion.swift`
- `lume/Services/GoalAIService.swift`
- `lume/Presentation/Features/Goals/GoalSuggestionsView.swift`
- `lume/Presentation/ViewModels/ChatViewModel.swift` (for integration)

**Backend APIs:**
- `POST /api/v1/goals/suggestions` - Generate goal suggestions
- `POST /api/v1/consultations` - Create consultation with context
- `GET /api/v1/consultations/quick-actions` - Get quick actions

---

## Testing Checklist

**Markdown Rendering:**
- [ ] Bold text renders correctly
- [ ] Italic text renders correctly
- [ ] Code blocks have background
- [ ] Lists display with bullets
- [ ] Links are clickable
- [ ] User messages remain plain text

**Goal Generation (Phase 1):**
- [ ] Button appears in chat toolbar
- [ ] Button disabled with < 3 messages
- [ ] Tapping button triggers goal suggestions
- [ ] Goal suggestions based on conversation
- [ ] User can create goal from suggestion
- [ ] Created goal appears in goals list

---

## Future Enhancements

1. **Contextual Goal Types:**
   - Nutrition goals from nutritionist persona
   - Fitness goals from fitness coach persona
   - Wellness goals from wellness specialist

2. **Goal Progress Tracking in Chat:**
   - AI references user's active goals
   - Provides progress updates
   - Suggests adjustments based on chat

3. **Multi-Goal Conversations:**
   - Create multiple related goals from one chat
   - AI suggests goal hierarchy (parent/sub-goals)

4. **Goal Refinement:**
   - User discusses goal with AI
   - AI refines suggestion based on feedback
   - Iterative goal creation process

---

## Conclusion

**Markdown Rendering:** ✅ Implemented
- AI messages now render markdown properly
- User messages remain plain text
- Clean, readable chat experience

**Goal Generation:** 🔄 Feasible with Existing Infrastructure
- Current: Goal suggestions exist but not integrated with chat
- Recommended: Add button to generate goals from conversation
- Future: Full AI-driven goal creation within chat flow

The app has all the building blocks needed for chat-based goal generation. Integration is straightforward and can be implemented incrementally.