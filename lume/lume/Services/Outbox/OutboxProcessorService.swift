//
//  OutboxProcessorService.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Combine
import FitIQCore
import Foundation
import SwiftData
import SwiftUI

/// Service for processing outbox events and syncing with backend
/// Implements retry logic with exponential backoff for resilient communication
@MainActor
final class OutboxProcessorService: ObservableObject {

    /// Callback to notify when user needs to re-authenticate
    var onAuthenticationRequired: (() -> Void)?

    // MARK: - Properties

    private let outboxRepository: OutboxRepositoryProtocol
    private let tokenStorage: TokenStorageProtocol
    let moodBackendService: MoodBackendServiceProtocol
    let journalBackendService: JournalBackendServiceProtocol
    let goalBackendService: GoalBackendServiceProtocol
    let chatBackendService: ChatBackendServiceProtocol
    let refreshTokenUseCase: RefreshTokenUseCase?
    private let modelContext: ModelContext
    private let networkMonitor: NetworkMonitor

    @Published private(set) var isProcessing = false
    @Published private(set) var lastProcessedAt: Date?
    @Published private(set) var pendingEventCount = 0

    private var processingTask: Task<Void, Never>?
    private let maxRetries = 5
    private let baseRetryDelay: TimeInterval = 2.0  // 2 seconds

    // MARK: - Initialization

    init(
        outboxRepository: OutboxRepositoryProtocol,
        tokenStorage: TokenStorageProtocol,
        moodBackendService: MoodBackendServiceProtocol,
        journalBackendService: JournalBackendServiceProtocol,
        goalBackendService: GoalBackendServiceProtocol,
        chatBackendService: ChatBackendServiceProtocol,
        modelContext: ModelContext,
        refreshTokenUseCase: RefreshTokenUseCase? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.outboxRepository = outboxRepository
        self.tokenStorage = tokenStorage
        self.moodBackendService = moodBackendService
        self.journalBackendService = journalBackendService
        self.goalBackendService = goalBackendService
        self.chatBackendService = chatBackendService
        self.modelContext = modelContext
        self.refreshTokenUseCase = refreshTokenUseCase
        self.networkMonitor = networkMonitor ?? NetworkMonitor.shared
    }

    // MARK: - Public Methods

    /// Start periodic processing of outbox events
    func startProcessing(interval: TimeInterval = 30) {
        guard processingTask == nil else {
            print("⚠️ [OutboxProcessor] Processing already started")
            return
        }

        processingTask = Task {
            print("✅ [OutboxProcessor] Started periodic processing (interval: \(interval)s)")

            while !Task.isCancelled {
                await processOutbox()

                // Wait for the interval before next processing
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }

            print("🛑 [OutboxProcessor] Stopped periodic processing")
        }
    }

