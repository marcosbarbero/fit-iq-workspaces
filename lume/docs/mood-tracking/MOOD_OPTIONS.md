# Mood Tracking Options

**Version:** 2.0.0  
**Last Updated:** 2025-01-15  
**Feature:** Mood Tracking

---

## Overview

Lume offers **10 mood options** that provide comprehensive emotional coverage while remaining approachable and non-overwhelming. Each mood is carefully designed to feel warm, calm, and non-judgmental.

---

## Mood Options

### 1. Peaceful 🌙
- **API Value:** `peaceful`
- **Description:** "Tranquil and serene"
- **Icon:** `moon.stars.fill`
- **Color:** `#E8E3F0` (Very light lavender)
- **Score:** 3 (Neutral-positive)
- **Prompt:** "What brought you this tranquility?"
- **Energy Level:** Low
- **Valence:** Positive

### 2. Calm 🍃
- **API Value:** `calm`
- **Description:** "Relaxed and steady"
- **Icon:** `leaf.fill`
- **Color:** `#D8C8EA` (Soft lavender)
- **Score:** 3 (Neutral-positive)
- **Prompt:** "What helped you feel steady today?"
- **Energy Level:** Low-Medium
- **Valence:** Positive

### 3. Content ✓
- **API Value:** `content`
- **Description:** "Satisfied and at ease"
- **Icon:** `checkmark.circle.fill`
- **Color:** `#B8D4E8` (Light sky blue)
- **Score:** 3 (Neutral-positive)
- **Prompt:** "What are you satisfied with?"
- **Energy Level:** Medium
- **Valence:** Positive

### 4. Happy ☀️
- **API Value:** `happy`
- **Description:** "Joyful and positive"
- **Icon:** `sun.max.fill`
- **Color:** `#F5DFA8` (Bright yellow)
- **Score:** 4 (Positive)
- **Prompt:** "What brought you joy today?"
- **Energy Level:** Medium-High
- **Valence:** Very Positive

### 5. Excited ✨
- **API Value:** `excited`
- **Description:** "Enthusiastic and eager"
- **Icon:** `sparkles`
- **Color:** `#FFD4E5` (Light pink)
- **Score:** 5 (Very positive)
- **Prompt:** "What are you looking forward to?"
- **Energy Level:** High
- **Valence:** Very Positive

### 6. Energetic ⚡
- **API Value:** `energetic`
- **Description:** "Motivated and active"
- **Icon:** `bolt.fill`
- **Color:** `#C5E8C0` (Light mint green)
- **Score:** 4 (Positive)
- **Prompt:** "How will you use this energy?"
- **Energy Level:** High
- **Valence:** Positive

### 7. Tired 😴
- **API Value:** `tired`
- **Description:** "Low energy and weary"
- **Icon:** `bed.double.fill`
- **Color:** `#D4D9E8` (Light blue-gray)
- **Score:** 2 (Low-neutral)
- **Prompt:** "What do you need right now?"
- **Energy Level:** Very Low
- **Valence:** Neutral-Negative

### 8. Sad 💧
- **API Value:** `sad`
- **Description:** "Down or melancholy"
- **Icon:** `cloud.rain.fill`
- **Color:** `#C8D4E8` (Light blue)
- **Score:** 1 (Negative)
- **Prompt:** "What's weighing on your heart?"
- **Energy Level:** Low
- **Valence:** Negative

### 9. Anxious 🌬️
- **API Value:** `anxious`
- **Description:** "Worried or uneasy"
- **Icon:** `wind`
- **Color:** `#E8D9C8` (Light tan)
- **Score:** 1 (Negative)
- **Prompt:** "What's on your mind?"
- **Energy Level:** Medium-High (restless)
- **Valence:** Negative

### 10. Stressed ☁️
- **API Value:** `stressed`
- **Description:** "Overwhelmed or tense"
- **Icon:** `cloud.fill`
- **Color:** `#F0B8A4` (Soft coral)
- **Score:** 1 (Negative)
- **Prompt:** "What can you let go of?"
- **Energy Level:** High (tense)
- **Valence:** Negative

---

## Design Rationale

### Emotional Coverage

The 10 moods cover the complete emotional spectrum:

**Positive States (6):**
- Low energy: Peaceful, Calm
- Medium energy: Content, Happy
- High energy: Excited, Energetic

**Neutral/Negative States (4):**
- Low energy: Tired, Sad
- High energy: Anxious, Stressed

### Color Strategy

All colors are **very light pastels** to maintain Lume's calm aesthetic:

