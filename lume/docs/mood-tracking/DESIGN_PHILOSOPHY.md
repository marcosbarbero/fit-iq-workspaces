# Lume Design Philosophy

**Version:** 2.0.0  
**Last Updated:** 2025-01-15  
**Purpose:** Core design principles and unique identity for Lume wellness app

---

## Our Philosophy: Warmth Over Clinical

Lume is not about tracking metrics—it's about creating a warm, safe space for self-reflection and growth. Every design decision should ask: **"Does this feel cozy and welcoming?"**

### Core Principles

1. **No Pressure, Just Presence**
   - We never guilt users into tracking
   - We celebrate check-ins without demanding streaks
   - Missing a day is okay—life happens

2. **Warm, Not Cold**
   - Use warm gradients and soft colors
   - Avoid stark whites and harsh blacks
   - Every interaction should feel like a gentle embrace

3. **Simple, Not Simplistic**
   - Powerful features hidden behind gentle interfaces
   - Progressive disclosure—show complexity only when needed
   - Three taps maximum to accomplish any task

4. **Human, Not Clinical**
   - Mood isn't a number—it's an experience
   - We use metaphors from nature (sunlight, not scales)
   - Language is conversational and compassionate

---

## The Sunlight Metaphor

Traditional mood trackers use clinical scales (1-10) or sterile emojis. Lume uses **the journey of sunlight** through a day:

- **Dawn** - Just getting started
- **Sunrise** - Things are looking up
- **Noon** - Feeling bright
- **Sunset** - Winding down peacefully
- **Twilight** - Ready for rest

### Why Sunlight?

1. **Universal Experience** - Everyone understands the rhythm of a day
2. **No Judgment** - Twilight isn't "bad"—it's natural and peaceful
3. **Cyclical Nature** - After twilight comes dawn—hope is built in
4. **Visual Beauty** - Creates opportunities for warm, gradient backgrounds
5. **Metaphorical Depth** - "My day is like noon" carries more meaning than "7/10"

---

## Color as Emotion

Every mood in Lume has its own **warm gradient** derived from our brand palette:

```
Dawn:     Soft pink → Lavender (#E8B4A8 → #D8A8C8)
Sunrise:  Warm peach → Coral (#F5C89B → #F2A67C)
Noon:     Bright yellow → Warm sand (#F5E6A8 → #F2C9A7)
Sunset:   Warm rose → Soft purple (#E8C4B8 → #D8B8D8)
Twilight: Lavender → Soft blue (#C8B8E8 → #B8C8E8)
```

**Design Rules:**
- Always use gradients, never flat colors for moods
- Gradients flow from top-left to bottom-right
- Icons use high-contrast colors for accessibility
- Text remains readable against all backgrounds

---

## Interaction Patterns

### Entry Points: Quick & Immersive

Users can interact with Lume in two ways:

1. **Quick Check-In** (3 seconds)
   - Tap a mood button from the main screen
   - Minimal friction, maximum encouragement
   - Perfect for busy moments

2. **Deep Reflection** (2-5 minutes)
   - Full-screen immersive experience
   - Add notes and gratitude
   - Prompted reflection questions
   - Beautiful, calm environment

### Animation Philosophy

- **Gentle, not jarring** - Spring animations with 0.4s response, 0.7-0.8 damping
- **Meaningful, not decorative** - Every animation reinforces the action
- **Respectful of attention** - No infinite loops or distracting motion
- **Responsive feedback** - Immediate visual response to touch

### Text & Typography

- **SF Pro Rounded** for all text (matches iOS design language but softer)
- **Generous line heights** (1.4-1.6) for comfortable reading
- **Never more than 3 levels of hierarchy** on one screen
- **Conversational tone** - "How's your day?" not "Rate your mood"

---

## Avoiding the Mindfulness Trap

While inspired by Apple's Mindfulness app's calm aesthetic, Lume must differentiate:

### What We DON'T Copy

❌ Dark, moody backgrounds  
❌ Pulsing/breathing animations  
❌ Clinical 7-level scales  
❌ Swipe-to-change interactions  
❌ Weather metaphors (storms = bad)  

### What Makes Us Unique

✅ Warm gradients from our brand palette  
✅ Sunlight metaphor (natural cycles)  
✅ 5-level scale (balanced, not overwhelming)  
✅ Tap-to-select interactions (faster)  
✅ Gratitude integration (positive psychology)  
✅ Optional depth (quick or reflective)  

---

## The Gratitude Difference

Lume isn't just mood tracking—it's **emotional nourishment**. Every mood entry can include:

1. **What happened today?**
   - Free-form reflection
   - Contextual prompts based on mood
   - No character limits—write as much as needed

2. **Something you're grateful for**
   - Optional but encouraged
   - Builds positive psychology habits
   - Sparks icon (✨) creates warm association

**Design Intent:** Over time, even on difficult days, users build a record of moments worth celebrating.

---

## Data Visualization (Future)

When we add insights and trends, we must maintain our philosophy:

### Good Examples
- Warm gradient charts showing mood patterns
- Sunrise/sunset markers on timeline
- Celebratory language: "You had 12 bright days this month!"
- Gentle suggestions: "Noon moods often follow mornings with..."

### Bad Examples
- Clinical bar charts with stark colors
- "Your average mood score is 6.3/10"
- Red alerts or warnings
- Gamification badges or streaks

---

## Voice & Tone

### Writing Principles

1. **Second Person, Present Tense**
   - "How's your day?" not "How is the user's day?"
   - "You felt..." not "The user felt..."

2. **Questions, Not Commands**
   - "What happened today?" not "Describe your day"
   - "Something you're grateful for?" not "Add gratitude"

3. **Celebration, Not Criticism**
   - "You checked in 5 times this week!" not "You missed 2 days"
   - "Welcome back!" not "It's been a while"

4. **Natural Rhythm**
   - Read prompts aloud—do they sound human?
   - Vary sentence length for natural flow
   - Use contractions (you're, what's, it's)

### Example Rewrites

❌ **Clinical:** "Rate your emotional state on a scale of 1-7"  
✅ **Lume:** "How's your day feeling?"

❌ **Demanding:** "You haven't tracked in 3 days. Track now."  
✅ **Lume:** "Welcome back! Take a moment to check in?"

❌ **Generic:** "Entry saved successfully"  
✅ **Lume:** "Thanks for checking in ✨"

---

## Technical Excellence Supports Experience

Beautiful design means nothing if the app is slow, buggy, or loses data. Technical quality is a design principle:

- **Instant Feedback** - Save locally first, sync later
- **Offline First** - Full functionality without internet
- **Smooth Animations** - 60fps or don't ship it
- **Accessible** - WCAG AA minimum, AAA preferred
- **Private** - User data stays on device unless explicitly synced

---

## Testing the Design

Before shipping any feature, ask:

1. **Does it feel warm?** (Not clinical or cold)
2. **Is it simple?** (3 taps or less to complete)
3. **Is it human?** (Would you say this to a friend?)
4. **Is it beautiful?** (Does it spark joy?)
5. **Is it respectful?** (No pressure, no guilt)

If you answer "no" to any question, redesign.

---

## Summary

Lume is a **warm companion** for emotional wellness, not a clinical tracking tool. Every pixel, every word, every interaction should feel like coming home to a cozy space where you're safe to be yourself.

**Design Mantra:** *"Gentle, warm, and yours."*

---

## References

- [Copilot Instructions](/.github/copilot-instructions.md) - Technical architecture
- [Brand Guidelines](#) - Color palette and typography (to be created)
- [Component Library](#) - Reusable UI patterns (to be created)