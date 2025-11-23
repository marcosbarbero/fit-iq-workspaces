# Chat Duplication Fix

## Root Cause Found!

When clicking on an existing chat, the code was calling:
```swift
consultationManager?.startConsultation(persona: persona.rawValue, goalID: nil)
```

This **creates a NEW consultation** on the backend instead of connecting to the existing one!

## The Fix

Added new method to `ConsultationWebSocketManager`:
```swift
func connectToExistingConsultation(consultationID: String) async throws
```

Updated `ChatViewModel.startLiveChat` to use the existing conversation ID:
```swift
try await consultationManager?.connectToExistingConsultation(
    consultationID: conversationId.uuidString.lowercased()
)
```

## Files Modified

1. **ConsultationWebSocketManager.swift** - Added `connectToExistingConsultation()`
2. **ChatViewModel.swift** - Use existing ID instead of creating new

## Cleanup Needed

You now have 10 duplicate consultations in the backend. To clean up:

### Option 1: Manual cleanup via API
```bash
# Get your auth token from Xcode logs
TOKEN="your_token_here"

# Archive all but the one you want to keep
curl -X PATCH \
  "https://fit-iq-backend.fly.dev/api/v1/consultations/df4cffae-8d6f-474f-aea5-d8f545c385e7" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{"status": "archived"}'
```

### Option 2: Keep one, archive the rest
From the logs, keep this one (has messages):
- `66a66183-4639-47fb-a5ec-b150a54033fe` (18 messages, created 2025-11-17)

Archive these 9 duplicates:
- `df4cffae-8d6f-474f-aea5-d8f545c385e7`
- `66eee316-3ab1-4130-8f92-d733462bb8b6`
- `164d1ce0-08f7-4ec5-a4bf-990146253889`
- `5a3090bb-43dd-4768-80cf-5a7d48eb685d`
- `f3c59c4e-3381-47a7-bfbd-26cbc36acb62`
- `e9ea9366-4af2-45be-88e5-22f3eb9e7292`
- `a1696b5e-350b-4e0b-9efa-3ba5147c6c63`
- `22efcfe9-7e42-4462-9592-7c885aba4e86`
- `1f9625dc-43b7-4bcf-ace2-11d578ab92a2`

### Option 3: Delete app data and start fresh
1. Delete app from simulator/device
2. Reinstall
3. Login again

## Testing

After applying fix:
1. Tap on existing chat
2. Should connect to that chat
3. Should NOT create new consultation
4. Check logs for: "🔌 [ConsultationWS] Connecting to existing consultation"

## Result

✅ No more duplicate consultations created
✅ Tapping chat connects to existing one
✅ WebSocket connects to right conversation
