//
//  PhotoRecognitionViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  ViewModel for photo-based meal logging functionality
//

import Foundation
import Observation
import SwiftUI
import UIKit

// MARK: - UI Model (Adapter from Domain Model)

/// UI-friendly representation of PhotoRecognition for display
struct PhotoRecognitionUIModel: Identifiable {
    let id: UUID
    let imageURL: String?
    let mealType: MealType
    let status: PhotoRecognitionStatus
    let confidenceScore: Double?
    let needsReview: Bool
    let recognizedItems: [RecognizedFoodItemUIModel]
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let totalFiberG: Double?
    let totalSugarG: Double?
    let loggedAt: Date
    let notes: String?
    let errorMessage: String?
    let processingStartedAt: Date?
    let processingCompletedAt: Date?
    let createdAt: Date
    let backendID: String?
    let syncStatus: SyncStatus
    let mealLogID: UUID?

    // MARK: - UI Helper Properties

    /// Returns true if the photo is still being processed
    var isProcessing: Bool {
        status == .pending || status == .processing
    }

    /// Returns true if the recognition is complete
    var isCompleted: Bool {
        status == .completed
    }

    /// Returns true if the recognition failed
    var isFailed: Bool {
        status == .failed
    }

    /// Returns true if the user confirmed and created meal log
    var isConfirmed: Bool {
        status == .confirmed
    }

    /// Returns user-friendly status text for display
    var statusText: String {
        switch status {
        case .pending:
            return "Uploading..."
        case .processing:
            return "Analyzing photo..."
        case .completed:
            return "Review results"
        case .failed:
            return "Analysis failed"
        case .confirmed:
            return "Logged"
        }
    }

    /// Returns status icon for display
    var statusIcon: String {
        switch status {
        case .pending, .processing:
            return "hourglass"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .confirmed:
            return "checkmark.seal.fill"
        }
    }

    /// Returns status color for display
    var statusColor: Color {
        switch status {
        case .pending, .processing:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .confirmed:
            return .blue
        }
    }

    /// Returns confidence level description
    var confidenceDescription: String {
        guard let score = confidenceScore else { return "Unknown" }

        if score >= 0.9 {
            return "Very High"
        } else if score >= 0.7 {
            return "High"
        } else if score >= 0.5 {
            return "Medium"
        } else if score >= 0.3 {
            return "Low"
        } else {
            return "Very Low"
        }
    }

    /// Returns formatted confidence score for display
    var confidenceText: String {
        guard let score = confidenceScore else { return "N/A" }
        return String(format: "%.0f%%", score * 100)
    }
}

/// UI-friendly representation of RecognizedFoodItem for display
struct RecognizedFoodItemUIModel: Identifiable {
    let id: UUID
    let name: String
    let quantity: Double
    let unit: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let confidenceScore: Double
    let confidenceLevel: PhotoConfidenceLevel
    let orderIndex: Int

    // MARK: - UI Helper Properties

    /// Formatted quantity with unit for display
    var quantityText: String {
        String(format: "%.1f %@", quantity, unit)
    }

    /// Returns confidence level description
    var confidenceDescription: String {
        switch confidenceLevel {
        case .veryHigh:
            return "Very High"
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        case .veryLow:
            return "Very Low"
        }
    }

    /// Returns confidence color for display
    var confidenceColor: Color {
        switch confidenceLevel {
        case .veryHigh:
            return .green
        case .high:
            return .blue
        case .medium:
            return .orange
        case .low, .veryLow:
            return .red
        }
    }

    /// Returns formatted confidence score for display
    var confidenceText: String {
        String(format: "%.0f%%", confidenceScore * 100)
    }

    /// Returns formatted nutrition summary
    var nutritionSummary: String {
        var parts: [String] = []
        parts.append("\(calories) cal")
        parts.append(String(format: "P: %.1fg", proteinG))
        parts.append(String(format: "C: %.1fg", carbsG))
        parts.append(String(format: "F: %.1fg", fatG))
        return parts.joined(separator: " • ")
    }
}

// MARK: - Domain to UI Model Conversion

