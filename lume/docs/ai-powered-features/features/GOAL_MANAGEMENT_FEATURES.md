# Goal Management Features

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Purpose:** Documentation for goal management, tracking, and lifecycle features

---

## Overview

The Lume app now includes comprehensive goal management features that allow users to:

- Track progress on their goals with an interactive slider
- Mark goals as complete
- Pause and resume goals
- Archive goals for reference
- Delete goals permanently
- Quick actions via swipe gestures
- Start AI chat consultations about specific goals

These features maintain the app's warm, calm, and supportive atmosphere while giving users full control over their wellness journey.

---

## Features

### 1. Progress Tracking

**Location:** Goal Detail View

**Description:** Users can track their progress toward completing a goal using an interactive slider.

**Key Elements:**
- Visual progress bar showing current completion percentage
- Interactive slider (0-100%) to update progress
- Real-time updates with backend sync via Outbox pattern
- Only shown for active goals

**Implementation:**
- `GoalsViewModel.updateProgress(goalId:progress:)` - Updates goal progress
- Slider bound to local state with onChange handler
- Automatically syncs to backend and refreshes UI

**User Experience:**
- Drag the slider to update progress
- Visual feedback shows current percentage
- Progress bar fills with goal category color
- Helper text: "Drag to update progress"

**Quick Access:**
- Also available via detail view
- Swipe actions provide alternative access to all goal actions

---

### 2. Complete Goal

**Location:** Goal Detail View

**Description:** Users can mark a goal as complete, automatically setting progress to 100% and status to `.completed`.

**Key Elements:**
- Green "Mark as Complete" button with checkmark icon
- Only shown for active goals with progress < 100%
- Instant visual feedback

**Implementation:**
- `GoalsViewModel.completeGoal(goalId:)` - Marks goal as complete
- Sets progress to 1.0 and status to `.completed`
- Creates outbox event for backend sync
- Dismisses detail view after completion

**User Experience:**
- Clear call-to-action button
- Immediate navigation back to list
- Goal appears in "Completed" tab
- Celebratory green accent color

---

### 3. Pause/Resume Goal

**Location:** Goal Detail View

**Description:** Users can pause goals they're not actively working on and resume them later.

**Key Elements:**
- "Pause Goal" button shown for active goals
- "Resume Goal" button shown for paused goals
- Maintains progress when paused
- Status changes between `.active` and `.paused`

**Implementation:**
- `GoalsViewModel.pauseGoal(goalId:)` - Pauses an active goal
- `GoalsViewModel.resumeGoal(goalId:)` - Resumes a paused goal
- Updates status without affecting progress
- Syncs to backend via Outbox pattern

**User Experience:**
- Pause button: gray with pause icon
- Resume button: green with play icon
- Paused goals visible in "Paused" tab
- No loss of progress data

---

### 4. Archive Goal

**Location:** Goal Detail View

**Description:** Users can archive goals to remove them from active view while keeping them for reference.

**Key Elements:**
- "Archive Goal" button with archivebox icon
- Confirmation dialog before archiving
- Archived goals moved to "Archived" tab
- Can be viewed but not actively worked on

**Implementation:**
- `GoalsViewModel.archiveGoal(goalId:)` - Archives a goal
- Confirmation dialog prevents accidental archives
- Sets status to `.archived`
- Preserves all goal data and progress

**User Experience:**
- Confirmation: "Archived goals can be viewed in the Archived tab"
- Cancel or confirm options
- Goal remains accessible in Archived tab
- Soft gray styling for archive button

---

### 5. Delete Goal

**Location:** Goal Detail View

**Description:** Users can permanently delete goals they no longer want to keep.

**Key Elements:**
- "Delete Goal" button with trash icon (red/coral color)
- Destructive confirmation dialog
- Permanent action (cannot be undone)
- Currently implemented as archive (soft delete)

**Implementation:**
- `GoalsViewModel.deleteGoal(goalId:)` - Deletes a goal
- Destructive confirmation dialog
- Currently archives goal (soft delete pattern)
- Can be extended to hard delete in future

**User Experience:**
- Red/coral warning color
- Strong confirmation: "This action cannot be undone"
- Destructive button role in dialog
- Goal removed from all views

---

### 6. Swipe Actions (Quick Access)

**Location:** Goals List View

**Description:** Users can perform common actions directly from the list using swipe gestures.

**Key Elements:**
- Swipe right for positive actions (complete, resume)
- Swipe left for management actions (pause, archive, delete)
- Context-aware actions based on goal status
- Color-coded for instant recognition

**Implementation:**
- List-based UI with `.swipeActions()` modifier
- Separate action sets for leading/trailing edges
- Status-dependent action availability

**Available Swipe Actions by Status:**

