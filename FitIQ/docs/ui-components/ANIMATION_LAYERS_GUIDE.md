# Animation Layers Visual Guide

**Component:** `MindfulnessIconView`  
**Purpose:** Visual breakdown of each animation layer  
**Created:** 2025-01-27

---

## Layer Stack (Bottom to Top)

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│    Layer 5: Particle Effect (Very Pleasant only)       │
│    • 8 small circles                                    │
│    • Radiates outward 80-100px                          │
│    • Fades 0.8 → 0.0                                    │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    Layer 4: Core Icon with Shadow                      │
│    • SF Symbol (70pt, ultraLight)                      │
│    • White gradient fill                                │
│    • Soft glow shadow                                   │
│    • Breathes 1.0 ↔ 1.08                               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    Layer 3: Inner Glow Circle                          │
│    • Radial gradient (180px diameter)                   │
│    • Breathes 0.95 ↔ 1.1 scale                         │
│    • Main breathing effect                              │
│    • Duration: 2.5s                                     │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    Layer 2: Rotating Gradient Ring                     │
│    • 70% partial circle (160px diameter)               │
│    • Angular gradient                                   │
│    • Rotates 360° continuously                          │
│    • Duration: 8.0s                                     │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    Layer 1: Outer Ethereal Glow (3 rings)             │
│    • Ring 1: 180px, 3.0s, no delay                     │
│    • Ring 2: 220px, 3.3s, 0.2s delay                   │
│    • Ring 3: 260px, 3.6s, 0.4s delay                   │
│    • Expands 1.0 → 1.15, fades 0.6 → 0.0              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Animation Timeline (2.5 Second Cycle)

```
Time:  0.0s      0.625s     1.25s      1.875s     2.5s
       |          |          |          |          |
       ↓          ↓          ↓          ↓          ↓

Inner  ●─────────○─────────◯─────────○─────────●
Glow   (min)  (expanding)  (max)  (contracting) (min)
       0.95      1.0        1.1       1.0       0.95

Icon   ●─────────○─────────◯─────────○─────────●
       (min)  (growing)    (max)   (shrinking)  (min)
       1.0       1.04       1.08      1.04      1.0

Outer  ●─────────────────────────────────────→ ×
Ring 1 (visible, 60%)  (expanding, 30%)  (faded, 0%)
       (cycle: 3.0s)

Outer  ─ ●─────────────────────────────────→ ×
Ring 2    (0.2s delay, cycle: 3.3s)

Outer  ───── ●─────────────────────────────→ ×
Ring 3       (0.4s delay, cycle: 3.6s)

Gradient  ──────────────────────────────────────→
Ring         (continuous 360° rotation, 8.0s per cycle)

Particles  ●─○─◯─○─●─○─◯─○─●  (Very Pleasant only)
(8 total)  (breathe with inner glow, staggered 0.1s)
```

---

## Visual Representation

### Neutral State (Scale = 1.0)
```
              Outer Ring 3 (fading)
          ╱                           ╲
        ╱     Outer Ring 2 (fading)     ╲
      ╱       ╱                   ╲       ╲
    ╱       ╱   Outer Ring 1       ╲       ╲
   │       │    (visible)            │       │
   │      ╱  ╱─────────────╲  ╲      │
   │     │  │   Gradient    │  │     │
   │     │  │     Ring      │  │     │
   │     │  │  (rotating)   │  │     │
   │     │   ╲             ╱   │     │
   │      ╲   ╲─────────╱    ╱      │
   │       ╲                 ╱       │
   │        ╲   Inner      ╱        │
    ╲        ╲   Glow    ╱        ╱
     ╲        ╲         ╱        ╱
      ╲        │  Icon │        ╱
       ╲       │   ☁️  │       ╱
        ╲      │       │      ╱
         ╲─────┴───────┴─────╱
```

### Breathe In (Scale = 1.1)
```
                Outer Ring 3
            ╱                       ╲
          ╱     Outer Ring 2          ╲
        ╱       ╱               ╲       ╲
      ╱       ╱   Outer Ring 1   ╲       ╲
     │       │                      │       │
     │      │   ╱─────────────╲   │      │
     │     │   │   Gradient    │   │     │
     │     │   │     Ring      │   │     │
     │     │   │  (rotating)   │   │     │
     │     │   │               │   │     │
     │      │   ╲─────────────╱   │      │
     │       │                      │       │
     │        ╲   Inner Glow      ╱        │
     │         ╲   (expanded)    ╱         │
      ╲         ╲               ╱         ╱
       ╲         │             │         ╱
        ╲        │    Icon     │        ╱
         ╲       │   (larger)  │       ╱
          ╲      │     ☁️      │      ╱
           ╲─────┴─────────────┴─────╱
```

