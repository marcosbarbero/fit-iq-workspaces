//
//  FitIQApp.swift
//  FitIQ
//
//  Created by Marcos Barbero on 10/10/2025.
//

import SwiftData
import SwiftUI

@main
struct FitIQApp: App {
    @StateObject private var localeManager: LocaleManager
    @StateObject private var authManager: AuthManager  // This line should be updated.

    // deps must be initialized after authManager is ready.
    let deps: AppDependencies

    init() {
        // Initialize the underlying property wrappers for StateObjects first.
        // This ensures the instances are created before `deps` tries to use them.
        _localeManager = StateObject(wrappedValue: LocaleManager.shared)

        // NEW: Create the adapter first to pass to AuthManager
        let authTokenPersistenceAdapter = KeychainAuthTokenAdapter()

        // Create the AuthManager instance directly
        let authManagerInstance = AuthManager(authTokenPersistence: authTokenPersistenceAdapter)

        // Wrap the created instance in StateObject
        _authManager = StateObject(wrappedValue: authManagerInstance)

        // Now, initialize `deps` by calling the static `build` method
        // and passing the *same* `authManagerInstance` directly.
        // This avoids accessing `_authManager.wrappedValue` which might not be fully installed yet.
        self.deps = AppDependencies.build(
            authManager: authManagerInstance
        )
    }

    var body: some Scene {
        WindowGroup {

            Group {
                switch authManager.currentAuthState {
                case .checkingAuthentication:
                    LoadingView()
                        .transition(.opacity)
                case .loggedOut:
                    // User sees the initial entry page
                    LandingView(authManager: self.authManager)
                        .transition(.move(edge: .leading))

                case .needsSetup:
                    // User is logged in but must complete permissions
                    let onboardingSetUpViewModel = OnboardingSetupViewModel(
                        healthKitAuthUseCase: deps.healthKitAuthUseCase)
                    OnboardingSetupView(
                        authManager: self.authManager, viewModel: onboardingSetUpViewModel
                    )
                    .transition(.move(edge: .leading))

                case .loadingInitialData:
                    // User completed onboarding - show loading view while syncing data
                    LoadingView()
                        .transition(.opacity)
                        .task {
                            // Perform initial data load via use case
                            await performInitialDataLoad()
                        }

                case .loggedIn:
                    // User is fully authenticated and data is ready
                    RootTabView(deps: deps, authManager: self.authManager)
                        .transition(.opacity)
                }
            }
            .environmentObject(localeManager)
            .environmentObject(authManager)
            .environmentObject(deps)
            .environment(
                \.locale,
                Locale(identifier: localeManager.currentLanguageCode)
            )
        }
    }

    // MARK: - Initial Data Load (Presentation Layer)
    @MainActor
    private func performInitialDataLoad() async {
        guard let userID = authManager.currentUserProfileID else {
            print("FitIQApp: User ID is nil. Cannot perform initial load.")
            authManager.completeInitialDataLoad()
            return
        }

        do {
            // Use case handles all business logic
            try await deps.performInitialDataLoadUseCase.execute(forUserID: userID)
        } catch {
            print("⚠️ FitIQApp: Initial data load failed: \(error.localizedDescription)")
            // Continue anyway - user can manually refresh
        }

        // Transition to logged in state
        print("🎉 FitIQApp: Transitioning to .loggedIn state")
        authManager.completeInitialDataLoad()
    }

}
