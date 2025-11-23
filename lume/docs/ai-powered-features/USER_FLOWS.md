# Lume AI Features - User Flows & Journey Maps

**Version:** 1.0.0  
**Last Updated:** 2025-01-15

---

## Overview

This document maps out the complete user journeys for the three AI features in Lume:
1. Goals Management
2. AI Insights
3. AI Consultant Chat

Each flow shows how users interact with features and how they interconnect.

---

## User Journey Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER ONBOARDS TO LUME                       │
│                     (Authentication Complete)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Main Tabs     │
                    │  Dashboard      │
                    │  Mood           │
                    │  Journal        │
                    │  Goals          │
                    │  Profile        │
                    └─────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
    ┌───────────────┐  ┌────────────┐  ┌──────────────┐
    │   Dashboard   │  │    Mood    │  │    Goals     │
    │   Features    │  │  Tracking  │  │  Management  │
    └───────────────┘  └────────────┘  └──────────────┘
            │                 │                 │
            ▼                 ▼                 ▼
    ┌───────────────┐  ┌────────────┐  ┌──────────────┐
    │ AI Insights   │  │  Journal   │  │  AI Chat     │
    │  (Periodic)   │  │   Entries  │  │ (On-Demand)  │
    └───────────────┘  └────────────┘  └──────────────┘
```

---

## Flow 1: Creating First Goal with AI Help

### Scenario: New user wants to set a wellness goal

```
1. User opens Goals tab
   ├─ Sees empty state: "No goals yet"
   └─ Prominent button: "Create Your First Goal"
        │
        ▼
2. Taps "Create Your First Goal"
   ├─ Opens CreateGoalView
   │
   ├─ Sees form fields:
   │  • Title (empty)
   │  • Description (empty)
   │  • Category (General selected)
   │  • Target Date (optional)
   │
   └─ Sees button: "💬 Get AI Suggestions"
        │
        ▼
3. User taps "Get AI Suggestions"
   ├─ Opens AI Chat with context: goalSetting
   │
   ├─ AI greets: "Hi! I'd love to help you set a wellness goal. 
   │              What area of your life would you like to improve?"
   │
   └─ User types: "I want to be less stressed"
        │
        ▼
4. AI responds with questions
   ├─ "That's a great goal! Stress management is so important.
   │   What activities help you feel calm?"
   │
   └─ User: "Meditation and walking"
        │
        ▼
5. AI suggests specific goals
   ├─ "Based on what you've shared, here are some goals that might work:"
   │
   ├─ [Suggestion Card 1]
   │  • "Meditate 10 minutes daily"
   │  • Category: Mental Health
   │  • Target: 30 days
   │  • [Use This Goal]
   │
   ├─ [Suggestion Card 2]
   │  • "Take 3 mindful walks per week"
   │  • Category: Physical Health
   │  • Target: 4 weeks
   │  • [Use This Goal]
   │
   └─ User taps [Use This Goal] on first suggestion
        │
        ▼
6. Returns to CreateGoalView
   ├─ Form is pre-filled:
   │  • Title: "Meditate 10 minutes daily"
   │  • Description: "Practice daily meditation to reduce stress..."
   │  • Category: Mental Health
   │  • Target Date: 30 days from now
   │
   └─ User can edit or save directly
        │
        ▼
7. User taps "Create Goal"
   ├─ Goal is saved
   ├─ Returns to GoalListView
   │
   └─ Sees new goal card:
        • Title with icon
        • Progress bar (0%)
        • Target date shown
        │
        ▼
8. User is now tracking their first goal!
   └─ Can update progress daily
   └─ Can ask AI for tips anytime
```

---

## Flow 2: Receiving Weekly AI Insight

### Scenario: System generates weekly insight on Sunday evening

```
1. Background Service Runs (Sunday 8pm)
   ├─ InsightGenerationService.handleWeeklyInsight()
   │
   ├─ Checks: Should generate weekly insight?
   │  └─ Last weekly was 7+ days ago → Yes
   │
   └─ Triggers: GenerateAIInsightUseCase.execute(type: .weekly)
        │
        ▼
