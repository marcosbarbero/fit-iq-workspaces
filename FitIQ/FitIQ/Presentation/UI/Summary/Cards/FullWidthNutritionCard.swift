//
//  FullWidthNutritionCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Foundation
import SwiftUI

import SwiftUI
import Observation

// Mock data structures assumed to be defined in NutritionSummaryViewModel.swift

// MARK: - Main Card View

struct FullWidthNutritionCard: View {
    
    // Assumes NutritionSummaryViewModel is @Observable and injected
    let viewModel: NutritionSummaryViewModel
    
    private let primaryColor = Color.ascendBlue
    
    // Derived property for the NET STATUS BAR
    private var netStatus: (text: String, color: Color, icon: String) {
        let net = viewModel.netCalories
        let goal = viewModel.netGoal
        
        if net <= goal {
            // Net is equal to or below target deficit (Good)
            return ("Great Deficit", Color.growthGreen, "leaf.fill")
        } else if net > 0 {
            // Net is positive (Warning/Surplus)
            return ("Calorie Surplus", Color.attentionOrange, "flame.fill")
        } else if net > goal && net < 0 {
            // Net is a deficit, but hasn't reached the target yet
            return ("In Deficit", primaryColor, "arrow.down")
        } else {
            // Placeholder/Balance
            return ("On Track", primaryColor, "circle")
        }
    }
    
    // MacroSnapshot created for Calories/Intake Goal, aligning its usage with other macros
    private var calorieMacro: MacroSnapshot {
        MacroSnapshot(
            name: "Intake",
            current: Double(viewModel.caloriesConsumed),
            goal: Double(viewModel.intakeGoal),
            unit: "kcal",
            color: primaryColor
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // 1. HEADER: Title
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.title2)
                        .foregroundColor(primaryColor)
                    
                    Text("Nutrition Tracker")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.bottom, 5)
            
            // 2. NET STATUS BAR (Goal Status Bar - High visual priority)
            GoalStatusBar(
                netCalories: viewModel.netCalories,
                netGoal: viewModel.netGoal,
                status: netStatus
            )
            .padding(.bottom, 10)
            
            // 3. Calorie Consumption Progress Bar (Primary Intake Focus)
            MacroProgressBar(macro: calorieMacro, isPrimary: true)
                .padding(.bottom, 5)
            
            // 4. Macronutrient Progress Bars (Secondary)
            VStack(spacing: 12) {
                ForEach(viewModel.macros, id: \.name) { macro in
                    MacroProgressBar(macro: macro)
                }
            }
        }
        .padding(.top)
        .padding(.horizontal)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct MacroProgressBar: View {
    let macro: MacroSnapshot
    var isPrimary: Bool = false
    
    // Calculated progress, but NOT capped at 1.0 for the purpose of detecting surplus
    private var actualProgress: Double {
        macro.current / macro.goal
    }
    
    // The progress used for drawing the standard bar (capped at 100%)
    private var displayProgress: Double {
        min(1.0, actualProgress)
    }

    private var hasSurplus: Bool {
        actualProgress > 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ... (HStack for labels remains the same) ...
            HStack(alignment: .lastTextBaseline) {
                
                // LEFT: Macro/Calorie Name
                Text(macro.name)
                    .font(isPrimary ? .title3 : .subheadline)
                    .fontWeight(isPrimary ? .heavy : .semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // RIGHT: Explicit Consumed / Goal
                Text("\(Int(macro.current)) / \(Int(macro.goal)) \(macro.unit)")
                    .font(isPrimary ? .title3 : .subheadline)
                    .fontWeight(isPrimary ? .bold : .semibold)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar Area
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: isPrimary ? 12 : 8)
                    
                    // Progress fill (capped at 100% width)
                    Capsule()
                        .fill(macro.color)
                        .frame(width: geometry.size.width * CGFloat(displayProgress), height: isPrimary ? 12 : 8)
                        .animation(.easeOut, value: actualProgress)

                    // 🛑 NEW: Surplus Indicator (Only visible and applicable to the primary calorie bar)
                    if isPrimary && hasSurplus {
                        // Small overlay on the right end of the bar showing over-consumption
                        Capsule()
                            .fill(Color.attentionOrange) // Use Warning color
                            .frame(width: 8, height: isPrimary ? 12 : 8)
                            .offset(x: geometry.size.width - 4) // Position it right at the edge
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                                    .offset(x: geometry.size.width - 4)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(height: isPrimary ? 12 : 8)
        }
    }
}
