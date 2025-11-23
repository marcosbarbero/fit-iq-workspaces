//
//  SDOutboxEvent+Helpers.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Helper methods for SDOutboxEvent to support Outbox Pattern operations
//

import Foundation

/// Extension providing helper methods for SDOutboxEvent status management
///
/// These methods mirror the functionality from FitIQCore's OutboxEvent domain model
/// but operate directly on the SwiftData persistence model for efficiency.
extension SDOutboxEvent {

    // MARK: - Status Checks

    /// Check if event can be retried after failure
    var canRetry: Bool {
        status == "failed" && attemptCount < maxAttempts
    }

    /// Check if event is stale (pending for too long)
    var isStale: Bool {
        guard status == "pending" else { return false }
        let staleThreshold: TimeInterval = 300  // 5 minutes
        return Date().timeIntervalSince(createdAt) > staleThreshold
    }

    /// Check if event should be processed
    var shouldProcess: Bool {
        status == "pending" || canRetry
    }

    // MARK: - Status Mutations

    /// Mark event as processing (increments attempt count)
    func markAsProcessing() {
        self.status = "processing"
        self.lastAttemptAt = Date()
        self.attemptCount += 1
    }

    /// Mark event as completed
    func markAsCompleted() {
        self.status = "completed"
        self.completedAt = Date()
        self.errorMessage = nil
    }

    /// Mark event as failed with error message
    ///
    /// - Parameter error: Error message describing the failure
    func markAsFailed(error: String) {
        self.status = "failed"
        self.errorMessage = error
        self.lastAttemptAt = Date()
    }

    /// Reset event for retry (only if canRetry is true)
    func resetForRetry() {
        guard canRetry else { return }
        self.status = "pending"
        self.errorMessage = nil
    }

    // MARK: - Retry Delay Calculation

    /// Calculate next retry delay using exponential backoff
    ///
    /// - Parameter retryDelays: Array of delay values in seconds (default: [1, 5, 30, 120, 600])
    /// - Returns: Delay in seconds, or nil if no retry should be attempted
    func nextRetryDelay(retryDelays: [TimeInterval] = [1, 5, 30, 120, 600]) -> TimeInterval? {
        guard canRetry else { return nil }
        let index = min(attemptCount, retryDelays.count - 1)
        return retryDelays[index]
    }
}
