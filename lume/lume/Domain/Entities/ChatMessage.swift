//
//  ChatMessage.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Represents a single message in a chat conversation
struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let conversationId: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var metadata: MessageMetadata?

    /// Maximum content length for a chat message (10,000 characters)
    static let maxContentLength = 10_000

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }

    /// Check if message is from user
    var isUserMessage: Bool {
        role == .user
    }

    /// Check if message is from assistant
    var isAssistantMessage: Bool {
        role == .assistant
    }

    /// Format timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Format timestamp with date
    var formattedTimestampWithDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

/// Role of a message sender
enum MessageRole: String, Codable, CaseIterable, Equatable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"

    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "AI Assistant"
        case .system:
            return "System"
        }
    }
}

/// Metadata for a chat message
struct MessageMetadata: Codable, Equatable, Hashable {
    let persona: ChatPersona?
    let context: [String: String]?
    let tokens: Int?
    let processingTime: Double?
    var isStreaming: Bool

    init(
        persona: ChatPersona? = nil,
        context: [String: String]? = nil,
        tokens: Int? = nil,
        processingTime: Double? = nil,
        isStreaming: Bool = false
    ) {
        self.persona = persona
        self.context = context
        self.tokens = tokens
        self.processingTime = processingTime
        self.isStreaming = isStreaming
    }
}

/// AI assistant persona for consultations (matches backend API)
enum ChatPersona: String, Codable, CaseIterable, Equatable {
    case generalWellness = "general_wellness"
    case wellnessSpecialist = "wellness_specialist"
    case nutritionist = "nutritionist"
    case fitnessCoach = "fitness_coach"
    case mentalHealthCoach = "mental_health_coach"
    case sleepCoach = "sleep_coach"

    var displayName: String {
        switch self {
        case .generalWellness:
            return "Wellness Coach"
        case .wellnessSpecialist:
            return "Wellness Companion"
        case .nutritionist:
            return "Nutritionist"
        case .fitnessCoach:
            return "Fitness Coach"
        case .mentalHealthCoach:
            return "Mental Health Coach"
        case .sleepCoach:
            return "Sleep Coach"
        }
    }

    var description: String {
        switch self {
        case .generalWellness:
            return "Your holistic wellness companion"
        case .wellnessSpecialist:
            return "Your supportive guide for mood and wellness"
        case .nutritionist:
            return "Expert nutrition guidance"
        case .fitnessCoach:
            return "Personalized fitness coaching"
        case .mentalHealthCoach:
            return "Mental wellness support"
        case .sleepCoach:
            return "Sleep optimization help"
        }
    }

    var systemImage: String {
        switch self {
        case .generalWellness:
            return "heart.circle.fill"
        case .wellnessSpecialist:
            return "heart.circle.fill"
        case .nutritionist:
            return "leaf.circle.fill"
        case .fitnessCoach:
            return "figure.run.circle.fill"
        case .mentalHealthCoach:
            return "brain.head.profile"
        case .sleepCoach:
            return "moon.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .generalWellness:
            return "accentPrimary"
        case .wellnessSpecialist:
            return "accentSecondary"
        case .nutritionist:
            return "moodPositive"
        case .fitnessCoach:
            return "moodLow"
        case .mentalHealthCoach:
            return "accentSecondary"
        case .sleepCoach:
            return "moodNeutral"
        }
    }

    var greeting: String {
        switch self {
        case .generalWellness:
            return "Hi! I'm here to support your wellness journey. How can I help you today?"
        case .wellnessSpecialist:
            return
                "Welcome. I'm here to support your mood and wellness journey. What's on your mind?"
        case .nutritionist:
            return "Hello! I'm your nutrition guide. Let's talk about healthy eating!"
        case .fitnessCoach:
            return "Hey there! Ready to talk about fitness and movement?"
        case .mentalHealthCoach:
            return "Welcome. I'm here to support your mental wellness. What's on your mind?"
        case .sleepCoach:
            return "Hi! Let's work together to improve your sleep quality."
        }
    }
}

