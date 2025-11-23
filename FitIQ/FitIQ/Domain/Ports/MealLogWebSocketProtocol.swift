//
//  MealLogWebSocketProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Port (protocol) for meal log WebSocket operations
//  Updated for dedicated /ws/meal-logs endpoint specification
//

import Foundation

// MARK: - WebSocket Message Types

/// WebSocket message types for the dedicated /ws/meal-logs endpoint
public enum MealLogWebSocketMessageType: String, Codable {
    case connected = "connected"
    case ping = "ping"
    case pong = "pong"
    case mealLogCompleted = "meal_log.completed"
    case mealLogFailed = "meal_log.failed"
    case error = "error"
}

// MARK: - Message Payloads

/// Connected message payload - sent when connection is established
public struct MealLogConnectedPayload: Codable {
    /// The user ID for this connection
    public let userId: String

    /// Connection timestamp
    public let timestamp: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case timestamp
    }
}

/// Meal log item in WebSocket update
public struct MealLogItemPayload: Codable {
    /// The item ID (from backend)
    public let id: String

    /// Parent meal log ID
    public let mealLogId: String

    /// Reference to global foods table (optional)
    public let foodId: String?

    /// Reference to user_foods table (optional)
    public let userFoodId: String?

    /// The food name
    public let foodName: String

    /// The quantity as a number
    public let quantity: Double

    /// The unit of measurement
    public let unit: String

    /// Nutritional values
    public let calories: Int
    public let proteinG: Double
    public let carbsG: Double
    public let fatG: Double
    public let fiberG: Double?
    public let sugarG: Double?

    /// Food type classification: "food" (solid), "drink" (caloric beverage), "water" (water/zero-cal)
    public let foodType: String

    /// AI confidence score (0.0 - 1.0)
    public let confidenceScore: Double?

    /// Any parsing notes or assumptions
    public let parsingNotes: String?

    /// Display order
    public let orderIndex: Int

    /// When the item was created
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case mealLogId = "meal_log_id"
        case foodId = "food_id"
        case userFoodId = "user_food_id"
        case foodName = "food_name"
        case quantity
        case unit
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case foodType = "food_type"
        case confidenceScore = "confidence_score"
        case parsingNotes = "parsing_notes"
        case orderIndex = "order_index"
        case createdAt = "created_at"
    }
}

/// Meal log completed payload - sent when processing succeeds
public struct MealLogCompletedPayload: Codable {
    /// The meal log ID
    public let id: String

    /// The user ID
    public let userId: String

    /// Original natural language input (for AI-parsed meals)
    public let rawInput: String?

    /// The meal type
    public let mealType: String

    /// The current processing status
    public let status: String

    /// Total nutritional values
    public let totalCalories: Int?
    public let totalProteinG: Double?
    public let totalCarbsG: Double?
    public let totalFatG: Double?
    public let totalFiberG: Double?
    public let totalSugarG: Double?

    /// When the meal was logged
    public let loggedAt: String

    /// Processing timestamps
    public let processingStartedAt: String?
    public let processingCompletedAt: String?

    /// When the meal log was created
    public let createdAt: String

    /// When the meal log was last updated
    public let updatedAt: String

    /// Parsed meal items
    public let items: [MealLogItemPayload]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rawInput = "raw_input"
        case mealType = "meal_type"
        case status
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"
        case totalSugarG = "total_sugar_g"
        case loggedAt = "logged_at"
        case processingStartedAt = "processing_started_at"
        case processingCompletedAt = "processing_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
    }
}

/// Meal log failed payload - sent when processing fails
public struct MealLogFailedPayload: Codable {
    /// The meal log ID
    public let mealLogId: String

    /// The user ID
    public let userId: String

    /// Original natural language input
    public let rawInput: String

    /// The meal type
    public let mealType: String

    /// Error message
    public let error: String

    /// Error code
    public let errorCode: String

    /// Detailed error explanation
    public let details: String?

    /// Suggestions for the user
    public let suggestions: [String]?

    enum CodingKeys: String, CodingKey {
        case mealLogId = "meal_log_id"
        case userId = "user_id"
        case rawInput = "raw_input"
        case mealType = "meal_type"
        case error
        case errorCode = "error_code"
        case details
        case suggestions
    }
}

/// Error message payload
public struct MealLogErrorPayload: Codable {
    /// Error message
    public let error: String

    /// Error code
    public let errorCode: String?

    /// Detailed error explanation
    public let details: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorCode = "error_code"
        case details
    }
}

// MARK: - WebSocket Messages

/// Connected message
public struct MealLogConnectedMessage: Codable {
    public let type: String
    public let userId: String
    public let timestamp: String

    enum CodingKeys: String, CodingKey {
        case type
        case userId = "user_id"
        case timestamp
    }
}

/// Pong message
public struct MealLogPongMessage: Codable {
    public let type: String
    public let timestamp: String
}

/// Meal log completed message
public struct MealLogCompletedMessage: Codable {
    public let type: String
    public let data: MealLogCompletedPayload
    public let timestamp: String
}

/// Meal log failed message
public struct MealLogFailedMessage: Codable {
    public let type: String
    public let data: MealLogFailedPayload
    public let timestamp: String
}

