//
//  GoalCheckboxCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

struct GoalCheckboxCard: View {
    let goal: TriageGoal
    let isSelected: Bool
    let action: () -> Void
    
    // Choose the accent color based on the primary mapped type (Nutritionist = Blue, Fitness = Teal, etc.)
    private var primaryColor: Color {
        goal.mappedTypes.contains(.nutritionist) ? .ascendBlue :
        goal.mappedTypes.contains(.fitnessCoach) ? .vitalityTeal :
        goal.mappedTypes.contains(.wellness) ? .serenityLavender :
        Color(.systemGray)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            
            // 1. Checkbox/Circle Icon
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? primaryColor : Color(.systemGray3))
                .padding(.top, 4)
            
            // 2. Goal Title
            Text(goal.title)
                .font(.headline)
                .lineLimit(nil)
            
            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Card Styling
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            // Highlight the card if selected
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? primaryColor : Color.clear, lineWidth: isSelected ? 3 : 0)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onTapGesture(perform: action)
    }
}
