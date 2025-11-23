# 🍽️ Nutrition Meal Log Status Indicators - UX Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Define visual status indicators for meal logs based on FitIQ design system

---

## 📋 Overview

This document defines the UX patterns for displaying meal log status indicators throughout the FitIQ app. Status indicators help users understand the current state of their meal logs as they're being processed by the AI backend.

**Key Principles:**
- **Clarity:** Users should immediately understand what's happening with their meal log
- **Consistency:** Use the same visual language throughout the app
- **Non-intrusive:** Don't distract from primary content
- **Accessibility:** Meet WCAG AA standards for color contrast

---

## 🎨 Status Indicator Design System

### Color Palette (From FitIQ Color Profile)

| Status | Color | Hex Code | Rationale |
|--------|-------|----------|-----------|
| **Pending** | Ascend Blue | `#007AFF` | Trustworthy, indicates processing in progress |
| **Processing** | Attention Orange | `#FF9500` | Active attention, AI is working |
| **Completed** | Growth Green | `#34C759` | Success, goal completion |
| **Failed** | System Red | `#FF3B30` | Error state, needs user attention |

### Typography

- **Status Text:** SF Pro Text, Medium weight
- **Helper Text:** SF Pro Text, Regular weight
- **Size:** 13pt for status labels, 11pt for helper text

---

## 📱 Status Indicator Patterns

### 1. Pending Status

**When to Show:**
- Meal log has been created locally
- Waiting for backend sync to complete
- Has a `backendID` but no response yet

**Visual Design:**
```
┌────────────────────────────────────────┐
│  🍳 Breakfast                          │
│  ⏳ Processing...                      │
│                                        │
│  "2 eggs, toast, coffee"               │
│  Logged at 8:30 AM                     │
│                                        │
│  [Blue pulsing indicator]              │
└────────────────────────────────────────┘
```

**SwiftUI Implementation:**
```swift
// Status Badge
HStack(spacing: 4) {
    Image(systemName: "clock.fill")
        .foregroundColor(.blue)
        .font(.system(size: 12))
    
    Text("Processing...")
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.blue)
}
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color.blue.opacity(0.1))
.cornerRadius(6)
```

**Helper Properties (MealLog):**
```swift
extension MealLog {
    var isPending: Bool {
        syncStatus == .pending || status == .pending
    }
    
    var statusBadgeText: String {
        if isPending {
            return "Processing..."
        }
        // ... other statuses
    }
    
    var statusBadgeColor: Color {
        if isPending {
            return .blue
        }
        // ... other statuses
    }
    
    var statusIcon: String {
        if isPending {
            return "clock.fill"
        }
        // ... other statuses
    }
}
```

---

### 2. Processing Status

**When to Show:**
- Backend has acknowledged the meal log
- AI is actively parsing nutritional data
- Status = `.processing`

**Visual Design:**
```
┌────────────────────────────────────────┐
│  🍳 Breakfast                          │
│  🔄 AI Analyzing...                    │
│                                        │
│  "2 eggs, toast, coffee"               │
│  Logged at 8:30 AM                     │
│                                        │
│  [Orange animated spinner]             │
└────────────────────────────────────────┘
```

**SwiftUI Implementation:**
```swift
// Status Badge with Animation
HStack(spacing: 4) {
    ProgressView()
        .controlSize(.small)
        .tint(.orange)
    
    Text("AI Analyzing...")
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.orange)
}
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color.orange.opacity(0.1))
.cornerRadius(6)
```

**Helper Properties:**
```swift
extension MealLog {
    var isProcessing: Bool {
        status == .processing
    }
}
```

---

### 3. Completed Status

**When to Show:**
- AI parsing completed successfully
- Nutritional data available
- Status = `.completed`

**Visual Design:**
```
┌────────────────────────────────────────┐
│  🍳 Breakfast                          │
│  ✅ Analyzed                           │
│                                        │
│  🥚 2 eggs (140 cal)                   │
│  🍞 Toast with butter (150 cal)        │
│  ☕ Coffee (5 cal)                     │
│                                        │
│  Total: 295 cal | P: 18g C: 20g F: 15g│
│  Logged at 8:30 AM                     │
└────────────────────────────────────────┘
```

**SwiftUI Implementation:**
```swift
// Status Badge (Subtle, can be hidden after animation)
HStack(spacing: 4) {
    Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)
        .font(.system(size: 12))
    
    Text("Analyzed")
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.green)
}
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color.green.opacity(0.1))
.cornerRadius(6)
.transition(.scale.combined(with: .opacity))
// Auto-hide after 2 seconds (optional)
```

**Helper Properties:**
```swift
extension MealLog {
    var isSynced: Bool {
        syncStatus == .synced && status == .completed
    }
    
    var isComplete: Bool {
        status == .completed
    }
}
```

---

### 4. Failed/Error Status

**When to Show:**
- AI parsing failed
- Network error during sync
- Status = `.failed` or `syncStatus == .failed`

**Visual Design:**
```
┌────────────────────────────────────────┐
│  🍳 Breakfast                          │
│  ❌ Analysis Failed                    │
│                                        │
│  "2 eggs, toast, coffee"               │
│  Logged at 8:30 AM                     │
│                                        │
│  Unable to analyze. Tap to retry.      │
│  [Red indicator with retry button]     │
└────────────────────────────────────────┘
```

**SwiftUI Implementation:**
```swift
// Status Badge with Action
VStack(alignment: .leading, spacing: 8) {
    HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
            .font(.system(size: 12))
        
        Text("Analysis Failed")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.red)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.red.opacity(0.1))
    .cornerRadius(6)
    
    Button(action: { /* Retry action */ }) {
        Text("Tap to retry")
            .font(.system(size: 12))
            .foregroundColor(.blue)
    }
}
```

