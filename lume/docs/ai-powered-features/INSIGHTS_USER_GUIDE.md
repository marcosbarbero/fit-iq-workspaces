# AI Insights User Guide

**Last Updated:** 2025-01-28  
**Feature Status:** ✅ Ready to Use

---

## What You'll See in the Dashboard

### Initial State: No Insights Yet

When you first open the dashboard, you'll see the **AI Insights** section with:

```
✨ AI Insights

┌─────────────────────────────────────┐
│          ✨                         │
│   Your AI Insights Await            │
│                                     │
│ Keep tracking your mood and journal │
│ entries. We'll generate personalized│
│ insights based on your patterns.    │
│                                     │
│     [Get AI Insights]               │
└─────────────────────────────────────┘
```

**What to do:**
1. Click the **"Get AI Insights"** button
2. Wait a moment while the app fetches insights from the backend
3. The latest insight will appear in the card

---

## After Getting Insights

Once you have insights, you'll see:

```
✨ AI Insights  [3]  🔄  View All

┌─────────────────────────────────────┐
│ Weekly Insight        [NEW]  ⭐ 📦  │
│ Your Week in Review                 │
│                                     │
│ This week, you've shown remarkable  │
│ consistency in tracking your mood...│
│                                     │
│ 📊 7 moods · 5 journals · 3 goals  │
│ 📅 Jan 21 - Jan 28                 │
└─────────────────────────────────────┘
```

**UI Elements:**

1. **Unread Badge** `[3]` - Shows number of unread insights
2. **Refresh Button** 🔄 - Fetch latest insights from backend
3. **View All** - Opens full insights list
4. **Insight Card** - Shows latest insight preview
5. **Status Icons**:
   - ⭐ Favorite (tap to toggle)
   - 📦 Archive (tap to archive)
   - [NEW] Unread badge

---

## Interacting with Insights

### Viewing Details

**Tap on any insight card** to see the full detail view:

```
┌─────────────────────────────────────┐
│ ← Back              ⭐ 📦 ⋯         │
│                                     │
│ Weekly Insight                      │
│ Your Week in Review                 │
│ Created: January 28, 2025           │
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ 📝 Summary                          │
│ A positive week with consistent     │
│ mood tracking and regular journaling│
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ Full insight content here with      │
│ detailed analysis and patterns...   │
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ 💡 Suggestions                      │
│ • Continue your daily check-ins     │
│ • Consider setting a new goal       │
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ 📊 Data Summary                     │
│ Period: Jan 21 - Jan 28 (7 days)   │
│ 7 mood entries                      │
│ 5 journal entries                   │
│ 3 active goals                      │
└─────────────────────────────────────┘
```

### Actions Available

1. **Mark as Read** - Automatically when you open it
2. **Favorite** ⭐ - Save important insights
3. **Archive** 📦 - Hide from main list
4. **Share** - Share via system share sheet
5. **Delete** ⋯ - Remove permanently

---

## Insight Types You'll See

### 1. Daily Insights ☀️
- **Frequency:** Generated daily
- **Content:** Daily wellness snapshot
- **Example:** "Today's mood patterns show higher energy in mornings"

### 2. Weekly Insights 📅
- **Frequency:** Generated weekly (Mondays)
- **Content:** Week in review with patterns
- **Example:** "Your Week in Review - Consistent tracking this week"

### 3. Monthly Insights 📆
- **Frequency:** Generated monthly (1st of month)
- **Content:** Monthly wellness review
- **Example:** "January Wellness Report - 28 days of growth"

### 4. Milestone Insights ⭐
- **Frequency:** Triggered by achievements
- **Content:** Celebrate your progress
- **Example:** "Milestone Reached! 7-day tracking streak"

---

## How Insights Are Generated

### Backend Generation (Automatic)

The backend automatically generates insights based on:

1. **Your Activity:**
   - Mood check-ins
   - Journal entries
   - Goal progress
   - Tracking consistency

2. **Time-Based Triggers:**
   - Daily (each morning)
   - Weekly (Monday mornings)
   - Monthly (1st of month)
   - Milestones (when achieved)

3. **AI Analysis:**
   - Pattern recognition
   - Trend analysis
   - Personalized recommendations
   - Context-aware suggestions

### Client-Side Fetching

When you click **"Get AI Insights"** or **refresh** 🔄:

1. App connects to backend
2. Fetches latest insights
3. Syncs to local database
4. Updates UI with new insights

**Note:** You're not generating insights yourself - you're fetching insights that the backend has already created for you based on your data.

---

## Managing Your Insights

### View All Insights

Click **"View All"** to see the full list with filtering:

