//
//  OutboxProcessorService.swift
//  FitIQCore
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Service that processes outbox events for reliable data synchronization
//

import Foundation

/// Service that processes outbox events to sync data with remote API
/// Implements the Outbox Pattern with robust retry logic and error handling
public actor OutboxProcessorService {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let batchSize: Int
        public let processingInterval: TimeInterval
        public let maxConcurrentOperations: Int
        public let retryDelays: [TimeInterval]
        public let cleanupInterval: TimeInterval

        public init(
            batchSize: Int = 10,
            processingInterval: TimeInterval = 0.1,
            maxConcurrentOperations: Int = 3,
            retryDelays: [TimeInterval] = [1, 5, 30, 120, 600],
            cleanupInterval: TimeInterval = 300
        ) {
            self.batchSize = batchSize
            self.processingInterval = processingInterval
            self.maxConcurrentOperations = maxConcurrentOperations
            self.retryDelays = retryDelays
            self.cleanupInterval = cleanupInterval
        }

        public static let `default` = Configuration()
    }

    // MARK: - Event Handler Protocol

    public protocol OutboxEventHandler: Sendable {
        func canHandle(eventType: OutboxEventType) -> Bool
        func handle(event: OutboxEvent) async throws
    }

    // MARK: - Properties

    private let repository: OutboxRepositoryProtocol
    private let configuration: Configuration
    private var handlers: [any OutboxEventHandler] = []

    private var isProcessing = false
    private var processingTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var currentUserID: String?

    // MARK: - Initialization

    public init(
        repository: OutboxRepositoryProtocol,
        configuration: Configuration = .default
    ) {
        self.repository = repository
        self.configuration = configuration
    }

    // MARK: - Handler Registration

    public func registerHandler(_ handler: any OutboxEventHandler) {
        handlers.append(handler)
    }

    // MARK: - Processing Control

    /// Starts processing outbox events for a specific user
    /// - Parameter userID: User ID to process events for
    public func startProcessing(forUserID userID: String) {
        // If already processing for a different user, stop first
        if isProcessing {
            print("⚠️ [OutboxProcessor] Already processing, restarting for user \(userID)")
            stopProcessing()
        }

        currentUserID = userID
        isProcessing = true

        print("🚀 [OutboxProcessor] Starting for user \(userID)")

        // Start periodic processing
        processingTask = Task { [weak self] in
            await self?.processLoop()
        }

        // Start periodic cleanup
        cleanupTask = Task { [weak self] in
            await self?.cleanupLoop()
        }
    }

    /// Stops processing outbox events
    public func stopProcessing() {
        guard isProcessing else { return }

        print("🛑 [OutboxProcessor] Stopping")

        isProcessing = false
        currentUserID = nil

        processingTask?.cancel()
        processingTask = nil

        cleanupTask?.cancel()
        cleanupTask = nil
    }

    /// Triggers immediate processing (skips waiting for next poll cycle)
    public func triggerImmediateProcessing() {
        guard isProcessing else {
            print("⚠️ [OutboxProcessor] Cannot trigger - processor not started")
            return
        }

        print("⚡ [OutboxProcessor] Triggering immediate processing")

        Task {
            await self.processBatch()
        }
    }

    // MARK: - Private Processing Logic

    private func processLoop() async {
        while isProcessing && !Task.isCancelled {
            await processBatch()

            // Wait for next cycle
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(configuration.processingInterval * 1_000_000_000))
            } catch {
                // Task was cancelled
                break
            }
        }
    }

    private func processBatch() async {
        guard let userID = currentUserID else { return }

        do {
            // Fetch pending events
            let events = try await repository.fetchPendingEvents(
                forUserID: userID,
                limit: configuration.batchSize
            )

            guard !events.isEmpty else { return }

            print("📦 [OutboxProcessor] Processing \(events.count) events")

            // Process events concurrently (up to max concurrent operations)
            await withTaskGroup(of: Void.self) { group in
                for event in events.prefix(configuration.maxConcurrentOperations) {
                    group.addTask { [weak self] in
                        await self?.processEvent(event)
                    }
                }
            }

        } catch {
            print("❌ [OutboxProcessor] Error fetching events: \(error)")
        }
    }

    private func processEvent(_ event: OutboxEvent) async {
        do {
            // Mark as processing
            try await repository.markAsProcessing(event.id)

            // Find handler
            guard let handler = handlers.first(where: { $0.canHandle(eventType: event.eventType) })
            else {
                throw OutboxProcessorError.noHandlerFound(eventType: event.eventType)
            }

            // Handle event
            try await handler.handle(event: event)

            // Mark as completed
            try await repository.markAsCompleted(event.id)

            print(
                "✅ [OutboxProcessor] Completed: \(event.eventType.displayName) (\(event.id))")

        } catch {
            // Mark as failed with error message
            try? await repository.markAsFailed(event.id, error: error.localizedDescription)

            print(
                "❌ [OutboxProcessor] Failed: \(event.eventType.displayName) (\(event.id)) - \(error)"
            )
        }
    }

    private func cleanupLoop() async {
        while isProcessing && !Task.isCancelled {
            // Wait for cleanup interval
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(configuration.cleanupInterval * 1_000_000_000))
            } catch {
                // Task was cancelled
                break
            }

            guard isProcessing else { break }

            do {
                // Delete completed events older than 24 hours
                let cutoffDate = Date().addingTimeInterval(-86400)
                let deletedCount = try await repository.deleteCompletedEvents(olderThan: cutoffDate)

                if deletedCount > 0 {
                    print("🧹 [OutboxProcessor] Cleaned up \(deletedCount) old completed events")
                }
            } catch {
                print("⚠️ [OutboxProcessor] Cleanup error: \(error)")
            }
        }
    }

    // MARK: - Statistics

    public func getStatistics() async throws -> OutboxStatistics {
        guard let userID = currentUserID else {
            throw OutboxProcessorError.notStarted
        }

        return try await repository.getStatistics(forUserID: userID)
    }

    // MARK: - Status

    public var isRunning: Bool {
        isProcessing
    }
}

// MARK: - Errors

public enum OutboxProcessorError: LocalizedError {
    case notStarted
    case noHandlerFound(eventType: OutboxEventType)

    public var errorDescription: String? {
        switch self {
        case .notStarted:
            return "Outbox processor not started"
        case .noHandlerFound(let eventType):
            return "No handler found for event type: \(eventType.rawValue)"
        }
    }
}
