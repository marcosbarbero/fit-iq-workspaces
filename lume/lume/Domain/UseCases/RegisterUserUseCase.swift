import Foundation

protocol RegisterUserUseCase {
    func execute(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> User
}

final class RegisterUserUseCaseImpl: RegisterUserUseCase {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> User
    {
        // Validate inputs
        guard !email.isEmpty, email.contains("@") else {
            throw AuthenticationError.invalidEmail
        }

        guard password.count >= 8 else {
            throw AuthenticationError.passwordTooShort
        }

        guard !name.isEmpty else {
            throw AuthenticationError.invalidName
        }

        // COPPA compliance: Validate age (must be 13+)
        let calendar = Calendar.current
        let now = Date()
        guard let age = calendar.dateComponents([.year], from: dateOfBirth, to: now).year,
            age >= 13
        else {
            throw AuthenticationError.ageTooYoung
        }

        // Call repository to register user
        return try await authRepository.register(
            email: email, password: password, name: name, dateOfBirth: dateOfBirth)
    }
}

enum AuthenticationError: LocalizedError {
    case invalidEmail
    case passwordTooShort
    case invalidName
    case ageTooYoung
    case invalidCredentials
    case userAlreadyExists
    case tokenExpired
    case tokenRevoked
    case invalidResponse
    case networkError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .passwordTooShort:
            return "Password must be at least 8 characters"
        case .invalidName:
            return "Please enter your name"
        case .ageTooYoung:
            return "You must be at least 13 years old to register"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userAlreadyExists:
            return "An account with this email already exists"
        case .tokenExpired:
            return "Your session has expired. Please log in again"
        case .tokenRevoked:
            return "Your session has been revoked. Please log in again"
        case .invalidResponse:
            return "Received invalid response from server"
        case .networkError:
            return "Unable to connect. Please check your internet connection"
        case .unknown:
            return "An unexpected error occurred. Please try again"
        }
    }
}
