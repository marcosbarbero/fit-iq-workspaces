//
//  SessionMetricsCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

// Helper to format the time duration into HH:MM
private func formatDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h > 0 {
        return String(format: "%d hr %02d min", h, m)
    } else {
        return String(format: "%d min", m)
    }
}

struct SessionMetricsCard: View {
    let log: CompletedWorkout  // Contains all necessary data
    private let primaryColor = Color.vitalityTeal

    // Color for RPE based on intensity level
    private func colorForRPE(_ value: Int) -> Color {
        switch value {
        case 1...3: return Color.green
        case 4...5: return Color.yellow
        case 6...7: return Color.orange
        case 8...9: return Color.red
        case 10: return Color.purple
        default: return Color.gray
        }
    }

    // Height for each bar - increases progressively
    private func heightForBar(_ index: Int) -> CGFloat {
        let baseHeight: CGFloat = 12
        let increment: CGFloat = 3
        return baseHeight + (CGFloat(index) * increment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Row 1: Effort Bar (Full Width Focus) - Only show if RPE was provided
            if log.effortRPE > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Effort (RPE)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(log.effortRPE) / 10")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(colorForRPE(log.effortRPE))
                    }

                    // 10-bar visualization with gradient colors and increasing heights
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(1...10, id: \.self) { barIndex in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    barIndex <= log.effortRPE
                                        ? colorForRPE(barIndex)
                                        : Color.secondary.opacity(0.2)
                                )
                                .frame(height: heightForBar(barIndex - 1))
                        }
                    }
                    .frame(height: 50)
                }
                .padding([.horizontal, .top], 15)

                Divider().padding(.horizontal, 15)
            }

            // Row 2: Duration, Sets, and Calories (3x Grid or Split)
            HStack(spacing: 10) {
                // Duration
                MetricDetailView(
                    title: "Duration",
                    value: formatDuration(log.durationMinutes),
                    icon: "clock.fill",
                    color: primaryColor
                )
                // Sets Completed
                MetricDetailView(
                    title: "Sets Completed",
                    value: "\(log.setsCompleted)",
                    icon: "repeat.circle.fill",
                    color: primaryColor
                )
                // Calories Burned
                MetricDetailView(
                    title: "Calories Burned",
                    value: "\(log.caloriesBurned) kcal",
                    icon: "flame.fill",
                    color: primaryColor
                )
            }
            .padding([.horizontal, .bottom], 15)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
}

// Helper struct for clean metric layout inside the card (replaces MetricCard)
struct MetricDetailView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
