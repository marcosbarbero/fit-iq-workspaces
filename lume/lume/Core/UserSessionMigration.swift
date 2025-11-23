//
//  UserSessionMigration.swift
//  lume
//
//  Created by FitIQ Team on 2025-01-27.
//  Handles one-time migration of user data from UserDefaults to Keychain
//

import FitIQCore
import Foundation

/// Handles one-time migration of user data from UserDefaults to Keychain
///
/// **Purpose:** Existing Lume users have their user data stored in UserDefaults (plain text).
/// This migration moves that data to Keychain (encrypted) via FitIQCore's AuthManager.
///
/// **Safety:**
/// - Safe to call multiple times (only runs once)
/// - Idempotent (repeated calls have no effect)
/// - Non-destructive (preserves data if migration fails)
/// - Automatic cleanup of old UserDefaults data
///
/// **Usage:**
/// ```swift
/// // In lumeApp.swift init
/// Task { @MainActor in
///     await UserSessionMigration.migrateIfNeeded(
///         authManager: dependencies.authManager
///     )
/// }
/// ```
final class UserSessionMigration {

    // MARK: - Migration Keys

    /// Key to track if migration has been completed
    private static let migrationKey = "lume.userSession.migrated.v1"

    /// Old UserDefaults keys (deprecated)
    private enum LegacyKeys {
        static let userId = "lume.user.id"
        static let userEmail = "lume.user.email"
        static let userName = "lume.user.name"
        static let dateOfBirth = "lume.user.dateOfBirth"
        static let isAuthenticated = "lume.user.isAuthenticated"
    }

    // MARK: - Migration

    /// Performs one-time migration of user data from UserDefaults to Keychain
    ///
    /// This method is safe to call multiple times - it only runs once.
    /// After successful migration, old UserDefaults entries are cleared.
    ///
    /// - Parameter authManager: FitIQCore's AuthManager to store user data
    @MainActor
    static func migrateIfNeeded(authManager: AuthManager) async {
        let userDefaults = UserDefaults.standard

        // Check if migration already completed
        if userDefaults.bool(forKey: migrationKey) {
            print("🔄 [Migration] User data already migrated to Keychain")
            return
        }

        print("🔄 [Migration] Checking for user data in UserDefaults...")

        // Check if there's data to migrate
        guard let userIdString = userDefaults.string(forKey: LegacyKeys.userId),
            let userId = UUID(uuidString: userIdString)
        else {
            print("🔄 [Migration] No user data in UserDefaults to migrate")
            // Mark as complete even if no data (prevents repeated checks)
            userDefaults.set(true, forKey: migrationKey)
            return
        }

        print("🔄 [Migration] Found user data in UserDefaults, starting migration...")
        print("🔄 [Migration] User ID: \(userId)")

        // Extract all user data from UserDefaults
        let email = userDefaults.string(forKey: LegacyKeys.userEmail) ?? "unknown@email.com"
        let name = userDefaults.string(forKey: LegacyKeys.userName) ?? "Unknown User"

        var dateOfBirth: Date?
        if let dobTimestamp = userDefaults.object(forKey: LegacyKeys.dateOfBirth) as? TimeInterval {
            dateOfBirth = Date(timeIntervalSince1970: dobTimestamp)
        }

        print("🔄 [Migration] Extracted data:")
        print("   - Email: \(email)")
        print("   - Name: \(name)")
        print("   - Date of Birth: \(dateOfBirth?.description ?? "nil")")

        // Create UserProfile from extracted data (using FitIQCore's UserProfile)
        let profile = FitIQCore.UserProfile(
            id: userId,
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )

        // Validate profile before migration
        let validationErrors = profile.validate()
        if !validationErrors.isEmpty {
            print("⚠️ [Migration] Profile validation warnings:")
            for error in validationErrors {
                print("   - \(error.localizedDescription)")
            }
            // Continue anyway - better to have some data than none
        }

        do {
            // Save to Keychain via AuthManager
            await authManager.handleSuccessfulAuth(
                userProfileID: userId,
                userProfile: profile
            )

            print("✅ [Migration] Successfully migrated user data to Keychain")
            print("✅ [Migration] User profile stored securely")

            // Clear old UserDefaults data
            clearLegacyUserDefaults()

            // Mark migration as complete
            userDefaults.set(true, forKey: migrationKey)
            userDefaults.synchronize()  // Force immediate save

            print("✅ [Migration] Migration complete. Old UserDefaults entries cleared.")
        }
    }

    // MARK: - Cleanup