2. Use Case Builds Context
   ├─ UserContextBuilder gathers:
   │  • Mood entries (last 7 days)
   │  • Journal entries (last 7 days)
   │  • Active goals
   │  • Completed goals
   │
   └─ Creates UserContext object
        │
        ▼
3. AI Service Creates Outbox Event
   ├─ Payload: { type: "weekly", context: {...} }
   ├─ Status: "pending"
   └─ Saves to local database
        │
        ▼
4. Outbox Processor Picks Up Event
   ├─ Sends request to AI API
   │  POST /api/v1/ai/insights
   │  Body: { type, context }
   │
   ├─ AI processes data and generates insight:
   │  • Analyzes mood trends
   │  • Reviews journal themes
   │  • Checks goal progress
   │  • Identifies patterns
   │  • Creates suggestions
   │
   └─ Returns AIInsight object
        │
        ▼
5. Insight Saved Locally
   ├─ InsightRepository.save(insight)
   │
   ├─ Marks outbox event as "completed"
   │
   └─ (Optional) Sends local notification:
        "Your weekly wellness check-in is ready! 🌟"
        │
        ▼
6. User Opens App (Monday morning)
   ├─ Navigates to Dashboard
   │
   ├─ Sees InsightCardView at top:
   │  ┌────────────────────────────┐
   │  │ 💡 Latest Insight          │
   │  │ ┌────────────────────────┐ │
   │  │ │ 🌟 Weekly Check-In     │ │
   │  │ │                        │ │
   │  │ │ You've been showing    │ │
   │  │ │ great consistency!     │ │
   │  │ │ Your mood has been...  │ │
   │  │ │                        │ │
   │  │ │ [Read More →]          │ │
   │  │ └────────────────────────┘ │
   │  └────────────────────────────┘
   │
   └─ User taps [Read More]
        │
        ▼
7. Opens InsightDetailView
   ├─ Full screen view with:
   │  • Title: "Weekly Check-In"
   │  • Date range: "Jan 8-14, 2025"
   │  • Full content with analysis
   │  • Metrics section:
   │    - Mood entries: 6/7 days
   │    - Positive moods: 4
   │    - Journal entries: 5
   │  • Observations paragraph
   │  • Suggestions list
   │
   ├─ Marks insight as "read"
   │
   └─ Sees button: [Ask AI About This]
        │
        ▼
8. User taps [Ask AI About This]
   ├─ Opens ChatView with context
   │  • Context type: insightDiscussion
   │  • Related ID: insight.id
   │
   ├─ AI knows context:
   │  "I noticed you wanted to talk about your weekly check-in.
   │   What would you like to explore?"
   │
   └─ User can ask specific questions about the insight
        │
        ▼
9. User Returns to Dashboard
   └─ Feels motivated and supported
   └─ Continues wellness journey
```

---

## Flow 3: Getting Help with Struggling Goal

### Scenario: User has goal at risk of missing target

```
1. User Opens Goals Tab
   ├─ Sees goal card with warning indicator:
   │  ┌────────────────────────────┐
   │  │ 🧘 Daily Meditation    ⚠️  │
   │  │ Practice 10 min daily      │
   │  │ ██████░░░░░░ 50%          │
   │  │ Overdue by 2 days          │
   │  └────────────────────────────┘
   │
   └─ User taps goal card
        │
        ▼
2. Opens GoalDetailView
   ├─ Shows full details:
   │  • Progress: 50%
   │  • Target: Jan 30 (4 days away)
   │  • Recent activity timeline:
   │    - Jan 14: Meditated 10m ✓
   │    - Jan 13: Meditated 10m ✓
   │    - Jan 12: Missed ✗
   │    - Jan 11: Missed ✗
   │
   ├─ Pattern visible: Struggling on weekends
   │
   └─ Sees button: [💬 Ask AI for tips]
        │
        ▼