| Status | Swipe Right (Leading) | Swipe Left (Trailing) |
|--------|----------------------|----------------------|
| **Active** | Complete (green) | Pause (purple), Archive (gray), Delete (red) |
| **Paused** | Resume (green) | Archive (gray), Delete (red) |
| **Completed** | - | Delete (red) |
| **Archived** | - | Delete (red) |

**User Experience:**
- Swipe gestures feel natural and intuitive
- No confirmation needed for non-destructive actions
- Confirmations still shown for delete
- Actions dismiss automatically after execution

---

### 7. AI Chat Consultation

**Location:** Goal Detail View

**Description:** Users can start an AI-powered chat conversation focused on a specific goal for personalized support and guidance.

**Key Elements:**
- "Chat About Goal" button with chat bubble icon
- Creates goal-specific conversation with motivational persona
- Full conversation context includes goal details
- Access to chat history and ongoing support

**Implementation:**
- `CreateConversationUseCase.createForGoal()` - Creates goal-linked chat
- Goal ID and title passed as context
- Motivational persona pre-selected
- Conversation stored for future reference

**User Experience:**
- Prominent button below "Get AI Tips"
- Loading state while creating conversation
- Seamless transition to chat interface
- Goal context automatically provided to AI
- Can return to goal detail and resume chat later

**AI Capabilities:**
- Personalized encouragement and motivation
- Strategy suggestions for achieving the goal
- Obstacle identification and problem-solving
- Progress celebration and recognition
- Adjustment recommendations if needed

---

## Goal Status Lifecycle

```
┌─────────┐
│  Active │ ◄──────────┐
└────┬────┘            │
     │                 │
     ├──► Complete     │
     │                 │
     ├──► Pause ───────┘
     │       │
     │       └──► Resume
     │
     ├──► Archive
     │
     └──► Delete (Archive)
```

### Status Definitions

| Status | Description | User Actions Available |
|--------|-------------|------------------------|
| **Active** | Currently working on goal | Update progress, Complete, Pause, Archive, Delete |
| **Completed** | Goal achieved | Archive, Delete |
| **Paused** | Temporarily not working on goal | Resume, Archive, Delete |
| **Archived** | Stored for reference | Delete |

---

## UI Organization

### Tab Structure

The Goals List View includes four tabs:

1. **Active** - Goals currently being worked on
2. **Completed** - Successfully achieved goals
3. **Paused** - Goals on hold
4. **Archived** - Goals stored for reference

Each tab shows a count badge (e.g., "Active (3)") and displays appropriate empty states when no goals exist.

### List-Based UI

Goals are displayed in a `List` view for optimal performance and native iOS features:
- Smooth scrolling with lazy loading
- Native swipe gesture support
- Pull-to-refresh capability
- Proper keyboard avoidance
- Accessibility support built-in

### Goal Cards

Each goal card displays:
- Category icon with colored background
- Goal title and category name
- Progress bar with percentage
- Target date (if set)
- Status badge (for non-active goals)
- Overdue indicator (red date for past targets)

---

## Architecture

### Domain Layer

**Entities:**
- `Goal` - Core goal entity with status, progress, category
- `GoalStatus` - Enum: active, completed, paused, archived
- `GoalCategory` - Enum: general, physical, mental, emotional, social, spiritual, professional

**Use Cases:**
- `CreateGoalUseCase` - Creates new goals
- `UpdateGoalUseCase` - Updates existing goals
- `FetchGoalsUseCase` - Retrieves goals with filtering

### Presentation Layer

**ViewModel:**
- `GoalsViewModel` - Manages all goal operations
  - `updateProgress(goalId:progress:)` - Updates progress
  - `completeGoal(goalId:)` - Marks complete
  - `pauseGoal(goalId:)` - Pauses goal
  - `resumeGoal(goalId:)` - Resumes goal
  - `archiveGoal(goalId:)` - Archives goal
  - `deleteGoal(goalId:)` - Deletes goal
  - Computed properties: `activeGoals`, `completedGoals`, `pausedGoals`, `archivedGoals`

**Views:**
- `GoalsListView` - Main list with tabs and swipe actions
- `GoalDetailView` - Detail view with actions and chat integration
- `GoalRowView` - Individual goal row component for List
- `GoalChatView` - AI chat interface for goal-specific conversations
- `FloatingActionButton` - Create new goal button

### Data Layer

**Repository:**
- `GoalRepository` implements `GoalRepositoryProtocol`
- Methods: `updateProgress()`, `updateStatus()`, `archive()`, `complete()`, `delete()`
- Uses Outbox pattern for backend sync
- SwiftData for local persistence

---

## Backend Integration

All goal actions create outbox events for backend synchronization:

**Event Types:**
- `goal.progress.update` - Progress changed
- `goal.status.update` - Status changed (complete, pause, resume, archive)
- `goal.update` - Other goal properties changed

