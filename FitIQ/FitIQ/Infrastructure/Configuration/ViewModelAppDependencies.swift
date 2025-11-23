//
//  ViewAppDependencies.swift
//  FitIQ
//
//  Created by Marcos Barbero on 15/10/2025.
//

import Combine
import Foundation

/// This class is responsible for managing and providing dependencies required by various views in the application.
/// The separation of view dependencies into this class helps in maintaining a clean architecture, and enables lazy loading and easy testing of view-related services.

class ViewModelAppDependencies: ObservableObject {
    let appDependencies: AppDependencies
    let authManager: AuthManager

    // MARK: - Summary
    let summaryViewModel: SummaryViewModel
    let profileViewModel: ProfileViewModel
    let bodyMassEntryViewModel: BodyMassEntryViewModel
    let bodyMassDetailViewModel: BodyMassDetailViewModel
    let moodEntryViewModel: MoodEntryViewModel
    let moodDetailViewModel: MoodDetailViewModel
    let nutritionSummaryViewModel: NutritionSummaryViewModel
    let sleepDetailViewModel: SleepDetailViewModel
    let heartRateDetailViewModel: HeartRateDetailViewModel
    let stepsDetailViewModel: StepsDetailViewModel

    // MARK: - Nutrition
    let nutritionViewModel: NutritionViewModel
    let addMealViewModel: AddMealViewModel
    let mealQuickSelectViewModel: MealQuickSelectViewModel
    let photoRecognitionViewModel: PhotoRecognitionViewModel

    // MARK: - Coach
    let coachViewModel: CoachViewModel

    private init(
        appDependencies: AppDependencies,
        authManager: AuthManager,
        summaryViewModel: SummaryViewModel,
        profileViewModel: ProfileViewModel,
        bodyMassEntryViewModel: BodyMassEntryViewModel,
        bodyMassDetailViewModel: BodyMassDetailViewModel,
        moodEntryViewModel: MoodEntryViewModel,
        moodDetailViewModel: MoodDetailViewModel,
        nutritionSummaryViewModel: NutritionSummaryViewModel,
        sleepDetailViewModel: SleepDetailViewModel,
        heartRateDetailViewModel: HeartRateDetailViewModel,
        stepsDetailViewModel: StepsDetailViewModel,
        nutritionViewModel: NutritionViewModel,
        addMealViewModel: AddMealViewModel,
        mealQuickSelectViewModel: MealQuickSelectViewModel,
        photoRecognitionViewModel: PhotoRecognitionViewModel,
        coachViewModel: CoachViewModel,
    ) {
        self.appDependencies = appDependencies
        self.authManager = authManager
        self.summaryViewModel = summaryViewModel
        self.profileViewModel = profileViewModel
        self.bodyMassEntryViewModel = bodyMassEntryViewModel
        self.bodyMassDetailViewModel = bodyMassDetailViewModel
        self.moodEntryViewModel = moodEntryViewModel
        self.moodDetailViewModel = moodDetailViewModel
        self.nutritionSummaryViewModel = nutritionSummaryViewModel
        self.sleepDetailViewModel = sleepDetailViewModel
        self.heartRateDetailViewModel = heartRateDetailViewModel
        self.stepsDetailViewModel = stepsDetailViewModel
        self.nutritionViewModel = nutritionViewModel
        self.addMealViewModel = addMealViewModel
        self.mealQuickSelectViewModel = mealQuickSelectViewModel
        self.photoRecognitionViewModel = photoRecognitionViewModel
        self.coachViewModel = coachViewModel
    }

