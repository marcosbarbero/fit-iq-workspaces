# Goals and Chat Integration - QA Testing Guide

**Date:** 2025-01-30  
**Version:** 1.0.0  
**Feature:** Goals-Chat Integration  
**Status:** Ready for QA

---

## Overview

This guide provides comprehensive testing scenarios for the Goals and Chat integration feature in the Lume iOS app. This integration allows users to have AI-powered conversations about their wellness goals with full context and seamless navigation.

---

## Prerequisites

### Test Environment Setup

- [ ] iOS device or simulator (iOS 17.0+)
- [ ] Lume app installed (latest build)
- [ ] Valid test account credentials
- [ ] Stable internet connection
- [ ] Backend API accessible (fit-iq-backend.fly.dev)

### Test Data Requirements

- At least 3 existing goals in various states:
  - 1 goal in "Not Started" status
  - 1 goal in "In Progress" status
  - 1 goal in "Completed" status

### Before Each Test Session

1. Clear app data (or fresh install)
2. Log in with test account
3. Verify backend connectivity
4. Note the app version and build number

---

## Test Scenarios

## 1. Chat About Goal - From Goals Tab

### Test Case 1.1: Chat About Existing Goal (Success Path)

**Priority:** High  
**Preconditions:** User has at least one goal that has been synced to backend

**Steps:**
1. Open Lume app
2. Navigate to Goals tab
3. Find a goal with backend sync (should have swipe actions)
4. Swipe left on the goal
5. Tap "Chat" action (purple chat bubble icon)

**Expected Results:**
- ✅ Loading indicator appears briefly
- ✅ Navigation to chat screen occurs smoothly
- ✅ Chat header shows persona icon (sparkles)
- ✅ Goal context is visible (small goal card at top or in context)
- ✅ Empty chat shows welcoming message or goal context
- ✅ Keyboard appears for message input

**Validation Points:**
- No error messages displayed
- No flickering or UI jumps
- Persona icon is high contrast (dark color)
- Goal information is accurate

---

### Test Case 1.2: Chat About Goal (Needs Sync)

**Priority:** High  
**Preconditions:** Freshly created goal (not yet synced to backend)

**Steps:**
1. Navigate to Goals tab
2. Tap "+" to create a new goal
3. Fill in goal details:
   - Title: "Test Goal - QA"
   - Description: "Testing chat integration"
   - Target Date: 30 days from now
4. Tap "Create Goal"
5. Immediately swipe left on the new goal
6. Tap "Chat" action

**Expected Results:**
- ✅ Brief loading indicator (syncing to backend)
- ✅ "Syncing goal..." or similar message (optional)
- ✅ Navigation to chat after sync completes
- ✅ No error messages
- ✅ Chat loads with goal context

**Validation Points:**
- Goal sync happens automatically
- User not blocked or confused
- Chat opens successfully after sync
- Goal now has backend ID (can verify by checking persistence)

---

### Test Case 1.3: Chat About Goal (Network Error)

**Priority:** Medium  
**Preconditions:** Goal exists, network connectivity can be toggled

**Steps:**
1. Navigate to Goals tab
2. Turn off WiFi and cellular data
3. Swipe left on a goal
4. Tap "Chat" action

**Expected Results:**
- ✅ Error message displayed clearly
- ✅ Message indicates network issue
- ✅ Message suggests trying again later
- ✅ User can dismiss error
- ✅ App doesn't crash

**Example Error Message:**
"Unable to connect. Please check your internet connection and try again."

**Recovery Test:**
5. Turn network back on
6. Tap "Chat" again
7. Should succeed this time

---

## 2. Create Goal from Chat Suggestion

### Test Case 2.1: AI Suggests Goal - User Accepts

**Priority:** High  
**Preconditions:** User in a chat conversation

**Steps:**
1. Navigate to Chat tab
2. Open any conversation (or start new one)
3. Send a message that might trigger goal suggestion, e.g.:
   - "I want to exercise more"
   - "I need to drink more water"
   - "I'd like to meditate daily"
4. Wait for AI response
5. If AI suggests a goal, a card should appear
6. Tap "Create Goal" button on suggestion card

