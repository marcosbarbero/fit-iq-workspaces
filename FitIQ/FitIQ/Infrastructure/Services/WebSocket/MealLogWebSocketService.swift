//
//  MealLogWebSocketService.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Service that manages WebSocket connections for meal log real-time updates
//  Updated for dedicated /ws/meal-logs endpoint specification
//

import Combine
import Foundation

/// Service that manages WebSocket connections for meal log real-time updates
///
/// This service wraps `MealLogWebSocketProtocol` following the Hexagonal Architecture pattern,
/// similar to how `AuthManager` wraps `AuthTokenPersistencePortProtocol`.
///
/// **Architecture:**
/// - Domain service that hides infrastructure details from ViewModels
/// - Manages WebSocket lifecycle (connect, disconnect, reconnect)
/// - Handles authentication token retrieval via AuthManager
/// - Provides clean callback-based API for real-time updates
///
/// **Endpoint:** `/ws/meal-logs`
/// **Authentication:** JWT token via query parameter
///
/// **Message Types:**
/// - `connected`: Connection established
/// - `pong`: Keep-alive response
/// - `meal_log.completed`: Meal processing succeeded
/// - `meal_log.failed`: Meal processing failed
/// - `error`: Connection-level error
///
/// **Usage:**
/// ```swift
/// let service = MealLogWebSocketService(
///     webSocketClient: webSocketClient,
///     authManager: authManager
/// )
///
/// try await service.connect(
///     onCompleted: { payload in
///         // Handle successful meal log processing
///         print("Meal \(payload.id) completed with \(payload.items.count) items")
///     },
///     onFailed: { payload in
///         // Handle failed meal log processing
///         print("Meal failed: \(payload.error)")
///     }
/// )
/// ```
final class MealLogWebSocketService: ObservableObject {

    // MARK: - Published State

    /// Whether the WebSocket is currently connected
    @Published private(set) var isConnected: Bool = false

    /// Current connection error, if any
    @Published private(set) var connectionError: String?

    /// User ID for the connected session
    @Published private(set) var connectedUserId: String?

    // MARK: - Dependencies

    private let webSocketClient: MealLogWebSocketProtocol
    private let authManager: AuthManager

    // MARK: - Private State

    /// Current subscription IDs for WebSocket updates
    private var completedSubscriptionId: UUID?
    private var failedSubscriptionId: UUID?
    private var connectionSubscriptionId: UUID?
    private var errorSubscriptionId: UUID?

    /// Callbacks for handling updates
    private var completedHandler: ((MealLogCompletedPayload) async -> Void)?
    private var failedHandler: ((MealLogFailedPayload) async -> Void)?

    // MARK: - Initialization

    init(
        webSocketClient: MealLogWebSocketProtocol,
        authManager: AuthManager
    ) {
        self.webSocketClient = webSocketClient
        self.authManager = authManager

        print("MealLogWebSocketService: Initialized")
    }

    deinit {
        disconnect()
        print("MealLogWebSocketService: Deinitialized")
    }

    // MARK: - Public API

