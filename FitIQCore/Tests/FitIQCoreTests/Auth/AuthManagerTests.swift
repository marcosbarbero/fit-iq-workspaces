//
//  AuthManagerTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team
//

import XCTest

@testable import FitIQCore

final class AuthManagerTests: XCTestCase {

    var sut: AuthManager!
    fileprivate var mockTokenStorage: MockAuthTokenStorage!

    override func setUp() {
        super.setUp()
        mockTokenStorage = MockAuthTokenStorage()
        sut = AuthManager(
            authTokenPersistence: mockTokenStorage,
            onboardingKey: "test_onboarding_key"
        )
    }

    override func tearDown() {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "test_onboarding_key")
        sut = nil
        mockTokenStorage = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_NoStoredTokens_SetsUnauthenticated() async {
        // Arrange
        mockTokenStorage.accessToken = nil

        // Act
        let authManager = AuthManager(
            authTokenPersistence: mockTokenStorage,
            onboardingKey: "test_key"
        )

        // Wait for async initialization
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Assert
        await MainActor.run {
            XCTAssertFalse(authManager.isAuthenticated)
            XCTAssertNil(authManager.currentUserProfileID)
            XCTAssertEqual(authManager.currentAuthState, .loggedOut)
        }
    }

    func testInit_WithStoredTokens_SetsAuthenticated() async {
        // Arrange
        let userID = UUID()
        mockTokenStorage.accessToken = "valid_token"
        mockTokenStorage.userProfileID = userID

        // Act
        let authManager = AuthManager(
            authTokenPersistence: mockTokenStorage,
            onboardingKey: "test_key"
        )

        // Wait for async initialization
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Assert
        await MainActor.run {
            XCTAssertTrue(authManager.isAuthenticated)
            XCTAssertEqual(authManager.currentUserProfileID, userID)
        }
    }

    // MARK: - Authentication Status Tests

    func testCheckAuthenticationStatus_ValidToken_SetsAuthenticated() async {
        // Arrange
        let userID = UUID()
        mockTokenStorage.accessToken = "valid_token"
        mockTokenStorage.userProfileID = userID

        // Act
        await sut.checkAuthenticationStatus()

        // Assert
        await MainActor.run {
            XCTAssertTrue(sut.isAuthenticated)
            XCTAssertEqual(sut.currentUserProfileID, userID)
        }
    }

    func testCheckAuthenticationStatus_NoToken_SetsUnauthenticated() async {
        // Arrange
        mockTokenStorage.accessToken = nil

        // Act
        await sut.checkAuthenticationStatus()

        // Assert
        await MainActor.run {
            XCTAssertFalse(sut.isAuthenticated)
            XCTAssertNil(sut.currentUserProfileID)
        }
    }

    func testCheckAuthenticationStatus_EmptyToken_SetsUnauthenticated() async {
        // Arrange
        mockTokenStorage.accessToken = ""

        // Act
        await sut.checkAuthenticationStatus()

        // Assert
        await MainActor.run {
            XCTAssertFalse(sut.isAuthenticated)
            XCTAssertNil(sut.currentUserProfileID)
        }
    }

    // MARK: - Handle Successful Auth Tests

    func testHandleSuccessfulAuth_ValidUserID_SetsAuthenticatedAndSavesID() async {
        // Arrange
        let userID = UUID()

        // Act
        await sut.handleSuccessfulAuth(userProfileID: userID)

        // Assert
        await MainActor.run {
            XCTAssertTrue(sut.isAuthenticated)
            XCTAssertEqual(sut.currentUserProfileID, userID)
            XCTAssertEqual(mockTokenStorage.savedUserProfileID, userID)
        }
    }

    func testHandleSuccessfulAuth_NilUserID_DoesNotSetAuthenticated() async {
        // Act
        await sut.handleSuccessfulAuth(userProfileID: nil)

        // Assert
        await MainActor.run {
            XCTAssertFalse(sut.isAuthenticated)
            XCTAssertNil(sut.currentUserProfileID)
            XCTAssertNil(mockTokenStorage.savedUserProfileID)
        }
    }

    // MARK: - Logout Tests

    func testLogout_ClearsAuthenticationAndDeletesTokens() async {
        // Arrange
        let userID = UUID()
        mockTokenStorage.accessToken = "token"
        mockTokenStorage.userProfileID = userID
        await sut.handleSuccessfulAuth(userProfileID: userID)

        // Act
        await sut.logout()

        // Assert
        await MainActor.run {
            XCTAssertFalse(sut.isAuthenticated)
            XCTAssertNil(sut.currentUserProfileID)
            XCTAssertFalse(sut.isInitialDataLoadComplete)
            XCTAssertTrue(mockTokenStorage.deleteTokensCalled)
            XCTAssertTrue(mockTokenStorage.deleteUserProfileIDCalled)
        }
    }