**Expected Results:**
- ✅ Goal creation confirmation appears
- ✅ Goal is added to Goals tab
- ✅ Goal has conversation linked
- ✅ User can see goal immediately in Goals tab
- ✅ Success message or indicator shown

**Validation Points:**
- Goal title and description match suggestion
- Target date is reasonable (e.g., 30 days from now)
- Goal status is "Not Started"
- Goal has backend ID (synced immediately)
- Conversation ID is linked to goal

---

### Test Case 2.2: View Created Goal from Chat

**Priority:** Medium  
**Preconditions:** Goal just created from chat suggestion

**Steps:**
1. After creating goal from chat (Test Case 2.1)
2. Navigate to Goals tab
3. Find the newly created goal
4. Tap to view goal details

**Expected Results:**
- ✅ Goal details match what was suggested
- ✅ Goal shows creation date (today)
- ✅ Progress is 0%
- ✅ "Chat About This Goal" button/action is available
- ✅ Tapping chat action returns to original conversation

---

### Test Case 2.3: Multiple Goal Suggestions in One Chat

**Priority:** Medium  
**Preconditions:** User in chat conversation

**Steps:**
1. Start a conversation about multiple wellness areas:
   - "I want to improve my fitness, sleep better, and eat healthier"
2. Wait for AI response
3. AI may suggest multiple goals
4. Create first suggested goal
5. Scroll to second suggestion
6. Create second suggested goal

**Expected Results:**
- ✅ All goal suggestions are actionable
- ✅ Can create multiple goals from one conversation
- ✅ Each goal is properly created and linked
- ✅ Goals tab shows all new goals
- ✅ No duplicate goals created

---

## 3. Streaming Message Reliability

### Test Case 3.1: Normal Streaming (Success Path)

**Priority:** High  
**Preconditions:** User in any chat conversation

**Steps:**
1. Navigate to Chat
2. Send a message: "Tell me about wellness habits"
3. Observe AI response streaming

**Expected Results:**
- ✅ Response begins within 1-2 seconds
- ✅ Message updates every ~2 seconds
- ✅ Text appears smoothly without jumps
- ✅ "..." indicator shows while streaming
- ✅ "..." disappears when complete
- ✅ Full message is readable and formatted
- ✅ No duplicate messages appear

**Validation Points:**
- Streaming feels natural, not too fast or slow
- No message splitting (each response is one message)
- Message doesn't get stuck with "..."
- Markdown formatting renders correctly

---

### Test Case 3.2: Streaming with Slow Connection

**Priority:** High  
**Preconditions:** Can simulate slow network

**Steps:**
1. Enable network throttling (in Xcode or device settings)
2. Set to "3G" or "Edge" speed
3. Send a message in chat
4. Observe streaming behavior

**Expected Results:**
- ✅ Streaming still works (may be slower)
- ✅ Updates happen as chunks arrive
- ✅ No timeout error for 30 seconds
- ✅ Message eventually completes
- ✅ Partial content is preserved if any issues

**Validation Points:**
- App doesn't crash on slow connection
- User sees progress (text appearing)
- Timeout only occurs after 30+ seconds of no data
- Error message is clear if timeout occurs

---

### Test Case 3.3: Streaming Timeout Recovery

**Priority:** Medium  
**Preconditions:** Can force network interruption

**Steps:**
1. Send a message in chat
2. Immediately turn off network (during streaming)
3. Wait 30+ seconds
4. Observe timeout behavior

**Expected Results:**
- ✅ Message shows partial content (if any received)
- ✅ Timeout message appears after 30s
- ✅ Error message is user-friendly
- ✅ User can send another message
- ✅ No stuck state in UI

**Example Timeout Message:**
"I'm having trouble responding right now. Please try again."

**Recovery Test:**
5. Turn network back on
6. Send another message
7. Should work normally

---

### Test Case 3.4: Rapid Message Sending

**Priority:** Low  
**Preconditions:** User in chat

**Steps:**
1. Send first message: "Hello"
2. Immediately send second message: "How are you?"
3. Immediately send third message: "Tell me about goals"
4. Observe all responses

