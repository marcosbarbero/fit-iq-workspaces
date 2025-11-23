//
//  ConfirmPhotoRecognitionUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Use case for confirming photo recognition and creating meal log
//

import Foundation

// MARK: - Protocol

/// Use case for confirming photo recognition and creating meal log
protocol ConfirmPhotoRecognitionUseCase {
    /// Confirm photo recognition and create meal log from recognized items
    /// - Parameters:
    ///   - photoRecognitionID: The photo recognition ID
    ///   - confirmedItems: User-confirmed/edited food items
    ///   - notes: Optional notes to add/update
    /// - Returns: The created meal log
    func execute(
        photoRecognitionID: UUID,
        confirmedItems: [ConfirmedFoodItem],
        notes: String?
    ) async throws -> MealLog
}

// MARK: - Implementation

final class ConfirmPhotoRecognitionUseCaseImpl: ConfirmPhotoRecognitionUseCase {

    // MARK: - Dependencies

    private let photoRecognitionAPI: PhotoRecognitionAPIProtocol
    private let photoRecognitionRepository: PhotoRecognitionRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        photoRecognitionAPI: PhotoRecognitionAPIProtocol,
        photoRecognitionRepository: PhotoRecognitionRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.photoRecognitionAPI = photoRecognitionAPI
        self.photoRecognitionRepository = photoRecognitionRepository
        self.authManager = authManager
    }

    // MARK: - ConfirmPhotoRecognitionUseCase Implementation

    func execute(
        photoRecognitionID: UUID,
        confirmedItems: [ConfirmedFoodItem],
        notes: String? = nil
    ) async throws -> MealLog {
        print(
            "ConfirmPhotoRecognitionUseCase: Confirming photo recognition - ID: \(photoRecognitionID)"
        )
        print("ConfirmPhotoRecognitionUseCase: Confirmed items count: \(confirmedItems.count)")

        // 1. Validate user authentication
        guard authManager.currentUserProfileID != nil else {
            print("ConfirmPhotoRecognitionUseCase: ❌ User not authenticated")
            throw ConfirmPhotoRecognitionError.userNotAuthenticated
        }

        // 2. Validate confirmed items
        guard !confirmedItems.isEmpty else {
            print("ConfirmPhotoRecognitionUseCase: ❌ No items to confirm")
            throw ConfirmPhotoRecognitionError.noItemsToConfirm
        }

        // 3. Get photo recognition from local storage
        guard
            let photoRecognition = try await photoRecognitionRepository.fetchByID(
                photoRecognitionID)
        else {
            print("ConfirmPhotoRecognitionUseCase: ❌ Photo recognition not found")
            throw ConfirmPhotoRecognitionError.photoRecognitionNotFound
        }

        // 4. Validate photo recognition status
        guard photoRecognition.status == .completed else {
            print(
                "ConfirmPhotoRecognitionUseCase: ❌ Photo recognition not completed - Status: \(photoRecognition.status.rawValue)"
            )
            throw ConfirmPhotoRecognitionError.photoRecognitionNotCompleted
        }

        // 5. Validate not already confirmed
        guard photoRecognition.mealLogID == nil else {
            print("ConfirmPhotoRecognitionUseCase: ❌ Photo recognition already confirmed")
            throw ConfirmPhotoRecognitionError.alreadyConfirmed
        }

        // 6. Get backend ID
        guard let backendID = photoRecognition.backendID else {
            print("ConfirmPhotoRecognitionUseCase: ❌ No backend ID")
            throw ConfirmPhotoRecognitionError.notSynced
        }

        // 7. Confirm via backend API
        do {
            let mealLog = try await photoRecognitionAPI.confirmPhotoRecognition(
                id: backendID,
                confirmedItems: confirmedItems,
                notes: notes
            )

            print(
                "ConfirmPhotoRecognitionUseCase: ✅ Photo recognition confirmed - Meal log ID: \(mealLog.id)"
            )

            // 8. Update photo recognition status to confirmed and link to meal log
            _ = try await photoRecognitionRepository.markAsConfirmed(
                photoRecognitionID,
                mealLogID: mealLog.id
            )

            print("ConfirmPhotoRecognitionUseCase: ✅ Photo recognition marked as confirmed locally")

            return mealLog

        } catch let error as PhotoRecognitionAPIError {
            print("ConfirmPhotoRecognitionUseCase: ❌ API error: \(error.localizedDescription)")
            throw ConfirmPhotoRecognitionError.confirmationFailed(error)
        } catch {
            print("ConfirmPhotoRecognitionUseCase: ❌ Unexpected error: \(error)")
            throw ConfirmPhotoRecognitionError.unknownError(error)
        }
    }
}

// MARK: - Errors

enum ConfirmPhotoRecognitionError: Error, LocalizedError {
    case userNotAuthenticated
    case noItemsToConfirm
    case photoRecognitionNotFound
    case photoRecognitionNotCompleted
    case alreadyConfirmed
    case notSynced
    case confirmationFailed(PhotoRecognitionAPIError)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .noItemsToConfirm:
            return "No items to confirm"
        case .photoRecognitionNotFound:
            return "Photo recognition not found"
        case .photoRecognitionNotCompleted:
            return "Photo recognition is not completed yet"
        case .alreadyConfirmed:
            return "Photo recognition already confirmed"
        case .notSynced:
            return "Photo recognition not synced to backend"
        case .confirmationFailed(let apiError):
            return "Confirmation failed: \(apiError.localizedDescription)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
