# Pre-Release Checklist for TestFlight Builds

**Last Updated:** 2025-01-15  
**App:** Lume iOS Wellness App

---

## Overview

Complete this checklist before uploading any build to TestFlight to ensure quality and avoid common issues.

---

## 1. Code Quality ✓

### Compilation
- [ ] Project builds without errors
- [ ] No critical warnings in build log
- [ ] All targets compile successfully
- [ ] Release configuration builds (not just Debug)

### Code Review
- [ ] Recent changes peer reviewed
- [ ] No debug code or test credentials in source
- [ ] No hardcoded API keys or secrets
- [ ] Console logs appropriate for production
- [ ] No `TODO` or `FIXME` in critical paths

### Testing
- [ ] All features tested on device (not just simulator)
- [ ] Tested on iPhone (various screen sizes if possible)
- [ ] Tested on iPad (if supported)
- [ ] Keyboard interactions work correctly
- [ ] Navigation flows complete properly
- [ ] All buttons/actions respond correctly

---

## 2. Configuration ✓

### App Settings
- [ ] Bundle Identifier matches App Store Connect
- [ ] Version number updated (if needed)
- [ ] Build number incremented from last upload
- [ ] Deployment target set to iOS 17.0
- [ ] Display name is correct: "Lume"

### Backend Configuration
- [ ] `config.plist` points to correct backend
- [ ] Using staging/test backend (not production)
- [ ] Backend is accessible and healthy
- [ ] API keys are valid and not expired
- [ ] WebSocket endpoints configured correctly

### Signing
- [ ] Signing certificates are valid
- [ ] Provisioning profiles not expired
- [ ] Team selected correctly
- [ ] Automatic signing enabled (or manual profiles set)

---

## 3. Features & Functionality ✓

### Authentication
- [ ] Registration works with valid data
- [ ] Login works with test accounts
- [ ] Logout clears session properly
- [ ] Token refresh works correctly
- [ ] Error messages are user-friendly

### Core Features
- [ ] Mood tracking creates entries
- [ ] Journal entries save and sync
- [ ] Goals can be created and updated
- [ ] AI chat sends and receives messages
- [ ] Profile updates save correctly

### Chat Features
- [ ] FAB creates and opens new chat
- [ ] Empty state shows quick action buttons
- [ ] Quick actions send messages to AI
- [ ] Keyboard dismisses when tapping outside
- [ ] Goal suggestions card scrolls properly
- [ ] Messages display correctly
- [ ] WebSocket connects successfully

### Navigation
- [ ] All tabs navigate correctly
- [ ] Back navigation works
- [ ] Deep links work (if implemented)
- [ ] Modal dismissal works
- [ ] Tab switching preserves state

### Data Persistence
- [ ] Data saves to SwiftData
- [ ] Data persists after app restart
- [ ] Sync with backend works
- [ ] Offline mode handles gracefully
- [ ] No data loss on app termination

---

## 4. UI/UX ✓

### Visual Design
- [ ] App icon displays correctly
- [ ] Launch screen shows properly
- [ ] Colors match design system
- [ ] Typography is consistent
- [ ] Spacing and padding correct
- [ ] No visual glitches or overlaps

### Animations
- [ ] Transitions are smooth
- [ ] No janky scrolling
- [ ] Loading indicators show appropriately
- [ ] Pull-to-refresh works
- [ ] Animations not too fast/slow

### Accessibility
- [ ] VoiceOver navigation works
- [ ] Dynamic Type supported
- [ ] Color contrast meets standards
- [ ] Tap targets minimum 44pt
- [ ] Focus order is logical

### Edge Cases
- [ ] Empty states display correctly
- [ ] Error states are user-friendly
- [ ] Long text doesn't overflow
- [ ] Small screens (iPhone SE) work
- [ ] Large screens (iPad/Pro Max) work

---

## 5. Performance ✓

### Speed
- [ ] App launches quickly (<3 seconds)
- [ ] Screens load without delay
- [ ] Scrolling is smooth (60fps)
- [ ] Images load efficiently
- [ ] No blocking UI operations

### Memory
- [ ] No obvious memory leaks
- [ ] Background tasks terminate properly
- [ ] Large lists scroll without issues
- [ ] Memory usage reasonable (<200MB)

### Battery
- [ ] No excessive battery drain
- [ ] Background activity minimized
- [ ] Network calls optimized
- [ ] Location services off when not needed

### Network
- [ ] API calls have timeouts
- [ ] Retry logic for failed requests
- [ ] Offline mode works
- [ ] No excessive API calls
- [ ] Large data loads incrementally

---

## 6. Security & Privacy ✓

### Data Protection
- [ ] Passwords never stored in plain text
- [ ] Auth tokens in Keychain (not UserDefaults)
- [ ] Sensitive data encrypted at rest
- [ ] API uses HTTPS only
- [ ] Certificate pinning (if required)

### Privacy
- [ ] Info.plist has all usage descriptions
- [ ] Camera permission text is clear
- [ ] Photo library permission text is clear
- [ ] Permissions requested at appropriate times
- [ ] User can deny permissions without crash

### Export Compliance
- [ ] Know answer to encryption questions
- [ ] If using only HTTPS/TLS: exempt = YES
- [ ] If using custom encryption: documentation ready