3. User taps [Ask AI for tips]
   ├─ Opens ChatView with context:
   │  • Type: goalProgress
   │  • Related ID: goal.id
   │  • Summary: "Meditation goal at 50%, 4 days left"
   │
   └─ AI has full context about the goal
        │
        ▼
4. AI Opens Conversation
   ├─ "I see you're working on your meditation goal! 
   │   You're halfway there with 4 days left.
   │   
   │   I noticed you meditated consistently on weekdays
   │   but missed the weekend. What happened?"
   │
   └─ User: "I sleep in on weekends and forget"
        │
        ▼
5. AI Provides Tailored Advice
   ├─ "That makes total sense! Weekend routines are different.
   │   
   │   Here are some ideas:
   │   
   │   1. Set your meditation cushion out Friday night
   │      as a visual reminder
   │   
   │   2. Try meditating right after breakfast instead
   │      of first thing in the morning
   │   
   │   3. What if you did a shorter 5-minute session
   │      on weekends to keep the streak going?
   │   
   │   Which of these resonates with you?"
   │
   └─ User: "I like the 5-minute weekend idea"
        │
        ▼
6. AI Suggests Goal Adjustment
   ├─ "Great! Would you like me to adjust your goal?
   │   
   │   New plan:
   │   • Weekdays: 10 minutes
   │   • Weekends: 5 minutes
   │   
   │   This keeps consistency without overwhelming you.
   │   
   │   [Update Goal] [Keep As Is]"
   │
   └─ User taps [Update Goal]
        │
        ▼
7. Goal Updated
   ├─ Description now includes weekend adjustment
   ├─ User feels supported, not pressured
   └─ Returns to goal detail view
        │
        ▼
8. Over Next Week
   ├─ User successfully meditates with new plan
   ├─ Progress increases to 75%, 85%, 100%
   └─ Goal is completed!
        │
        ▼
9. Completion Celebration
   ├─ Goal marked complete
   ├─ Special insight generated (milestone type)
   ├─ User feels accomplished
   └─ AI suggests next goal based on success
```

---

## Flow 4: Daily Check-In Pattern

### Scenario: User's typical daily usage

```
Morning (7:00 AM)
│
├─ User opens app
├─ Navigates to Mood tab
├─ Records mood: "Happy" 😊
└─ Adds note: "Slept well, ready for the day"
     │
     ▼
Mid-Morning (10:00 AM)
│
├─ User opens Journal
├─ Writes entry about morning walk
└─ Mentions feeling peaceful
     │
     ▼
Afternoon (2:00 PM)
│
├─ Notification: "How are you feeling?"
├─ Quick mood check: "Content" 😌
└─ No additional notes
     │
     ▼
Evening (8:00 PM)
│
├─ User opens Goals tab
├─ Updates meditation goal: +10% progress
├─ Adds note: "Meditated before dinner"
│
├─ Sees dashboard insight card (if new one generated)
│
└─ Reviews day's entries
     │
     ▼
Night (10:00 PM)
│
├─ User opens Journal
├─ Writes reflection on the day
├─ Tags entry with mood
│
└─ Closes app feeling complete
     │
     ▼
Background (Throughout Day)
│
├─ App syncs data to backend via Outbox
├─ AI processes patterns for insights
├─ Prepares context for next interaction
└─ Schedules next insight generation
```

---

## Flow 5: First-Time AI Chat Experience

### Scenario: User discovers AI consultant feature

```
1. Discovery
   ├─ User sees "Get AI Help" button in Goals tab
   ├─ Curious about AI capabilities
   └─ Taps button
        │
        ▼
