//
//  MoodEntryViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Redesigned for Unified Single-Screen UX (v3.0)
//

import Foundation
import Observation

/// Mood factors that can influence mood
enum MoodFactor: String, CaseIterable, Identifiable {
    case work = "Work"
    case exercise = "Exercise"
    case sleep = "Sleep"
    case weather = "Weather"
    case relationships = "Relationships"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .exercise: return "figure.run"
        case .sleep: return "bed.double.fill"
        case .weather: return "cloud.sun.fill"
        case .relationships: return "heart.fill"
        }
    }

    /// Get emotions influenced by this factor
    func emotions(forPositiveMood: Bool) -> [String] {
        switch self {
        case .work:
            return forPositiveMood ? ["motivated", "content"] : ["stressed", "frustrated"]
        case .exercise:
            return forPositiveMood ? ["energetic", "happy"] : ["tired"]
        case .sleep:
            return forPositiveMood ? ["relaxed", "peaceful"] : ["tired", "overwhelmed"]
        case .weather:
            return forPositiveMood ? ["happy"] : ["sad"]
        case .relationships:
            return forPositiveMood ? ["content", "happy"] : ["sad", "anxious"]
        }
    }
}

@Observable
final class MoodEntryViewModel {

    // MARK: - State

    /// Slider position (0.0 to 1.0) - Single source of truth
    var sliderPosition: Double = 0.5

    /// Details section expanded?
    var detailsExpanded: Bool = false

    /// Selected factors (for detailed tracking)
    var selectedFactors: Set<MoodFactor> = []

    /// Optional notes
    var notes: String = ""

    /// Selected date
    var selectedDate: Date = Date()

    /// Loading state
    var isLoading: Bool = false

    /// Error message
    var errorMessage: String?

    /// Success state
    var showSuccessMessage: Bool = false

    // MARK: - Computed Properties

    /// Mood score (1-10) computed from slider position
    var moodScore: Int {
        let rawScore = (sliderPosition * 9.0) + 1.0
        return max(1, min(10, Int(round(rawScore))))
    }

    /// Current emoji based on slider position
    var currentEmoji: String {
        switch sliderPosition {
        case 0.0..<0.15: return "😢"
        case 0.15..<0.30: return "😔"
        case 0.30..<0.45: return "🙁"
        case 0.45..<0.60: return "😐"
        case 0.60..<0.75: return "🙂"
        case 0.75..<0.90: return "😊"
        case 0.90...1.0: return "🤩"
        default: return "😐"
        }
    }

    /// Current label based on slider position
    var currentLabel: String {
        switch sliderPosition {
        case 0.0..<0.15: return "Awful"
        case 0.15..<0.30: return "Down"
        case 0.30..<0.45: return "Bad"
        case 0.45..<0.60: return "Okay"
        case 0.60..<0.75: return "Good"
        case 0.75..<0.90: return "Great"
        case 0.90...1.0: return "Amazing"
        default: return "Okay"
        }
    }

