//
//  MoodEntry.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Refactored: 2025-01-15 - Aligned with backend API and HealthKit standards
//

import Foundation

/// Represents a user's mood entry for a specific date
/// Aligned with Apple HealthKit's mental wellness model and backend API
struct MoodEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let date: Date

    /// Emotional valence from -1.0 (very unpleasant) to 1.0 (very pleasant)
    /// Based on Apple HealthKit's mental wellness model
    let valence: Double

    /// Mood labels describing emotional states
    /// Primary label should be first in the array
    let labels: [String]

    /// Contextual associations (e.g., work, family, health)
    let associations: [String]

    /// Optional notes about mood and feelings
    let notes: String?

    /// Source of the mood entry
    let source: MoodSource

    /// External source identifier (e.g., HealthKit sample ID)
    let sourceId: String?

    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        date: Date,
        valence: Double,
        labels: [String] = [],
        associations: [String] = [],
        notes: String? = nil,
        source: MoodSource = .manual,
        sourceId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.valence = min(max(valence, -1.0), 1.0)  // Clamp between -1.0 and 1.0
        self.labels = labels
        self.associations = associations
        self.notes = notes
        self.source = source
        self.sourceId = sourceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Convenience Initializer

    /// Create mood entry from a mood label
    init(
        id: UUID = UUID(),
        userId: UUID,
        date: Date,
        moodLabel: MoodLabel,
        associations: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.valence = moodLabel.defaultValence
        self.labels = [moodLabel.rawValue]
        self.associations = associations
        self.notes = notes
        self.source = .manual
        self.sourceId = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Primary mood label (first label in array)
    var primaryLabel: String? {
        labels.first
    }

    /// Primary mood as MoodLabel enum (if valid)
    var primaryMoodLabel: MoodLabel? {
        guard let primary = primaryLabel else { return nil }
        return MoodLabel(rawValue: primary)
    }

    /// Display name for primary mood, with fallback
    var primaryMoodDisplayName: String {
        primaryMoodLabel?.displayName ?? "No Label"
    }

    /// System image for primary mood, with fallback
    var primaryMoodSystemImage: String {
        primaryMoodLabel?.systemImage ?? "circle.fill"
    }

    /// Color for primary mood, with neutral fallback
    var primaryMoodColor: String {
        primaryMoodLabel?.color ?? "#E8E3F0"  // Light neutral color
    }

    /// Preview of the note (first 100 characters)
    var notePreview: String {
        guard let notes = notes, !notes.isEmpty else {
            return ""
        }
        return String(notes.prefix(100))
    }

    /// Check if mood entry has a note
    var hasNote: Bool {
        guard let notes = notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Valence category for display
    var valenceCategory: ValenceCategory {
        switch valence {
        case -1.0..<(-0.5): return .veryUnpleasant
        case -0.5..<0.0: return .unpleasant
        case 0.0: return .neutral
        case 0.0..<0.5: return .pleasant
        case 0.5...1.0: return .veryPleasant
        default: return .neutral
        }
    }

    /// System image based on valence category
    var valenceCategorySystemImage: String {
        switch valenceCategory {
        case .veryUnpleasant: return "cloud.rain.fill"
        case .unpleasant: return "cloud.fill"
        case .neutral: return "minus.circle.fill"
        case .pleasant: return "sun.max.fill"
        case .veryPleasant: return "star.fill"
        }
    }

    /// Valence as percentage (0-100) for UI display
    var valencePercentage: Int {
        Int(round((valence + 1.0) * 50.0))
    }
}

// MARK: - MoodSource

/// Source of the mood entry
enum MoodSource: String, Codable {
    case manual = "manual"
    case healthkit = "healthkit"
}

// MARK: - ValenceCategory

/// Categorization of valence for display purposes
enum ValenceCategory: String {
    case veryUnpleasant = "Very Unpleasant"
    case unpleasant = "Unpleasant"
    case neutral = "Neutral"
    case pleasant = "Pleasant"
    case veryPleasant = "Very Pleasant"

    var color: String {
        switch self {
        case .veryUnpleasant: return "#F0B8A4"  // Soft coral
        case .unpleasant: return "#E8D9C8"  // Light tan
        case .neutral: return "#B8D4E8"  // Light sky blue
        case .pleasant: return "#F5DFA8"  // Bright yellow
        case .veryPleasant: return "#C5E8C0"  // Light mint green
        }
    }
}

// MARK: - MoodLabel

/// Standardized mood labels aligned with backend API
/// These map to the backend's allowed label enum values
enum MoodLabel: String, Codable, CaseIterable, Identifiable {
    // Backend accepted labels (positive)
    case amazed = "amazed"
    case grateful = "grateful"
    case happy = "happy"
    case proud = "proud"
    case hopeful = "hopeful"
    case content = "content"
    case peaceful = "peaceful"
    case excited = "excited"
    case joyful = "joyful"

    // Backend accepted labels (negative)
    case sad = "sad"
    case angry = "angry"
    case stressed = "stressed"
    case anxious = "anxious"
    case frustrated = "frustrated"
    case overwhelmed = "overwhelmed"
    case lonely = "lonely"
    case scared = "scared"
    case worried = "worried"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .amazed: return "Amazed"
        case .grateful: return "Grateful"
        case .happy: return "Happy"
        case .proud: return "Proud"
        case .hopeful: return "Hopeful"
        case .content: return "Content"
        case .peaceful: return "Peaceful"
        case .excited: return "Excited"
        case .joyful: return "Joyful"
        case .sad: return "Sad"
        case .angry: return "Angry"
        case .stressed: return "Stressed"
        case .anxious: return "Anxious"
        case .frustrated: return "Frustrated"
        case .overwhelmed: return "Overwhelmed"
        case .lonely: return "Lonely"
        case .scared: return "Scared"
        case .worried: return "Worried"
        }
    }

    var description: String {
        switch self {
        case .amazed: return "Wonderstruck and in awe"
        case .grateful: return "Thankful and appreciative"
        case .happy: return "Joyful and positive"
        case .proud: return "Accomplished and confident"
        case .hopeful: return "Optimistic and encouraged"
        case .content: return "Satisfied and at ease"
        case .peaceful: return "Tranquil and serene"
        case .excited: return "Enthusiastic and eager"
        case .joyful: return "Cheerful and delighted"
        case .sad: return "Down or melancholy"
        case .angry: return "Upset or frustrated"
        case .stressed: return "Overwhelmed or tense"
        case .anxious: return "Worried or uneasy"
        case .frustrated: return "Annoyed or irritated"
        case .overwhelmed: return "Too much to handle"
        case .lonely: return "Isolated or disconnected"
        case .scared: return "Fearful or afraid"
        case .worried: return "Concerned or troubled"
        }
    }

    /// SF Symbol for each mood
    var systemImage: String {
        switch self {
        case .amazed: return "star.circle.fill"
        case .grateful: return "heart.fill"
        case .happy: return "sun.max.fill"
        case .proud: return "trophy.fill"
        case .hopeful: return "sunrise.fill"
        case .content: return "checkmark.circle.fill"
        case .peaceful: return "moon.stars.fill"
        case .excited: return "sparkles"
        case .joyful: return "star.fill"
        case .sad: return "cloud.rain.fill"
        case .angry: return "flame.fill"
        case .stressed: return "cloud.fill"
        case .anxious: return "wind"
        case .frustrated: return "exclamationmark.triangle.fill"
        case .overwhelmed: return "tornado"
        case .lonely: return "figure.stand.line.dotted.figure.stand"
        case .scared: return "bolt.trianglebadge.exclamationmark.fill"
        case .worried: return "brain.head.profile"
        }
    }

    /// Light color for each mood from LumeColors
    var color: String {
        switch self {
        // Positive moods - vibrant, warm, energizing colors
        case .amazed: return "#E8D4F0"  // Light purple - wonder
        case .grateful: return "#FFD4E5"  // Light rose - warmth
        case .happy: return "#F5DFA8"  // Bright yellow - joy
        case .proud: return "#D4B8F0"  // Soft purple - achievement
        case .hopeful: return "#B8E8D4"  // Light mint - optimism
        case .content: return "#D8E8C8"  // Sage green - peace
        case .peaceful: return "#C8D8EA"  // Soft sky blue - calm
        case .excited: return "#FFE4B5"  // Light orange - energy
        case .joyful: return "#F5E8A8"  // Bright lemon - delight

        // Challenging moods - softer, muted colors for comfort
        case .sad: return "#C8D4E8"  // Light blue - melancholy
        case .angry: return "#F0B8A4"  // Soft coral - frustration
        case .stressed: return "#E8C4B4"  // Soft peach - tension
        case .anxious: return "#E8E4D8"  // Light tan - unease
        case .frustrated: return "#F0C8A4"  // Light terracotta - irritation
        case .overwhelmed: return "#D4C8E8"  // Light purple-gray - overload
        case .lonely: return "#B8C8E8"  // Cool lavender-blue - isolation
        case .scared: return "#E8D4C8"  // Warm beige - fear
        case .worried: return "#D8C8D8"  // Light mauve - concern
        }
    }

    /// Default valence for this mood label
    /// Based on typical emotional valence research
    /// Scale: -1.0 (most unpleasant) to 1.0 (most pleasant)
    var defaultValence: Double {
        switch self {
        // Positive moods (most pleasant to pleasant)
        case .joyful: return 0.9
        case .excited: return 0.85
        case .amazed: return 0.8
        case .grateful: return 0.75
        case .proud: return 0.7
        case .happy: return 0.65
        case .hopeful: return 0.5
        case .peaceful: return 0.3
        case .content: return 0.0  // Neutral - balanced state

        // Negative moods (mild discomfort to most unpleasant)
        case .worried: return -0.4
        case .anxious: return -0.5
        case .frustrated: return -0.55
        case .lonely: return -0.6
        case .stressed: return -0.65
        case .overwhelmed: return -0.7
        case .angry: return -0.75
        case .scared: return -0.8
        case .sad: return -0.85
        }
    }

    /// Reflection prompt for this mood
    var reflectionPrompt: String {
        switch self {
        case .amazed: return "What filled you with wonder today?"
        case .grateful: return "What are you thankful for?"
        case .happy: return "What brought you joy today?"
        case .proud: return "What are you proud of accomplishing?"
        case .hopeful: return "What are you looking forward to?"
        case .content: return "What are you satisfied with?"
        case .peaceful: return "What brought you this tranquility?"
        case .excited: return "What has you feeling energized?"
        case .joyful: return "What made you feel so delighted?"
        case .sad: return "What's weighing on your heart?"
        case .angry: return "What triggered this feeling?"
        case .stressed: return "What can you let go of?"
        case .anxious: return "What's on your mind?"
        case .frustrated: return "What's not going as planned?"
        case .overwhelmed: return "What feels like too much right now?"
        case .lonely: return "Who or what do you miss?"
        case .scared: return "What feels uncertain or threatening?"
        case .worried: return "What concerns are on your mind?"
        }
    }
}

