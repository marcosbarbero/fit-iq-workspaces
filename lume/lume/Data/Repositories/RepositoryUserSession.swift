//
//  RepositoryUserSession.swift
//  lume
//
//  Created by AI Assistant on 29/01/2025.
//

import Foundation

/// Centralized authentication helper for all repositories
/// Provides consistent user ID access across the data layer
///
/// Usage in any repository:
/// ```
/// class MyRepository: UserAuthenticatedRepository {
///     func fetchData() async throws -> [Data] {
///         let userId = try getCurrentUserId()
///         // Use userId for queries
///     }
/// }
/// ```
protocol UserAuthenticatedRepository {
    /// Get the current authenticated user's ID
    /// - Returns: UUID of the currently authenticated user
    /// - Throws: `RepositoryAuthError.notAuthenticated` if no user is logged in
    func getCurrentUserId() throws -> UUID
}

// MARK: - Default Implementation

extension UserAuthenticatedRepository {
    /// Default implementation using UserSession
    /// All repositories get this implementation automatically
    func getCurrentUserId() throws -> UUID {
        guard let userId = UserSession.shared.currentUserId else {
            print("❌ [\(String(describing: Self.self))] No user ID in session")
            throw RepositoryAuthError.notAuthenticated
        }
        return userId
    }
}

// MARK: - Errors

/// Authentication errors specific to repository operations
enum RepositoryAuthError: LocalizedError {
    case notAuthenticated
    case invalidUserId
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No user is currently authenticated. Please log in."
        case .invalidUserId:
            return "Invalid user ID format in session."
        case .sessionExpired:
            return "User session has expired. Please log in again."
        }
    }
}

// MARK: - Logging Helper

extension UserAuthenticatedRepository {
    /// Helper to log user ID in repository operations
    /// Useful for debugging and tracing user-specific operations
    func logUserOperation(_ operation: String) {
        if let userId = UserSession.shared.currentUserId {
            print("👤 [\(String(describing: Self.self))] \(operation) for user: \(userId)")
        } else {
            print("⚠️ [\(String(describing: Self.self))] \(operation) - no user in session")
        }
    }

    /// Helper to validate user ID exists before operation
    /// Returns true if user is authenticated, false otherwise
    func isUserAuthenticated() -> Bool {
        UserSession.shared.currentUserId != nil
    }
}

// MARK: - Migration Notes

/*
 MIGRATION GUIDE FOR EXISTING REPOSITORIES
 ==========================================

 1. Add conformance to UserAuthenticatedRepository:
    ```
    class MyRepository: MyRepositoryProtocol, UserAuthenticatedRepository {
        // existing code
    }
    ```

 2. Remove private getCurrentUserId() implementations:
    ```
    // DELETE THIS:
    private func getCurrentUserId() async throws -> UUID {
        // various implementations
    }
    ```

 3. The protocol extension provides the implementation automatically
    - All calls to getCurrentUserId() will use UserSession.shared.currentUserId
    - Consistent error handling across all repositories
    - No need to pass tokenStorage or other dependencies

 4. Update error types if needed:
    ```
    // BEFORE:
    throw MyRepositoryError.notAuthenticated

    // AFTER:
    throw RepositoryAuthError.notAuthenticated

    // OR keep your own error and catch:
    do {
        let userId = try getCurrentUserId()
    } catch {
        throw MyRepositoryError.notAuthenticated
    }
    ```

 AFFECTED REPOSITORIES:
 - AIInsightRepository ✅ (now uses UserSession.shared.currentUserId)
 - ChatRepository ✅ (uses UserSession.shared.requireUserId())
 - GoalRepository ❌ (parses JWT token - should migrate)
 - MoodRepository ✅ (uses UserSession.shared.requireUserId())
 - SwiftDataJournalRepository ✅ (uses UserSession.shared.requireUserId())
 - StatisticsRepository (needs review)

 BENEFITS:
 - Single source of truth for user ID
 - Consistent error handling
 - Easy to test (mock UserSession)
 - No duplicate code
 - Type-safe and Swift-friendly
 - Thread-safe (UserSession uses dispatch queue)
 */
