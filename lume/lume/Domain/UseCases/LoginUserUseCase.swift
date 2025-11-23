import Foundation
import FitIQCore

protocol LoginUserUseCase {
    func execute(email: String, password: String) async throws -> AuthToken
}

final class LoginUserUseCaseImpl: LoginUserUseCase {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(email: String, password: String) async throws -> AuthToken {
        // Validate inputs
        guard !email.isEmpty, email.contains("@") else {
            throw AuthenticationError.invalidEmail
        }

        guard !password.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }

        // Call repository to log in user
        return try await authRepository.login(email: email, password: password)
    }
}