```
┌─────────────────────────────────────┐
│ AI Insights              ⚙️         │
│                                     │
│ [All] [Unread 3] [Favorites] [⋮]   │
│                                     │
│ ┌─────────────────────────────┐   │
│ │ Weekly · Your Week in Review│   │
│ │ This week you've shown...   │   │
│ └─────────────────────────────┘   │
│                                     │
│ ┌─────────────────────────────┐   │
│ │ Daily · Mood Pattern        │   │
│ │ Higher energy in mornings...│   │
│ └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### Filter Options

Tap the filter icon ⚙️ to show:

- **Type:** Daily, Weekly, Monthly, Milestone
- **Status:** Unread only, Favorites only
- **Archive:** Show/hide archived

### Quick Actions (Swipe)

Swipe left on any insight card:
- ⭐ **Favorite** - Mark as important
- 📦 **Archive** - Hide from list
- 🗑️ **Delete** - Remove permanently

---

## Troubleshooting

### "No insights yet"

**Why:** The backend hasn't generated any insights for you yet.

**Solutions:**
1. Make sure you've tracked moods and/or written journal entries
2. Wait for the backend to generate insights (usually within 24 hours)
3. Click **"Get AI Insights"** to fetch latest from backend
4. Check your internet connection

### Refresh button spinning

**Why:** Fetching data from backend.

**Wait:** Usually takes 1-3 seconds. If it hangs:
1. Check internet connection
2. Pull down to refresh the dashboard
3. Close and reopen the app

### Empty after clicking "Get AI Insights"

**Why:** Backend hasn't generated insights yet OR you need more data.

**Solutions:**
1. **Track more data:** Log at least 3-5 moods and/or journal entries
2. **Wait 24 hours:** Backend generates insights periodically
3. **Set goals:** Having active goals improves insight quality
4. **Be consistent:** Daily tracking helps AI find patterns

---

## Best Practices

### Get Better Insights

1. **Track Regularly**
   - Daily mood check-ins
   - Regular journaling
   - Update goal progress

2. **Be Detailed**
   - Add notes to mood entries
   - Write meaningful journal entries
   - Set specific, measurable goals

3. **Stay Consistent**
   - Track at similar times each day
   - Don't skip days
   - Review insights weekly

### Organize Your Insights

1. **Use Favorites** ⭐
   - Mark insights that resonate
   - Quick access to important patterns
   - Build your personal growth library

2. **Archive Old Ones** 📦
   - Keep your list clean
   - Archive after acting on suggestions
   - Can always view archived later

3. **Act on Suggestions** 💡
   - Insights include actionable tips
   - Try implementing 1-2 suggestions
   - Track if they help

---

## Privacy & Data

### What Data Is Used?

- Your mood check-ins (dates, labels, notes)
- Journal entries (dates, content, word counts)
- Goal information (titles, progress, status)
- Usage patterns (tracking frequency, consistency)

### Where Is Processing Done?

- **Backend Server:** All AI analysis happens on secure backend
- **Local Storage:** Insights are cached on your device for offline access
- **Sync:** App syncs with backend when online

### Your Control

- ✅ Delete any insight anytime
- ✅ Archive insights you don't want to see
- ✅ Your data is only used for YOUR insights
- ✅ No sharing with other users
- ✅ Standard data privacy protections

---

## Coming Soon

Future enhancements planned:

- 🔔 **Notifications:** Get alerted when new insights arrive
- 💬 **Chat About Insights:** Discuss insights with AI
- 📊 **Trend Charts:** Visual representation of patterns
- 🎯 **Action Plans:** Convert insights into actionable goals
- 🔗 **Goal Integration:** Link insights to specific goals

---

## Need Help?

### In-App Support
- Tap the help icon in any insight view
- Access the help center from settings

### Common Questions

**Q: How often are insights generated?**  
A: Backend generates them automatically (daily, weekly, monthly, and on milestones).

**Q: Can I request a specific insight?**  
A: Not yet, but the refresh button fetches any new ones available.

**Q: Why don't I have insights yet?**  
A: You need at least 3-5 data points (moods/journals) and up to 24 hours for backend generation.

**Q: Can insights be wrong?**  
A: Insights are AI-generated suggestions based on patterns. Use your judgment and what feels right for you.

---

## Quick Reference

| Action | How To |
|--------|--------|
| Get first insights | Click "Get AI Insights" button |
| Refresh insights | Tap 🔄 refresh button |
| View details | Tap any insight card |
| Mark favorite | Tap ⭐ star icon |
| Archive | Tap 📦 archive icon |
| Delete | Swipe left → Delete OR tap ⋯ menu |
| Filter list | Tap ⚙️ filter icon |
| View all | Tap "View All" link |

---

**Enjoy your personalized AI insights! They're here to support your wellness journey.** ✨