- **Lavender/Purple tones** - Peaceful, Calm (calming states)
- **Blue tones** - Content (stable, reliable)
- **Yellow tones** - Happy (bright, cheerful)
- **Pink/Coral tones** - Excited, Stressed (high energy)
- **Green tones** - Energetic (active, growing)
- **Gray/Tan tones** - Tired, Anxious (neutral, subdued)

All colors use **light tints** (0.2 blend with white) to ensure backgrounds stay light and calming.

### Icon Selection

Icons use **SF Symbols** and follow these principles:

- **Nature metaphors** - Moon/stars, leaf, sun, cloud, wind
- **Energy indicators** - Bolt, sparkles
- **State symbols** - Checkmark, bed
- **Avoid** - Emojis, faces, clinical symbols

### Reflection Prompts

Each prompt is:
- **Open-ended** - Encourages reflection
- **Non-judgmental** - No "why" questions
- **Action-oriented** - Forward-looking where appropriate
- **Supportive** - Gentle and caring tone

---

## API Mapping

### Supported by API (10/15)

Lume currently supports these moods from the API's 15 options:

✅ happy  
✅ sad  
✅ calm  
✅ energetic  
✅ stressed  
✅ content  
✅ peaceful  
✅ excited  
✅ tired  
✅ anxious  

### Not Yet Supported (5/15)

These API moods are not currently offered in the UI:

❌ relaxed (covered by "calm" and "peaceful")  
❌ angry  
❌ frustrated  
❌ motivated (covered by "energetic" and "excited")  
❌ overwhelmed (covered by "stressed")  

**Rationale:** We prioritize the most common emotional states while keeping the interface clean. Future versions may add these if user feedback indicates a need.

---

## UX Considerations

### Visibility Without Scrolling

All 10 mood options are visible without scrolling using a **2-column grid layout**:

1. **Compact cards** - Smaller, icon-focused design
2. **2-column grid** - Uses horizontal space efficiently
3. **10 cards fit perfectly** - 5 rows × 2 columns on standard iPhone screens
4. **Header stays visible** - "How are you feeling?" always on screen

### Layout Strategy

**2-Column Grid (5 rows × 2 columns):**
- Row 1: Peaceful, Calm
- Row 2: Content, Happy
- Row 3: Excited, Energetic
- Row 4: Tired, Sad
- Row 5: Anxious, Stressed

Moods are ordered by **energy level and valence**:

1. **Low energy positive** - Peaceful, Calm
2. **Medium positive** - Content, Happy
3. **High energy positive** - Excited, Energetic
4. **Low/negative** - Tired, Sad
5. **High energy negative** - Anxious, Stressed

This creates a natural flow from calm → energetic → tired/sad/stressed while utilizing the 2-column space efficiently.

### Auto-Navigation Flow

To minimize clicks and friction:

1. User taps a mood card
2. Card shows selection (background tint + border)
3. **Automatic navigation** to note-taking view after 0.3s
4. No "Continue" button required

**Benefits:**
- Faster mood logging (one tap instead of two)
- Cleaner interface (no extra buttons)
- Natural flow (selection → immediate action)
- Still gives visual feedback before transition

**Card Design:**
- Compact vertical layout (icon above text)
- Icon: 48pt circle with subtle color background
- Text: Name + brief description
- Selection: Light tint + border highlight
- Padding: Generous touch targets despite compact size

---

### Analytics Scoring

The 1-5 scoring system enables trend analysis:

| Score | Moods | Interpretation |
|-------|-------|----------------|
| 5 | Excited | Very high well-being |
| 4 | Happy, Energetic | High well-being |
| 3 | Peaceful, Calm, Content | Neutral/stable |
| 2 | Tired | Low energy (not necessarily negative) |
| 1 | Sad, Anxious, Stressed | Requires attention |

This allows the app to:
- Track emotional trends over time
- Identify patterns (e.g., "stressed every Monday")
- Provide gentle insights without judgment

---

## Future Enhancements

Potential additions based on user feedback:

1. **Custom moods** - Let users define their own
2. **Mood intensity** - Slider for "very" vs "slightly" anxious
3. **Multiple moods** - Select 2-3 moods at once
4. **Mood categories** - Group similar moods for easier selection
5. **Quick mood** - One-tap logging from home screen widget

---

## Related Documentation

- [Mood Tracking Design Philosophy](DESIGN_PHILOSOPHY.md)
- [Mood UX Design](MOOD_UX_DESIGN.md)
- [API Integration](../backend-integration/)

---

**Remember:** Every mood option should feel welcoming and non-judgmental. No emotion is "wrong" or "bad" in Lume. 🌟