### Very Pleasant Mode (with Particles)
```
                    *                      * = particle
                  ╱   ╲                    
                *       *
              ╱     ╱     ╲     ╲
            *      │  Icon  │      *
              ╲    │   ✨   │    ╱
                *  │       │  *
                  ╱ ╲─────╱ ╲
                *       (breathing)       *
                    *
```

---

## Color & Opacity Guide

### Outer Glow Rings
```
Ring 1:  opacity 0.4 → 0.0  (3.0s)
         ████████████░░░░░░░░░░░░→

Ring 2:  opacity 0.3 → 0.0  (3.3s, +0.2s delay)
         ──██████████░░░░░░░░░░→

Ring 3:  opacity 0.25 → 0.0  (3.6s, +0.4s delay)
         ────████████░░░░░░░→
```

### Gradient Ring (Angular)
```
   Start (0°)
      ↓
    White (60%)  ─────→  White (30%)  ─────→  Transparent (0%)
         ████████         ████░░░░         ░░░░░░░░
```

### Inner Glow (Radial)
```
Center                               Edge
  ↓                                   ↓
White (40%)  ─────→  White (15%)  ─────→  Transparent
   ████████         ████░░░░         ░░░░░░░░
```

### Icon Gradient (Linear)
```
Top                                Bottom
 ↓                                   ↓
White (100%)  ─────────────→  White (90%)
   ████████████████████████    ████████████
```

---

## Animation Curves

### Breathing (EaseInOut)
```
Scale
1.1 ┤     ╭─╮
    │    ╱   ╲
1.0 ┤   ╱     ╲    (inhale → pause → exhale)
    │  ╱       ╲
0.95┼─╯         ╰──
    └──────────────→ Time (2.5s cycle)
```

### Outer Glow (EaseInOut, no reverse)
```
Scale
1.15┤              ╱
    │            ╱
1.0 ┤──────────╯    (expand and fade)
    │
0.0 ┤
    └──────────────→ Time (3.0s cycle)

Opacity
0.6 ┤╲
    │ ╲
0.3 ┤  ╲             (fade out as it expands)
    │   ╲
0.0 ┤────╲─────────
    └──────────────→ Time
```

### Rotation (Linear)
```
Angle
360°┤              ╱
    │            ╱
180°┤          ╱      (constant speed)
    │        ╱
0°  ┤──────╯
    └──────────────→ Time (8.0s cycle)
```

---

## Mood-Specific Effects

### Very Unpleasant (☁️ rain cloud)
```
Effect:  Standard breathing
Speed:   2.5s (could be slower in future: 3.0s)
Layers:  All standard layers
Special: None
```

### Unpleasant (☁️ cloud)
```
Effect:  Standard breathing
Speed:   2.5s
Layers:  All standard layers
Special: None
```

### Slightly Unpleasant (🌤️ partly cloudy)
```
Effect:  Standard breathing
Speed:   2.5s
Layers:  All standard layers
Special: None
```

### Neutral (● circle)
```
Effect:  Standard breathing
Speed:   2.5s
Layers:  All standard layers
Special: None (most minimal)
```

### Slightly Pleasant (☀️ small sun)
```
Effect:  Standard breathing
Speed:   2.5s
Layers:  All standard layers
Special: None
```

### Pleasant (☀️ large sun)
```
Effect:  Standard breathing
Speed:   2.5s
Layers:  All standard layers
Special: None
```

### Very Pleasant (✨ sparkles)
```
Effect:  Standard breathing + particles
Speed:   2.5s
Layers:  All standard layers + 8 particles
Special: ✨ 8 particles radiate outward
         • Positioned in circle (45° intervals)
         • Breathe 80px → 100px radius
         • Fade 0.8 → 0.0 opacity
         • Staggered delays (0.1s each)
```

---

## Performance Metrics

