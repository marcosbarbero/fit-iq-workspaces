//
//  LoginViewModel.swift
//
//  Created by Marcos Barbero on 10/10/2025.
//

import Combine
import Foundation
import Security

class LoginViewModel: ObservableObject {
    private let authManager: AuthManager
    private let loginUserUseCase: LoginUserUseCaseProtocol

    @Published var email = ""  // Updated property name
    @Published var password = ""
    @Published var isLoading = false
    @Published var loginMessage: String?

    init(authManager: AuthManager, loginUserUseCase: LoginUserUseCaseProtocol) {
        self.authManager = authManager
        self.loginUserUseCase = loginUserUseCase
    }

    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            loginMessage = "Please enter your email and password."
            return
        }

        Task { @MainActor in
            self.isLoading = true
            self.loginMessage = nil

            let credentials = LoginCredentials(
                email: email,
                password: password
            )

            do {
                let userProfile = try await loginUserUseCase.execute(credentials: credentials)
                self.loginMessage = "Login Successful! Welcome back, \(userProfile.name)."

                // Note: handleSuccessfulAuth is already called by AuthenticateUserUseCase
                // No need to call it again here

            } catch let APIError.apiError(error as ErrorResponse) {
                // Handles 401 (Invalid credentials) and 500
                self.loginMessage = "Login Failed: \(error.message)"
            } catch let APIError.apiError(error as ValidationErrorResponse) {
                // Handles 400 (Validation failed)
                self.loginMessage =
                    "Validation Failed: \(error.message ?? "ValidationErrorResponse")"
            } catch let keychainError as KeychainError {
                // Handle Keychain errors specifically
                self.loginMessage =
                    "Login Successful, but failed to secure tokens: \(keychainError.localizedDescription)"
                self.authManager.handleSuccessfulAuth(userProfileID: nil)
            } catch {
                self.loginMessage = "An unknown error occurred: \(error.localizedDescription)"
            }

            self.isLoading = false
        }
    }
}