---

## 7. App Store Connect ✓

### Metadata Ready
- [ ] App description written
- [ ] Keywords selected
- [ ] Screenshots prepared (all required sizes)
- [ ] Preview video (optional but recommended)
- [ ] Support URL set
- [ ] Privacy policy URL set

### Build Information
- [ ] Release notes written for this build
- [ ] "What to Test" documented
- [ ] Known issues listed
- [ ] Contact email for feedback set

### Categories
- [ ] Primary category: Health & Fitness
- [ ] Secondary category selected (if desired)
- [ ] Age rating appropriate

---

## 8. Testing Plan ✓

### Internal Testing
- [ ] Tester group created
- [ ] Internal testers added
- [ ] Testing instructions prepared
- [ ] Expected timeline communicated

### External Testing
- [ ] External group created (if ready)
- [ ] Build submitted for review (first time)
- [ ] Public link generated (if using)
- [ ] Tester invitations ready to send

### Feedback Collection
- [ ] Feedback email monitored
- [ ] Crash reporting configured
- [ ] Analytics tracking enabled
- [ ] Issue tracking system ready

---

## 9. Documentation ✓

### For Testers
- [ ] Installation instructions written
- [ ] Feature guide prepared
- [ ] Known limitations documented
- [ ] Feedback instructions clear
- [ ] Contact information provided

### For Team
- [ ] Build notes in version control
- [ ] Release tag created (optional)
- [ ] Changes documented
- [ ] Backend changes coordinated
- [ ] Rollback plan exists

---

## 10. Final Checks ✓

### Pre-Upload
- [ ] Clean build folder in Xcode
- [ ] Archive created successfully
- [ ] Archive validated in Organizer
- [ ] No warnings in validation
- [ ] File size reasonable (<100MB)

### Post-Upload
- [ ] Upload completed successfully
- [ ] Build appears in App Store Connect
- [ ] Processing completed (wait for email)
- [ ] Export compliance answered
- [ ] Build assigned to test group

### Communication
- [ ] Team notified of new build
- [ ] Testers notified when ready
- [ ] Support channels monitored
- [ ] Feedback tracking active

---

## Common Issues to Check

### Critical (Must Fix Before Upload)
- [ ] App doesn't crash on launch
- [ ] Authentication flow completes
- [ ] Core features are functional
- [ ] No data loss bugs
- [ ] No security vulnerabilities

### Important (Should Fix)
- [ ] UI glitches or overlaps
- [ ] Slow loading times
- [ ] Confusing error messages
- [ ] Missing feedback to user actions
- [ ] Inconsistent design elements

### Nice to Have (Can Fix Later)
- [ ] Minor visual polish
- [ ] Performance optimizations
- [ ] Additional features
- [ ] Enhanced animations
- [ ] Better empty states

---

## Version-Specific Notes

### Build 1 (v1.0.0) - Initial Release
```
✨ New Features:
- User authentication and profile management
- Mood tracking with emotional check-ins
- Journaling with rich text support
- Goal tracking with AI consulting
- AI chat with quick action buttons
- Interactive empty states

🔧 Focus Areas for Testing:
- Complete user registration flow
- Create mood entry and verify sync
- Write journal entry and verify save
- Create goal and test AI chat
- Test quick action buttons in chat
- Verify keyboard dismiss behavior

📝 Known Issues:
- "Chat About Goal" button temporarily hidden (by design)
- Some quick actions may have limited functionality

🎯 Goals for This Build:
- Validate core user flows
- Test backend integration
- Gather initial UX feedback
- Identify critical bugs
```

---

## Emergency Rollback Plan

If critical issues discovered post-release:

1. **Immediate:**
   - Notify all testers via email
   - Update "Known Issues" in TestFlight
   - Disable problematic features if possible

2. **Short-term:**
   - Create hotfix branch
   - Fix critical issues
   - Test thoroughly
   - Upload new build ASAP

3. **Communication:**
   - Be transparent about issues
   - Set expectations for fix timeline
   - Thank testers for patience

---

## Success Metrics

Track these for each build:

- [ ] Installation rate (invited vs installed)
- [ ] Crash-free rate (target: >99%)
- [ ] Session length (engagement)
- [ ] Feature usage rates
- [ ] Feedback volume and sentiment
- [ ] Time to critical bugs found

---

## Sign-Off

Before uploading, confirm:

- [ ] **Developer:** Code quality verified
- [ ] **QA:** Testing completed
- [ ] **Product:** Features approved
- [ ] **Design:** UI/UX approved
- [ ] **Backend:** Services ready

**Build Number:** _________  
**Version:** _________  
**Release Date:** _________  
**Signed By:** _________

---

## Quick Reference

**Minimum Requirements:**
- ✅ Builds without errors
- ✅ Doesn't crash on launch
- ✅ Auth flow works
- ✅ Core features functional
- ✅ Build number incremented
- ✅ Backend accessible

**Nice to Have:**
- ✨ All edge cases handled
- ✨ Perfect performance
- ✨ Complete documentation
- ✨ 100% test coverage

**Remember:** Beta testing is for finding issues. It's okay if everything isn't perfect—but core flows must work!

---

**Ready to upload? Review this checklist one more time, then proceed to TestFlight! 🚀**