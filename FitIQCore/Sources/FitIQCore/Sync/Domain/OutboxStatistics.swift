//
//  OutboxStatistics.swift
//  FitIQCore
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Statistics and metrics for Outbox Pattern monitoring
//

import Foundation

/// Statistics about outbox events for monitoring and debugging
public struct OutboxStatistics: Codable, Sendable, Equatable {
    public let totalEvents: Int
    public let pendingCount: Int
    public let processingCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let staleCount: Int
    public let oldestPendingDate: Date?
    public let newestCompletedDate: Date?

    public init(
        totalEvents: Int,
        pendingCount: Int,
        processingCount: Int,
        completedCount: Int,
        failedCount: Int,
        staleCount: Int,
        oldestPendingDate: Date? = nil,
        newestCompletedDate: Date? = nil
    ) {
        self.totalEvents = totalEvents
        self.pendingCount = pendingCount
        self.processingCount = processingCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.staleCount = staleCount
        self.oldestPendingDate = oldestPendingDate
        self.newestCompletedDate = newestCompletedDate
    }

    /// Calculate success rate percentage
    public var successRate: Double {
        let total = pendingCount + processingCount + completedCount + failedCount
        guard total > 0 else { return 100.0 }
        return (Double(completedCount) / Double(total)) * 100.0
    }

    /// Determine if there are any issues that need attention
    public var hasIssues: Bool {
        failedCount > 0 || staleCount > 0 || pendingCount > 20
    }

    /// Human-readable status summary
    public var statusSummary: String {
        """
        Total: \(totalEvents) | Pending: \(pendingCount) | Processing: \(processingCount) | \
        Completed: \(completedCount) | Failed: \(failedCount) | Stale: \(staleCount)
        """
    }

    /// Detailed report with success rate
    public var detailedReport: String {
        var report = statusSummary
        report += "\nSuccess Rate: \(String(format: "%.1f", successRate))%"

        if let oldest = oldestPendingDate {
            let age = Date().timeIntervalSince(oldest)
            let minutes = Int(age / 60)
            report += "\nOldest Pending: \(minutes) minutes ago"
        }

        if let newest = newestCompletedDate {
            let age = Date().timeIntervalSince(newest)
            let seconds = Int(age)
            report += "\nLast Completed: \(seconds) seconds ago"
        }

        if hasIssues {
            report += "\n⚠️ Issues detected!"
        }

        return report
    }

    /// Empty statistics (no events)
    public static let empty = OutboxStatistics(
        totalEvents: 0,
        pendingCount: 0,
        processingCount: 0,
        completedCount: 0,
        failedCount: 0,
        staleCount: 0,
        oldestPendingDate: nil,
        newestCompletedDate: nil
    )
}
