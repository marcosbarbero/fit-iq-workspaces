//
//  TokenRefreshClientTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team
//

import XCTest

@testable import FitIQCore

@available(iOS 17, macOS 12, *)
final class TokenRefreshClientTests: XCTestCase {

    // MARK: - Test Doubles

    /// Mock network client for testing
    private final class MockNetworkClient: NetworkClientProtocol {
        var executeRequestCalled = false
        var executeRequestCallCount = 0
        var requestsReceived: [URLRequest] = []
        var responseToReturn: (Data, HTTPURLResponse)?
        var errorToThrow: Error?

        func executeRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            executeRequestCalled = true
            executeRequestCallCount += 1
            requestsReceived.append(request)

            if let error = errorToThrow {
                throw error
            }

            guard let response = responseToReturn else {
                throw NSError(domain: "MockNetworkClient", code: -1, userInfo: nil)
            }

            return response
        }

        func reset() {
            executeRequestCalled = false
            executeRequestCallCount = 0
            requestsReceived.removeAll()
            responseToReturn = nil
            errorToThrow = nil
        }
    }

    // MARK: - Properties

    private var sut: TokenRefreshClient!
    private var mockNetworkClient: MockNetworkClient!
    private let baseURL = "https://test.example.com"
    private let apiKey = "test-api-key"
    private let refreshToken = "old-refresh-token"

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        sut = TokenRefreshClient(
            baseURL: baseURL,
            apiKey: apiKey,
            networkClient: mockNetworkClient
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createSuccessResponse(
        accessToken: String = "new-access-token",
        refreshToken: String = "new-refresh-token"
    ) -> (Data, HTTPURLResponse) {
        let responseJSON = """
            {
                "success": true,
                "data": {
                    "access_token": "\(accessToken)",
                    "refresh_token": "\(refreshToken)"
                },
                "error": null
            }
            """

        let data = responseJSON.data(using: .utf8)!
        let httpResponse = HTTPURLResponse(
            url: URL(string: baseURL)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (data, httpResponse)
    }

    private func createErrorResponse(
        statusCode: Int = 401,
        message: String = "Invalid refresh token"
    ) -> (Data, HTTPURLResponse) {
        let responseJSON = """
            {
                "success": false,
                "data": null,
                "error": "\(message)"
            }
            """

        let data = responseJSON.data(using: .utf8)!
        let httpResponse = HTTPURLResponse(
            url: URL(string: baseURL)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!

        return (data, httpResponse)
    }

    // MARK: - Initialization Tests

    func testInit_CreatesClientWithCorrectConfiguration() {
        // Assert
        XCTAssertNotNil(sut)
    }

    // MARK: - Success Tests

    func testRefreshToken_WithValidRefreshToken_ReturnsNewTokens() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act
        let response = try await sut.refreshToken(refreshToken: refreshToken)

        // Assert
        XCTAssertEqual(response.accessToken, "new-access-token")
        XCTAssertEqual(response.refreshToken, "new-refresh-token")
    }

    func testRefreshToken_SendsCorrectRequest() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act
        _ = try await sut.refreshToken(refreshToken: refreshToken)

        // Assert
        XCTAssertTrue(mockNetworkClient.executeRequestCalled)
        XCTAssertEqual(mockNetworkClient.executeRequestCallCount, 1)

        let request = mockNetworkClient.requestsReceived.first!
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "\(baseURL)/api/v1/auth/refresh")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), apiKey)

        // Verify request body
        let bodyData = request.httpBody!
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        XCTAssertEqual(bodyJSON["refresh_token"] as? String, refreshToken)
    }

    func testRefreshToken_WithCustomPath_UsesCorrectEndpoint() async throws {
        // Arrange
        let customPath = "/custom/refresh"
        sut = TokenRefreshClient(
            baseURL: baseURL,
            apiKey: apiKey,
            networkClient: mockNetworkClient,
            refreshPath: customPath
        )
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act
        _ = try await sut.refreshToken(refreshToken: refreshToken)

        // Assert
        let request = mockNetworkClient.requestsReceived.first!
        XCTAssertEqual(request.url?.absoluteString, "\(baseURL)\(customPath)")
    }

    // MARK: - Error Handling Tests

    func testRefreshToken_With401Error_ThrowsTokenRefreshError() async {
        // Arrange
        mockNetworkClient.responseToReturn = createErrorResponse(
            statusCode: 401,
            message: "Invalid refresh token"
        )

        // Act & Assert
        do {
            _ = try await sut.refreshToken(refreshToken: refreshToken)
            XCTFail("Expected error to be thrown")
        } catch let error as TokenRefreshError {
            if case .apiError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 401)
                XCTAssertEqual(message, "Invalid refresh token")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testRefreshToken_With500Error_ThrowsTokenRefreshError() async {
        // Arrange
        mockNetworkClient.responseToReturn = createErrorResponse(
            statusCode: 500,
            message: "Server error"
        )

        // Act & Assert
        do {
            _ = try await sut.refreshToken(refreshToken: refreshToken)
            XCTFail("Expected error to be thrown")
        } catch let error as TokenRefreshError {
            if case .apiError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 500)
                XCTAssertEqual(message, "Server error")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testRefreshToken_WithNetworkError_ThrowsError() async {
        // Arrange
        let networkError = NSError(domain: "NetworkError", code: -1, userInfo: nil)
        mockNetworkClient.errorToThrow = networkError

        // Act & Assert
        do {
            _ = try await sut.refreshToken(refreshToken: refreshToken)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Thread Safety Tests

    func testRefreshToken_ConcurrentCalls_OnlyMakesOneRequest() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Set up mock response
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act - Launch 5 concurrent refresh requests
        async let result1 = sut.refreshToken(refreshToken: refreshToken)
        async let result2 = sut.refreshToken(refreshToken: refreshToken)
        async let result3 = sut.refreshToken(refreshToken: refreshToken)
        async let result4 = sut.refreshToken(refreshToken: refreshToken)
        async let result5 = sut.refreshToken(refreshToken: refreshToken)

        let results = try await [result1, result2, result3, result4, result5]

        // Assert - Only one network request was made
        XCTAssertEqual(mockNetworkClient.executeRequestCallCount, 1)

        // All results should be the same
        for result in results {
            XCTAssertEqual(result.accessToken, "new-access-token")
            XCTAssertEqual(result.refreshToken, "new-refresh-token")
        }
    }

    func testRefreshToken_SequentialCalls_MakesMultipleRequests() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act - Make 3 sequential refresh requests
        _ = try await sut.refreshToken(refreshToken: refreshToken)
        _ = try await sut.refreshToken(refreshToken: refreshToken)
        _ = try await sut.refreshToken(refreshToken: refreshToken)

        // Assert - Three separate network requests were made
        XCTAssertEqual(mockNetworkClient.executeRequestCallCount, 3)
    }

    func testRefreshToken_ConcurrentCallsAfterFirstCompletes_MakesNewRequest() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act - First request
        _ = try await sut.refreshToken(refreshToken: refreshToken)

        // Wait a bit to ensure first request completes
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Second batch of concurrent requests
        async let result1 = sut.refreshToken(refreshToken: refreshToken)
        async let result2 = sut.refreshToken(refreshToken: refreshToken)

        _ = try await [result1, result2]

        // Assert - Two requests total (first + second batch)
        XCTAssertEqual(mockNetworkClient.executeRequestCallCount, 2)
    }

    // MARK: - Error Propagation Tests

    func testRefreshToken_ConcurrentCallsWithError_AllReceiveError() async {
        // Arrange
        mockNetworkClient.responseToReturn = createErrorResponse(statusCode: 401)

        // Act - Launch 3 concurrent refresh requests
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    _ = try await self.sut.refreshToken(refreshToken: self.refreshToken)
                    XCTFail("Expected error to be thrown")
                } catch {
                    // Expected
                }
            }
            group.addTask {
                do {
                    _ = try await self.sut.refreshToken(refreshToken: self.refreshToken)
                    XCTFail("Expected error to be thrown")
                } catch {
                    // Expected
                }
            }
            group.addTask {
                do {
                    _ = try await self.sut.refreshToken(refreshToken: self.refreshToken)
                    XCTFail("Expected error to be thrown")
                } catch {
                    // Expected
                }
            }
        }

        // Assert - Only one network request was made
        XCTAssertEqual(mockNetworkClient.executeRequestCallCount, 1)
    }

    // MARK: - Logging Tests

    func testRefreshToken_LogsRefreshAttempt() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse()

        // Act
        _ = try await sut.refreshToken(refreshToken: refreshToken)

        // Assert - This test verifies that the method runs without crashing
        // Actual logging verification would require a logging mock
        XCTAssertTrue(mockNetworkClient.executeRequestCalled)
    }

    // MARK: - TokenRefreshError Tests

    func testTokenRefreshError_InvalidURL_HasDescription() {
        // Arrange
        let error = TokenRefreshError.invalidURL

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Invalid"))
    }

    func testTokenRefreshError_APIError_HasDescription() {
        // Arrange
        let error = TokenRefreshError.apiError(statusCode: 401, message: "Test error")

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("401"))
        XCTAssertTrue(description!.contains("Test error"))
    }

    func testTokenRefreshError_InvalidRefreshToken_HasDescription() {
        // Arrange
        let error = TokenRefreshError.invalidRefreshToken

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Invalid"))
    }

    func testTokenRefreshError_NetworkError_HasDescription() {
        // Arrange
        let underlyingError = NSError(
            domain: "TestError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Test network error"]
        )
        let error = TokenRefreshError.networkError(underlyingError)

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Network"))
    }

    // MARK: - RefreshResponse Tests

    func testRefreshResponse_Codable() throws {
        // Arrange
        let response = TokenRefreshClient.RefreshResponse(
            accessToken: "test-access",
            refreshToken: "test-refresh"
        )

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)

        // Act - Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenRefreshClient.RefreshResponse.self, from: data)

        // Assert
        XCTAssertEqual(decoded.accessToken, response.accessToken)
        XCTAssertEqual(decoded.refreshToken, response.refreshToken)
    }

    func testRefreshResponse_DecodesSnakeCase() throws {
        // Arrange
        let json = """
            {
                "access_token": "test-access",
                "refresh_token": "test-refresh"
            }
            """
        let data = json.data(using: .utf8)!

        // Act
        let decoder = JSONDecoder()
        let response = try decoder.decode(TokenRefreshClient.RefreshResponse.self, from: data)

        // Assert
        XCTAssertEqual(response.accessToken, "test-access")
        XCTAssertEqual(response.refreshToken, "test-refresh")
    }

    // MARK: - Integration Tests

    func testRefreshToken_CompleteFlow_WorksCorrectly() async throws {
        // Arrange
        mockNetworkClient.responseToReturn = createSuccessResponse(
            accessToken: "new-access-123",
            refreshToken: "new-refresh-456"
        )

        // Act
        let response = try await sut.refreshToken(refreshToken: "old-refresh-789")

        // Assert
        XCTAssertEqual(response.accessToken, "new-access-123")
        XCTAssertEqual(response.refreshToken, "new-refresh-456")

        // Verify the correct refresh token was sent
        let request = mockNetworkClient.requestsReceived.first!
        let bodyData = request.httpBody!
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        XCTAssertEqual(bodyJSON["refresh_token"] as? String, "old-refresh-789")
    }
}
