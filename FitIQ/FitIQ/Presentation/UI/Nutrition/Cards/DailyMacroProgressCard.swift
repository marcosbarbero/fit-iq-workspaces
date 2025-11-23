//
//  DailyMacroProgressCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI


struct DailyMacroProgressCard: View {
    // Uses the NutritionViewModel for live data access
    @Bindable var viewModel: NutritionViewModel
    
    private let primaryColor = Color.ascendBlue
    
    // MacroSnapshot creation adapted from the Summary Card logic
    private var macroSnapshots: [MacroSnapshot] {
        let targets = viewModel.dailyTargets // Assumes ViewModel now holds targets
        let summary = viewModel.dailySummary // Current consumed totals
        
        return [
            // Calorie Bar (Primary Focus)
            MacroSnapshot(name: "Intake", current: Double(summary.kcal), goal: Double(targets.kcal), unit: "kcal", color: primaryColor),
            // Macronutrient Bars
            MacroSnapshot(name: "Protein", current: Double(summary.protein), goal: Double(targets.protein), unit: "g", color: Color.sustenanceYellow),
            MacroSnapshot(name: "Carbs", current: Double(summary.carbs), goal: Double(targets.carbs), unit: "g", color: Color.vitalityTeal),
            MacroSnapshot(name: "Fat", current: Double(summary.fat), goal: Double(targets.fat), unit: "g", color: Color.serenityLavender)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // Header with Calorie Goal Summary
            HStack {
                Text("Daily Goal: \(viewModel.dailyTargets.kcal) kcal")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Remaining: \(viewModel.dailyTargets.kcal - viewModel.dailySummary.kcal) kcal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bars
            VStack(spacing: 12) {
                ForEach(macroSnapshots, id: \.name) { macro in
                    // Use MacroProgressBar, making Calories the primary bar
                    MacroProgressBar(macro: macro, isPrimary: macro.name == "Intake")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
}