/// Error message
public struct MealLogErrorMessage: Codable {
    public let type: String
    public let error: String
    public let errorCode: String?
    public let details: String?
    public let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case type
        case error
        case errorCode = "error_code"
        case details
        case timestamp
    }
}

// MARK: - WebSocket Connection State

/// WebSocket connection state
public enum MealLogWebSocketState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(Error)

    // Custom Equatable implementation since Error doesn't conform to Equatable
    public static func == (lhs: MealLogWebSocketState, rhs: MealLogWebSocketState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected, .connected):
            return true
        case (.error, .error):
            return true  // Consider all error states equal
        default:
            return false
        }
    }
}

// MARK: - WebSocket Protocol

/// Protocol for WebSocket communication for meal log processing updates
///
/// Handles real-time status updates from the backend during meal log processing.
/// Follows the Hexagonal Architecture pattern as a port (interface) that will be
/// implemented by an adapter in the Infrastructure layer.
///
/// **Endpoint:** `/ws/meal-logs`
/// **Authentication:** JWT token via query parameter (`?token=YOUR_JWT_TOKEN`)
///
/// **Message Types:**
/// - Server → Client: `connected`, `pong`, `meal_log.completed`, `meal_log.failed`, `error`
/// - Client → Server: `ping`
public protocol MealLogWebSocketProtocol: AnyObject {

    /// Current connection state
    var connectionState: MealLogWebSocketState { get }

    /// Connect to the WebSocket server
    ///
    /// Establishes a WebSocket connection to `/ws/meal-logs` for receiving meal log processing updates.
    /// Uses the JWT access token for authentication via query parameter.
    ///
    /// - Parameter accessToken: The JWT access token for authentication
    /// - Throws: Error if connection fails
    func connect(accessToken: String) async throws

    /// Disconnect from the WebSocket server
    ///
    /// Closes the WebSocket connection gracefully.
    func disconnect()

    /// Subscribe to meal log completed updates
    ///
    /// Registers a callback to receive completed meal log updates.
    /// The callback will be invoked on the main thread.
    ///
    /// - Parameter onCompleted: Callback invoked when a meal log completes successfully
    /// - Returns: A subscription ID that can be used to unsubscribe
    func subscribeToCompleted(onCompleted: @escaping (MealLogCompletedPayload) -> Void) -> UUID

    /// Subscribe to meal log failed updates
    ///
    /// Registers a callback to receive failed meal log updates.
    /// The callback will be invoked on the main thread.
    ///
    /// - Parameter onFailed: Callback invoked when a meal log processing fails
    /// - Returns: A subscription ID that can be used to unsubscribe
    func subscribeToFailed(onFailed: @escaping (MealLogFailedPayload) -> Void) -> UUID

    /// Subscribe to connection events
    ///
    /// Registers a callback to receive connection status updates.
    /// The callback will be invoked on the main thread.
    ///
    /// - Parameter onConnected: Callback invoked when connection is established
    /// - Returns: A subscription ID that can be used to unsubscribe
    func subscribeToConnection(onConnected: @escaping (MealLogConnectedPayload) -> Void) -> UUID

    /// Subscribe to error events
    ///
    /// Registers a callback to receive error notifications.
    /// The callback will be invoked on the main thread.
    ///
    /// - Parameter onError: Callback invoked when an error occurs
    /// - Returns: A subscription ID that can be used to unsubscribe
    func subscribeToErrors(onError: @escaping (MealLogErrorPayload) -> Void) -> UUID

    /// Unsubscribe from updates
    ///
    /// Removes a previously registered callback.
    ///
    /// - Parameter subscriptionId: The subscription ID returned by subscribe()
    func unsubscribe(_ subscriptionId: UUID)

    /// Send a ping message to keep the connection alive
    ///
    /// The server requires periodic ping messages (every 30s recommended) to keep the connection open.
    func sendPing()
}

// MARK: - Conversion Helpers

extension MealLogCompletedPayload {
    /// Convert WebSocket status to domain MealLogStatus enum
    public func toDomainStatus() -> MealLogStatus {
        MealLogStatus(rawValue: status) ?? .completed
    }

    /// Convert WebSocket meal type string to MealType enum
    public func toDomainMealType() -> MealType {
        MealType(rawValue: mealType.lowercased()) ?? .other
    }

    /// Parse ISO8601 date string
    public func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    /// Convert to date objects
    public var loggedAtDate: Date? {
        parseDate(loggedAt)
    }

    public var processingStartedAtDate: Date? {
        guard let timestamp = processingStartedAt else { return nil }
        return parseDate(timestamp)
    }

    public var processingCompletedAtDate: Date? {
        guard let timestamp = processingCompletedAt else { return nil }
        return parseDate(timestamp)
    }

    public var createdAtDate: Date? {
        parseDate(createdAt)
    }

    public var updatedAtDate: Date? {
        parseDate(updatedAt)
    }
}

extension MealLogFailedPayload {
    /// Convert WebSocket meal type string to MealType enum
    public func toDomainMealType() -> MealType {
        MealType(rawValue: mealType.lowercased()) ?? .other
    }
}