**Outbox Pattern:**
1. User action triggers ViewModel method
2. Repository updates local SwiftData
3. Outbox event created with payload
4. `OutboxProcessorService` syncs to backend
5. Event marked as completed or failed

**Offline Support:**
- All actions work offline
- Changes queued in outbox
- Automatic sync when online
- No data loss on failures

---

## Design Principles

### Visual Design

**Colors:**
- Complete button: `#B8E8D4` (Hopeful mint green)
- Pause button: `#D8C8EA` (Soft purple)
- Resume button: `#B8E8D4` (Hopeful mint green)
- Archive button: `#6E625A` (Secondary text gray)
- Delete button: `#F0B8A4` (Soft coral - warning)
- Chat button: `#F2C9A7` (Primary accent)
- Floating action button: `#F2C9A7` (Primary accent)

**Typography:**
- Button labels: Body weight semibold
- Helper text: Caption weight regular
- Percentages: Body weight semibold

**Spacing:**
- Button height: 14pt vertical padding
- Section spacing: 12pt between elements
- Action buttons: 12pt spacing between buttons

### User Experience

**Calm and Supportive:**
- Gentle confirmation dialogs
- No aggressive prompts
- Clear but soft color coding
- Helpful helper text

**Safety:**
- Confirmations for destructive actions
- Clear explanation of consequences
- Cancel always available
- Soft delete (archive) for safety

**Progress:**
- Visual progress bar always visible
- Interactive slider for quick updates
- Real-time percentage display
- Smooth animations

---

## Future Enhancements

### Planned Features

1. **Enhanced Chat Integration**
   - Quick chat access from goal card
   - Chat history visible in goal detail
   - AI proactive check-ins at milestones

2. **Hard Delete Option**
   - Add true permanent delete
   - Keep archive as default
   - Add "Delete Permanently" in archived view

3. **Bulk Actions**
   - Multi-select goals
   - Batch archive/delete
   - Bulk status changes

4. **Progress History**
   - Track progress changes over time
   - Show progress graph
   - Milestone celebrations

5. **Goal Templates**
   - Quick start from templates
   - Pre-filled common goals
   - Category-specific templates

6. **Sharing**
   - Share completed goals
   - Export goal data
   - Social accountability features

7. **Smart Notifications**
   - Progress reminders
   - Milestone celebrations
   - Encouragement when stalled

---

## Testing Checklist

### Functional Tests

- [ ] Progress slider updates local state immediately
- [ ] Progress syncs to backend via outbox
- [ ] Complete button sets progress to 100% and status to completed
- [ ] Pause button changes status and moves to Paused tab
- [ ] Resume button restores to Active tab
- [ ] Archive button shows confirmation and moves to Archived tab
- [ ] Delete button shows confirmation and removes goal
- [ ] All actions work offline and sync later
- [ ] Tab counts update correctly
- [ ] Empty states show for tabs with no goals
- [ ] Swipe right shows complete/resume actions
- [ ] Swipe left shows pause/archive/delete actions
- [ ] Swipe actions are context-aware by status
- [ ] Chat button creates goal-specific conversation
- [ ] Chat loads with goal context

### UI/UX Tests

- [ ] Progress bar fills smoothly
- [ ] Slider is easy to drag and precise
- [ ] Buttons have appropriate colors
- [ ] Confirmation dialogs are clear
- [ ] Actions provide immediate feedback
- [ ] Transitions are smooth and calm
- [ ] Colors match brand palette
- [ ] Text is readable and helpful
- [ ] Swipe gestures feel natural
- [ ] List scrolling is smooth
- [ ] Pull-to-refresh works correctly
- [ ] Chat interface integrates seamlessly

### Edge Cases

- [ ] Progress slider handles 0% and 100%
- [ ] Completing goal at 50% jumps to 100%
- [ ] Pausing/resuming maintains progress
- [ ] Archiving from any status works
- [ ] Deleting shows correct confirmation
- [ ] Backend errors handled gracefully
- [ ] Offline actions queue correctly
- [ ] Multiple rapid actions don't break state

---

## Summary

The goal management features provide users with complete control over their wellness journey while maintaining Lume's warm, supportive atmosphere. Through progress tracking, status management, swipe actions, and AI chat integration, users can engage with their goals at their own pace without pressure or judgment.

**Key Principles:**
- User autonomy and control
- Safety through confirmations
- Offline-first with sync
- Calm, warm visual design
- Clear, helpful feedback
- Gesture-based efficiency
- AI-powered personalized support
- Seamless cross-feature integration

**Core Improvements:**
- **Swipe Actions**: Quick access to all goal management features directly from the list
- **AI Chat**: Personalized, goal-specific conversations for motivation and guidance
- **List-Based UI**: Native iOS patterns for better performance and accessibility
- **Status Lifecycle**: Complete goal management from creation to completion or archival