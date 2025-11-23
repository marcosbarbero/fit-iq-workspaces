# AI Features Debugging Guide

**Last Updated:** 2025-01-28  
**Purpose:** Help debug issues with AI Goal Suggestions and Tips

---

## Issue 1: Goal Suggestions Not Showing in UI

### Symptoms
- Backend returns suggestions successfully (verified in response)
- UI shows empty state or doesn't update
- No visible error messages

### Root Cause Analysis

The issue was that the backend returns `goal_type` values like:
- `"activity"` 
- `"nutrition"`
- `"custom"`

But the app's `mapCategory()` function wasn't handling these values, only looking for keywords like "physical", "fitness", etc.

### Fix Applied

Updated `lume/lume/Domain/Ports/GoalAIServiceProtocol.swift`:

```swift
private func mapCategory(from type: String) -> GoalCategory {
    let lowercased = type.lowercased()

    // Map backend goal_type values to app categories
    if lowercased == "activity" || lowercased.contains("physical")
        || lowercased.contains("fitness") || lowercased.contains("exercise")
    {
        return .physical
    } else if lowercased == "nutrition" || lowercased.contains("food")
        || lowercased.contains("diet") || lowercased.contains("eating")
    {
        return .physical  // Nutrition is part of physical health
    } else if lowercased.contains("mental") || lowercased.contains("mind") {
        return .mental
    } else if lowercased.contains("emotional") || lowercased.contains("mood") {
        return .emotional
    } else if lowercased.contains("social") || lowercased.contains("relationship") {
        return .social
    } else if lowercased.contains("spiritual") || lowercased.contains("meditation") {
        return .spiritual
    } else if lowercased.contains("professional") || lowercased.contains("career")
        || lowercased.contains("work")
    {
        return .professional
    }
    return .general
}
```

---

## Debugging Steps

### Step 1: Enable Debug Logging

The app now has extensive debug logging. When running in DEBUG mode, you'll see:

**In Console:**
```
=== HTTP Request ===
URL: https://fit-iq-backend.fly.dev/api/v1/goals/suggestions
Method: POST
Status: 200
Response: {"data":{"suggestions":[...]}}
===================

✅ [GoalAIService] Received response with 5 suggestions
📦 [GoalAIService] Success: true

🔍 [GoalSuggestionDTO] Converting to domain:
   - Title: Increase Daily Step Count
   - Goal Type: activity
   - Category: physical
   - Difficulty: 2 -> easy
   - Duration: 60 days

🎯 [GoalAIService] Converted to 5 domain suggestions
✅ [GoalsViewModel] Generated 5 suggestions
```

### Step 2: Check What You See

**Expected Flow:**
1. Open app → Goals tab
2. Tap sparkles icon (✨) in top-right
3. See "AI Goal Suggestions" screen with "Generate Suggestions" button
4. Tap button
5. See "Generating personalized suggestions..." loading state
6. See list of 5 suggestions with cards

**If you see empty state after loading:**
- Check console logs for errors
- Look for "❌" in logs indicating failures
- Check if suggestions array is populated but UI not updating

### Step 3: Verify Backend Response

The backend response format should be:
```json
{
  "data": {
    "suggestions": [
      {
        "title": "Increase Daily Step Count",
        "description": "Aim to increase your daily step count...",
        "goal_type": "activity",
        "target_value": 7000,
        "target_unit": "steps",
        "rationale": "Increasing your daily step count...",
        "estimated_duration": 60,
        "difficulty": 2
      }
    ],
    "count": 5
  }
}
```

### Step 4: Check ViewModel State

Add a breakpoint or print statement in `GoalsViewModel.generateSuggestions()`:

```swift
func generateSuggestions() async {
    isLoadingSuggestions = true
    errorMessage = nil
    defer { isLoadingSuggestions = false }
    
    do {
        suggestions = try await generateSuggestionsUseCase.execute()
        print("✅ [GoalsViewModel] Generated \(suggestions.count) suggestions")
        print("📋 [GoalsViewModel] Suggestions: \(suggestions.map { $0.title })")
    } catch {
        errorMessage = "Failed to generate suggestions: \(error.localizedDescription)"
        print("❌ [GoalsViewModel] Failed to generate suggestions: \(error)")
    }
}
```

### Step 5: Check UI Binding

Verify the view is properly observing the ViewModel:

```swift
struct GoalSuggestionsView: View {
    @Bindable var viewModel: GoalsViewModel  // ✅ Should use @Bindable
    
    var body: some View {
        ZStack {
            if viewModel.isLoadingSuggestions {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)  // ✅ Now shows errors
            } else if viewModel.suggestions.isEmpty {
                emptyOrGenerateView
            } else {
                suggestionsContent  // ✅ Should show suggestions
            }
        }
    }
}
```

---

## Common Issues & Solutions

### Issue: Decoding Error

**Symptom:**
```
❌ [GoalAIService] Failed to generate suggestions: keyNotFound(...)
```

**Cause:** Backend response doesn't match expected structure

**Solution:**
1. Check backend response format
2. Verify `CodingKeys` in `GoalSuggestionDTO`
3. Ensure all required fields are present

### Issue: Category Mapping Fails

