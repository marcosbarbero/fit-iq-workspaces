//
//  MoodIntensitySelector.swift
//  lume
//
//  Created by AI Assistant on 2025-01-15.
//  Modern, fun 1-10 intensity selector with visual feedback
//

import SwiftUI

/// Modern visual selector for mood intensity (1-10)
/// Features animated bubbles that grow and change color based on selection
struct MoodIntensitySelector: View {
    @Binding var selectedIntensity: Int
    let moodColor: String

    @State private var animatingIndex: Int? = nil

    // Grid of 2 rows x 5 columns for clean layout
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with current selection
            HStack {
                Text("Intensity")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                Spacer()

                if selectedIntensity > 0 {
                    HStack(spacing: 8) {
                        Text("\(selectedIntensity)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: moodColor))

                        Text("/ 10")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Description
            Text(intensityDescription)
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)
                .animation(.easeInOut, value: selectedIntensity)

            // Intensity bubbles
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...10, id: \.self) { intensity in
                    IntensityBubble(
                        intensity: intensity,
                        isSelected: selectedIntensity == intensity,
                        isAnimating: animatingIndex == intensity,
                        baseColor: moodColor
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            selectedIntensity = intensity
                            animatingIndex = intensity
                        }

                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()

                        // Reset animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            animatingIndex = nil
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var intensityDescription: String {
        switch selectedIntensity {
        case 0:
            return "Tap a bubble to rate the intensity of this feeling"
        case 1...3:
            return "Barely noticeable, subtle"
        case 4...6:
            return "Moderate, clearly present"
        case 7...9:
            return "Strong, significant"
        case 10:
            return "Overwhelming, all-encompassing"
        default:
            return ""
        }
    }
}

/// Individual intensity bubble with animations
struct IntensityBubble: View {
    let intensity: Int
    let isSelected: Bool
    let isAnimating: Bool
    let baseColor: String
    let action: () -> Void

    private var size: CGFloat {
        if isSelected {
            return 64
        } else {
            // Smaller bubbles get smaller size
            return intensity <= 3 ? 48 : (intensity <= 6 ? 52 : 56)
        }
    }

    private var opacity: Double {
        if isSelected {
            return 1.0
        } else {
            // Fade out unselected when one is selected
            return intensity > 0 && !isSelected ? 0.4 : 0.7
        }
    }

    private var bubbleColor: Color {
        let base = Color(hex: baseColor)

        if isSelected {
            return base
        }

        // Lighter for lower intensities
        _ = 1.0 - (Double(intensity) / 15.0)
        return base.opacity(0.3 + (Double(intensity) / 20.0))
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow for selected
                if isSelected {
                    Circle()
                        .fill(bubbleColor.opacity(0.3))
                        .frame(width: size + 16, height: size + 16)
                        .blur(radius: 8)
                }

                // Main bubble
                Circle()
                    .fill(bubbleColor)
                    .frame(width: size, height: size)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    }
                    .shadow(
                        color: isSelected ? bubbleColor.opacity(0.5) : Color.black.opacity(0.1),
                        radius: isSelected ? 12 : 4,
                        x: 0,
                        y: isSelected ? 6 : 2
                    )

                // Number
                Text("\(intensity)")
                    .font(.system(size: isSelected ? 24 : 18, weight: .bold, design: .rounded))
                    .foregroundColor(
                        isSelected ? LumeColors.textPrimary : LumeColors.textSecondary
                    )

                // Pulse animation when tapped
                if isAnimating {
                    Circle()
                        .stroke(bubbleColor, lineWidth: 3)
                        .frame(width: size, height: size)
                        .scaleEffect(1.5)
                        .opacity(0)
                        .animation(
                            .easeOut(duration: 0.6),
                            value: isAnimating
                        )
                }
            }
            .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: size)
    }
}

// MARK: - Alternative: Bar Style Selector

/// Alternative intensity selector using animated bars (more compact)
struct IntensityBarSelector: View {
    @Binding var selectedIntensity: Int
    let moodColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Intensity")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                Spacer()

                if selectedIntensity > 0 {
                    Text("\(selectedIntensity)/10")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: moodColor))
                }
            }

            // Bars
            HStack(spacing: 8) {
                ForEach(1...10, id: \.self) { intensity in
                    IntensityBar(
                        intensity: intensity,
                        isActive: intensity <= selectedIntensity,
                        color: moodColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedIntensity = intensity
                        }

                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
            }

            // Labels
            HStack {
                Text("Subtle")
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)

                Spacer()

                Text("Intense")
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)
            }
        }
    }
}

struct IntensityBar: View {
    let intensity: Int
    let isActive: Bool
    let color: String
    let action: () -> Void

    private var height: CGFloat {
        let baseHeight: CGFloat = 30
        let increment: CGFloat = 8
        return baseHeight + (CGFloat(intensity) * increment)
    }

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isActive
                        ? Color(hex: color).opacity(0.7 + (Double(intensity) / 30.0))
                        : LumeColors.textSecondary.opacity(0.2)
                )
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Bubble Selector") {
    struct PreviewWrapper: View {
        @State private var intensity = 5

        var body: some View {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                VStack {
                    MoodIntensitySelector(
                        selectedIntensity: $intensity,
                        moodColor: "#F5DFA8"
                    )
                    .padding(20)
                    .background(LumeColors.surface)
                    .cornerRadius(16)
                    .padding(20)

                    Spacer()
                }
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Bar Selector") {
    struct PreviewWrapper: View {
        @State private var intensity = 7

        var body: some View {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                VStack {
                    IntensityBarSelector(
                        selectedIntensity: $intensity,
                        moodColor: "#F0B8A4"
                    )
                    .padding(20)
                    .background(LumeColors.surface)
                    .cornerRadius(16)
                    .padding(20)

                    Spacer()
                }
            }
        }
    }

    return PreviewWrapper()
}