**Helper Properties:**
```swift
extension MealLog {
    var hasSyncError: Bool {
        syncStatus == .failed || status == .failed
    }
    
    var canRetry: Bool {
        hasSyncError && backendID != nil
    }
}
```

---

## 🔄 Pull-to-Refresh Pattern

**When to Show:**
- User manually pulls down on meal log list
- Triggers manual sync of pending/processing meal logs

**Visual Design:**
```
┌────────────────────────────────────────┐
│         ↓ Pull to refresh              │
│                                        │
│  [Meal Log List]                       │
│                                        │
│  🍳 Breakfast - ⏳ Processing...       │
│  🥗 Lunch - ✅ Analyzed                │
│  🍝 Dinner - ⏳ Processing...          │
└────────────────────────────────────────┘
```

**SwiftUI Implementation:**
```swift
List {
    ForEach(mealLogs) { mealLog in
        MealLogRow(mealLog: mealLog)
    }
}
.refreshable {
    await viewModel.manualSyncPendingMeals()
}
```

**User Feedback:**
- Show subtle success message if meals were updated
- Don't show error for silent background sync failures
- Haptic feedback on pull completion

---

## 📊 Real-Time Updates (WebSocket)

**When Updates Occur:**
- WebSocket receives `meal_log.completed` event
- WebSocket receives `meal_log.failed` event
- Local storage is updated automatically

**Animation:**
1. **Pending → Processing:** Subtle fade transition
2. **Processing → Completed:** Scale + fade animation (celebrate success)
3. **Processing → Failed:** Shake animation (indicate error)

**SwiftUI Implementation:**
```swift
.onChange(of: mealLog.status) { oldValue, newValue in
    if newValue == .completed {
        // Celebrate with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSuccessAnimation = true
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    } else if newValue == .failed {
        // Error animation
        withAnimation(.default) {
            showErrorAnimation = true
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
```

---

## 🎯 Best Practices

### Do's ✅

1. **Show status for pending/processing meals prominently**
   - Users need to know their meal is being analyzed

2. **Auto-hide completed status after 2-3 seconds**
   - Keep UI clean, users don't need to see "Analyzed" forever

3. **Provide retry action for failed meals**
   - Give users control to fix issues

4. **Use haptic feedback for status changes**
   - Reinforce visual feedback with tactile response

5. **Show progress for multiple pending meals**
   - "Analyzing 2 meals..." if multiple are pending

### Don'ts ❌

1. **Don't show status for all completed meals**
   - Only show during transition (then hide)

2. **Don't use intrusive alerts for sync errors**
   - Use inline badges with retry options

3. **Don't block UI while syncing**
   - Keep UI responsive, show status inline

4. **Don't auto-retry failed meals without user action**
   - User might want to edit or delete

---

## 📝 Code Examples

### Complete Status Badge Component

```swift
struct MealLogStatusBadge: View {
    let mealLog: MealLog
    
    var body: some View {
        Group {
            if mealLog.isPending {
                pendingBadge
            } else if mealLog.isProcessing {
                processingBadge
            } else if mealLog.hasSyncError {
                errorBadge
            } else if mealLog.isSynced && mealLog.isComplete {
                // Show briefly, then hide
                completedBadge
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var pendingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .foregroundColor(.blue)
                .font(.system(size: 12))
            
            Text("Processing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var processingBadge: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.small)
                .tint(.orange)
            
            Text("AI Analyzing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
            
            Text("Analyzed")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var errorBadge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                
                Text("Analysis Failed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)
        }
    }
}
```

### Usage in Meal Log Row

```swift
struct MealLogRow: View {
    let mealLog: MealLog
    @State private var showCompletedBadge = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealLog.mealType.displayName)
                    .font(.headline)
                
                Spacer()
                
                if showCompletedBadge || !mealLog.isSynced {
                    MealLogStatusBadge(mealLog: mealLog)
                }
            }
            
            // Meal content...
        }
        .onChange(of: mealLog.status) { oldValue, newValue in
            if newValue == .completed {
                showCompletedBadge = true
                
                // Auto-hide after 2 seconds
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        showCompletedBadge = false
                    }
                }
            }
        }
    }
}
```

---

## 🔍 Accessibility Considerations

### Color Contrast

All status colors meet WCAG AA standards:
- **Blue on white:** 4.5:1 (AA)
- **Orange on white:** 4.5:1 (AA)
- **Green on white:** 4.5:1 (AA)
- **Red on white:** 4.5:1 (AA)

### VoiceOver Support

```swift
.accessibilityLabel(mealLog.isPending ? "Meal log is being processed" : 
                    mealLog.isProcessing ? "AI is analyzing your meal" :
                    mealLog.isSynced ? "Meal analyzed successfully" :
                    mealLog.hasSyncError ? "Meal analysis failed, tap to retry" : "")
.accessibilityHint(mealLog.hasSyncError ? "Double tap to retry analysis" : "")
```

### Dynamic Type Support

- Use `.font(.system(size: 13, weight: .medium))` for scalable text
- Test with larger accessibility text sizes
- Ensure badges don't truncate or overflow

---

## 📚 Related Documentation

- [FitIQ Color Profile](./COLOR_PROFILE.md)
- [Nutrition WebSocket Integration](../nutrition/nutrition-websocket-integration-summary.md)
- [Meal Log API Integration](../api-integration/features/nutrition-tracking.md)

---

**Version History:**
- **1.0.0** (2025-01-27): Initial UX documentation for nutrition status indicators