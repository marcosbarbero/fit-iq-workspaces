//
//  AuthToken.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Authentication tokens with JWT parsing and validation capabilities
///
/// This entity represents JWT access and refresh tokens used for API authentication.
/// It provides production-ready features including:
/// - JWT payload parsing (expiration, user ID)
/// - Automatic expiration tracking
/// - Proactive refresh detection
/// - Validation and security features
///
/// **Usage:**
/// ```swift
/// // Create with automatic JWT parsing
/// let token = AuthToken.withParsedExpiration(
///     accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///     refreshToken: "dGhpc2lzYXJlZnJlc2h0b2tlbg..."
/// )
///
/// // Check expiration
/// if token.willExpireSoon {
///     // Proactively refresh before expiration
/// }
///
/// // Parse user ID from JWT
/// if let userId = token.parseUserIdFromJWT() {
///     print("User: \(userId)")
/// }
/// ```
///
/// **Thread Safety:** This is an immutable value type and is thread-safe.
public struct AuthToken: Equatable, Sendable {

    // MARK: - Properties

    /// JWT access token
    ///
    /// Used for authenticating API requests via `Authorization: Bearer <token>` header.
    /// Typically short-lived (e.g., 1 hour).
    public let accessToken: String

    /// Refresh token for obtaining new access tokens
    ///
    /// Used to get a new access token when the current one expires.
    /// Typically longer-lived than access token (e.g., 7 days).
    public let refreshToken: String

    /// Optional expiration time
    ///
    /// When the access token expires. Can be parsed from JWT claims using `parseExpirationFromJWT()`.
    /// If nil, token expiration is unknown.
    public let expiresAt: Date?

    // MARK: - Computed Properties

    /// Whether the access token has expired
    ///
    /// Returns true if expiresAt is set and is in the past.
    /// If expiresAt is nil, assumes token is still valid (conservative approach).
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt <= Date()
    }

    /// Whether the access token will expire soon (within 5 minutes)
    ///
    /// Useful for proactive token refresh before actual expiration.
    /// Prevents race conditions where token expires during a request.
    public var willExpireSoon: Bool {
        guard let expiresAt = expiresAt else { return false }
        let fiveMinutesFromNow = Date().addingTimeInterval(5 * 60)
        return expiresAt <= fiveMinutesFromNow
    }

    /// Time until expiration in seconds
    ///
    /// Returns nil if expiresAt is not set or token is already expired.
    /// Useful for scheduling refresh operations.
    public var secondsUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt, !isExpired else { return nil }
        return expiresAt.timeIntervalSinceNow
    }

    /// Whether both tokens are non-empty
    ///
    /// Basic validation that tokens exist. Does not verify token format or signature.
    public var isValid: Bool {
        !accessToken.isEmpty && !refreshToken.isEmpty
    }

    // MARK: - Initializer

    /// Creates a new AuthToken instance
    ///
    /// - Parameters:
    ///   - accessToken: JWT access token (required)
    ///   - refreshToken: Refresh token (required)
    ///   - expiresAt: Expiration time (optional, can be parsed from JWT using `withParsedExpiration`)
    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

// MARK: - JWT Parsing

extension AuthToken {

    /// Parses the expiration time from the JWT access token
    ///
    /// This extracts the "exp" claim from the JWT payload (second segment).
    /// The JWT format is: header.payload.signature
    ///
    /// - Returns: Expiration date or nil if parsing fails
    public func parseExpirationFromJWT() -> Date? {
        let segments = accessToken.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = segments[1]

        // Decode base64url to JSON
        guard let payloadData = decodeBase64URL(payloadSegment),
            let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
            let exp = json["exp"] as? TimeInterval
        else {
            return nil
        }

        return Date(timeIntervalSince1970: exp)
    }

    /// Parses the user ID from the JWT access token
    ///
    /// This extracts the "sub" (subject) claim from the JWT payload.
    /// In FitIQ backend, this is the user's unique identifier.
    ///
    /// - Returns: User ID string or nil if parsing fails
    public func parseUserIdFromJWT() -> String? {
        let segments = accessToken.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = segments[1]

        // Decode base64url to JSON
        guard let payloadData = decodeBase64URL(payloadSegment),
            let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
            let userId = json["sub"] as? String
        else {
            return nil
        }

        return userId
    }

    /// Parses the email from the JWT access token
    ///
    /// This extracts the "email" claim from the JWT payload.
    ///
    /// - Returns: Email string or nil if parsing fails
    public func parseEmailFromJWT() -> String? {
        let segments = accessToken.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }

