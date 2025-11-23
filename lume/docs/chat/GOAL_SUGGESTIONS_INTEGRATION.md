# Goal Suggestions Integration in Chat

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Status:** ✅ Integrated and Ready for Testing

---

## Overview

The Goal Suggestions feature allows users to generate personalized goal recommendations based on their AI chat conversations. This creates a seamless flow from discussion to actionable goal-setting, leveraging the contextual understanding built during consultation sessions.

---

## Architecture

### Components

```
ChatView (Presentation)
    ↓
ChatViewModel (Presentation)
    ↓
GoalAIService (Infrastructure)
    ↓
Backend API: /api/v1/consultations/{id}/suggest-goals
```

### Key Files

- **UI Components:**
  - `ChatView.swift` - Main chat interface with integrated prompt
  - `GoalSuggestionPromptCard.swift` - Inline card encouraging goal generation
  - `ConsultationGoalSuggestionsView.swift` - Bottom sheet displaying suggestions

- **ViewModels:**
  - `ChatViewModel.swift` - Enhanced with goal suggestion methods

- **Services:**
  - `GoalAIService.swift` - Backend integration for AI suggestions
  - `GoalAIServiceProtocol.swift` - Domain port definition

- **Use Cases:**
  - `CreateGoalUseCase.swift` - Creates goals from suggestions

---

## User Flow

### 1. Conversation Progress

User engages in meaningful conversation with AI wellness coach:
- Minimum 4 messages total (2 user + 2 assistant)
- Discussions about wellness goals, challenges, or aspirations

### 2. Prompt Display

Once conversation reaches sufficient depth:
- Inline prompt card appears after messages
- Warm, encouraging design matches Lume brand
- Gradient icon with sparkle effect for visual appeal
- Clear call-to-action: "Generate Goal Ideas"

### 3. Generation

When user taps prompt:
- Backend analyzes full conversation context
- AI generates 3 personalized goal suggestions
- Each suggestion includes:
  - Title and detailed description
  - Goal type and category
  - Rationale based on conversation
  - Estimated duration and difficulty level
  - Target values and units (if applicable)

### 4. Review & Selection

Bottom sheet presents suggestions:
- Expandable cards with full details
- Each card shows:
  - Goal title and description
  - Visual category badge with color coding
  - Difficulty indicator
  - Duration estimate
  - AI rationale explaining why this goal fits
- One-tap goal creation
- Smooth dismiss animation

### 5. Goal Creation

User selects a suggestion:
- Goal automatically created in Goals tab
- Pre-populated with all suggestion details
- User can edit immediately or later
- Success feedback and auto-dismiss

---

## Implementation Details

### ChatViewModel Enhancements

#### New Dependencies

```swift
private let goalAIService: GoalAIServiceProtocol
private let createGoalUseCase: CreateGoalUseCase
```

#### New State Properties

```swift
var isLoadingGoalSuggestions = false
var goalSuggestions: [GoalSuggestion] = []
var goalSuggestionsError: String?
```

#### Key Methods

**Check Readiness:**
```swift
var isReadyForGoalSuggestions: Bool {
    let userMessages = messages.filter { $0.isUserMessage }.count
    let assistantMessages = messages.filter { $0.isAssistantMessage }.count
    return userMessages >= 2 && assistantMessages >= 2
}
```

**Generate Suggestions:**
```swift
func generateGoalSuggestions() async {
    guard let conversation = currentConversation,
          let consultationId = conversation.backendId
    else { return }
    
    isLoadingGoalSuggestions = true
    
    do {
        let suggestions = try await goalAIService.generateConsultationGoalSuggestions(
            consultationId: consultationId,
            maxSuggestions: 3
        )
        goalSuggestions = suggestions
    } catch {
        goalSuggestionsError = "Failed to generate goal suggestions: \(error.localizedDescription)"
    }
    
    isLoadingGoalSuggestions = false
}
```

**Create from Suggestion:**
```swift
func createGoal(from suggestion: GoalSuggestion) async throws {
    _ = try await createGoalUseCase.createFromSuggestion(suggestion)
}
```

### ChatView Integration

#### Prompt Card Placement

```swift
// In LazyVStack after messages
if viewModel.isReadyForGoalSuggestions && !viewModel.isSendingMessage {
    GoalSuggestionPromptCard {
        Task {
            await viewModel.generateGoalSuggestions()
            showGoalSuggestions = true
        }
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
}
```

#### Bottom Sheet

```swift
.sheet(isPresented: $showGoalSuggestions) {
    viewModel.clearGoalSuggestions()
} content: {
    if let conversationId = conversation.backendId {
        ConsultationGoalSuggestionsView(
            consultationId: conversationId,
            persona: conversation.persona,
            suggestions: viewModel.goalSuggestions,
            onCreateGoal: { suggestion in
                Task {
                    do {
                        try await viewModel.createGoal(from: suggestion)
                        showGoalSuggestions = false
                    } catch {
                        viewModel.errorMessage = "Failed to create goal: \(error.localizedDescription)"
                        viewModel.showError = true
                    }
                }
            }
        )
    }
}
```

---

## Backend Integration

### Endpoint

```
POST /api/v1/consultations/{consultationID}/suggest-goals
```

### Request

```json
{
    "max_suggestions": 3
}
```

### Response

```json
{
    "success": true,
    "data": {
        "suggestions": [
            {
                "title": "Improve Sleep Quality",
                "description": "Establish a consistent sleep routine...",
                "goal_type": "wellness",
                "target_value": 8.0,
                "target_unit": "hours",
                "rationale": "Based on your discussion about sleep challenges...",
                "estimated_duration": 30,
                "difficulty": 2
            }
        ],
        "count": 3
    }
}
```

