//
//  LumeColors.swift
//  lume
//
//  Created by Marcos Barbero on 14/11/2025.
//

import SwiftUI

/// Lume brand color palette
/// Provides warm, calm, and cozy colors aligned with the app's emotional tone
enum LumeColors {
    // MARK: - Background Colors

    /// Main app background color - warm off-white
    /// Hex: #F8F4EC
    static let appBackground = Color(red: 0xF8 / 255, green: 0xF4 / 255, blue: 0xEC / 255)

    /// Surface background color for cards and elevated content
    /// Hex: #E8DFD6
    static let surface = Color(red: 0xE8 / 255, green: 0xDF / 255, blue: 0xD6 / 255)

    // MARK: - Accent Colors

    /// Primary accent color - warm peach
    /// Hex: #F2C9A7
    static let accentPrimary = Color(red: 0xF2 / 255, green: 0xC9 / 255, blue: 0xA7 / 255)

    /// Secondary accent color - soft lavender
    /// Hex: #D8C8EA
    static let accentSecondary = Color(red: 0xD8 / 255, green: 0xC8 / 255, blue: 0xEA / 255)

    // MARK: - Text Colors

    /// Primary text color - dark warm brown
    /// Hex: #3B332C
    static let textPrimary = Color(red: 0x3B / 255, green: 0x33 / 255, blue: 0x2C / 255)

    /// Secondary text color - medium warm brown
    /// Hex: #6E625A
    static let textSecondary = Color(red: 0x6E / 255, green: 0x62 / 255, blue: 0x5A / 255)

    // MARK: - Mood Colors (Positive Emotions)

    /// Amazed mood - light purple (wonder)
    /// Hex: #E8D4F0
    static let moodAmazed = Color(red: 0xE8 / 255, green: 0xD4 / 255, blue: 0xF0 / 255)

    /// Grateful mood - light rose (warmth)
    /// Hex: #FFD4E5
    static let moodGrateful = Color(red: 0xFF / 255, green: 0xD4 / 255, blue: 0xE5 / 255)

    /// Happy mood - bright warm yellow (joy)
    /// Hex: #F5DFA8
    static let moodHappy = Color(red: 0xF5 / 255, green: 0xDF / 255, blue: 0xA8 / 255)

    /// Proud mood - soft purple (achievement)
    /// Hex: #D4B8F0
    static let moodProud = Color(red: 0xD4 / 255, green: 0xB8 / 255, blue: 0xF0 / 255)

    /// Hopeful mood - light mint (optimism)
    /// Hex: #B8E8D4
    static let moodHopeful = Color(red: 0xB8 / 255, green: 0xE8 / 255, blue: 0xD4 / 255)

    /// Content mood - sage green (peace)
    /// Hex: #D8E8C8
    static let moodContent = Color(red: 0xD8 / 255, green: 0xE8 / 255, blue: 0xC8 / 255)

    /// Peaceful mood - soft sky blue (calm)
    /// Hex: #C8D8EA
    static let moodPeaceful = Color(red: 0xC8 / 255, green: 0xD8 / 255, blue: 0xEA / 255)

    /// Excited mood - light orange (energy)
    /// Hex: #FFE4B5
    static let moodExcited = Color(red: 0xFF / 255, green: 0xE4 / 255, blue: 0xB5 / 255)

    /// Joyful mood - bright lemon (delight)
    /// Hex: #F5E8A8
    static let moodJoyful = Color(red: 0xF5 / 255, green: 0xE8 / 255, blue: 0xA8 / 255)

    // MARK: - Mood Colors (Challenging Emotions)

    /// Sad mood - light blue (melancholy)
    /// Hex: #C8D4E8
    static let moodSad = Color(red: 0xC8 / 255, green: 0xD4 / 255, blue: 0xE8 / 255)

    /// Angry mood - soft coral (frustration)
    /// Hex: #F0B8A4
    static let moodAngry = Color(red: 0xF0 / 255, green: 0xB8 / 255, blue: 0xA4 / 255)

    /// Stressed mood - soft peach (tension)
    /// Hex: #E8C4B4
    static let moodStressed = Color(red: 0xE8 / 255, green: 0xC4 / 255, blue: 0xB4 / 255)

    /// Anxious mood - light tan (unease)
    /// Hex: #E8E4D8
    static let moodAnxious = Color(red: 0xE8 / 255, green: 0xE4 / 255, blue: 0xD8 / 255)

    /// Frustrated mood - light terracotta (irritation)
    /// Hex: #F0C8A4
    static let moodFrustrated = Color(red: 0xF0 / 255, green: 0xC8 / 255, blue: 0xA4 / 255)

    /// Overwhelmed mood - light purple-gray (overload)
    /// Hex: #D4C8E8
    static let moodOverwhelmed = Color(red: 0xD4 / 255, green: 0xC8 / 255, blue: 0xE8 / 255)

    /// Lonely mood - cool lavender-blue (isolation)
    /// Hex: #B8C8E8
    static let moodLonely = Color(red: 0xB8 / 255, green: 0xC8 / 255, blue: 0xE8 / 255)

    /// Scared mood - warm beige (fear)
    /// Hex: #E8D4C8
    static let moodScared = Color(red: 0xE8 / 255, green: 0xD4 / 255, blue: 0xC8 / 255)

    /// Worried mood - light mauve (concern)
    /// Hex: #D8C8D8
    static let moodWorried = Color(red: 0xD8 / 255, green: 0xC8 / 255, blue: 0xD8 / 255)

    // MARK: - Legacy Mood Colors (for backward compatibility)

    /// Positive mood indicator - bright warm yellow
    /// Hex: #F5DFA8
    static let moodPositive = moodHappy

    /// Neutral mood indicator - sage green
    /// Hex: #D8E8C8
    static let moodNeutral = moodContent

    /// Low mood indicator - soft coral
    /// Hex: #F0B8A4
    static let moodLow = moodAngry
}
