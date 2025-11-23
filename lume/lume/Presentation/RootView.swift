//
//  RootView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import FitIQCore
import SwiftUI

/// Root view that handles authentication state and navigation
/// Implements offline-first authentication checking
/// - If user has a valid session locally, they can use the app offline
/// - Token validation and refresh only happens when online

struct RootView: View {
    @Bindable var authViewModel: AuthViewModel
    let dependencies: AppDependencies
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                // Main app content - shown when user is logged in
                MainTabView(
                    dependencies: dependencies,
                    authViewModel: authViewModel
                )
                .transition(.opacity)
            } else {
                // Authentication flow - shown when user is not logged in
                AuthCoordinatorView(viewModel: authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .task {
            await checkAuthenticationStatus()
        }
    }

    /// Check if user has a valid stored token on app launch
    /// Implements offline-first authentication:
    /// 1. Check UserSession first (local state)
    /// 2. If authenticated locally, allow app usage even when offline
    /// 3. Only validate/refresh tokens when online
    private func checkAuthenticationStatus() async {
        // STEP 1: Check local session first (offline-first)
        // This allows users to continue using the app even without internet
        if UserSession.shared.isAuthenticated {
            print("✅ [RootView] User has active local session")
            authViewModel.isAuthenticated = true

            // STEP 2: If online, validate and refresh token in background
            // This ensures tokens stay fresh when connectivity is available
            if networkMonitor.isConnected {
                print("🌐 [RootView] Online - validating token in background")
                await validateAndRefreshTokenIfNeeded()
            } else {
                print("📴 [RootView] Offline - allowing app usage with local session")
            }
            return
        }

        // STEP 3: No local session - check if we have a stored token
        // This handles app restart scenarios
        print("⚠️ [RootView] No local session found, checking stored token")

        do {
            let tokenStorage = dependencies.tokenStorage

            // Try to get stored token
            guard let token = try await tokenStorage.getToken() else {
                // No token stored, show authentication
                print("❌ [RootView] No stored token, showing authentication")
                authViewModel.isAuthenticated = false
                return
            }

            // We have a token, but need to verify it if online
            if networkMonitor.isConnected {
                print("🌐 [RootView] Found token, online - validating")

                // Check if token is still valid
                if !token.isExpired {
                    // Token is valid, need to fetch profile to restore session
                    print("✅ [RootView] Token valid, fetching profile to restore session")
                    do {
                        // Fetch profile to populate UserSession
                        let profile = try await dependencies.userProfileService
                            .fetchCurrentUserProfile(
                                accessToken: token.accessToken
                            )

                        guard let userId = profile.userIdUUID else {
                            print("❌ [RootView] Invalid user ID in profile")
                            // Clear invalid token
                            try? await dependencies.tokenStorage.deleteToken()
                            authViewModel.isAuthenticated = false
                            return
                        }

                        // Restore UserSession
                        UserSession.shared.startSession(
                            userId: userId,
                            email: profile.email,
                            name: profile.name,
                            dateOfBirth: profile.dateOfBirthDate
                        )

                        print("✅ [RootView] Session restored successfully")
                        authViewModel.isAuthenticated = true

                        // Migrate existing data in background
                        Task {
                            let migration = UserIdMigration(modelContext: dependencies.modelContext)
                            try? await migration.migrateToAuthenticatedUser(newUserId: userId)
                        }
                    } catch {
                        print(
                            "❌ [RootView] Failed to restore session: \(error.localizedDescription)")
                        // Clear invalid token
                        try? await dependencies.tokenStorage.deleteToken()
                        authViewModel.isAuthenticated = false
                    }
                } else if token.willExpireSoon {
                    // Token expired but can be refreshed
                    print("🔄 [RootView] Token expired, attempting refresh")
                    do {
                        _ = try await dependencies.refreshTokenUseCase.execute()
                        print("✅ [RootView] Token refreshed, session restored")
                        authViewModel.isAuthenticated = true
                    } catch {
                        // Refresh failed, clear everything and show authentication
                        print("❌ [RootView] Token refresh failed: \(error.localizedDescription)")
                        print("🗑️ [RootView] Clearing token and session due to refresh failure")
                        try? await dependencies.tokenStorage.deleteToken()
                        UserSession.shared.endSession()
                        authViewModel.isAuthenticated = false
                    }
                } else {
                    // Token expired and can't be refreshed
                    print("❌ [RootView] Token expired and cannot be refreshed")
                    print("🗑️ [RootView] Clearing expired token")
                    try? await dependencies.tokenStorage.deleteToken()
                    UserSession.shared.endSession()
                    authViewModel.isAuthenticated = false
                }
            } else {
                // Offline with token but no session - can't restore without internet
                print("📴 [RootView] Offline with token but no session - need to login online first")
                // We can't fetch profile to restore session without internet
                // User needs to login while online at least once
                print("🗑️ [RootView] Clearing token - cannot restore session offline")
                try? await dependencies.tokenStorage.deleteToken()
                UserSession.shared.endSession()
                authViewModel.isAuthenticated = false
            }
        } catch {
            // Error checking token, show authentication
            print("❌ [RootView] Error checking token: \(error.localizedDescription)")
            print("🗑️ [RootView] Clearing token due to error")
            try? await dependencies.tokenStorage.deleteToken()
            UserSession.shared.endSession()
            authViewModel.isAuthenticated = false
        }
    }

    /// Validate and refresh token if needed (background operation)
    /// Only called when online and user has active session
    private func validateAndRefreshTokenIfNeeded() async {
        do {
            guard let token = try await dependencies.tokenStorage.getToken() else {
                print("⚠️ [RootView] No token to validate")
                return
            }

            // Only refresh if needed
            if token.willExpireSoon {
                print("🔄 [RootView] Token needs refresh, refreshing in background")
                _ = try await dependencies.refreshTokenUseCase.execute()
                print("✅ [RootView] Background token refresh successful")
            } else {
                print("✅ [RootView] Token still valid, no refresh needed")
            }
        } catch let error as AuthenticationError {
            // Handle authentication-specific errors
            print("❌ [RootView] Authentication error during token refresh: \(error)")

            switch error {
            case .tokenExpired, .tokenRevoked:
                // Refresh token is revoked or expired - must log out
                print("🚪 [RootView] Refresh token expired/revoked - logging user out")
                try? await dependencies.tokenStorage.deleteToken()
                UserSession.shared.endSession()
                await MainActor.run {
                    authViewModel.isAuthenticated = false
                }
            case .invalidCredentials:
                // Invalid credentials - log out
                print("🚪 [RootView] Invalid credentials - logging out")
                try? await dependencies.tokenStorage.deleteToken()
                UserSession.shared.endSession()
                await MainActor.run {
                    authViewModel.isAuthenticated = false
                }
            default:
                // Other auth errors - allow offline mode but log the issue
                print("⚠️ [RootView] Auth error but allowing offline mode: \(error)")
            }
        } catch {
            // Non-authentication errors (network, etc.) - allow offline mode
            print("⚠️ [RootView] Background token refresh failed: \(error.localizedDescription)")
            print("📴 [RootView] User can continue in offline mode")
        }
    }
}

#Preview("Not Authenticated") {
    let dependencies = AppDependencies.preview
    let viewModel = dependencies.makeAuthViewModel()
    viewModel.isAuthenticated = false

    return RootView(
        authViewModel: viewModel,
        dependencies: dependencies
    )
}

#Preview("Authenticated") {
    let dependencies = AppDependencies.preview
    let viewModel = dependencies.makeAuthViewModel()
    viewModel.isAuthenticated = true

    return RootView(
        authViewModel: viewModel,
        dependencies: dependencies
    )
}
