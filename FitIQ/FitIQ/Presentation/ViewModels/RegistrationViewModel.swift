//
//  RegistrationViewModel.swift
//
//  Created by Marcos Barbero on 08/10/2025.
//

import Combine
import FitIQCore
import Foundation

// MARK: - Example Usage in a ViewModel

class RegistrationViewModel: ObservableObject {
    private let authManager: AuthManager
    private let createUserUseCase: RegisterUserUseCaseProtocol

    @Published var email = ""
    @Published var name = ""
    @Published var password = ""
    @Published var dateOfBirth = Date()

    @Published var isLoading = false
    @Published var registrationMessage: String?
    @Published var registeredUser: FitIQCore.UserProfile?
    @Published var registrationSuccessful = false  // NEW: Added this property

    init(
        authManager: AuthManager,
        authRepository: AuthRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        profileMetadataClient: UserProfileMetadataClient
    ) {
        self.authManager = authManager
        self.createUserUseCase = CreateUserUseCase(
            authRepository: authRepository,
            authManager: authManager,
            userProfileStorage: userProfileStorage,
            authTokenPersistence: authTokenPersistence,
            profileMetadataClient: profileMetadataClient
        )
    }

    func register() {
        guard !email.isEmpty, !password.isEmpty else {
            registrationMessage = "Please fill out all fields."
            return
        }

        Task { @MainActor in
            self.isLoading = true
            self.registrationMessage = nil
            self.registrationSuccessful = false

            let registrationRequest = RegisterUserData(
                email: email,
                name: name,
                password: password,
                dateOfBirth: dateOfBirth
            )

            do {
                let userProfile = try await createUserUseCase.execute(data: registrationRequest)
                self.registeredUser = userProfile
                self.registrationMessage =
                    "Registration Successful! Welcome, \(userProfile.username)!"

                // REMOVED: This call is now handled by CreateUserUseCase
                // self.authManager.handleSuccessfulAuth()

                self.registrationSuccessful = true  // Signal success to the view for dismissal
            } catch let APIError.apiError(error as ErrorResponse) {
                self.registrationMessage = "Registration Failed: \(error.message)"
            } catch let APIError.apiError(error as ValidationErrorResponse) {
                self.registrationMessage = "Validation Failed: \(error.message)"
            } catch {
                self.registrationMessage =
                    "An unknown error occurred: \(error.localizedDescription)"
            }

            self.isLoading = false
        }
    }
}
