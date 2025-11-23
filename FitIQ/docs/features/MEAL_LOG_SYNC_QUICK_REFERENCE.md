# 🍽️ Meal Log Sync - Quick Reference Guide

**Last Updated:** 2025-01-27  
**Status:** ✅ Complete

---

## 🎯 What Was Built

A complete meal log sync system with:
- ✅ Helper properties for easy status checking
- ✅ Manual sync use case for pull-to-refresh
- ✅ UX documentation with status indicators
- ✅ Full dependency injection setup

---

## 📂 Files Modified/Created

| File | Action | Purpose |
|------|--------|---------|
| `Domain/Entities/Nutrition/MealLogEntities.swift` | Modified | Added `isPending`, `isSynced`, `hasSyncError` helpers |
| `Domain/UseCases/Nutrition/SyncPendingMealLogsUseCase.swift` | Created | Manual sync use case implementation |
| `Infrastructure/Configuration/AppDependencies.swift` | Modified | Added DI for sync use case |
| `Presentation/ViewModels/NutritionViewModel.swift` | Verified | Already has `manualSyncPendingMeals()` |
| `docs/ux/NUTRITION_STATUS_INDICATORS_UX.md` | Created | UX guide for status indicators |

---

## 🚀 How to Use

### In SwiftUI Views (Pull-to-Refresh)

```swift
List {
    ForEach(viewModel.mealLogs) { mealLog in
        MealLogRow(mealLog: mealLog)
    }
}
.refreshable {
    await viewModel.manualSyncPendingMeals()
}
```

### Checking Meal Log Status

```swift
// Helper properties on MealLog
if mealLog.isPending {
    // Show blue "Processing..." badge
}

if mealLog.isSynced {
    // Show green "Analyzed" badge (auto-hide)
}

if mealLog.hasSyncError {
    // Show red "Failed" badge with retry
}
```

### Status Badge Component

```swift
struct MealLogStatusBadge: View {
    let mealLog: MealLog
    
    var body: some View {
        if mealLog.isPending {
            statusBadge(
                icon: "clock.fill",
                text: "Processing...",
                color: .blue
            )
        } else if mealLog.isProcessing {
            statusBadge(
                icon: "arrow.triangle.2.circlepath",
                text: "AI Analyzing...",
                color: .orange,
                animated: true
            )
        } else if mealLog.hasSyncError {
            statusBadge(
                icon: "exclamationmark.triangle.fill",
                text: "Analysis Failed",
                color: .red
            )
        }
    }
    
    private func statusBadge(
        icon: String,
        text: String,
        color: Color,
        animated: Bool = false
    ) -> some View {
        HStack(spacing: 4) {
            if animated {
                ProgressView()
                    .controlSize(.small)
                    .tint(color)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 12))
            }
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}
```

---

## 🎨 Status Colors (FitIQ Design System)

| Status | Color | Hex | Usage |
|--------|-------|-----|-------|
| Pending | Ascend Blue | `#007AFF` | Processing in queue |
| Processing | Attention Orange | `#FF9500` | AI actively analyzing |
| Completed | Growth Green | `#34C759` | Success |
| Failed | System Red | `#FF3B30` | Error, needs retry |

---

## 🔄 Sync Flow

### Automatic (WebSocket)
```
Backend completes processing
→ WebSocket sends event
→ UpdateMealLogStatusUseCase updates local storage
→ UI auto-refreshes (@Observable)
```

### Manual (Pull-to-Refresh)
```
User pulls down
→ manualSyncPendingMeals()
→ SyncPendingMealLogsUseCase.execute()
→ Fetches pending meals with backendID
→ Gets latest data from API
→ Updates local storage
→ Refreshes UI
```

---

## 📊 Status State Machine

```
.pending → .processing → .completed
    ↓                         ↑
    └────────→ .failed ───────┘
                  (retry)
```

---

## 🧪 Testing

### Manual Testing Steps

1. **Submit Meal Log**
   ```swift
   await viewModel.saveMealLog(
       rawInput: "2 eggs, toast, coffee",
       mealType: .breakfast
   )
   ```

2. **Check Status Badge**
   - Should show blue "Processing..." immediately

3. **Wait for WebSocket**
   - Badge changes to orange "AI Analyzing..."
   - Then green "Analyzed" (auto-hides after 2s)

4. **Test Pull-to-Refresh**
   - Pull down on meal log list
   - Should sync any pending meals

5. **Test Offline Scenario**
   - Turn off network
   - Submit meal log
   - Badge shows pending
   - Turn on network
   - Pull-to-refresh
   - Meal updates

---

## 🐛 Debugging

### Check Logs

```bash
# Filter for sync-related logs
# In Xcode console, search for:
SyncPendingMealLogsUseCase
NutritionViewModel: 🔄 Syncing
UpdateMealLogStatusUseCase
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Meal stays pending | No `backendID` | Check if API returned ID |
| Pull-to-refresh no effect | No pending meals | Check meal status |
| Badge not showing | Missing helper property | Use `mealLog.isPending` |
| UI not updating | Not using @Observable | Check ViewModel uses `@Observable` |

---

## 📖 Full Documentation

- **Complete Summary:** `MEAL_LOG_SYNC_IMPLEMENTATION_COMPLETE.md`
- **UX Guide:** `docs/ux/NUTRITION_STATUS_INDICATORS_UX.md`
- **WebSocket Integration:** `docs/nutrition/nutrition-websocket-integration-summary.md`

---

## 🎉 Quick Win Checklist

- ✅ Helper properties added to `MealLog`
- ✅ `SyncPendingMealLogsUseCase` created
- ✅ Registered in `AppDependencies`
- ✅ `manualSyncPendingMeals()` available in ViewModel
- ✅ UX documentation complete
- ✅ Zero compilation errors

---

**Ready to use!** Pull-to-refresh and status indicators are fully functional.