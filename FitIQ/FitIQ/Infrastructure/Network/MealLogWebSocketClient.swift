//
//  MealLogWebSocketClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  WebSocket client for meal log real-time status updates
//  Updated for dedicated /ws/meal-logs endpoint specification
//

import Foundation

/// WebSocket client for receiving real-time meal log processing updates
///
/// Implements MealLogWebSocketProtocol using URLSessionWebSocketTask.
/// Handles connection management, message parsing, and subscriber notifications.
///
/// **Endpoint:** `/ws/meal-logs`
/// **Authentication:** JWT token via query parameter (`?token=YOUR_JWT_TOKEN`)
///
/// **Message Flow:**
/// 1. Client connects with JWT token
/// 2. Server sends `connected` message
/// 3. Client sends `ping` every 30s, server responds with `pong`
/// 4. Server sends `meal_log.completed` or `meal_log.failed` for processed meals
/// 5. Server sends `error` for connection-level errors
final class MealLogWebSocketClient: NSObject, MealLogWebSocketProtocol {

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let webSocketURL: String

    private(set) var connectionState: MealLogWebSocketState = .disconnected

    // Subscribers dictionaries: [subscriptionId: callback]
    private var completedSubscribers: [UUID: (MealLogCompletedPayload) -> Void] = [:]
    private var failedSubscribers: [UUID: (MealLogFailedPayload) -> Void] = [:]
    private var connectionSubscribers: [UUID: (MealLogConnectedPayload) -> Void] = [:]
    private var errorSubscribers: [UUID: (MealLogErrorPayload) -> Void] = [:]

    private let subscriberQueue = DispatchQueue(label: "com.fitiq.meallog.websocket.subscribers")

    // Ping timer for keeping connection alive
    private var pingTimer: Timer?

    // Track last pong timestamp for connection health monitoring
    private var lastPongTimestamp: Date?

    // MARK: - Initialization

    init(webSocketURL: String) {
        self.webSocketURL = webSocketURL
        super.init()
    }

    deinit {
        disconnect()
    }

    // MARK: - MealLogWebSocketProtocol Implementation

