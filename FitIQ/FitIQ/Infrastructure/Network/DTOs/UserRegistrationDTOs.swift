//
//  UserRegistrationDTOs.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation

// MARK: - Registration Request DTO (matches new FitIQ API)

struct CreateUserRequest: Encodable {
    let email: String
    let password: String
    let name: String
    let dateOfBirth: String  // Format: "YYYY-MM-DD"

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case name
        case dateOfBirth = "date_of_birth"
    }
}

// MARK: - Registration Response DTO (matches actual FitIQ API)
// Updated to match new backend flow where registration creates profile directly

struct RegisterResponse: Decodable {
    let userId: String
    let email: String
    let name: String
    let createdAt: String
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case name
        case createdAt = "created_at"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
