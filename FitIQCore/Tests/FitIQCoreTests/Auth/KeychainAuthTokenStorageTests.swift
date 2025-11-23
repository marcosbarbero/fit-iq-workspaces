//
//  KeychainAuthTokenStorageTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team
//

import XCTest
@testable import FitIQCore

final class KeychainAuthTokenStorageTests: XCTestCase {

    var sut: KeychainAuthTokenStorage!

    // Test keys - use unique keys to avoid conflicts with production data
    private let testAccessTokenKey = "com.marcosbarbero.FitIQ.authToken.test"
    private let testRefreshTokenKey = "com.marcosbarbero.FitIQ.refreshToken.test"
    private let testUserProfileIDKey = "com.marcosbarbero.FitIQ.userProfileID.test"

    override func setUp() {
        super.setUp()
        sut = KeychainAuthTokenStorage()

        // Clean up any existing test data
        try? KeychainManager.delete(key: testAccessTokenKey)
        try? KeychainManager.delete(key: testRefreshTokenKey)
        try? KeychainManager.delete(key: testUserProfileIDKey)
    }

    override func tearDown() {
        // Clean up test data after each test
        try? KeychainManager.delete(key: testAccessTokenKey)
        try? KeychainManager.delete(key: testRefreshTokenKey)
        try? KeychainManager.delete(key: testUserProfileIDKey)

        sut = nil
        super.tearDown()
    }

    // MARK: - Token Storage Tests

    func testSaveTokens_ValidTokens_SavesSuccessfully() throws {
        // Arrange
        let accessToken = "test_access_token_123"
        let refreshToken = "test_refresh_token_456"

        // Act
        try sut.save(accessToken: accessToken, refreshToken: refreshToken)

        // Assert
        let savedAccessToken = try sut.fetchAccessToken()
        let savedRefreshToken = try sut.fetchRefreshToken()

        XCTAssertEqual(savedAccessToken, accessToken)
        XCTAssertEqual(savedRefreshToken, refreshToken)
    }

    func testFetchAccessToken_NoToken_ReturnsNil() throws {
        // Act
        let token = try sut.fetchAccessToken()

        // Assert
        XCTAssertNil(token)
    }

    func testFetchRefreshToken_NoToken_ReturnsNil() throws {
        // Act
        let token = try sut.fetchRefreshToken()

        // Assert
        XCTAssertNil(token)
    }

    func testDeleteTokens_ExistingTokens_DeletesSuccessfully() throws {
        // Arrange
        let accessToken = "test_access_token"
        let refreshToken = "test_refresh_token"
        try sut.save(accessToken: accessToken, refreshToken: refreshToken)

        // Act
        try sut.deleteTokens()

        // Assert
        let savedAccessToken = try sut.fetchAccessToken()
        let savedRefreshToken = try sut.fetchRefreshToken()

        XCTAssertNil(savedAccessToken)
        XCTAssertNil(savedRefreshToken)
    }

    func testDeleteTokens_NoTokens_DoesNotThrow() throws {
        // Act & Assert - should not throw
        XCTAssertNoThrow(try sut.deleteTokens())
    }

    func testSaveTokens_OverwriteExisting_UpdatesTokens() throws {
        // Arrange
        let initialAccessToken = "initial_access"
        let initialRefreshToken = "initial_refresh"
        try sut.save(accessToken: initialAccessToken, refreshToken: initialRefreshToken)

        let newAccessToken = "new_access"
        let newRefreshToken = "new_refresh"

        // Act
        try sut.save(accessToken: newAccessToken, refreshToken: newRefreshToken)

        // Assert
        let savedAccessToken = try sut.fetchAccessToken()
        let savedRefreshToken = try sut.fetchRefreshToken()

        XCTAssertEqual(savedAccessToken, newAccessToken)
        XCTAssertEqual(savedRefreshToken, newRefreshToken)
    }

    // MARK: - User Profile ID Tests

    func testSaveUserProfileID_ValidUUID_SavesSuccessfully() throws {
        // Arrange
        let userID = UUID()

        // Act
        try sut.saveUserProfileID(userID)

        // Assert
        let savedUserID = try sut.fetchUserProfileID()
        XCTAssertEqual(savedUserID, userID)
    }

    func testFetchUserProfileID_NoID_ReturnsNil() throws {
        // Act
        let userID = try sut.fetchUserProfileID()

        // Assert
        XCTAssertNil(userID)
    }

    func testDeleteUserProfileID_ExistingID_DeletesSuccessfully() throws {
        // Arrange
        let userID = UUID()
        try sut.saveUserProfileID(userID)

        // Act
        try sut.deleteUserProfileID()

        // Assert
        let savedUserID = try sut.fetchUserProfileID()
        XCTAssertNil(savedUserID)
    }

    func testDeleteUserProfileID_NoID_DoesNotThrow() throws {
        // Act & Assert - should not throw
        XCTAssertNoThrow(try sut.deleteUserProfileID())
    }

    func testSaveUserProfileID_OverwriteExisting_UpdatesID() throws {
        // Arrange
        let initialUserID = UUID()
        try sut.saveUserProfileID(initialUserID)

        let newUserID = UUID()

        // Act
        try sut.saveUserProfileID(newUserID)

        // Assert
        let savedUserID = try sut.fetchUserProfileID()
        XCTAssertEqual(savedUserID, newUserID)
        XCTAssertNotEqual(savedUserID, initialUserID)
    }

    // MARK: - Integration Tests

    func testFullAuthFlow_SaveFetchDelete_WorksCorrectly() throws {
        // Arrange
        let accessToken = "test_access_token"
        let refreshToken = "test_refresh_token"
        let userID = UUID()

        // Act - Save
        try sut.save(accessToken: accessToken, refreshToken: refreshToken)
        try sut.saveUserProfileID(userID)

        // Assert - Verify saved
        XCTAssertEqual(try sut.fetchAccessToken(), accessToken)
        XCTAssertEqual(try sut.fetchRefreshToken(), refreshToken)
        XCTAssertEqual(try sut.fetchUserProfileID(), userID)

        // Act - Delete
        try sut.deleteTokens()
        try sut.deleteUserProfileID()

        // Assert - Verify deleted
        XCTAssertNil(try sut.fetchAccessToken())
        XCTAssertNil(try sut.fetchRefreshToken())
        XCTAssertNil(try sut.fetchUserProfileID())
    }

    func testTokenPersistence_AcrossInstances_Persists() throws {
        // Arrange
        let accessToken = "persistent_access_token"
        let refreshToken = "persistent_refresh_token"
        let storage1 = KeychainAuthTokenStorage()

        // Act
        try storage1.save(accessToken: accessToken, refreshToken: refreshToken)

        // Create new instance
        let storage2 = KeychainAuthTokenStorage()

        // Assert - New instance can read data saved by old instance
        XCTAssertEqual(try storage2.fetchAccessToken(), accessToken)
        XCTAssertEqual(try storage2.fetchRefreshToken(), refreshToken)

        // Cleanup
        try storage2.deleteTokens()
    }
}
