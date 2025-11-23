//
//  ViewDependencies.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Combine
import Foundation

final class ViewDependencies: ObservableObject {
    let summaryView: SummaryView
    let nutritionView: NutritionView
    let coachView: CoachView

    init(
        summaryView: SummaryView,
        nutritionView: NutritionView,
        connectView: CoachView,
    ) {
        self.summaryView = summaryView
        self.nutritionView = nutritionView
        self.coachView = connectView
    }

    public static func build(viewModelDependencies: ViewModelAppDependencies)
        -> ViewDependencies
    {

        let summaryView = SummaryView(
            profileViewModel: viewModelDependencies.profileViewModel,
            summaryViewModel: viewModelDependencies.summaryViewModel,
            bodyMassEntryViewModel: viewModelDependencies
                .bodyMassEntryViewModel,
            bodyMassDetailViewModel: viewModelDependencies
                .bodyMassDetailViewModel,
            moodEntryViewModel: viewModelDependencies.moodEntryViewModel,
            moodDetailViewModel: viewModelDependencies.moodDetailViewModel,
            nutritionSummaryViewModel: viewModelDependencies
                .nutritionSummaryViewModel,
            sleepDetailViewModel: viewModelDependencies.sleepDetailViewModel,
            heartRateDetailViewModel: viewModelDependencies.heartRateDetailViewModel,
            stepsDetailViewModel: viewModelDependencies.stepsDetailViewModel
        )

        let nutritionView = NutritionView(
            nutritionViewModel: viewModelDependencies.nutritionViewModel,
            addMealViewModel: viewModelDependencies.addMealViewModel,
            quickSelectViewModel: viewModelDependencies.mealQuickSelectViewModel,
            photoRecognitionViewModel: viewModelDependencies.photoRecognitionViewModel
        )

        let coachView = CoachView(
            viewModel: viewModelDependencies.coachViewModel
        )

        return ViewDependencies(
            summaryView: summaryView,
            nutritionView: nutritionView,
            connectView: coachView
        )
    }
}
