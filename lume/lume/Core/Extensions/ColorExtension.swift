//
//  ColorExtension.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import SwiftUI

extension Color {
    /// Initialize a Color from a hex string
    /// Supports formats: "#RRGGBB", "RRGGBB"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch hex.count {
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Create a very light tint by blending this color with white
    /// - Parameter amount: How much of the original color to use (0.0 = white, 1.0 = original color)
    /// - Returns: A new color that's a light tint
    func lightTint(amount: Double = 0.1) -> Color {
        // Extract RGB components
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Blend with white (1.0) based on amount
        let newRed = red * amount + 1.0 * (1.0 - amount)
        let newGreen = green * amount + 1.0 * (1.0 - amount)
        let newBlue = blue * amount + 1.0 * (1.0 - amount)

        return Color(
            .sRGB,
            red: Double(newRed),
            green: Double(newGreen),
            blue: Double(newBlue),
            opacity: 1.0
        )
    }

    /// Create a darkened version of this color
    /// - Parameter amount: How much to darken (0.0 = no change, 1.0 = black)
    /// - Returns: A new color that's darkened
    func darkened(amount: Double = 0.2) -> Color {
        // Extract RGB components
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Darken by reducing each component
        let factor = 1.0 - amount
        let newRed = red * factor
        let newGreen = green * factor
        let newBlue = blue * factor

        return Color(
            .sRGB,
            red: Double(newRed),
            green: Double(newGreen),
            blue: Double(newBlue),
            opacity: Double(alpha)
        )
    }
}
