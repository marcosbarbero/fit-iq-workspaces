# Workout Templates Debug Fixes

**Date:** 2025-01-27  
**Status:** ✅ Completed  
**Version:** 1.0.0

---

## 📋 Overview

This document describes the fixes and debug enhancements applied to address:

1. **Difficulty filter not working** - Filter was not actually filtering templates
2. **Exercises not displaying** - Investigation into whether exercises are being saved/loaded properly

---

## 🐛 Issues Identified

### Issue #1: Difficulty Filter Not Working

**Problem:**  
When clicking on a difficulty filter (e.g., "Advanced") in ManageWorkoutsView, the filter was selected but the template list was not being filtered.

**Root Cause:**  
The `filteredWorkouts` computed property in `ManageWorkoutsView` had a comment saying difficulty filtering needed backend support, but no actual client-side filtering was implemented for the already-fetched templates.

```swift
// BEFORE: No difficulty filtering
private var filteredWorkouts: [Workout] {
    var results = viewModel.workoutTemplates
    
    // Search filter
    if !searchText.isEmpty {
        results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Note: Category and difficulty filtering would need backend support
    // For now, filtering is client-side on already-fetched templates
    
    return results
}
```

**Impact:**  
- Users could select difficulty filter but see no change
- Confusing UX - filter appeared broken
- No feedback that filter was applied

---

### Issue #2: Exercises Not Displaying

**Problem:**  
When opening a workout template detail view (e.g., "Push Day Advanced"), the exercises section was showing the empty state message "No exercises added to this template yet" even though the backend was returning exercises in the API response.

**Possible Root Causes:**
1. Exercises not being saved to SwiftData during sync
2. Exercises not being loaded from SwiftData when fetching templates
3. Relationship between template and exercises not working
4. Exercise data lost during domain conversion

**Investigation Needed:**
- Track exercise count through entire flow: API → DTO → Domain → SwiftData → Domain → UI
- Verify SwiftData relationship is properly configured
- Confirm exercises are being saved with templates
- Confirm exercises are being loaded with templates

---

## ✅ Solutions Implemented

### Solution #1: Implement Client-Side Difficulty Filtering

**File:** `FitIQ/Presentation/UI/Workout/ManageWorkoutsView.swift`

**Changes:**
```swift
// AFTER: Difficulty filtering implemented
private var filteredWorkouts: [Workout] {
    var results = viewModel.workoutTemplates
    
    // Search filter
    if !searchText.isEmpty {
        results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Difficulty filter (client-side on already-fetched templates)
    if let difficulty = selectedDifficulty {
        results = results.filter { workout in
            // Get the full template to check difficulty
            guard let template = viewModel.getWorkoutTemplate(byID: workout.id) else {
                return false
            }
            return template.difficultyLevel?.rawValue.lowercased() == difficulty.lowercased()
        }
    }
    
    return results
}
```

**How It Works:**
1. For each workout in the list, fetch the full `WorkoutTemplate` from the ViewModel
2. Check if the template's `difficultyLevel` matches the selected filter
3. Case-insensitive comparison for robustness
4. Only show templates that match the selected difficulty

**Benefits:**
- ✅ Difficulty filter now works correctly
- ✅ Filters apply instantly (client-side)
- ✅ Can combine with search filter
- ✅ Clear visual feedback (filter chips show active filters)

**Note:**  
This is client-side filtering on already-synced templates. For optimal performance with large datasets, backend filtering should be implemented in the future by passing the difficulty parameter to the sync API call.

---

### Solution #2: Comprehensive Debug Logging for Exercise Tracking

Added extensive logging throughout the exercise loading pipeline to identify where exercises might be lost.

#### 2.1 ViewModel Logging

**File:** `FitIQ/Presentation/ViewModels/WorkoutViewModel.swift`