    public static func build(authManager: AuthManager, appDependencies: AppDependencies)
        -> ViewModelAppDependencies
    {
        let summaryViewModel = SummaryViewModel(
            getLatestBodyMetricsUseCase: appDependencies.getLatestBodyMetricsUseCase,
            getHistoricalWeightUseCase: appDependencies.getHistoricalWeightUseCase,
            authManager: authManager,
            getHistoricalMoodUseCase: appDependencies.getHistoricalMoodUseCase,
            getLatestHeartRateUseCase: appDependencies.getLatestHeartRateUseCase,
            getLast8HoursHeartRateUseCase: appDependencies.getLast8HoursHeartRateUseCase,
            getLast8HoursStepsUseCase: appDependencies.getLast8HoursStepsUseCase,
            getLast5WeightsForSummaryUseCase: appDependencies.getLast5WeightsForSummaryUseCase,
            getLatestSleepForSummaryUseCase: appDependencies.getLatestSleepForSummaryUseCase,
            getDailyStepsTotalUseCase: appDependencies.getDailyStepsTotalUseCase,
            processDailyHealthDataUseCase: appDependencies.processDailyHealthDataUseCase,
            localDataChangePublisher: appDependencies.localDataChangePublisher  // NEW: For live updates
        )

        // NEW: Instantiate CloudDataManager using the app's ModelContainer
        let cloudDataManager = CloudDataManager(modelContainer: appDependencies.modelContainer)

        // NEW: Instantiate ProfileViewModel with its dependencies
        let profileViewModel = ProfileViewModel(
            getPhysicalProfileUseCase: appDependencies.getPhysicalProfileUseCase,
            updateUserProfileUseCase: appDependencies.updateUserProfileUseCase,
            updateProfileMetadataUseCase: appDependencies.updateProfileMetadataUseCase,
            updatePhysicalProfileUseCase: appDependencies.updatePhysicalProfileUseCase,
            userProfileStorage: appDependencies.userProfileStorage,
            authManager: authManager,
            cloudDataManager: cloudDataManager,
            getLatestHealthKitMetrics: appDependencies.getLatestBodyMetricsUseCase,
            healthRepository: appDependencies.healthRepository,
            syncBiologicalSexFromHealthKitUseCase: appDependencies
                .syncBiologicalSexFromHealthKitUseCase,
            deleteAllUserDataUseCase: appDependencies.deleteAllUserDataUseCase,
            healthKitAuthUseCase: appDependencies.healthKitAuthUseCase
        )

        let bodyMassEntryViewModel = BodyMassEntryViewModel(
            saveBodyMassUseCase: appDependencies.saveBodyMassUseCase,
            getLatestBodyMetricsUseCase: appDependencies.getLatestBodyMetricsUseCase
        )

        let bodyMassDetailViewModel = BodyMassDetailViewModel(
            getHistoricalWeightUseCase: appDependencies.getHistoricalWeightUseCase,
            authManager: authManager,
            healthRepository: appDependencies.healthRepository,
            forceHealthKitResyncUseCase: appDependencies.forceHealthKitResyncUseCase
        )

        let moodEntryViewModel = MoodEntryViewModel(
            saveMoodProgressUseCase: appDependencies.saveMoodProgressUseCase
        )

        let moodDetailViewModel = MoodDetailViewModel(
            getHistoricalMoodUseCase: appDependencies.getHistoricalMoodUseCase
        )

        let nutritionSummaryViewModel = NutritionSummaryViewModel(
            getTodayWaterIntakeUseCase: appDependencies.getTodayWaterIntakeUseCase
        )

        let sleepDetailViewModel = SleepDetailViewModel(
            sleepRepository: appDependencies.sleepRepository,
            authManager: authManager
        )

        let heartRateDetailViewModel = HeartRateDetailViewModel(
            progressRepository: appDependencies.progressRepository,
            authManager: authManager
        )

        let stepsDetailViewModel = StepsDetailViewModel(
            progressRepository: appDependencies.progressRepository,
            authManager: authManager
        )

        let nutritionViewModel = NutritionViewModel(
            saveMealLogUseCase: appDependencies.saveMealLogUseCase,
            getMealLogsUseCase: appDependencies.getMealLogsUseCase,
            updateMealLogStatusUseCase: appDependencies.updateMealLogStatusUseCase,
            syncPendingMealLogsUseCase: appDependencies.syncPendingMealLogsUseCase,
            deleteMealLogUseCase: appDependencies.deleteMealLogUseCase,
            webSocketService: appDependencies.mealLogWebSocketService,
            authManager: authManager,
            outboxProcessor: appDependencies.outboxProcessorService,
            saveWaterProgressUseCase: appDependencies.saveWaterProgressUseCase,
            nutritionSummaryViewModel: nutritionSummaryViewModel
        )

        // 🛑 FIX: Inject MockLogMealUseCase into AddMealViewModel
        let addMealViewModel = AddMealViewModel()

        let mealQuickSelectViewModel = MealQuickSelectViewModel()

        let photoRecognitionViewModel = PhotoRecognitionViewModel(
            uploadMealPhotoUseCase: appDependencies.uploadMealPhotoUseCase,
            getPhotoRecognitionUseCase: appDependencies.getPhotoRecognitionUseCase,
            confirmPhotoRecognitionUseCase: appDependencies.confirmPhotoRecognitionUseCase
        )

        let coachViewModel = CoachViewModel()

        return ViewModelAppDependencies(
            appDependencies: appDependencies,
            authManager: authManager,
            summaryViewModel: summaryViewModel,
            profileViewModel: profileViewModel,
            bodyMassEntryViewModel: bodyMassEntryViewModel,
            bodyMassDetailViewModel: bodyMassDetailViewModel,
            moodEntryViewModel: moodEntryViewModel,
            moodDetailViewModel: moodDetailViewModel,
            nutritionSummaryViewModel: nutritionSummaryViewModel,
            sleepDetailViewModel: sleepDetailViewModel,
            heartRateDetailViewModel: heartRateDetailViewModel,
            stepsDetailViewModel: stepsDetailViewModel,
            nutritionViewModel: nutritionViewModel,
            addMealViewModel: addMealViewModel,
            mealQuickSelectViewModel: mealQuickSelectViewModel,
            photoRecognitionViewModel: photoRecognitionViewModel,
            coachViewModel: coachViewModel
        )
    }
}