    func testLogout_ClearsOnboardingFlag() async {
        // Arrange
        await MainActor.run {
            UserDefaults.standard.set(true, forKey: "test_onboarding_key")
        }

        // Act
        await sut.logout()

        // Assert
        await MainActor.run {
            XCTAssertFalse(sut.hasCompletedOnboarding)
        }
    }

    // MARK: - Onboarding Tests

    func testHasCompletedOnboarding_NotSet_ReturnsFalse() async {
        // Act & Assert
        await MainActor.run {
            XCTAssertFalse(sut.hasCompletedOnboarding)
        }
    }

    func testHasCompletedOnboarding_Set_ReturnsTrue() async {
        // Arrange
        await MainActor.run {
            UserDefaults.standard.set(true, forKey: "test_onboarding_key")
        }

        // Act & Assert
        await MainActor.run {
            XCTAssertTrue(sut.hasCompletedOnboarding)
        }
    }

    func testCompleteOnboarding_SetsOnboardingFlagAndTransitionsToLoading() async {
        // Act
        await sut.completeOnboarding()

        // Assert
        await MainActor.run {
            XCTAssertTrue(sut.hasCompletedOnboarding)
            XCTAssertEqual(sut.currentAuthState, .loadingInitialData)
            XCTAssertFalse(sut.isInitialDataLoadComplete)
        }
    }

    func testCompleteInitialDataLoad_SetsLoadCompleteAndTransitionsToLoggedIn() async {
        // Act
        await sut.completeInitialDataLoad()

        // Assert
        await MainActor.run {
            XCTAssertTrue(sut.isInitialDataLoadComplete)
            XCTAssertEqual(sut.currentAuthState, .loggedIn)
        }
    }

    // MARK: - Auth State Tests

    func testCurrentAuthState_UnauthenticatedUser_IsLoggedOut() async {
        // Arrange
        mockTokenStorage.accessToken = nil

        // Act
        await sut.checkAuthenticationStatus()

        // Assert
        await MainActor.run {
            XCTAssertEqual(sut.currentAuthState, .loggedOut)
        }
    }

    func testCurrentAuthState_AuthenticatedWithoutOnboarding_IsNeedsSetup() async {
        // Arrange
        let userID = UUID()
        mockTokenStorage.accessToken = "test-access-token"
        mockTokenStorage.refreshToken = "test-refresh-token"
        mockTokenStorage.userProfileID = userID
        await sut.handleSuccessfulAuth(userProfileID: userID)
        await MainActor.run {
            UserDefaults.standard.set(false, forKey: "test_onboarding_key")
        }

        // Act
        await sut.checkAuthenticationStatus()

        // Assert
        await MainActor.run {
            XCTAssertEqual(sut.currentAuthState, .needsSetup)
        }
    }

    func testCurrentAuthState_AuthenticatedWithOnboarding_IsLoggedIn() async {
        // Arrange
        let userID = UUID()
        mockTokenStorage.accessToken = "test-access-token"
        mockTokenStorage.refreshToken = "test-refresh-token"
        mockTokenStorage.userProfileID = userID
        await sut.handleSuccessfulAuth(userProfileID: userID)
        await MainActor.run {
            UserDefaults.standard.set(true, forKey: "test_onboarding_key")
        }

        // Act
        await sut.checkAuthenticationStatus()

        // Assert
        await MainActor.run {
            XCTAssertEqual(sut.currentAuthState, .loggedIn)
        }
    }

    // MARK: - Fetch Access Token Tests

    func testFetchAccessToken_ReturnsTokenFromStorage() throws {
        // Arrange
        let expectedToken = "test_access_token"
        mockTokenStorage.accessToken = expectedToken

        // Act
        let token = try sut.fetchAccessToken()

        // Assert
        XCTAssertEqual(token, expectedToken)
    }

    func testFetchAccessToken_NoToken_ReturnsNil() throws {
        // Arrange
        mockTokenStorage.accessToken = nil

        // Act
        let token = try sut.fetchAccessToken()

        // Assert
        XCTAssertNil(token)
    }
}

// MARK: - Mock Auth Token Storage

private final class MockAuthTokenStorage: AuthTokenPersistenceProtocol {
    var accessToken: String?
    var refreshToken: String?
    var userProfileID: UUID?
    var savedUserProfileID: UUID?

    var deleteTokensCalled = false
    var deleteUserProfileIDCalled = false
    var saveTokensCalled = false
    var saveUserProfileIDCalled = false

    func save(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        saveTokensCalled = true
    }

    func fetchAccessToken() throws -> String? {
        return accessToken
    }

    func fetchRefreshToken() throws -> String? {
        return refreshToken
    }

    func deleteTokens() throws {
        accessToken = nil
        refreshToken = nil
        deleteTokensCalled = true
    }

    func saveUserProfileID(_ userID: UUID) throws {
        self.userProfileID = userID
        self.savedUserProfileID = userID
        saveUserProfileIDCalled = true
    }

    func fetchUserProfileID() throws -> UUID? {
        return userProfileID
    }

    func deleteUserProfileID() throws {
        userProfileID = nil
        deleteUserProfileIDCalled = true
    }
}