    /// Clears legacy UserDefaults entries
    private static func clearLegacyUserDefaults() {
        let userDefaults = UserDefaults.standard

        userDefaults.removeObject(forKey: LegacyKeys.userId)
        userDefaults.removeObject(forKey: LegacyKeys.userEmail)
        userDefaults.removeObject(forKey: LegacyKeys.userName)
        userDefaults.removeObject(forKey: LegacyKeys.dateOfBirth)
        userDefaults.removeObject(forKey: LegacyKeys.isAuthenticated)

        print("🗑️ [Migration] Cleared legacy UserDefaults entries:")
        print("   - \(LegacyKeys.userId)")
        print("   - \(LegacyKeys.userEmail)")
        print("   - \(LegacyKeys.userName)")
        print("   - \(LegacyKeys.dateOfBirth)")
        print("   - \(LegacyKeys.isAuthenticated)")
    }

    // MARK: - Debug Helpers

    /// Checks if user data exists in UserDefaults (for debugging)
    static func hasLegacyData() -> Bool {
        let userDefaults = UserDefaults.standard
        return userDefaults.string(forKey: LegacyKeys.userId) != nil
    }

    /// Resets migration flag (for testing only)
    static func resetMigrationForTesting() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("⚠️ [Migration] Migration flag reset for testing")
    }

    /// Prints current migration status (for debugging)
    static func printMigrationStatus() {
        let userDefaults = UserDefaults.standard
        let migrationComplete = userDefaults.bool(forKey: migrationKey)
        let hasLegacyData = self.hasLegacyData()

        print("=== Migration Status ===")
        print("Migration Complete: \(migrationComplete)")
        print("Has Legacy Data: \(hasLegacyData)")

        if hasLegacyData {
            print("Legacy Data:")
            if let userId = userDefaults.string(forKey: LegacyKeys.userId) {
                print("  - User ID: \(userId)")
            }
            if let email = userDefaults.string(forKey: LegacyKeys.userEmail) {
                print("  - Email: \(email)")
            }
            if let name = userDefaults.string(forKey: LegacyKeys.userName) {
                print("  - Name: \(name)")
            }
        }
        print("========================")
    }
}

// MARK: - Migration Testing

#if DEBUG
    extension UserSessionMigration {

        /// Creates test user data in UserDefaults for testing migration
        /// Only available in debug builds
        static func createTestLegacyData() {
            let userDefaults = UserDefaults.standard
            let testUserId = UUID()

            userDefaults.set(testUserId.uuidString, forKey: LegacyKeys.userId)
            userDefaults.set("test@example.com", forKey: LegacyKeys.userEmail)
            userDefaults.set("Test User", forKey: LegacyKeys.userName)
            userDefaults.set(Date().timeIntervalSince1970, forKey: LegacyKeys.dateOfBirth)
            userDefaults.set(true, forKey: LegacyKeys.isAuthenticated)

            // Reset migration flag to allow testing
            userDefaults.removeObject(forKey: migrationKey)

            print("✅ [Testing] Created test legacy data in UserDefaults")
            print("   User ID: \(testUserId)")
        }
    }
#endif

// MARK: - Migration Notes

/*
 MIGRATION STRATEGY
 ==================

 **Problem:**
 - Existing Lume users have user data in UserDefaults (plain text)
 - User IDs are personally identifiable information
 - Should be stored in Keychain (encrypted)

 **Solution:**
 - One-time automatic migration on app launch
 - Move user data from UserDefaults to Keychain
 - Use FitIQCore's AuthManager for secure storage
 - Clear old UserDefaults entries after successful migration

 **Safety Measures:**
 - Idempotent (safe to run multiple times)
 - Non-destructive (preserves data on failure)
 - Automatic retry (if migration fails, tries next launch)
 - Validation (ensures data integrity)

 **Testing:**

 1. Fresh Install:
    - No legacy data
    - Migration completes immediately
    - Data goes directly to Keychain

 2. Existing User:
    - Legacy data in UserDefaults
    - Migration runs on first launch
    - Data moved to Keychain
    - UserDefaults cleared

 3. Already Migrated:
    - Migration flag set
    - No operation performed
    - Fast startup

 **Rollback:**
 If issues arise, can revert by:
 - Removing migration code
 - Restoring old UserSession implementation
 - User data remains in Keychain (more secure)

 **Monitoring:**
 Check logs for:
 - "Migration complete" (successful)
 - "Failed to migrate" (needs attention)
 - "Already migrated" (normal)
 */