extension PhotoRecognition {
    func toUIModel() -> PhotoRecognitionUIModel {
        PhotoRecognitionUIModel(
            id: id,
            imageURL: imageURL,
            mealType: mealType,
            status: status,
            confidenceScore: confidenceScore,
            needsReview: needsReview,
            recognizedItems: recognizedItems.map { $0.toUIModel() },
            totalCalories: totalCalories,
            totalProteinG: totalProteinG,
            totalCarbsG: totalCarbsG,
            totalFatG: totalFatG,
            totalFiberG: totalFiberG,
            totalSugarG: totalSugarG,
            loggedAt: loggedAt,
            notes: notes,
            errorMessage: errorMessage,
            processingStartedAt: processingStartedAt,
            processingCompletedAt: processingCompletedAt,
            createdAt: createdAt,
            backendID: backendID,
            syncStatus: syncStatus,
            mealLogID: mealLogID
        )
    }
}

extension PhotoRecognizedFoodItem {
    func toUIModel() -> RecognizedFoodItemUIModel {
        RecognizedFoodItemUIModel(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            sugarG: sugarG,
            confidenceScore: confidenceScore,
            confidenceLevel: confidenceLevel,
            orderIndex: orderIndex
        )
    }
}

// MARK: - ViewModel

/// ViewModel for photo-based meal logging
/// Handles photo upload, recognition status polling, and confirmation
@Observable
@MainActor
final class PhotoRecognitionViewModel {

    // MARK: - State

    /// Current photo recognitions (filtered by status if needed)
    var photoRecognitions: [PhotoRecognitionUIModel] = []

    /// Currently selected photo recognition for viewing/editing
    var selectedPhotoRecognition: PhotoRecognitionUIModel?

    /// Loading state for async operations
    var isLoading = false

    /// Upload progress (0.0 to 1.0)
    var uploadProgress: Double = 0.0

    /// Error message for display
    var errorMessage: String?

    /// Success message for display
    var successMessage: String?

    /// Whether to show error alert
    var showErrorAlert = false

    /// Whether to show success alert
    var showSuccessAlert = false

    /// Filter status for listing
    var filterStatus: PhotoRecognitionStatus?

    /// Editable items during confirmation (user can modify)
    var editableItems: [EditableFoodItem] = []

    /// Notes during confirmation
    var confirmationNotes: String = ""

    // MARK: - Dependencies

    private let uploadMealPhotoUseCase: UploadMealPhotoUseCase
    private let getPhotoRecognitionUseCase: GetPhotoRecognitionUseCase
    private let confirmPhotoRecognitionUseCase: ConfirmPhotoRecognitionUseCase

    // MARK: - Initialization

    init(
        uploadMealPhotoUseCase: UploadMealPhotoUseCase,
        getPhotoRecognitionUseCase: GetPhotoRecognitionUseCase,
        confirmPhotoRecognitionUseCase: ConfirmPhotoRecognitionUseCase
    ) {
        self.uploadMealPhotoUseCase = uploadMealPhotoUseCase
        self.getPhotoRecognitionUseCase = getPhotoRecognitionUseCase
        self.confirmPhotoRecognitionUseCase = confirmPhotoRecognitionUseCase
    }

    // MARK: - Actions

    /// Upload photo and start recognition
    func uploadPhoto(
        image: UIImage,
        mealType: MealType,
        notes: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        uploadProgress = 0.0

        do {
            // Simulate upload progress (actual progress would come from network layer)
            uploadProgress = 0.3

            // Upload photo (use case handles image conversion internally)
            let photoRecognition = try await uploadMealPhotoUseCase.execute(
                image: image,
                mealType: mealType,
                loggedAt: Date(),
                notes: notes
            )

            uploadProgress = 1.0

            // Add to list
            photoRecognitions.insert(photoRecognition.toUIModel(), at: 0)

            // Set as selected for review (backend returns immediate results)
            selectedPhotoRecognition = photoRecognition.toUIModel()

            // Backend processes synchronously - results are already complete!
            print("PhotoRecognitionViewModel: ✅ Recognition complete!")
            print(
                "PhotoRecognitionViewModel: Recognized \(photoRecognition.recognizedItems.count) items"
            )
            print(
                "PhotoRecognitionViewModel: Total calories: \(photoRecognition.totalCalories ?? 0)")
            print(
                "PhotoRecognitionViewModel: Overall confidence: \(Int((photoRecognition.confidenceScore ?? 0) * 100))%"
            )

            successMessage =
                "Recognized \(photoRecognition.recognizedItems.count) items! Review and confirm."
            showSuccessAlert = true

        } catch let error as PhotoRecognitionError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            showErrorAlert = true
        }

