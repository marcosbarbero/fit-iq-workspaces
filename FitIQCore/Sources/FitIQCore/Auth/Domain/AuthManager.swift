//
//  AuthManager.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Combine
import Foundation

/// Protocol defining the authentication manager interface
public protocol AuthManagerProtocol {
    var isAuthenticated: Bool { get }
    var currentAuthState: AuthState { get }
    var currentUserProfileID: UUID? { get }
    var currentUserProfile: UserProfile? { get }
    var isInitialDataLoadComplete: Bool { get }
    var hasCompletedOnboarding: Bool { get }

    func checkAuthenticationStatus() async
    func handleSuccessfulAuth(userProfileID: UUID?, userProfile: UserProfile?) async
    func saveUserProfile(_ profile: UserProfile) async throws
    func completeOnboarding() async
    func completeInitialDataLoad() async
    func logout() async
    func fetchAccessToken() throws -> String?
}

/// Manages the authentication state of the user for the entire application.
/// This is a shared component that can be used by both FitIQ and Lume apps.
@available(iOS 17, macOS 12, *)
public final class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// Tracks if the user is authenticated and should see the main app content
    @Published public var isAuthenticated: Bool = false

    /// Tracks the current authentication and onboarding state
    @Published public var currentAuthState: AuthState = .checkingAuthentication

    /// The current user's profile ID
    @Published public var currentUserProfileID: UUID?

    /// The current user's profile (includes email, name, date of birth)
    @Published public var currentUserProfile: UserProfile?

    /// Tracks if initial data load (e.g., HealthKit sync) is complete
    @Published public var isInitialDataLoadComplete: Bool = false

    // MARK: - Private Properties

    private let authTokenPersistence: AuthTokenPersistenceProtocol
    private let onboardingKey: String

    // MARK: - Initialization

    /// Initializes the AuthManager with the given token persistence implementation
    /// - Parameters:
    ///   - authTokenPersistence: The persistence layer for auth tokens
    ///   - onboardingKey: UserDefaults key for onboarding status (allows apps to use different keys)
    public init(
        authTokenPersistence: AuthTokenPersistenceProtocol,
        onboardingKey: String = "hasFinishedOnboardingSetup"
    ) {
        self.authTokenPersistence = authTokenPersistence
        self.onboardingKey = onboardingKey

        Task { @MainActor in
            await checkAuthenticationStatus()
            await checkAuthState()
        }
    }

    // MARK: - Public Methods

    /// Checks if the user has completed onboarding
    @MainActor
    public var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: onboardingKey)
    }

    /// Marks onboarding as complete and transitions to loading state
    @MainActor
    public func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        // Reset the flag before transitioning
        self.isInitialDataLoadComplete = false
        // Transition to loading state to trigger initial data sync
        self.currentAuthState = .loadingInitialData
    }

    /// Marks initial data load as complete and transitions to logged in state
    @MainActor
    public func completeInitialDataLoad() {
        // Called after HealthKit sync completes
        // Toggle flag to hide loading overlay and transition to loggedIn
        self.isInitialDataLoadComplete = true
        self.currentAuthState = .loggedIn
    }

    /// Called upon successful registration or login to transition to the main app
    /// - Parameters:
    ///   - userProfileID: The authenticated user's profile ID
    ///   - userProfile: The authenticated user's profile data (optional)
    @MainActor
    public func handleSuccessfulAuth(userProfileID: UUID?, userProfile: UserProfile?) async {
        guard let userProfileID = userProfileID else {
            print(
                "FitIQCore: AuthManager: handleSuccessfulAuth called with nil userProfileID. Cannot set currentUserProfileID."
            )
            return
        }

        self.currentUserProfileID = userProfileID
        self.currentUserProfile = userProfile

        // Save the user profile ID to persistence
        do {
            try authTokenPersistence.saveUserProfileID(userProfileID)

            // Save the full profile if provided
            if let profile = userProfile {
                try authTokenPersistence.saveUserProfile(profile)
                print(
                    "FitIQCore: User successfully authenticated. User ID: \(userProfileID), Profile: \(profile.sanitizedDescription) saved to persistence."
                )
            } else {
                print(
                    "FitIQCore: User successfully authenticated. User ID: \(userProfileID) saved to persistence."
                )
            }

            self.isAuthenticated = true
        } catch {
            self.currentUserProfileID = nil
            self.currentUserProfile = nil
            print(
                "FitIQCore: ERROR: AuthManager failed to save user profile to persistence: \(error.localizedDescription)"
            )
        }

        await checkAuthState()
    }

    /// Saves or updates the user profile
    /// - Parameter profile: The user profile to save
    /// - Throws: Error if save operation fails
    @MainActor
    public func saveUserProfile(_ profile: UserProfile) async throws {
        do {
            try authTokenPersistence.saveUserProfile(profile)
            self.currentUserProfile = profile
            print("FitIQCore: User profile updated: \(profile.sanitizedDescription)")
        } catch {
            print(
                "FitIQCore: ERROR: AuthManager failed to save user profile: \(error.localizedDescription)"
            )
            throw error
        }
    }

    /// Logs out the current user and clears all auth data
    @MainActor
    public func logout() async {
        UserDefaults.standard.set(false, forKey: onboardingKey)
        self.isAuthenticated = false
        self.currentUserProfileID = nil
        self.currentUserProfile = nil
        self.isInitialDataLoadComplete = false

        do {
            try authTokenPersistence.deleteTokens()
            try authTokenPersistence.deleteUserProfileID()
            try authTokenPersistence.deleteUserProfile()
            print(
                "FitIQCore: User logged out. Cleared tokens, user ID, and profile from persistence."
            )
        } catch {
            print(
                "FitIQCore: AuthManager: Error logging out and clearing auth data: \(error.localizedDescription)"
            )
        }

        await checkAuthState()
    }

    /// Fetches the current access token
    /// - Returns: Access token if available
    /// - Throws: Error if token cannot be retrieved
    public func fetchAccessToken() throws -> String? {
        return try authTokenPersistence.fetchAccessToken()
    }

    /// Checks the current authentication status from persistent storage
    @MainActor
    public func checkAuthenticationStatus() async {
        do {
            // Check for an auth token using the persistence port
            if let authToken = try authTokenPersistence.fetchAccessToken(), !authToken.isEmpty {
                self.isAuthenticated = true
                // Load the user profile ID from persistence
                self.currentUserProfileID = try authTokenPersistence.fetchUserProfileID()
                // Load the user profile from persistence
                self.currentUserProfile = try authTokenPersistence.fetchUserProfile()

                if let profileID = self.currentUserProfileID {
                    if let profile = self.currentUserProfile {
                        print(
                            "FitIQCore: AuthManager initialized. User session checked: Authenticated, User ID: \(profileID), Profile: \(profile.sanitizedDescription) loaded."
                        )
                    } else {
                        print(
                            "FitIQCore: AuthManager initialized. User session checked: Authenticated, User ID: \(profileID) loaded (no profile data)."
                        )
                    }
                } else {
                    print(
                        "FitIQCore: AuthManager initialized. User session checked: Authenticated, but no User ID found."
                    )
                    // Any downstream service that requires currentUserProfileID will need to handle nil
                }
            } else {
                self.isAuthenticated = false
                self.currentUserProfileID = nil
                self.currentUserProfile = nil
                print(
                    "FitIQCore: AuthManager initialized. User session checked: Unauthenticated (no valid token)."
                )
            }
        } catch {
            print(
                "FitIQCore: AuthManager: Error checking authentication status: \(error.localizedDescription)"
            )
            self.isAuthenticated = false
            self.currentUserProfileID = nil
            self.currentUserProfile = nil
        }

        // Update auth state based on authentication status
        await checkAuthState()
    }

    // MARK: - Private Methods

    @MainActor
    private func checkAuthState() async {
        if !self.isAuthenticated {
            self.currentAuthState = .loggedOut
        } else {
            // User is authenticated
            if self.hasCompletedOnboarding {
                self.currentAuthState = .loggedIn
            } else {
                // Authenticated, but needs onboarding
                self.currentAuthState = .needsSetup
            }
        }
    }
}