**Changes:**
```swift
@MainActor
func loadRealTemplates() async {
    guard let fetchWorkoutTemplatesUseCase = fetchWorkoutTemplatesUseCase else {
        print("WorkoutViewModel: ℹ️ fetchWorkoutTemplatesUseCase not available, using mock data")
        return
    }
    
    do {
        print("WorkoutViewModel: 📋 Loading workout templates from local storage...")
        _realWorkoutTemplates = try await fetchWorkoutTemplatesUseCase.execute(
            source: nil,
            category: nil,
            difficulty: nil
        )
        print("WorkoutViewModel: ✅ Loaded \(_realWorkoutTemplates.count) templates")
        
        // Debug: Log exercise counts for each template
        for template in _realWorkoutTemplates {
            print(
                "  - '\(template.name)': \(template.exercises.count) exercises (exerciseCount field: \(template.exerciseCount))"
            )
        }
    } catch {
        workoutError = "Failed to load templates: \(error.localizedDescription)"
        print("WorkoutViewModel: ❌ Failed to load templates: \(error.localizedDescription)")
    }
}
```

**What It Logs:**
- Total number of templates loaded
- For each template:
  - Template name
  - Actual exercises array count
  - exerciseCount field value (for comparison)

**Purpose:**
Verify that exercises are making it to the ViewModel layer with the correct counts.

---

#### 2.2 Repository Domain Conversion Logging

**File:** `FitIQ/Infrastructure/Repositories/SwiftDataWorkoutTemplateRepository.swift`

**Changes:**
```swift
extension SDWorkoutTemplate {
    /// Convert SwiftData model to domain model
    func toDomain() -> WorkoutTemplate {
        let exercisesArray = self.exercises?.map { $0.toDomain() } ?? []
        
        print("SwiftDataWorkoutTemplateRepository.toDomain: Converting '\(self.name)'")
        print("  - SwiftData exercises count: \(self.exercises?.count ?? 0)")
        print("  - Mapped exercises count: \(exercisesArray.count)")
        
        return WorkoutTemplate(
            id: self.id,
            userID: self.userProfile?.id.uuidString,
            name: self.name,
            description: self.templateDescription,
            category: self.category,
            difficultyLevel: self.difficultyLevel.flatMap { DifficultyLevel(rawValue: $0) },
            estimatedDurationMinutes: self.estimatedDurationMinutes,
            isPublic: self.isPublic,
            isSystem: self.isSystem,
            status: TemplateStatus(rawValue: self.status) ?? .draft,
            exerciseCount: self.exercises?.count ?? 0,
            exercises: exercisesArray,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            isFavorite: self.isFavorite,
            isFeatured: self.isFeatured,
            backendID: self.backendID,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .pending
        )
    }
}
```

**What It Logs:**
- Template name being converted
- Number of exercises in SwiftData model
- Number of exercises after mapping to domain

**Purpose:**
Verify that:
1. SwiftData relationship is loading exercises
2. Mapping to domain models is working
3. No exercises are lost during conversion

---

#### 2.3 Repository Batch Save Logging

**File:** `FitIQ/Infrastructure/Repositories/SwiftDataWorkoutTemplateRepository.swift`

**Changes:**
```swift
func batchSave(templates: [WorkoutTemplate]) async throws {
    print("SwiftDataWorkoutTemplateRepository: Batch saving \(templates.count) templates")
    
    for template in templates {
        print("  - Saving '\(template.name)' with \(template.exercises.count) exercises")
        
        // ... existing save logic ...
        
        if /* creating new template */ {
            print("    - Creating new template with \(template.exercises.count) exercises")
            for exercise in template.exercises {
                let sdExercise = SDTemplateExercise(...)
                modelContext.insert(sdExercise)
                print(
                    "      - Added exercise: \(exercise.exerciseName) (order: \(exercise.orderIndex))"
                )
            }
        }
    }
    
    try modelContext.save()
    print(
        "SwiftDataWorkoutTemplateRepository: ✅ Batch save completed for \(templates.count) templates"
    )
    
    // Verify exercises were saved
    for template in templates {
        if let savedTemplate = try? await fetchByID(template.id) {
            print(
                "  - Verified '\(savedTemplate.name)': \(savedTemplate.exercises.count) exercises in DB"
            )
        }
    }
    
    print("SwiftDataWorkoutTemplateRepository: ✅ Batch saved \(templates.count) templates")
}
```

**What It Logs:**
- Number of templates being saved
- For each template:
  - Template name
  - Number of exercises being saved
  - Each individual exercise being added (name and order)
