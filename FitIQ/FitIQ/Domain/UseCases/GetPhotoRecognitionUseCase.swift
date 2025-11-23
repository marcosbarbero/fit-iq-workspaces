//
//  GetPhotoRecognitionUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Use case for retrieving photo recognition results
//

import Foundation

// MARK: - Protocol

/// Use case for getting photo recognition results
protocol GetPhotoRecognitionUseCase {
    /// Get photo recognition by ID with latest results from backend
    /// - Parameter id: The photo recognition ID
    /// - Returns: The photo recognition with recognition results
    func execute(id: UUID) async throws -> PhotoRecognition

    /// Get photo recognition from local storage only
    /// - Parameter id: The photo recognition ID
    /// - Returns: The photo recognition if found locally
    func executeLocal(id: UUID) async throws -> PhotoRecognition?
}

// MARK: - Implementation

final class GetPhotoRecognitionUseCaseImpl: GetPhotoRecognitionUseCase {

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

    // MARK: - GetPhotoRecognitionUseCase Implementation

    func execute(id: UUID) async throws -> PhotoRecognition {
        print("GetPhotoRecognitionUseCase: Fetching photo recognition - ID: \(id)")

        // 1. Validate user authentication
        guard authManager.currentUserProfileID != nil else {
            print("GetPhotoRecognitionUseCase: ❌ User not authenticated")
            throw GetPhotoRecognitionError.userNotAuthenticated
        }

        // 2. Get from local storage first
        guard let localPhotoRecognition = try await photoRecognitionRepository.fetchByID(id) else {
            print("GetPhotoRecognitionUseCase: ❌ Photo recognition not found locally")
            throw GetPhotoRecognitionError.notFound
        }

        // 3. If processing is complete or failed, return local version
        if localPhotoRecognition.status == .completed
            || localPhotoRecognition.status == .failed
            || localPhotoRecognition.status == .confirmed
        {
            print("GetPhotoRecognitionUseCase: ✅ Returning completed local photo recognition")
            return localPhotoRecognition
        }

        // 4. If still processing, fetch from backend for latest status
        guard let backendID = localPhotoRecognition.backendID else {
            print("GetPhotoRecognitionUseCase: ⚠️ No backend ID, returning local version")
            return localPhotoRecognition
        }

        do {
            print("GetPhotoRecognitionUseCase: Fetching latest from backend - ID: \(backendID)")
            let updatedPhotoRecognition = try await photoRecognitionAPI.getPhotoRecognition(
                id: backendID)

            print(
                "GetPhotoRecognitionUseCase: ✅ Fetched from backend - Status: \(updatedPhotoRecognition.status.rawValue)"
            )

            // 5. Update local storage with latest data
            let saved = try await photoRecognitionRepository.update(updatedPhotoRecognition)

            print("GetPhotoRecognitionUseCase: ✅ Updated local storage")

            return saved

        } catch let error as PhotoRecognitionAPIError {
            print("GetPhotoRecognitionUseCase: ❌ API error: \(error.localizedDescription)")
            print("GetPhotoRecognitionUseCase: ⚠️ Falling back to local version")
            return localPhotoRecognition
        } catch {
            print("GetPhotoRecognitionUseCase: ❌ Unexpected error: \(error)")
            print("GetPhotoRecognitionUseCase: ⚠️ Falling back to local version")
            return localPhotoRecognition
        }
    }

    func executeLocal(id: UUID) async throws -> PhotoRecognition? {
        print("GetPhotoRecognitionUseCase: Fetching from local storage only - ID: \(id)")

        // Validate user authentication
        guard authManager.currentUserProfileID != nil else {
            print("GetPhotoRecognitionUseCase: ❌ User not authenticated")
            throw GetPhotoRecognitionError.userNotAuthenticated
        }

        let photoRecognition = try await photoRecognitionRepository.fetchByID(id)

        if photoRecognition != nil {
            print("GetPhotoRecognitionUseCase: ✅ Found in local storage")
        } else {
            print("GetPhotoRecognitionUseCase: ⚠️ Not found in local storage")
        }

        return photoRecognition
    }
}

// MARK: - Errors

enum GetPhotoRecognitionError: Error, LocalizedError {
    case userNotAuthenticated
    case notFound
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .notFound:
            return "Photo recognition not found"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
