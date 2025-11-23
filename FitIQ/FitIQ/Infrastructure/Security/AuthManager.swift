//
//  AuthManager.swift
//  FitIQ
//
//  Created by Marcos Barbero on 10/10/2025.
//

import Combine
import Foundation

enum AuthState {
    case loggedOut  // Shows LandingView (Login/Registration)
    case needsSetup  // Shows OnboardingSetupView
    case loadingInitialData  // Shows LoadingView while syncing HealthKit data
    case loggedIn  // Shows MainTabView (Finished onboarding)
    case checkingAuthentication
}

/// Manages the authentication state of the user for the entire application.
class AuthManager: ObservableObject {
    // Tracks if the user is authenticated and should see the main app content.
    @Published var isAuthenticated: Bool = false
    @Published var currentAuthState: AuthState = .checkingAuthentication
    @Published var currentUserProfileID: UUID?

    // Tracks if initial data load (HealthKit sync) is complete
    @Published var isInitialDataLoadComplete: Bool = false

    private let authTokenPersistence: AuthTokenPersistencePortProtocol

    init(authTokenPersistence: AuthTokenPersistencePortProtocol) {
        self.authTokenPersistence = authTokenPersistence
        Task { @MainActor in
            await checkAuthenticationStatus()
            await checkAuthState()
        }
    }

    @MainActor
    private func checkAuthState() async {
        if !self.isAuthenticated {
            self.currentAuthState = .loggedOut
        } else {  // User is authenticated
            if self.hasCompletedOnboarding {  // Check if onboarding is complete
                self.currentAuthState = .loggedIn
            } else {
                self.currentAuthState = .needsSetup  // Authenticated, but needs onboarding
            }
        }
    }

    @MainActor
    private func checkAuthenticationStatus() async {
        do {
            // Check for an auth token using the persistence port
            if let authToken = try authTokenPersistence.fetchAccessToken(), !authToken.isEmpty {
                self.isAuthenticated = true
                // Load the user profile ID from persistence
                self.currentUserProfileID = try authTokenPersistence.fetchUserProfileID()

                if self.currentUserProfileID != nil {
                    print(
                        "AuthManager initialized. User session checked: Authenticated from Keychain, User ID loaded."
                    )
                } else {
                    print(
                        "AuthManager initialized. User session checked: Authenticated from Keychain, but no User ID found in persistence."
                    )
                    // Decide if this should lead to a logout or a prompt to re-login/re-setup.
                    // For now, it will proceed as authenticated but with no `currentUserProfileID`.
                    // Any downstream service that requires `currentUserProfileID` will need to handle `nil`.
                }
            } else {
                self.isAuthenticated = false
                self.currentUserProfileID = nil  // Ensure ID is nil if unauthenticated
                print(
                    "AuthManager initialized. User session checked: Unauthenticated (no valid token in Keychain)."
                )
            }
        } catch {
            print(
                "AuthManager: Error checking authentication status from persistence: \(error.localizedDescription)"
            )
            self.isAuthenticated = false  // Default to unauthenticated on error
            self.currentUserProfileID = nil
        }
    }

    @MainActor
    var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: "hasFinishedOnboardingSetup")
    }

    @MainActor
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasFinishedOnboardingSetup")
        // Reset the flag before transitioning
        self.isInitialDataLoadComplete = false
        // Transition to loading state to trigger initial data sync
        self.currentAuthState = .loadingInitialData
    }

    @MainActor
    func completeInitialDataLoad() {
        // Called after HealthKit sync completes
        // Toggle flag to hide loading overlay and transition to loggedIn
        self.isInitialDataLoadComplete = true
        self.currentAuthState = .loggedIn
    }

    @MainActor
    /// Called upon successful registration or login to transition to the main app.
    /// Now accepts the userProfileID as a String and attempts to convert it to UUID.
    func handleSuccessfulAuth(userProfileID: UUID?) {

        if userProfileID == nil {
            print(
                "AuthManager: handleSuccessfulAuth called with nil userProfileID. Cannot set currentUserProfileID."
            )
            return
        }

        self.currentUserProfileID = userProfileID
        // Save the user profile ID to persistence
        do {
            try authTokenPersistence.saveUserProfileID(userProfileID!)
            self.isAuthenticated = true
            print(
                "User successfully authenticated. Routing to main app. User ID: \(userProfileID!) saved to persistence."
            )
        } catch {
            self.currentUserProfileID = nil
            print(
                "ERROR: AuthManager failed to save user profile ID to persistence: \(error.localizedDescription)"
            )
        }

        Task { @MainActor in
            await self.checkAuthState()
        }
    }

    @MainActor
    func logout() {
        UserDefaults.standard.set(false, forKey: "hasFinishedOnboardingSetup")
        self.isAuthenticated = false
        self.currentUserProfileID = nil  // CLEAR THE USER ID ON LOGOUT
        self.isInitialDataLoadComplete = false  // Reset data load flag

        do {
            try authTokenPersistence.deleteTokens()
            try authTokenPersistence.deleteUserProfileID()  // Delete user ID from persistence
            print("User logged out. Routing to authentication view and cleared tokens and user ID.")
        } catch {
            print(
                "AuthManager: Error logging out and clearing tokens/user ID via persistence port: \(error.localizedDescription)"
            )
        }
        Task { @MainActor in
            await self.checkAuthState()
        }
    }

    // MARK: - Token Access

    /// Fetches the current access token
    /// - Returns: Access token if available
    /// - Throws: Error if token cannot be retrieved
    func fetchAccessToken() throws -> String? {
        return try authTokenPersistence.fetchAccessToken()
    }
}
