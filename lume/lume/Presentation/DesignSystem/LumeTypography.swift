//
//  LumeTypography.swift
//  lume
//
//  Created by Marcos Barbero on 14/11/2025.
//

import SwiftUI

/// Lume typography system
/// Provides comfortable, readable text styles using rounded SF Pro families
enum LumeTypography {
    // MARK: - Title Styles

    /// Large title for main headings
    /// Size: 28pt, Regular weight
    static let titleLarge = Font.system(size: 28, weight: .regular, design: .rounded)

    /// Medium title for section headings
    /// Size: 22pt, Regular weight
    static let titleMedium = Font.system(size: 22, weight: .regular, design: .rounded)

    /// Small title for subsection headings
    /// Size: 20pt, Regular weight
    static let titleSmall = Font.system(size: 20, weight: .regular, design: .rounded)

    // MARK: - Body Styles

    /// Standard body text for main content
    /// Size: 17pt, Regular weight
    static let body = Font.system(size: 17, weight: .regular, design: .rounded)

    /// Small body text for secondary content
    /// Size: 15pt, Regular weight
    static let bodySmall = Font.system(size: 15, weight: .regular, design: .rounded)

    // MARK: - Caption Styles

    /// Caption text for labels and hints
    /// Size: 13pt, Regular weight
    static let caption = Font.system(size: 13, weight: .regular, design: .rounded)

    /// Small caption text for minimal annotations
    /// Size: 11pt, Regular weight
    static let captionSmall = Font.system(size: 11, weight: .regular, design: .rounded)

    // MARK: - Button Styles

    /// Primary button text
    /// Size: 17pt, Medium weight
    static let buttonPrimary = Font.system(size: 17, weight: .medium, design: .rounded)

    /// Secondary button text
    /// Size: 15pt, Medium weight
    static let buttonSecondary = Font.system(size: 15, weight: .medium, design: .rounded)
}
