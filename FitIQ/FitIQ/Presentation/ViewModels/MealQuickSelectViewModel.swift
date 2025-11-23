//
//  QuickSelectViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import Observation

struct MealTemplate: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
}

@Observable
final class MealQuickSelectViewModel {
    var isLoading: Bool = false
    var templates: [MealTemplate] = [
        MealTemplate(name: "Morning Protein Shake", calories: 310),
        MealTemplate(name: "Standard Lunch Salad", calories: 480),
        MealTemplate(name: "Post-Workout Banana", calories: 105),
    ]
    
    // In a real app, this would fetch from MealRepository/Templates
    init() {}
}
