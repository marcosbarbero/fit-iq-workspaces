//
//  AuthState.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Represents the current authentication and onboarding state of the user
public enum AuthState {
    /// User is logged out and should see login/registration screen
    case loggedOut

    /// User is authenticated but needs to complete onboarding setup
    case needsSetup

    /// User is authenticated and loading initial data (e.g., HealthKit sync)
    case loadingInitialData

    /// User is fully authenticated and onboarded, ready to use the app
    case loggedIn

    /// Currently checking authentication status (initial state)
    case checkingAuthentication
}
