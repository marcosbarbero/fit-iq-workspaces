//
//  NutritionSummaryViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Foundation
import Observation
import SwiftUI  // For Color usage in mock

// Mock structure for macro nutrient goals and current consumption
struct MacroSnapshot {
    let name: String
    let current: Double
    let goal: Double
    let unit: String
    let color: Color
}

@Observable
final class NutritionSummaryViewModel {

    // Total calorie intake goal (from nutrition plan)
    var intakeGoal: Int = 2500
    var caloriesConsumed: Int = 1150

    var caloriesBurned: Int = 2800  // Mock burned
    var netGoal: Int = -700  // Mock target deficit

    var macros: [MacroSnapshot] = []

    // Water intake tracking
    var waterIntakeLiters: Double = 0.0  // Current water intake in liters
    var waterGoalLiters: Double = 2.5  // Daily water goal in liters (default 2.5L)

    // Dependencies
    private let getTodayWaterIntakeUseCase: GetTodayWaterIntakeUseCase

    var netCalories: Int {
        // net calories = consumed - burned
        caloriesConsumed - caloriesBurned
    }

    init(getTodayWaterIntakeUseCase: GetTodayWaterIntakeUseCase) {
        self.getTodayWaterIntakeUseCase = getTodayWaterIntakeUseCase

        loadMockData()

        // Load water intake from local storage
        Task {
            await loadWaterIntake()
        }
    }

    @MainActor
    func loadMockData() {
        self.macros = [
            MacroSnapshot(
                name: "Protein", current: 75, goal: 150, unit: "g", color: Color.sustenanceYellow),
            MacroSnapshot(
                name: "Carbs", current: 120, goal: 250, unit: "g", color: Color.vitalityTeal),
            MacroSnapshot(
                name: "Fat", current: 30, goal: 60, unit: "g", color: Color.serenityLavender),
        ]

        self.caloriesConsumed = 1150
        self.intakeGoal = 2500

        // Mock values for Net Calories
        self.caloriesBurned = 2800
        self.netGoal = -700
    }

    // Derived property for quick calculation (Used in FullWidthNutritionCard)
    var caloriesRemaining: Int {
        max(0, intakeGoal - caloriesConsumed)
    }

    // Water intake formatted for display
    var waterIntakeFormatted: String {
        String(format: "%.1f", waterIntakeLiters)
    }

    var waterGoalFormatted: String {
        String(format: "%.1f", waterGoalLiters)
    }

    // Water intake percentage (0.0 to 1.0)
    var waterIntakeProgress: Double {
        guard waterGoalLiters > 0 else { return 0 }
        return min(waterIntakeLiters / waterGoalLiters, 1.0)
    }

    // MARK: - Data Loading

    /// Load today's water intake from local storage (LOCAL-FIRST)
    @MainActor
    func loadWaterIntake() async {
        do {
            // Fetch from LOCAL storage (source of truth)
            let todayWaterLiters = try await getTodayWaterIntakeUseCase.execute()

            self.waterIntakeLiters = todayWaterLiters

            print(
                "NutritionSummaryViewModel: Loaded water intake: \(String(format: "%.2f", todayWaterLiters))L"
            )
        } catch {
            print("NutritionSummaryViewModel: Failed to load water intake: \(error)")
            // Keep current value on error (don't reset to 0)
        }
    }
}