    /// Emotions array computed from slider position and selected factors
    var emotions: [String] {
        var result: [String] = []

        // Base emotions from slider position
        let baseEmotions: [String] = {
            switch sliderPosition {
            case 0.0..<0.15: return ["overwhelmed", "sad"]
            case 0.15..<0.30: return ["sad", "tired"]
            case 0.30..<0.45: return ["frustrated", "stressed"]
            case 0.45..<0.60: return ["calm"]
            case 0.60..<0.75: return ["content", "relaxed"]
            case 0.75..<0.90: return ["happy", "peaceful"]
            case 0.90...1.0: return ["excited", "motivated"]
            default: return ["calm"]
            }
        }()

        result.append(contentsOf: baseEmotions)

        // Add emotions from selected factors
        let isPositiveMood = sliderPosition >= 0.5
        for factor in selectedFactors {
            let factorEmotions = factor.emotions(forPositiveMood: isPositiveMood)
            result.append(contentsOf: factorEmotions)
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        result = result.filter { seen.insert($0).inserted }

        return result
    }

    /// Color for current mood
    var moodColor: String {
        switch sliderPosition {
        case 0.0..<0.15: return "#DC3545"  // Red (Awful)
        case 0.15..<0.30: return "#FD7E14"  // Orange (Down)
        case 0.30..<0.45: return "#FFC107"  // Amber (Bad)
        case 0.45..<0.60: return "#6C757D"  // Gray (Okay)
        case 0.60..<0.75: return "#20C997"  // Teal (Good)
        case 0.75..<0.90: return "#28A745"  // Green (Great)
        case 0.90...1.0: return "#B58BEF"  // Lavender (Amazing)
        default: return "#6C757D"
        }
    }

    // MARK: - Dependencies

    private let saveMoodProgressUseCase: SaveMoodProgressUseCase

    // MARK: - Initialization

    init(saveMoodProgressUseCase: SaveMoodProgressUseCase) {
        self.saveMoodProgressUseCase = saveMoodProgressUseCase
    }

    // MARK: - Lifecycle

    /// Reset to defaults when view appears (for new entries)
    func onAppear() {
        reset()
    }

    // MARK: - Actions

    /// Set mood score directly (for mindfulness-style UX)
    func setMoodScore(_ score: Int) {
        // Map score (1-10) to slider position (0.0-1.0)
        sliderPosition = Double(score - 1) / 9.0
    }

    /// User tapped an emoji pill - jump slider to that position
    func selectEmoji(_ emoji: String) {
        let position: Double

        switch emoji {
        case "😢": position = 0.075  // Awful (midpoint of 0.0-0.15)
        case "😔": position = 0.225  // Down (midpoint of 0.15-0.30)
        case "🙁": position = 0.375  // Bad (midpoint of 0.30-0.45)
        case "😐": position = 0.525  // Okay (midpoint of 0.45-0.60)
        case "🙂": position = 0.675  // Good (midpoint of 0.60-0.75)
        case "😊": position = 0.825  // Great (midpoint of 0.75-0.90)
        case "🤩": position = 0.95  // Amazing (midpoint of 0.90-1.0)
        default: position = 0.5
        }

        sliderPosition = position
    }

    /// User dragged slider - position already updated via binding
    func updateSlider(to position: Double) {
        sliderPosition = max(0.0, min(1.0, position))
    }

    /// Toggle details section
    func toggleDetails() {
        detailsExpanded.toggle()
    }

    /// Toggle factor selection
    func toggleFactor(_ factor: MoodFactor) {
        if selectedFactors.contains(factor) {
            selectedFactors.remove(factor)
        } else {
            selectedFactors.insert(factor)
        }
    }

    /// Save mood entry
    @MainActor
    func save() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await saveMoodProgressUseCase.execute(
                score: moodScore,
                emotions: emotions,
                notes: notes.isEmpty ? nil : notes,
                date: selectedDate
            )
            // Success - view will auto-dismiss

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// Dismiss success message
    func dismissSuccessMessage() {
        showSuccessMessage = false
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Reset form to defaults
    func reset() {
        sliderPosition = 0.5
        detailsExpanded = false
        selectedFactors.removeAll()
        notes = ""
        selectedDate = Date()
        errorMessage = nil
        showSuccessMessage = false
    }

    /// Check if an emoji is currently selected
    func isEmojiSelected(_ emoji: String) -> Bool {
        return currentEmoji == emoji
    }

    /// Get position for emoji (for range checking)
    func positionRange(for emoji: String) -> ClosedRange<Double> {
        switch emoji {
        case "😢": return 0.0...0.15
        case "😔": return 0.15...0.30
        case "🙁": return 0.30...0.45
        case "😐": return 0.45...0.60
        case "🙂": return 0.60...0.75
        case "😊": return 0.75...0.90
        case "🤩": return 0.90...1.0
        default: return 0.45...0.60
        }
    }
}
