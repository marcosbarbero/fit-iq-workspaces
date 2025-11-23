import FitIQCore
import Foundation
import SwiftData

final class AuthRepository: AuthRepositoryProtocol {
    private let authService: AuthServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let userProfileService: UserProfileServiceProtocol
    private let modelContext: ModelContext
    private let tokenRefreshClient: TokenRefreshClient

    init(
        authService: AuthServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        userProfileService: UserProfileServiceProtocol,
        modelContext: ModelContext,
        tokenRefreshClient: TokenRefreshClient
    ) {
        self.authService = authService
        self.tokenStorage = tokenStorage
        self.userProfileService = userProfileService
        self.modelContext = modelContext
        self.tokenRefreshClient = tokenRefreshClient
    }

    func register(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> User
    {
        // Process the registration directly (auth must be immediate)
        let (user, token) = try await authService.register(
            email: email,
            password: password,
            name: name,
            dateOfBirth: dateOfBirth
        )

        // Save token securely
        try await tokenStorage.saveToken(token)

        print("✅ [AuthRepository] User registered: \(user.email)")

        // Fetch and store user profile
        try await fetchAndStoreUserProfile(accessToken: token.accessToken)

        return user
    }

    func login(email: String, password: String) async throws -> AuthToken {
        // Process the login directly (auth must be immediate)
        let token = try await authService.login(
            email: email,
            password: password
        )

        // Save token securely
        try await tokenStorage.saveToken(token)

        print("✅ [AuthRepository] User logged in")

        // Fetch and store user profile
        try await fetchAndStoreUserProfile(accessToken: token.accessToken)

        return token
    }

    func refreshToken() async throws -> AuthToken {
        print("🔄 [AuthRepository] Starting token refresh via FitIQCore")

        // Get current refresh token
        guard let currentToken = try await tokenStorage.getToken() else {
            print("❌ [AuthRepository] No current token found in storage")
            throw AuthenticationError.tokenExpired
        }

        print("🔄 [AuthRepository] Using FitIQCore TokenRefreshClient")
        print(
            "🔄 [AuthRepository] Refresh token (first 20 chars): \(String(currentToken.refreshToken.prefix(20)))..."
        )

        // Use FitIQCore's TokenRefreshClient (thread-safe, coordinated)
        do {
            let refreshResponse = try await tokenRefreshClient.refreshToken(
                refreshToken: currentToken.refreshToken
            )

            // Convert to AuthToken
            let newToken = AuthToken(
                accessToken: refreshResponse.accessToken,
                refreshToken: refreshResponse.refreshToken
            )

            // Save new token
            try await tokenStorage.saveToken(newToken)

            print("✅ [AuthRepository] Token refreshed successfully via FitIQCore")
            print("✅ [AuthRepository] New token expiry: \(String(describing: newToken.expiresAt))")
            return newToken

        } catch {
            // Handle errors - logout if token is invalid/revoked
            print("❌ [AuthRepository] Token refresh failed: \(error)")
            try? await tokenStorage.deleteToken()
            UserSession.shared.endSession()
            throw error
        }
    }

    func logout() async throws {
        // Delete stored token directly (auth must be immediate)
        try await tokenStorage.deleteToken()

        // Clear user session
        UserSession.shared.endSession()

        print("✅ [AuthRepository] User logged out")
    }

    // MARK: - Private Helpers

    /// Fetch user profile from backend and store in UserSession
    private func fetchAndStoreUserProfile(accessToken: String) async throws {
        do {
            print("🔍 [AuthRepository] Fetching user profile...")

            let profile = try await userProfileService.fetchCurrentUserProfile(
                accessToken: accessToken)

            guard let userId = profile.userIdUUID else {
                print("❌ [AuthRepository] Invalid user ID in profile")
                throw AuthenticationError.invalidResponse
            }

            // Store in UserSession
            UserSession.shared.startSession(
                userId: userId,
                email: profile.email,  // Use actual email from profile
                name: profile.name,
                dateOfBirth: profile.dateOfBirthDate
            )

            print("✅ [AuthRepository] User profile stored in session: \(userId)")

            // Migrate existing data to authenticated user
            await migrateExistingData(to: userId)

        } catch {
            print("❌ [AuthRepository] Failed to fetch user profile: \(error)")
            throw error
        }
    }

    /// Migrate existing local data to authenticated user's ID
    private func migrateExistingData(to userId: UUID) async {
        do {
            let migration = UserIdMigration(modelContext: modelContext)
            try await migration.migrateToAuthenticatedUser(newUserId: userId)
        } catch {
            // Don't fail authentication if migration fails, just log it
            print("⚠️ [AuthRepository] Data migration failed: \(error)")
        }
    }
}
