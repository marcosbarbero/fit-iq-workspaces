//
//  FetchConversationsUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for fetching chat conversations use case
protocol FetchConversationsUseCaseProtocol {
    /// Fetch all conversations with optional sync and filtering
    /// - Parameters:
    ///   - includeArchived: Whether to include archived conversations (local filter only)
    ///   - syncFromBackend: Whether to sync from backend first
    ///   - status: Optional backend status filter (active, completed, abandoned, archived)
    ///   - persona: Optional persona filter
    ///   - limit: Number of results to return (1-100, default: 20)
    ///   - offset: Pagination offset (default: 0)
    /// - Returns: Array of ChatConversation objects
    /// - Throws: Use case error if fetch fails
    func execute(
        includeArchived: Bool,
        syncFromBackend: Bool,
        status: String?,
        persona: ChatPersona?,
        limit: Int,
        offset: Int
    ) async throws -> [ChatConversation]
}

/// Use case for fetching chat conversations
/// Coordinates between local repository and backend service
final class FetchConversationsUseCase: FetchConversationsUseCaseProtocol {
    private let chatRepository: ChatRepositoryProtocol
    private let chatService: ChatServiceProtocol

    init(
        chatRepository: ChatRepositoryProtocol,
        chatService: ChatServiceProtocol
    ) {
        self.chatRepository = chatRepository
        self.chatService = chatService
    }

    func execute(
        includeArchived: Bool = false,
        syncFromBackend: Bool = true,
        status: String? = nil,
        persona: ChatPersona? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        // Sync from backend if requested
        if syncFromBackend {
            do {
                let backendConversations = try await chatService.fetchConversations(
                    status: status,
                    persona: persona,
                    limit: limit,
                    offset: offset
                )

                // Update local repository
                for conversation in backendConversations {
                    do {
                        _ = try await chatRepository.updateConversation(conversation)
                    } catch {
                        print(
                            "⚠️ [FetchConversationsUseCase] Failed to update conversation \(conversation.id): \(error)"
                        )
                    }
                }

                print(
                    "✅ [FetchConversationsUseCase] Synced \(backendConversations.count) conversations from backend"
                )
            } catch {
                // If backend sync fails, continue with local data
                print(
                    "⚠️ [FetchConversationsUseCase] Backend sync failed: \(error.localizedDescription)"
                )
            }
        }

        // Fetch from local repository
        let allConversations = try await chatRepository.fetchAllConversations()

        // Filter archived if needed
        var conversations: [ChatConversation]
        if includeArchived {
            conversations = allConversations
        } else {
            conversations = allConversations.filter { !$0.isArchived }
        }

        // Sort by updated date, most recent first
        conversations.sort { $0.updatedAt > $1.updatedAt }

        return conversations
    }
}

// MARK: - Convenience Methods

extension FetchConversationsUseCase {
    /// Fetch a specific conversation by ID
    /// - Parameters:
    ///   - id: The conversation UUID
    ///   - syncFromBackend: Whether to fetch from backend first
    /// - Returns: The conversation if found, nil otherwise
    func fetchById(_ id: UUID, syncFromBackend: Bool = true) async throws -> ChatConversation? {
        if syncFromBackend {
            // Try to fetch from backend first
            do {
                let conversation = try await chatService.fetchConversation(id: id)
                // Update local repository
                _ = try await chatRepository.updateConversation(conversation)
                print("✅ [FetchConversationsUseCase] Fetched conversation \(id) from backend")
                return conversation
            } catch {
                print(
                    "⚠️ [FetchConversationsUseCase] Backend fetch failed, checking local: \(error)")
            }
        }

        // Fallback to local repository
        return try await chatRepository.fetchConversationById(id)
    }

    /// Fetch active (non-archived) conversations
    func fetchActive(
        syncFromBackend: Bool = true,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        try await execute(
            includeArchived: false,
            syncFromBackend: syncFromBackend,
            status: "active",
            persona: nil,
            limit: limit,
            offset: offset
        )
    }

    /// Fetch archived conversations only
    func fetchArchived(
        syncFromBackend: Bool = false,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        try await execute(
            includeArchived: true,
            syncFromBackend: syncFromBackend,
            status: "archived",
            persona: nil,
            limit: limit,
            offset: offset
        )
    }

