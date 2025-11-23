//
//  MoodLabel.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of HKStateOfMind Mood Tracking Integration
//

import Foundation
import HealthKit

/// Mood label representing emotional state
/// Mirrors HKStateOfMind.Label for iOS 18+ compatibility
///
/// Labels are categorized by valence (pleasant/unpleasant/neutral)
/// and provide descriptive context for mood entries.
enum MoodLabel: String, Codable, CaseIterable, Sendable {
    // MARK: - Unpleasant Labels (Negative Valence)

    /// Feeling angry or hostile
    case angry

    /// Feeling annoyed or bothered
    case annoyed

    /// Feeling anxious or nervous
    case anxious

    /// Feeling ashamed or embarrassed about oneself
    case ashamed

    /// Feeling drained or exhausted
    case drained

    /// Feeling embarrassed or self-conscious
    case embarrassed

    /// Feeling frustrated or blocked
    case frustrated

    /// Feeling guilty or regretful
    case guilty

    /// Feeling irritated or agitated
    case irritated

    /// Feeling lonely or isolated
    case lonely

    /// Feeling overwhelmed or overloaded
    case overwhelmed

    /// Feeling sad or down
    case sad

    /// Feeling scared or afraid
    case scared

    /// Feeling stressed or under pressure
    case stressed

    /// Feeling worried or concerned
    case worried

    // MARK: - Neutral Labels

    /// Feeling calm or tranquil
    case calm

    /// Feeling content or satisfied
    case content

    /// Feeling indifferent or neutral
    case indifferent

    // MARK: - Pleasant Labels (Positive Valence)

    /// Feeling amazed or in awe
    case amazed

    /// Feeling amused or entertained
    case amused

    /// Feeling confident or self-assured
    case confident

    /// Feeling excited or enthusiastic
    case excited

    /// Feeling grateful or thankful
    case grateful

    /// Feeling happy or joyful
    case happy

    /// Feeling hopeful or optimistic
    case hopeful

    /// Feeling passionate or intense
    case passionate

    /// Feeling peaceful or serene
    case peaceful

    /// Feeling proud or accomplished
    case proud

    /// Feeling relaxed or at ease
    case relaxed

    /// Feeling surprised (can be positive or negative depending on context)
    case surprised

    // MARK: - Computed Properties

    /// Returns the typical valence category for this label
    var valenceCategory: ValenceCategory {
        switch self {
        // Unpleasant
        case .angry, .annoyed, .anxious, .ashamed, .drained, .embarrassed,
            .frustrated, .guilty, .irritated, .lonely, .overwhelmed,
            .sad, .scared, .stressed, .worried:
            return .unpleasant

        // Neutral
        case .calm, .content, .indifferent:
            return .neutral

        // Pleasant
        case .amazed, .amused, .confident, .excited, .grateful, .happy,
            .hopeful, .passionate, .peaceful, .proud, .relaxed:
            return .pleasant

        // Context-dependent
        case .surprised:
            return .neutral
        }
    }

    /// Returns the display name for the label
    var displayName: String {
        return rawValue.capitalized
    }

    /// Returns an SF Symbol name for the label (for UI)
    var symbolName: String {
        switch self {
        case .angry: return "flame.fill"
        case .annoyed: return "exclamationmark.bubble.fill"
        case .anxious: return "tornado"
        case .ashamed: return "eye.slash.fill"
        case .drained: return "battery.0"
        case .embarrassed: return "face.smiling.inverse"
        case .frustrated: return "xmark.circle.fill"
        case .guilty: return "hand.raised.fill"
        case .irritated: return "exclamationmark.triangle.fill"
        case .lonely: return "person.fill.xmark"
        case .overwhelmed: return "square.stack.3d.up.fill"
        case .sad: return "cloud.rain.fill"
        case .scared: return "exclamationmark.shield.fill"
        case .stressed: return "bolt.fill"
        case .worried: return "cloud.fill"
        case .calm: return "leaf.fill"
        case .content: return "checkmark.circle.fill"
        case .indifferent: return "minus.circle.fill"
        case .amazed: return "sparkles"
        case .amused: return "face.smiling.fill"
        case .confident: return "hand.thumbsup.fill"
        case .excited: return "star.fill"
        case .grateful: return "heart.fill"
        case .happy: return "sun.max.fill"
        case .hopeful: return "sunrise.fill"
        case .passionate: return "flame.fill"
        case .peaceful: return "moon.stars.fill"
        case .proud: return "trophy.fill"
        case .relaxed: return "figure.mind.and.body"
        case .surprised: return "exclamationmark.circle.fill"
        }
    }

