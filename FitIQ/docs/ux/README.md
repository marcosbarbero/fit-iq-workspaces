# FitIQ UX Documentation

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** User experience design specifications and guidelines

---

## 📚 Table of Contents

1. [Overview](#overview)
2. [Design System](#design-system)
3. [Feature Documentation](#feature-documentation)
4. [Quick Links](#quick-links)

---

## 📋 Overview

This directory contains all UX design specifications, visual guidelines, and feature documentation for the FitIQ iOS app. All designs follow iOS Human Interface Guidelines and align with the backend API contract.

### Design Principles

1. **Simple & Intuitive** - Easy to learn, quick to use
2. **Consistent** - Unified color palette, typography, and patterns
3. **Accessible** - Supports VoiceOver, Dynamic Type, High Contrast
4. **Delightful** - Smooth animations, haptic feedback, visual polish

---

## 🎨 Design System

### Color Profile

**File:** [COLOR_PROFILE.md](./COLOR_PROFILE.md)

Primary colors used throughout the app:

| Color | Hex | Usage |
|-------|-----|-------|
| **Ascend Blue** | `#007AFF` | CTAs, active states, navigation, AI chat |
| **Vitality Teal** | `#00C896` | Fitness, activity, workouts, community |
| **Serenity Lavender** | `#B58BEF` | Wellness, mood, meditation, rest |
| **Clean Slate** | `#FFFFFF` / `#1C1C1E` | Backgrounds (light/dark) |
| **Growth Green** | `#34C759` | Success, goal completion |
| **Attention Orange** | `#FF9500` | Alerts, warnings, urgent actions |

### Typography

**System Font:** SF Pro (iOS default)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Large Title | 34pt | Bold | Main headings |
| Title 1 | 28pt | Bold | Section headers |
| Title 2 | 22pt | Bold | Subsection headers |
| Headline | 17pt | Semibold | Card titles, labels |
| Body | 17pt | Regular | Primary content |
| Callout | 16pt | Regular | Secondary content |
| Subheadline | 15pt | Regular | Supporting text |
| Footnote | 13pt | Regular | Captions, metadata |
| Caption | 12pt | Regular | Timestamps, counts |

---

## 📱 Feature Documentation

### Mood Tracking (Latest Update: 2025-01-27)

Complete redesign to align with backend API and improve UX.

#### Core Documents

1. **[MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md)** ⭐ **START HERE**
   - Complete UX specification
   - Design goals and principles
   - Component details (dial, emotions, notes)
   - User flows (quick and detailed entry)
   - Architecture and data flow
   - Backend API integration
   - Validation rules
   - Accessibility features
   - Future enhancements

2. **[MOOD_ENTRY_CHANGELOG.md](./MOOD_ENTRY_CHANGELOG.md)**
   - Before vs after comparison
   - Domain model changes
   - ViewModel changes
   - Use case changes
   - View changes
   - Visual design improvements
   - UX flow improvements
   - Backend API alignment
   - Testing impact
   - Metrics and performance
   - Migration guide

3. **[MOOD_ENTRY_VISUAL_GUIDE.md](./MOOD_ENTRY_VISUAL_GUIDE.md)**
   - ASCII mockups of full screen
   - Component-level visual specs
   - Color specifications
   - Layout specifications (spacing, typography, sizes)
   - Interaction states (animations, transitions)
   - Responsive behavior (landscape, iPad)
   - Accessibility features (VoiceOver, Dynamic Type)
   - Animation specifications
   - Performance considerations

#### Quick Summary

**What Changed:**
- ❌ Removed: Complex valence, 32+ mood labels, 22+ associations, HealthKit integration
- ✅ Added: Simple emotion selection grid (15 predefined emotions)
- ✅ Improved: Visual design with Serenity Lavender theme, gradients, shadows
- ✅ Aligned: 100% backend API compatible (`/api/v1/mood`)

**Key Features:**
- 🎯 Circular progress dial (1-10 mood score)
- 🎭 Emotion selection grid (15 emotions with icons)
- 📝 Notes field (500 char limit)
- 🎨 Serenity Lavender color theme
- ✨ Smooth animations and haptic feedback
- ♿ Full accessibility support

**User Flow:**
1. Adjust mood score slider (1-10) → See emoji + description
2. Select emotions (optional) → Tap chips to toggle
3. Add notes (optional) → Type context
4. Tap "Log Mood" → Success confirmation → Dismiss

**Time to Complete:**
- Quick entry: ~10 seconds
- Detailed entry: ~30-60 seconds

---

## 🔗 Quick Links

### Internal Documentation

- [Copilot Instructions](../../.github/copilot-instructions.md) - Development guidelines
- [Backend API Spec](../be-api-spec/swagger.yaml) - API contracts
- [Integration Handoff](../IOS_INTEGRATION_HANDOFF.md) - Integration patterns
- [Architecture](../architecture/) - System design patterns

### Feature Specs

- **Mood Tracking:** [MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md)
- **Sleep Tracking:** _(Coming soon)_
- **Nutrition Tracking:** _(Coming soon)_
- **Activity Dashboard:** _(Coming soon)_

### Design Resources

- [COLOR_PROFILE.md](./COLOR_PROFILE.md) - Color palette
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icon library
- [iOS HIG](https://developer.apple.com/design/human-interface-guidelines/ios) - Design guidelines

---

## 🎯 How to Use This Documentation

### For Designers

1. Start with [COLOR_PROFILE.md](./COLOR_PROFILE.md) to understand the color system
2. Review feature specs (e.g., [MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md))
3. Use [MOOD_ENTRY_VISUAL_GUIDE.md](./MOOD_ENTRY_VISUAL_GUIDE.md) for detailed mockups
4. Create high-fidelity designs in Figma/Sketch following these specs

### For Developers

1. Read the feature spec (e.g., [MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md))
2. Check the changelog for before/after comparison (e.g., [MOOD_ENTRY_CHANGELOG.md](./MOOD_ENTRY_CHANGELOG.md))
3. Use the visual guide for implementation details (e.g., [MOOD_ENTRY_VISUAL_GUIDE.md](./MOOD_ENTRY_VISUAL_GUIDE.md))
4. Reference [Copilot Instructions](../../.github/copilot-instructions.md) for architecture patterns

### For Product Managers

1. Review the feature spec's "Design Goals" section
2. Check the "User Flow" section for expected behavior
3. Review the "Success Metrics" in the changelog
4. Use the "Future Enhancements" section for roadmap planning

### For QA Engineers

1. Review the "Validation Rules" section in feature specs
2. Check the "Testing" section for test cases
3. Use the "Interaction States" in visual guides for edge cases
4. Verify accessibility features (VoiceOver, Dynamic Type, High Contrast)

---

## ✅ Documentation Standards

All UX documentation in this directory follows these standards:

### File Naming

- Feature specs: `<FEATURE>_<TYPE>.md` (e.g., `MOOD_ENTRY_REDESIGN.md`)
- Changelogs: `<FEATURE>_CHANGELOG.md`
- Visual guides: `<FEATURE>_VISUAL_GUIDE.md`
- System docs: `<CATEGORY>_PROFILE.md` (e.g., `COLOR_PROFILE.md`)

### Document Structure

All feature specs include:
1. **Overview** - Summary of the feature
2. **Design Goals** - What we're trying to achieve
3. **UI Components** - Detailed component specs
4. **User Flow** - Step-by-step user journey
5. **Architecture** - Data flow and technical integration
6. **Backend Integration** - API contracts and sync strategy
7. **Validation Rules** - Input validation requirements
8. **Accessibility** - VoiceOver, Dynamic Type, High Contrast
9. **Testing** - Unit, integration, and UI tests
10. **Future Enhancements** - Roadmap items

### Versioning

- Use semantic versioning (e.g., 1.0.0)
- Update "Last Updated" date on changes
- Mark status (✅ Implemented, 🚧 In Progress, 📋 Planned)

### Maintenance

- Review and update docs after each major feature release
- Keep backend API references in sync with backend team
- Document any deviations from specs in changelogs
- Archive outdated specs in `/docs/archive/`

---

## 📞 Contact

For questions about UX documentation:

- **Design Team:** Review UX specs and provide feedback
- **Product Team:** Define feature requirements and success metrics
- **Engineering Team:** Implement features according to specs
- **QA Team:** Test features against documented behavior

---

## 📝 Recent Updates

| Date | Feature | Change | Documents |
|------|---------|--------|-----------|
| 2025-01-27 | Mood Tracking | Complete redesign + backend API alignment | [MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md), [MOOD_ENTRY_CHANGELOG.md](./MOOD_ENTRY_CHANGELOG.md), [MOOD_ENTRY_VISUAL_GUIDE.md](./MOOD_ENTRY_VISUAL_GUIDE.md) |
| 2025-01-15 | Color System | Initial color profile defined | [COLOR_PROFILE.md](./COLOR_PROFILE.md) |

---

## 🚀 Next Steps

1. **Review** - Product/UX team reviews mood entry redesign
2. **Test** - QA team validates implementation against specs
3. **Iterate** - Incorporate feedback and update docs
4. **Document** - Create similar specs for other features (sleep, nutrition, activity)

---

**Status:** ✅ Active  
**Maintainer:** Design & Product Teams  
**Last Review:** 2025-01-27