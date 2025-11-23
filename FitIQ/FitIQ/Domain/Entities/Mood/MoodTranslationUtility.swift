//
//  MoodTranslationUtility.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of HKStateOfMind Mood Tracking Integration
//
//  ⚠️ DEPRECATED: This file is part of the old complex mood tracking implementation.
//  Use SaveMoodProgressUseCase instead for new mood entries.
//  This file is kept for backward compatibility only.
//

import Foundation
import HealthKit

/// Utility for translating between 1-10 mood scores and HKStateOfMind representations
///
/// Provides bidirectional translation between:
/// - Simple 1-10 numeric scale (for backend API compatibility)
/// - Rich HKStateOfMind data (valence + labels + associations)
///
/// **Translation Formulas:**
/// - Score → Valence: `(score - 1) / 4.5 - 1.0`
/// - Valence → Score: `round((valence + 1.0) * 4.5 + 1.0)`
enum MoodTranslationUtility {

    // MARK: - Score ↔ Valence Conversion

    /// Converts 1-10 score to valence (-1.0 to +1.0)
    ///
    /// - Parameter score: Mood score (1-10)
    /// - Returns: Valence value (-1.0 to +1.0)
    ///
    /// **Examples:**
    /// - Score 1 → Valence -1.0 (very unpleasant)
    /// - Score 5 → Valence -0.11 (slightly unpleasant)
    /// - Score 6 → Valence +0.11 (slightly pleasant)
    /// - Score 10 → Valence +1.0 (very pleasant)
    static func scoreToValence(_ score: Int) -> Double {
        // Formula: valence = (score - 1) / 4.5 - 1.0
        let valence = (Double(score) - 1.0) / 4.5 - 1.0
        return max(-1.0, min(1.0, valence))  // Clamp to valid range
    }

    /// Converts valence (-1.0 to +1.0) to 1-10 score
    ///
    /// - Parameter valence: Valence value (-1.0 to +1.0)
    /// - Returns: Mood score (1-10)
    ///
    /// **Examples:**
    /// - Valence -1.0 → Score 1 (very unpleasant)
    /// - Valence -0.11 → Score 5 (slightly unpleasant)
    /// - Valence +0.11 → Score 6 (slightly pleasant)
    /// - Valence +1.0 → Score 10 (very pleasant)
    static func valenceToScore(_ valence: Double) -> Int {
        // Formula: score = round((valence + 1.0) * 4.5 + 1.0)
        let rawScore = (valence + 1.0) * 4.5 + 1.0
        let roundedScore = Int(round(rawScore))
        return max(1, min(10, roundedScore))  // Clamp to valid range
    }

    // MARK: - Score → Labels (Smart Selection)

    /// Selects appropriate mood labels based on score
    ///
    /// - Parameters:
    ///   - score: Mood score (1-10)
    ///   - notes: Optional user notes to refine label selection
    /// - Returns: Array of suggested mood labels
    ///
    /// **Label Selection Strategy:**
    /// - Score 1-2: Strong unpleasant labels (sad, depressed, lonely)
    /// - Score 3-4: Moderate unpleasant labels (frustrated, anxious)
    /// - Score 5-6: Neutral labels (calm, content)
    /// - Score 7-8: Moderate pleasant labels (happy, confident)
    /// - Score 9-10: Strong pleasant labels (excited, passionate, grateful)
    static func labelsForScore(_ score: Int, notes: String? = nil) -> [MoodLabel] {
        var labels: [MoodLabel] = []
        let notesLower = notes?.lowercased() ?? ""

        switch score {
        case 1:
            labels = [.sad]
            if notesLower.contains("lonely") || notesLower.contains("alone") {
                labels.append(.lonely)
            } else if notesLower.contains("drain") || notesLower.contains("exhaust") {
                labels.append(.drained)
            } else {
                labels.append(.overwhelmed)
            }

        case 2:
            labels = [.anxious, .worried]
            if notesLower.contains("stress") {
                labels.append(.stressed)
            } else if notesLower.contains("scare") || notesLower.contains("afraid") {
                labels.append(.scared)
            }

        case 3:
            labels = [.frustrated]
            if notesLower.contains("annoy") {
                labels.append(.annoyed)
            } else if notesLower.contains("overwhelm") {
                labels.append(.overwhelmed)
            } else {
                labels.append(.irritated)
            }

        case 4:
            labels = [.irritated]
            if notesLower.contains("worry") || notesLower.contains("worried") {
                labels.append(.worried)
            } else if notesLower.contains("stress") {
                labels.append(.stressed)
            } else {
                labels.append(.annoyed)
            }

        case 5:
            labels = [.calm]
            if notesLower.contains("content") {
                labels.append(.content)
            } else if notesLower.contains("indifferent") || notesLower.contains("neutral") {
                labels.append(.indifferent)
            } else {
                labels.append(.content)
            }

        case 6:
            labels = [.content]
            if notesLower.contains("peace") || notesLower.contains("peaceful") {
                labels.append(.peaceful)
            } else if notesLower.contains("calm") {
                labels.append(.calm)
            } else {
                labels.append(.peaceful)
            }

        case 7:
            labels = [.happy]
            if notesLower.contains("peace") || notesLower.contains("peaceful") {
                labels.append(.peaceful)
            } else if notesLower.contains("relax") {
                labels.append(.relaxed)
            } else {
                labels.append(.peaceful)
            }

        case 8:
            labels = [.happy]
            if notesLower.contains("confid") {
                labels.append(.confident)
            } else if notesLower.contains("excit") {
                labels.append(.excited)
            } else if notesLower.contains("grat") {
                labels.append(.grateful)
            } else {
                labels.append(.confident)
            }

        case 9:
            labels = [.excited]
            if notesLower.contains("grat") || notesLower.contains("thank") {
                labels.append(.grateful)
            } else if notesLower.contains("proud") {
                labels.append(.proud)
            } else if notesLower.contains("hope") {
                labels.append(.hopeful)
            } else {
                labels.append(.grateful)
            }

        case 10:
            labels = [.passionate]
            if notesLower.contains("amaz") {
                labels.append(.amazed)
            } else if notesLower.contains("hope") {
                labels.append(.hopeful)
            } else if notesLower.contains("proud") {
                labels.append(.proud)
            } else {
                labels.append(.hopeful)
            }

        default:
            labels = [.content]
        }

        return labels
    }

