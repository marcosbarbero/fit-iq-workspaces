# Workout Template Sharing - UI Integration Guide

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Completed

---

## Overview

This document describes the UI integration for the workout template sharing features, including ViewModels, view components, and field bindings for sharing, copying, and managing shared templates.

---

## Architecture Summary

### Hexagonal Architecture Compliance

✅ **ViewModels created** - Business logic orchestration  
✅ **Field bindings added** - Connect UI to save/persist/remote calls  
❌ **No UI layout changes** - Only minimal components for data interaction  
❌ **No styling changes** - Followed existing patterns  
❌ **No navigation changes** - Used existing patterns

---

## Components Created

### 1. WorkoutTemplateSharingViewModel

**File:** `Presentation/ViewModels/WorkoutTemplateSharingViewModel.swift`

**Purpose:** Central ViewModel for all template sharing operations

**State Properties:**
```swift
var isSharing: Bool                              // Loading state for share operations
var isRevoking: Bool                             // Loading state for revoke operations
var isLoadingSharedTemplates: Bool               // Loading state for fetching
var isCopying: Bool                              // Loading state for copy operations
var errorMessage: String?                        // Error display
var successMessage: String?                      // Success display
var sharedWithMeTemplates: [SharedTemplateInfo]  // Shared templates list
var hasMoreSharedTemplates: Bool                 // Pagination state
var selectedProfessionalType: ProfessionalType?  // Filter state
var lastShareResponse: ShareWorkoutTemplateResponse? // Last share result
```

**Key Methods:**

#### Share Template (Bulk)
```swift
func shareTemplate(
    templateId: UUID,
    userIds: [UUID],
    professionalType: ProfessionalType,
    notes: String? = nil
) async
```
- Validates at least one user selected
- Calls `ShareWorkoutTemplateUseCase`
- Updates `lastShareResponse` and `successMessage`
- Sets `errorMessage` on failure

#### Revoke Share
```swift
func revokeTemplateShare(
    templateId: UUID,
    userId: UUID
) async
```
- Calls `RevokeTemplateShareUseCase`
- Updates `successMessage` on success
- Sets `errorMessage` on failure

#### Load Shared Templates
```swift
func loadSharedWithMeTemplates(reset: Bool = false) async
```
- Fetches templates shared with user
- Supports pagination
- Optional professional type filtering
- Updates `sharedWithMeTemplates` array

#### Copy Template
```swift
func copyTemplate(
    templateId: UUID,
    newName: String? = nil
) async -> WorkoutTemplate?
```
- Copies template to user's library
- Returns copied template on success
- Updates `successMessage` or `errorMessage`

**Factory Method:**
```swift
static func create(from dependencies: AppDependencies) -> WorkoutTemplateSharingViewModel
```

---

### 2. TemplateShareSheet

**File:** `Presentation/UI/Workout/Components/TemplateShareSheet.swift`

**Purpose:** Sheet view for sharing templates with users

**Field Bindings:**
- `selectedUserIds: String` - Comma-separated user UUIDs
- `selectedProfessionalType: ProfessionalType` - Professional type picker
- `notes: String` - Optional share notes

**Key Features:**
- Parses comma-separated UUIDs
- Validates input before sharing
- Shows success/error messages
- Auto-dismisses on success
- Disables form during operation

**Usage:**
```swift
.sheet(isPresented: $showingShareSheet) {
    TemplateShareSheet(
        viewModel: sharingViewModel,
        templateId: template.id,
        templateName: template.name
    )
}
```

---

### 3. TemplateCopySheet

**File:** `Presentation/UI/Workout/Components/TemplateCopySheet.swift`

**Purpose:** Sheet view for copying templates

**Field Bindings:**
- `newName: String` - Optional new name for copy
- `useOriginalName: Bool` - Toggle for name choice

**Key Features:**
- Option to use original name or provide new one
- Shows original template name
- Validates new name if provided
- Callback on successful copy
- Auto-dismisses on success

**Usage:**
```swift
.sheet(isPresented: $showingCopySheet) {
    TemplateCopySheet(
        viewModel: sharingViewModel,
        templateId: template.id,
        originalTemplateName: template.name,
        onCopySuccess: { copiedTemplate in
            // Handle successful copy
        }
    )
}
```

---

### 4. SharedWithMeTemplatesView

**File:** `Presentation/UI/Workout/Components/SharedWithMeTemplatesView.swift`

**Purpose:** Full view for browsing templates shared with user

**Key Features:**
- List of shared templates
- Professional type filtering (menu)
- Pull-to-refresh support
- Infinite scroll pagination
- Empty state view
- Copy and view detail actions

