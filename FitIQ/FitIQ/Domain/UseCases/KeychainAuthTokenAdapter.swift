// Infrastructure/Persistence/KeychainAuthTokenAdapter.swift
import Foundation

/// An adapter that implements AuthTokenPersistencePortProtocol using KeychainManager.
/// This bridges the domain's need to store tokens to the infrastructure's Keychain service.
class KeychainAuthTokenAdapter: AuthTokenPersistencePortProtocol {
    private enum KeychainKey: String {
        case authToken = "com.marcosbarbero.FitIQ.authToken"
        case refreshToken = "com.marcosbarbero.FitIQ.refreshToken"
        case userProfileID = "com.marcosbarbero.FitIQ.userProfileID"
    }

    func save(accessToken: String, refreshToken: String) throws {
        do {
            try KeychainManager.save(key: KeychainKey.authToken.rawValue, value: accessToken)
            try KeychainManager.save(key: KeychainKey.refreshToken.rawValue, value: refreshToken)
            print("Successfully saved auth tokens to Keychain.")
        } catch {
            print("Failed to save auth tokens to Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    // NEW: Implement fetchAccessToken
    func fetchAccessToken() throws -> String? {
        do {
            return try KeychainManager.read(key: KeychainKey.authToken.rawValue)
        } catch {
            print("Failed to fetch access token from Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    // NEW: Implement fetchRefreshToken
    func fetchRefreshToken() throws -> String? {
        do {
            return try KeychainManager.read(key: KeychainKey.refreshToken.rawValue)
        } catch {
            print("Failed to fetch refresh token from Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteTokens() throws {
        do {
            try KeychainManager.delete(key: KeychainKey.authToken.rawValue)
            try KeychainManager.delete(key: KeychainKey.refreshToken.rawValue)
            print("Successfully deleted auth tokens from Keychain.")
        } catch {
            print("Failed to delete auth tokens from Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    func saveUserProfileID(_ userID: UUID) throws {
        do {
            try KeychainManager.save(key: KeychainKey.userProfileID.rawValue, value: userID.uuidString)
            print("Successfully saved user profile ID \(userID) to Keychain.")
        } catch {
            print("Failed to save user profile ID to Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchUserProfileID() throws -> UUID? {
        do {
            if let idString = try KeychainManager.read(key: KeychainKey.userProfileID.rawValue), !idString.isEmpty {
                return UUID(uuidString: idString)
            }
            return nil
        } catch {
            print("Failed to fetch user profile ID from Keychain: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteUserProfileID() throws {
        do {
            try KeychainManager.delete(key: KeychainKey.userProfileID.rawValue)
            print("Successfully deleted user profile ID from Keychain.")
        } catch {
            print("Failed to delete user profile ID from Keychain: \(error.localizedDescription)")
            throw error
        }
    }
}
