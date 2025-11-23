import Combine
import Foundation

@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var name: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    var isLoading: Bool = false
    var errorMessage: String?
    var isAuthenticated: Bool = false  // To track authentication status

    private let registerUserUseCase: RegisterUserUseCase
    private let loginUserUseCase: LoginUserUseCase
    private let logoutUserUseCase: LogoutUserUseCase

    init(
        registerUserUseCase: RegisterUserUseCase,
        loginUserUseCase: LoginUserUseCase,
        logoutUserUseCase: LogoutUserUseCase
    ) {
        self.registerUserUseCase = registerUserUseCase
        self.loginUserUseCase = loginUserUseCase
        self.logoutUserUseCase = logoutUserUseCase
    }

    @MainActor
    func register() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await registerUserUseCase.execute(
                email: email,
                password: password,
                name: name,
                dateOfBirth: dateOfBirth)

            // Clear form fields on successful registration
            clearFormFields()

            // Set authenticated state to transition to main app
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    @MainActor
    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Login only returns token, not user data
            _ = try await loginUserUseCase.execute(
                email: email,
                password: password)

            // Clear form fields on successful login
            clearFormFields()

            // Set authenticated state to transition to main app
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }

    @MainActor
    func logout() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await logoutUserUseCase.execute()

            // Clear form fields and state on logout
            clearFormFields()

            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clear all form fields and error messages
    private func clearFormFields() {
        email = ""
        password = ""
        name = ""
        dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
        errorMessage = nil
    }
}
