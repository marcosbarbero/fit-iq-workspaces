# TestFlight Quick Start Checklist

**For:** Lume iOS App  
**Time Required:** ~30 minutes (first time)

---

## Prerequisites ✓

- [ ] Apple Developer Program account ($99/year)
- [ ] macOS with Xcode 15.0+
- [ ] App Store Connect access
- [ ] Lume project opens without errors

---

## One-Time Setup (First Upload Only)

### 1. Create App in App Store Connect
- [ ] Log in to https://appstoreconnect.apple.com
- [ ] Click "My Apps" → "+" → "New App"
- [ ] Fill in app info:
  - Name: **Lume**
  - Bundle ID: **[Select from dropdown]**
  - SKU: **lume-ios-wellness**
  - Primary Language: **English (U.S.)**
- [ ] Click "Create"

### 2. Configure Xcode
- [ ] Open project in Xcode
- [ ] Select Lume target
- [ ] Go to "Signing & Capabilities"
- [ ] Enable "Automatically manage signing"
- [ ] Select your Team
- [ ] Verify Bundle Identifier matches App Store Connect

### 3. Set App Icon
- [ ] Add 1024x1024 icon to Assets.xcassets
- [ ] Add all required icon sizes

---

## Every Upload (Repeat for Each Version)

### Step 1: Prepare Build
```
Version: 1.0.0  (Update for major releases)
Build: 1        (MUST increment each upload)
```

- [ ] Update build number in Xcode (General tab)
- [ ] Clean build folder: `⇧⌘K`

### Step 2: Create Archive
- [ ] Select "Any iOS Device (arm64)" in toolbar
- [ ] Product → Archive
- [ ] Wait for build to complete
- [ ] Verify in Organizer window

### Step 3: Upload to TestFlight
- [ ] Click "Distribute App"
- [ ] Select "App Store Connect" → Next
- [ ] Select "Upload" → Next
- [ ] Check both options:
  - ✓ Upload symbols
  - ✓ Manage version/build number
- [ ] Click Next → Upload
- [ ] Wait for success message (5-15 min)

### Step 4: Configure in App Store Connect
- [ ] Go to App Store Connect → TestFlight
- [ ] Wait for processing (10-60 min, check email)
- [ ] Answer export compliance:
  - "Does your app use encryption?" → **Yes (HTTPS only)**
  - "Is it exempt?" → **Yes**
- [ ] Add "What to Test" notes

### Step 5: Add Testers
**Internal (instant access):**
- [ ] TestFlight → Internal Testing
- [ ] Create group → Add testers by email

**External (24hr review first time):**
- [ ] TestFlight → External Testing  
- [ ] Create group → Add build
- [ ] Add testers by email OR generate public link

---

## Send to Testers

Copy/paste this message:

```
🎉 Lume Beta is Ready!

1. Install TestFlight: https://apps.apple.com/app/testflight/id899247664

2. Check your email for invitation

3. Tap "View in TestFlight" → Accept → Install

4. Launch Lume (may have "Beta" badge)

5. Feedback: [your-email@example.com]

Requirements: iOS 17.0+
```

---

## Quick Troubleshooting

**Archive fails?**
→ Clean build folder, check signing, verify bundle ID

**Upload fails?**
→ Check internet, verify certificates, try again

**Build stuck processing?**
→ Wait up to 2 hours, check status page

**Testers can't install?**
→ Verify iOS 17.0+, check invitation accepted

---

## Version Numbers Explained

```
1.0.0 (5)
 │ │ │  └─ Build number (increment EVERY upload)
 │ │ └──── Patch (bug fixes)
 │ └────── Minor (new features)
 └──────── Major (big changes)
```

**Examples:**
- `1.0.0 (1)` - First TestFlight
- `1.0.0 (2)` - Quick bug fix, same version
- `1.0.1 (3)` - Small update
- `1.1.0 (4)` - New feature
- `2.0.0 (5)` - Major redesign

---

## Build Notes Template

```
Build X (vX.X.X) - January 15, 2025

✨ New Features:
- [Feature description]

🔧 Improvements:
- [Improvement description]

🐛 Bug Fixes:
- [Fix description]

📝 Known Issues:
- [Any known issues]

🧪 Please Test:
- [Specific things to test]
```

---

## Tips

💡 **Increment build number** - Most common mistake!  
💡 **Test locally first** - Don't waste upload time  
💡 **Keep notes** - Track what changed  
💡 **Start small** - Few internal testers first  
💡 **Respond to feedback** - Build trust with testers

---

## Timeline

| Step | Duration |
|------|----------|
| Archive & Upload | 15-20 min |
| Processing | 30-60 min |
| External Review (first time) | 24 hours |
| Tester Install | Instant |

**Total first-time:** ~1-2 days  
**Total subsequent:** ~1 hour

---

## Next Build Checklist

- [ ] Increment build number
- [ ] Test locally
- [ ] Update release notes
- [ ] Clean & Archive
- [ ] Upload
- [ ] Wait for processing
- [ ] Notify testers

---

## Resources

📖 Full Guide: `docs/distribution/TESTFLIGHT_GUIDE.md`  
🌐 App Store Connect: https://appstoreconnect.apple.com  
📱 TestFlight: https://testflight.apple.com  
📚 Apple Docs: https://developer.apple.com/testflight/

---

**Ready? Start with Step 1 above! 🚀**