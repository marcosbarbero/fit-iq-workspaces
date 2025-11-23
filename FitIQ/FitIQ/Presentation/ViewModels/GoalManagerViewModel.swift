//
//  GoalManagerViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//


import Foundation
import Observation

// Mock structure for a long-term goal
struct LongTermGoal: Identifiable {
    let id = UUID()
    let name: String
    let target: Double // e.g., 5.0 kg
    let current: Double // e.g., 3.7 kg
    let unit: String
    let deadline: Date?
}

@Observable
final class GoalManagerViewModel {
    var isLoading: Bool = false
    
    // Primary L/T Goals (Weight/Performance)
    var primaryGoals: [LongTermGoal] = [
        LongTermGoal(name: "Weight Loss Target", target: 5.0, current: 3.7, unit: "kg", deadline: Calendar.current.date(byAdding: .month, value: 2, to: Date())!),
        LongTermGoal(name: "Increase Bench Press", target: 100, current: 85, unit: "kg", deadline: nil)
    ]
    
    // Custom Daily Habit Goals (Water, Steps, Meditation, etc.)
    // This model needs to integrate with the Habit Tracker system planned earlier.
    // For now, simple mockup:
    var customHabits: [ActivityRingSnapshot] = [
        ActivityRingSnapshot(name: "Water Intake", current: 2.5, goal: 3.0, unit: "L", color: .ascendBlue),
        ActivityRingSnapshot(name: "Steps", current: 9000, goal: 10000, unit: "steps", color: .vitalityTeal),
        // Assuming ActivityRingSnapshot structure is available
    ]
    
    // ... load logic, etc.
    init() {}
}