**Template Row Display:**
- Template name and professional badge
- Description (if available)
- Stats: duration, exercises, difficulty
- Professional name and share date
- Notes (if available)
- Action buttons: View and Copy

**Usage:**
```swift
SharedWithMeTemplatesView(
    viewModel: sharingViewModel,
    onCopyTemplate: { templateId, name in
        // Handle copy action
    },
    onViewTemplateDetail: { templateId in
        // Navigate to template detail
    }
)
```

**Filtering:**
- Menu in toolbar for professional type filter
- "All" option to clear filter
- Filter updates reload templates

---

## Integration Examples

### Example 1: Add to WorkoutViewModel

The `WorkoutViewModel` now includes the sharing ViewModel:

```swift
var sharingViewModel: WorkoutTemplateSharingViewModel?
```

**Initialize in init:**
```swift
init(
    // ... existing parameters ...
    sharingViewModel: WorkoutTemplateSharingViewModel? = nil
) {
    // ... existing assignments ...
    self.sharingViewModel = sharingViewModel
}
```

**Create from AppDependencies:**
```swift
let sharingViewModel = WorkoutTemplateSharingViewModel.create(from: dependencies)
let workoutViewModel = WorkoutViewModel(
    // ... other parameters ...
    sharingViewModel: sharingViewModel
)
```

---

### Example 2: Updated WorkoutTemplateDetailView

The detail view now supports sharing and copying:

**New Properties:**
```swift
var sharingViewModel: WorkoutTemplateSharingViewModel?

@State private var showingShareSheet = false
@State private var showingCopySheet = false
```

**New Action Buttons:**
```swift
if sharingViewModel != nil {
    HStack(spacing: 12) {
        // Share button (only for owned published templates)
        if template.userID != nil && template.status == .published {
            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }

        // Copy button (for any accessible template)
        Button {
            showingCopySheet = true
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.vitalityTeal)
    }
    .padding(.horizontal)
}
```

**Sheet Presentations:**
```swift
.sheet(isPresented: $showingShareSheet) {
    if let sharingViewModel = sharingViewModel {
        TemplateShareSheet(
            viewModel: sharingViewModel,
            templateId: template.id,
            templateName: template.name
        )
    }
}
.sheet(isPresented: $showingCopySheet) {
    if let sharingViewModel = sharingViewModel {
        TemplateCopySheet(
            viewModel: sharingViewModel,
            templateId: template.id,
            originalTemplateName: template.name,
            onCopySuccess: { copiedTemplate in
                print("Template copied: \(copiedTemplate.name)")
            }
        )
    }
}
```

---

### Example 3: Add "Shared With Me" Tab

Add to your main navigation:

```swift
NavigationStack {
    SharedWithMeTemplatesView(
        viewModel: sharingViewModel,
        onCopyTemplate: { templateId, name in
            // Show copy sheet or directly copy
            showCopySheet = true
        },
        onViewTemplateDetail: { templateId in
            // Navigate to template detail
            selectedTemplateId = templateId
            showTemplateDetail = true
        }
    )
}
```

---

## Field Bindings Summary

### TemplateShareSheet Bindings
| Field | Type | Purpose | Validation |
|-------|------|---------|------------|
| `selectedUserIds` | String | Comma-separated UUIDs | Parsed to [UUID] |
| `selectedProfessionalType` | ProfessionalType | Professional category | Enum picker |
| `notes` | String | Share notes | Optional |

### TemplateCopySheet Bindings
| Field | Type | Purpose | Validation |
|-------|------|---------|------------|
| `useOriginalName` | Bool | Name choice toggle | - |
| `newName` | String | New template name | Required if not using original |

### SharedWithMeTemplatesView Bindings
| Field | Type | Purpose | Validation |
|-------|------|---------|------------|
| `selectedProfessionalType` | ProfessionalType? | Filter option | Optional |
| Pagination state | Internal | Auto-handled | - |

---

## State Management

### Loading States

All operations have dedicated loading states:
```swift
viewModel.isSharing              // Share operation in progress
viewModel.isRevoking             // Revoke operation in progress
viewModel.isLoadingSharedTemplates // Fetch operation in progress
viewModel.isCopying              // Copy operation in progress
viewModel.isAnyOperationInProgress // Any operation in progress
```

**Usage:**
```swift
.disabled(viewModel.isSharing)
Button("Share") { ... }
    .disabled(viewModel.isSharing || selectedUserIds.isEmpty)
```

### Error Handling

