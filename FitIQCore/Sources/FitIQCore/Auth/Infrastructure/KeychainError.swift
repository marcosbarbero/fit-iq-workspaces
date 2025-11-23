//
//  KeychainError.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Errors that can occur during Keychain operations
public enum KeychainError: Error, LocalizedError {
    /// An item with the same key already exists
    case duplicateItem

    /// An unknown error occurred with the given status code
    case unknown(OSStatus)

    /// The requested item was not found
    case itemNotFound

    /// Failed to convert data to/from string
    case dataConversionError

    /// Failed to encode data for storage
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "An item with the same key already exists in the Keychain."
        case .unknown(let status):
            return "An unknown Keychain error occurred with status: \(status)."
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .dataConversionError:
            return "Failed to convert data to/from string for Keychain storage."
        case .encodingFailed:
            return "Failed to encode data for Keychain storage."
        }
    }
}
