//
//  PhotoRecognitionAPIProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Port for photo recognition remote API
//

import Foundation

/// API client protocol for photo recognition endpoints (Hexagonal Architecture Port)
///
/// Defines the contract for communicating with the backend photo recognition API.
/// This is a secondary port - the domain defines the interface, infrastructure provides the implementation.
protocol PhotoRecognitionAPIProtocol {

    // MARK: - Photo Upload & Recognition

    /// Upload photo and start AI recognition
    /// - Parameters:
    ///   - imageData: Base64-encoded image data (JPEG, PNG, or WebP format)
    ///   - mealType: Type of meal (breakfast, lunch, dinner, snack)
    ///   - loggedAt: When the meal was consumed
    ///   - notes: Optional user notes about the meal
    /// - Returns: The photo recognition entry with initial status
    func uploadPhoto(
        imageData: String,
        mealType: String,
        loggedAt: Date,
        notes: String?
    ) async throws -> PhotoRecognition

    // MARK: - Get Recognition Results

    /// Get photo recognition result by ID
    /// - Parameter id: The backend photo recognition ID
    /// - Returns: The photo recognition with recognition results
    func getPhotoRecognition(id: String) async throws -> PhotoRecognition

    /// List photo recognition history
    /// - Parameters:
    ///   - status: Optional filter by status
    ///   - startDate: Optional filter by start date
    ///   - endDate: Optional filter by end date
    ///   - limit: Maximum number of results
    ///   - offset: Number of results to skip
    /// - Returns: Array of photo recognitions with pagination info
    func listPhotoRecognitions(
        status: PhotoRecognitionStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?,
        offset: Int?
    ) async throws -> PhotoRecognitionListResult

    // MARK: - Confirm & Create Meal Log

    /// Confirm photo recognition and create meal log
    /// - Parameters:
    ///   - id: The backend photo recognition ID
    ///   - confirmedItems: User-confirmed/edited food items
    ///   - notes: Optional notes to add/update
    /// - Returns: The created meal log
    func confirmPhotoRecognition(
        id: String,
        confirmedItems: [ConfirmedFoodItem],
        notes: String?
    ) async throws -> MealLog

    // MARK: - Delete

    /// Delete photo recognition entry
    /// - Parameter id: The backend photo recognition ID
    func deletePhotoRecognition(id: String) async throws
}

// MARK: - Supporting Types

/// Result type for photo recognition list with pagination
struct PhotoRecognitionListResult {
    let recognitions: [PhotoRecognition]
    let totalCount: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - Errors

enum PhotoRecognitionAPIError: Error, LocalizedError {
    case invalidRequest
    case unauthorized
    case forbidden
    case notFound
    case methodNotAllowed
    case payloadTooLarge
    case invalidImageFormat
    case processingFailed
    case networkError(Error)
    case decodingError(Error)
    case unknownError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid photo recognition request"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Photo recognition not found"
        case .methodNotAllowed:
            return
                "Method not allowed - the photo upload endpoint may not be available yet on the backend. Please check that the backend API is up to date (version 0.32.0+)"
        case .payloadTooLarge:
            return "Image exceeds 20MB limit"
        case .invalidImageFormat:
            return "Invalid image format (must be JPEG, PNG, or WebP)"
        case .processingFailed:
            return "Photo recognition processing failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknownError(let statusCode):
            return "Unknown error (status code: \(statusCode))"
        }
    }
}
