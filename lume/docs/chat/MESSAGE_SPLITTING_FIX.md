# Message Splitting Fix

**Date:** 2025-01-29  
**Issue:** AI responses split into multiple messages mid-sentence  
**Status:** ✅ Fixed

---

## Problem Statement

### User Report

> "the responses now are broken down in multiple messages, somethings breaking it in half or mid sentence"

AI responses were being split into multiple separate messages, sometimes breaking in the middle of sentences. This created a poor user experience and made conversations hard to follow.

### Example of Issue

**Expected Behavior:**
```
AI: "I can certainly help you with that. Let me provide some suggestions 
     based on your goals and preferences. Here are three options to consider..."
```

**Actual Behavior (Bug):**
```
AI: "I can certainly help you with that. Let me provide some suggestions"
AI: " based on your goals and preferences. Here are three options to consider..."
```

---

## Root Cause

The streaming timeout mechanism (added to prevent stuck messages) was triggering prematurely during long responses. Here's what was happening:

### Original Logic Flow

1. First stream chunk arrives → Start 5-second timeout
2. More chunks arrive → Update message content
3. **Timeout fires after 5 seconds** (even if chunks still coming)
4. Message finalized prematurely
5. New chunks arrive → Create **NEW message** with remaining content
6. Result: Message split into multiple parts ❌

### The Bug

**Problem:** Timeout only started once but never reset when new chunks arrived.

```swift
// ORIGINAL (BUGGY) CODE
case "stream_chunk":
    if let messageID = currentStreamingMessageID {
        // Update existing message
        messages[index].content = currentStreamingMessage
        // ❌ NO TIMEOUT RESET - timeout keeps counting from first chunk
    } else {
        // Create new message
        messages.append(streamingMessage)
        startStreamingTimeout()  // Only starts here
    }
```

**Impact:** Any response taking longer than 5 seconds would be split, regardless of whether chunks were still arriving.

---

## Solution

### Timeout Reset on Each Chunk

Changed the timeout to be an **inactivity timeout** that resets whenever a new chunk arrives:

```swift
// FIXED CODE
case "stream_chunk":
    if let content = message.content {
        currentStreamingMessage += content
        
        if let messageID = currentStreamingMessageID,
            let index = messages.firstIndex(where: { $0.id == messageID }) {
            // Update existing streaming message
            messages[index].content = currentStreamingMessage
            // ✅ RESET TIMEOUT - each chunk restarts the 5-second timer
            startStreamingTimeout()
        } else {
            // Create new streaming message
            messages.append(streamingMessage)
            // Start initial timeout
            startStreamingTimeout()
        }
    }
```

### How It Works Now

1. First chunk arrives → Start 5-second timeout
2. Second chunk arrives (3s later) → **Reset timeout** to 5 seconds
3. Third chunk arrives (2s later) → **Reset timeout** to 5 seconds
4. Fourth chunk arrives (1s later) → **Reset timeout** to 5 seconds
5. Stream complete signal → Cancel timeout, finalize message ✅

**Key Change:** Timeout only triggers if **no chunks arrive for 5 consecutive seconds**.

---

## Timeout Behavior Comparison

### Before Fix (Total Duration)

```
Chunk 1 (t=0s)     → Start 5s timeout
Chunk 2 (t=2s)     → Continue (no reset)
Chunk 3 (t=4s)     → Continue (no reset)
Timeout (t=5s)     → ❌ FIRES - message finalized
Chunk 4 (t=6s)     → ❌ Creates NEW message (split!)
Chunk 5 (t=7s)     → Updates second message
```

**Result:** Message split into 2 parts after 5 seconds

### After Fix (Inactivity Duration)

```
Chunk 1 (t=0s)     → Start 5s timeout
Chunk 2 (t=2s)     → ✅ Reset to 5s (now t=7s)
Chunk 3 (t=4s)     → ✅ Reset to 5s (now t=9s)
Chunk 4 (t=6s)     → ✅ Reset to 5s (now t=11s)
Chunk 5 (t=7s)     → ✅ Reset to 5s (now t=12s)
Complete (t=8s)    → ✅ Cancel timeout, finalize
```

**Result:** Single complete message, no splitting ✅

---

## Technical Implementation

### File Modified

**ConsultationWebSocketManager.swift** (Lines 261-264, 454-490)

### Code Changes

```swift
// CHANGE 1: Reset timeout on chunk update
case "stream_chunk":
    if let messageID = currentStreamingMessageID,
        let index = messages.firstIndex(where: { $0.id == messageID }) {
        messages[index].content = currentStreamingMessage
+       // Reset timeout since we received a new chunk
+       startStreamingTimeout()
    }

// CHANGE 2: Updated documentation
/// Start a timeout timer for streaming messages to handle cases where stream_complete is never received
+/// This resets the timeout each time a new chunk arrives, only triggering if no chunks for 5 seconds
private func startStreamingTimeout() {
-   // Cancel any existing timeout
+   // Cancel any existing timeout to reset the timer
    streamingTimeoutTask?.cancel()
    
    // ... rest of implementation
}
```

---

## Benefits

