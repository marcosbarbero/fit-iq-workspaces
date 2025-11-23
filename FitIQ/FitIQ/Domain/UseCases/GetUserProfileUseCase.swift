// Domain/UseCases/GetUserProfileUseCase.swift
import Foundation

public protocol GetUserProfileUseCaseProtocol {
    func execute(forUserID userID: UUID) async throws -> UserProfile?
}

public final class GetUserProfileUseCase: GetUserProfileUseCaseProtocol {
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager // To get current user ID

    init(userProfileStorage: UserProfileStoragePortProtocol, authManager: AuthManager) {
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager
    }

    public func execute(forUserID userID: UUID) async throws -> UserProfile? {
        guard userID == authManager.currentUserProfileID else {
            print("GetUserProfileUseCase: Attempt to fetch profile for a different user ID than current authenticated user.")
            // Potentially throw an error or return nil based on security requirements
            return nil
        }
        return try await userProfileStorage.fetch(forUserID: userID)
    }
    
    // Convenience method to fetch for the current authenticated user
    public func executeForCurrentUser() async throws -> UserProfile? {
        guard let currentUserID = authManager.currentUserProfileID else {
            print("GetUserProfileUseCase: No authenticated user ID.")
            throw UserProfileError.notAuthenticated
        }
        return try await userProfileStorage.fetch(forUserID: currentUserID)
    }
}

public enum UserProfileError: Error, LocalizedError {
    case notAuthenticated
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No authenticated user. Please log in."
        }
    }
}

