# Goal Chat Title Fix

**Date:** 2025-01-15  
**Issue:** Goal chat messages were showing "Chat with Wellness Coach" instead of the actual goal title  
**Status:** ✅ Fixed

---

## Problem Description

When users opened a chat for a specific goal, the AI's welcome message would reference "Chat with Wellness Coach" instead of the actual goal title. For example:

> "I'm your AI wellness coach. Let's create a plan, tackle challenges, and make real progress on **'Chat with Wellness Coach'**."

This should have shown the actual goal title like:

> "I'm your AI wellness coach. Let's create a plan, tackle challenges, and make real progress on **'Lose 10 pounds'**."

---

## Root Cause Analysis

The issue occurred because:

1. **Backend doesn't store conversation titles**: The backend API doesn't accept or store custom titles when creating consultations. It generates its own default title based on the persona.

2. **Title reconstruction logic**: When conversations were fetched from the backend, the `ConversationDTO.toDomain()` method would generate a title. For goal-based chats, it would set a placeholder: `"💪 Goal Chat"` with a comment saying "will be updated by UI layer" - but this update never happened.

3. **UI used conversation title**: The `ChatView.goalTitle` computed property was using `conversation.title` and trying to strip emoji prefixes, but the conversation title was the generic "Chat with Wellness Coach" from the backend.

4. **Context didn't include goal title**: The `ConversationContext` struct stored `relatedGoalIds` and `backendGoalId`, but not the actual goal title string, so there was no way to retrieve it without additional database queries.

5. **Existing conversations**: The backend returns existing conversations for a goal (HTTP 409 or reusing existing consultation), and these older conversations were created before `goalTitle` was added to the context.

6. **Context lost during backend round-trip**: When creating a conversation, the `goalTitle` was set in the context locally, but when the backend returned the conversation, the `toDomain()` method would reconstruct a new context without the `goalTitle`.

---

## Solution

Store the goal title in the `ConversationContext` when creating goal-based conversations, preserve it during backend round-trips, and update existing conversations that don't have it yet.

### Changes Made

#### 1. Updated `ConversationContext` Entity

**File:** `lume/Domain/Entities/ChatMessage.swift`

Added `goalTitle` field to store the actual goal title:

```swift
struct ConversationContext: Codable, Equatable, Hashable {
    let relatedGoalIds: [UUID]?
    let relatedInsightIds: [UUID]?
    let moodContext: MoodContextSummary?
    let quickAction: String?
    let backendGoalId: String?
    let goalTitle: String?  // ✅ NEW: Actual goal title for display
    
    init(
        relatedGoalIds: [UUID]? = nil,
        relatedInsightIds: [UUID]? = nil,
        moodContext: MoodContextSummary? = nil,
        quickAction: String? = nil,
        backendGoalId: String? = nil,
        goalTitle: String? = nil  // ✅ NEW
    ) {
        // ...
    }
}
```

#### 2. Updated `CreateConversationUseCase`

**File:** `lume/Domain/UseCases/Chat/CreateConversationUseCase.swift`

Modified `createForGoal` to store the goal title in the context:

```swift
func createForGoal(
    goalId: UUID,
    goalTitle: String,  // Already received as parameter
    backendGoalId: String?,
    persona: ChatPersona = .generalWellness
) async throws -> ChatConversation {
    let context = ConversationContext(
        relatedGoalIds: [goalId],
        relatedInsightIds: nil,
        moodContext: nil,
        quickAction: "goal_support",
        backendGoalId: contextGoalId,
        goalTitle: goalTitle  // ✅ Store the actual goal title
    )
    // ...
}
```

#### 3. Updated `ChatView` Goal Title Logic

**File:** `lume/Presentation/Features/Chat/ChatView.swift`

Modified the `goalTitle` computed property to use the context's goal title:

```swift
private var goalTitle: String {
    // ✅ Use goal title from context if available
    if let contextGoalTitle = conversation.context?.goalTitle, !contextGoalTitle.isEmpty {
        return contextGoalTitle
    }

    // Fallback: Remove emoji prefix from conversation title
    let title = conversation.title
    let cleanTitle = title.replacingOccurrences(of: "💪 ", with: "")
        .replacingOccurrences(of: "🎯 ", with: "")
        .replacingOccurrences(of: "✨ ", with: "")
    return cleanTitle.isEmpty ? "Your Goal" : cleanTitle
}
```

#### 4. Updated `ChatRepository` to Preserve Context

**File:** `lume/Data/Repositories/ChatRepository.swift`

Modified `createConversation` to merge the original context with the backend response:

