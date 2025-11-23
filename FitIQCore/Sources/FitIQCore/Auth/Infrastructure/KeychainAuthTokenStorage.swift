//
//  KeychainAuthTokenStorage.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// An adapter that implements AuthTokenPersistenceProtocol using KeychainManager.
/// This bridges the domain's need to store tokens to the infrastructure's Keychain service.
public final class KeychainAuthTokenStorage: AuthTokenPersistenceProtocol {

    // MARK: - Properties

    private enum KeychainKey: String {
        case authToken = "com.marcosbarbero.FitIQ.authToken"
        case refreshToken = "com.marcosbarbero.FitIQ.refreshToken"
        case userProfileID = "com.marcosbarbero.FitIQ.userProfileID"
        case userProfile = "com.marcosbarbero.FitIQ.userProfile"
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - AuthTokenPersistenceProtocol

    public func save(accessToken: String, refreshToken: String) throws {
        do {
            try KeychainManager.save(key: KeychainKey.authToken.rawValue, value: accessToken)
            try KeychainManager.save(key: KeychainKey.refreshToken.rawValue, value: refreshToken)
            print("FitIQCore: Successfully saved auth tokens to Keychain.")
        } catch {
            print(
                "FitIQCore: Failed to save auth tokens to Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    public func fetchAccessToken() throws -> String? {
        do {
            return try KeychainManager.read(key: KeychainKey.authToken.rawValue)
        } catch {
            print(
                "FitIQCore: Failed to fetch access token from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func fetchRefreshToken() throws -> String? {
        do {
            return try KeychainManager.read(key: KeychainKey.refreshToken.rawValue)
        } catch {
            print(
                "FitIQCore: Failed to fetch refresh token from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func deleteTokens() throws {
        do {
            try KeychainManager.delete(key: KeychainKey.authToken.rawValue)
            try KeychainManager.delete(key: KeychainKey.refreshToken.rawValue)
            print("FitIQCore: Successfully deleted auth tokens from Keychain.")
        } catch {
            print(
                "FitIQCore: Failed to delete auth tokens from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func saveUserProfileID(_ userID: UUID) throws {
        do {
            try KeychainManager.save(
                key: KeychainKey.userProfileID.rawValue,
                value: userID.uuidString
            )
            print("FitIQCore: Successfully saved user profile ID \(userID) to Keychain.")
        } catch {
            print(
                "FitIQCore: Failed to save user profile ID to Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func fetchUserProfileID() throws -> UUID? {
        do {
            if let idString = try KeychainManager.read(key: KeychainKey.userProfileID.rawValue),
                !idString.isEmpty
            {
                return UUID(uuidString: idString)
            }
            return nil
        } catch {
            print(
                "FitIQCore: Failed to fetch user profile ID from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func deleteUserProfileID() throws {
        do {
            try KeychainManager.delete(key: KeychainKey.userProfileID.rawValue)
            print("FitIQCore: Successfully deleted user profile ID from Keychain.")
        } catch {
            print(
                "FitIQCore: Failed to delete user profile ID from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func saveUserProfile(_ profile: UserProfile) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)

            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw KeychainError.encodingFailed
            }

            try KeychainManager.save(
                key: KeychainKey.userProfile.rawValue,
                value: jsonString
            )
            print("FitIQCore: Successfully saved user profile to Keychain (ID: \(profile.id)).")
        } catch {
            print(
                "FitIQCore: Failed to save user profile to Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    public func fetchUserProfile() throws -> UserProfile? {
        do {
            guard let jsonString = try KeychainManager.read(key: KeychainKey.userProfile.rawValue),
                !jsonString.isEmpty,
                let data = jsonString.data(using: .utf8)
            else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profile = try decoder.decode(UserProfile.self, from: data)
            return profile
        } catch {
            print(
                "FitIQCore: Failed to fetch user profile from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func deleteUserProfile() throws {
        do {
            try KeychainManager.delete(key: KeychainKey.userProfile.rawValue)
            print("FitIQCore: Successfully deleted user profile from Keychain.")
        } catch {
            print(
                "FitIQCore: Failed to delete user profile from Keychain: \(error.localizedDescription)"
            )
            throw error
        }
    }
}
