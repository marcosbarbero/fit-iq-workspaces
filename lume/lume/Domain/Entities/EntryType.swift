//
//  EntryType.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation

/// Types of journal entries for categorization and organization
enum EntryType: String, Codable, CaseIterable, Identifiable {
    case freeform = "freeform"
    case gratitude = "gratitude"
    case reflection = "reflection"
    case goalReview = "goal_review"
    case dailyLog = "daily_log"

    var id: String { rawValue }

    /// Display name for the entry type
    var displayName: String {
        switch self {
        case .freeform:
            return "Freeform"
        case .gratitude:
            return "Gratitude"
        case .reflection:
            return "Reflection"
        case .goalReview:
            return "Goal Review"
        case .dailyLog:
            return "Daily Log"
        }
    }

    /// Description of the entry type
    var description: String {
        switch self {
        case .freeform:
            return "Write freely about anything on your mind"
        case .gratitude:
            return "Reflect on things you're grateful for"
        case .reflection:
            return "Deep reflection on experiences and thoughts"
        case .goalReview:
            return "Review progress on your goals"
        case .dailyLog:
            return "Capture the highlights of your day"
        }
    }

    /// SF Symbol icon for the entry type
    var icon: String {
        switch self {
        case .freeform:
            return "pencil.and.outline"
        case .gratitude:
            return "heart.fill"
        case .reflection:
            return "brain.head.profile"
        case .goalReview:
            return "target"
        case .dailyLog:
            return "calendar"
        }
    }

    /// Color hex string for the entry type
    var colorHex: String {
        switch self {
        case .freeform:
            return "#F2C9A7"  // Primary accent
        case .gratitude:
            return "#FFD4E5"  // Pink - warmth
        case .reflection:
            return "#D4B8F0"  // Purple - introspection
        case .goalReview:
            return "#B8E8D4"  // Mint - optimism
        case .dailyLog:
            return "#F5DFA8"  // Yellow - brightness
        }
    }

    /// Default prompt/placeholder for this entry type
    var prompt: String {
        switch self {
        case .freeform:
            return "What's on your mind today?"
        case .gratitude:
            return "What are you grateful for today?"
        case .reflection:
            return "Take a moment to reflect on your thoughts and experiences..."
        case .goalReview:
            return "How are you progressing on your goals?"
        case .dailyLog:
            return "How was your day? What happened?"
        }
    }

    /// Suggested tags for this entry type
    var suggestedTags: [String] {
        switch self {
        case .freeform:
            return ["thoughts", "ideas", "personal"]
        case .gratitude:
            return ["grateful", "thankful", "blessed", "appreciation"]
        case .reflection:
            return ["reflection", "insight", "learning", "growth"]
        case .goalReview:
            return ["goals", "progress", "achievement", "planning"]
        case .dailyLog:
            return ["daily", "routine", "summary", "recap"]
        }
    }
}
