# Chat Testing Steps - Quick Verification Guide

**Date:** 2025-01-28  
**Purpose:** Step-by-step testing for chat navigation and response fixes  
**Estimated Time:** 10-15 minutes

---

## Prerequisites

- [ ] App is compiled and running on simulator/device
- [ ] User is logged in
- [ ] Backend is accessible (`fit-iq-backend.fly.dev`)
- [ ] Xcode console is open for monitoring logs

---

## Test 1: Fix Existing Chat Selection Bug ✅

**Issue:** Clicking on existing chat was creating new conversation instead of opening it.

### Steps:
1. Go to **AI Chat** tab
2. If no chats exist, create one first (see Test 2)
3. **Tap on an existing conversation** in the list
4. Observe the conversation opens
5. **Note the conversation title** in the navigation bar
6. Go back to the chat list
7. **Tap on the SAME conversation again**

### Expected Results:
- ✅ Same conversation opens (same title, same messages)
- ✅ No new conversation is created
- ✅ Message history is preserved
- ✅ Conversation list count doesn't increase

### Console Logs to Check:
```
📖 [ChatViewModel] selectConversation called for: [UUID]
✅ [ChatViewModel] Setting new current conversation: [UUID]
```

### ❌ FAIL if:
- New conversation is created
- Conversation list grows in size
- Messages disappear or reset
- Different conversation ID in logs

---

## Test 2: Fix "Start Blank Chat" Bug ✅

**Issue:** "Start Blank Conversation" was opening first existing chat instead of creating new one.

### Steps:
1. Go to **AI Chat** tab
2. If conversations exist, tap the **FAB (+ button)** in bottom-right
3. In the "New Chat" sheet, tap **"Start Blank Conversation"**
4. Observe a new chat opens
5. **Count conversations** in the list
6. Repeat steps 2-4 to create **another new conversation**
7. **Count conversations again**

### Expected Results:
- ✅ New empty conversation opens each time
- ✅ Conversation count increases by 1 each time
- ✅ Each conversation has unique ID
- ✅ Sheet dismisses automatically
- ✅ You land in the new conversation ready to type

### Console Logs to Check:
```
🆕 [ChatViewModel] Force creating new conversation (forceNew=true)
✅ [ChatViewModel] Created new conversation: [NEW-UUID]
```

### ❌ FAIL if:
- Opens existing conversation
- Conversation count doesn't increase
- Gets stuck or shows error
- Same conversation ID in logs

---

## Test 3: Fix AI Response Not Appearing ✅

**Issue:** Messages sent but AI responses weren't appearing in UI.

### Steps:
1. Open or create a conversation
2. Type a message: **"Hello, how are you?"**
3. Tap the **send button** (arrow up circle)
4. Observe:
   - Your message appears immediately
   - Typing indicator (three dots) appears
   - AI response streams in word-by-word
   - Typing indicator disappears when done
5. Send **another message**: **"Tell me about sleep hygiene"**
6. Observe AI responds again
7. Send a **third message** to verify consistency

### Expected Results:
- ✅ User message appears instantly in UI
- ✅ Typing indicator shows with AI persona icon
- ✅ AI response appears within 2-3 seconds
- ✅ Response streams in smoothly (not all at once)
- ✅ Typing indicator disappears when response complete
- ✅ Multiple messages work consistently
- ✅ Messages are correctly aligned (user right, AI left)

### Console Logs to Check:
```
📤 [ChatViewModel] Sending message: 'Hello, how are you?'...
💬 [ChatViewModel] Sending via live chat WebSocket
📤 [ConsultationWS] Sending message: Hello, how are you?...
✅ [ConsultationWS] Message sent to WebSocket
📥 [ConsultationWS] Received: {"type":"message_received"}...
📝 [ConsultationWS] Stream chunk received, total length: [X]
✅ [ConsultationWS] Stream complete, final length: [Y]
🔄 [ChatViewModel] Syncing [N] messages from consultation manager
✅ [ChatViewModel] Synced messages, now showing [N] in UI
```

### ❌ FAIL if:
- AI response never appears
- Typing indicator shows forever
- Error message appears
- Messages appear out of order
- Response appears all at once (not streaming)
- Console shows connection errors

---

## Test 4: Quick Action Messages ✨

**Bonus test for quick action functionality.**

### Steps:
1. Tap **FAB (+)** button
2. Tap one of the quick action buttons (e.g., "Check In")
3. Observe:
   - New conversation created
   - Initial message sent automatically
   - AI responds to the quick action

### Expected Results:
- ✅ Quick action creates new conversation
- ✅ Pre-filled message is sent
- ✅ AI responds appropriately to the context
- ✅ Sheet dismisses and lands in new chat

---

## Test 5: Navigation Between Chats ✨

**Test switching between multiple conversations.**

### Steps:
1. Ensure you have **at least 3 conversations**
2. Open **conversation A**
3. Send a message: "This is chat A"
4. Go back to chat list
5. Open **conversation B**
6. Send a message: "This is chat B"
7. Go back to chat list
8. Open **conversation A again**
9. Verify you see "This is chat A" message