    /// Stop periodic processing
    func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        print("🛑 [OutboxProcessor] Processing stopped")
    }

    /// Process outbox events immediately
    /// If already processing, waits for current processing to complete
    func processOutbox() async {
        // If already processing, wait for it to complete
        if isProcessing {
            print("⏳ [OutboxProcessor] Already processing, skipping...")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🔄 [OutboxProcessor] Starting outbox processing...")

        // Check network connectivity
        guard networkMonitor.isConnected else {
            print("⚠️ [OutboxProcessor] No network connection, skipping processing")
            return
        }

        // Get access token
        guard let accessToken = try? await getValidAccessToken() else {
            print("⚠️ [OutboxProcessor] No valid access token, skipping processing")
            onAuthenticationRequired?()
            return
        }

        do {
            // Fetch pending events
            let events = try await outboxRepository.fetchPendingEvents(forUserID: nil, limit: 50)

            if events.isEmpty {
                print("✅ [OutboxProcessor] No pending events")
                pendingEventCount = 0
                lastProcessedAt = Date()
                return
            }

            print("📦 [OutboxProcessor] Found \(events.count) pending events")
            pendingEventCount = events.count

            // Process events sequentially
            for event in events {
                print(
                    "🔄 [OutboxProcessor] Processing event: \(event.id) (type: \(event.eventType.rawValue), attempt: \(event.attemptCount + 1))"
                )

                do {
                    // Process the event
                    try await processEvent(event, accessToken: accessToken)

                    // Mark as completed
                    try await outboxRepository.markAsCompleted(event.id)
                    print("✅ [OutboxProcessor] Event completed: \(event.id)")

                } catch let error as HTTPError {
                    // Handle specific HTTP errors
                    switch error {
                    case .unauthorized:
                        // Authentication error - stop processing
                        print("🔐 [OutboxProcessor] Authentication failed, stopping processing")
                        onAuthenticationRequired?()
                        return

                    case .notFound:
                        // Entity not found on backend - mark as completed (likely already deleted)
                        print(
                            "⚠️ [OutboxProcessor] Entity not found (404), marking as completed: \(event.id)"
                        )
                        try await outboxRepository.markAsCompleted(event.id)

                    case .conflict, .conflictWithDetails:
                        // Conflict - entity already exists, mark as completed
                        print(
                            "⚠️ [OutboxProcessor] Conflict (409), entity already exists, marking as completed: \(event.id)"
                        )
                        try await outboxRepository.markAsCompleted(event.id)

                    default:
                        // Other HTTP errors - retry
                        throw error
                    }

                } catch {
                    // Other errors - mark as failed and retry
                    print("❌ [OutboxProcessor] Event failed: \(event.id) - \(error)")

                    if event.attemptCount + 1 >= maxRetries {
                        print(
                            "⛔ [OutboxProcessor] Max retries reached, giving up on event: \(event.id)"
                        )
                        try await outboxRepository.markAsFailed(
                            event.id,
                            error: error.localizedDescription
                        )
                    } else {
                        // Mark as failed to increment attempt count
                        try await outboxRepository.markAsFailed(
                            event.id,
                            error: error.localizedDescription
                        )
                        print(
                            "🔄 [OutboxProcessor] Will retry event \(event.id) (attempt \(event.attemptCount + 2)/\(maxRetries))"
                        )
                    }
                }

                // Small delay between events to avoid overwhelming the backend
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }

            // Update counts
            let remainingEvents = try await outboxRepository.fetchPendingEvents(
                forUserID: nil, limit: 1)
            pendingEventCount = remainingEvents.count
            lastProcessedAt = Date()

            print("✅ [OutboxProcessor] Outbox processing completed")

        } catch {
            print("❌ [OutboxProcessor] Error during processing: \(error)")
        }
    }

    /// Trigger immediate processing (for manual sync)
    func triggerProcessing() {
        Task {
            await processOutbox()
        }
    }

    // MARK: - Private Methods

    private func getValidAccessToken() async throws -> String {
        // Try to get current token
        if let token = try? await tokenStorage.getToken(), !token.accessToken.isEmpty {
            return token.accessToken
        }

        // Try to refresh token if use case available
        if let refreshTokenUseCase = refreshTokenUseCase {
            do {
                let refreshedToken = try await refreshTokenUseCase.execute()
                return refreshedToken.accessToken
            } catch {
                print("⚠️ [OutboxProcessor] Failed to refresh token: \(error)")
            }
        }

        throw ProcessorError.missingBackendId  // Reuse existing error for authentication failure
    }

    private func processEvent(_ event: OutboxEvent, accessToken: String) async throws {
        // Implement exponential backoff for retries
        if event.attemptCount > 0 {
            let delay = calculateRetryDelay(for: event.attemptCount)
            print("⏳ [OutboxProcessor] Waiting \(delay)s before retry...")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Route to appropriate handler based on event type
        switch event.eventType {
        case .moodEntry:
            try await processMoodEvent(event, accessToken: accessToken)

        case .journalEntry:
            try await processJournalEvent(event, accessToken: accessToken)

        case .goal:
            try await processGoalEvent(event, accessToken: accessToken)

        case .chatMessage:
            // Check if this is a delete operation
            if case .generic(let dict) = event.metadata, dict["operation"] == "delete" {
                try await processConversationDeleted(event, accessToken: accessToken)
            } else {
                print("⚠️ [OutboxProcessor] Chat message events not yet implemented")
            }

        default:
            print("⚠️ [OutboxProcessor] Unknown event type: \(event.eventType.rawValue)")
        }
    }

    // MARK: - Mood Event Processing

    private func processMoodEvent(_ event: OutboxEvent, accessToken: String) async throws {
        // Check if this is a delete operation
        if case .generic(let dict) = event.metadata, dict["operation"] == "delete" {
            try await processMoodDeleted(event, accessToken: accessToken)
            return
        }

        // For create/update, fetch the full entity from local store
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { $0.id == event.entityID }
        )
        guard let moodEntry = try modelContext.fetch(descriptor).first else {
            print("⚠️ [OutboxProcessor] Mood entry not found: \(event.entityID)")
            throw ProcessorError.entityNotFound
        }

        if event.isNewRecord {
            try await processMoodCreated(event, moodEntry: moodEntry, accessToken: accessToken)
        } else {
            try await processMoodUpdated(event, moodEntry: moodEntry, accessToken: accessToken)
        }
    }

    private func processMoodCreated(
        _ event: OutboxEvent, moodEntry: SDMoodEntry, accessToken: String
    ) async throws {
        // Convert SDMoodEntry to domain MoodEntry
        let domainEntry = MoodEntry(
            id: moodEntry.id,
            userId: moodEntry.userId,
            date: moodEntry.date,
            valence: moodEntry.valence,
            labels: moodEntry.labels,
            associations: moodEntry.associations,
            notes: moodEntry.notes,
            source: MoodSource(rawValue: moodEntry.source) ?? .manual,
            sourceId: moodEntry.sourceId,
            createdAt: moodEntry.createdAt,
            updatedAt: moodEntry.updatedAt
        )

        // Send to backend and get backend ID
        let backendId = try await moodBackendService.createMood(
            domainEntry, accessToken: accessToken)

        // Store backend ID in local database
        moodEntry.backendId = backendId
        try modelContext.save()
        print("✅ [OutboxProcessor] Stored backend ID: \(backendId) for mood entry: \(moodEntry.id)")
    }

    private func processMoodUpdated(
        _ event: OutboxEvent, moodEntry: SDMoodEntry, accessToken: String
    ) async throws {
        // Ensure we have a backend ID
        guard let backendId = moodEntry.backendId else {
            print(
                "⚠️ [OutboxProcessor] Cannot update - no backend ID found for mood entry: \(moodEntry.id)"
            )
            print(
                "⚠️ [OutboxProcessor] Entry may not have been created on backend yet. Treating as create."
            )
            // Fallback to create if no backend ID
            try await processMoodCreated(event, moodEntry: moodEntry, accessToken: accessToken)
            return
        }

        // Convert SDMoodEntry to domain MoodEntry
        let domainEntry = MoodEntry(
            id: moodEntry.id,
            userId: moodEntry.userId,
            date: moodEntry.date,
            valence: moodEntry.valence,
            labels: moodEntry.labels,
            associations: moodEntry.associations,
            notes: moodEntry.notes,
            source: MoodSource(rawValue: moodEntry.source) ?? .manual,
            sourceId: moodEntry.sourceId,
            createdAt: moodEntry.createdAt,
            updatedAt: moodEntry.updatedAt
        )

        // Send update to backend using PUT
        try await moodBackendService.updateMood(
            domainEntry, backendId: backendId, accessToken: accessToken)
        print("✅ [OutboxProcessor] Successfully updated backend mood entry: \(backendId)")
    }

    private func processMoodDeleted(_ event: OutboxEvent, accessToken: String) async throws {
        // Extract backend ID from metadata
        guard case .generic(let dict) = event.metadata,
            let backendId = dict["backendId"]
        else {
            print(
                "⚠️ [OutboxProcessor] No backend ID for mood deletion, entry was never synced: \(event.entityID)"
            )
            return
        }

        try await moodBackendService.deleteMood(backendId: backendId, accessToken: accessToken)
        print("✅ [OutboxProcessor] Mood deleted from backend: \(backendId)")
    }

    // MARK: - Journal Event Processing

    private func processJournalEvent(_ event: OutboxEvent, accessToken: String) async throws {
        // Check if this is a delete operation
        if case .generic(let dict) = event.metadata, dict["operation"] == "delete" {
            try await processJournalDeleted(event, accessToken: accessToken)
            return
        }

        // For create/update, fetch the full entity from local store
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.id == event.entityID }
        )
        guard let journalEntry = try modelContext.fetch(descriptor).first else {
            print("⚠️ [OutboxProcessor] Journal entry not found: \(event.entityID)")
            throw ProcessorError.entityNotFound
        }

        if event.isNewRecord {
            try await processJournalCreated(
                event, journalEntry: journalEntry, accessToken: accessToken)
        } else {
            try await processJournalUpdated(
                event, journalEntry: journalEntry, accessToken: accessToken)
        }
    }

    private func processJournalCreated(
        _ event: OutboxEvent, journalEntry: SDJournalEntry, accessToken: String
    ) async throws {
        // Convert SDJournalEntry to domain JournalEntry
        let domainEntry = JournalEntry(
            id: journalEntry.id,
            userId: journalEntry.userId,
            date: journalEntry.date,
            title: journalEntry.title,
            content: journalEntry.content,
            tags: journalEntry.tags,
            entryType: EntryType(rawValue: journalEntry.entryType) ?? .freeform,
            isFavorite: journalEntry.isFavorite,
            linkedMoodId: journalEntry.linkedMoodId,
            createdAt: journalEntry.createdAt,
            updatedAt: journalEntry.updatedAt
        )

        // Send to backend and get backend ID
        let backendId = try await journalBackendService.createJournalEntry(
            domainEntry, accessToken: accessToken)

        // Store backend ID in local database
        journalEntry.backendId = backendId
        try modelContext.save()
        print(
            "✅ [OutboxProcessor] Stored backend ID: \(backendId) for journal entry: \(journalEntry.id)"
        )
    }

    private func processJournalUpdated(
        _ event: OutboxEvent, journalEntry: SDJournalEntry, accessToken: String
    ) async throws {
        // Ensure we have a backend ID
        guard let backendId = journalEntry.backendId else {
            print(
                "⚠️ [OutboxProcessor] Cannot update journal - no backend ID found for entry: \(journalEntry.id)"
            )
            print(
                "⚠️ [OutboxProcessor] Journal entry may not have been created on backend yet. Treating as create."
            )
            // Fallback to create if no backend ID
            try await processJournalCreated(
                event, journalEntry: journalEntry, accessToken: accessToken)
            return
        }

        // Convert SDJournalEntry to domain JournalEntry
        let domainEntry = JournalEntry(
            id: journalEntry.id,
            userId: journalEntry.userId,
            date: journalEntry.date,
            title: journalEntry.title,
            content: journalEntry.content,
            tags: journalEntry.tags,
            entryType: EntryType(rawValue: journalEntry.entryType) ?? .freeform,
            isFavorite: journalEntry.isFavorite,
            linkedMoodId: journalEntry.linkedMoodId,
            createdAt: journalEntry.createdAt,
            updatedAt: journalEntry.updatedAt
        )

        // Send update to backend using PUT
        try await journalBackendService.updateJournalEntry(
            domainEntry, backendId: backendId, accessToken: accessToken)
        print("✅ [OutboxProcessor] Successfully updated backend journal entry: \(backendId)")
    }

    private func processJournalDeleted(_ event: OutboxEvent, accessToken: String) async throws {
        // Extract backend ID from metadata
        guard case .generic(let dict) = event.metadata,
            let backendId = dict["backendId"]
        else {
            print(
                "⚠️ [OutboxProcessor] No backend ID for journal deletion, entry was never synced: \(event.entityID)"
            )
            return
        }

        try await journalBackendService.deleteJournalEntry(
            backendId: backendId, accessToken: accessToken)
        print("✅ [OutboxProcessor] Journal deleted from backend: \(backendId)")
    }

    // MARK: - Goal Event Processing

    private func processGoalEvent(_ event: OutboxEvent, accessToken: String) async throws {
        // Check if this is a delete operation
        if case .generic(let dict) = event.metadata, dict["operation"] == "delete" {
            try await processGoalDeleted(event, accessToken: accessToken)
            return
        }

        // For create/update, fetch the full entity from local store
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == event.entityID }
        )
        guard let goal = try modelContext.fetch(descriptor).first else {
            print("⚠️ [OutboxProcessor] Goal not found: \(event.entityID)")
            throw ProcessorError.entityNotFound
        }

        if event.isNewRecord {
            try await processGoalCreated(event, goal: goal, accessToken: accessToken)
        } else {
            try await processGoalUpdated(event, goal: goal, accessToken: accessToken)
        }
    }

    private func processGoalCreated(_ event: OutboxEvent, goal: SDGoal, accessToken: String)
        async throws
    {
        // Convert SDGoal to domain Goal
        let domainGoal = Goal(
            id: goal.id,
            userId: goal.userId,
            title: goal.title,
            description: goal.goalDescription,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt,
            targetDate: goal.targetDate,
            progress: goal.progress,
            status: GoalStatus(rawValue: goal.status) ?? .active,
            category: GoalCategory(rawValue: goal.category) ?? .general
        )

        print("🌐 [OutboxProcessor] Sending goal to backend: /api/v1/goals")

        // Send to backend
        let backendId = try await goalBackendService.createGoal(
            domainGoal, accessToken: accessToken)
        print("✅ [OutboxProcessor] Backend returned ID: \(backendId)")

        // Update local record with backend ID
        goal.backendId = backendId
        try modelContext.save()
        print(
            "✅ [OutboxProcessor] Successfully synced goal: \(goal.id), backend ID: \(backendId)")
    }

    private func processGoalUpdated(_ event: OutboxEvent, goal: SDGoal, accessToken: String)
        async throws
    {
        // Ensure we have a backend ID
        guard let backendId = goal.backendId else {
            print(
                "⚠️ [OutboxProcessor] Cannot update goal - no backend ID found for goal: \(goal.id)"
            )
            print(
                "⚠️ [OutboxProcessor] Goal may not have been created on backend yet. Treating as create."
            )
            // Fallback to create if no backend ID
            try await processGoalCreated(event, goal: goal, accessToken: accessToken)
            return
        }

        // Convert SDGoal to domain Goal
        let domainGoal = Goal(
            id: goal.id,
            userId: goal.userId,
            title: goal.title,
            description: goal.goalDescription,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt,
            targetDate: goal.targetDate,
            progress: goal.progress,
            status: GoalStatus(rawValue: goal.status) ?? .active,
            category: GoalCategory(rawValue: goal.category) ?? .general
        )

        // Send update to backend
        try await goalBackendService.updateGoal(
            domainGoal, backendId: backendId, accessToken: accessToken)
        print("✅ [OutboxProcessor] Successfully updated backend goal: \(backendId)")
    }

    private func processGoalDeleted(_ event: OutboxEvent, accessToken: String) async throws {
        // Extract backend ID from metadata
        guard case .generic(let dict) = event.metadata,
            let backendId = dict["backendId"]
        else {
            print(
                "⚠️ [OutboxProcessor] No backend ID for goal deletion, entry was never synced: \(event.entityID)"
            )
            return
        }

        try await goalBackendService.deleteGoal(backendId: backendId, accessToken: accessToken)
        print("✅ [OutboxProcessor] Successfully deleted backend goal: \(backendId)")
    }

    // MARK: - Chat/Conversation Event Processing

    private func processConversationDeleted(_ event: OutboxEvent, accessToken: String) async throws
    {
        // Extract conversationId from metadata
        guard case .generic(let dict) = event.metadata,
            let conversationIdString = dict["conversationId"],
            let conversationId = UUID(uuidString: conversationIdString)
        else {
            print("⚠️ [OutboxProcessor] Invalid conversation ID for deletion: \(event.entityID)")
            throw ProcessorError.invalidMetadata
        }

        print("🗑️ [OutboxProcessor] Processing conversation deletion: \(conversationId)")

        // Call backend to delete conversation
        try await chatBackendService.deleteConversation(
            conversationId: conversationId,
            accessToken: accessToken
        )

        print("✅ [OutboxProcessor] Conversation deleted from backend: \(conversationId)")
    }

    private func calculateRetryDelay(for retryCount: Int) -> TimeInterval {
        // Exponential backoff: 2^retryCount * baseDelay
        // Retry 1: 2s, Retry 2: 4s, Retry 3: 8s, Retry 4: 16s, Retry 5: 32s
        let delay = pow(2.0, Double(retryCount)) * baseRetryDelay
        return min(delay, 60.0)  // Cap at 60 seconds
    }
}

// MARK: - Processor Errors

enum ProcessorError: Error, LocalizedError {
    case entityNotFound
    case invalidMetadata
    case missingBackendId

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "Entity not found in local database"
        case .invalidMetadata:
            return "Invalid or missing metadata"
        case .missingBackendId:
            return "Backend ID not found"
        }
    }
}
