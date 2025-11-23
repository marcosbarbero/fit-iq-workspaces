# Live Chat Testing Guide 🧪

**Purpose:** Verify that the ConsultationWebSocketManager live streaming is working  
**Status:** Enhanced logging added for debugging

---

## 🔍 What to Look For

When you open/create a conversation and send a message, you should see these logs **in order**:

### Expected Log Sequence for Live Chat

```
1. When Opening Conversation:
🔌 [ChatViewModel] connectWebSocket called for: CONVERSATION-UUID
✅ [ChatViewModel] Current conversation found, starting live chat...
🎬 [ChatViewModel] startLiveChat called for conversation: UUID, persona: wellness_specialist
🔑 [ChatViewModel] Getting token from storage...
✅ [ChatViewModel] Token retrieved successfully
✅ [ChatViewModel] API key retrieved: ****************************
🚀 [ChatViewModel] Starting live chat with ConsultationWebSocketManager
🚀 [ConsultationWS] Starting consultation with persona: wellness_specialist
📡 [ConsultationWS] Create consultation response: 409 (or 201)
ℹ️ [ConsultationWS] Consultation exists, fetching: CONSULTATION-ID
✅ [ConsultationWS] Got consultation ID: CONSULTATION-ID
✅ [ConsultationWS] Loaded X historical messages
🔌 [ConsultationWS] Connecting to: wss://fit-iq-backend.fly.dev/api/v1/consultations/ID/ws
✅ [ConsultationWS] WebSocket connected to consultation: CONSULTATION-ID
✅ [ChatViewModel] Live chat started successfully

2. When Server Confirms Connection:
📥 [ConsultationWS] Received: {"type":"connected"...
✅ [ConsultationWS] Connection confirmed by server

3. When Sending Message:
💬 [ChatViewModel] Sending via live chat WebSocket
📤 [ConsultationWS] Sending message: Your message here...
✅ [ConsultationWS] Message sent to WebSocket

4. When Receiving Response:
📥 [ConsultationWS] Received: {"type":"message_received"...
✅ [ConsultationWS] Server acknowledged message
📥 [ConsultationWS] Received: {"type":"stream_chunk","content":"I "...
📝 [ConsultationWS] Stream chunk received, total length: 2
📥 [ConsultationWS] Received: {"type":"stream_chunk","content":"understand "...
📝 [ConsultationWS] Stream chunk received, total length: 12
... (more chunks)
📥 [ConsultationWS] Received: {"type":"stream_complete"...
✅ [ConsultationWS] Stream complete, final length: 150
```

---

## ❌ What You're Seeing Instead

Based on your logs, you're seeing:

```
✅ [ChatViewModel] REST API message sent and response received
```

This means the app is **NOT** using live chat, but falling back to REST API.

---

## 🐛 Debugging Steps

### Step 1: Check if connectWebSocket is Called

Look for:
```
🔌 [ChatViewModel] connectWebSocket called for: UUID
```

**If you DON'T see this:**
- The conversation wasn't opened with `selectConversation()`
- OR it was created but WebSocket connection wasn't triggered

**If you DO see this:**
- Continue to Step 2

### Step 2: Check if startLiveChat is Called

Look for:
```
🎬 [ChatViewModel] startLiveChat called for conversation: UUID
```

**If you DON'T see this:**
- `currentConversation` is nil
- Check if conversation was set properly

**If you DO see this:**
- Continue to Step 3

### Step 3: Check Token Retrieval

Look for:
```
🔑 [ChatViewModel] Getting token from storage...
✅ [ChatViewModel] Token retrieved successfully
```

**If you see "No token available":**
- User is not logged in properly
- Token was cleared

**If token is retrieved:**
- Continue to Step 4

### Step 4: Check for Errors

Look for:
```
❌ [ChatViewModel] Failed to start live chat: ERROR
```

**Common errors:**
- `ConsultationError.httpError(409)` - Expected, should be handled
- `ConsultationError.httpError(401)` - Token invalid
- Network errors - Check internet connection
- WebSocket connection errors - Check backend URL

---

## 🧪 Manual Test Procedure

### Test 1: Create New Conversation