// MARK: - MoodAssociation

/// Contextual associations for mood entries
/// Aligned with backend API enum values
enum MoodAssociation: String, Codable, CaseIterable, Identifiable {
    case work = "work"
    case family = "family"
    case health = "health"
    case weather = "weather"
    case fitness = "fitness"
    case social = "social"
    case travel = "travel"
    case hobbies = "hobbies"
    case dating = "dating"
    case currentEvents = "currentEvents"
    case finances = "finances"
    case education = "education"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .family: return "Family"
        case .health: return "Health"
        case .weather: return "Weather"
        case .fitness: return "Fitness"
        case .social: return "Social"
        case .travel: return "Travel"
        case .hobbies: return "Hobbies"
        case .dating: return "Dating"
        case .currentEvents: return "Current Events"
        case .finances: return "Finances"
        case .education: return "Education"
        }
    }

    var systemImage: String {
        switch self {
        case .work: return "briefcase.fill"
        case .family: return "house.fill"
        case .health: return "heart.fill"
        case .weather: return "cloud.sun.fill"
        case .fitness: return "figure.run"
        case .social: return "person.2.fill"
        case .travel: return "airplane"
        case .hobbies: return "paintbrush.fill"
        case .dating: return "heart.circle.fill"
        case .currentEvents: return "newspaper.fill"
        case .finances: return "dollarsign.circle.fill"
        case .education: return "book.fill"
        }
    }
}
