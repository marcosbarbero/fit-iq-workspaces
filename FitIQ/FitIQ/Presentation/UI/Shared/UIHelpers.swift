//
//  UIHelpers.swift
//  FitIQ
//
//  Created by Marcos Barbero on 10/10/2025.
//

/// Common UI Helpers

import Foundation
import SwiftUI

// MARK: - Core Palette
extension Color {

    /// A vibrant, trustworthy blue. Primary accent color for CTAs, graphs, and the AI Companion.
    static let ascendBlue = Color(hex: "#007AFF")

    /// A fresh, invigorating teal/mint. Used for all Fitness and Activity elements.
    static let vitalityTeal = Color(hex: "#00C896")

    /// A soft, gentle purple/lavender. Used for all Wellness and Mood tracking elements.
    static let serenityLavender = Color(hex: "#B58BEF")

    /// Pure white for Light Mode backgrounds.
    static let cleanSlateLight = Color(hex: "#FFFFFF")

    /// Very dark gray for Dark Mode backgrounds (matches iOS system background).
    static let cleanSlateDark = Color(hex: "#1C1C1E")

    /// Standard green for success indicators and goal completion.
    static let growthGreen = Color(hex: "#34C759")

    /// Used sparingly for potential issues or warnings.
    static let attentionOrange = Color(hex: "#FF9500")

    static let alertRed = Color(hex: "#f5473d")

    static let sustenanceYellow = Color(hex: "#FFCC00")

    static let midnightBlue = Color(hex: "#191970")
    static let lavenderDusk = Color(hex: "#8470FF")
    static let twilightGray = Color(hex: "#A9A9A9")
    static let warningRed = Color(hex: "#E55B5B")
    
    static let deepViolet = Color(hex: "#4A2C87")
    static let calmIris = Color(hex: "#8F75CC")
    static let softLilac = Color(hex: "#C2B9D9")
    
    
    static let midnightIndigo = Color(hex: "#1A237E") // Deep
    static let calmBlue = Color(hex: "#455A64")     // Core
    static let skyBlue = Color(hex: "#90CAF9")
    
    static let oceanCore = Color(hex: "#5C6BC0")

}

// Color+AppPalette.swift (Conceptual Addition)

extension Color {
    // Determines if a color is light enough that black text is needed.
    // The threshold is typically around 0.5 on the sRGB luminance scale.
    func isLight() -> Bool {
        // Implement complex brightness calculation here (e.g., using CGColor components)
        // For our defined palette:
        switch self {
        case .ascendBlue, .midnightIndigo, .deepViolet:
            return false // These are dark, so use white text
        case .vitalityTeal, .serenityLavender, .sustenanceYellow, .calmBlue:
            return true // These are brighter, so use black/primary text
        default:
            // Fallback logic, treating custom/system colors as dark by default if calculation fails
            return false
        }
    }
}

// MARK: - Hexadecimal Initializer Extension

// Since SwiftUI's Color doesn't have a direct initializer for hex strings,
// this helper extension makes the code clean and readable.
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHex = cleanHex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        Scanner(string: cleanHex).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}


struct ActionFAB: View {
    let action: () -> Void
    let color: Color
    let systemImageName: String
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(20)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

// NEW: Helper view for individual action card content (Moved from NutritionView.swift to be shared)
struct ActionCardContent: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 15) // Horizontal padding for content
        .frame(height: 70) // Set a consistent height for the card
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