### Error Handling

Standard error responses:
- `401` - Authentication required (token expired/invalid)
- `404` - Consultation not found
- `400` - Invalid request (max_suggestions out of range)
- `500` - Server error generating suggestions

---

## UX Design Principles

### Timing

- **Not Too Early:** Prompt only appears after meaningful conversation depth
- **Not Intrusive:** Inline placement doesn't interrupt message flow
- **Optional:** Users can ignore and continue conversation

### Visual Design

**Prompt Card:**
- Soft gradient background (primary accent colors)
- Sparkle icon suggesting AI magic
- Warm, encouraging copy
- Subtle shadow for elevation
- Rounded corners (16pt radius)

**Suggestion Cards:**
- Category-based color coding
- Clear visual hierarchy
- Expandable for full details
- Easy-to-scan layout
- One-tap action buttons

### Messaging

**Prompt Card:**
> "Ready to turn your insights into action?"
> "Generate Goal Ideas"

**Empty State (if no suggestions):**
> "Continue your conversation to get personalized goal suggestions"

**Loading State:**
> "Analyzing your conversation..."

**Error State:**
> "Unable to generate suggestions right now. Please try again."

---

## Testing Checklist

### Functional Tests

- [ ] Prompt appears after 4+ messages (2 user + 2 assistant)
- [ ] Prompt does NOT appear during typing indicator
- [ ] Tapping prompt triggers generation
- [ ] Loading state displays during generation
- [ ] Suggestions appear in bottom sheet
- [ ] All suggestion details render correctly
- [ ] Tapping suggestion creates goal
- [ ] Goal appears in Goals tab
- [ ] Error handling works for network failures
- [ ] Error handling works for auth failures
- [ ] Sheet dismissal clears state

### UX Tests

- [ ] Prompt card matches brand colors
- [ ] Smooth animations on sheet present/dismiss
- [ ] No UI jank during generation
- [ ] Keyboard dismisses when sheet appears
- [ ] Haptic feedback on goal creation (if implemented)
- [ ] Success message or visual confirmation
- [ ] Can dismiss sheet without creating goal

### Edge Cases

- [ ] Archived conversations (prompt should not show)
- [ ] Very short conversations (prompt hidden)
- [ ] Backend returns empty suggestions array
- [ ] Backend returns malformed data
- [ ] Network timeout during generation
- [ ] Multiple rapid taps on prompt button
- [ ] Conversation without backend ID (should not crash)

---

## Known Limitations

1. **Single Generation per Session:**
   - Users must dismiss and re-tap prompt for new suggestions
   - Consider adding "Generate More" button in future

2. **No Suggestion History:**
   - Previous suggestions not saved
   - Consider adding suggestion history feature

3. **Fixed Suggestion Count:**
   - Always requests 3 suggestions
   - Consider making this user-configurable

4. **No Feedback Loop:**
   - No way to rate or improve suggestions
   - Consider adding feedback mechanism

---

## Future Enhancements

### Short-term (Next Sprint)

1. **Add Suggestion Persistence:**
   - Save generated suggestions to local database
   - Show suggestion history in Goals tab

2. **Improve Loading UX:**
   - Add progress indicator with steps
   - Show estimated time remaining

3. **Enhanced Error Recovery:**
   - Retry mechanism for failed generations
   - Better error messages with actionable steps

### Long-term (Future Releases)

1. **Multi-Device Sync:**
   - Sync suggestions across devices
   - Backend storage for suggestion history

2. **Suggestion Refinement:**
   - Allow users to request different suggestions
   - "Not quite right" feedback button

3. **Goal Templates:**
   - Create reusable templates from popular suggestions
   - Community-shared goal templates

4. **Contextual Prompting:**
   - Analyze conversation topics to show prompt at optimal moment
   - Different prompts based on conversation type

---

## Dependencies

### Required Services

- `GoalAIService` - Backend integration
- `CreateGoalUseCase` - Goal creation logic
- `ChatViewModel` - State management

### Required Models

- `GoalSuggestion` - Suggestion data structure
- `ChatConversation` - Conversation context
- `Goal` - Created goal entity

### UI Components

- `GoalSuggestionPromptCard` - Inline prompt
- `ConsultationGoalSuggestionsView` - Bottom sheet
- `ChatView` - Host view

---

## Rollout Strategy

### Phase 1: Internal Testing ✅
- Feature complete and integrated
- Ready for internal QA

### Phase 2: Beta Testing (Pending)
- Deploy to TestFlight
- Gather user feedback
- Monitor analytics for usage patterns

### Phase 3: Production Release (Pending)
- Full rollout to App Store
- Monitor backend performance
- Track conversion rate (conversations → goals created)

---

## Analytics & Metrics

### Key Metrics to Track

1. **Engagement:**
   - % of conversations reaching prompt threshold
   - % of prompts tapped
   - Average suggestions generated per user

2. **Conversion:**
   - % of suggestions converted to goals
   - Most popular suggestion categories
   - Time from suggestion to goal creation

3. **Quality:**
   - Goal completion rate for suggestion-based goals
   - User retention after creating suggested goal
   - Comparison: suggested goals vs. manual goals

---

## Summary

The Goal Suggestions integration creates a natural bridge between AI consultations and actionable goal-setting. By leveraging conversation context, we provide personalized, relevant suggestions at the right moment in the user journey.

**Key Benefits:**
- ✅ Reduces friction in goal creation process
- ✅ Leverages AI for personalized recommendations
- ✅ Maintains warm, encouraging UX throughout
- ✅ Follows hexagonal architecture principles
- ✅ Fully integrated with existing goal management

**Status:** Ready for testing and feedback!