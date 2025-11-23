# Photo Recognition Implementation Documentation

**Feature:** Meal Logging via Photo Recognition API  
**Version:** 1.0.0  
**Date:** 2025-01-28  
**Status:** ✅ Complete - Ready for Integration

---

## 📋 Overview

This document describes the implementation of the photo-based meal logging feature that integrates with the FitIQ backend's `/api/v1/meal-logs/photo` endpoint. The implementation follows **Hexagonal Architecture** principles with clear separation between Domain, Infrastructure, and Presentation layers.

---

## 🏗️ Architecture

### Layer Structure

```
Presentation Layer (ViewModels/Views)
    ↓ depends on ↓
Domain Layer (Entities, UseCases, Ports)
    ↑ implemented by ↑
Infrastructure Layer (Repositories, Network, SwiftData)
```

---

## 📁 Files Created

### 1. Domain Layer

#### Entities
- **`Domain/Entities/Nutrition/PhotoRecognitionEntities.swift`**
  - `PhotoRecognition` - Main domain entity for photo recognition
  - `RecognizedFoodItem` - AI-recognized food item from photo
  - `ConfirmedFoodItem` - User-confirmed food item for meal log creation
  - `PhotoRecognitionStatus` - Status enum (pending, processing, completed, failed, confirmed)
  - `ConfidenceLevel` - Confidence level enum for AI predictions

#### Ports (Protocols)
- **`Domain/Ports/PhotoRecognitionRepositoryProtocol.swift`**
  - Local persistence interface
  - CRUD operations for photo recognitions
  - Filtering and pagination support

- **`Domain/Ports/PhotoRecognitionAPIProtocol.swift`**
  - Remote API interface
  - Photo upload, retrieval, confirmation, deletion
  - List operations with filtering

#### Use Cases
- **`Domain/UseCases/UploadMealPhotoUseCase.swift`**
  - Protocol: `UploadMealPhotoUseCase`
  - Implementation: `UploadMealPhotoUseCaseImpl`
  - Purpose: Upload photo and start AI recognition
  - Validation: Image format, size, meal type

- **`Domain/UseCases/GetPhotoRecognitionUseCase.swift`**
  - Protocol: `GetPhotoRecognitionUseCase`
  - Implementation: `GetPhotoRecognitionUseCaseImpl`
  - Purpose: Retrieve recognition results (local-first with backend sync)
  - Supports: Single fetch and list operations

- **`Domain/UseCases/ConfirmPhotoRecognitionUseCase.swift`**
  - Protocol: `ConfirmPhotoRecognitionUseCase`
  - Implementation: `ConfirmPhotoRecognitionUseCaseImpl`
  - Purpose: Confirm recognition and create meal log
  - Features: User can modify items before confirmation

---

### 2. Infrastructure Layer

#### Persistence
- **`Infrastructure/Persistence/Schema/SchemaV9.swift`**
  - New schema version with photo recognition models
  - `SDPhotoRecognition` - SwiftData model (with `SD` prefix)
  - `SDRecognizedFoodItem` - SwiftData model for recognized items
  - `SDUserProfileV9` - Updated user profile with photo recognitions relationship

- **`Infrastructure/Persistence/Schema/SchemaDefinition.swift`**
  - Updated `CurrentSchema` typealias to `SchemaV9`
  - Added `v9` case to `FitIQSchemaDefinitition` enum

- **`Infrastructure/Persistence/Schema/PersistenceHelper.swift`**
  - Added typealiases: `SDPhotoRecognition`, `SDRecognizedFoodItem`
  - Added conversion extensions: `SDPhotoRecognition.toDomain()`, `SDRecognizedFoodItem.toDomain()`

#### Repository
- **`Infrastructure/Repositories/SwiftDataPhotoRecognitionRepository.swift`**
  - Implements `PhotoRecognitionRepositoryProtocol`
  - Full CRUD operations using SwiftData
  - Filtering by status, date range
  - Pagination support
  - Sync status management

#### Network
- **`Infrastructure/Network/PhotoRecognitionAPIClient.swift`**
  - Implements `PhotoRecognitionAPIProtocol`
  - API endpoints:
    - `POST /api/v1/meal-logs/photo` - Upload photo
    - `GET /api/v1/meal-logs/photo/{id}` - Get recognition
    - `GET /api/v1/meal-logs/photo` - List recognitions
    - `PATCH /api/v1/meal-logs/photo/{id}` - Confirm recognition
    - `DELETE /api/v1/meal-logs/photo/{id}` - Delete recognition
  - Token refresh logic (401 retry)
  - Error handling (400, 403, 404, 413, etc.)
  - DTO conversions (API <-> Domain)

---

### 3. Presentation Layer

