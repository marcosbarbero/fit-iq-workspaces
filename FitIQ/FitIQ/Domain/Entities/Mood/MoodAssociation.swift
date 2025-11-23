//
//  MoodAssociation.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of HKStateOfMind Mood Tracking Integration
//

import Foundation
import HealthKit

/// Mood association representing contextual factors
/// Mirrors HKStateOfMind.Association for iOS 18+ compatibility
///
/// Associations help track what areas of life are influencing mood,
/// enabling deeper insights into mood patterns and triggers.
enum MoodAssociation: String, Codable, CaseIterable, Sendable {
    // MARK: - Social & Relationships

    /// Community involvement or social groups
    case community

    /// Dating or romantic interests
    case dating

    /// Family relationships
    case family

    /// Friends and friendships
    case friends

    /// Romantic partner relationship
    case partner

    // MARK: - Work & Education

    /// Educational activities or studies
    case education

    /// Work or career-related matters
    case work

    /// Tasks, chores, or responsibilities
    case tasks

    // MARK: - Health & Wellness

    /// Physical or mental health concerns
    case health

    /// Fitness or exercise activities
    case fitness

    /// Self-care activities
    case selfCare

    // MARK: - Personal & Identity

    /// Personal identity or self-concept
    case identity

    /// Spiritual or religious matters
    case spirituality

    /// Hobbies or leisure activities
    case hobbies

    // MARK: - External Factors

    /// Current events or news
    case currentEvents

    /// Financial matters
    case money

    /// Travel or being away from home
    case travel

    /// Weather conditions
    case weather

    // MARK: - Computed Properties

    /// Returns the display name for the association
    var displayName: String {
        switch self {
        case .community: return "Community"
        case .currentEvents: return "Current Events"
        case .dating: return "Dating"
        case .education: return "Education"
        case .family: return "Family"
        case .fitness: return "Fitness"
        case .friends: return "Friends"
        case .health: return "Health"
        case .hobbies: return "Hobbies"
        case .identity: return "Identity"
        case .money: return "Money"
        case .partner: return "Partner"
        case .selfCare: return "Self Care"
        case .spirituality: return "Spirituality"
        case .tasks: return "Tasks"
        case .travel: return "Travel"
        case .weather: return "Weather"
        case .work: return "Work"
        }
    }

    /// Returns an SF Symbol name for the association (for UI)
    var symbolName: String {
        switch self {
        case .community: return "person.3.fill"
        case .currentEvents: return "newspaper.fill"
        case .dating: return "heart.circle.fill"
        case .education: return "graduationcap.fill"
        case .family: return "house.fill"
        case .fitness: return "figure.run"
        case .friends: return "person.2.fill"
        case .health: return "cross.case.fill"
        case .hobbies: return "paintpalette.fill"
        case .identity: return "person.fill.questionmark"
        case .money: return "dollarsign.circle.fill"
        case .partner: return "heart.fill"
        case .selfCare: return "sparkles"
        case .spirituality: return "leaf.fill"
        case .tasks: return "checklist"
        case .travel: return "airplane"
        case .weather: return "cloud.sun.fill"
        case .work: return "briefcase.fill"
        }
    }

    /// Returns the category for grouping associations
    var category: AssociationCategory {
        switch self {
        case .community, .dating, .family, .friends, .partner:
            return .social
        case .education, .work, .tasks:
            return .workAndEducation
        case .health, .fitness, .selfCare:
            return .healthAndWellness
        case .identity, .spirituality, .hobbies:
            return .personal
        case .currentEvents, .money, .travel, .weather:
            return .external
        }
    }

    // MARK: - iOS 18+ HealthKit Conversion

    /// Converts to HKStateOfMind.Association (iOS 18+)
    @available(iOS 18.0, *)
    var toHealthKit: HKStateOfMind.Association? {
        switch self {
        case .community: return .community
        case .currentEvents: return .currentEvents
        case .dating: return .dating
        case .education: return .education
        case .family: return .family
        case .fitness: return .fitness
        case .friends: return .friends
        case .health: return .health
        case .hobbies: return .hobbies
        case .identity: return .identity
        case .money: return .money
        case .partner: return .partner
        case .selfCare: return .selfCare
        case .spirituality: return .spirituality
        case .tasks: return .tasks
        case .travel: return .travel
        case .weather: return .weather
        case .work: return .work
        }
    }

    /// Creates MoodAssociation from HKStateOfMind.Association (iOS 18+)
    @available(iOS 18.0, *)
    static func from(healthKit association: HKStateOfMind.Association) -> MoodAssociation? {
        switch association {
        case .community: return .community
        case .currentEvents: return .currentEvents
        case .dating: return .dating
        case .education: return .education
        case .family: return .family
        case .fitness: return .fitness
        case .friends: return .friends
        case .health: return .health
        case .hobbies: return .hobbies
        case .identity: return .identity
        case .money: return .money
        case .partner: return .partner
        case .selfCare: return .selfCare
        case .spirituality: return .spirituality
        case .tasks: return .tasks
        case .travel: return .travel
        case .weather: return .weather
        case .work: return .work
        @unknown default: return nil
        }
    }

    // MARK: - Grouping Helpers

    /// Returns all associations in the social category
    static var socialAssociations: [MoodAssociation] {
        return allCases.filter { $0.category == .social }
    }

    /// Returns all associations in the work/education category
    static var workAndEducationAssociations: [MoodAssociation] {
        return allCases.filter { $0.category == .workAndEducation }
    }

    /// Returns all associations in the health/wellness category
    static var healthAndWellnessAssociations: [MoodAssociation] {
        return allCases.filter { $0.category == .healthAndWellness }
    }

    /// Returns all associations in the personal category
    static var personalAssociations: [MoodAssociation] {
        return allCases.filter { $0.category == .personal }
    }

    /// Returns all associations in the external category
    static var externalAssociations: [MoodAssociation] {
        return allCases.filter { $0.category == .external }
    }
}

// MARK: - Association Category

/// Category for grouping related associations
enum AssociationCategory: String, Codable, Hashable {
    case social
    case workAndEducation
    case healthAndWellness
    case personal
    case external

    var displayName: String {
        switch self {
        case .social: return "Social & Relationships"
        case .workAndEducation: return "Work & Education"
        case .healthAndWellness: return "Health & Wellness"
        case .personal: return "Personal & Identity"
        case .external: return "External Factors"
        }
    }

    var symbolName: String {
        switch self {
        case .social: return "person.2.fill"
        case .workAndEducation: return "briefcase.fill"
        case .healthAndWellness: return "heart.fill"
        case .personal: return "person.fill"
        case .external: return "globe"
        }
    }
}

// MARK: - Extensions

extension Array where Element == MoodAssociation {
    /// Groups associations by category
    var groupedByCategory: [AssociationCategory: [MoodAssociation]] {
        return Dictionary(grouping: self) { $0.category }
    }

    /// Returns all unique categories represented in the array
    var categories: [AssociationCategory] {
        let uniqueCategories = Set(self.map { $0.category })
        return uniqueCategories.sorted { $0.displayName < $1.displayName }
    }
}