**Symptom:**
```
🔍 [GoalSuggestionDTO] Converting to domain:
   - Category: general  (should be physical or other)
```

**Cause:** `goal_type` value not recognized by mapper

**Solution:**
Update `mapCategory()` to handle new goal_type values

### Issue: Empty Suggestions After Success

**Symptom:**
- Console shows "✅ Generated 5 suggestions"
- UI still shows empty state

**Possible Causes:**
1. UI not observing ViewModel changes
2. Suggestions filtered out by duplicate detection
3. UI refresh not triggered

**Solutions:**
1. Verify `@Bindable` is used
2. Check if suggestions are too similar to existing goals
3. Force UI refresh with state change

### Issue: Loading State Never Ends

**Symptom:**
- Loading spinner shows indefinitely
- No error message

**Cause:** Exception thrown before `defer` can set loading to false

**Solution:**
Already handled with `defer { isLoadingSuggestions = false }`

---

## Testing Checklist

### Backend Response Test
- [ ] Backend returns 200 status
- [ ] Response has `data.suggestions` array
- [ ] Each suggestion has required fields
- [ ] `goal_type` values are recognized
- [ ] `difficulty` is 1-5 integer

### Parsing Test
- [ ] No decoding errors in console
- [ ] All suggestions convert to domain objects
- [ ] Categories mapped correctly
- [ ] Difficulty levels parsed correctly

### ViewModel Test
- [ ] `suggestions` array populated
- [ ] `isLoadingSuggestions` transitions: false → true → false
- [ ] No `errorMessage` set on success
- [ ] Console shows "✅ Generated X suggestions"

### UI Test
- [ ] Loading state shows during fetch
- [ ] Suggestions list appears after loading
- [ ] Each card shows title, description, rationale
- [ ] Difficulty and duration displayed
- [ ] "Use This Goal" button works
- [ ] Categories have correct icons and colors

---

## Manual Test Procedure

### Test 1: Fresh Generation

1. Open app (ensure you're logged in)
2. Go to Goals tab
3. Tap ✨ sparkles icon
4. See "AI Goal Suggestions" screen
5. Tap "Generate Suggestions" button
6. **Expected:** Loading state appears
7. **Expected:** Within 2-3 seconds, 5 suggestions appear
8. **Verify:** Each card has title, description, rationale
9. **Verify:** Icons and colors match categories

### Test 2: Error Handling

1. Turn off WiFi/airplane mode ON
2. Go to Goals → ✨ Sparkles
3. Tap "Generate Suggestions"
4. **Expected:** Loading state appears
5. **Expected:** Error screen appears with "Try Again" button
6. Turn WiFi back on
7. Tap "Try Again"
8. **Expected:** Suggestions load successfully

### Test 3: Creating Goal from Suggestion

1. Generate suggestions (test 1)
2. Tap "Use This Goal" on any suggestion
3. **Expected:** Sheet dismisses
4. **Expected:** Goal appears in Goals list
5. **Verify:** Goal has correct title and description
6. **Verify:** Goal has target date based on duration

---

## Debug Configuration

### Xcode Console Filters

To see only AI-related logs:
```
GoalAIService
GoalSuggestionDTO
GoalsViewModel
```

To see HTTP requests:
```
HTTP Request
```

To see errors only:
```
❌
```

### Breakpoints

Set breakpoints at:
1. `GoalAIService.generateGoalSuggestions()` - Before network call
2. `GoalSuggestionDTO.toDomain()` - During parsing
3. `GoalsViewModel.generateSuggestions()` - After response
4. `GoalSuggestionsView.body` - UI update

---

## Known Issues

### Issue: Backend 500 Error

**Status:** Documented, backend team aware

**Symptom:**
```
❌ [HTTPClient] Server error 500 - Response body: Internal Server Error
```

**Workaround:** None - requires backend fix

**Timeline:** TBD by backend team

### Issue: Mock Mode Not Working

**Status:** By design

**Explanation:** Mock mode returns hardcoded suggestions for development

**Enable:** Set `AppMode.useMockData = true` in `AppDependencies`

---

## Performance Monitoring

### Expected Timings
- Network request: 1-2 seconds
- Parsing: < 100ms
- UI update: < 50ms
- **Total:** < 3 seconds

### If Slower
- Check network connectivity
- Check backend logs for slow AI generation
- Profile with Instruments

---

## Next Steps After Fix

1. **Test with real user data**
   - Ensure mood and journal history exists
   - Verify suggestions are personalized

2. **Test edge cases**
   - No mood history
   - No journal entries
   - No existing goals
   - All categories already have goals

3. **User acceptance testing**
   - Are suggestions relevant?
   - Are difficulty levels accurate?
   - Are durations reasonable?
   - Do rationales make sense?

---

## Contact & Resources

**Backend API Docs:** Check with backend team  
**Swagger UI:** `https://fit-iq-backend.fly.dev/swagger/index.html`  
**Code Location:** `lume/lume/Services/Backend/GoalAIService.swift`  
**Documentation:** `docs/ai-features/GOAL_TIPS_FEATURE.md`

---

**Last Updated:** 2025-01-28  
**Status:** Issues identified and fixed - ready for testing