#### ViewModel
- **`Presentation/ViewModels/PhotoRecognitionViewModel.swift`**
  - `@Observable` ViewModel following existing patterns
  - UI Models: `PhotoRecognitionUIModel`, `RecognizedFoodItemUIModel`
  - Features:
    - Photo upload with progress tracking
    - Automatic polling for recognition results (up to 30 seconds)
    - Editable items for user confirmation
    - Status filtering and listing
    - Error and success handling
  - State management:
    - `photoRecognitions` - List of recognitions
    - `selectedPhotoRecognition` - Currently viewing
    - `editableItems` - User-modifiable items before confirmation
    - `isLoading`, `errorMessage`, `successMessage`

---

### 4. Dependency Injection

- **`Infrastructure/Configuration/AppDependencies.swift`**
  - Added properties:
    ```swift
    let photoRecognitionRepository: PhotoRecognitionRepositoryProtocol
    let photoRecognitionAPIClient: PhotoRecognitionAPIProtocol
    let uploadMealPhotoUseCase: UploadMealPhotoUseCase
    let getPhotoRecognitionUseCase: GetPhotoRecognitionUseCase
    let confirmPhotoRecognitionUseCase: ConfirmPhotoRecognitionUseCase
    ```
  - Registered in `build()` method
  - Dependencies wired correctly

---

## 🔄 Data Flow

### Upload Flow

```
1. User takes/selects photo in View
   ↓
2. PhotoRecognitionViewModel.uploadPhoto()
   - Converts UIImage to base64
   - Calls UploadMealPhotoUseCase
   ↓
3. UploadMealPhotoUseCase
   - Validates image data
   - Calls PhotoRecognitionAPIClient.uploadPhoto()
   - Saves to PhotoRecognitionRepository (local)
   ↓
4. PhotoRecognitionAPIClient
   - POST /api/v1/meal-logs/photo
   - Returns PhotoRecognition with status: "pending"
   ↓
5. ViewModel starts automatic polling
   - Calls GetPhotoRecognitionUseCase every 1 second
   - Updates UI with status changes
   ↓
6. Backend processes photo (async)
   - Status: pending → processing → completed
   - Recognized items populated
   ↓
7. When status == "completed"
   - Stop polling
   - Show results to user
   - Prepare editable items for confirmation
```

### Confirmation Flow

```
1. User reviews recognized items
   - Can edit quantities, remove items
   - Can add notes
   ↓
2. User taps "Confirm"
   ↓
3. PhotoRecognitionViewModel.confirmRecognition()
   - Converts editableItems to ConfirmedFoodItem[]
   - Calls ConfirmPhotoRecognitionUseCase
   ↓
4. ConfirmPhotoRecognitionUseCase
   - Calls PhotoRecognitionAPIClient.confirmPhotoRecognition()
   - Saves returned MealLog to MealLogRepository
   ↓
5. PhotoRecognitionAPIClient
   - PATCH /api/v1/meal-logs/photo/{id}
   - Backend creates MealLog
   - Returns MealLog
   ↓
6. ViewModel updates status to "confirmed"
   - Clears selected recognition
   - Shows success message
```

---

## 🎯 Key Features

### 1. **Local-First Architecture**
- Photo recognitions saved locally immediately
- Survives app crashes
- Offline-capable (with limitations)

### 2. **Automatic Polling**
- Polls backend every 1 second after upload
- Max 30 polls (30 seconds)
- Updates UI in real-time
- Handles network failures gracefully

### 3. **User Editing**
- Users can modify recognized items before confirmation
- Can remove incorrect items
- Can adjust quantities
- Can add/edit notes

### 4. **Status Tracking**
- `pending` - Just uploaded, waiting for processing
- `processing` - AI is analyzing the photo
- `completed` - Recognition complete, awaiting user confirmation
- `failed` - Recognition failed (error message available)
- `confirmed` - User confirmed and meal log created

### 5. **Confidence Scoring**
- Overall confidence score for entire recognition
- Individual confidence scores per food item
- Confidence levels: Very High, High, Medium, Low, Very Low
- Color-coded UI indicators

---

## 🔌 API Integration

### Endpoint: `POST /api/v1/meal-logs/photo`

**Request:**
```json
{
  "image": "base64-encoded-image-data",
  "meal_type": "lunch",
  "logged_at": "2025-01-28T12:00:00Z",
  "notes": "Optional notes"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "image_url": "https://...",
    "meal_type": "lunch",
    "status": "pending",
    "confidence_score": null,
    "needs_review": true,
    "recognized_items": [],
    "total_calories": null,
    "logged_at": "2025-01-28T12:00:00Z",
    "created_at": "2025-01-28T12:00:01Z"
  }
}
```

### Endpoint: `GET /api/v1/meal-logs/photo/{id}`