### Expected Results:
- ✅ Each conversation maintains its own messages
- ✅ No message mixing between conversations
- ✅ WebSocket reconnects properly when switching
- ✅ No duplicate messages appear

### Console Logs to Check:
```
📖 [ChatViewModel] selectConversation called for: [UUID-A]
🔌 [ChatViewModel] Connecting to WebSocket for new conversation
...
📖 [ChatViewModel] selectConversation called for: [UUID-B]
🔌 [ChatViewModel] Connecting to WebSocket for new conversation
```

---

## Test 6: Error Handling ⚠️

**Test graceful degradation when WebSocket fails.**

### Steps:
1. Turn on **Airplane Mode** on device/simulator
2. Open a conversation
3. Try to send a message
4. Observe error handling
5. Turn off Airplane Mode
6. Send message again

### Expected Results:
- ✅ Error message shown to user
- ✅ Message not lost from input field
- ✅ Can retry after connection restored
- ✅ App doesn't crash

### Console Logs to Check:
```
⚠️ [ChatViewModel] Live chat failed: [error], falling back to REST API
❌ [ConsultationWS] Failed to start live chat: [error]
```

---

## Test 7: Conversation List Features ✨

**Test swipe actions and filters.**

### Steps:
1. In chat list, **swipe left** on a conversation
2. Tap **Delete**
3. Verify conversation is removed
4. Create a new conversation
5. **Swipe right** on it
6. Tap **Archive**
7. Tap the **filter button** (top-right)
8. Toggle **"Show Archived Only"**
9. Verify archived conversation appears

### Expected Results:
- ✅ Swipe actions work smoothly
- ✅ Delete removes conversation immediately
- ✅ Archive hides conversation from main list
- ✅ Filter shows/hides archived conversations
- ✅ Actions don't trigger navigation

---

## Test 8: FAB Button Visibility ✨

**Test floating action button appears correctly.**

### Steps:
1. Start with **no conversations** (delete all if needed)
2. Observe empty state with "Start Chatting" button
3. **Verify FAB is NOT visible**
4. Tap "Start Chatting" to create first conversation
5. Return to chat list
6. **Verify FAB IS visible** in bottom-right corner

### Expected Results:
- ✅ FAB hidden when list is empty
- ✅ FAB visible when conversations exist
- ✅ FAB positioned correctly (bottom-right)
- ✅ FAB has proper styling (warm peach color)

---

## Quick Smoke Test (2 minutes)

If short on time, run this abbreviated test:

1. ✅ **Tap existing chat** → Opens correct conversation
2. ✅ **Tap FAB → Start blank chat** → Creates new conversation
3. ✅ **Send message** → AI responds within 3 seconds
4. ✅ **Send another message** → AI responds again

If all 4 pass, core functionality is working!

---

## Success Criteria

### All Tests Must Pass:
- [x] ✅ Existing chat opens correctly (Test 1)
- [x] ✅ Start blank chat creates new conversation (Test 2)
- [x] ✅ AI responses appear in UI (Test 3)
- [x] ✅ Quick actions work (Test 4)
- [x] ✅ Navigation between chats works (Test 5)
- [x] ✅ Error handling works (Test 6)
- [x] ✅ List features work (Test 7)
- [x] ✅ FAB visibility correct (Test 8)

### Console Must Be Clean:
- No repeated error messages
- No crash logs
- No infinite loops
- WebSocket connects successfully

---

## Troubleshooting

### If Test 1 Fails (Chat Selection):
- Check: Is `NavigationLink` still being used? (should be `Button`)
- Check: Is `conversationToNavigate` being set?
- Check logs for: "selectConversation called"

### If Test 2 Fails (Blank Chat):
- Check: Is `forceNew: true` parameter being passed?
- Check: Is `createConversation` reusing existing conversation?
- Check logs for: "Force creating new conversation"

### If Test 3 Fails (AI Response):
- Check: Is WebSocket connected? Look for "WebSocket connected"
- Check: Are messages syncing? Look for "Syncing [N] messages"
- Check: Is backend reachable? Try from browser
- Check: Is token valid? Look for auth errors

### If Multiple Tests Fail:
1. Clean build (Cmd+Shift+K)
2. Rebuild app (Cmd+B)
3. Delete app from simulator
4. Re-install and test again
5. Check backend status
6. Verify `config.plist` settings

---

## Reporting Issues

If any test fails, provide:

1. **Which test failed** (number and name)
2. **What happened** vs what was expected
3. **Console logs** from Xcode
4. **Screenshots** of the issue
5. **Device/Simulator** info
6. **Steps to reproduce** consistently

---

## Sign-Off

After completing all tests:

- [ ] All 8 tests passed
- [ ] No errors in console
- [ ] UI is smooth and responsive
- [ ] Ready for QA/production

**Tester Name:** _______________  
**Date:** _______________  
**Build Version:** _______________  
**Result:** ✅ PASS / ❌ FAIL

---

**Good luck with testing! 🚀**