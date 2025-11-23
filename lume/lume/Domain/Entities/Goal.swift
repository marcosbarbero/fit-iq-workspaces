//
//  Goal.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation

/// Represents a wellness goal with AI consulting support
struct Goal: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    var title: String
    var description: String
    let createdAt: Date
    var updatedAt: Date
    var targetDate: Date?
    var progress: Double  // 0.0 to 1.0 (calculated from current_value / target_value)
    var status: GoalStatus
    var category: GoalCategory
    var targetValue: Double  // Required by backend
    var targetUnit: String  // Required by backend (kg, steps, minutes, servings, etc.)
    var currentValue: Double  // Current progress value
    var backendId: String?  // Backend goal ID for API sync

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        description: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetDate: Date? = nil,
        progress: Double = 0.0,
        status: GoalStatus = .active,
        category: GoalCategory = .general,
        targetValue: Double = 1.0,
        targetUnit: String = "completion",
        currentValue: Double = 0.0,
        backendId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetDate = targetDate
        self.progress = min(max(progress, 0.0), 1.0)  // Clamp between 0 and 1
        self.status = status
        self.category = category
        self.targetValue = max(targetValue, 0.01)  // Must be > 0 for backend
        self.targetUnit = targetUnit
        self.currentValue = currentValue
        self.backendId = backendId
    }

    /// Check if the goal is complete
    var isComplete: Bool {
        progress >= 1.0 || status == .completed
    }

    /// Check if the goal has a target date
    var hasTargetDate: Bool {
        targetDate != nil
    }

    /// Check if the goal is overdue
    var isOverdue: Bool {
        guard let target = targetDate else { return false }
        return Date() > target && !isComplete
    }

    /// Days remaining until target date (nil if no target date)
    var daysRemaining: Int? {
        guard let target = targetDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: target)
        return components.day
    }

    /// Progress as a percentage (0-100)
    var progressPercentage: Int {
        Int(progress * 100)
    }

    /// Calculate progress from current and target values
    var calculatedProgress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }

    /// Format current value with unit for display
    var formattedCurrentValue: String {
        formatValue(currentValue)
    }

    /// Format target value with unit for display
    var formattedTargetValue: String {
        formatValue(targetValue)
    }

    private func formatValue(_ value: Double) -> String {
        let formatted =
            value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formatted) \(targetUnit)"
    }

    /// Format target date for display
    var formattedTargetDate: String? {
        guard let target = targetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: target)
    }
}

/// Status of a goal
enum GoalStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case archived = "archived"

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .paused:
            return "Paused"
        case .archived:
            return "Archived"
        }
    }

    var systemImage: String {
        switch self {
        case .active:
            return "target"
        case .completed:
            return "checkmark.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .archived:
            return "archivebox.fill"
        }
    }
}

/// Category of a goal for organization
enum GoalCategory: String, Codable, CaseIterable {
    case general = "general"
    case physical = "physical"
    case mental = "mental"
    case emotional = "emotional"
    case social = "social"
    case spiritual = "spiritual"
    case professional = "professional"

    var displayName: String {
        switch self {
        case .general:
            return "General"
        case .physical:
            return "Physical Health"
        case .mental:
            return "Mental Health"
        case .emotional:
            return "Emotional Well-being"
        case .social:
            return "Social Connection"
        case .spiritual:
            return "Spiritual Growth"
        case .professional:
            return "Professional Development"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "star.fill"
        case .physical:
            return "figure.walk"
        case .mental:
            return "brain.head.profile"
        case .emotional:
            return "heart.fill"
        case .social:
            return "person.2.fill"
        case .spiritual:
            return "sparkles"
        case .professional:
            return "briefcase.fill"
        }
    }

    var color: String {
        switch self {
        case .general:
            return "accentPrimary"
        case .physical:
            return "moodPositive"
        case .mental:
            return "accentSecondary"
        case .emotional:
            return "moodLow"
        case .social:
            return "accentPrimary"
        case .spiritual:
            return "accentSecondary"
        case .professional:
            return "textPrimary"
        }
    }

    /// Alias for systemImage for consistency with other views
    var icon: String {
        return systemImage
    }

    /// Hex color codes for the category
    var colorHex: String {
        switch self {
        case .general:
            return "#F2C9A7"  // Primary Accent
        case .physical:
            return "#F5DFA8"  // Mood Positive (Happy yellow)
        case .mental:
            return "#D8C8EA"  // Secondary Accent (purple)
        case .emotional:
            return "#FFD4E5"  // Grateful (light rose)
        case .social:
            return "#B8E8D4"  // Hopeful (light mint)
        case .spiritual:
            return "#E8D4F0"  // Amazed (light purple)
        case .professional:
            return "#3B332C"  // Primary Text
        }
    }
}
