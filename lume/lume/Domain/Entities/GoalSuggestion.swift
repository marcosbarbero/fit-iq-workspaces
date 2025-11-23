//
//  GoalSuggestion.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Represents an AI-generated goal suggestion
struct GoalSuggestion: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let goalType: String
    let targetValue: Double?
    let targetUnit: String?
    let rationale: String
    let estimatedDuration: Int?  // in days
    let difficulty: DifficultyLevel
    let category: GoalCategory
    let generatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        goalType: String,
        targetValue: Double? = nil,
        targetUnit: String? = nil,
        rationale: String,
        estimatedDuration: Int? = nil,
        difficulty: DifficultyLevel = .moderate,
        category: GoalCategory = .general,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.goalType = goalType
        self.targetValue = targetValue
        self.targetUnit = targetUnit
        self.rationale = rationale
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.category = category
        self.generatedAt = generatedAt
    }

    /// Duration formatted as text
    var durationText: String {
        guard let duration = estimatedDuration else { return "Ongoing" }

        if duration < 7 {
            return "\(duration) day\(duration > 1 ? "s" : "")"
        } else if duration < 30 {
            let weeks = duration / 7
            return "\(weeks) week\(weeks > 1 ? "s" : "")"
        } else {
            let months = duration / 30
            return "\(months) month\(months > 1 ? "s" : "")"
        }
    }

    /// Target date based on estimated duration
    var estimatedTargetDate: Date? {
        guard let duration = estimatedDuration else { return nil }
        return Calendar.current.date(byAdding: .day, value: duration, to: Date())
    }

    /// Format target value with unit for display
    var formattedTarget: String? {
        guard let value = targetValue else { return nil }
        let unit = targetUnit ?? ""
        return String(format: "%.0f %@", value, unit).trimmingCharacters(in: .whitespaces)
    }

    /// Convert suggestion to a Goal entity
    func toGoal(userId: UUID) -> Goal {
        Goal(
            id: UUID(),
            userId: userId,
            title: title,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            targetDate: estimatedTargetDate,
            progress: 0.0,
            status: .active,
            category: category
        )
    }
}

/// Difficulty level for goal suggestions
enum DifficultyLevel: Int, Codable, CaseIterable, Equatable {
    case veryEasy = 1
    case easy = 2
    case moderate = 3
    case challenging = 4
    case veryChallenging = 5

    var displayName: String {
        switch self {
        case .veryEasy:
            return "Very Easy"
        case .easy:
            return "Easy"
        case .moderate:
            return "Moderate"
        case .challenging:
            return "Challenging"
        case .veryChallenging:
            return "Very Challenging"
        }
    }

    var systemImage: String {
        switch self {
        case .veryEasy:
            return "1.circle.fill"
        case .easy:
            return "2.circle.fill"
        case .moderate:
            return "3.circle.fill"
        case .challenging:
            return "4.circle.fill"
        case .veryChallenging:
            return "5.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .veryEasy, .easy:
            return "moodPositive"
        case .moderate:
            return "moodNeutral"
        case .challenging, .veryChallenging:
            return "moodLow"
        }
    }

    var colorHex: String {
        switch self {
        case .veryEasy, .easy:
            return "#F5DFA8"  // Mood positive (happy yellow)
        case .moderate:
            return "#D8E8C8"  // Mood neutral (sage green)
        case .challenging, .veryChallenging:
            return "#F0B8A4"  // Mood low (soft coral)
        }
    }

    init(from difficulty: Int) {
        switch difficulty {
        case 1:
            self = .veryEasy
        case 2:
            self = .easy
        case 3:
            self = .moderate
        case 4:
            self = .challenging
        case 5:
            self = .veryChallenging
        default:
            self = .moderate
        }
    }
}

/// Represents a tip for achieving a goal
struct GoalTip: Identifiable, Codable, Equatable {
    let id: UUID
    let tip: String
    let category: TipCategory
    let priority: TipPriority

    init(
        id: UUID = UUID(),
        tip: String,
        category: TipCategory = .general,
        priority: TipPriority = .medium
    ) {
        self.id = id
        self.tip = tip
        self.category = category
        self.priority = priority
    }
}

/// Category for goal tips
enum TipCategory: String, Codable, CaseIterable, Equatable {
    case general = "general"
    case nutrition = "nutrition"
    case exercise = "exercise"
    case sleep = "sleep"
    case mindset = "mindset"
    case habit = "habit"

    var displayName: String {
        switch self {
        case .general:
            return "General"
        case .nutrition:
            return "Nutrition"
        case .exercise:
            return "Exercise"
        case .sleep:
            return "Sleep"
        case .mindset:
            return "Mindset"
        case .habit:
            return "Habit"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "lightbulb.fill"
        case .nutrition:
            return "fork.knife"
        case .exercise:
            return "figure.run"
        case .sleep:
            return "bed.double.fill"
        case .mindset:
            return "brain.head.profile"
        case .habit:
            return "repeat"
        }
    }

    var color: String {
        switch self {
        case .general:
            return "accentPrimary"
        case .nutrition:
            return "moodPositive"
        case .exercise:
            return "moodLow"
        case .sleep:
            return "accentSecondary"
        case .mindset:
            return "accentPrimary"
        case .habit:
            return "moodNeutral"
        }
    }
}

/// Priority level for goal tips
enum TipPriority: String, Codable, CaseIterable, Equatable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high:
            return "High Priority"
        case .medium:
            return "Medium Priority"
        case .low:
            return "Low Priority"
        }
    }

    var systemImage: String {
        switch self {
        case .high:
            return "exclamationmark.circle.fill"
        case .medium:
            return "circle.fill"
        case .low:
            return "circle"
        }
    }

    var color: String {
        switch self {
        case .high:
            return "moodLow"
        case .medium:
            return "moodNeutral"
        case .low:
            return "moodPositive"
        }
    }

    var level: Int {
        switch self {
        case .high:
            return 3
        case .medium:
            return 2
        case .low:
            return 1
        }
    }
}
