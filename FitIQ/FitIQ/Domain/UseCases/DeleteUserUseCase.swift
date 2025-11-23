// Domain/UseCases/DeleteUserUseCase.swift
import Foundation

public protocol DeleteUserUseCaseProtocol {
    func execute() async
}

public final class DeleteUserUseCase: DeleteUserUseCaseProtocol {
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    public func execute() async {
        // This use case can be expanded to include backend calls for user deletion
        // For now, it performs a local logout, which often accompanies account deletion.
        authManager.logout()
        print("DeleteUserUseCase: User logged out as part of deletion process.")
    }
}