Errors are captured in `errorMessage`:
```swift
if let error = viewModel.errorMessage {
    Section {
        Text(error)
            .foregroundStyle(.red)
            .font(.caption)
    }
}
```

### Success Feedback

Success messages are captured in `successMessage`:
```swift
if let success = viewModel.successMessage {
    Section {
        Text(success)
            .foregroundStyle(.green)
            .font(.caption)
    }
}
```

**Auto-dismiss pattern:**
```swift
if viewModel.successMessage != nil {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        dismiss()
    }
}
```

---

## Pagination Pattern

The `SharedWithMeTemplatesView` uses infinite scroll:

```swift
// In List
ForEach(viewModel.sharedWithMeTemplates) { template in
    SharedTemplateRow(template: template, ...)
}

if viewModel.hasMoreSharedTemplates {
    HStack {
        Spacer()
        ProgressView()
        Spacer()
    }
    .task {
        await viewModel.loadMoreSharedTemplates()
    }
}
```

**Refresh:**
```swift
.refreshable {
    await viewModel.refreshSharedTemplates()
}
```

**Initial load:**
```swift
.task {
    if viewModel.sharedWithMeTemplates.isEmpty {
        await viewModel.loadSharedWithMeTemplates()
    }
}
```

---

## Professional Type Filtering