    /// Connect to WebSocket and subscribe to meal log updates
    ///
    /// Automatically retrieves authentication token from AuthManager and establishes
    /// WebSocket connection to `/ws/meal-logs`. Subscribes to real-time meal log updates.
    ///
    /// - Parameters:
    ///   - onCompleted: Callback invoked when a meal log completes successfully
    ///   - onFailed: Callback invoked when a meal log processing fails
    /// - Returns: A tuple containing the subscription IDs (completedId, failedId) for tracking
    /// - Throws: `MealLogWebSocketServiceError` if connection fails
    func connect(
        onCompleted: @escaping (MealLogCompletedPayload) async -> Void,
        onFailed: @escaping (MealLogFailedPayload) async -> Void
    ) async throws -> (completedId: UUID, failedId: UUID) {
        print("MealLogWebSocketService: Connecting to /ws/meal-logs...")

        // Validate authentication
        guard authManager.isAuthenticated else {
            let error = MealLogWebSocketServiceError.notAuthenticated
            connectionError = error.errorDescription
            print("MealLogWebSocketService: ❌ Not authenticated")
            throw error
        }

        // Get access token from AuthManager
        guard let accessToken = try? authManager.fetchAccessToken(),
            !accessToken.isEmpty
        else {
            let error = MealLogWebSocketServiceError.missingAccessToken
            connectionError = error.errorDescription
            print("MealLogWebSocketService: ❌ Missing access token")
            throw error
        }

        // Store update handlers
        self.completedHandler = onCompleted
        self.failedHandler = onFailed

        do {
            // Connect to WebSocket
            print("MealLogWebSocketService: Connecting with JWT token...")
            try await webSocketClient.connect(accessToken: accessToken)

            // Subscribe to connection events
            connectionSubscriptionId = webSocketClient.subscribeToConnection {
                [weak self] payload in
                Task {
                    await self?.handleConnection(payload)
                }
            }

            // Subscribe to completed updates
            completedSubscriptionId = webSocketClient.subscribeToCompleted { [weak self] payload in
                Task {
                    await self?.handleCompleted(payload)
                }
            }

            // Subscribe to failed updates
            failedSubscriptionId = webSocketClient.subscribeToFailed { [weak self] payload in
                Task {
                    await self?.handleFailed(payload)
                }
            }

            // Subscribe to error events
            errorSubscriptionId = webSocketClient.subscribeToErrors { [weak self] payload in
                Task {
                    await self?.handleError(payload)
                }
            }

            isConnected = true
            connectionError = nil

            print("MealLogWebSocketService: ✅ Connected and subscribed to all events")
            print(
                "MealLogWebSocketService: 📋 Returning subscription IDs - Completed: \(completedSubscriptionId!), Failed: \(failedSubscriptionId!)"
            )

            // Return subscription IDs to caller for tracking
            return (completedId: completedSubscriptionId!, failedId: failedSubscriptionId!)

        } catch {
            isConnected = false
            connectionError = error.localizedDescription

            print("MealLogWebSocketService: ❌ Connection failed: \(error)")

            throw MealLogWebSocketServiceError.connectionFailed(underlying: error)
        }
    }

    /// Unsubscribe from completed events
    ///
    /// - Parameter subscriptionId: The subscription ID to unsubscribe
    func unsubscribeFromCompleted(subscriptionId: UUID) {
        print("MealLogWebSocketService: Unsubscribing from completed events: \(subscriptionId)")
        webSocketClient.unsubscribe(subscriptionId)
        if completedSubscriptionId == subscriptionId {
            completedSubscriptionId = nil
        }
    }

    /// Unsubscribe from failed events
    ///
    /// - Parameter subscriptionId: The subscription ID to unsubscribe
    func unsubscribeFromFailed(subscriptionId: UUID) {
        print("MealLogWebSocketService: Unsubscribing from failed events: \(subscriptionId)")
        webSocketClient.unsubscribe(subscriptionId)
        if failedSubscriptionId == subscriptionId {
            failedSubscriptionId = nil
        }
    }

    /// Disconnect from WebSocket
    ///
    /// Unsubscribes from all updates and closes the WebSocket connection.
    func disconnect() {
        print("MealLogWebSocketService: Disconnecting...")

        // Unsubscribe from all events
        if let id = completedSubscriptionId {
            webSocketClient.unsubscribe(id)
            completedSubscriptionId = nil
        }

        if let id = failedSubscriptionId {
            webSocketClient.unsubscribe(id)
            failedSubscriptionId = nil
        }

        if let id = connectionSubscriptionId {
            webSocketClient.unsubscribe(id)
            connectionSubscriptionId = nil
        }

        if let id = errorSubscriptionId {
            webSocketClient.unsubscribe(id)
            errorSubscriptionId = nil
        }

        // Disconnect WebSocket
        webSocketClient.disconnect()

        isConnected = false
        connectedUserId = nil
        completedHandler = nil
        failedHandler = nil

        print("MealLogWebSocketService: ✅ Disconnected")
    }

