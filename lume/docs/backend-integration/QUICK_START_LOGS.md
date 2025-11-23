# Quick Start: See Outbox Logs NOW

**Time:** 2 minutes  
**Purpose:** Immediately see what's happening with outbox pattern

---

## 🚀 Fastest Way to See Logs

### Step 1: Run the App (30 seconds)

1. Open `lume.xcodeproj` in Xcode
2. Press **⌘+R** (Run)
3. Press **⌘+⇧+C** (Open Console)

### Step 2: Look for Startup Logs (5 seconds)

You should immediately see:

```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Local Development
🔧 [lumeApp] Backend enabled: false
🔵 [lumeApp] Outbox processing disabled (AppMode: Local Development)
💡 [lumeApp] To enable backend sync: Set AppMode.current = .production in AppMode.swift
```

**What this means:**
- ✅ App is working
- 🔵 Currently in LOCAL mode (no backend sync)
- 💡 To enable sync, switch to production mode

### Step 3: Track a Mood (30 seconds)

1. Navigate to mood tracking
2. Select any mood
3. Save

**You'll see:**
```
✅ [MoodRepository] Saved mood locally: Happy for Jan 15, 2025
🔵 [MoodRepository] Skipping outbox (AppMode: Local Development)
```

**What this means:**
- ✅ Mood saved locally
- 🔵 No outbox event created (because local mode)
- 📱 Data stays on device only

---

## 🎯 That's It!

**You just saw the outbox pattern working in LOCAL mode.**

### What You Confirmed:
- ✅ Logging is working
- ✅ App is running correctly
- ✅ Mood tracking saves locally
- ✅ Outbox pattern is aware of current mode

---

## 🚀 Want to See Backend Sync?

### Enable Production Mode (1 minute)

1. **Stop the app** (⌘+. or stop button)

2. **Open:** `lume/Core/Configuration/AppMode.swift`

3. **Change line 17 from:**
   ```swift
   static var current: AppMode = .local
   ```
   
   **To:**
   ```swift
   static var current: AppMode = .production
   ```

4. **Save file** (⌘+S)

5. **Run app again** (⌘+R)

### New Startup Logs:

```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Production
🔧 [lumeApp] Backend enabled: true
🌐 [lumeApp] Backend URL: https://fit-iq-backend.fly.dev
✅ [lumeApp] Outbox processing started (interval: 30s)
📦 [lumeApp] Outbox will sync mood data to backend automatically
```

**Now you're in PRODUCTION mode!**

### Track Another Mood:

```
✅ [MoodRepository] Saved mood locally: Excited for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: abc-123-def-456
📦 [OutboxRepository] Event created: type='mood.created', id=xyz-789, status=pending
```

**See the difference?**
- ✅ Mood saved locally (same as before)
- 📦 Outbox event CREATED (new!)
- 📦 Event is PENDING (waiting to sync)

### Wait 30 Seconds:

```
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: abc-123-def-456
✅ [OutboxRepository] Event completed: type='mood.created', id=xyz-789
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Backend sync happened!**
- 📦 Processor found pending event
- ✅ Sent to backend successfully
- ✅ Marked as completed
- 📦 Removed from outbox

---

## 🔍 Console Filtering Tips

### See Only Outbox Logs

In Xcode Console, filter by:
- `[lumeApp]` - App lifecycle
- `[MoodRepository]` - Mood operations
- `[OutboxProcessor]` - Sync processing
- `[OutboxRepository]` - Event management
- `[MoodBackendService]` - Backend API calls

### Example Filter

Type in console search: `[Outbox`

Shows only outbox-related logs.

---

## 📊 Log Symbols Quick Reference

| Symbol | Meaning |
|--------|---------|
| 🚀 | App start |
| 📱 | App mode |
| 🔧 | Configuration |
| 🌐 | Backend URL |
| ✅ | Success |
| 📦 | Outbox event |
| 🔵 | Local mode |
| 💡 | Helpful tip |
| ⚠️ | Warning/Retry |
| ❌ | Error |
| 🔄 | Refresh |

---

## ❓ Common Questions

### "I don't see ANY logs"

**Check:**
1. Is Xcode Console open? (⌘+⇧+C)
2. Is "All Output" selected in console dropdown?
3. Is console search filter empty?
4. Try filtering by `[lume` to see all logs

### "I see local mode logs but want production"

**Solution:**
1. Stop app
2. Edit `AppMode.swift` 
3. Change to `.production`
4. Run again

### "Production mode but no auth token"

**You'll see:**
```
⚠️ [OutboxProcessor] No token available, skipping processing
```

**Solution:**
1. Login or register first
2. Token gets stored in keychain
3. Processing resumes automatically

### "Events created but not syncing"

**Possible reasons:**
- No internet connection (will retry automatically)
- Backend is down (will retry with backoff)
- Token expired (will auto-refresh if possible)

**Check logs for specific error message**

---

## 🎉 Success Checklist

After following this guide, you should have:

- [x] Seen startup logs
- [x] Tracked a mood in local mode
- [x] Saw "Skipping outbox" message
- [x] (Optional) Switched to production mode
- [x] (Optional) Saw outbox event created
- [x] (Optional) Saw successful backend sync

---

## 📚 Next Steps

**If logs are working:**
- ✅ Read: `LOGGING_GUIDE.md` - Complete log reference
- ✅ Run: `VERIFICATION_CHECKLIST.md` - Full testing

**If having issues:**
- ⚠️ Read: `LOGGING_GUIDE.md` - Troubleshooting section
- ⚠️ Check: Files added to Xcode project
- ⚠️ Verify: Backend configuration

**To understand system:**
- 📖 Read: `OUTBOX_IMPLEMENTATION_SUMMARY.md` - Quick overview
- 📖 Read: `OUTBOX_PATTERN_IMPLEMENTATION.md` - Full details

---

## 💡 Remember

**Local Mode (Default):**
- 🔵 No outbox events
- 🔵 No backend sync
- ✅ Perfect for development
- ✅ Works offline always

**Production Mode:**
- 📦 Creates outbox events
- 📦 Syncs to backend every 30s
- ✅ Works offline (queues for later)
- ✅ Auto-syncs when back online

---

**Status:** ✅ Ready to See Logs  
**Time Required:** 2 minutes  
**Difficulty:** Beginner  
**Version:** 1.1.0