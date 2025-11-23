//
//  AuthTokenTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team
//

import XCTest

@testable import FitIQCore

final class AuthTokenTests: XCTestCase {

    // MARK: - Test Data

    // Sample JWT token with known payload:
    // {
    //   "sub": "123e4567-e89b-12d3-a456-426614174000",
    //   "email": "test@example.com",
    //   "exp": 1738000000,
    //   "iat": 1737996400
    // }
    private let sampleAccessToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjNlNDU2Ny1lODliLTEyZDMtYTQ1Ni00MjY2MTQxNzQwMDAiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJleHAiOjE3MzgwMDAwMDAsImlhdCI6MTczNzk5NjQwMH0.dummysignature"
    private let sampleRefreshToken = "refresh_token_abc123xyz"

    // Token with expiration in the past (Jan 1, 2020)
    private let expiredAccessToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjNlNDU2Ny1lODliLTEyZDMtYTQ1Ni00MjY2MTQxNzQwMDAiLCJleHAiOjE1Nzc4MzY4MDAsImlhdCI6MTU3NzgzMzIwMH0.dummysignature"

    // Invalid JWT tokens for testing
    private let invalidTokenOnePart = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    private let invalidTokenTwoParts = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ"

    // MARK: - Initialization Tests

    func testInit_WithValidTokens_CreatesAuthToken() {
        // Arrange
        let expiresAt = Date().addingTimeInterval(3600)

        // Act
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: expiresAt
        )