    /// Returns a suggested color for the label
    var suggestedColorName: String {
        switch valenceCategory {
        case .unpleasant: return "red"
        case .neutral: return "gray"
        case .pleasant: return "green"
        }
    }

    // MARK: - iOS 18+ HealthKit Conversion

    /// Converts to HKStateOfMind.Label (iOS 18+)
    @available(iOS 18.0, *)
    var toHealthKit: HKStateOfMind.Label? {
        switch self {
        case .angry: return .angry
        case .annoyed: return .annoyed
        case .anxious: return .anxious
        case .ashamed: return .ashamed
        case .drained: return .drained
        case .embarrassed: return .embarrassed
        case .frustrated: return .frustrated
        case .guilty: return .guilty
        case .irritated: return .irritated
        case .lonely: return .lonely
        case .overwhelmed: return .overwhelmed
        case .sad: return .sad
        case .scared: return .scared
        case .stressed: return .stressed
        case .worried: return .worried
        case .calm: return .calm
        case .content: return .content
        case .indifferent: return .indifferent
        case .amazed: return .amazed
        case .amused: return .amused
        case .confident: return .confident
        case .excited: return .excited
        case .grateful: return .grateful
        case .happy: return .happy
        case .hopeful: return .hopeful
        case .passionate: return .passionate
        case .peaceful: return .peaceful
        case .proud: return .proud
        case .relaxed: return .calm  // HealthKit doesn't have .relaxed, map to .calm
        case .surprised: return .surprised
        }
    }

    /// Creates MoodLabel from HKStateOfMind.Label (iOS 18+)
    @available(iOS 18.0, *)
    static func from(healthKit label: HKStateOfMind.Label) -> MoodLabel? {
        switch label {
        case .angry: return .angry
        case .annoyed: return .annoyed
        case .anxious: return .anxious
        case .ashamed: return .ashamed
        case .drained: return .drained
        case .embarrassed: return .embarrassed
        case .frustrated: return .frustrated
        case .guilty: return .guilty
        case .irritated: return .irritated
        case .lonely: return .lonely
        case .overwhelmed: return .overwhelmed
        case .sad: return .sad
        case .scared: return .scared
        case .stressed: return .stressed
        case .worried: return .worried
        case .calm: return .calm
        case .content: return .content
        case .indifferent: return .indifferent
        case .amazed: return .amazed
        case .amused: return .amused
        case .confident: return .confident
        case .excited: return .excited
        case .grateful: return .grateful
        case .happy: return .happy
        case .hopeful: return .hopeful
        case .passionate: return .passionate
        case .peaceful: return .peaceful
        case .proud: return .proud
        // Note: HealthKit doesn't have .relaxed, so .calm maps to both calm and relaxed
        case .surprised: return .surprised
        @unknown default: return nil
        }
    }

    // MARK: - Grouping Helpers

    /// Returns all labels in the unpleasant category
    static var unpleasantLabels: [MoodLabel] {
        return allCases.filter { $0.valenceCategory == .unpleasant }
    }

    /// Returns all labels in the neutral category
    static var neutralLabels: [MoodLabel] {
        return allCases.filter { $0.valenceCategory == .neutral }
    }

    /// Returns all labels in the pleasant category
    static var pleasantLabels: [MoodLabel] {
        return allCases.filter { $0.valenceCategory == .pleasant }
    }
}

// MARK: - Valence Category

/// Category representing the general emotional valence
enum ValenceCategory: String, Codable {
    case unpleasant
    case neutral
    case pleasant

    var displayName: String {
        switch self {
        case .unpleasant: return "Unpleasant"
        case .neutral: return "Neutral"
        case .pleasant: return "Pleasant"
        }
    }
}

// MARK: - Extensions

extension Array where Element == MoodLabel {
    /// Calculates the average valence tendency of the labels
    var averageValenceTendency: Double {
        guard !isEmpty else { return 0.0 }

        let valenceMappings: [ValenceCategory: Double] = [
            .unpleasant: -0.7,
            .neutral: 0.0,
            .pleasant: 0.7,
        ]

        let sum = self.reduce(0.0) { sum, label in
            sum + (valenceMappings[label.valenceCategory] ?? 0.0)
        }

        return sum / Double(count)
    }

    /// Returns the dominant valence category
    var dominantValenceCategory: ValenceCategory? {
        guard !isEmpty else { return nil }

        let grouped = Dictionary(grouping: self) { $0.valenceCategory }
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }
}
