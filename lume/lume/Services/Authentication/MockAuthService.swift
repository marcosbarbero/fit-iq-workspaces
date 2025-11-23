//
//  MockAuthService.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import FitIQCore
import Foundation

/// Mock authentication service for local development
/// Simulates backend behavior without requiring network connection
final class MockAuthService: AuthServiceProtocol {

    // In-memory storage of registered users
    private var registeredUsers: [String: MockRegisteredUser] = [:]

    private struct MockRegisteredUser {
        let user: User
        let password: String
        let token: AuthToken
    }

    init() {
        // Pre-register demo user
        let demoUser = MockUser.shared
        let demoToken = MockToken.shared
        registeredUsers[demoUser.email] = MockRegisteredUser(
            user: demoUser,
            password: "password123",
            token: demoToken
        )
    }

    func register(
        email: String,
        password: String,
        name: String,
        dateOfBirth: Date
    ) async throws -> (User, AuthToken) {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Check if user already exists
        if registeredUsers[email] != nil {
            throw AuthenticationError.userAlreadyExists
        }

        // Create new user
        let user = User(
            id: UUID(),
            email: email,
            name: name,
            dateOfBirth: dateOfBirth,
            createdAt: Date()
        )

        // Create token
        let token = AuthToken(
            accessToken: "mock-access-\(UUID().uuidString)",
            refreshToken: "mock-refresh-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)  // 1 hour
        )

        // Store user
        registeredUsers[email] = MockRegisteredUser(
            user: user,
            password: password,
            token: token
        )

        print("✅ [MockAuth] Registered user: \(email)")

        return (user, token)
    }

    func login(email: String, password: String) async throws -> AuthToken {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Check if user exists
        guard let registeredUser = registeredUsers[email] else {
            throw AuthenticationError.invalidCredentials
        }

        // Check password
        guard registeredUser.password == password else {
            throw AuthenticationError.invalidCredentials
        }

        // Create new token (simulate token refresh)
        let token = AuthToken(
            accessToken: "mock-access-\(UUID().uuidString)",
            refreshToken: "mock-refresh-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)  // 1 hour
        )

        // Update stored token
        registeredUsers[email] = MockRegisteredUser(
            user: registeredUser.user,
            password: registeredUser.password,
            token: token
        )

        print("✅ [MockAuth] Logged in user: \(email)")

        return token
    }

    func refreshToken(_ token: String) async throws -> AuthToken {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

        // Create new token
        let newToken = AuthToken(
            accessToken: "mock-access-\(UUID().uuidString)",
            refreshToken: "mock-refresh-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)  // 1 hour
        )

        print("✅ [MockAuth] Refreshed token")

        return newToken
    }
}