2. Introduction Screen (First Time Only)
   ├─ Welcome message:
   │  "Meet Your AI Wellness Consultant 🤖
   │   
   │   I'm here to help you:
   │   • Set meaningful goals
   │   • Stay motivated
   │   • Overcome obstacles
   │   • Celebrate progress
   │   
   │   I have access to your mood and journal
   │   history to give personalized advice.
   │   
   │   Your privacy is protected—I never
   │   share your data with anyone."
   │
   ├─ Buttons:
   │  [Learn More About Privacy]
   │  [Let's Start]
   │
   └─ User taps [Let's Start]
        │
        ▼
3. Quick Actions Screen
   ├─ Shows personalized quick actions:
   │
   │  💪 Help me set a goal
   │  📊 Review my progress this week
   │  💡 Give me a wellness tip
   │  ❓ I have a question
   │  ✍️ Help me reflect on my day
   │
   └─ User taps "💪 Help me set a goal"
        │
        ▼
4. Chat Interface Opens
   ├─ AI responds immediately:
   │  "I'd love to help you set a goal! 🎯
   │   
   │   I noticed you've been tracking your
   │   mood consistently. That's wonderful!
   │   
   │   What area of wellness would you like
   │   to focus on?"
   │
   ├─ Shows category buttons:
   │  • Mental Health
   │  • Physical Health
   │  • Emotional Well-being
   │  • Social Connection
   │  • Or type your own →
   │
   └─ User taps "Mental Health"
        │
        ▼
5. Contextual Conversation
   ├─ AI: "Great choice! I see you've logged
   │      'stressed' moods a few times this week.
   │      
   │      Would you like to work on:
   │      • Stress management
   │      • Better sleep
   │      • Mindfulness practice
   │      • Something else?"
   │
   └─ User: "Stress management"
        │
        ▼
6. Personalized Suggestions
   ├─ AI analyzes user's patterns:
   │  • Stress tends to spike on Wednesdays
   │  • Journal mentions work deadlines
   │  • Moods improve after exercise
   │
   ├─ AI suggests:
   │  "Based on your patterns, I recommend:
   │   
   │   1. 'Weekly Stress Check'
   │      Take 5 minutes every Wednesday
   │      morning to plan your week mindfully
   │   
   │   2. 'Evening Wind-Down Routine'
   │      15-minute routine before bed to
   │      release stress from the day
   │   
   │   Which sounds more helpful?"
   │
   └─ User chooses option 2
        │
        ▼
7. Goal Creation Assistance
   ├─ AI: "Perfect! Let's build this together.
   │      
   │      Your goal: Evening Wind-Down Routine
   │      
   │      What activities help you relax?
   │      (journaling, reading, stretching, etc.)"
   │
   ├─ User: "Reading and journaling"
   │
   ├─ AI: "Love it! Here's your goal:
   │      
   │      Title: Evening Wind-Down
   │      Description: Spend 15 minutes before
   │      bed reading or journaling to release
   │      stress and prepare for rest
   │      
   │      Target: Build this habit over 21 days
   │      
   │      [Create This Goal]"
   │
   └─ User taps [Create This Goal]
        │
        ▼
8. Confirmation & Next Steps
   ├─ Goal is created and appears in Goals tab
   │
   ├─ AI: "Awesome! Your goal is set! 🎉
   │      
   │      I'll check in with you through
   │      weekly insights. Feel free to ask
   │      for tips anytime.
   │      
   │      Would you like to:
   │      • Set another goal
   │      • Get tips for this goal
   │      • End chat for now"
   │
   └─ User: "End chat for now"
        │
        ▼
9. User Returns to Goals Tab
   └─ Sees new goal
   └─ Feels supported and motivated
   └─ Knows AI is available whenever needed
```

---

## Integration Flow: Full Feature Ecosystem

```
┌─────────────────────────────────────────────────────────────┐
│                    USER'S WELLNESS JOURNEY                  │
└─────────────────────────────────────────────────────────────┘

Day 1-7: Onboarding & Exploration
├─ Track mood daily
├─ Write journal entries
├─ Explore app features
└─ Build baseline data
     │
     ▼
Day 8: First AI Insight (Weekly)
├─ Receives first weekly check-in
├─ Learns about AI capabilities
├─ Sees personalized observations
└─ Gets motivated to set goals
     │
     ▼
Day 9: Create First Goal
├─ Opens Goals tab
├─ Uses AI chat for guidance
├─ Creates meaningful goal
└─ Starts tracking progress
     │
     ▼
Day 10-20: Active Tracking
├─ Updates mood regularly
├─ Journals about experiences
├─ Updates goal progress
├─ Receives daily insights (if enabled)
└─ Uses AI chat for questions/tips
     │
     ▼
Day 21: Goal Milestone
├─ Completes first goal (or makes significant progress)
├─ Receives milestone insight
├─ AI celebrates achievement
└─ Suggests next goal based on success
     │
     ▼
Day 22-30: Momentum Building
├─ Sets additional goals
├─ Sees patterns in mood/journal
├─ Weekly insights track improvement
├─ Chat becomes trusted resource
└─ Forms sustainable habits
     │
     ▼
Day 31+: Long-Term Engagement
├─ Goals become part of routine
├─ Insights provide ongoing guidance
├─ Chat helps overcome obstacles
├─ User sees clear wellness progress
└─ Recommends app to friends
```

---

## Cross-Feature Interactions

### Mood → Insights → Goals → Chat

```
User tracks "stressed" mood multiple times
     │
     ▼
Weekly insight identifies stress pattern
     │
     ▼
Insight suggests stress management goal
     │
     ▼
User taps to create goal
     │
     ▼
Chat helps customize goal for user's lifestyle
     │
     ▼
Goal is created and tracked
     │
     ▼
Future insights monitor stress levels and goal progress
     │
     ▼
User sees improvement, feels supported
```

### Journal → Insights → Chat → Goals

```
User journals about wanting better sleep
     │
     ▼
Insight picks up sleep theme from journal
     │
     ▼
Insight suggests: "Talk to AI about sleep"
     │
     ▼
User opens chat from insight
     │
     ▼
Chat discusses sleep challenges
     │
     ▼
Chat suggests specific sleep hygiene goal
     │
     ▼
Goal created and linked to journal theme
     │
     ▼
User tracks progress with AI support
```

---

## Error & Edge Case Flows

### When AI is Unavailable

```
User requests AI assistance
     │
     ▼
App creates Outbox event
     │
     ▼
Network is offline or AI service down
     │
     ▼
User sees: "Your request is queued. 
           We'll process it when connection
           is restored."
     │
     ▼
Outbox processor retries automatically
     │
     ▼
When online, request is processed
     │
     ▼
User gets notification: "Your AI response is ready!"
     │
     ▼
User returns to see result
```

### When User Has No Data Yet

```
New user tries to get AI insight
     │
     ▼
System checks: sufficient data?
     │
     ├─ Less than 3 mood entries
     └─ Less than 2 journal entries
     │
     ▼
AI responds gracefully:
"I'd love to give you insights, but I need
 a bit more information first.
 
 Keep tracking your mood and journaling,
 and I'll have personalized insights for
 you in a few days! 🌱"
     │
     ▼
User understands and continues tracking
```

---

## Success Metrics per Flow

### Goal Creation Flow
- Time to first goal: Target < 5 minutes
- Completion rate: Target > 70%
- AI assistance usage: Track adoption rate
- Goal quality: User satisfaction rating

### Insight Generation Flow
- Generation success rate: Target > 95%
- Read rate: Target > 60%
- Action taken rate: Target > 30%
- User feedback score: Target > 4/5

### Chat Interaction Flow
- Response time: Target < 3 seconds
- Conversation completion: Track drop-off
- User satisfaction: Target > 4.5/5
- Feature discovery: Track unique users

---

## Conclusion

These user flows demonstrate how the three AI features work together to create a cohesive, supportive wellness experience. Each feature enhances the others:

- **Goals** provide structure and tangible progress
- **Insights** offer reflection and awareness
- **Chat** provides personalized guidance and support

The flows are designed to feel natural, warm, and non-judgmental—always supporting the user's wellness journey without pressure or criticism.