    // MARK: - Labels → Score Adjustment

    /// Adjusts base score based on label sentiment
    ///
    /// Refines the score calculated from valence by considering the emotional
    /// intensity indicated by the labels.
    ///
    /// - Parameters:
    ///   - baseScore: Score calculated from valence
    ///   - labels: Mood labels from HKStateOfMind
    /// - Returns: Adjusted score (1-10)
    static func adjustScoreForLabels(baseScore: Int, labels: [MoodLabel]) -> Int {
        guard !labels.isEmpty else { return baseScore }

        // Define strongly negative labels (should pull score down)
        let stronglyNegative: Set<MoodLabel> = [
            .sad, .overwhelmed, .ashamed, .scared, .lonely, .drained,
        ]

        // Define strongly positive labels (should pull score up)
        let stronglyPositive: Set<MoodLabel> = [
            .passionate, .grateful, .proud, .hopeful, .excited, .amazed,
        ]

        let hasStronglyNegative = labels.contains(where: stronglyNegative.contains)
        let hasStronglyPositive = labels.contains(where: stronglyPositive.contains)

        var adjustedScore = baseScore

        if hasStronglyNegative && baseScore > 3 {
            adjustedScore -= 1  // Pull down if labels indicate stronger negativity
        } else if hasStronglyPositive && baseScore < 8 {
            adjustedScore += 1  // Pull up if labels indicate stronger positivity
        }

        return max(1, min(10, adjustedScore))
    }

    // MARK: - Notes → Associations (Smart Inference)

    /// Infers contextual associations from user notes
    ///
    /// Analyzes user notes for keywords that suggest contextual factors
    /// influencing the mood.
    ///
    /// - Parameter notes: User notes text
    /// - Returns: Array of inferred associations
    ///
    /// **Examples:**
    /// - "Great workout today!" → [.fitness]
    /// - "Stressful day at work" → [.work]
    /// - "Lovely time with friends" → [.friends]
    static func associationsFromNotes(_ notes: String?) -> [MoodAssociation] {
        guard let notes = notes, !notes.isEmpty else { return [] }

        var associations: [MoodAssociation] = []
        let notesLower = notes.lowercased()

        // Social & Relationships
        if notesLower.contains("family") || notesLower.contains("parent")
            || notesLower.contains("sibling")
        {
            associations.append(.family)
        }
        if notesLower.contains("friend") || notesLower.contains("social") {
            associations.append(.friends)
        }
        if notesLower.contains("partner") || notesLower.contains("spouse")
            || notesLower.contains("relationship")
        {
            associations.append(.partner)
        }
        if notesLower.contains("date") || notesLower.contains("dating") {
            associations.append(.dating)
        }
        if notesLower.contains("community") || notesLower.contains("group") {
            associations.append(.community)
        }

        // Work & Education
        if notesLower.contains("work") || notesLower.contains("job")
            || notesLower.contains("office") || notesLower.contains("career")
        {
            associations.append(.work)
        }
        if notesLower.contains("school") || notesLower.contains("study")
            || notesLower.contains("class") || notesLower.contains("exam")
        {
            associations.append(.education)
        }
        if notesLower.contains("task") || notesLower.contains("chore")
            || notesLower.contains("todo")
        {
            associations.append(.tasks)
        }

        // Health & Wellness
        if notesLower.contains("workout") || notesLower.contains("exercise")
            || notesLower.contains("gym") || notesLower.contains("run")
            || notesLower.contains("fitness")
        {
            associations.append(.fitness)
        }
        if notesLower.contains("health") || notesLower.contains("doctor")
            || notesLower.contains("sick") || notesLower.contains("pain")
        {
            associations.append(.health)
        }
        if notesLower.contains("self-care") || notesLower.contains("self care")
            || notesLower.contains("meditation") || notesLower.contains("relax")
        {
            associations.append(.selfCare)
        }

        // Personal & Identity
        if notesLower.contains("hobby") || notesLower.contains("hobbies")
            || notesLower.contains("interest")
        {
            associations.append(.hobbies)
        }
        if notesLower.contains("spiritual") || notesLower.contains("pray")
            || notesLower.contains("faith") || notesLower.contains("religion")
        {
            associations.append(.spirituality)
        }
        if notesLower.contains("identity") || notesLower.contains("myself")
            || notesLower.contains("who i am")
        {
            associations.append(.identity)
        }

        // External Factors
        if notesLower.contains("weather") || notesLower.contains("rain")
            || notesLower.contains("sunny") || notesLower.contains("cold")
        {
            associations.append(.weather)
        }
        if notesLower.contains("money") || notesLower.contains("financial")
            || notesLower.contains("budget") || notesLower.contains("expense")
        {
            associations.append(.money)
        }
        if notesLower.contains("travel") || notesLower.contains("trip")
            || notesLower.contains("vacation")
        {
            associations.append(.travel)
        }
        if notesLower.contains("news") || notesLower.contains("current events")
            || notesLower.contains("politics")
        {
            associations.append(.currentEvents)
        }

        return associations
    }