```swift
func createConversation(
    title: String,
    persona: ChatPersona,
    context: ConversationContext?
) async throws -> ChatConversation {
    // ... create on backend ...
    
    // Merge the original context with backend response to preserve client-side data like goalTitle
    var finalConversation = backendConversation
    if let originalContext = context, let backendContext = backendConversation.context {
        // Preserve goalTitle from original context (backend doesn't store/return it)
        let mergedContext = ConversationContext(
            relatedGoalIds: backendContext.relatedGoalIds ?? originalContext.relatedGoalIds,
            relatedInsightIds: backendContext.relatedInsightIds ?? originalContext.relatedInsightIds,
            moodContext: backendContext.moodContext ?? originalContext.moodContext,
            quickAction: backendContext.quickAction ?? originalContext.quickAction,
            backendGoalId: backendContext.backendGoalId ?? originalContext.backendGoalId,
            goalTitle: originalContext.goalTitle  // Always use original goalTitle
        )
        finalConversation = ChatConversation(/* ... with mergedContext */)
    }
    
    return finalConversation
}
```

#### 5. Updated `GoalDetailView` to Handle Existing Conversations

**File:** `lume/Presentation/Features/Goals/GoalDetailView.swift`

Added logic to update existing conversations with the current goal title:

```swift
private func createConversation() async {
    var conversation = try await useCase.createForGoal(
        goalId: goal.id,
        goalTitle: goal.title,
        backendGoalId: goal.backendId,
        persona: ChatPersona.generalWellness
    )

    // Ensure context has the current goal title (handles existing conversations)
    if let existingContext = conversation.context {
        if existingContext.goalTitle != goal.title {
            // Update context with current goal title
            let updatedContext = ConversationContext(
                relatedGoalIds: existingContext.relatedGoalIds,
                relatedInsightIds: existingContext.relatedInsightIds,
                moodContext: existingContext.moodContext,
                quickAction: existingContext.quickAction,
                backendGoalId: existingContext.backendGoalId,
                goalTitle: goal.title  // ✅ Current goal title
            )
            
            conversation = ChatConversation(/* ... with updatedContext */)
            _ = try await dependencies.chatRepository.updateConversation(conversation)
        }
    }
}
```

---

## Architecture Benefits

This solution maintains clean architecture principles:

1. **Domain-centric**: The `ConversationContext` entity (in the domain layer) now contains all necessary display information.

2. **No presentation-layer database queries**: The `ChatView` doesn't need to query the goals database or inject a goal repository.

3. **Single source of truth**: The goal title is captured once when the conversation is created and stored in the context.

4. **Backward compatible**: The fallback logic ensures old conversations without `goalTitle` still display reasonably.

5. **Decoupled from backend**: The client doesn't depend on the backend storing or returning titles - it manages them locally.

6. **Handles existing data**: The solution updates older conversations that were created before this fix, ensuring all goal chats show the correct title.

7. **Context preservation**: The repository now preserves client-side context data during backend round-trips, preventing data loss.

---

## Testing Checklist

- [ ] Create a new goal
- [ ] Open chat for that goal (creates new conversation)
- [ ] Verify AI welcome message shows actual goal title
- [ ] Verify example prompts reference the goal correctly
- [ ] Close and reopen the goal chat (reuses existing conversation)
- [ ] Verify the goal title is still correct on reopen
- [ ] Test with goals containing emojis
- [ ] Test with long goal titles
- [ ] Test with old conversations created before this fix
- [ ] Update goal title and verify chat reflects the new title

---

## Related Files

- `lume/Domain/Entities/ChatMessage.swift` - Added `goalTitle` to `ConversationContext`
- `lume/Domain/UseCases/Chat/CreateConversationUseCase.swift` - Store goal title when creating goal chat
- `lume/Data/Repositories/ChatRepository.swift` - Preserve context during backend round-trip
- `lume/Presentation/Features/Chat/ChatView.swift` - Use goal title from context
- `lume/Presentation/Features/Goals/GoalDetailView.swift` - Update existing conversations with current goal title

---

## Future Improvements

1. **Backend enhancement**: Consider updating the backend API to accept and store custom conversation titles, which would eliminate the need for client-side title management.

2. **Context DTOs**: Add `goal_title` to the backend's consultation API response for better cross-device sync.

3. **Batch migration**: Create a one-time migration script to populate `goalTitle` for all existing goal conversations in the database.

4. **Goal title updates**: Consider adding a listener to update conversation contexts when a goal's title is changed.

---

**Status:** ✅ Complete  
**Impact:** High - Improves user experience by making goal-specific chats feel personalized and contextual