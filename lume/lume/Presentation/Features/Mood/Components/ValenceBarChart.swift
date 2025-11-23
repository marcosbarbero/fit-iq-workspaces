//
//  ValenceBarChart.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Visual representation of valence as a bar chart similar to Apple Fitness
//

import SwiftUI

/// Bar chart visualization for mood valence
/// Similar to Apple Fitness intensity bars
struct ValenceBarChart: View {
    let valence: Double
    let color: String
    let animated: Bool

    private let barCount = 5
    private let barSpacing: CGFloat = 3
    private let maxBarHeight: CGFloat = 24

    init(valence: Double, color: String, animated: Bool = true) {
        self.valence = valence
        self.color = color
        self.animated = animated
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                BarView(
                    height: heightForBar(at: index),
                    color: color,
                    isFilled: shouldFillBar(at: index),
                    animated: animated,
                    delay: animated ? Double(index) * 0.05 : 0
                )
            }
        }
        .frame(height: maxBarHeight)
    }

    /// Calculate height for each bar (progressively taller from left to right)
    private func heightForBar(at index: Int) -> CGFloat {
        let baseHeight = maxBarHeight * 0.4
        let increment = (maxBarHeight - baseHeight) / CGFloat(barCount - 1)
        return baseHeight + (increment * CGFloat(index))
    }

    /// Determine if a bar should be filled based on valence
    /// Valence ranges from -1.0 to 1.0, we map to 0-5 bars
    private func shouldFillBar(at index: Int) -> Bool {
        // Map valence from [-1.0, 1.0] to [0, 5]
        let normalizedValence = (valence + 1.0) / 2.0  // Now in range [0, 1]
        let filledBars = Int(round(normalizedValence * Double(barCount)))
        return index < filledBars
    }
}

/// Individual bar in the chart
private struct BarView: View {
    let height: CGFloat
    let color: String
    let isFilled: Bool
    let animated: Bool
    let delay: Double

    @State private var scale: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isFilled ? Color(hex: color) : Color(hex: color).opacity(0.35))
            .frame(width: 6, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        isFilled
                            ? Color(hex: color).opacity(0.6)
                            : Color.gray.opacity(0.5),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isFilled ? Color(hex: color).opacity(0.2) : Color.clear,
                radius: 1,
                x: 0,
                y: 0.5
            )
            .scaleEffect(y: animated ? scale : 1, anchor: .bottom)
            .onAppear {
                if animated {
                    withAnimation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(delay)
                    ) {
                        scale = 1
                    }
                } else {
                    scale = 1
                }
            }
    }
}

// MARK: - Previews

#Preview("Valence Bar Chart - Various Levels") {
    VStack(spacing: 32) {
        VStack(spacing: 8) {
            Text("Very Unpleasant (-0.8)")
                .font(.caption)
            ValenceBarChart(valence: -0.8, color: "#F0B8A4")
        }

        VStack(spacing: 8) {
            Text("Unpleasant (-0.3)")
                .font(.caption)
            ValenceBarChart(valence: -0.3, color: "#E8D9C8")
        }

        VStack(spacing: 8) {
            Text("Neutral (0.0)")
                .font(.caption)
            ValenceBarChart(valence: 0.0, color: "#B8D4E8")
        }

        VStack(spacing: 8) {
            Text("Pleasant (0.3)")
                .font(.caption)
            ValenceBarChart(valence: 0.3, color: "#D8C8EA")
        }

        VStack(spacing: 8) {
            Text("Very Pleasant (0.8)")
                .font(.caption)
            ValenceBarChart(valence: 0.8, color: "#F5DFA8")
        }

        VStack(spacing: 8) {
            Text("Ecstatic (1.0)")
                .font(.caption)
            ValenceBarChart(valence: 1.0, color: "#FFE4B5")
        }
    }
    .padding()
}