/// Represents a chat conversation with the AI
struct ChatConversation: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    var title: String
    var persona: ChatPersona
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var context: ConversationContext?
    var hasContextForGoalSuggestions: Bool

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String = "New Conversation",
        persona: ChatPersona = .generalWellness,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        context: ConversationContext? = nil,
        hasContextForGoalSuggestions: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.persona = persona
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.context = context
        self.hasContextForGoalSuggestions = hasContextForGoalSuggestions
    }

    /// Get the last message in the conversation
    var lastMessage: ChatMessage? {
        messages.last
    }

    /// Get the last user message
    var lastUserMessage: ChatMessage? {
        messages.last(where: { $0.role == .user })
    }

    /// Get the last assistant message
    var lastAssistantMessage: ChatMessage? {
        messages.last(where: { $0.role == .assistant })
    }

    /// Total number of messages
    var messageCount: Int {
        messages.count
    }

    /// Number of user messages
    var userMessageCount: Int {
        messages.filter { $0.role == .user }.count
    }

    /// Number of assistant messages
    var assistantMessageCount: Int {
        messages.filter { $0.role == .assistant }.count
    }

    /// Check if conversation has messages
    var hasMessages: Bool {
        !messages.isEmpty
    }

    /// Format created date for display
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    /// Format updated date for display
    var formattedUpdatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }

    /// Add a message to the conversation
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()

        // Auto-generate title from first user message if still default
        if title == "New Conversation", message.role == .user {
            let words = message.content.components(separatedBy: .whitespaces).prefix(5)
            title = words.joined(separator: " ")
            if message.content.count > title.count {
                title += "..."
            }
        }
    }

    /// Archive the conversation
    mutating func archive() {
        isArchived = true
        updatedAt = Date()
    }

    /// Unarchive the conversation
    mutating func unarchive() {
        isArchived = false
        updatedAt = Date()
    }

    /// Clear all messages
    mutating func clearMessages() {
        messages.removeAll()
        updatedAt = Date()
    }
}

/// Context information for a conversation
struct ConversationContext: Codable, Equatable, Hashable {
    let relatedGoalIds: [UUID]?
    let relatedInsightIds: [UUID]?
    let moodContext: MoodContextSummary?
    let quickAction: String?
    let backendGoalId: String?  // Backend goal ID for API sync
    let goalTitle: String?  // Actual goal title for display

    init(
        relatedGoalIds: [UUID]? = nil,
        relatedInsightIds: [UUID]? = nil,
        moodContext: MoodContextSummary? = nil,
        quickAction: String? = nil,
        backendGoalId: String? = nil,
        goalTitle: String? = nil
    ) {
        self.relatedGoalIds = relatedGoalIds
        self.relatedInsightIds = relatedInsightIds
        self.moodContext = moodContext
        self.quickAction = quickAction
        self.backendGoalId = backendGoalId
        self.goalTitle = goalTitle
    }

    /// Check if conversation has context
    var hasContext: Bool {
        relatedGoalIds != nil || relatedInsightIds != nil || moodContext != nil
            || quickAction != nil
    }
}

/// Summary of mood context for conversations
struct MoodContextSummary: Codable, Equatable, Hashable {
    let recentMoodAverage: Double?
    let moodTrend: String?
    let moodEntryCount: Int?

    init(
        recentMoodAverage: Double? = nil,
        moodTrend: String? = nil,
        moodEntryCount: Int? = nil
    ) {
        self.recentMoodAverage = recentMoodAverage
        self.moodTrend = moodTrend
        self.moodEntryCount = moodEntryCount
    }

    /// Format mood average for display
    var formattedMoodAverage: String? {
        guard let average = recentMoodAverage else { return nil }
        return String(format: "%.1f/5.0", average)
    }
}

/// Quick action types for chat
enum QuickAction: String, Codable, CaseIterable {
    case createGoal = "create_goal"
    case reviewGoals = "review_goals"
    case moodCheck = "mood_check"
    case journalPrompt = "journal_prompt"
    case motivationalQuote = "motivational_quote"
    case progressReview = "progress_review"

    var displayName: String {
        switch self {
        case .createGoal:
            return "Create a Goal"
        case .reviewGoals:
            return "Review My Goals"
        case .moodCheck:
            return "How am I feeling?"
        case .journalPrompt:
            return "Journal Prompt"
        case .motivationalQuote:
            return "Inspire Me"
        case .progressReview:
            return "Review My Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .createGoal:
            return "target"
        case .reviewGoals:
            return "list.bullet.clipboard"
        case .moodCheck:
            return "heart.text.square"
        case .journalPrompt:
            return "square.and.pencil"
        case .motivationalQuote:
            return "quote.bubble"
        case .progressReview:
            return "chart.line.uptrend.xyaxis"
        }
    }

    var prompt: String {
        switch self {
        case .createGoal:
            return "I'd like to set a new wellness goal"
        case .reviewGoals:
            return "Can you help me review my current goals?"
        case .moodCheck:
            return "I'd like to check in on my mood"
        case .journalPrompt:
            return "Can you give me a journaling prompt?"
        case .motivationalQuote:
            return "I need some motivation today"
        case .progressReview:
            return "How am I progressing on my wellness journey?"
        }
    }
}
