# Quick Reference - Validation Tasks

**Date:** January 27, 2025  
**Status:** 🔍 Needs Validation  
**Full Doc:** `HANDOFF_NEEDS_VALIDATION_2025_01_27.md`

---

## 🚨 MOST CRITICAL: Biological Sex Sync

**Problem:** Biological sex shows in UI but appears as `nil` in ProfileSyncService

**Action Required:**
1. Open Edit Profile sheet
2. Capture complete console logs
3. Look for: `SyncBiologicalSexFromHealthKitUseCase: ===== HEALTHKIT SYNC START =====`
4. Identify which pattern occurs:
   - ✅ Success: "Successfully synced to backend"
   - ⚠️ No Change: "No change detected, skipping sync"
   - ❌ Not Found: "Profile not found"
   - ⚠️ Backend Failed: "Backend sync failed"

**Expected Logs (Success):**
```
ProfileViewModel: ===== SYNC BIOLOGICAL SEX FROM HEALTHKIT =====
SyncBiologicalSexFromHealthKitUseCase: ===== HEALTHKIT SYNC START =====
SyncBiologicalSexFromHealthKitUseCase: User ID: [UUID]
SyncBiologicalSexFromHealthKitUseCase: HealthKit biological sex: male
SyncBiologicalSexFromHealthKitUseCase: Current local value: nil
SyncBiologicalSexFromHealthKitUseCase: 🔄 Change detected: 'nil' → 'male'
SyncBiologicalSexFromHealthKitUseCase: ✅ Saved to local storage
SyncBiologicalSexFromHealthKitUseCase: 📡 Syncing to backend...
SyncBiologicalSexFromHealthKitUseCase: ✅ Successfully synced to backend
```

---

## ✅ Quick Test Checklist

### Test 1: New User Registration (2 min)
- [ ] Register with DOB: July 20, 1983
- [ ] Verify displays: July 20, 1983 (not July 19)

### Test 2: Duplicate Cleanup (1 min)
- [ ] Launch app
- [ ] Check logs: "Deleted X duplicate profile(s)"

### Test 3: Height Auto-Save (3 min)
- [ ] Open Edit Profile
- [ ] Check logs: "Auto-saving height to storage..."
- [ ] Verify height pre-filled from HealthKit

### Test 4: Biological Sex Sync (5 min) ⭐ CRITICAL
- [ ] Open Edit Profile
- [ ] **Capture all logs**
- [ ] Identify log pattern
- [ ] Share logs with team

### Test 5: Profile Decode (2 min)
- [ ] Update profile (name/bio)
- [ ] Check logs: "Successfully decoded wrapped profile response"
- [ ] No "Failed to decode" warnings

---

## 📊 What's Been Fixed (Needs Validation)

| Fix | What Changed | Test |
|-----|--------------|------|
| **DI Wiring** | All use cases accessible | App launches OK |
| **Date Fix** | Uses local timezone | New user DOB correct |
| **Duplicate Cleanup** | Auto-removes dupes | Check logs on launch |
| **Height Auto-Save** | Auto-saves from HealthKit | Pre-filled in UI |
| **Decode Fix** | Handles nested response | No decode warnings |

---

## 🐛 Known Issues

| Issue | Status | Action |
|-------|--------|--------|
| **Biological Sex nil** | 🔍 Investigating | Capture logs |
| **Existing user DOB wrong** | 🔍 Known | Need migration |

---

## 🎯 Next Steps Priority

1. **🔴 IMMEDIATE:** Test biological sex sync with logs
2. **🔴 HIGH:** Validate all fixes with real testing
3. **🟡 MEDIUM:** Fix biological sex issue (based on logs)
4. **🟡 MEDIUM:** Plan DOB migration for existing users
5. **🟢 LOW:** Implement Settings split from Profile

---

## 📱 UX Improvement Proposal

**Move from Profile to Settings:**
- Language (currently in Edit Profile)
- Unit System (currently in Edit Profile)

**Keep in Profile:**
- Name, Bio, Date of Birth
- Height, Biological Sex
- Health metrics

**Benefits:**
- Clearer separation: Profile = identity, Settings = app config
- Follows iOS conventions
- Room to add more settings later

**Estimated:** 4-5 days implementation

---

## 🔧 Quick Commands

**Build:**
```bash
cd FitIQ
xcodebuild -scheme FitIQ -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Clean Build:**
```bash
xcodebuild clean
```

**View Logs:**
```bash
# In Xcode: Product → Scheme → Edit Scheme → Run → Arguments
# Add environment variable: OS_ACTIVITY_MODE = disable
# Then check Console.app for device logs
```

---

## 📞 Need Help?

**Full Documentation:**
- `HANDOFF_NEEDS_VALIDATION_2025_01_27.md` - Complete details
- `SESSION_COMPLETE_2025_01_27_PART2.md` - Session summary
- `docs/fixes/` - Individual fix documentation

**Key Files:**
- `AppDependencies.swift` - All dependency wiring
- `ProfileViewModel.swift` - Profile management logic
- `SyncBiologicalSexFromHealthKitUseCase.swift` - Biological sex sync

**Backend:**
- Swagger: https://fit-iq-backend.fly.dev/swagger/index.html
- API Spec: `docs/api-spec.yaml`

---

**Priority:** Test biological sex sync with detailed logs ASAP!  
**Status:** All builds passing ✅  
**Blockers:** Need real device testing with HealthKit data