# Swipe Actions & AI Chat - Quick Reference

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Purpose:** Quick reference for new gesture-based and AI chat features

---

## 🎯 Overview

Two major UX improvements have been added to Goals:

1. **Swipe Actions** - Quick access to goal management without opening detail view
2. **AI Chat** - Personalized conversations about specific goals

---

## 👆 Swipe Actions

### How to Use

**Swipe Right (Leading Edge)** → Positive actions
- ✅ Complete goal
- ▶️ Resume paused goal

**Swipe Left (Trailing Edge)** → Management actions
- ⏸️ Pause goal
- 📦 Archive goal
- 🗑️ Delete goal

### Status-Specific Actions

#### Active Goals
- **Swipe Right**: Complete (green checkmark)
- **Swipe Left**: Pause (purple), Archive (gray), Delete (red)

#### Paused Goals
- **Swipe Right**: Resume (green play button)
- **Swipe Left**: Archive (gray), Delete (red)

#### Completed Goals
- **Swipe Left**: Delete (red) only

#### Archived Goals
- **Swipe Left**: Delete (red) only

### Design Details

**Colors:**
- Complete/Resume: `#B8E8D4` (mint green)
- Pause: `#D8C8EA` (soft purple)
- Archive: `#6E625A` (gray)
- Delete: Red (destructive)

**Behavior:**
- No confirmation for Complete, Pause, Resume, Archive
- Confirmation dialog for Delete
- Actions auto-dismiss after execution
- Offline support via Outbox pattern

---

## 💬 AI Chat Consultation

### How to Access

1. Tap any goal to open detail view
2. Tap **"Chat About Goal"** button (below "Get AI Tips")
3. AI creates a goal-specific conversation
4. Start chatting immediately

### What It Does

**Automatic Context:**
- Goal title passed to AI
- Goal ID linked to conversation
- Motivational persona selected
- Conversation saved for future reference

**AI Capabilities:**
- Personalized encouragement
- Strategy suggestions
- Obstacle problem-solving
- Progress celebration
- Adjustment recommendations

### Implementation Notes

**Backend:**
- Uses existing chat/consultation infrastructure
- Creates conversation with `goal` context type
- Links conversation to specific goal ID

**Code:**
```swift
// Automatically called when "Chat About Goal" is tapped
let conversation = try await useCase.createForGoal(
    goalId: goal.id,
    goalTitle: goal.title,
    persona: .motivational
)
```

**UI Flow:**
1. User taps "Chat About Goal"
2. Loading state: "Starting conversation..."
3. Chat view opens with empty conversation
4. User sends first message
5. AI responds with goal-aware context
6. Conversation continues naturally

---

## 🔄 Migration from Old UI

### Before (ScrollView + Cards)

```swift
ScrollView {
    LazyVStack {
        ForEach(goals) { goal in
            GoalCard(goal: goal) {
                selectedGoal = goal
            }
        }
    }
}
```

### After (List + Swipe Actions)

```swift
List {
    ForEach(goals) { goal in
        GoalRowView(goal: goal)
            .onTapGesture { selectedGoal = goal }
            .swipeActions(edge: .trailing) {
                // Management actions
            }
            .swipeActions(edge: .leading) {
                // Positive actions
            }
    }
}
.listStyle(.plain)
```

### Benefits of List

✅ Native iOS swipe gesture support  
✅ Better performance with large datasets  
✅ Pull-to-refresh built-in  
✅ Keyboard avoidance automatic  
✅ Accessibility support included  
✅ Lazy loading by default  

---

## 🎨 Visual Design

### Goal Row Layout

```
┌─────────────────────────────────────────────────────┐
│  [Icon]  Goal Title                    [Status]     │
│          Category Name                               │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  75% Complete                       Jan 15, 2025    │
└─────────────────────────────────────────────────────┘
```

**Elements:**
- Category icon with colored background (48x48pt circle)
- Goal title (body semibold)
- Category name (caption secondary)
- Status badge (only for non-active goals)
- Progress bar (8pt height, category color)
- Percentage and target date (caption)

### Swipe Action Colors

| Action | Background | Icon | Text |
|--------|-----------|------|------|
| Complete | `#B8E8D4` | checkmark.circle.fill | White |
| Resume | `#B8E8D4` | play.circle | White |
| Pause | `#D8C8EA` | pause.circle | White |
| Archive | `#6E625A` | archivebox | White |
| Delete | Red | trash | White |

---

## 📱 User Experience Flow

### Quick Complete (Swipe Right)

```
1. User sees goal in list
2. Swipes right on active goal
3. Green "Complete" action appears
4. Taps Complete
5. Goal progress → 100%
6. Goal status → Completed
7. Goal moves to "Completed" tab
8. Confetti animation (future)
```

### Start Goal Chat

```
1. User taps goal in list
2. Detail view opens
3. User scrolls to "Chat About Goal" button
4. Taps button
5. Loading: "Starting conversation..."
6. Chat view opens
7. User types message
8. AI responds with goal context
9. Conversation continues
```

