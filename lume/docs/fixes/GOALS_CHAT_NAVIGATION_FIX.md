# Goals-to-Chat Navigation Fix

**Date:** 2025-01-29  
**Issue:** Fatal error when navigating from Goal Detail to Chat  
**Status:** ✅ Resolved

---

## Problem

When attempting to navigate from a Goal Detail view to the Chat tab using the "Chat About Goal" button, the app crashed with:

```
SwiftUICore/EnvironmentObject.swift:93: Fatal error: No ObservableObject of type TabCoordinator found. 
A View.environmentObject(_:) for TabCoordinator may be missing as an ancestor of this view.
```

**Log Output:**
```
✅ [CreateConversationUseCase] Created conversation: BF3183B2-DAA5-4B2D-BFF7-EC87FC2E48B4
✅ [GoalDetailView] Goal chat created: BF3183B2-DAA5-4B2D-BFF7-EC87FC2E48B4
🚀 [GoalDetailView] Navigating to chat tab with conversation
[CRASH] Fatal error: No ObservableObject of type TabCoordinator found
```

---

## Root Cause

The `TabCoordinator` environment object was not properly propagated through the navigation hierarchy:

1. `MainTabView` creates `@StateObject private var tabCoordinator`
2. `GoalsListView` within Goals tab NavigationStack did not receive the coordinator
3. `GoalDetailView` (presented as a sheet from `GoalsListView`) requires `@EnvironmentObject var tabCoordinator`
4. When `GoalDetailView` tried to call `tabCoordinator.switchToChat()`, the environment object was missing

---

## Solution

### 1. Added `TabCoordinator` to Goals Tab NavigationStack

**File:** `lume/lume/Presentation/MainTabView.swift`

```swift
NavigationStack {
    GoalsListView(
        viewModel: dependencies.makeGoalsViewModel(),
        goalToShow: $tabCoordinator.goalToShow,
        dependencies: dependencies
    )
    .toolbar(.visible, for: .tabBar)
    .toolbar {
        // ... toolbar items
    }
    .environmentObject(tabCoordinator)  // ✅ Added
}
.tabItem {
    Label("Goals", systemImage: "target")
}
.tag(3)
```

### 2. Captured `TabCoordinator` in `GoalsListView`

**File:** `lume/lume/Presentation/Features/Goals/GoalsListView.swift`

```swift
struct GoalsListView: View {
    @EnvironmentObject private var tabCoordinator: TabCoordinator  // ✅ Added
    @Bindable var viewModel: GoalsViewModel
    @Binding var goalToShow: Goal?
    let dependencies: AppDependencies
    
    // ... rest of properties
```

### 3. Passed `TabCoordinator` to Sheet-Presented `GoalDetailView`

**File:** `lume/lume/Presentation/Features/Goals/GoalsListView.swift`

```swift
.sheet(item: $selectedGoal) { goal in
    NavigationStack {
        GoalDetailView(goal: goal, viewModel: viewModel, dependencies: dependencies)
            .environmentObject(tabCoordinator)  // ✅ Added
    }
    .presentationBackground(LumeColors.appBackground)
}
```

---

## Environment Object Propagation Chain

The fix establishes the following environment object flow:

```
MainTabView
├─ @StateObject tabCoordinator
│
└─ Goals Tab NavigationStack
   ├─ .environmentObject(tabCoordinator)  ← Injected here
   │
   └─ GoalsListView
      ├─ @EnvironmentObject tabCoordinator  ← Captured here
      │
      └─ .sheet → NavigationStack
         ├─ .environmentObject(tabCoordinator)  ← Passed down
         │
         └─ GoalDetailView
            └─ @EnvironmentObject tabCoordinator  ← Used here
               └─ tabCoordinator.switchToChat()  ← Works! ✅
```

---

## Verification

After the fix:

1. ✅ User can tap "Chat About Goal" in Goal Detail
2. ✅ Conversation is created with goal context
3. ✅ App navigates to Chat tab
4. ✅ Chat opens with the new goal-linked conversation
5. ✅ No crash or missing environment object errors

---

## Related Files

- `lume/lume/Presentation/MainTabView.swift` - Main tab coordinator setup
- `lume/lume/Presentation/Features/Goals/GoalsListView.swift` - Goals list with navigation
- `lume/lume/Presentation/Features/Goals/GoalDetailView.swift` - Goal detail with chat creation

---

## Architecture Notes

### TabCoordinator Pattern

The `TabCoordinator` is an `ObservableObject` that enables cross-tab navigation:

```swift
@MainActor
class TabCoordinator: ObservableObject {
    @Published var selectedTab = 0
    @Published var goalToShow: Goal?
    @Published var conversationToShow: ChatConversation?
    
    func switchToGoals(showingGoal goal: Goal? = nil)
    func switchToChat(showingConversation conversation: ChatConversation? = nil)
}
```

**Usage Pattern:**
- Created as `@StateObject` in `MainTabView`
- Injected via `.environmentObject()` to each tab's root NavigationStack
- Captured via `@EnvironmentObject` in views that need cross-tab navigation
- Must be explicitly passed through sheet and navigation presentations

**Best Practice:**
Always inject `TabCoordinator` at the NavigationStack level for each tab that needs cross-tab navigation capabilities.

---

## Lessons Learned

1. **Environment Objects Don't Auto-Propagate Through Sheets**  
   When presenting a sheet, environment objects from the presenting view are not automatically available unless explicitly passed with `.environmentObject()`.

2. **NavigationStack is the Injection Point**  
   For tab-based navigation, inject shared coordinators at the NavigationStack level inside each tab, not just at the TabView level.

3. **Chain of Custody**  
   Each view in the hierarchy that needs to pass the coordinator down must either:
   - Capture it with `@EnvironmentObject` and pass it explicitly to sheets/navigation destinations, OR
   - Inject it directly at the presentation point if it has access to the coordinator

---

## Testing Checklist

- [x] Create goal from Goals tab
- [x] Tap goal to open detail view
- [x] Tap "Chat About Goal" button
- [x] Verify conversation creation logs
- [x] Verify navigation to Chat tab
- [x] Verify chat opens with correct conversation
- [x] Verify goal context is linked in conversation
- [x] Test with goals created from chat suggestions
- [x] Test with existing goals
- [x] Verify no crashes or environment object errors

---

**Status:** Production ready ✅