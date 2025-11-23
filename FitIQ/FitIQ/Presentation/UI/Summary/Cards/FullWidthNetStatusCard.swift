//
//  FullWidthNetStatusCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Foundation
import SwiftUI

struct FullWidthNetStatusCard: View {
    let viewModel: NutritionSummaryViewModel
    
    private var netStatus: (text: String, color: Color, icon: String) {
        let net = viewModel.netCalories
        let goal = viewModel.netGoal
        
        if net <= goal {
            return ("Great Deficit", Color.growthGreen, "leaf.fill")
        } else if net > 0 {
            return ("Calorie Surplus", Color.attentionOrange, "flame.fill")
        } else if net > goal && net < 0 {
            return ("In Deficit", .ascendBlue, "arrow.down")
        } else {
            return ("Balanced", .secondary, "circle")
        }
    }
    
    private var netDisplay: String {
        "\(viewModel.netCalories) kcal"
    }
    
    var body: some View {
        HStack(spacing: 15) {
            
            // Left Side: Status Icon and Message (Focus)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: netStatus.icon)
                        .font(.title)
                        .foregroundColor(netStatus.color)
                    
                    Text(netStatus.text)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                }
                
                // Detailed Status Line
                Text("Net: \(netDisplay) (Target: \(viewModel.netGoal) kcal)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Right Side: Progress Gauge (Visual Cue)
            // Using a simple text-based gauge for mock-up simplicity
            VStack(alignment: .trailing) {
                Text(netStatus.color == Color.growthGreen ? "SUCCESS" : "IN PROGRESS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(netStatus.color)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(netStatus.color.opacity(0.1)) // Subtle, themed background
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(netStatus.color.opacity(0.4), lineWidth: 1) // Themed border
        )
    }
}
