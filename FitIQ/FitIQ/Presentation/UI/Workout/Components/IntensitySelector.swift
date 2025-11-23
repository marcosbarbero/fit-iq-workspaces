//
//  IntensitySelector.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import SwiftUI

/// RPE (Rate of Perceived Exertion) Intensity Selector
/// Allows user to rate workout intensity on a 1-10 scale
struct IntensitySelector: View {
    @Binding var selectedIntensity: Int
    let onComplete: () -> Void
    
    private let primaryColor = Color.vitalityTeal
    
    // RPE scale labels
    private let intensityLabels: [Int: String] = [
        1: "Rest",
        2: "Very Easy",
        3: "Easy",
        4: "Moderate",
        5: "Moderate+",
        6: "Challenging",
        7: "Hard",
        8: "Very Hard",
        9: "Near Max",
        10: "All Out"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("How Intense Was Your Workout?")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Rate of Perceived Exertion (RPE)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Current selection display
            VStack(spacing: 8) {
                Text("\(selectedIntensity)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(intensityColor(for: selectedIntensity))
                
                Text(intensityLabels[selectedIntensity] ?? "")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            
            // Slider
            VStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { Double(selectedIntensity) },
                        set: { selectedIntensity = Int($0) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .tint(intensityColor(for: selectedIntensity))
                
                // Scale markers
                HStack {
                    ForEach(1...10, id: \.self) { value in
                        Text("\(value)")
                            .font(.caption2)
                            .foregroundColor(selectedIntensity == value ? intensityColor(for: value) : .secondary)
                            .fontWeight(selectedIntensity == value ? .bold : .regular)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal)
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(primaryColor)
                    Text("RPE Scale Guide")
                        .font(.headline)
                }
                
                Text("1-3: Light effort, can hold conversation easily")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("4-6: Moderate effort, breathing harder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("7-9: Hard effort, pushing limits")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("10: Maximum effort, can't continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Spacer()
            
            // Complete button
            Button(action: onComplete) {
                Text("Complete Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(primaryColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    // Helper to get color based on intensity
    private func intensityColor(for intensity: Int) -> Color {
        switch intensity {
        case 1...3:
            return .green
        case 4...6:
            return .orange
        case 7...9:
            return .red
        case 10:
            return .purple
        default:
            return .gray
        }
    }
}

#Preview {
    IntensitySelector(
        selectedIntensity: .constant(7),
        onComplete: {}
    )
}