    /// Reconnect to WebSocket with automatic token refresh
    ///
    /// Disconnects and reconnects with fresh authentication token.
    /// Useful for handling token expiration or connection issues.
    ///
    /// - Parameters:
    ///   - onCompleted: Callback invoked when a meal log completes successfully
    ///   - onFailed: Callback invoked when a meal log processing fails
    /// - Throws: `MealLogWebSocketServiceError` if reconnection fails
    func reconnect(
        onCompleted: @escaping (MealLogCompletedPayload) async -> Void,
        onFailed: @escaping (MealLogFailedPayload) async -> Void
    ) async throws {
        print("MealLogWebSocketService: Reconnecting...")

        // Disconnect first
        disconnect()

        // Small delay to allow cleanup
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Reconnect
        try await connect(onCompleted: onCompleted, onFailed: onFailed)
    }

    // MARK: - Private Helpers

    /// Handle connection established event
    @MainActor
    private func handleConnection(_ payload: MealLogConnectedPayload) async {
        print("MealLogWebSocketService: ✅ Connection established")
        print("MealLogWebSocketService:    - User ID: \(payload.userId)")
        print("MealLogWebSocketService:    - Timestamp: \(payload.timestamp)")

        connectedUserId = payload.userId
        isConnected = true
        connectionError = nil
    }

    /// Handle meal log completed event
    private func handleCompleted(_ payload: MealLogCompletedPayload) async {
        print("MealLogWebSocketService: 📩 Meal log completed")
        print("MealLogWebSocketService:    - ID: \(payload.id)")
        print("MealLogWebSocketService:    - Meal Type: \(payload.mealType)")
        print("MealLogWebSocketService:    - Items: \(payload.items.count)")
        print("MealLogWebSocketService:    - Total Calories: \(payload.totalCalories ?? 0)")
        print("MealLogWebSocketService:    - Total Protein: \(payload.totalProteinG ?? 0)g")
        print("MealLogWebSocketService:    - Total Carbs: \(payload.totalCarbsG ?? 0)g")
        print("MealLogWebSocketService:    - Total Fat: \(payload.totalFatG ?? 0)g")

        // Forward to completed handler
        await completedHandler?(payload)
    }

    /// Handle meal log failed event
    private func handleFailed(_ payload: MealLogFailedPayload) async {
        print("MealLogWebSocketService: ❌ Meal log failed")
        print("MealLogWebSocketService:    - ID: \(payload.mealLogId)")
        print("MealLogWebSocketService:    - Error: \(payload.error)")
        print("MealLogWebSocketService:    - Error Code: \(payload.errorCode)")
        if let details = payload.details {
            print("MealLogWebSocketService:    - Details: \(details)")
        }
        if let suggestions = payload.suggestions {
            print(
                "MealLogWebSocketService:    - Suggestions: \(suggestions.joined(separator: ", "))")
        }

        // Forward to failed handler
        await failedHandler?(payload)
    }

    /// Handle error event
    @MainActor
    private func handleError(_ payload: MealLogErrorPayload) async {
        print("MealLogWebSocketService: ❌ WebSocket error")
        print("MealLogWebSocketService:    - Error: \(payload.error)")
        if let code = payload.errorCode {
            print("MealLogWebSocketService:    - Error Code: \(code)")
        }
        if let details = payload.details {
            print("MealLogWebSocketService:    - Details: \(details)")
        }

        connectionError = payload.error

        // Check for authentication errors
        if let code = payload.errorCode {
            switch code {
            case "AUTH_FAILED":
                print("MealLogWebSocketService: ⚠️ Authentication failed - token may be expired")
                isConnected = false
            // Caller should handle re-authentication and reconnection

            case "CONNECTION_LIMIT":
                print("MealLogWebSocketService: ⚠️ Connection limit reached")
                isConnected = false

            case "RATE_LIMIT":
                print("MealLogWebSocketService: ⚠️ Rate limit exceeded")

            default:
                print("MealLogWebSocketService: ⚠️ Unhandled error code: \(code)")
            }
        }
    }
}

// MARK: - Errors

/// Errors that can occur in MealLogWebSocketService
enum MealLogWebSocketServiceError: Error, LocalizedError {
    case notAuthenticated
    case missingAccessToken
    case connectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated to connect to real-time updates"
        case .missingAccessToken:
            return "No access token available. Please log in again."
        case .connectionFailed(let error):
            return "Failed to connect to real-time updates: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated, .missingAccessToken:
            return "Please log in to your account."
        case .connectionFailed:
            return "Check your internet connection and try again."
        }
    }
}
