//
//  StandardBackendResponses.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation

/// This file contains shared DTOs and error handling for backend API interactions.

// Maps to the handlers.StandardResponse structure
struct StandardResponse<T: Decodable>: Decodable {
    let message: String?
    let data: T  // Generic type for the actual data payload (e.g., UserResponse)
}

// Basic Error Response structure (for 409, 500)
struct ErrorResponse: Decodable, Error {
    let message: String
    // APIs often include a detailed error code or field
    // let code: String?
}

// Basic Validation Error Response structure (for 400)
struct ValidationErrorResponse: Decodable, Error {
    let error: String?
    let message: String?
    let details: [String]?
}

// MARK: - API Service

// Errors
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case apiError(statusCode: Int, message: String)
    case apiError(Error)
    case unauthorized
    case notFound
    case invalidUserId
}
