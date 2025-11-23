//
//  CompletedWorkoutDetailView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI
import Charts

struct CompletedWorkoutDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    let log: CompletedWorkout
    
    private let primaryColor = Color.vitalityTeal
    
    private var isAppLogged: Bool { log.source == .appLogged }
    
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    SessionMetricsCard(log: log)
                        .padding(.horizontal)
                    
                    WorkoutPlanBreakdown(exercises: log.exercises)
                        .padding(.horizontal)
                    
                    // MARK: 3. Performance/Data Insights (Mock Chart)
                    VStack(alignment: .leading) {
                        Text("Performance & Heart Rate")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        PerformanceChart(durationMinutes: log.durationMinutes, color: primaryColor)
                            .frame(height: 200)
                            .padding(.horizontal)
                    }
                    
                    // MARK: 4. Action Buttons (Conditional Edit/Delete)
                    ActionFooter(isAppLogged: isAppLogged)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle(log.name)
            .toolbar {
                // Toolbar Item 1: Close Button (remains the same)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                // 🛑 NEW: Custom Title View in the center (.principal placement)
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: isAppLogged ? "appclip" : "inset.filled.applewatch.case")
                            .foregroundColor(isAppLogged ? primaryColor : .secondary)
                        
                        Text(log.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(1) // Ensure it fits cleanly
                    }
                }
            }
        }
    }
}
