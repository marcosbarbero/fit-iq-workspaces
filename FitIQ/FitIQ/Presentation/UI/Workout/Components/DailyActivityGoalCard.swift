//
//  DailyActivityGoalCard.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

struct DailyActivityGoalCard: View {
    @Bindable var viewModel: WorkoutViewModel
    
    private let primaryColor = Color.vitalityTeal // Fitness Theme
    
    
    var body: some View {
        HStack(spacing: 20) {
            
            // 1. Multi-Ring Gauge (Visual Status)
            MultiRingActivityGauge(rings: viewModel.ringData)
            
            // 2. Metrics and Streak
            // 2. Metrics and Details (Right Panel)
            VStack(alignment: .leading, spacing: 10) {
                
                // Streak is the general health indicator
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.vitalityTeal)
                    Text("\(viewModel.activityGoals.streakDays) Day Streak")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Divider() // Separator for clarity
                
                // Details for each Ring
                ForEach(viewModel.ringData) { ring in
                    ActivityRingDetailRow(ring: ring)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20) // MARK: - CHANGE: Consistent 20pt padding
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        // REMOVED: .padding(.horizontal) - This is now handled by the List's layout and the card's internal padding
    }
}

// New Helper: Row for displaying ring details
struct ActivityRingDetailRow: View {
    let ring: ActivityRingSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(ring.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(ring.color)
                
                Spacer()
                
                // Show completion status (Goal Met vs. Progress)
                Text(ring.progress >= 1.0 ? "GOAL MET" : "\(Int(ring.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ring.progress >= 1.0 ? .growthGreen : .secondary)
            }
            
            // Current / Goal amount
            Text("\(Int(ring.current)) / \(Int(ring.goal)) \(ring.unit)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
