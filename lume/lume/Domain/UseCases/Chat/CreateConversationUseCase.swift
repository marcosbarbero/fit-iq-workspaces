//
//  CreateConversationUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for creating a new chat conversation use case
protocol CreateConversationUseCaseProtocol {
    /// Create a new chat conversation
    /// - Parameters:
    ///   - title: The conversation title
    ///   - persona: The AI persona for this conversation
    ///   - context: Optional conversation context
    /// - Returns: The created ChatConversation
    /// - Throws: Use case error if creation fails
    func execute(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?
    ) async throws -> ChatConversation
}

/// Use case for creating chat conversations
/// Validates input and coordinates between repository and backend service
final class CreateConversationUseCase: CreateConversationUseCaseProtocol {
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
        title: String,
        persona: ChatPersona,
        context: ConversationContext? = nil
    ) async throws -> ChatConversation {
        // Validate input
        try validateInput(title: title)

        // Create conversation in repository (this will handle both local and backend)
        let conversation = try await chatRepository.createConversation(
            title: title,
            persona: persona,
            context: context
        )

        print("✅ [CreateConversationUseCase] Created conversation: \(conversation.id)")

        return conversation
    }
}

// MARK: - Validation

extension CreateConversationUseCase {
    /// Validate conversation input
    fileprivate func validateInput(title: String) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            throw CreateConversationError.emptyTitle
        }

        guard trimmedTitle.count >= 3 else {
            throw CreateConversationError.titleTooShort
        }

        guard trimmedTitle.count <= 100 else {
            throw CreateConversationError.titleTooLong
        }
    }
}

// MARK: - Convenience Methods

extension CreateConversationUseCase {
    /// Create conversation with default wellness persona
    func createDefault(title: String) async throws -> ChatConversation {
        try await execute(title: title, persona: .generalWellness, context: nil)
    }

    /// Create conversation with goal context
    func createForGoal(
        goalId: UUID,
        goalTitle: String,
        backendGoalId: String?,
        persona: ChatPersona = .generalWellness
    ) async throws -> ChatConversation {
        // Use backend goal ID if available, otherwise fall back to local UUID
        let contextGoalId = backendGoalId ?? goalId.uuidString

        let context = ConversationContext(
            relatedGoalIds: [goalId],
            relatedInsightIds: nil,
            moodContext: nil,
            quickAction: "goal_support",
            backendGoalId: contextGoalId,
            goalTitle: goalTitle
        )

        // Use goal title with emoji for visual distinction
        let title = "💪 \(goalTitle)"
        print("🎯 [CreateConversationUseCase] Creating goal chat with title: '\(title)'")
        print("   - Goal ID: \(goalId)")
        print("   - Context has relatedGoalIds: \(context.relatedGoalIds ?? [])")

        let conversation = try await execute(title: title, persona: persona, context: context)

        print("✅ [CreateConversationUseCase] Goal chat created successfully")
        print("   - Conversation ID: \(conversation.id)")
        print("   - Conversation title: \(conversation.title)")
        print("   - Context: \(conversation.context != nil ? "✓" : "✗")")
        print("   - Related goal IDs: \(conversation.context?.relatedGoalIds ?? [])")

        return conversation
    }

    /// Create conversation with mood context
    func createForMoodSupport(
        moodContext: MoodContextSummary,
        persona: ChatPersona = .wellnessSpecialist
    ) async throws -> ChatConversation {
        let context = ConversationContext(
            relatedGoalIds: nil,
            relatedInsightIds: nil,
            moodContext: moodContext,
            quickAction: "mood_support"
        )

        let title = "Mood Support Chat"
        return try await execute(title: title, persona: persona, context: context)
    }

    /// Create conversation with insight context
    func createForInsight(
        insightId: UUID,
        insightType: String,
        persona: ChatPersona = .generalWellness
    ) async throws -> ChatConversation {
        let context = ConversationContext(
            relatedGoalIds: nil,
            relatedInsightIds: [insightId],
            moodContext: nil,
            quickAction: "insight_discussion"
        )

        let title = "Chat about \(insightType) Insight"
        return try await execute(title: title, persona: persona, context: context)
    }

    /// Create quick check-in conversation
    func createQuickCheckIn() async throws -> ChatConversation {
        try await execute(
            title: "Quick Check-in",
            persona: .wellnessSpecialist,
            context: nil
        )
    }
}

// MARK: - Errors

/// Errors specific to CreateConversationUseCase
enum CreateConversationError: Error, LocalizedError {
    case emptyTitle
    case titleTooShort
    case titleTooLong
    case serviceUnavailable
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Conversation title cannot be empty."
        case .titleTooShort:
            return "Conversation title must be at least 3 characters."
        case .titleTooLong:
            return "Conversation title must be 100 characters or less."
        case .serviceUnavailable:
            return "Chat service is temporarily unavailable."
        case .rateLimitExceeded:
            return "Too many conversations created. Please try again later."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyTitle, .titleTooShort:
            return "Please enter a meaningful conversation title."
        case .titleTooLong:
            return "Try to make your conversation title more concise."
        case .serviceUnavailable:
            return "Please check your connection and try again."
        case .rateLimitExceeded:
            return "Wait a moment before creating another conversation."
        }
    }
}
