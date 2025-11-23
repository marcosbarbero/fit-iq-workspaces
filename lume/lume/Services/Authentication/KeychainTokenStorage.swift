import FitIQCore
import Foundation

/// Adapter that bridges FitIQCore's KeychainAuthTokenStorage to Lume's TokenStorageProtocol
///
/// This adapter eliminates code duplication by reusing FitIQCore's battle-tested
/// keychain implementation while maintaining compatibility with Lume's existing interfaces.
final class KeychainTokenStorage: TokenStorageProtocol {

    // MARK: - Properties

    private let coreStorage: KeychainAuthTokenStorage

    // MARK: - Initialization

    init(coreStorage: KeychainAuthTokenStorage = KeychainAuthTokenStorage()) {
        self.coreStorage = coreStorage
    }

    // MARK: - TokenStorageProtocol

    func saveToken(_ token: AuthToken) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            do {
                // Save tokens to FitIQCore's keychain storage
                try coreStorage.save(
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken
                )
                continuation.resume()
            } catch {
                continuation.resume(throwing: KeychainError.saveFailed)
            }
        }
    }

    func getToken() async throws -> AuthToken? {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<AuthToken?, Error>) in
            do {
                // Retrieve tokens from FitIQCore's keychain storage
                guard let accessToken = try coreStorage.fetchAccessToken(),
                    let refreshToken = try coreStorage.fetchRefreshToken()
                else {
                    continuation.resume(returning: nil)
                    return
                }

                // Use FitIQCore's JWT parsing to extract expiration
                let token = AuthToken.withParsedExpiration(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )

                continuation.resume(returning: token)
            } catch {
                continuation.resume(throwing: KeychainError.retrievalFailed)
            }
        }
    }

    func deleteToken() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            do {
                try coreStorage.deleteTokens()
                continuation.resume()
            } catch {
                continuation.resume(throwing: KeychainError.deleteFailed)
            }
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case saveFailed
    case retrievalFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save data to Keychain"
        case .retrievalFailed:
            return "Failed to retrieve data from Keychain"
        case .deleteFailed:
            return "Failed to delete data from Keychain"
        }
    }
}