        isLoading = false
        uploadProgress = 0.0
    }

    /// Poll for recognition results (called automatically after upload)
    private func pollForResults(photoRecognitionID: UUID) async {
        var pollCount = 0
        let maxPolls = 30  // 30 seconds max (1 poll per second)

        while pollCount < maxPolls {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

                let photoRecognition = try await getPhotoRecognitionUseCase.execute(
                    id: photoRecognitionID
                )

                // Update in list
                if let index = photoRecognitions.firstIndex(where: { $0.id == photoRecognitionID })
                {
                    photoRecognitions[index] = photoRecognition.toUIModel()
                }

                // Update selected if it's the same one
                if selectedPhotoRecognition?.id == photoRecognitionID {
                    selectedPhotoRecognition = photoRecognition.toUIModel()
                }

                // Check if completed or failed
                if photoRecognition.status == .completed {
                    successMessage = "Recognition complete! Review the results."
                    showSuccessAlert = true

                    // Prepare editable items for confirmation
                    prepareEditableItems(from: photoRecognition)
                    break
                } else if photoRecognition.status == .failed {
                    errorMessage = photoRecognition.errorMessage ?? "Recognition failed"
                    showErrorAlert = true
                    break
                }

                pollCount += 1

            } catch {
                // Continue polling on error (might be temporary network issue)
                pollCount += 1
            }
        }

        if pollCount >= maxPolls {
            errorMessage = "Recognition is taking longer than expected. Please check back later."
            showErrorAlert = true
        }
    }

    /// Fetch photo recognition by ID (for manual refresh)
    func fetchPhotoRecognition(id: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let photoRecognition = try await getPhotoRecognitionUseCase.execute(id: id)

            // Update in list
            if let index = photoRecognitions.firstIndex(where: { $0.id == id }) {
                photoRecognitions[index] = photoRecognition.toUIModel()
            }

            // Update selected if it's the same one
            if selectedPhotoRecognition?.id == id {
                selectedPhotoRecognition = photoRecognition.toUIModel()

                // Prepare editable items if completed
                if photoRecognition.status == .completed {
                    prepareEditableItems(from: photoRecognition)
                }
            }

        } catch let error as PhotoRecognitionError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to fetch photo recognition: \(error.localizedDescription)"
            showErrorAlert = true
        }

        isLoading = false
    }

    /// Prepare editable items from recognition results
    private func prepareEditableItems(from photoRecognition: PhotoRecognition) {
        editableItems = photoRecognition.recognizedItems.map { item in
            EditableFoodItem(
                id: item.id,
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                calories: Double(item.calories),
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                fiberG: item.fiberG,
                sugarG: item.sugarG,
                isIncluded: true  // All items included by default
            )
        }

        confirmationNotes = photoRecognition.notes ?? ""
    }

    /// Confirm photo recognition and create meal log
    func confirmRecognition(photoRecognitionID: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // Convert editable items to confirmed items (only included ones)
            let confirmedItems =
                editableItems
                .filter { $0.isIncluded }
                .map { item in
                    ConfirmedFoodItem(
                        name: item.name,
                        quantity: item.quantity,
                        unit: item.unit,
                        calories: Int(item.calories),
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG,
                        fiberG: item.fiberG,
                        sugarG: item.sugarG
                    )
                }

            // Confirm recognition
            let mealLog = try await confirmPhotoRecognitionUseCase.execute(
                photoRecognitionID: photoRecognitionID,
                confirmedItems: confirmedItems,
                notes: confirmationNotes.isEmpty ? nil : confirmationNotes
            )

            // Update status to confirmed
            if let index = photoRecognitions.firstIndex(where: { $0.id == photoRecognitionID }) {
                var updatedRecognition = photoRecognitions[index]
                // Create a new instance with updated status (since it's a struct)
                photoRecognitions[index] = PhotoRecognitionUIModel(
                    id: updatedRecognition.id,
                    imageURL: updatedRecognition.imageURL,
                    mealType: updatedRecognition.mealType,
                    status: .confirmed,
                    confidenceScore: updatedRecognition.confidenceScore,
                    needsReview: false,
                    recognizedItems: updatedRecognition.recognizedItems,
                    totalCalories: updatedRecognition.totalCalories,
                    totalProteinG: updatedRecognition.totalProteinG,
                    totalCarbsG: updatedRecognition.totalCarbsG,
                    totalFatG: updatedRecognition.totalFatG,
                    totalFiberG: updatedRecognition.totalFiberG,
                    totalSugarG: updatedRecognition.totalSugarG,
                    loggedAt: updatedRecognition.loggedAt,
                    notes: confirmationNotes.isEmpty ? updatedRecognition.notes : confirmationNotes,
                    errorMessage: updatedRecognition.errorMessage,
                    processingStartedAt: updatedRecognition.processingStartedAt,
                    processingCompletedAt: updatedRecognition.processingCompletedAt,
                    createdAt: updatedRecognition.createdAt,
                    backendID: updatedRecognition.backendID,
                    syncStatus: updatedRecognition.syncStatus,
                    mealLogID: mealLog.id
                )
            }

            successMessage = "Meal logged successfully!"
            showSuccessAlert = true

            // Clear selection and editable items
            selectedPhotoRecognition = nil
            editableItems = []
            confirmationNotes = ""

        } catch let error as PhotoRecognitionError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to confirm recognition: \(error.localizedDescription)"
            showErrorAlert = true
        }

        isLoading = false
    }

    /// Load photo recognitions with optional status filter
    /// Note: This is a placeholder - actual list functionality would need
    /// to be implemented in the repository layer to query SwiftData
    func loadPhotoRecognitions(status: PhotoRecognitionStatus? = nil) async {
        isLoading = true
        errorMessage = nil

        // TODO: Implement listing functionality in repository layer
        // For now, this is a placeholder that does nothing
        // In a full implementation, you would:
        // 1. Add a listAll method to PhotoRecognitionRepositoryProtocol
        // 2. Implement it in SwiftDataPhotoRecognitionRepository
        // 3. Call it here to populate photoRecognitions array

        photoRecognitions = []

        isLoading = false
    }

    /// Clear all alerts
    func clearAlerts() {
        errorMessage = nil
        successMessage = nil
        showErrorAlert = false
        showSuccessAlert = false
    }

    /// Confirm photo recognition with provided items (simplified wrapper)
    func confirmPhotoRecognition(
        id: UUID,
        confirmedItems: [ConfirmedFoodItem],
        notes: String?
    ) async throws -> MealLog {
        return try await confirmPhotoRecognitionUseCase.execute(
            photoRecognitionID: id,
            confirmedItems: confirmedItems,
            notes: notes
        )
    }
}

// MARK: - Editable Food Item

/// Editable food item for user to modify before confirmation
struct EditableFoodItem: Identifiable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double?
    var sugarG: Double?
    var isIncluded: Bool  // Whether to include in final meal log
}

// MARK: - Errors

enum PhotoRecognitionError: Error, LocalizedError {
    case imageConversionFailed
    case uploadFailed
    case recognitionFailed
    case confirmationFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image. Please try a different photo."
        case .uploadFailed:
            return "Failed to upload photo. Please check your connection and try again."
        case .recognitionFailed:
            return "AI recognition failed. Please try again with a clearer photo."
        case .confirmationFailed:
            return "Failed to confirm recognition. Please try again."
        case .notFound:
            return "Photo recognition not found."
        }
    }
}
