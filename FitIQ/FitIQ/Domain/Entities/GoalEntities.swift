//
//  GoalEntities.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation

enum GoalSource: String, Codable {
    case declarative // Added by user via the Goal Settings View
    case aiTriage    // Derived from the "I'm not sure" chat flow
    case professional // Confirmed/set by a human specialist
}

struct TriageGoal: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    /// The Set of ConsultantTypes required to fulfill this goal.
    let mappedTypes: Set<ConsultantType>
    
    // NEW PROPERTIES ADDED:
    var targetValue: Double? // For declarative goals like "lose 5kg"
    var unit: String? // e.g., "kg", "times/week"
    var targetDate: Date? // e.g., "by Christmas"
    
    let source: GoalSource
    
    // Custom initializer to include new properties, making them optional for existing usage
    init(
        id: UUID = UUID(), title: String,
        mappedTypes: Set<ConsultantType>, targetValue: Double? = nil,
        unit: String? = nil, targetDate: Date? = nil,
        source: GoalSource
    ) {
        self.id = id
        self.title = title
        self.mappedTypes = mappedTypes
        self.targetValue = targetValue
        self.unit = unit
        self.targetDate = targetDate
        self.source = source
    }
}

extension TriageGoal {
    static let allGoals: [TriageGoal] = [
        // Existing goals updated to use the new initializer with default (nil) values
        TriageGoal(title: "Improve my diet and lose weight.", mappedTypes: [.nutritionist], source: .declarative),
        TriageGoal(title: "Get stronger or build muscle.", mappedTypes: [.fitnessCoach], source: .aiTriage),
        TriageGoal(title: "Reduce stress and improve sleep.", mappedTypes: [.wellness], source: .professional),
        TriageGoal(title: "Have more energy for my daily life.", mappedTypes: [.wellness, .nutritionist], source: .declarative),
        TriageGoal(title: "Prepare for a specific event (e.g., marathon).", mappedTypes: [.fitnessCoach, .nutritionist], source: .aiTriage)
    ]
}

