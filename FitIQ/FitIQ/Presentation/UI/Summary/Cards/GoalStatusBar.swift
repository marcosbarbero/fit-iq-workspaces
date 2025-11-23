//
//  GoalStatusBar.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Foundation
import SwiftUI

struct GoalStatusBar: View {
    let netCalories: Int
    let netGoal: Int
    let status: (text: String, color: Color, icon: String)

    private var netDisplay: String {
        // Formats the number with a sign, e.g., "-750 kcal" or "+120 kcal"
        let sign = netCalories > 0 ? "+" : ""
        return "\(sign)\(netCalories) kcal"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.icon)
                .font(.title2)
                .foregroundColor(status.color)
            
            VStack(alignment: .leading, spacing: 2) {
                // Primary status (Deficit/Surplus text)
                Text(status.text)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(status.color)
                
                // Secondary status (Net calories for the day)
                Text("Net: \(netDisplay) (Target: \(netGoal) kcal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(status.color.opacity(0.1)) // Subtle colored background
        .cornerRadius(10)
    }
}
