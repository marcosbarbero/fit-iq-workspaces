//
//  AddWorkoutViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//


import Foundation
import Observation
import SwiftUI

// Structs to hold conditional settings
struct StrengthConfig: Identifiable {
    let id = UUID()
    var defaultRestSeconds: Int = 90
    var defaultSets: Int = 3
}

struct CardioConfig: Identifiable {
    let id = UUID()
    var targetPace: String = "6:00 min/km"
    var intervalTimeSeconds: Int = 300 // 5 minutes
}

// Data Model for an Exercise in the Plan (Needs to be flexible)
struct PlanExercise: Identifiable {
    let id = UUID()
    var name: String
    var sets: Int = 3
    var reps: Int? = 10
    var timeSeconds: Int? = nil // Used for Cardio/Mobility
    var loadKg: Double? = nil
}

@Observable
final class AddWorkoutViewModel {
    
    // Core Routine Metadata
    var name: String = "New Custom Routine"
    var selectedCategory: WorkoutCategory = .strength // Default to strength
    var estimatedDurationMinutes: Int = 45
    var equipmentRequired: Bool = true
    
    // Conditional Configuration States
    var strengthConfig = StrengthConfig()
    var cardioConfig = CardioConfig()
    
    // Exercise List
    var plannedExercises: [PlanExercise] = []
    
    // Assumed UseCase dependency for saving data (Hex Arch)
    // private let saveWorkoutTemplateUseCase: SaveWorkoutTemplateUseCaseProtocol

    init() {
        // Mock a starting exercise for visual demonstration
        plannedExercises = [
            PlanExercise(name: "Barbell Squat", sets: 3, reps: 8, loadKg: 100),
            PlanExercise(name: "Bench Press", sets: 3, reps: 10, loadKg: 60)
        ]
    }
    
    // Logic to call Use Case (Mock)
    func saveWorkoutPlan() {
        // 🛑 Hex Arch: This would call the Use Case to transform the view data
        // into a Domain Entity and save it.
        print("Saving new plan: \(name), Category: \(selectedCategory.rawValue), Exercises: \(plannedExercises.count)")
    }
}