- After save, verification of exercise count in database

**Purpose:**
Verify that:
1. Exercises are being saved to SwiftData
2. All exercises from API response are being persisted
3. Exercises can be read back after save (verification step)

---

## 📊 Debug Flow Example

When syncing templates and opening a template detail view, you'll now see comprehensive logging:

### 1. During Sync (API → SwiftData)
```
SyncWorkoutTemplatesUseCase: Starting template sync from backend...
SyncWorkoutTemplatesUseCase: Fetching batch - offset: 0, limit: 100
WorkoutTemplateAPIClient: ✅ Fetched 45 public templates

SwiftDataWorkoutTemplateRepository: Batch saving 45 templates
  - Saving 'Push Day Advanced' with 8 exercises
    - Creating new template with 8 exercises
      - Added exercise: Bench Press (order: 0)
      - Added exercise: Incline Dumbbell Press (order: 1)
      - Added exercise: Cable Flyes (order: 2)
      - Added exercise: Overhead Press (order: 3)
      - Added exercise: Lateral Raises (order: 4)
      - Added exercise: Tricep Pushdowns (order: 5)
      - Added exercise: Overhead Tricep Extension (order: 6)
      - Added exercise: Diamond Push-ups (order: 7)
  - Saving 'Pull Day Intermediate' with 6 exercises
    ... (similar output for each template)

SwiftDataWorkoutTemplateRepository: ✅ Batch save completed for 45 templates
  - Verified 'Push Day Advanced': 8 exercises in DB
  - Verified 'Pull Day Intermediate': 6 exercises in DB
  ... (verification for each template)
```

### 2. During Load (SwiftData → ViewModel)
```
WorkoutViewModel: 📋 Loading workout templates from local storage...

SwiftDataWorkoutTemplateRepository.toDomain: Converting 'Push Day Advanced'
  - SwiftData exercises count: 8
  - Mapped exercises count: 8

SwiftDataWorkoutTemplateRepository.toDomain: Converting 'Pull Day Intermediate'
  - SwiftData exercises count: 6
  - Mapped exercises count: 6

WorkoutViewModel: ✅ Loaded 45 templates
  - 'Push Day Advanced': 8 exercises (exerciseCount field: 8)
  - 'Pull Day Intermediate': 6 exercises (exerciseCount field: 6)
  ... (all templates listed)
```

### 3. When Opening Detail View
```
WorkoutViewModel: ✅ Found template 'Push Day Advanced' with 8 exercises
```

### 4. If Template Not Found
```
WorkoutViewModel: ⚠️ Template not found with ID: [UUID]
WorkoutViewModel: Available templates: [UUID1, UUID2, UUID3, ...]
```

---

## 🔍 Troubleshooting Guide

### If Exercises Still Not Showing

Use the debug logs to identify where exercises are being lost:

#### Scenario A: Exercises Lost During API Fetch
**Symptoms:**
```
SwiftDataWorkoutTemplateRepository: Batch saving 45 templates
  - Saving 'Push Day Advanced' with 0 exercises  ❌ Problem here!
```

**Root Cause:** API response not including exercises, or DTO conversion failing

**Next Steps:**
1. Check API response in network layer logs
2. Verify `WorkoutTemplateResponse.exercises` is populated
3. Check DTO `toDomain()` method in `WorkoutTemplateDTOs.swift`

---

#### Scenario B: Exercises Not Saved to SwiftData
**Symptoms:**
```
SwiftDataWorkoutTemplateRepository: ✅ Batch save completed for 45 templates
  - Verified 'Push Day Advanced': 0 exercises in DB  ❌ Problem here!
```

**Root Cause:** SwiftData relationship not working or exercises not being inserted

**Next Steps:**
1. Check SwiftData model relationship (`@Relationship` configuration)
2. Verify `SDTemplateExercise.template` inverse relationship
3. Check if `modelContext.insert()` is being called for exercises
4. Verify `modelContext.save()` is called after inserting

---

#### Scenario C: Exercises Not Loaded from SwiftData
**Symptoms:**
```
SwiftDataWorkoutTemplateRepository.toDomain: Converting 'Push Day Advanced'
  - SwiftData exercises count: 0  ❌ Problem here!
  - Mapped exercises count: 0
```

