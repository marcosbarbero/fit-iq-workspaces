//
//  MockAuthRepository.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Mock implementation for previews and testing
//

import Foundation
import FitIQCore

/// Mock authentication repository for previews and testing
final class MockAuthRepository: AuthRepositoryProtocol {
    private var currentUser: User?
    private var currentToken: AuthToken?
    private var isAuthenticated = true

    init() {
        // Create a mock user and token for testing
        self.currentUser = User(
            id: UUID(),
            email: "test@lume.app",
            name: "Test User",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
            createdAt: Date()
        )

        self.currentToken = AuthToken(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            expiresAt: Date().addingTimeInterval(3600)
        )
    }

    func register(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> User
    {
        let user = User(
            id: UUID(),
            email: email,
            name: name,
            dateOfBirth: dateOfBirth,
            createdAt: Date()
        )
        self.currentUser = user
        self.currentToken = AuthToken(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            expiresAt: Date().addingTimeInterval(3600)
        )
        self.isAuthenticated = true
        print("✅ [MockAuthRepository] Registered user: \(name)")
        return user
    }

    func login(email: String, password: String) async throws -> AuthToken {
        let token = AuthToken(
            accessToken: "mock_access_token_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)
        )

        self.currentUser = User(
            id: UUID(),
            email: email,
            name: "Test User",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
            createdAt: Date()
        )
        self.currentToken = token
        self.isAuthenticated = true
        print("✅ [MockAuthRepository] Logged in user: \(email)")
        return token
    }

    func logout() async throws {
        self.currentUser = nil
        self.currentToken = nil
        self.isAuthenticated = false
        print("✅ [MockAuthRepository] Logged out")
    }

    func refreshToken() async throws -> AuthToken {
        let token = AuthToken(
            accessToken: "mock_access_token_refreshed",
            refreshToken: "mock_refresh_token_refreshed",
            expiresAt: Date().addingTimeInterval(3600)
        )
        self.currentToken = token
        return token
    }

    // Helper method for getting current user (not part of protocol but useful for tests)
    func getCurrentUser() async throws -> User? {
        return currentUser
    }

    // Helper method for checking authentication status (not part of protocol but useful for tests)
    func isUserAuthenticated() async -> Bool {
        return isAuthenticated && currentToken != nil
    }
}