    /// Fetch conversations by persona
    func fetchByPersona(
        _ persona: ChatPersona,
        syncFromBackend: Bool = true,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        try await execute(
            includeArchived: false,
            syncFromBackend: syncFromBackend,
            status: nil,
            persona: persona,
            limit: limit,
            offset: offset
        )
    }

    /// Fetch recent conversations (last 7 days)
    func fetchRecent(
        syncFromBackend: Bool = true,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        let conversations = try await execute(
            includeArchived: false,
            syncFromBackend: syncFromBackend,
            status: nil,
            persona: nil,
            limit: limit,
            offset: offset
        )
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        return conversations.filter { $0.updatedAt >= sevenDaysAgo }
    }

    /// Fetch conversations related to a specific goal
    func fetchForGoal(
        _ goalId: UUID,
        syncFromBackend: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        let conversations = try await execute(
            includeArchived: false,
            syncFromBackend: syncFromBackend,
            status: nil,
            persona: nil,
            limit: limit,
            offset: offset
        )

        return conversations.filter { conversation in
            if let relatedGoalIds = conversation.context?.relatedGoalIds {
                return relatedGoalIds.contains(goalId)
            }
            return false
        }
    }

    /// Fetch conversations with recent activity (updated in last 24 hours)
    func fetchWithRecentActivity(
        syncFromBackend: Bool = true,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        let conversations = try await execute(
            includeArchived: false,
            syncFromBackend: syncFromBackend,
            status: nil,
            persona: nil,
            limit: limit,
            offset: offset
        )

        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        return conversations.filter { $0.updatedAt >= oneDayAgo }
    }

    /// Search conversations by title
    func search(
        query: String,
        syncFromBackend: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        let conversations = try await execute(
            includeArchived: false,
            syncFromBackend: syncFromBackend,
            status: nil,
            persona: nil,
            limit: limit,
            offset: offset
        )
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !lowercasedQuery.isEmpty else {
            return conversations
        }

        return conversations.filter { conversation in
            conversation.title.lowercased().contains(lowercasedQuery)
        }
    }
}

// MARK: - Statistics

extension FetchConversationsUseCase {
    /// Get conversation statistics
    func getStatistics(syncFromBackend: Bool = true) async throws -> ConversationStatistics {
        let allConversations = try await execute(
            includeArchived: true,
            syncFromBackend: syncFromBackend,
            status: nil,
            persona: nil,
            limit: 100,
            offset: 0
        )

        let activeCount = allConversations.filter { !$0.isArchived }.count
        let archivedCount = allConversations.filter { $0.isArchived }.count

        // Count by persona
        let personaCounts = Dictionary(
            grouping: allConversations.filter { !$0.isArchived }, by: { $0.persona }
        )
        .mapValues { $0.count }

        // Calculate average messages per conversation
        var totalMessages = 0
        for conversation in allConversations.filter({ !$0.isArchived }) {
            let messages = try await chatRepository.fetchMessages(for: conversation.id)
            totalMessages += messages.count
        }

        let averageMessagesPerConversation =
            activeCount > 0 ? Double(totalMessages) / Double(activeCount) : 0.0

        // Find most recent conversation
        let mostRecent = allConversations.filter { !$0.isArchived }.max {
            $0.updatedAt < $1.updatedAt
        }

        return ConversationStatistics(
            totalCount: allConversations.count,
            activeCount: activeCount,
            archivedCount: archivedCount,
            personaCounts: personaCounts,
            totalMessages: totalMessages,
            averageMessagesPerConversation: averageMessagesPerConversation,
            mostRecentUpdatedAt: mostRecent?.updatedAt
        )
    }
}

// MARK: - Supporting Types

/// Statistics summary for conversations
struct ConversationStatistics {
    let totalCount: Int
    let activeCount: Int
    let archivedCount: Int
    let personaCounts: [ChatPersona: Int]
    let totalMessages: Int
    let averageMessagesPerConversation: Double
    let mostRecentUpdatedAt: Date?

    var mostUsedPersona: ChatPersona? {
        personaCounts.max { $0.value < $1.value }?.key
    }

    var description: String {
        var parts: [String] = []

        if activeCount > 0 {
            parts.append("\(activeCount) active")
        }
        if archivedCount > 0 {
            parts.append("\(archivedCount) archived")
        }
        if totalMessages > 0 {
            parts.append("\(totalMessages) messages")
        }

        if parts.isEmpty {
            return "No conversations yet"
        }

        return parts.joined(separator: ", ")
    }
}
