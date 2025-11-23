import Foundation

protocol LogoutUserUseCase {
    func execute() async throws
}

final class LogoutUserUseCaseImpl: LogoutUserUseCase {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() async throws {
        try await authRepository.logout()
    }
}