Filter menu in toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Menu {
            Button {
                Task {
                    await viewModel.updateProfessionalTypeFilter(nil)
                }
            } label: {
                Label("All", systemImage: "line.3.horizontal.decrease.circle")
            }

            Divider()

            ForEach(ProfessionalType.allCases, id: \.self) { type in
                Button {
                    Task {
                        await viewModel.updateProfessionalTypeFilter(type)
                    }
                } label: {
                    Label(type.displayName, systemImage: "person.fill")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}
```

---

## Testing Checklist

### Unit Testing

- [ ] Test `WorkoutTemplateSharingViewModel` state management
- [ ] Test share action with valid/invalid user IDs
- [ ] Test revoke action
- [ ] Test copy action with/without new name
- [ ] Test pagination in shared templates
- [ ] Test professional type filtering

### Integration Testing

- [ ] Test share sheet with real backend
- [ ] Test copy sheet with real backend
- [ ] Test shared templates list loading
- [ ] Test error handling (network failures)
- [ ] Test success messages and auto-dismiss
- [ ] Test filter changes reload data
- [ ] Test infinite scroll loading more

### UI Testing

- [ ] Verify Share button only shows for owned published templates
- [ ] Verify Copy button shows for all accessible templates
- [ ] Verify sheets present and dismiss correctly
- [ ] Verify error messages display properly
- [ ] Verify success messages display properly
- [ ] Verify loading states disable UI correctly
- [ ] Verify pagination loads more on scroll
- [ ] Verify pull-to-refresh works

---

## Best Practices

### 1. Always Check ViewModel Availability

```swift
if let sharingViewModel = sharingViewModel {
    // Use sharing features
}
```

### 2. Handle Success Callbacks

```swift
onCopySuccess: { copiedTemplate in
    // Update local state
    // Show confirmation
    // Refresh lists if needed
}
```

### 3. Clear Messages on New Actions

```swift
viewModel.clearMessages()
await viewModel.shareTemplate(...)
```

### 4. Use @MainActor for UI Updates

All ViewModel methods that update UI state are marked `@MainActor`:
```swift
@MainActor
func shareTemplate(...) async { ... }
```

### 5. Validate Input Before Actions

```swift
guard !userIds.isEmpty else {
    viewModel.errorMessage = "Please select at least one user"
    return
}
```

---

## Common Patterns

### Pattern 1: Present Share Sheet from Detail View

```swift
Button("Share") {
    showingShareSheet = true
}
.sheet(isPresented: $showingShareSheet) {
    if let sharingViewModel = sharingViewModel {
        TemplateShareSheet(
            viewModel: sharingViewModel,
            templateId: template.id,
            templateName: template.name
        )
    }
}
```

### Pattern 2: Present Copy Sheet from List

```swift
Button("Copy") {
    selectedTemplateId = template.id
    selectedTemplateName = template.name
    showingCopySheet = true
}
.sheet(isPresented: $showingCopySheet) {
    if let sharingViewModel = sharingViewModel,
       let templateId = selectedTemplateId,
       let templateName = selectedTemplateName {
        TemplateCopySheet(
            viewModel: sharingViewModel,
            templateId: templateId,
            originalTemplateName: templateName,
            onCopySuccess: { copiedTemplate in
                // Refresh template list
                Task {
                    await workoutViewModel.loadRealTemplates()
                }
            }
        )
    }
}
```

### Pattern 3: Standalone Shared Templates Tab

```swift
TabView {
    // ... other tabs ...
    
    NavigationStack {
        SharedWithMeTemplatesView(
            viewModel: sharingViewModel,
            onCopyTemplate: { templateId, name in
                currentCopyTemplateId = templateId
                currentCopyTemplateName = name
                showCopySheet = true
            },
            onViewTemplateDetail: { templateId in
                // Fetch full template and show detail
                Task {
                    if let template = await fetchTemplate(templateId) {
                        selectedTemplate = template
                        showTemplateDetail = true
                    }
                }
            }
        )
    }
    .tabItem {
        Label("Shared", systemImage: "person.2")
    }
}
```

---

## Files Modified/Created

### Created Files (4)

1. `Presentation/ViewModels/WorkoutTemplateSharingViewModel.swift`
   - Central ViewModel for all sharing operations
   - 278 lines

2. `Presentation/UI/Workout/Components/TemplateShareSheet.swift`
   - Share template sheet with field bindings
   - 113 lines

3. `Presentation/UI/Workout/Components/TemplateCopySheet.swift`
   - Copy template sheet with field bindings
   - 106 lines

4. `Presentation/UI/Workout/Components/SharedWithMeTemplatesView.swift`
   - View for browsing shared templates
   - 246 lines

### Modified Files (2)

1. `Presentation/ViewModels/WorkoutViewModel.swift`
   - Added `sharingViewModel` property
   - Updated init to accept sharing ViewModel

2. `Presentation/UI/Workout/WorkoutTemplateDetailView.swift`
   - Added share and copy buttons (field bindings only)
   - Added sheet presentations
   - No layout/styling changes beyond button additions

---

## Migration from Old UI (If Applicable)

If you had previous sharing UI:

1. **Replace single-user share** with bulk share sheet
2. **Update share button handlers** to use `TemplateShareSheet`
3. **Add copy functionality** using `TemplateCopySheet`
4. **Add "Shared With Me"** section using `SharedWithMeTemplatesView`

---

## Troubleshooting

### Issue: Share button not showing
**Solution:** Verify template is owned by user and status is `.published`

### Issue: Copy button not working
**Solution:** Verify `sharingViewModel` is not nil and properly initialized

### Issue: Shared templates not loading
**Solution:** Check user authentication and network connectivity

### Issue: Sheet not dismissing after success
**Solution:** Verify `successMessage` is set and delay is working

### Issue: Pagination not loading more
**Solution:** Verify `hasMoreSharedTemplates` is true and not already loading

---

## Next Steps

### Required for Production

1. **Add to Main App:**
   - Initialize `WorkoutTemplateSharingViewModel` in app startup
   - Pass to `WorkoutViewModel` instances
   - Add to detail views and management views

2. **User Selection UI:**
   - Create proper user picker (current uses text input)
   - Add search/autocomplete for users
   - Show user avatars and names

3. **Enhanced Copy:**
   - Show template preview before copying
   - Allow customization during copy
   - Bulk copy support

4. **Share Management:**
   - View list of users template is shared with
   - Revoke shares from management view
   - Share analytics/tracking

### Optional Enhancements

- Push notifications when templates are shared
- Activity feed for sharing events
- Share history/audit log
- Template ratings/feedback from shared users
- Bulk operations (share multiple templates at once)

---

## References

- **Backend API:** `docs/be-api-spec/swagger.yaml` (lines 9024-9200)
- **Implementation Guide:** `docs/WORKOUT_TEMPLATE_SHARING_IMPLEMENTATION.md`
- **Use Cases:** `Domain/UseCases/Workout/ShareWorkoutTemplateUseCase.swift` (and related)
- **API Client:** `Infrastructure/Network/WorkoutTemplateAPIClient.swift`
- **Architecture Rules:** `.github/copilot-instructions.md`

---

## Conclusion

The UI integration for workout template sharing is complete with:

✅ **ViewModels** - `WorkoutTemplateSharingViewModel` for business logic  
✅ **View Components** - Share, Copy, and Shared list views  
✅ **Field Bindings** - All inputs connected to remote calls  
✅ **State Management** - Loading, error, success states  
✅ **Pagination** - Infinite scroll for shared templates  
✅ **Filtering** - Professional type filtering  
✅ **Integration** - Connected to existing `WorkoutTemplateDetailView`  

**Status:** ✅ Ready for production integration

---

**Last Updated:** 2025-01-27  
**Implemented By:** AI Assistant  
**Reviewed By:** Pending