1. **Open app** and log in
2. **Navigate** to Chat tab
3. **Create** new conversation (tap "Start Chat" or similar)
4. **Watch console** for:
   ```
   🔌 [ChatViewModel] connectWebSocket called
   🎬 [ChatViewModel] startLiveChat called
   🚀 [ConsultationWS] Starting consultation
   ```
5. **Send message**
6. **Watch for:**
   ```
   💬 [ChatViewModel] Sending via live chat WebSocket
   📝 [ConsultationWS] Stream chunk received
   ```

**Expected:** Live chat works, message streams in real-time

### Test 2: Select Existing Conversation

1. **Open app** (already logged in)
2. **Navigate** to Chat tab
3. **See list** of existing conversations
4. **Tap** on an existing conversation
5. **Watch console** for:
   ```
   🔌 [ChatViewModel] connectWebSocket called
   🎬 [ChatViewModel] startLiveChat called
   ```
6. **Send message**
7. **Watch for:**
   ```
   💬 [ChatViewModel] Sending via live chat WebSocket
   ```

**Expected:** Live chat connects, message streams

### Test 3: Verify Fallback

1. **Turn off WiFi** (to simulate network issue)
2. **Open conversation**
3. **Watch console** for:
   ```
   ❌ [ChatViewModel] Failed to start live chat
   🔄 [ChatViewModel] Falling back to polling
   ```
4. **Send message**
5. **Watch for:**
   ```
   ✅ [ChatViewModel] REST API message sent
   ```

**Expected:** Falls back gracefully, still works

---

## 🔧 Quick Fixes

### Issue: No logs at all

**Solution:**
- Make sure you're running in Debug configuration
- Check Console filter isn't hiding logs
- Try adding breakpoint in `connectWebSocket`

### Issue: Token not found

**Solution:**
- Log out and log back in
- Check if `tokenStorage` is properly wired
- Verify token is saved on login

### Issue: 409 Conflict not handled

**Solution:**
- Check if `getOrCreateConsultation` handles 409
- Should fetch existing consultation ID
- Verify consultation is fetched successfully

### Issue: WebSocket URL wrong

**Solution:**
- Check `config.plist`:
  ```xml
  <key>WebSocketURL</key>
  <string>wss://fit-iq-backend.fly.dev</string>
  ```
- Verify `AppConfiguration` loads it correctly

---

## 📊 Comparison: Live Chat vs REST API

### Live Chat (Desired)
```
User sends message
  ↓ (instant)
💬 [ChatViewModel] Sending via live chat WebSocket
  ↓ (websocket)
Backend processes
  ↓ (real-time chunks)
📝 [ConsultationWS] Stream chunk received
📝 [ConsultationWS] Stream chunk received
📝 [ConsultationWS] Stream chunk received
  ↓ (complete)
✅ [ConsultationWS] Stream complete
```

**Result:** Character-by-character streaming ✨

### REST API (Fallback)
```
User sends message
  ↓ (HTTP POST)
✅ [ChatViewModel] REST API message sent
  ↓ (wait for full response)
✅ [ChatViewModel] REST API message received
  ↓ (polling)
✅ [ChatViewModel] Polled 1 new message(s)
```

**Result:** Full message at once (slower)

---

## 🎯 Success Criteria

✅ See "Starting live chat with ConsultationWebSocketManager"  
✅ See "WebSocket connected to consultation"  
✅ See "Sending via live chat WebSocket"  
✅ See "Stream chunk received" multiple times  
✅ See "Stream complete"  
✅ Message appears character-by-character in UI  

---

## 📝 What to Share for Help

If live chat still isn't working, share:

1. **Full console log** from app launch to sending message
2. **Look for:**
   - Is `connectWebSocket` called?
   - Is `startLiveChat` called?
   - Any error messages?
   - Which path is taken (live chat or REST)?
3. **Check:**
   - Is user logged in?
   - Does conversation exist?
   - Is `currentConversation` set?

---

## 🚀 Next Steps

1. **Run the app** in Debug mode
2. **Open/create conversation**
3. **Check console** for the new detailed logs
4. **Send a message**
5. **Look for** the log patterns above

The enhanced logging will show **exactly** where the flow is going and why live chat isn't being used.

---

**With the new logging, you should be able to identify exactly where the issue is!** 🔍
