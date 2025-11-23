//
//  KeychainManager.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation
import Security

/// Manages secure storage operations using the iOS Keychain
public class KeychainManager {

    // MARK: - Public Methods

    /// Stores a string securely in the Keychain
    /// - Parameters:
    ///   - key: The key to associate with the data
    ///   - value: The string value to store
    /// - Throws: `KeychainError` if the operation fails
    public static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Only accessible after the first unlock, and only on this device
            // This offers a good balance of security and usability
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Delete any existing item with the same key before adding a new one
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                // This case should ideally not be reached because of SecItemDelete above,
                // but included for robustness
                throw KeychainError.duplicateItem
            } else {
                throw KeychainError.unknown(status)
            }
        }
    }

    /// Retrieves a string from the Keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The retrieved string, or `nil` if not found
    /// - Throws: `KeychainError` if the operation fails (other than `itemNotFound`)
    public static func read(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // Item not found is not an error for reading, just means it's not there
                return nil
            } else {
                throw KeychainError.unknown(status)
            }
        }

        guard let data = item as? Data,
            let string = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.dataConversionError
        }

        return string
    }

    /// Deletes a string from the Keychain
    /// - Parameter key: The key associated with the data to delete
    /// - Throws: `KeychainError` if the operation fails
    public static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is not an error for deletion, as it means it's already gone
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