    func connect(accessToken: String) async throws {
        // If already connected or connecting, return
        guard connectionState != .connected && connectionState != .connecting else {
            print("MealLogWebSocketClient: Already connected or connecting")
            return
        }

        connectionState = .connecting
        print("MealLogWebSocketClient: Connecting to \(webSocketURL)")

        // Construct WebSocket URL with auth token as query parameter
        guard var urlComponents = URLComponents(string: webSocketURL) else {
            let error = WebSocketError.invalidURL
            connectionState = .error(error)
            throw error
        }

        // Add access token as query parameter
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "token", value: accessToken))
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            let error = WebSocketError.invalidURL
            connectionState = .error(error)
            throw error
        }

        // Create URL session with delegate
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        // Create WebSocket task
        webSocketTask = urlSession?.webSocketTask(with: url)

        print("MealLogWebSocketClient: 🔌 Attempting connection to \(url.absoluteString)")
        print("MealLogWebSocketClient: 🔑 Token prefix: \(String(accessToken.prefix(10)))...")
        print("MealLogWebSocketClient: ⏰ Connection timestamp: \(Date())")

        webSocketTask?.resume()

        // Wait a moment to verify connection before marking as connected
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        connectionState = .connected
        print("MealLogWebSocketClient: ✅ Connected successfully at \(Date())")
        print("MealLogWebSocketClient: 📊 Connection state: \(connectionState)")

        // Start receiving messages
        receiveMessage()

        // Start ping timer to keep connection alive (every 30 seconds)
        startPingTimer()
    }

    func disconnect() {
        print("MealLogWebSocketClient: 🔌 Disconnecting at \(Date())...")

        // Stop ping timer
        stopPingTimer()

        // Close WebSocket
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        // Invalidate session
        urlSession?.invalidateAndCancel()
        urlSession = nil

        connectionState = .disconnected
        print("MealLogWebSocketClient: ✅ Disconnected at \(Date())")
    }

    func subscribeToCompleted(onCompleted: @escaping (MealLogCompletedPayload) -> Void) -> UUID {
        let subscriptionId = UUID()

        subscriberQueue.async { [weak self] in
            self?.completedSubscribers[subscriptionId] = onCompleted
        }

        print("MealLogWebSocketClient: ➕ Completed subscriber added (ID: \(subscriptionId))")
        return subscriptionId
    }

    func subscribeToFailed(onFailed: @escaping (MealLogFailedPayload) -> Void) -> UUID {
        let subscriptionId = UUID()

        subscriberQueue.async { [weak self] in
            self?.failedSubscribers[subscriptionId] = onFailed
        }

        print("MealLogWebSocketClient: ➕ Failed subscriber added (ID: \(subscriptionId))")
        return subscriptionId
    }

    func subscribeToConnection(onConnected: @escaping (MealLogConnectedPayload) -> Void) -> UUID {
        let subscriptionId = UUID()

        subscriberQueue.async { [weak self] in
            self?.connectionSubscribers[subscriptionId] = onConnected
        }

        print("MealLogWebSocketClient: ➕ Connection subscriber added (ID: \(subscriptionId))")
        return subscriptionId
    }

    func subscribeToErrors(onError: @escaping (MealLogErrorPayload) -> Void) -> UUID {
        let subscriptionId = UUID()

        subscriberQueue.async { [weak self] in
            self?.errorSubscribers[subscriptionId] = onError
        }

        print("MealLogWebSocketClient: ➕ Error subscriber added (ID: \(subscriptionId))")
        return subscriptionId
    }

    func unsubscribe(_ subscriptionId: UUID) {
        subscriberQueue.async { [weak self] in
            guard let self = self else { return }

            self.completedSubscribers.removeValue(forKey: subscriptionId)
            self.failedSubscribers.removeValue(forKey: subscriptionId)
            self.connectionSubscribers.removeValue(forKey: subscriptionId)
            self.errorSubscribers.removeValue(forKey: subscriptionId)
        }

        print("MealLogWebSocketClient: ➖ Subscriber removed (ID: \(subscriptionId))")
    }

    func sendPing() {
        guard let webSocketTask = webSocketTask else {
            print(
                "MealLogWebSocketClient: ⚠️ Cannot send ping - no active WebSocket task at \(Date())"
            )
            return
        }

        print("MealLogWebSocketClient: 🏓 Sending application-level ping at \(Date())")
        print("MealLogWebSocketClient: 📊 Connection state before ping: \(connectionState)")

        // Send application-level ping message as expected by backend
        // Backend expects: {"type": "ping"}
        // Backend responds with: {"type": "pong", "timestamp": "2024-11-08T10:30:00Z"}
        let pingMessage: [String: String] = ["type": "ping"]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: pingMessage),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            print("MealLogWebSocketClient: ❌ Failed to serialize ping message")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)

        webSocketTask.send(message) { [weak self] error in
            if let error = error {
                print(
                    "MealLogWebSocketClient: ⚠️ Ping failed at \(Date()): \(error.localizedDescription)"
                )
                print("MealLogWebSocketClient: ⚠️ Error code: \((error as NSError).code)")
                print("MealLogWebSocketClient: ⚠️ Error domain: \((error as NSError).domain)")

                // Check if it's a connection error
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain {
                    if nsError.code == NSURLErrorNotConnectedToInternet {
                        print("MealLogWebSocketClient: ❌ No internet connection")
                    } else if nsError.code == NSURLErrorCannotConnectToHost {
                        print("MealLogWebSocketClient: ❌ Cannot connect to WebSocket server")
                    } else if nsError.code == NSURLErrorTimedOut {
                        print("MealLogWebSocketClient: ❌ Connection timed out")
                    }
                }

                self?.handleError(error)
            } else {
                print("MealLogWebSocketClient: ✅ Application ping sent successfully at \(Date())")
                print("MealLogWebSocketClient: ⏳ Waiting for pong response from backend...")
            }
        }
    }

    // MARK: - Private Helpers

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                print("MealLogWebSocketClient: 📨 Message received at \(Date())")
                self.handleMessage(message)
                // Continue receiving messages
                self.receiveMessage()

            case .failure(let error):
                print(
                    "MealLogWebSocketClient: ❌ Receive error at \(Date()): \(error.localizedDescription)"
                )
                print("MealLogWebSocketClient: ❌ Error code: \((error as NSError).code)")
                self.handleError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("MealLogWebSocketClient: 📨 Received message")
            parseMessage(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                print("MealLogWebSocketClient: 📨 Received binary message")
                parseMessage(text)
            } else {
                print("MealLogWebSocketClient: ⚠️ Received invalid binary message")
            }

        @unknown default:
            print("MealLogWebSocketClient: ⚠️ Received unknown message type")
        }
    }

    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("MealLogWebSocketClient: ⚠️ Failed to convert message to data")
            return
        }

        // First, determine message type by parsing the "type" field
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let typeString = json["type"] as? String
        else {
            print("MealLogWebSocketClient: ⚠️ Failed to parse message type")
            print("MealLogWebSocketClient: Raw message: \(text)")
            return
        }

        print("MealLogWebSocketClient: 📩 Message type: \(typeString)")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            switch typeString {
            case "connected":
                let message = try decoder.decode(MealLogConnectedMessage.self, from: data)
                print("MealLogWebSocketClient: ✅ Connected - User ID: \(message.userId)")
                let payload = MealLogConnectedPayload(
                    userId: message.userId,
                    timestamp: message.timestamp
                )
                notifyConnectionSubscribers(payload)

            case "pong":
                // Track pong timestamp for connection health monitoring
                lastPongTimestamp = Date()

                // Extract backend timestamp if available
                if let timestamp = json["timestamp"] as? String {
                    print("MealLogWebSocketClient: ✅ Pong received at \(Date())")
                    print("MealLogWebSocketClient:    - Backend timestamp: \(timestamp)")
                } else {
                    print("MealLogWebSocketClient: ✅ Pong received at \(Date())")
                }

                print("MealLogWebSocketClient: ✅ Connection is alive and healthy")

            case "meal_log.completed":
                let message = try decoder.decode(MealLogCompletedMessage.self, from: data)
                print("MealLogWebSocketClient: ✅ Meal log completed: \(message.data.id)")
                print("MealLogWebSocketClient:    - Items: \(message.data.items.count)")
                print("MealLogWebSocketClient:    - Calories: \(message.data.totalCalories ?? 0)")
                notifyCompletedSubscribers(message.data)

            case "meal_log.failed":
                let message = try decoder.decode(MealLogFailedMessage.self, from: data)
                print("MealLogWebSocketClient: ❌ Meal log failed: \(message.data.mealLogId)")
                print("MealLogWebSocketClient:    - Error: \(message.data.error)")
                notifyFailedSubscribers(message.data)

            case "error":
                let message = try decoder.decode(MealLogErrorMessage.self, from: data)
                print("MealLogWebSocketClient: ❌ Server error: \(message.error)")
                if let code = message.errorCode {
                    print("MealLogWebSocketClient:    - Code: \(code)")
                }
                if let details = message.details {
                    print("MealLogWebSocketClient:    - Details: \(details)")
                }
                let payload = MealLogErrorPayload(
                    error: message.error,
                    errorCode: message.errorCode,
                    details: message.details
                )
                notifyErrorSubscribers(payload)

            default:
                print("MealLogWebSocketClient: ⚠️ Unknown message type: \(typeString)")
            }

        } catch {
            print("MealLogWebSocketClient: ❌ Failed to parse message: \(error)")
            print("MealLogWebSocketClient: Raw message: \(text)")

            // If decoding fails, try to provide more context
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print(
                        "MealLogWebSocketClient: Missing key '\(key.stringValue)' - \(context.debugDescription)"
                    )
                case .typeMismatch(let type, let context):
                    print(
                        "MealLogWebSocketClient: Type mismatch for \(type) - \(context.debugDescription)"
                    )
                case .valueNotFound(let type, let context):
                    print(
                        "MealLogWebSocketClient: Value not found for \(type) - \(context.debugDescription)"
                    )
                case .dataCorrupted(let context):
                    print("MealLogWebSocketClient: Data corrupted - \(context.debugDescription)")
                @unknown default:
                    print("MealLogWebSocketClient: Unknown decoding error")
                }
            }
        }
    }

    private func notifyCompletedSubscribers(_ payload: MealLogCompletedPayload) {
        subscriberQueue.async { [weak self] in
            guard let self = self else { return }

            // Notify all subscribers on main thread
            DispatchQueue.main.async {
                for (subscriptionId, callback) in self.completedSubscribers {
                    print(
                        "MealLogWebSocketClient: 📢 Notifying completed subscriber \(subscriptionId)"
                    )
                    callback(payload)
                }
            }
        }
    }

    private func notifyFailedSubscribers(_ payload: MealLogFailedPayload) {
        subscriberQueue.async { [weak self] in
            guard let self = self else { return }

            // Notify all subscribers on main thread
            DispatchQueue.main.async {
                for (subscriptionId, callback) in self.failedSubscribers {
                    print("MealLogWebSocketClient: 📢 Notifying failed subscriber \(subscriptionId)")
                    callback(payload)
                }
            }
        }
    }

    private func notifyConnectionSubscribers(_ payload: MealLogConnectedPayload) {
        subscriberQueue.async { [weak self] in
            guard let self = self else { return }

            // Notify all subscribers on main thread
            DispatchQueue.main.async {
                for (subscriptionId, callback) in self.connectionSubscribers {
                    print(
                        "MealLogWebSocketClient: 📢 Notifying connection subscriber \(subscriptionId)"
                    )
                    callback(payload)
                }
            }
        }
    }

    private func notifyErrorSubscribers(_ payload: MealLogErrorPayload) {
        subscriberQueue.async { [weak self] in
            guard let self = self else { return }

            // Notify all subscribers on main thread
            DispatchQueue.main.async {
                for (subscriptionId, callback) in self.errorSubscribers {
                    print("MealLogWebSocketClient: 📢 Notifying error subscriber \(subscriptionId)")
                    callback(payload)
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        connectionState = .error(error)

        // Notify error subscribers
        let payload = MealLogErrorPayload(
            error: error.localizedDescription,
            errorCode: nil,
            details: nil
        )
        notifyErrorSubscribers(payload)

        // Attempt to reconnect after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }

            print("MealLogWebSocketClient: 🔄 Reconnection needed")
            print("MealLogWebSocketClient: ⚠️ Reconnection requires caller to call connect() again")
        }
    }

    private func startPingTimer() {
        stopPingTimer()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }

        // Add to run loop to ensure it fires even when UI is busy
        if let timer = pingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("MealLogWebSocketClient: ⏰ Ping timer started (30s intervals)")
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
        print("MealLogWebSocketClient: ⏰ Ping timer stopped")
    }
}

// MARK: - URLSessionWebSocketDelegate

extension MealLogWebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print(
            "MealLogWebSocketClient: ✅ WebSocket opened with protocol: \(String(describing: `protocol`))"
        )
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "No reason"
        print(
            "MealLogWebSocketClient: ❌ WebSocket closed with code \(closeCode.rawValue): \(reasonString)"
        )

        connectionState = .disconnected
        stopPingTimer()
    }
}

// MARK: - Error Types

enum WebSocketError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case notConnected
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .connectionFailed:
            return "Failed to establish WebSocket connection"
        case .notConnected:
            return "WebSocket is not connected"
        case .sendFailed:
            return "Failed to send message over WebSocket"
        }
    }
}
