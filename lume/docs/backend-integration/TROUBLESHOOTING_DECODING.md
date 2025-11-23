# Troubleshooting Payload Decoding Issues

**Date:** 2025-01-15  
**Version:** 1.2.0  
**Purpose:** Fix "The data couldn't be read because it isn't in the correct format" errors

---

## The Error You're Seeing

```
⚠️ [OutboxProcessor] Event mood.created failed (retry 1/5): The data couldn't be read because it isn't in the correct format.
```

This means the JSON payload stored in the outbox doesn't match what the processor expects.

---

## Root Cause

**Date encoding mismatch** between:
- Where payload is created (`MoodRepository`)
- Where payload is decoded (`OutboxProcessorService`)

### The Problem

**Repository encodes dates as:**
```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601  // ISO 8601 format
let payloadData = try encoder.encode(payload)
```

**Processor decodes dates as:**
```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601  // Must match!
let payload = try decoder.decode(MoodCreatedPayload.self, from: event.payload)
```

If these don't match, decoding fails!

---

## The Fix (Already Applied)

### 1. Repository Side (`MoodRepository.swift`)

**Added ISO 8601 encoding:**
```swift
// When creating mood event
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601  // ← Added this
let payloadData = try encoder.encode(payload)
```

### 2. Processor Side (`OutboxProcessorService.swift`)

**Ensured ISO 8601 decoding:**
```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601  // ← Matches encoder
let payload = try decoder.decode(MoodCreatedPayload.self, from: event.payload)
```

### 3. Payload Structure Match

**Made sure fields match exactly:**

**MoodRepository Payload:**
```swift
private struct MoodPayload: Codable {
    let id: UUID
    let userId: UUID        // Required
    let mood: String
    let note: String?       // Optional
    let date: Date
    let createdAt: Date     // Required
    let updatedAt: Date     // Required
}
```

**OutboxProcessor Payload:**
```swift
private struct MoodCreatedPayload: Decodable {
    let id: UUID
    let userId: UUID        // Required (matching)
    let mood: String
    let note: String?       // Optional (matching)
    let date: Date
    let createdAt: Date     // Required (matching)
    let updatedAt: Date     // Required (matching)
}
```

---

## How to Test the Fix

### Step 1: Clear Old Events

Old events in the outbox may have wrong format. Delete them:

**Option A: Delete app and reinstall**
- Clears SwiftData database
- Fresh start

**Option B: Clear outbox programmatically**
```swift
// In a debug function
let events = try await outboxRepository.pendingEvents()
for event in events {
    try await outboxRepository.markCompleted(event)
}
```

### Step 2: Track a New Mood

1. Run app (⌘+R)
2. Track a mood
3. Watch console logs

**You should see:**
```
✅ [MoodRepository] Saved mood locally: Happy for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: abc-123
📦 [OutboxRepository] Event created: type='mood.created', id=xyz-789, status=pending
```

### Step 3: Wait for Processing

After 30 seconds (or bring app to foreground):