**Expected Results:**
- ✅ All messages appear in correct order
- ✅ Each response streams independently
- ✅ No messages lost or skipped
- ✅ All responses complete successfully
- ✅ UI remains responsive throughout

---

## 4. Markdown Rendering

### Test Case 4.1: Headers and Text Formatting

**Priority:** Medium  
**Preconditions:** User in chat

**Steps:**
1. Send a message that triggers formatted response
2. Look for these markdown elements in AI response:
   - Headers (# Header)
   - Bold text (**bold**)
   - Italic text (*italic*)
   - Lists (- item)
   - Horizontal rules (---)

**Expected Results:**
- ✅ Headers are larger/bold
- ✅ Bold text is bold
- ✅ Italic text is italic
- ✅ Lists have bullet points
- ✅ Horizontal rules show as dividers

**Validation Points:**
- Formatting is consistent with Lume design
- Colors match brand palette
- Spacing is appropriate
- Text is readable

---

### Test Case 4.2: Horizontal Rules (Dividers)

**Priority:** Medium  
**Preconditions:** AI response contains dividers

**Steps:**
1. Send message that triggers structured response
2. Look for horizontal rules in response
3. Check these variations:
   - `---`
   - `***`
   - `___`

**Expected Results:**
- ✅ All three syntaxes render as visual dividers
- ✅ Dividers are subtle (light purple/lavender)
- ✅ Dividers have proper spacing above/below
- ✅ Dividers span message width

---

### Test Case 4.3: Lists and Nested Content

**Priority:** Low  
**Preconditions:** AI response contains lists

**Steps:**
1. Ask AI: "Give me 5 tips for better sleep"
2. Observe list formatting in response

**Expected Results:**
- ✅ Numbered or bulleted list appears
- ✅ Each item is clearly separated
- ✅ Indentation is consistent
- ✅ Text wraps properly within list items

---

## 5. Navigation and UI Polish

### Test Case 5.1: Goal Suggestion Card (No Flickering)

**Priority:** Medium  
**Preconditions:** Empty chat conversation

**Steps:**
1. Navigate to Chat tab
2. Start a new conversation
3. Observe empty state
4. Watch for goal suggestion card appearance

**Expected Results:**
- ✅ Empty state shows smoothly
- ✅ No flickering or jumping
- ✅ Goal suggestion card (if shown) fades in smoothly
- ✅ All elements are stable
- ✅ Animations are smooth (not janky)

---

### Test Case 5.2: Persona Icon Visibility

**Priority:** Low  
**Preconditions:** User in any chat

**Steps:**
1. Navigate to Chat
2. Open any conversation
3. Look at navigation bar
4. Find persona icon (sparkles icon)

**Expected Results:**
- ✅ Persona icon is visible
- ✅ Icon has high contrast (dark color: #3B332C)
- ✅ Icon is not washed out or hard to see
- ✅ Icon size is appropriate (~20pt)

---

### Test Case 5.3: Navigation Between Goals and Chat

**Priority:** High  
**Preconditions:** Goal with linked conversation exists

**Steps:**
1. Start in Goals tab
2. Swipe left on goal, tap "Chat"
3. Verify in chat screen
4. Tap back button
5. Verify returned to Goals tab
6. Goal detail is still visible (if was viewing detail)

**Expected Results:**
- ✅ Navigation is smooth
- ✅ No loss of context
- ✅ Back navigation works correctly
- ✅ State is preserved
- ✅ No crashes or errors

---

## 6. Data Persistence and Sync

### Test Case 6.1: Goal-Conversation Link Persists

**Priority:** High  
**Preconditions:** Goal with linked conversation

**Steps:**
1. Create conversation for a goal (chat about goal)
2. Note the goal and conversation
3. Force quit the app
4. Relaunch the app
5. Navigate to Goals tab
6. Find the same goal
7. Swipe left, tap "Chat"

**Expected Results:**
- ✅ Same conversation loads
- ✅ Message history is preserved
- ✅ Goal context is still present
- ✅ No new conversation created
- ✅ Link persists across app restarts

---

### Test Case 6.2: Goal Created from Chat Syncs

**Priority:** High  
**Preconditions:** None

**Steps:**
1. In chat, create a goal from AI suggestion
2. Note goal details
3. Navigate to Goals tab
4. Verify goal appears
5. Force quit app
6. Relaunch app
7. Navigate to Goals tab
8. Find the same goal

**Expected Results:**
- ✅ Goal still exists after restart
- ✅ Goal details are unchanged
- ✅ Goal has backend ID
- ✅ Conversation link is preserved
- ✅ Progress and status are correct

---

### Test Case 6.3: Offline Goal Creation

**Priority:** Medium  
**Preconditions:** Can toggle network

**Steps:**
1. Turn off network
2. Navigate to Goals tab
3. Create a new goal manually
4. Try to swipe left and chat about it

**Expected Results:**
- ✅ Goal is created locally
- ✅ Chat action shows error (no network)
- ✅ Error message is clear
- ✅ Goal is not lost

**Recovery Test:**
5. Turn network back on
6. Wait a moment for background sync
7. Try chat action again
8. Should work now (goal synced)

---

## 7. Error Handling

### Test Case 7.1: Backend Goal Not Found

**Priority:** Low  
**Preconditions:** Can manipulate backend data

**Steps:**
1. Create a goal with backend sync
2. Manually delete goal from backend (via API or admin)
3. In app, try to chat about that goal

**Expected Results:**
- ✅ Clear error message
- ✅ Suggests checking goal status or refreshing
- ✅ App doesn't crash
- ✅ User can recover (delete local goal or sync)

**Example Error:**
"This goal is no longer available. It may have been deleted."

---

### Test Case 7.2: Conversation Creation Fails

**Priority:** Medium  
**Preconditions:** Can simulate backend error

**Steps:**
1. Navigate to Goals tab
2. Attempt to chat about a goal
3. Simulate backend 500 error

**Expected Results:**
- ✅ Error message is shown
- ✅ Message is user-friendly (not technical)
- ✅ User can retry
- ✅ App doesn't crash

**Example Error:**
"We're having trouble starting the conversation. Please try again in a moment."

---

### Test Case 7.3: Missing Backend ID Handling

**Priority:** High  
**Preconditions:** Freshly created goal (not synced)

**Steps:**
1. Create a new goal
2. Turn off network immediately
3. Try to chat about the goal
4. Observe behavior

**Expected Results:**
- ✅ App attempts to sync goal first
- ✅ Clear message about needing network
- ✅ No crash or stuck state
- ✅ Can retry when network returns

---

## 8. Edge Cases

### Test Case 8.1: Very Long Goal Titles/Descriptions

**Priority:** Low  
**Preconditions:** None

**Steps:**
1. Create goal with very long title (200+ characters)
2. Create goal with very long description (1000+ characters)
3. Try to chat about these goals
4. Observe how context is displayed in chat

**Expected Results:**
- ✅ Long text doesn't break UI
- ✅ Text is truncated appropriately
- ✅ Full context is sent to AI (even if UI truncates)
- ✅ Chat loads successfully
- ✅ No layout issues

---

### Test Case 8.2: Special Characters in Goal Text

**Priority:** Low  
**Preconditions:** None

**Steps:**
1. Create goal with special characters:
   - Emojis: "Exercise 💪 3x per week"
   - Symbols: "Save $1,000 & reduce debt"
   - International: "Méditer chaque jour"
2. Chat about this goal
3. Verify everything displays correctly

**Expected Results:**
- ✅ Special characters preserved
- ✅ No encoding issues
- ✅ Chat displays goal context correctly
- ✅ AI can understand and respond appropriately

---

### Test Case 8.3: Rapid Goal Creation and Chat

**Priority:** Low  
**Preconditions:** None

**Steps:**
1. Quickly create 5 goals from chat suggestions
2. Navigate to Goals tab
3. Quickly try to chat about each goal
4. Observe system behavior

**Expected Results:**
- ✅ All goals created successfully
- ✅ All chat actions work
- ✅ No race conditions
- ✅ Correct conversation loaded for each goal
- ✅ No duplicate conversations

---

## 9. Accessibility Testing

### Test Case 9.1: VoiceOver Navigation

**Priority:** Medium  
**Preconditions:** VoiceOver enabled

**Steps:**
1. Enable VoiceOver on iOS device
2. Navigate to Goals tab
3. Use swipe gestures to navigate to a goal
4. Perform swipe action to chat
5. Navigate through chat interface

**Expected Results:**
- ✅ All elements are announced
- ✅ Actions are clearly labeled
- ✅ Navigation is logical
- ✅ User can complete full flow with VoiceOver

---

### Test Case 9.2: Dynamic Type Support

**Priority:** Low  
**Preconditions:** None

**Steps:**
1. Go to iOS Settings → Accessibility → Display & Text Size
2. Increase text size to largest
3. Return to Lume app
4. Navigate to Goals tab
5. Try chat about goal flow
6. View chat messages

**Expected Results:**
- ✅ All text scales appropriately
- ✅ No text is cut off
- ✅ Layout adapts to larger text
- ✅ Everything remains readable
- ✅ No overlapping elements

---

## 10. Performance Testing

### Test Case 10.1: Chat with Many Messages

**Priority:** Medium  
**Preconditions:** Conversation with 50+ messages

**Steps:**
1. Open a long conversation (create test data if needed)
2. Scroll through messages
3. Send a new message
4. Observe scrolling and streaming performance

**Expected Results:**
- ✅ Scrolling is smooth (60fps)
- ✅ Messages load quickly
- ✅ New message streaming works normally
- ✅ No lag or stuttering
- ✅ Memory usage is reasonable

---

### Test Case 10.2: Goals Tab with Many Goals

**Priority:** Low  
**Preconditions:** 20+ goals exist

**Steps:**
1. Navigate to Goals tab
2. Scroll through list
3. Swipe actions on various goals
4. Chat about goals near end of list

**Expected Results:**
- ✅ Scrolling is smooth
- ✅ Swipe actions are responsive
- ✅ Chat loads quickly for any goal
- ✅ No performance degradation

---

## Regression Testing Checklist

After any changes to Goals or Chat features, verify:

### Goals Functionality
- [ ] Can create new goals
- [ ] Can edit existing goals
- [ ] Can delete goals
- [ ] Goal progress updates
- [ ] Goal status changes work
- [ ] Swipe actions appear correctly

### Chat Functionality
- [ ] Can send messages
- [ ] Messages stream correctly
- [ ] Can start new conversations
- [ ] Can view message history
- [ ] Markdown renders properly
- [ ] Persona icons display

### Integration Points
- [ ] Chat about goal from Goals tab
- [ ] Create goal from chat suggestion
- [ ] Goal context shows in chat
- [ ] Navigation between features works
- [ ] Data persists correctly
- [ ] Sync happens reliably

---

## Bug Report Template

When reporting issues, include:

```
**Title:** [Brief description]

**Priority:** High/Medium/Low

**Environment:**
- App Version: [e.g., 1.0.0 build 123]
- iOS Version: [e.g., 17.2]
- Device: [e.g., iPhone 15 Pro]

**Test Case:** [Reference test case number]

**Steps to Reproduce:**
1. [First step]
2. [Second step]
3. [etc.]

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Screenshots/Videos:**
[Attach if available]

**Additional Notes:**
[Any other relevant information]
```

---

## Testing Sign-Off

### Feature Readiness Checklist

Before approving for release:

- [ ] All High priority test cases passed
- [ ] All Medium priority test cases passed (or documented exceptions)
- [ ] No critical bugs found
- [ ] Performance is acceptable
- [ ] Accessibility tested
- [ ] Error handling verified
- [ ] Data persistence confirmed
- [ ] Backend integration validated
- [ ] Documentation reviewed
- [ ] Team demo completed

### Sign-Off

**Tested By:** ___________________  
**Date:** ___________________  
**Build Version:** ___________________  
**Status:** ✅ Approved / ⚠️ Approved with Issues / ❌ Not Approved  

**Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

## Contact

**Questions about test cases:** iOS Engineering Team  
**Bug reports:** QA Team Lead  
**Feature clarification:** Product Manager  

---

**Last Updated:** 2025-01-30  
**Version:** 1.0.0  
**Next Review:** After first production release