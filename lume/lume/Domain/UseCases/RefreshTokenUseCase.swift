import Foundation
import FitIQCore

protocol RefreshTokenUseCase {
    func execute() async throws -> AuthToken
}

final class RefreshTokenUseCaseImpl: RefreshTokenUseCase {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() async throws -> AuthToken {
        return try await authRepository.refreshToken()
    }
}