**Root Cause:** SwiftData not loading exercises relationship

**Next Steps:**
1. Check if `@Relationship` is properly configured
2. Verify fetch descriptor is not limiting relationships
3. Check if SwiftData lazy loading is causing issues
4. Try explicitly fetching with relationships included

---

#### Scenario D: Exercises Lost During Domain Conversion
**Symptoms:**
```
SwiftDataWorkoutTemplateRepository.toDomain: Converting 'Push Day Advanced'
  - SwiftData exercises count: 8  ✅ Good!
  - Mapped exercises count: 0  ❌ Problem here!
```

**Root Cause:** Issue in `SDTemplateExercise.toDomain()` method

**Next Steps:**
1. Check `SDTemplateExercise` extension's `toDomain()` method
2. Verify all required fields are being mapped
3. Check for nil values causing filtering/dropping of exercises

---

#### Scenario E: Exercises Not Reaching ViewModel
**Symptoms:**
```
SwiftDataWorkoutTemplateRepository.toDomain: Converting 'Push Day Advanced'
  - SwiftData exercises count: 8  ✅ Good!
  - Mapped exercises count: 8  ✅ Good!

WorkoutViewModel: ✅ Loaded 45 templates
  - 'Push Day Advanced': 0 exercises (exerciseCount field: 8)  ❌ Problem here!
```

**Root Cause:** Issue in use case or ViewModel receiving data

**Next Steps:**
1. Check `FetchWorkoutTemplatesUseCase` is passing exercises
2. Verify ViewModel is storing complete templates
3. Check if any filtering/mapping is dropping exercises

---

#### Scenario F: Template Not Found by ID
**Symptoms:**
```
WorkoutViewModel: ⚠️ Template not found with ID: [UUID]
WorkoutViewModel: Available templates: [UUID1, UUID2, UUID3, ...]
```

**Root Cause:** UI model (Workout) ID doesn't match domain model (WorkoutTemplate) ID

**Next Steps:**
1. Check how `Workout` UI model gets its ID
2. Verify ID is preserved when converting from `WorkoutTemplate` to `Workout`
3. Check `workoutTemplates` computed property in ViewModel

---

## 📊 Expected Behavior

### After These Fixes

1. **Difficulty Filter:**
   - Selecting "Advanced" → Only advanced templates show
   - Selecting "Beginner" → Only beginner templates show
   - Clear filter → All templates show again
   - Filter chips appear showing active filters

2. **Exercise Display:**
   - Console logs show exercise counts at each step
   - Exercises count should match through entire pipeline
   - Opening template detail shows exercises or clear empty state
   - Can track exactly where exercises might be lost (if any)

---

## 🚀 Next Steps

### If Exercises Still Not Showing After Logging

1. **Run the app** and trigger a sync
2. **Check console output** for the entire flow
3. **Identify which scenario** matches the logs (A, B, C, D, E, or F)
4. **Follow troubleshooting guide** for that scenario
5. **Report findings** with relevant log excerpts

### Future Improvements

1. **Server-Side Filtering:**
   - Pass difficulty parameter to backend API during sync
   - Reduce number of templates fetched
   - Faster initial load

2. **Exercise Count Validation:**
   - Add warning if `exerciseCount` doesn't match `exercises.count`
   - Alert if exercises are missing unexpectedly
   - Auto-sync if count mismatch detected

3. **Caching Strategy:**
   - Cache template list separately from exercise details
   - Lazy-load exercises only when needed
   - Reduce memory footprint for large template libraries

---

## ✅ Files Modified

1. `FitIQ/Presentation/UI/Workout/ManageWorkoutsView.swift`
   - Implemented client-side difficulty filtering

2. `FitIQ/Presentation/ViewModels/WorkoutViewModel.swift`
   - Added exercise count logging in `loadRealTemplates()`

3. `FitIQ/Infrastructure/Repositories/SwiftDataWorkoutTemplateRepository.swift`
   - Added logging to `toDomain()` conversion
   - Added logging to `batchSave()` method
   - Added post-save verification

---

**End of Document**