        let payloadSegment = segments[1]

        // Decode base64url to JSON
        guard let payloadData = decodeBase64URL(payloadSegment),
            let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
            let email = json["email"] as? String
        else {
            return nil
        }

        return email
    }

    /// Creates a new AuthToken with expiration parsed from JWT
    ///
    /// Convenience method to create token with expiration automatically extracted.
    /// This is the recommended way to create tokens from API responses.
    ///
    /// - Parameters:
    ///   - accessToken: JWT access token
    ///   - refreshToken: Refresh token
    /// - Returns: AuthToken with parsed expiration or nil expiration if parsing fails
    public static func withParsedExpiration(
        accessToken: String,
        refreshToken: String
    ) -> AuthToken {
        let token = AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: nil
        )
        let expiresAt = token.parseExpirationFromJWT()
        return AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    // MARK: - Private Helpers

    /// Decodes base64url-encoded string to Data
    ///
    /// JWT uses base64url encoding (RFC 4648) which differs from standard base64:
    /// - Uses '-' instead of '+'
    /// - Uses '_' instead of '/'
    /// - Omits padding '=' characters
    ///
    /// - Parameter string: Base64url-encoded string
    /// - Returns: Decoded data or nil if decoding fails
    private func decodeBase64URL(_ string: String) -> Data? {
        // Convert base64url to base64
        var base64 =
            string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        return Data(base64Encoded: base64)
    }
}

// MARK: - Security

extension AuthToken {

    /// Sanitized description for logging (hides sensitive data)
    ///
    /// Only shows first/last few characters of tokens for debugging.
    /// **Never log full tokens in production.**
    ///
    /// Example output:
    /// ```
    /// AuthToken(access: eyJhbGciOi...VCJ9, refresh: dGhpc2lzYX...a2VuZw, expires: 2025-01-27 15:30:00)
    /// ```
    public var sanitizedDescription: String {
        let accessPreview = String(accessToken.prefix(10)) + "..." + String(accessToken.suffix(10))
        let refreshPreview =
            String(refreshToken.prefix(10)) + "..." + String(refreshToken.suffix(10))
        let expiresString = expiresAt.map { "expires: \($0)" } ?? "no expiration"
        return "AuthToken(access: \(accessPreview), refresh: \(refreshPreview), \(expiresString))"
    }
}

// MARK: - Validation

extension AuthToken {

    /// Validates that the token meets business rules
    ///
    /// Checks for:
    /// - Non-empty tokens
    /// - Valid JWT format (3 segments)
    /// - Reasonable expiration dates
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Access token cannot be empty
        if accessToken.isEmpty {
            errors.append(.emptyAccessToken)
        }

        // Refresh token cannot be empty
        if refreshToken.isEmpty {
            errors.append(.emptyRefreshToken)
        }

        // Access token should look like a JWT (has 3 parts: header.payload.signature)
        if !accessToken.isEmpty {
            let segments = accessToken.components(separatedBy: ".")
            if segments.count != 3 {
                errors.append(.invalidAccessTokenFormat)
            }
        }

        // If expiration is set, it should not be in the distant past
        if let expiresAt = expiresAt {
            let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60)
            if expiresAt < oneYearAgo {
                errors.append(.expirationTooOld)
            }
        }

        return errors
    }

    /// Validation errors for AuthToken
    public enum ValidationError: Error, LocalizedError, Equatable, Sendable {
        case emptyAccessToken
        case emptyRefreshToken
        case invalidAccessTokenFormat
        case expirationTooOld

        public var errorDescription: String? {
            switch self {
            case .emptyAccessToken:
                return "Access token cannot be empty"
            case .emptyRefreshToken:
                return "Refresh token cannot be empty"
            case .invalidAccessTokenFormat:
                return "Access token does not appear to be a valid JWT"
            case .expirationTooOld:
                return "Token expiration date is too old"
            }
        }
    }
}

// MARK: - Codable

extension AuthToken: Codable {

    /// Coding keys for JSON serialization
    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case expiresAt
    }

    /// Decodes an AuthToken from JSON
    ///
    /// If expiresAt is not present in JSON, attempts to parse it from JWT.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let accessToken = try container.decode(String.self, forKey: .accessToken)
        let refreshToken = try container.decode(String.self, forKey: .refreshToken)
        let expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)

        // If expiresAt is not provided, try to parse from JWT
        if expiresAt == nil {
            self = AuthToken.withParsedExpiration(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        } else {
            self.init(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
        }
    }

    /// Encodes an AuthToken to JSON
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}
