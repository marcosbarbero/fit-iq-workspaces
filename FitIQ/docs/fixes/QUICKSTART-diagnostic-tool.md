# Quick Start: Body Mass Diagnostic Tool

**Priority:** 🔴 URGENT  
**Time Required:** 2 minutes  
**Goal:** Find out why no weight data is showing

---

## 🎯 The Problem

You have weight data in Apple Health, but FitIQ shows **nothing**:
- Current weight: "--"
- All filters empty (7d, 30d, 90d, 1y, All)
- No chart, no historical entries

---

## 🩺 The Solution: Run Diagnostic

### Step 1: Open Body Mass View
1. Launch FitIQ app
2. Navigate to **Body Mass Tracking** screen

### Step 2: Tap Diagnostic Button
- Look for **stethoscope icon** (🩺) in top-right corner
- Tap it once

### Step 3: View Results
- Connect iPhone to Mac with Xcode (OR)
- Use Console app on Mac to view device logs

---

## 📊 What the Diagnostic Shows

The diagnostic checks:
- ✅ Is HealthKit available?
- ✅ Is weight permission granted?
- ✅ Can we fetch weight data?
- ✅ How many weight entries exist?
- ✅ Date range of entries

**Example Output:**
```
============================================================
HEALTHKIT DIAGNOSTIC - START
============================================================
HealthKit Available: ✅ YES
Weight Authorization Status: ❌ DENIED

<-- THIS TELLS YOU THE PROBLEM!
============================================================
```

---

## 🔧 Common Issues & Fixes

### Issue 1: Permission Denied ❌
**You See:** `Weight Authorization Status: ❌ DENIED`

**Fix:**
1. Open iPhone **Settings**
2. Privacy & Security → **Health**
3. Find **FitIQ**
4. Enable **READ** for Weight
5. Restart FitIQ
6. ✅ **FIXED!**

---

### Issue 2: No Data Found ⚠️
**You See:** `Total samples found: 0`

**Fix:**
1. Open **Apple Health** app
2. Browse → Body Measurements → **Weight**
3. Check: Do you actually have weight entries?
4. If NO entries: **Log your weight** in Apple Health
5. Return to FitIQ → Data should appear
6. ✅ **FIXED!**

---

### Issue 3: Fetch Failed ❌
**You See:** `❌ FETCH FAILED! Error: <message>`

**Action:**
1. **Copy the full error message**
2. **Screenshot the diagnostic output**
3. **Report to developers** with:
   - Error message
   - Your iOS version
   - What you see in Apple Health app
4. This is a code bug - needs developer fix

---

## 📋 Quick Checklist

Before reporting a bug, verify:

- [ ] Ran diagnostic tool (tapped stethoscope icon)
- [ ] Checked Apple Health app manually
- [ ] Verified permission in Settings → Privacy → Health
- [ ] Copied diagnostic output
- [ ] Noted what Apple Health app shows

---

## 🚀 Expected Time to Fix

| Issue | Fix Time | Who Fixes |
|-------|----------|-----------|
| Permission denied | **30 seconds** | You (Settings) |
| No data in Apple Health | **1 minute** | You (Log weight) |
| Query bug | **Hours/Days** | Developers |

---

## 📱 How to View Diagnostic Output

### Option A: Xcode (Recommended)
1. Connect iPhone to Mac with cable
2. Open **Xcode**
3. Window → Devices and Simulators
4. Select your iPhone
5. Click "Open Console"
6. Run diagnostic in FitIQ
7. Console shows full output

### Option B: Mac Console App
1. Connect iPhone to Mac
2. Open **Console** app (in Applications/Utilities)
3. Select your iPhone in sidebar
4. Filter for "FitIQ" or "HealthKit"
5. Run diagnostic in FitIQ
6. Look for diagnostic report

### Option C: Device Logs (Advanced)
1. Settings → Privacy → Analytics & Improvements
2. Analytics Data → Find FitIQ crash logs
3. Not recommended for real-time debugging

---

## 💡 Pro Tips

**Tip 1:** Run diagnostic **before** AND **after** making changes
- Shows if your fix worked

**Tip 2:** Keep Xcode console open while testing
- See real-time logs as you switch filters

**Tip 3:** Test immediately after logging weight in Apple Health
- Verify sync is working

---

## 📞 What to Report

If diagnostic shows an error you can't fix:

**Include:**
1. **Full diagnostic output** (copy/paste from console)
2. **Apple Health screenshot** (your weight entries)
3. **Permission screenshot** (Settings → Health → FitIQ)
4. **iOS version** (Settings → General → About)
5. **What you expected** vs **what you see**

**Post to:** GitHub issues, developer Slack, or support channel

---

## ✅ Success Indicators

You'll know it's fixed when:
- Current weight shows a number (not "--")
- Chart displays your weight trend
- Historical entries list shows dates
- Switching filters updates the chart

---

**Last Updated:** 2025-01-27  
**Related Docs:** `URGENT-body-mass-no-data-debug.md`  
**Support:** Run diagnostic first, then ask for help with output