### User Experience
- ✅ Complete, unbroken responses
- ✅ No mid-sentence splits
- ✅ Natural conversation flow
- ✅ Professional appearance

### Technical
- ✅ Handles long responses correctly
- ✅ Still protects against truly stuck messages
- ✅ Timeout only for actual inactivity (no chunks)
- ✅ No performance impact

---

## Testing Scenarios

### Test 1: Short Response (<5 seconds)
**Expected:** Works exactly as before, single message ✅

### Test 2: Long Response (>5 seconds)
**Expected:** Single complete message, no splitting ✅  
**Before Fix:** Would split ❌

### Test 3: Very Long Response (>20 seconds)
**Expected:** Single complete message as long as chunks keep arriving ✅  
**Before Fix:** Would split multiple times ❌

### Test 4: Stuck Message (No chunks for 5s)
**Expected:** Timeout triggers, message finalized ✅  
**Purpose:** Still protects against backend failures

### Test 5: Slow Streaming (chunks every 4s)
**Expected:** Single message, timeout keeps resetting ✅  
**Before Fix:** Would timeout and split ❌

---

## Console Log Examples

### Normal Long Response (After Fix)

```
📝 [ConsultationWS] Stream chunk received, total length: 45
📝 [ConsultationWS] Stream chunk received, total length: 98
📝 [ConsultationWS] Stream chunk received, total length: 152
📝 [ConsultationWS] Stream chunk received, total length: 201
📝 [ConsultationWS] Stream chunk received, total length: 267
✅ [ConsultationWS] Stream complete, final length: 267
```

**Result:** Single message with 267 characters ✅

### Stuck Message (Timeout Triggers)

```
📝 [ConsultationWS] Stream chunk received, total length: 45
📝 [ConsultationWS] Stream chunk received, total length: 98
(5 seconds of silence - no new chunks)
⏰ [ConsultationWS] Streaming timeout reached (no chunks for 5s), finalizing message
✅ [ConsultationWS] Stream finalized by timeout, length: 98
```

**Result:** Message finalized at 98 characters (backend stopped) ✅

---

## Configuration

### Timeout Duration

```swift
private let streamingTimeout: TimeInterval = 5.0  // Inactivity timeout
```

**5 seconds** is optimal because:
- Long enough to handle normal processing pauses
- Short enough to catch genuinely stuck messages
- Resets on activity, so doesn't limit total response length

**Important:** This is an **inactivity** timeout:
- ✅ Measures time **between chunks**
- ❌ NOT time since first chunk
- ✅ Resets on every chunk
- ✅ No limit on total message duration

---

## Edge Cases Handled

### Case 1: Very Slow Backend
- Backend sends chunks with 4-second gaps
- Each chunk resets timeout
- Message completes as single unit ✅

### Case 2: Network Hiccups
- Temporary network delay between chunks
- Timeout resets when chunks resume
- No premature finalization ✅

### Case 3: Backend Processing Pauses
- Backend pauses to think/process
- Timeout allows 5-second pauses
- Resumes when chunks continue ✅

### Case 4: Genuinely Stuck
- Backend crashes or hangs
- No chunks for 5+ seconds
- Timeout triggers correctly ✅

---

## Related Issues

### Why Original Implementation Was Wrong

The original timeout was meant to prevent **stuck messages**, but it accidentally prevented **long messages** instead:

- **Stuck message:** Backend stops sending, user waits forever
- **Long message:** Backend keeps sending, just takes time

The fix distinguishes between these two scenarios:
- **Inactivity (stuck):** Timeout triggers ✅
- **Activity (long):** Timeout keeps resetting ✅

---

## Performance Impact

### Memory
- Same as before (single Task per streaming message)
- Task cancelled and recreated on each chunk
- Minimal overhead

### CPU
- Negligible (Task cancellation is lightweight)
- No performance impact on normal streaming

### User Perception
- No change in streaming speed
- Better experience (no splits)

---

## Related Documentation

- [Streaming Timeout Fix](./STREAMING_TIMEOUT_FIX.md) - Original timeout implementation
- [Backend Sync Optimization](./BACKEND_SYNC_OPTIMIZATION.md) - Related work
- [UI Flickering and Polling Fix](./UI_FLICKERING_AND_POLLING_FIX.md) - Other recent fixes

---

## Summary

Messages were being split because the streaming timeout was a **total duration** timer instead of an **inactivity** timer. By resetting the timeout on each chunk arrival, we now correctly distinguish between:

- **Long responses that are still streaming** → Keep going ✅
- **Stuck responses that stopped streaming** → Timeout and finalize ✅

The fix is a simple 2-line addition that fundamentally changes the timeout behavior from "finalize after 5 seconds" to "finalize after 5 seconds **of inactivity**".

**Key Principle:** Timeouts should measure **inactivity**, not **total duration**, when dealing with streaming data.

---

**Implementation Date:** 2025-01-29  
**Files Modified:** 1 (ConsultationWebSocketManager.swift)  
**Lines Added:** 2  
**Impact:** Critical (prevents message splitting)  
**Status:** ✅ Fixed and Tested