### Pause Goal (Swipe Left)

```
1. User swipes left on active goal
2. Actions appear: Pause, Archive, Delete
3. Taps Pause
4. Goal status → Paused
5. Goal moves to "Paused" tab
6. Progress preserved
```

---

## 🔧 Technical Details

### ViewModel Methods

```swift
// Progress tracking
func updateProgress(goalId: UUID, progress: Double) async

// Status changes
func completeGoal(_ goalId: UUID) async
func pauseGoal(_ goalId: UUID) async
func resumeGoal(_ goalId: UUID) async
func archiveGoal(_ goalId: UUID) async
func deleteGoal(_ goalId: UUID) async
```

### Swipe Action Implementation

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        Task { await viewModel.deleteGoal(goal.id) }
    } label: {
        Label("Delete", systemImage: "trash")
    }
    
    Button {
        Task { await viewModel.archiveGoal(goal.id) }
    } label: {
        Label("Archive", systemImage: "archivebox")
    }
    .tint(Color(hex: "#6E625A"))
}
```

### Chat Integration

```swift
struct GoalChatView: View {
    let goal: Goal
    @State private var chatViewModel: ChatViewModel?
    
    var body: some View {
        // Chat interface
    }
    
    func createConversation() async {
        let useCase = AppDependencies.shared.createConversationUseCase
        let conversation = try await useCase.createForGoal(
            goalId: goal.id,
            goalTitle: goal.title,
            persona: .motivational
        )
        // Set up chat view model
    }
}
```

---

## ✅ Testing Checklist

### Swipe Actions

- [ ] Swipe right on active goal shows Complete
- [ ] Swipe left on active goal shows Pause, Archive, Delete
- [ ] Swipe right on paused goal shows Resume
- [ ] Complete action sets progress to 100%
- [ ] Pause preserves current progress
- [ ] Archive moves to Archived tab
- [ ] Delete shows confirmation dialog
- [ ] Actions work offline
- [ ] Swipe gestures feel smooth
- [ ] Colors match design spec

### AI Chat

- [ ] Chat button visible in goal detail
- [ ] Loading state shown while creating conversation
- [ ] Chat view opens with goal context
- [ ] AI understands goal details
- [ ] Conversation stored for future access
- [ ] Error state shown if creation fails
- [ ] "Try Again" button works on error
- [ ] Can return to goal detail and resume chat
- [ ] Chat history persists
- [ ] Offline message queuing works

---

## 🐛 Common Issues

### Swipe Actions Not Appearing

**Problem:** Swipe gestures don't show actions  
**Solution:** Ensure using `List` not `ScrollView`, and swipeActions modifiers are applied to row view

### Chat Button Not Working

**Problem:** Chat view doesn't open  
**Solution:** Check AppDependencies.shared is properly initialized

### Actions Don't Sync

**Problem:** Swipe actions work but don't sync to backend  
**Solution:** Verify Outbox pattern is running and network is available

---

## 📊 Performance Considerations

### List vs ScrollView

- **List**: Lazy loading by default, better for 100+ goals
- **ScrollView**: All views rendered, better for <20 goals
- **Decision**: Use List for scalability

### Chat Creation

- **Async operation**: ~500ms typical
- **Loading state**: Required for good UX
- **Error handling**: Essential for poor network

### Swipe Action Responsiveness

- **Target**: <16ms per frame (60fps)
- **Optimization**: Avoid heavy work in swipe handlers
- **Result**: Immediate visual feedback

---

## 🎯 Next Steps

### For Users

1. **Try swipe actions** on your active goals
2. **Start a chat** about a challenging goal
3. **Provide feedback** on gesture feel
4. **Report bugs** if actions don't work offline

### For Developers

1. **Monitor Outbox** for sync failures
2. **Track chat usage** analytics
3. **Optimize list performance** with many goals
4. **Add haptic feedback** to swipe actions (future)

---

## 📚 Related Documentation

- [Goal Management Features](GOAL_MANAGEMENT_FEATURES.md) - Complete feature documentation
- [AI Consultation Guide](../goals-insights-consultations/ai-consultation/consultations-enhanced.md) - Chat backend integration
- [Cross-Feature Integration](../goals-insights-consultations/cross-feature-integration.md) - How features work together

---

## 💡 Pro Tips

**Swipe Efficiency:**
- Swipe right = "I'm making progress" (Complete/Resume)
- Swipe left = "I need to manage this" (Pause/Archive/Delete)

**Chat Effectiveness:**
- Be specific in your questions
- Share obstacles you're facing
- Ask for concrete strategies
- Update the AI on your progress

**Goal Organization:**
- Use Pause for temporary breaks
- Use Archive for reference/completed experiments
- Use Delete only for mistakes
- Use Chat for motivation and strategy

---

**Result:** Goals are now faster to manage with swipe gestures and more supportive with AI chat integration! 🎉