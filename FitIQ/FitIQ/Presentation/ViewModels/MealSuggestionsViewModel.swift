//
//  MealSuggestionsViewModel.swift
//  HealthRestart
//
//  Created by Marcos Barbero on 26/09/2025.
//

import Foundation
import Combine



@MainActor
final class MealSuggestionsViewModel: ObservableObject {
    @Published var suggestions: [MealSuggestion] = []
    @Published var isLoading = false

//    private let suggestionsRepo: SuggestedMealsRepository
//    private let aiAdapter: OpenAIAdviceAdapter
//    private let nutritionVM: NutritionViewModel // or NutritionService port

    init(
//        suggestionsRepo: SuggestedMealsRepository,
//        aiAdapter: OpenAIAdviceAdapter,
//        nutritionVM: NutritionViewModel
    ) {
//        self.suggestionsRepo = suggestionsRepo
//        self.aiAdapter = aiAdapter
//        self.nutritionVM = nutritionVM
    }

    func refresh() async {
//        isLoading = true
//        do {
//            // First try local cache
//            let cached = try await suggestionsRepo.loadSuggestions()
//            if !cached.isEmpty {
//                suggestions = cached
//                isLoading = false
//                return
//            }
//
//            // Otherwise ask AI (pass user restrictions / goals)
//            // Here you should fetch real data: dailyGoal / last meals / restrictions from user profile
//            let request = MealSuggestionRequest(goalDescription: nil, dailyTargets: nil, restrictions: nil, recentMealsSummary: nil, locale: Locale.current.identifier)
//            let response = try await aiAdapter.requestSuggestions(request: request)
//            suggestions = response.suggestions
//            try await suggestionsRepo.saveSuggestions(response.suggestions)
//        } catch {
//            print("MealSuggestionsViewModel.refresh error: \(error)")
//            suggestions = []
//        }
//        isLoading = false
        print("MealSuggestionsViewModel.refresh is currently disabled.")
    }

    // Convert suggestion into a saved MealGroup using your existing flow
    func saveSuggestionAsMeal(suggestion: MealSuggestion, rawInput: String, items: [SuggestedFoodItem]) async {
        // Build MealGroup + call NutritionService/Repository pipeline
        // I assume you have NutritionViewModel.addMeal(text:mealType:date:) — adapt if needed.
//        await nutritionVM.addMeal(text: rawInput, mealType: .other, date: Date())
//        
//        // Optionally clear suggestion cache
//        try? await suggestionsRepo.deleteSuggestion(id: suggestion.id)
        print("MealSuggestionsViewModel.saveSuggestionAsMeal is currently disabled.")
    }
}
