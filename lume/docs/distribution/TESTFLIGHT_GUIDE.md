# TestFlight Distribution Guide for Lume iOS App

**Last Updated:** 2025-01-15  
**App:** Lume iOS Wellness App  
**Platform:** iOS 17.0+

---

## Overview

This guide walks you through distributing the Lume iOS app to testers using TestFlight, Apple's beta testing platform.

---

## Prerequisites

### 1. Apple Developer Account
- **Required:** Paid Apple Developer Program membership ($99/year)
- **Sign up:** https://developer.apple.com/programs/
- **Status check:** https://developer.apple.com/account/

### 2. App Store Connect Access
- Access to App Store Connect (https://appstoreconnect.apple.com)
- Role: Admin, App Manager, or Developer

### 3. Development Environment
- macOS with Xcode 15.0+
- Valid signing certificates
- Provisioning profiles

---

## Step 1: Create App in App Store Connect

### 1.1 Log in to App Store Connect
1. Go to https://appstoreconnect.apple.com
2. Sign in with your Apple ID

### 1.2 Create New App
1. Click **"My Apps"**
2. Click the **"+"** button
3. Select **"New App"**

### 1.3 Fill in App Information
```
Platform: iOS
Name: Lume
Primary Language: English (U.S.)
Bundle ID: [Select from dropdown - must match Xcode]
SKU: lume-ios-wellness (or any unique identifier)
User Access: Full Access
```

### 1.4 Set App Categories
```
Primary Category: Health & Fitness
Secondary Category (optional): Lifestyle
```

---

## Step 2: Configure App in Xcode

### 2.1 Open Project Settings
1. Open `lume.xcodeproj` in Xcode
2. Select the **Lume** target
3. Go to **"Signing & Capabilities"** tab

### 2.2 Configure Signing
```
Automatically manage signing: ✓ (Recommended)
Team: [Select your team]
Bundle Identifier: com.yourcompany.lume (must match App Store Connect)
```

**Manual Signing (Advanced):**
- Uncheck "Automatically manage signing"
- Select appropriate provisioning profiles for Debug and Release

### 2.3 Set App Version and Build Number
Go to **"General"** tab:
```
Version: 1.0.0 (Marketing version)
Build: 1 (Increment for each upload)
```

**Important:** Build number must be unique for each TestFlight upload.

### 2.4 Update App Icons
- Add app icons in `Assets.xcassets/AppIcon`
- Required sizes: 1024x1024 (App Store), plus all device sizes
- Use https://appicon.co to generate all sizes from one image

### 2.5 Configure Build Settings
1. Select target → **Build Settings**
2. Search for "bitcode"
3. Set `Enable Bitcode: NO` (deprecated by Apple)

---

## Step 3: Prepare for Archive

### 3.1 Update Info.plist Permissions
Ensure all required permissions are documented:

```xml
<key>NSCameraUsageDescription</key>
<string>Lume needs camera access to update your profile picture</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Lume needs photo library access to update your profile picture</string>

<!-- Add any other permissions your app uses -->
```

### 3.2 Set Release Build Configuration
1. Select scheme: **Product → Scheme → Edit Scheme**
2. Go to **Archive** section
3. Set **Build Configuration** to **Release**

### 3.3 Clean Build Folder
```
Product → Clean Build Folder (⇧⌘K)
```

---

## Step 4: Create Archive

### 4.1 Select Target Device
- In Xcode toolbar, select: **"Any iOS Device (arm64)"**
- Do NOT select a simulator

### 4.2 Create Archive
1. Go to **Product → Archive** (or ⇧⌘B then ⌥⇧⌘D)
2. Wait for build to complete (may take 5-10 minutes)
3. Xcode Organizer window will open automatically

### 4.3 Verify Archive
In Organizer, check:
- ✓ App name is correct
- ✓ Version and build number are correct
- ✓ Archive date is today
- ✓ No warnings or errors

---

## Step 5: Upload to App Store Connect

### 5.1 Distribute App
1. In Organizer, select the archive
2. Click **"Distribute App"**

### 5.2 Select Distribution Method
- Choose: **"App Store Connect"**
- Click **Next**

### 5.3 Select Destination
- Choose: **"Upload"**
- Click **Next**

### 5.4 App Store Connect Distribution Options
```
✓ Upload your app's symbols (Recommended)
✓ Manage Version and Build Number (Recommended)
```
- Click **Next**

### 5.5 Automatic Signing
- Select: **"Automatically manage signing"**
- Click **Next**

### 5.6 Review Summary
- Review all information
- Click **Upload**

### 5.7 Wait for Upload
- Upload time: 5-15 minutes depending on file size
- You'll see: "Upload Successful" message
- Click **Done**

---

## Step 6: Configure TestFlight in App Store Connect

### 6.1 Wait for Processing
1. Go to App Store Connect → **My Apps** → **Lume**
2. Click **TestFlight** tab
3. Wait for build to process (10-60 minutes)
4. You'll receive email when processing completes

### 6.2 Provide Export Compliance Information
When build finishes processing:
1. Click on the build number
2. You'll see: **"Provide Export Compliance Information"**
3. Answer questions:
   ```
   Does your app use encryption? 
   - If YES: Specify type (most apps use HTTPS only)
   - If NO: Select "No"
   ```
4. For Lume (uses HTTPS for backend API):
   ```
   Q: Is your app exempt from encryption export compliance?
   A: Yes (if only using HTTPS/TLS for API calls)
   ```

### 6.3 Add Test Information
1. Click on build → **Test Information**
2. Fill in required fields:
   ```
   What to Test: Brief description of new features
   Feedback Email: your-email@example.com
   ```

---

## Step 7: Manage Testers

### 7.1 Internal Testing (Apple Team Members)
1. Go to **TestFlight** → **Internal Testing** tab
2. Click **"+"** to create a group
3. Name group (e.g., "Lume Team")
4. Add internal testers by Apple ID email

**Internal Testers:**
- Up to 100 testers
- Must be added in App Store Connect with role
- Instant access (no review required)
- Can test immediately after upload

### 7.2 External Testing (Public Testers)
1. Go to **TestFlight** → **External Testing** tab
2. Click **"+"** to create a group
3. Name group (e.g., "Beta Testers", "Friends & Family")
4. Add build to group
5. Add testers by email

**External Testers:**
- Up to 10,000 testers per app
- Requires App Review (first time only, ~24 hours)
- Can share via public link or email invites

### 7.3 Add Testers by Email
1. Click **"Add Testers"**
2. Enter email addresses (one per line)
3. Click **Add**
4. Testers receive invitation via email

### 7.4 Generate Public Link (Optional)
1. Select external group
2. Toggle **"Enable Public Link"**
3. Copy and share link
4. Anyone with link can join (up to group limit)

---

## Step 8: Testers Install TestFlight

### 8.1 Tester Instructions
Send testers these instructions:

```
📱 How to Install Lume Beta via TestFlight

1. Install TestFlight app from App Store
   https://apps.apple.com/app/testflight/id899247664

2. Open invitation email on your iPhone/iPad
   
3. Tap "View in TestFlight" or "Start Testing"

4. Accept invitation

5. Tap "Install" to download Lume

6. Find app on home screen (may have "Beta" badge)

7. Provide feedback via TestFlight app or email
```

### 8.2 Requirements for Testers
- iOS 17.0 or later
- TestFlight app installed
- Invitation accepted (email or public link)
- ~50MB free space for app

---

## Step 9: Managing Builds & Updates

### 9.1 Upload New Build
When you have updates:
1. **Increment build number** in Xcode (e.g., 1 → 2)
2. Repeat **Step 4** (Create Archive)
3. Repeat **Step 5** (Upload)
4. New build appears in TestFlight after processing

### 9.2 Update Testers
Testers see update notification automatically:
- Red badge on TestFlight app
- Push notification (if enabled)
- In-app "Update Available" message

### 9.3 Build Expiration
- TestFlight builds expire after **90 days**
- Upload new build before expiration
- Testers must update to continue testing

### 9.4 Version Management Best Practices
```
Version Scheme: MAJOR.MINOR.PATCH (Build)

Examples:
- 1.0.0 (1) - Initial TestFlight release
- 1.0.0 (2) - Bug fix, same version
- 1.0.1 (3) - Minor update
- 1.1.0 (4) - New feature
- 2.0.0 (5) - Major release

Always increment build number for each upload!
```

---

## Step 10: Collect Feedback

### 10.1 Built-in Feedback
Testers can provide feedback via:
- Screenshot feedback (shake device → take screenshot)
- TestFlight app feedback section
- Crash reports (automatically collected)

### 10.2 View Feedback in App Store Connect
1. Go to **TestFlight** → **Builds**
2. Select build
3. Click **Crashes** or **Feedback** tabs

### 10.3 Crash Reports
- View crashes in **App Store Connect**
- Download full crash logs
- Symbolicate with dSYM files for readable stack traces

---

## Troubleshooting

### Build Upload Fails

**Problem:** "Archive failed" or upload error

**Solutions:**
- Check bundle ID matches App Store Connect
- Verify signing certificates are valid
- Clean build folder and retry
- Check Developer account status
- Ensure all targets build successfully

### Build Stuck in Processing

**Problem:** Build shows "Processing" for hours

**Solutions:**
- Processing typically takes 10-60 minutes
- If over 2 hours, contact Apple Support
- Check App Store Connect Status page: https://developer.apple.com/system-status/

### Testers Can't Install

**Problem:** "Unable to Install" error

**Solutions:**
- Verify tester's iOS version (must be 17.0+)
- Check device is compatible
- Ensure tester accepted invitation
- Try removing and re-inviting tester
- Check if build expired (>90 days)

### Missing Build

**Problem:** Build doesn't appear in TestFlight

**Solutions:**
- Wait for email confirmation (can take 1 hour)
- Check for processing errors in App Store Connect
- Verify export compliance was answered
- Check Activity tab for status

### Wrong Bundle ID

**Problem:** "Bundle ID doesn't match"

**Solutions:**
1. In Xcode → Target → General
2. Update Bundle Identifier to match App Store Connect
3. Clean build folder
4. Create new archive

---

## Best Practices

### 1. Versioning Strategy
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Increment build number for every upload
- Keep marketing version same for small fixes
- Update version for feature releases

### 2. Release Notes
For each build, provide clear notes:
```
Build 5 (v1.0.1) - January 15, 2025

New Features:
- Interactive empty state in chat
- Quick action buttons for instant guidance

Improvements:
- FAB now opens conversations immediately
- Keyboard dismisses when tapping outside input
- Goal suggestions card scrolls properly into view

Bug Fixes:
- Fixed scroll behavior for "Ready to set goals?" button
```

### 3. Testing Groups
Organize testers into groups:
- **Internal Team** - Core developers, immediate access
- **Alpha** - Close friends/family, weekly updates
- **Beta** - Wider audience, stable builds only
- **Production Preview** - Final testing before App Store

### 4. Communication
- Email testers when new builds are available
- Highlight what to test
- Provide feedback channels
- Set expectations for response time

### 5. Monitoring
- Check crash reports daily
- Review feedback weekly
- Track metrics (installs, sessions, crashes)
- Address critical issues in next build

---

## Automation (Advanced)

### Using Fastlane
Automate TestFlight uploads with Fastlane:

```ruby
# Fastfile
lane :beta do
  increment_build_number(xcodeproj: "lume.xcodeproj")
  build_app(scheme: "Lume")
  upload_to_testflight(
    skip_waiting_for_build_processing: true,
    notify_external_testers: false
  )
end
```

Run: `fastlane beta`

### CI/CD Integration
- GitHub Actions
- GitLab CI
- Bitrise
- CircleCI

See: https://docs.fastlane.tools/getting-started/ios/beta-deployment/

---

## Security Considerations

### 1. API Keys & Secrets
- **NEVER** hardcode API keys in app
- Use `config.plist` for configuration
- Add `config.plist` to `.gitignore`
- Provide separate config for testers if needed

### 2. Backend Environment
- Use separate staging backend for TestFlight
- Don't point testers to production database
- Consider using test data

### 3. Analytics
- Separate TestFlight analytics from production
- Tag TestFlight users differently
- Monitor beta-specific metrics

---

## Quick Reference

### Upload Checklist
- [ ] Build number incremented
- [ ] Version number updated (if needed)
- [ ] All features tested locally
- [ ] Release notes prepared
- [ ] Backend staging environment ready
- [ ] Clean build folder
- [ ] Archive created successfully
- [ ] Upload completed
- [ ] Export compliance answered
- [ ] Test information added
- [ ] Testers notified

### Common Commands
```bash
# Clean build folder
⇧⌘K

# Archive
Product → Archive

# View organizer
Window → Organizer
```

---

## Resources

### Official Documentation
- TestFlight Overview: https://developer.apple.com/testflight/
- App Store Connect Help: https://help.apple.com/app-store-connect/
- TestFlight Beta Testing: https://testflight.apple.com

### Tools
- Fastlane: https://fastlane.tools
- App Icon Generator: https://appicon.co
- Status Page: https://developer.apple.com/system-status/

### Support
- Apple Developer Forums: https://developer.apple.com/forums/
- Developer Support: https://developer.apple.com/support/
- App Review: https://developer.apple.com/app-store/review/

---

## Next Steps

After successful TestFlight testing:
1. Gather feedback and iterate
2. Fix critical bugs
3. Polish features based on feedback
4. Prepare for App Store submission
5. Create App Store listing (screenshots, description, etc.)
6. Submit for App Review
7. Release to public!

See: `docs/distribution/APP_STORE_SUBMISSION.md` (coming soon)

---

## Summary

TestFlight is the standard way to distribute iOS apps for testing. Key points:

✅ **Easy Setup** - Configure once in App Store Connect  
✅ **Fast Distribution** - Testers can install within hours  
✅ **Built-in Feedback** - Crashes and feedback automatically collected  
✅ **Generous Limits** - Up to 10,000 external testers  
✅ **90-Day Testing** - Each build valid for 3 months  
✅ **Free** - Included with Apple Developer Program

Start with internal testing, expand to external testers, gather feedback, iterate, and prepare for App Store release!

Good luck with your TestFlight distribution! 🚀