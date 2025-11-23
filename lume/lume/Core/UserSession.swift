//
//  UserSession.swift
//  lume
//
//  Refactored: 2025-01-27
//  Now delegates to FitIQCore's AuthManager for secure Keychain storage
//

import FitIQCore
import Foundation

/// User session management adapter
///
/// This adapter provides backward compatibility while delegating all storage
/// operations to FitIQCore's AuthManager. User data is now stored securely
/// in the Keychain instead of UserDefaults.
///
/// **Migration:** User IDs and profiles are automatically migrated from
/// UserDefaults to Keychain on first launch via `UserSessionMigration`.
///
/// **Usage:**
/// ```swift
/// // Start session after login
/// UserSession.shared.startSession(
///     userId: userId,
///     email: "user@example.com",
///     name: "John Doe",
///     dateOfBirth: birthDate
/// )
///
/// // Access user data
/// if let userId = UserSession.shared.currentUserId {
///     print("User ID: \(userId)")
/// }
///
/// // End session on logout
/// UserSession.shared.endSession()
/// ```
final class UserSession {

    // MARK: - Singleton

    static let shared = UserSession()

    // MARK: - Properties

    private var authManager: AuthManager!

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton
        print("🔐 [UserSession] Initialized (now delegates to FitIQCore's AuthManager)")
    }

    // MARK: - Configuration

    /// Configures the session with FitIQCore's AuthManager
    /// Must be called during app initialization before any other UserSession methods
    func configure(authManager: AuthManager) {
        self.authManager = authManager
        print("✅ [UserSession] Configured with FitIQCore's AuthManager")
    }

    // MARK: - Public API (Delegates to AuthManager)

    /// Current user ID (nil if not authenticated)
    /// Now stored in Keychain via FitIQCore
    var currentUserId: UUID? {
        authManager.currentUserProfileID
    }

    /// Current user email (nil if not authenticated)
    var currentUserEmail: String? {
        authManager.currentUserProfile?.email
    }

    /// Current user name (nil if not authenticated)
    var currentUserName: String? {
        authManager.currentUserProfile?.name
    }

    /// Current user date of birth (nil if not authenticated)
    var currentUserDateOfBirth: Date? {
        authManager.currentUserProfile?.dateOfBirth
    }

    /// Whether a user is currently authenticated
    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }

    /// Start a new user session
    /// Saves user profile to Keychain via FitIQCore's AuthManager
    ///
    /// - Parameters:
    ///   - userId: User's unique identifier
    ///   - email: User's email address
    ///   - name: User's name
    ///   - dateOfBirth: User's date of birth (optional)
    func startSession(userId: UUID, email: String, name: String, dateOfBirth: Date? = nil) {
        let profile = FitIQCore.UserProfile(
            id: userId,
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )

        Task { @MainActor in
            await authManager.handleSuccessfulAuth(
                userProfileID: userId,
                userProfile: profile
            )
            print("✅ [UserSession] Session started for user: \(email) (ID: \(userId))")
            print("🔐 [UserSession] User profile stored securely in Keychain")
        }
    }

    /// End the current user session (logout)
    /// Clears all user data from Keychain via FitIQCore's AuthManager
    func endSession() {
        Task { @MainActor in
            let userId = authManager.currentUserProfileID
            await authManager.logout()
            print("✅ [UserSession] Session ended for user ID: \(userId?.uuidString ?? "unknown")")
            print("🔐 [UserSession] User data cleared from Keychain")
        }
    }

    /// Update user information
    /// Updates the stored profile in Keychain
    ///
    /// - Parameters:
    ///   - email: Updated email (optional)
    ///   - name: Updated name (optional)
    ///   - dateOfBirth: Updated date of birth (optional)
    func updateUserInfo(email: String? = nil, name: String? = nil, dateOfBirth: Date? = nil) {
        guard let currentProfile = authManager.currentUserProfile else {
            print("⚠️ [UserSession] Cannot update user info: no current profile")
            return
        }

        let updatedProfile = currentProfile.updated(
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )

        Task { @MainActor in
            do {
                try await authManager.saveUserProfile(updatedProfile)
                print("✅ [UserSession] User info updated successfully")
            } catch {
                print("❌ [UserSession] Failed to update user info: \(error.localizedDescription)")
            }
        }
    }

    /// Get current user ID or throw error if not authenticated
    /// - Throws: `UserSessionError.notAuthenticated` if no user is logged in
    /// - Returns: Current user's UUID
    func requireUserId() throws -> UUID {
        guard let userId = currentUserId else {
            throw UserSessionError.notAuthenticated
        }
        return userId
    }

    /// Clear all session data (use for debugging or account deletion)
    /// Delegates to AuthManager's logout, which clears Keychain data
    func clearAllData() {
        Task { @MainActor in
            await authManager.logout()
            print("⚠️ [UserSession] All session data cleared from Keychain")
        }
    }
}

// MARK: - Errors

enum UserSessionError: LocalizedError {
    case notAuthenticated
    case invalidUserId

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No user is currently authenticated. Please log in."
        case .invalidUserId:
            return "Invalid user ID format."
        }
    }
}

// MARK: - Migration Notes

/*
 MIGRATION FROM USERDEFAULTS TO KEYCHAIN
 ========================================

 **What Changed:**
 - User IDs now stored in Keychain (was: UserDefaults)
 - User profiles now stored in Keychain (was: UserDefaults)
 - Storage handled by FitIQCore's AuthManager

 **Security Improvements:**
 - Hardware-backed encryption
 - System-level access control
 - Protected from other processes
 - Can be excluded from backups

 **Backward Compatibility:**
 - UserSessionMigration automatically moves data from UserDefaults to Keychain
 - All existing code continues to work (adapter pattern)
 - No breaking changes to consumers

 **Migration Code:**
 See: lume/Core/UserSessionMigration.swift
 Runs automatically on app launch via lumeApp.swift

 **Testing:**
 - Existing users: Data migrated on first launch
 - New users: Data goes directly to Keychain
 - Logout: Clears both UserDefaults (legacy) and Keychain
 */