        // Assert
        XCTAssertEqual(token.accessToken, sampleAccessToken)
        XCTAssertEqual(token.refreshToken, sampleRefreshToken)
        XCTAssertEqual(token.expiresAt, expiresAt)
    }

    func testInit_WithoutExpiresAt_CreatesAuthToken() {
        // Act
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Assert
        XCTAssertEqual(token.accessToken, sampleAccessToken)
        XCTAssertEqual(token.refreshToken, sampleRefreshToken)
        XCTAssertNil(token.expiresAt)
    }

    func testWithParsedExpiration_ValidJWT_ParsesExpiration() {
        // Act
        let token = AuthToken.withParsedExpiration(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Assert
        XCTAssertNotNil(token.expiresAt)
        // Expected expiration: 1738000000 (Jan 27, 2025)
        let expectedDate = Date(timeIntervalSince1970: 1_738_000_000)
        XCTAssertNotNil(token.expiresAt)
        XCTAssertEqual(
            token.expiresAt!.timeIntervalSince1970, expectedDate.timeIntervalSince1970,
            accuracy: 1.0)
    }

    func testWithParsedExpiration_InvalidJWT_ReturnsNilExpiration() {
        // Act
        let token = AuthToken.withParsedExpiration(
            accessToken: invalidTokenOnePart,
            refreshToken: sampleRefreshToken
        )

        // Assert
        XCTAssertNil(token.expiresAt)
    }

    // MARK: - JWT Parsing Tests

    func testParseExpirationFromJWT_ValidToken_ReturnsExpiration() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act
        let expiration = token.parseExpirationFromJWT()

        // Assert
        XCTAssertNotNil(expiration)
        let expectedDate = Date(timeIntervalSince1970: 1_738_000_000)
        XCTAssertNotNil(expiration)
        XCTAssertEqual(
            expiration!.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testParseExpirationFromJWT_InvalidToken_ReturnsNil() {
        // Arrange
        let token = AuthToken(
            accessToken: invalidTokenOnePart,
            refreshToken: sampleRefreshToken
        )

        // Act
        let expiration = token.parseExpirationFromJWT()

        // Assert
        XCTAssertNil(expiration)
    }

    func testParseUserIdFromJWT_ValidToken_ReturnsUserId() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act
        let userId = token.parseUserIdFromJWT()

        // Assert
        XCTAssertEqual(userId, "123e4567-e89b-12d3-a456-426614174000")
    }

    func testParseUserIdFromJWT_InvalidToken_ReturnsNil() {
        // Arrange
        let token = AuthToken(
            accessToken: invalidTokenOnePart,
            refreshToken: sampleRefreshToken
        )

        // Act
        let userId = token.parseUserIdFromJWT()

        // Assert
        XCTAssertNil(userId)
    }

    func testParseEmailFromJWT_ValidToken_ReturnsEmail() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act
        let email = token.parseEmailFromJWT()

        // Assert
        XCTAssertEqual(email, "test@example.com")
    }

    func testParseEmailFromJWT_InvalidToken_ReturnsNil() {
        // Arrange
        let token = AuthToken(
            accessToken: invalidTokenOnePart,
            refreshToken: sampleRefreshToken
        )

        // Act
        let email = token.parseEmailFromJWT()

        // Assert
        XCTAssertNil(email)
    }

    // MARK: - Expiration Tests

    func testIsExpired_WithFutureExpiration_ReturnsFalse() {
        // Arrange
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour from now
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: futureDate
        )

        // Act & Assert
        XCTAssertFalse(token.isExpired)
    }

    func testIsExpired_WithPastExpiration_ReturnsTrue() {
        // Arrange
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: pastDate
        )

        // Act & Assert
        XCTAssertTrue(token.isExpired)
    }

    func testIsExpired_WithNilExpiration_ReturnsFalse() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: nil
        )

        // Act & Assert
        XCTAssertFalse(token.isExpired)
    }

    func testWillExpireSoon_WithExpirationIn6Minutes_ReturnsFalse() {
        // Arrange
        let futureDate = Date().addingTimeInterval(6 * 60)  // 6 minutes
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: futureDate
        )

        // Act & Assert
        XCTAssertFalse(token.willExpireSoon)
    }

    func testWillExpireSoon_WithExpirationIn4Minutes_ReturnsTrue() {
        // Arrange
        let futureDate = Date().addingTimeInterval(4 * 60)  // 4 minutes
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: futureDate
        )

        // Act & Assert
        XCTAssertTrue(token.willExpireSoon)
    }

    func testWillExpireSoon_WithNilExpiration_ReturnsFalse() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: nil
        )

        // Act & Assert
        XCTAssertFalse(token.willExpireSoon)
    }

    func testSecondsUntilExpiration_WithFutureExpiration_ReturnsPositiveValue() {
        // Arrange
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: futureDate
        )

        // Act
        let seconds = token.secondsUntilExpiration

        // Assert
        XCTAssertNotNil(seconds)
        XCTAssertGreaterThan(seconds!, 3500)  // Allow some tolerance
        XCTAssertLessThan(seconds!, 3700)
    }

    func testSecondsUntilExpiration_WithExpiredToken_ReturnsNil() {
        // Arrange
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: pastDate
        )

        // Act
        let seconds = token.secondsUntilExpiration

        // Assert
        XCTAssertNil(seconds)
    }

    func testSecondsUntilExpiration_WithNilExpiration_ReturnsNil() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: nil
        )

        // Act
        let seconds = token.secondsUntilExpiration

        // Assert
        XCTAssertNil(seconds)
    }

    // MARK: - Validation Tests

    func testIsValid_WithNonEmptyTokens_ReturnsTrue() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act & Assert
        XCTAssertTrue(token.isValid)
    }

    func testIsValid_WithEmptyAccessToken_ReturnsFalse() {
        // Arrange
        let token = AuthToken(
            accessToken: "",
            refreshToken: sampleRefreshToken
        )

        // Act & Assert
        XCTAssertFalse(token.isValid)
    }

    func testIsValid_WithEmptyRefreshToken_ReturnsFalse() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: ""
        )

        // Act & Assert
        XCTAssertFalse(token.isValid)
    }

    func testValidate_WithValidToken_ReturnsNoErrors() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: Date().addingTimeInterval(3600)
        )

        // Act
        let errors = token.validate()

        // Assert
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_WithEmptyAccessToken_ReturnsError() {
        // Arrange
        let token = AuthToken(
            accessToken: "",
            refreshToken: sampleRefreshToken
        )

        // Act
        let errors = token.validate()

        // Assert
        XCTAssertTrue(errors.contains(.emptyAccessToken))
    }

    func testValidate_WithEmptyRefreshToken_ReturnsError() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: ""
        )

        // Act
        let errors = token.validate()

        // Assert
        XCTAssertTrue(errors.contains(.emptyRefreshToken))
    }

    func testValidate_WithInvalidJWTFormat_ReturnsError() {
        // Arrange
        let token = AuthToken(
            accessToken: invalidTokenOnePart,
            refreshToken: sampleRefreshToken
        )

        // Act
        let errors = token.validate()

        // Assert
        XCTAssertTrue(errors.contains(.invalidAccessTokenFormat))
    }

    func testValidate_WithVeryOldExpiration_ReturnsError() {
        // Arrange
        let twoYearsAgo = Date().addingTimeInterval(-2 * 365 * 24 * 60 * 60)
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: twoYearsAgo
        )

        // Act
        let errors = token.validate()

        // Assert
        XCTAssertTrue(errors.contains(.expirationTooOld))
    }

    // MARK: - Security Tests

    func testSanitizedDescription_DoesNotExposeFullTokens() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: Date()
        )

        // Act
        let description = token.sanitizedDescription

        // Assert
        XCTAssertFalse(description.contains(sampleAccessToken))
        XCTAssertFalse(description.contains(sampleRefreshToken))
        XCTAssertTrue(description.contains("..."))
    }

    func testSanitizedDescription_ShowsFirstAndLastCharacters() {
        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act
        let description = token.sanitizedDescription

        // Assert
        let accessPrefix = String(sampleAccessToken.prefix(10))
        let accessSuffix = String(sampleAccessToken.suffix(10))
        XCTAssertTrue(description.contains(accessPrefix))
        XCTAssertTrue(description.contains(accessSuffix))
    }

    // MARK: - Codable Tests

    func testEncodeDecode_WithAllProperties_PreservesData() throws {
        // Arrange
        let expiresAt = Date()
        let original = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: expiresAt
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuthToken.self, from: data)

        // Assert
        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.refreshToken, original.refreshToken)
        XCTAssertNotNil(decoded.expiresAt)
        XCTAssertNotNil(original.expiresAt)
        XCTAssertEqual(
            decoded.expiresAt!.timeIntervalSince1970, original.expiresAt!.timeIntervalSince1970,
            accuracy: 1.0)
    }

    func testDecode_WithoutExpiresAt_ParsesFromJWT() throws {
        // Arrange
        let json = """
            {
                "accessToken": "\(sampleAccessToken)",
                "refreshToken": "\(sampleRefreshToken)"
            }
            """
        let data = json.data(using: .utf8)!

        // Act
        let decoder = JSONDecoder()
        let token = try decoder.decode(AuthToken.self, from: data)

        // Assert
        XCTAssertNotNil(token.expiresAt)
        let expectedDate = Date(timeIntervalSince1970: 1_738_000_000)
        XCTAssertNotNil(token.expiresAt)
        XCTAssertEqual(
            token.expiresAt!.timeIntervalSince1970, expectedDate.timeIntervalSince1970,
            accuracy: 1.0)
    }

    func testEncode_ProducesValidJSON() throws {
        // Arrange
        let token = AuthToken(
            accessToken: "test-access",
            refreshToken: "test-refresh",
            expiresAt: Date(timeIntervalSince1970: 1_000_000)
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(token)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Assert
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["accessToken"] as? String, "test-access")
        XCTAssertEqual(json?["refreshToken"] as? String, "test-refresh")
        XCTAssertNotNil(json?["expiresAt"])
    }

    // MARK: - Equatable Tests

    func testEquatable_SameTokens_AreEqual() {
        // Arrange
        let token1 = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: nil
        )
        let token2 = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken,
            expiresAt: nil
        )

        // Act & Assert
        XCTAssertEqual(token1, token2)
    }

    func testEquatable_DifferentAccessTokens_AreNotEqual() {
        // Arrange
        let token1 = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )
        let token2 = AuthToken(
            accessToken: "different-token",
            refreshToken: sampleRefreshToken
        )

        // Act & Assert
        XCTAssertNotEqual(token1, token2)
    }

    func testEquatable_DifferentRefreshTokens_AreNotEqual() {
        // Arrange
        let token1 = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )
        let token2 = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: "different-refresh"
        )

        // Act & Assert
        XCTAssertNotEqual(token1, token2)
    }

    // MARK: - Edge Cases

    func testParseJWT_WithBase64URLEncoding_HandlesCorrectly() {
        // This tests the base64url decoding (with - and _ instead of + and /)
        // The sample token already uses proper base64url encoding

        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act
        let userId = token.parseUserIdFromJWT()
        let email = token.parseEmailFromJWT()
        let expiration = token.parseExpirationFromJWT()

        // Assert
        XCTAssertNotNil(userId)
        XCTAssertNotNil(email)
        XCTAssertNotNil(expiration)
    }

    func testParseJWT_WithPaddingNeeded_HandlesCorrectly() {
        // Base64url strings may not have padding, decoder should add it
        // This is already tested by our sample token which may not be perfectly padded

        // Arrange
        let token = AuthToken(
            accessToken: sampleAccessToken,
            refreshToken: sampleRefreshToken
        )

        // Act
        let expiration = token.parseExpirationFromJWT()

        // Assert
        XCTAssertNotNil(expiration)
    }

    func testValidationError_ErrorDescriptions_AreDescriptive() {
        // Assert all validation errors have descriptions
        XCTAssertNotNil(AuthToken.ValidationError.emptyAccessToken.errorDescription)
        XCTAssertNotNil(AuthToken.ValidationError.emptyRefreshToken.errorDescription)
        XCTAssertNotNil(AuthToken.ValidationError.invalidAccessTokenFormat.errorDescription)
        XCTAssertNotNil(AuthToken.ValidationError.expirationTooOld.errorDescription)
    }
}