    // MARK: - Complete Translations

    /// Creates a complete MoodEntry from a 1-10 score
    ///
    /// Generates valence, labels, and associations from the score and notes.
    /// Creates a MoodEntry from user input
    ///
    /// ⚠️ DEPRECATED: Use SaveMoodProgressUseCase instead
    ///
    /// - Parameters:
    ///   - score: Mood score (1-10)
    ///   - notes: Optional notes
    ///   - userID: User ID
    ///   - date: Date of the mood entry
    /// - Returns: Complete MoodEntry with all fields populated
    @available(*, deprecated, message: "Use SaveMoodProgressUseCase instead")
    static func createMoodEntry(
        score: Int,
        notes: String?,
        userID: String,
        date: Date = Date()
    ) -> MoodEntry {
        // Convert old labels to new emotion strings (simplified)
        let labels = labelsForScore(score, notes: notes)
        let emotions = labels.prefix(3).map { $0.rawValue }  // Take first 3 labels as emotions

        return MoodEntry(
            id: UUID(),
            userID: userID,
            date: date,
            score: score,
            emotions: Array(emotions),
            notes: notes,
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending
        )
    }

    /// Creates a MoodEntry from HKStateOfMind (iOS 18+)
    ///
    /// ⚠️ DEPRECATED: HealthKit integration removed from simplified model
    ///
    /// Converts HealthKit mood data to app's domain model.
    ///
    /// - Parameters:
    ///   - stateOfMind: HKStateOfMind from HealthKit
    ///   - userID: User ID for the entry
    /// - Returns: MoodEntry with score calculated from valence
    @available(iOS 18.0, *)
    @available(*, deprecated, message: "HealthKit integration removed from simplified mood model")
    static func createMoodEntry(
        from stateOfMind: HKStateOfMind,
        userID: String
    ) -> MoodEntry {
        // Convert valence to score
        let baseScore = valenceToScore(stateOfMind.valence)

        // Convert labels to emotions
        let convertedLabels = stateOfMind.labels.compactMap { MoodLabel.from(healthKit: $0) }

        // Adjust score based on labels
        let finalScore = adjustScoreForLabels(baseScore: baseScore, labels: convertedLabels)

        // Convert labels to emotion strings (take first 5)
        let emotions = convertedLabels.prefix(5).map { $0.rawValue }

        return MoodEntry(
            id: UUID(),
            userID: userID,
            date: stateOfMind.startDate,
            score: finalScore,
            emotions: Array(emotions),
            notes: nil,
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending
        )
    }
}

// MARK: - Validation Helpers

extension MoodTranslationUtility {
    /// Validates that score is in valid range (1-10)
    static func isValidScore(_ score: Int) -> Bool {
        return score >= 1 && score <= 10
    }

    /// Validates that valence is in valid range (-1.0 to +1.0)
    static func isValidValence(_ valence: Double) -> Bool {
        return valence >= -1.0 && valence <= 1.0
    }

    /// Tests round-trip conversion accuracy (score → valence → score)
    static func testRoundTrip(score: Int) -> Bool {
        guard isValidScore(score) else { return false }
        let valence = scoreToValence(score)
        let convertedScore = valenceToScore(valence)
        return abs(convertedScore - score) <= 1  // Allow ±1 score point difference
    }
}

// MARK: - Debug Helpers

extension MoodTranslationUtility {
    /// Prints translation table for debugging
    static func printTranslationTable() {
        print("Score → Valence → Score Round-Trip")
        print("=====================================")
        for score in 1...10 {
            let valence = scoreToValence(score)
            let roundTrip = valenceToScore(valence)
            let labels = labelsForScore(score)
            print(
                String(
                    format: "%2d → %+.2f → %2d | %@", score, valence, roundTrip,
                    labels.map(\.rawValue).joined(separator: ", ")))
        }
    }
}
