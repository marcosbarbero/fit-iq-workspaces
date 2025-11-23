# Goals UI Fixes - January 28, 2025

## Summary

Fixed two UI issues with the Goals feature:
1. ✅ Compilation error in `GoalAIService.swift`
2. ✅ White background in Goal sheets (should be warm Lume background)

---

## Issue 1: Compilation Error - Missing `body` Parameter

### Problem
```
/Users/marcosbarbero/Develop/GitHub/marcosbarbero/ios/lume/lume/Services/Backend/GoalAIService.swift:35:27 
Missing argument for parameter 'body' in call
```

The `HTTPClient.post()` method required a `body` parameter, but the Goals AI suggestions endpoint doesn't accept a request body (per Swagger spec).

### Root Cause
The endpoint `POST /api/v1/goals/suggestions` generates suggestions based on the authenticated user's existing data (mood, journal, goals) on the backend. No client-side data needs to be sent.

### Solution
Added a new `post()` method overload to `HTTPClient.swift` that doesn't require a body parameter:

```swift
// lume/Core/Network/HTTPClient.swift
/// Perform a POST request without a request body
func post<R: Decodable>(
    path: String,
    headers: [String: String] = [:],
    accessToken: String? = nil
) async throws -> R {
    let url = baseURL.appendingPathComponent(path)
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)
    
    return try await performRequest(request)
}
```

### Files Changed
- `lume/Core/Network/HTTPClient.swift` - Added POST method without body parameter

### Result
✅ `GoalAIService.swift` now compiles without errors

---

## Issue 2: White Background in Goal Sheets

### Problem
When CreateGoalView, GoalSuggestionsView, or GoalDetailView were presented as sheets, they appeared with a white background instead of Lume's warm `#F8F4EC` app background.

Additionally, the TextEditor inside CreateGoalView had a pastel background (`LumeColors.surface` = `#E8DFD6`) instead of the lighter, more transparent look used in JournalEntryView.

### Root Cause
1. SwiftUI sheets use the system background color by default (white)
2. The CreateGoalView was using `LumeColors.surface` instead of `Color.white.opacity(0.5)` to match JournalEntryView

### Solution

#### Part 1: Fixed Sheet Backgrounds
Added `.presentationBackground()` modifiers to all three sheet presentations in `GoalsListView.swift`:

```swift
// Goals list sheet presentations
.sheet(isPresented: $showingCreateGoal) {
    NavigationStack {
        CreateGoalView(viewModel: viewModel)
    }
    .presentationBackground(LumeColors.appBackground) // Added
}

.sheet(isPresented: $showingSuggestions) {
    NavigationStack {
        GoalSuggestionsView(viewModel: viewModel)
    }
    .presentationBackground(LumeColors.appBackground) // Added
}

.sheet(item: $selectedGoal) { goal in
    NavigationStack {
        GoalDetailView(goal: goal, viewModel: viewModel)
    }
    .presentationBackground(LumeColors.appBackground) // Added
}
```

#### Part 2: Fixed TextEditor Background
Changed the background from `LumeColors.surface` to `Color.white.opacity(0.5)` to match JournalEntryView:

```swift
// CreateGoalView.swift - Goal input block
VStack(alignment: .leading, spacing: 0) {
    // Title field
    // ...
    
    // Description TextEditor
    // ...
}
.background(Color.white.opacity(0.5)) // Changed from LumeColors.surface
.cornerRadius(16)
```

Also applied to the date picker:

```swift
// Date picker block
VStack(spacing: 0) {
    DatePicker(...)
}
.background(Color.white.opacity(0.5)) // Changed from LumeColors.surface
.cornerRadius(16)
```

### Design Consistency
This matches the pattern used in `JournalEntryView.swift`:

```swift
// JournalEntryView.swift line 192
.background(Color.white.opacity(0.5))
.cornerRadius(12)
```

### Files Changed
- `lume/Presentation/Features/Goals/GoalsListView.swift` - Added presentation backgrounds
- `lume/Presentation/Features/Goals/CreateGoalView.swift` - Changed backgrounds to white opacity

### Result
✅ All Goal-related sheets now display with Lume's warm background color
✅ CreateGoalView text editor matches JournalEntryView's lighter appearance

---

## Related Issue: Backend 500 Error

While fixing the compilation error, we discovered the backend is returning a 500 error for the suggestions endpoint:

```
=== HTTP Request ===
URL: https://fit-iq-backend.fly.dev/api/v1/goals/suggestions
Method: POST
Status: 500
```

### Status
- ✅ iOS client implementation is correct (no request body, proper headers)
- ❌ Backend is experiencing an internal server error
- 📝 Created debugging guide: `docs/fixes/GOALS_AI_BACKEND_500_ERROR.md`

### Workaround
Use mock data temporarily by switching to `InMemoryGoalAIService` in `AppDependencies.swift`:

```swift
lazy var goalAIService: GoalAIServiceProtocol = {
    InMemoryGoalAIService() // Mock data
    // GoalAIService(httpClient: httpClient, tokenStorage: tokenStorage) // Real service
}()
```

---

## Testing Checklist

- [x] CreateGoalView displays with warm background
- [x] GoalSuggestionsView displays with warm background
- [x] GoalDetailView displays with warm background
- [x] Text editor background matches JournalEntryView
- [x] Date picker background is consistent
- [x] No compilation errors
- [ ] Backend suggestions endpoint returns 200 (pending backend fix)

---

## Design System Compliance

All changes adhere to Lume's design principles:

✅ **Warm & Cozy:** App background (`#F8F4EC`) used consistently
✅ **Clean & Modern:** White transparency for input areas
✅ **Consistent:** Matches JournalEntryView patterns exactly
✅ **Professional:** Proper visual hierarchy maintained

---

## References

- Swagger spec: `docs/swagger-goals-ai.yaml`
- Backend debugging guide: `docs/fixes/GOALS_AI_BACKEND_500_ERROR.md`
- Architecture rules: `.github/copilot-instructions.md`
- Related thread: Zed conversation "Lume iOS AI Features Debugging"