**Response (after processing):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "completed",
    "confidence_score": 0.85,
    "needs_review": true,
    "recognized_items": [
      {
        "name": "Grilled Chicken Breast",
        "quantity": 200,
        "unit": "g",
        "calories": 330,
        "protein_g": 62.0,
        "carbs_g": 0.0,
        "fat_g": 7.0,
        "confidence_score": 0.92
      }
    ],
    "total_calories": 330,
    "total_protein_g": 62.0,
    ...
  }
}
```

### Endpoint: `PATCH /api/v1/meal-logs/photo/{id}`

**Request:**
```json
{
  "confirmed_items": [
    {
      "name": "Grilled Chicken Breast",
      "quantity": 200,
      "unit": "g",
      "calories": 330,
      "protein_g": 62.0,
      "carbs_g": 0.0,
      "fat_g": 7.0
    }
  ],
  "notes": "Dinner"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "meal-log-uuid",
    "user_id": "uuid",
    "raw_input": "Photo recognition",
    "meal_type": "lunch",
    "status": "completed",
    "items": [...],
    "total_calories": 330,
    ...
  }
}
```

---

## 📝 Usage Example

### In ViewModel

```swift
// Inject dependencies
let viewModel = PhotoRecognitionViewModel(
    uploadMealPhotoUseCase: appDependencies.uploadMealPhotoUseCase,
    getPhotoRecognitionUseCase: appDependencies.getPhotoRecognitionUseCase,
    confirmPhotoRecognitionUseCase: appDependencies.confirmPhotoRecognitionUseCase
)

// Upload photo
await viewModel.uploadPhoto(
    image: selectedImage,
    mealType: .lunch,
    notes: "Lunch at office"
)

// Automatic polling starts...
// When status == .completed, user reviews items

// Confirm recognition
await viewModel.confirmRecognition(
    photoRecognitionID: photoRecognition.id
)
```

---

## ✅ Testing Checklist

### Unit Tests (To Be Implemented)
- [ ] `UploadMealPhotoUseCaseTests`
  - [ ] Valid image upload
  - [ ] Invalid image format handling
  - [ ] Network error handling
- [ ] `GetPhotoRecognitionUseCaseTests`
  - [ ] Fetch by ID
  - [ ] Local-first behavior
  - [ ] Backend sync
- [ ] `ConfirmPhotoRecognitionUseCaseTests`
  - [ ] Valid confirmation
  - [ ] Empty items handling
  - [ ] Meal log creation

### Integration Tests (To Be Implemented)
- [ ] End-to-end photo upload flow
- [ ] Polling mechanism
- [ ] User confirmation flow
- [ ] Error recovery

### UI Tests (To Be Implemented)
- [ ] Photo selection
- [ ] Upload progress
- [ ] Recognition results display
- [ ] Item editing
- [ ] Confirmation success

---

## 🔄 Migration Notes

### Schema Migration: V8 → V9

**Changes:**
- Added `SDPhotoRecognition` model
- Added `SDRecognizedFoodItem` model
- Updated `SDUserProfile` to `SDUserProfileV9` with `photoRecognitions` relationship

**SwiftData handles migration automatically** for this case since:
- No existing data needs transformation
- Only additive changes (new models, new relationship)
- All new properties have default values

**If issues occur:**
1. Clear app data (development only)
2. Reinstall app
3. SwiftData will create fresh schema

---

## 🚀 Next Steps

### 1. **UI Implementation** (Required)
- [ ] Create `PhotoRecognitionView` for uploading photos
- [ ] Create `RecognitionResultsView` for reviewing items
- [ ] Create `ConfirmationView` for editing items
- [ ] Add photo recognition to main navigation

### 2. **Testing** (Recommended)
- [ ] Write unit tests for use cases
- [ ] Write integration tests for API client
- [ ] Write UI tests for critical flows

### 3. **Enhancements** (Future)
- [ ] Image compression optimization
- [ ] Offline queue for uploads
- [ ] Batch upload support
- [ ] Recognition history view
- [ ] Share recognition results

### 4. **Error Handling** (Recommended)
- [ ] Better error messages for network failures
- [ ] Retry logic for failed uploads
- [ ] User guidance for low-quality photos

---

## 🐛 Known Limitations

1. **Polling Duration**
   - Current implementation polls for max 30 seconds
   - If backend takes longer, user must manually refresh
   - **Solution:** Implement WebSocket for real-time updates

2. **Image Size**
   - No client-side image size validation yet
   - Backend has 10MB limit (413 error)
   - **Solution:** Add validation before upload

3. **Offline Support**
   - Uploads fail when offline
   - No automatic retry when connection restored
   - **Solution:** Implement outbox pattern for uploads

4. **No Image Preview**
   - Uploaded image URL expires in 24 hours
   - Can't preview image after expiration
   - **Solution:** Cache images locally

---

## 📚 References

- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Hexagonal Architecture Guide:** `.github/copilot-instructions.md`
- **Existing Meal Logging:** `NutritionViewModel.swift`
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html

---

## ✨ Summary

The photo recognition implementation is **complete and ready for UI integration**. All domain logic, infrastructure adapters, and dependency injection is in place. The architecture follows existing patterns precisely, ensuring maintainability and consistency with the rest of the codebase.

**Status:** ✅ Backend Integration Complete | ⏳ UI Implementation Pending

---

**Last Updated:** 2025-01-28  
**Version:** 1.0.0  
**Author:** AI Assistant