### Target Performance
```
Device          | FPS  | CPU Usage | GPU Usage
----------------|------|-----------|----------
iPhone 15 Pro   | 60   | <1%       | <5%
iPhone 12+      | 60   | <2%       | <10%
iPhone X/XS     | 50-60| <5%       | <15%
iPhone 8        | 45-60| <8%       | <20%
```

### Memory Usage
```
Component              | Memory    | Notes
-----------------------|-----------|------------------------
Base view              | ~2 KB     | SwiftUI view hierarchy
Outer glow (3 circles) | ~1 KB     | Shape rendering
Gradient ring          | ~0.5 KB   | Single shape
Inner glow             | ~0.5 KB   | Radial gradient
Icon + shadow          | ~1 KB     | SF Symbol + effects
Particles (8)          | ~0.5 KB   | Only for Very Pleasant
-----------------------|-----------|------------------------
TOTAL                  | ~6 KB     | Minimal footprint
```

---

## Implementation Code Reference

### Layer 1: Outer Glow
```swift
ForEach(0..<3, id: \.self) { index in
    Circle()
        .stroke(gradient, lineWidth: 3)
        .frame(width: 180 + CGFloat(index * 40))
        .scaleEffect(outerBreathing ? 1.15 : 1.0)
        .opacity(outerBreathing ? 0.0 : 0.6 - Double(index) * 0.15)
}
```

### Layer 2: Gradient Ring
```swift
Circle()
    .trim(from: 0.0, to: 0.7)
    .stroke(AngularGradient(...), style: StrokeStyle(...))
    .frame(width: 160)
    .rotationEffect(.degrees(rotation))
```

### Layer 3: Inner Glow
```swift
Circle()
    .fill(RadialGradient(...))
    .frame(width: 180)
    .scaleEffect(innerBreathing ? 1.1 : 0.95)
```

### Layer 4: Core Icon
```swift
ZStack {
    Image(systemName: mood.iconName)  // Shadow
        .blur(radius: 8)
        .offset(y: 4)
    
    Image(systemName: mood.iconName)  // Main
        .shadow(radius: 15)
}
.scaleEffect(innerBreathing ? 1.08 : 1.0)
```

### Layer 5: Particles (Very Pleasant)
```swift
ForEach(0..<8, id: \.self) { index in
    Circle()
        .fill(Color.white.opacity(0.6))
        .frame(width: 4, height: 4)
        .offset(
            x: cos(Double(index) * .pi / 4) * (innerBreathing ? 100 : 80),
            y: sin(Double(index) * .pi / 4) * (innerBreathing ? 100 : 80)
        )
}
```

---

## Debugging Tips

### Visual Debugging
```swift
// Add borders to see layer boundaries
.border(Color.red, width: 1)

// Reduce animation speed for inspection
.animation(.easeInOut(duration: 10.0), value: innerBreathing)

// Isolate single layer by commenting others
// Circle().stroke(...)  // Layer 1 (commented out)
```

### Performance Debugging
```swift
// Use Instruments:
// - Time Profiler (CPU usage)
// - Core Animation (FPS, layer count)
// - Allocations (memory usage)

// Add frame rate display in debug:
.overlay(
    Text("\(fps) FPS")
        .foregroundColor(.red)
)
```

---

## Accessibility Considerations

### Reduce Motion Support (TODO)
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Disable animations when enabled:
.animation(reduceMotion ? .none : .easeInOut(...), value: ...)

// Or reduce animation intensity:
let duration = reduceMotion ? 0.5 : 2.5
let scale = reduceMotion ? 1.02 : 1.1
```

### VoiceOver
```swift
// Icon is decorative, parent should describe:
.accessibilityLabel("Feeling \(mood.label)")
.accessibilityHidden(true)  // Hide animation from VO
```

---

## Future Enhancement Ideas

### Phase 2
- [ ] Haptic feedback synced with breathing
- [ ] Optional breath sound effect
- [ ] Adjustable animation speed (preferences)
- [ ] Mood-specific animation timing
- [ ] Custom color tinting per mood

### Phase 3
- [ ] Metal shaders for advanced effects
- [ ] 3D rotation effects
- [ ] More complex particle systems
- [ ] Dynamic adaptation (time of day)
- [ ] Integration with HealthKit mindfulness

---

**Created:** 2025-01-27  
**Version:** 1.0.0  
**Status:** ✅ Complete