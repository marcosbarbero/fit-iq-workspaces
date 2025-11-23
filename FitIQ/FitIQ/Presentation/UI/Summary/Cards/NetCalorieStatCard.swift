//
//  NetCalorieStatCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Foundation
import SwiftUI

struct NetCalorieStatCard: View {
    let viewModel: NutritionSummaryViewModel
    
    init(viewModel: NutritionSummaryViewModel) {
        self.viewModel = viewModel
    }
    
    private var netStatus: (text: String, color: Color, icon: String) {
        let net = viewModel.netCalories
        let goal = viewModel.netGoal
        
        if net <= goal {
            // Net is equal to or below target deficit (e.g., net -800, goal -700)
            return ("Great Deficit", Color.growthGreen, "leaf.fill")
        } else if net > 0 {
            // Net is positive (Calorie Surplus)
            return ("Calorie Surplus", Color.attentionOrange, "flame.fill")
        } else if net > goal && net < 0 {
            // Net is a deficit, but hasn't reached the target deficit yet
            return ("In Deficit", .ascendBlue, "arrow.down")
        } else {
            return ("Balanced", .secondary, "circle")
        }
    }
    
    private var netDisplay: String {
        // e.g., "-750 kcal" or "+120 kcal"
        "\(viewModel.netCalories) kcal"
    }
    
    var body: some View {
        // We reuse the standard StatCard design for grid consistency
        StatCard(
            currentValue: netDisplay,
            unit: netStatus.text,
            icon: netStatus.icon,
            color: netStatus.color
        )
    }
}