**Success looks like:**
```
📦 [OutboxProcessor] Processing 1 pending events
📋 [OutboxProcessor] Decoding payload: {"id":"abc-123","user_id":"def-456",...}
✅ [OutboxProcessor] Payload decoded successfully: id=abc-123, mood=happy
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Failure looks like:**
```
📦 [OutboxProcessor] Processing 1 pending events
📋 [OutboxProcessor] Decoding payload: {"id":"abc-123",...}
❌ [OutboxProcessor] Payload decode failed: keyNotFound(...)
⚠️ [OutboxProcessor] Event mood.created failed (retry 1/5): The data couldn't be read...
```

---

## Debug Logging

Enhanced logging now shows:

1. **Raw payload JSON** - See what's actually stored
2. **Decode success/failure** - Know immediately if it worked
3. **Error details** - Specific information about what went wrong

**Look for these logs:**
```
📋 [OutboxProcessor] Decoding payload: {...}
✅ [OutboxProcessor] Payload decoded successfully: ...
```

or

```
❌ [OutboxProcessor] Payload decode failed: ...
❌ [OutboxProcessor] Error details: ...
```

---

## Common Issues & Solutions

### Issue 1: "keyNotFound" error

**Error:**
```
❌ keyNotFound(CodingKeys(stringValue: "created_at", intValue: nil))
```

**Meaning:** Field missing in payload

**Solution:**
- Check `MoodPayload.init(entry:)` assigns all fields
- Verify `MoodEntry` has all required properties
- Clear old events and create new ones

### Issue 2: "typeMismatch" error

**Error:**
```
❌ typeMismatch(Date.self, ...)
```

**Meaning:** Date format doesn't match

**Solution:**
- Verify both encoder and decoder use `.iso8601`
- Check `createdAt` and `updatedAt` are Date types
- Clear old events with wrong format

### Issue 3: "dataCorrupted" error

**Error:**
```
❌ dataCorrupted(...)
```

**Meaning:** Invalid JSON structure

**Solution:**
- Check payload is valid JSON
- Look at `📋 Decoding payload:` log
- Verify no corruption in database

### Issue 4: Old events keep failing

**Problem:** Events created before fix still have old format

**Solution:**
1. Delete app from simulator/device
2. Reinstall
3. Track new mood
4. Should work now

---

## Verification Checklist

After applying fix:

- [ ] Rebuild app (⌘+⇧+K then ⌘+B)
- [ ] Clear old events (delete app or mark completed)
- [ ] Track a new mood
- [ ] See "Event created" log
- [ ] Wait 30 seconds or foreground app
- [ ] See "Payload decoded successfully" log
- [ ] See "Successfully synced" log
- [ ] See "Processing complete: 1 succeeded" log
- [ ] No "decode failed" errors
- [ ] Backend has the mood data

---

## Technical Details

### Date Encoding Strategies

**ISO 8601 (Used):**
```
"2025-01-15T10:30:00Z"
```
- Standard format
- Cross-platform compatible
- Human readable

**Timestamp (Not Used):**
```
1705319400.0
```
- Seconds since 1970
- Less readable
- Would also work if consistent

**Custom (Not Used):**
```
"2025-01-15"
```
- Custom format
- Requires formatter
- More complex

### Why ISO 8601?

✅ **Standard format** - Works with backend APIs  
✅ **Human readable** - Easy to debug  
✅ **Built-in support** - Native in Swift/Foundation  
✅ **Timezone aware** - Includes UTC offset

---

## Prevention

### For New Event Types

When adding journal, goal, or other events:

**Always use consistent encoding/decoding:**

```swift
// Creating event (Repository)
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601  // ← Important!
let payloadData = try encoder.encode(payload)

// Processing event (OutboxProcessor)
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601  // ← Must match!
let payload = try decoder.decode(YourPayload.self, from: event.payload)
```

### Payload Structure Rules

1. **Match exactly** - Encoder and decoder must use same structure
2. **Use CodingKeys** - For snake_case ↔ camelCase conversion
3. **Optional consistently** - If optional in encoder, optional in decoder
4. **Date strategy** - Always `.iso8601` unless you have a reason
5. **Test immediately** - Track + process before moving on

---

## Related Documentation

- **Full Guide:** `OUTBOX_PATTERN_IMPLEMENTATION.md`
- **Logging:** `LOGGING_GUIDE.md`
- **Testing:** `VERIFICATION_CHECKLIST.md`
- **Quick Start:** `QUICK_START_LOGS.md`

---

## Summary

**Problem:** Payload decoding failed due to date format mismatch

**Solution:**
1. ✅ Added `.iso8601` encoding in `MoodRepository`
2. ✅ Ensured `.iso8601` decoding in `OutboxProcessorService`
3. ✅ Matched payload structures exactly
4. ✅ Added debug logging for troubleshooting

**Result:** Events now encode/decode successfully and sync to backend

---

**Status:** ✅ Fixed  
**Version:** 1.2.0  
**Last Updated:** 2025-01-15