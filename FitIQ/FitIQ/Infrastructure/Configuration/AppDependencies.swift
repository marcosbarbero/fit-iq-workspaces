//
//  AppDependencies.swift
//  FitIQ
//
//  Created by Marcos Barbero on 10/10/2025.
//

import BackgroundTasks
import Combine
import FitIQCore
import Foundation
import HealthKit
import SwiftData
import SwiftUI

/// A class to hold all dependencies for the application.

class AppDependencies: ObservableObject {

    let modelContainer: ModelContainer
    let networkClient: NetworkClientProtocol
    let registerUserUseCase: RegisterUserUseCaseProtocol
    let loginUserUseCase: LoginUserUseCaseProtocol
    let authRepository: AuthRepositoryProtocol
    let healthRepository: HealthRepositoryProtocol
    let healthKitAuthUseCase: RequestHealthKitAuthorizationUseCase
    let getLatestBodyMetricsUseCase: GetLatestBodyMetricsUseCase
    let getHistoricalBodyMassUseCase: GetHistoricalBodyMassUseCase
    let userProfileStorage: UserProfileStoragePortProtocol
    let authTokenPersistence: AuthTokenPersistencePortProtocol
    let tokenRefreshClient: TokenRefreshClient
    let healthDataSyncService: HealthDataSyncOrchestrator
    let backgroundOperations: BackgroundOperationsProtocol
    let backgroundSyncManager: BackgroundSyncManagerProtocol
    let activitySnapshotRepository: ActivitySnapshotRepositoryProtocol
    let getLatestActivitySnapshotUseCase: GetLatestActivitySnapshotUseCaseProtocol
    let localHealthDataStore: LocalHealthDataStorePort

    let activitySnapshotEventPublisher: ActivitySnapshotEventPublisherProtocol
    let userHasHealthKitAuthorizationUseCase: UserHasHealthKitAuthorizationUseCase
    let performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol
    let performInitialDataLoadUseCase: PerformInitialDataLoadUseCase

    let localDataChangePublisher: LocalDataChangePublisherProtocol
    let localDataChangeMonitor: LocalDataChangeMonitor

    let remoteSyncService: RemoteSyncServiceProtocol

    let processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol
    let processConsolidatedDailyHealthDataUseCase: ProcessConsolidatedDailyHealthDataUseCaseProtocol

    // NEW: SaveBodyMassUseCase. This is a domain-level use case.
    let saveBodyMassUseCase: SaveBodyMassUseCaseProtocol

    // User Profile Management
    let updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol
    let userProfileRepository: UserProfileRepositoryProtocol
    let updateProfileMetadataUseCase: UpdateProfileMetadataUseCase
    let profileEventPublisher: ProfileEventPublisherProtocol
    let profileSyncService: ProfileSyncServiceProtocol
    let healthKitProfileSyncService: HealthKitProfileSyncServiceProtocol
    let profileMetadataClient: UserProfileMetadataClient

    // NEW: Progress Tracking
    let progressRepository: ProgressRepositoryProtocol
    let logHeightProgressUseCase: LogHeightProgressUseCase
    let saveStepsProgressUseCase: SaveStepsProgressUseCase
    let saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase
    let saveWeightProgressUseCase: SaveWeightProgressUseCase
    let getHistoricalWeightUseCase: GetHistoricalWeightUseCase

    // NEW: Mood Tracking
    let saveMoodProgressUseCase: SaveMoodProgressUseCase
    let getHistoricalMoodUseCase: GetHistoricalMoodUseCase
    let getLatestHeartRateUseCase: GetLatestHeartRateUseCase

    // NEW: Water Intake Tracking
    let saveWaterProgressUseCase: SaveWaterProgressUseCase
    let getTodayWaterIntakeUseCase: GetTodayWaterIntakeUseCase

    // SUMMARY-SPECIFIC: Use cases for fetching only the data needed for summary cards
    let getLast8HoursHeartRateUseCase: GetLast8HoursHeartRateUseCase
    let getLast8HoursStepsUseCase: GetLast8HoursStepsUseCase
    let getLast5WeightsForSummaryUseCase: GetLast5WeightsForSummaryUseCase
    let getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase

    // NEW: HealthKit Sync
    let syncBiologicalSexFromHealthKitUseCase: SyncBiologicalSexFromHealthKitUseCase

    // NEW: Delete All User Data
    let deleteAllUserDataUseCase: DeleteAllUserDataUseCase

    // NEW: Force HealthKit Re-sync
    let forceHealthKitResyncUseCase: ForceHealthKitResyncUseCase

    // NEW: Cleanup Orphaned Outbox Events
    let cleanupOrphanedOutboxEventsUseCase: CleanupOrphanedOutboxEventsUseCase

    // NEW: Debug Outbox Status
    let debugOutboxStatusUseCase: DebugOutboxStatusUseCase

    // NEW: Emergency Cleanup Outbox
    let emergencyCleanupOutboxUseCase: EmergencyCleanupOutboxUseCase

    // NEW: Outbox Pattern
    let outboxRepository: OutboxRepositoryProtocol
    let outboxProcessorService: OutboxProcessorService

    // NEW: Sleep Tracking
    let sleepRepository: SleepRepositoryProtocol
    let sleepAPIClient: SleepAPIClientProtocol
    let getLatestSleepForSummaryUseCase: GetLatestSleepForSummaryUseCase

    // NEW: Meal Logging / Nutrition Tracking
    let mealLogLocalRepository: MealLogLocalStorageProtocol
    let nutritionAPIClient: MealLogRemoteAPIProtocol
    let mealLogRepository: MealLogRepositoryProtocol
    let saveMealLogUseCase: SaveMealLogUseCase
    let getMealLogsUseCase: GetMealLogsUseCase
    let updateMealLogStatusUseCase: UpdateMealLogStatusUseCase
    let syncPendingMealLogsUseCase: SyncPendingMealLogsUseCase
    let deleteMealLogUseCase: DeleteMealLogUseCase
    let mealLogWebSocketClient: MealLogWebSocketProtocol
    let mealLogWebSocketService: MealLogWebSocketService

    // MARK: - Photo Recognition (Meal Logging via Photo)
    let photoRecognitionRepository: PhotoRecognitionRepositoryProtocol
    let photoRecognitionAPIClient: PhotoRecognitionAPIProtocol
    let uploadMealPhotoUseCase: UploadMealPhotoUseCase
    let getPhotoRecognitionUseCase: GetPhotoRecognitionUseCase
    let confirmPhotoRecognitionUseCase: ConfirmPhotoRecognitionUseCase

    // NEW: Workout Tracking
    let workoutRepository: WorkoutRepositoryProtocol
    let workoutAPIClient: WorkoutAPIClientProtocol
    let saveWorkoutUseCase: SaveWorkoutUseCase
    let getHistoricalWorkoutsUseCase: GetHistoricalWorkoutsUseCase
    let fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase

    // NEW: Workout Template Management
    let workoutTemplateRepository: WorkoutTemplateRepositoryProtocol
    let workoutTemplateAPIClient: WorkoutTemplateAPIClientProtocol
    let fetchWorkoutTemplatesUseCase: FetchWorkoutTemplatesUseCase
    let syncWorkoutTemplatesUseCase: SyncWorkoutTemplatesUseCase
    let createWorkoutTemplateUseCase: CreateWorkoutTemplateUseCase
    let shareWorkoutTemplateUseCase: ShareWorkoutTemplateUseCase
    let revokeTemplateShareUseCase: RevokeTemplateShareUseCase
    let fetchSharedWithMeTemplatesUseCase: FetchSharedWithMeTemplatesUseCase
    let copyWorkoutTemplateUseCase: CopyWorkoutTemplateUseCase
    let startWorkoutSessionUseCase: StartWorkoutSessionUseCase
    let completeWorkoutSessionUseCase: CompleteWorkoutSessionUseCase

    // NEW: Progressive Historical Sync Service
    let progressiveHistoricalSyncService: ProgressiveHistoricalSyncServiceProtocol

    // NEW: Database Optimization
    let optimizeDatabaseUseCase: OptimizeDatabaseUseCase

    // NEW: Sync Optimization Use Cases (Hexagonal Architecture Compliance)
    let getLatestProgressEntryDateUseCase: GetLatestProgressEntryDateUseCase
    let shouldSyncMetricUseCase: ShouldSyncMetricUseCase
    let getLatestSleepSessionDateUseCase: GetLatestSleepSessionDateUseCase
    let shouldSyncSleepUseCase: ShouldSyncSleepUseCase

    let authManager: AuthManager

    init(
        modelContainer: ModelContainer,
        networkClient: NetworkClientProtocol,
        registerUserUseCase: RegisterUserUseCaseProtocol,
        loginUserUseCase: LoginUserUseCaseProtocol,
        authRepository: AuthRepositoryProtocol,
        healthRepository: HealthRepositoryProtocol,
        healthKitAuthUseCase: RequestHealthKitAuthorizationUseCase,
        getLatestBodyMetricsUseCase: GetLatestBodyMetricsUseCase,
        getHistoricalBodyMassUseCase: GetHistoricalBodyMassUseCase,
        userProfileStorage: UserProfileStoragePortProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        tokenRefreshClient: TokenRefreshClient,
        healthDataSyncService: HealthDataSyncOrchestrator,
        backgroundOperations: BackgroundOperationsProtocol,
        backgroundSyncManager: BackgroundSyncManagerProtocol,
        activitySnapshotRepository: ActivitySnapshotRepositoryProtocol,
        getLatestActivitySnapshotUseCase: GetLatestActivitySnapshotUseCaseProtocol,
        localHealthDataStore: LocalHealthDataStorePort,
        activitySnapshotEventPublisher: ActivitySnapshotEventPublisherProtocol,
        userHasHealthKitAuthorizationUseCase: UserHasHealthKitAuthorizationUseCase,
        authManager: AuthManager,
        performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol,
        performInitialDataLoadUseCase: PerformInitialDataLoadUseCase,
        localDataChangePublisher: LocalDataChangePublisherProtocol,
        localDataChangeMonitor: LocalDataChangeMonitor,
        remoteSyncService: RemoteSyncServiceProtocol,
        processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol,
        processConsolidatedDailyHealthDataUseCase:
            ProcessConsolidatedDailyHealthDataUseCaseProtocol,
        saveBodyMassUseCase: SaveBodyMassUseCaseProtocol,
        updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol,
        userProfileRepository: UserProfileRepositoryProtocol,
        updateProfileMetadataUseCase: UpdateProfileMetadataUseCase,
        profileEventPublisher: ProfileEventPublisherProtocol,
        profileSyncService: ProfileSyncServiceProtocol,
        healthKitProfileSyncService: HealthKitProfileSyncServiceProtocol,
        profileMetadataClient: UserProfileMetadataClient,
        progressRepository: ProgressRepositoryProtocol,
        logHeightProgressUseCase: LogHeightProgressUseCase,
        saveStepsProgressUseCase: SaveStepsProgressUseCase,
        saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase,
        saveWeightProgressUseCase: SaveWeightProgressUseCase,
        getHistoricalWeightUseCase: GetHistoricalWeightUseCase,
        saveMoodProgressUseCase: SaveMoodProgressUseCase,
        getHistoricalMoodUseCase: GetHistoricalMoodUseCase,
        getLatestHeartRateUseCase: GetLatestHeartRateUseCase,
        saveWaterProgressUseCase: SaveWaterProgressUseCase,
        getTodayWaterIntakeUseCase: GetTodayWaterIntakeUseCase,
        getLast8HoursHeartRateUseCase: GetLast8HoursHeartRateUseCase,
        getLast8HoursStepsUseCase: GetLast8HoursStepsUseCase,
        getLast5WeightsForSummaryUseCase: GetLast5WeightsForSummaryUseCase,
        getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase,
        syncBiologicalSexFromHealthKitUseCase: SyncBiologicalSexFromHealthKitUseCase,
        deleteAllUserDataUseCase: DeleteAllUserDataUseCase,
        forceHealthKitResyncUseCase: ForceHealthKitResyncUseCase,
        outboxRepository: OutboxRepositoryProtocol,
        outboxProcessorService: OutboxProcessorService,
        sleepRepository: SleepRepositoryProtocol,
        sleepAPIClient: SleepAPIClientProtocol,
        getLatestSleepForSummaryUseCase: GetLatestSleepForSummaryUseCase,
        mealLogLocalRepository: MealLogLocalStorageProtocol,
        nutritionAPIClient: MealLogRemoteAPIProtocol,
        mealLogRepository: MealLogRepositoryProtocol,
        saveMealLogUseCase: SaveMealLogUseCase,
        getMealLogsUseCase: GetMealLogsUseCase,
        updateMealLogStatusUseCase: UpdateMealLogStatusUseCase,
        syncPendingMealLogsUseCase: SyncPendingMealLogsUseCase,
        deleteMealLogUseCase: DeleteMealLogUseCase,
        mealLogWebSocketClient: MealLogWebSocketProtocol,
        mealLogWebSocketService: MealLogWebSocketService,
        photoRecognitionRepository: PhotoRecognitionRepositoryProtocol,
        photoRecognitionAPIClient: PhotoRecognitionAPIProtocol,
        uploadMealPhotoUseCase: UploadMealPhotoUseCase,
        getPhotoRecognitionUseCase: GetPhotoRecognitionUseCase,
        confirmPhotoRecognitionUseCase: ConfirmPhotoRecognitionUseCase,
        workoutRepository: WorkoutRepositoryProtocol,
        workoutAPIClient: WorkoutAPIClientProtocol,
        saveWorkoutUseCase: SaveWorkoutUseCase,
        getHistoricalWorkoutsUseCase: GetHistoricalWorkoutsUseCase,
        fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase,
        workoutTemplateRepository: WorkoutTemplateRepositoryProtocol,
        workoutTemplateAPIClient: WorkoutTemplateAPIClientProtocol,
        fetchWorkoutTemplatesUseCase: FetchWorkoutTemplatesUseCase,
        syncWorkoutTemplatesUseCase: SyncWorkoutTemplatesUseCase,
        createWorkoutTemplateUseCase: CreateWorkoutTemplateUseCase,
        shareWorkoutTemplateUseCase: ShareWorkoutTemplateUseCase,
        revokeTemplateShareUseCase: RevokeTemplateShareUseCase,
        fetchSharedWithMeTemplatesUseCase: FetchSharedWithMeTemplatesUseCase,
        copyWorkoutTemplateUseCase: CopyWorkoutTemplateUseCase,
        startWorkoutSessionUseCase: StartWorkoutSessionUseCase,
        completeWorkoutSessionUseCase: CompleteWorkoutSessionUseCase,
        progressiveHistoricalSyncService: ProgressiveHistoricalSyncServiceProtocol,
        optimizeDatabaseUseCase: OptimizeDatabaseUseCase,
        cleanupOrphanedOutboxEventsUseCase: CleanupOrphanedOutboxEventsUseCase,
        debugOutboxStatusUseCase: DebugOutboxStatusUseCase,
        emergencyCleanupOutboxUseCase: EmergencyCleanupOutboxUseCase,
        getLatestProgressEntryDateUseCase: GetLatestProgressEntryDateUseCase,
        shouldSyncMetricUseCase: ShouldSyncMetricUseCase,
        getLatestSleepSessionDateUseCase: GetLatestSleepSessionDateUseCase,
        shouldSyncSleepUseCase: ShouldSyncSleepUseCase
    ) {
        self.modelContainer = modelContainer
        self.networkClient = networkClient
        self.registerUserUseCase = registerUserUseCase
        self.loginUserUseCase = loginUserUseCase
        self.authRepository = authRepository
        self.healthRepository = healthRepository
        self.healthKitAuthUseCase = healthKitAuthUseCase
        self.getLatestBodyMetricsUseCase = getLatestBodyMetricsUseCase
        self.getHistoricalBodyMassUseCase = getHistoricalBodyMassUseCase
        self.userProfileStorage = userProfileStorage
        self.authTokenPersistence = authTokenPersistence
        self.tokenRefreshClient = tokenRefreshClient
        self.healthDataSyncService = healthDataSyncService
        self.backgroundOperations = backgroundOperations
        self.backgroundSyncManager = backgroundSyncManager
        self.activitySnapshotRepository = activitySnapshotRepository
        self.getLatestActivitySnapshotUseCase = getLatestActivitySnapshotUseCase
        self.localHealthDataStore = localHealthDataStore
        self.activitySnapshotEventPublisher = activitySnapshotEventPublisher
        self.userHasHealthKitAuthorizationUseCase = userHasHealthKitAuthorizationUseCase
        self.performInitialHealthKitSyncUseCase = performInitialHealthKitSyncUseCase
        self.performInitialDataLoadUseCase = performInitialDataLoadUseCase
        self.localDataChangePublisher = localDataChangePublisher
        self.localDataChangeMonitor = localDataChangeMonitor
        self.remoteSyncService = remoteSyncService
        self.processDailyHealthDataUseCase = processDailyHealthDataUseCase
        self.processConsolidatedDailyHealthDataUseCase = processConsolidatedDailyHealthDataUseCase
        self.saveBodyMassUseCase = saveBodyMassUseCase
        self.updateUserProfileUseCase = updateUserProfileUseCase
        self.userProfileRepository = userProfileRepository
        self.updateProfileMetadataUseCase = updateProfileMetadataUseCase
        self.profileEventPublisher = profileEventPublisher
        self.profileSyncService = profileSyncService
        self.healthKitProfileSyncService = healthKitProfileSyncService
        self.profileMetadataClient = profileMetadataClient
        self.progressRepository = progressRepository
        self.logHeightProgressUseCase = logHeightProgressUseCase
        self.saveStepsProgressUseCase = saveStepsProgressUseCase
        self.saveHeartRateProgressUseCase = saveHeartRateProgressUseCase
        self.saveWeightProgressUseCase = saveWeightProgressUseCase
        self.getHistoricalWeightUseCase = getHistoricalWeightUseCase
        self.saveMoodProgressUseCase = saveMoodProgressUseCase
        self.getHistoricalMoodUseCase = getHistoricalMoodUseCase
        self.getLatestHeartRateUseCase = getLatestHeartRateUseCase
        self.saveWaterProgressUseCase = saveWaterProgressUseCase
        self.getTodayWaterIntakeUseCase = getTodayWaterIntakeUseCase
        self.getLast8HoursHeartRateUseCase = getLast8HoursHeartRateUseCase
        self.getLast8HoursStepsUseCase = getLast8HoursStepsUseCase
        self.getLast5WeightsForSummaryUseCase = getLast5WeightsForSummaryUseCase
        self.getDailyStepsTotalUseCase = getDailyStepsTotalUseCase
        self.syncBiologicalSexFromHealthKitUseCase = syncBiologicalSexFromHealthKitUseCase
        self.deleteAllUserDataUseCase = deleteAllUserDataUseCase
        self.forceHealthKitResyncUseCase = forceHealthKitResyncUseCase
        self.outboxRepository = outboxRepository
        self.outboxProcessorService = outboxProcessorService
        self.sleepRepository = sleepRepository
        self.sleepAPIClient = sleepAPIClient
        self.getLatestSleepForSummaryUseCase = getLatestSleepForSummaryUseCase
        self.mealLogLocalRepository = mealLogLocalRepository
        self.nutritionAPIClient = nutritionAPIClient
        self.mealLogRepository = mealLogRepository
        self.saveMealLogUseCase = saveMealLogUseCase
        self.getMealLogsUseCase = getMealLogsUseCase
        self.updateMealLogStatusUseCase = updateMealLogStatusUseCase
        self.syncPendingMealLogsUseCase = syncPendingMealLogsUseCase
        self.deleteMealLogUseCase = deleteMealLogUseCase
        self.mealLogWebSocketClient = mealLogWebSocketClient
        self.mealLogWebSocketService = mealLogWebSocketService
        self.photoRecognitionRepository = photoRecognitionRepository
        self.photoRecognitionAPIClient = photoRecognitionAPIClient
        self.uploadMealPhotoUseCase = uploadMealPhotoUseCase
        self.getPhotoRecognitionUseCase = getPhotoRecognitionUseCase
        self.confirmPhotoRecognitionUseCase = confirmPhotoRecognitionUseCase
        self.workoutRepository = workoutRepository
        self.workoutAPIClient = workoutAPIClient
        self.saveWorkoutUseCase = saveWorkoutUseCase
        self.getHistoricalWorkoutsUseCase = getHistoricalWorkoutsUseCase
        self.fetchHealthKitWorkoutsUseCase = fetchHealthKitWorkoutsUseCase
        self.workoutTemplateRepository = workoutTemplateRepository
        self.workoutTemplateAPIClient = workoutTemplateAPIClient
        self.fetchWorkoutTemplatesUseCase = fetchWorkoutTemplatesUseCase
        self.syncWorkoutTemplatesUseCase = syncWorkoutTemplatesUseCase
        self.createWorkoutTemplateUseCase = createWorkoutTemplateUseCase
        self.shareWorkoutTemplateUseCase = shareWorkoutTemplateUseCase
        self.revokeTemplateShareUseCase = revokeTemplateShareUseCase
        self.fetchSharedWithMeTemplatesUseCase = fetchSharedWithMeTemplatesUseCase
        self.copyWorkoutTemplateUseCase = copyWorkoutTemplateUseCase
        self.startWorkoutSessionUseCase = startWorkoutSessionUseCase
        self.completeWorkoutSessionUseCase = completeWorkoutSessionUseCase
        self.progressiveHistoricalSyncService = progressiveHistoricalSyncService
        self.optimizeDatabaseUseCase = optimizeDatabaseUseCase
        self.cleanupOrphanedOutboxEventsUseCase = cleanupOrphanedOutboxEventsUseCase
        self.debugOutboxStatusUseCase = debugOutboxStatusUseCase
        self.emergencyCleanupOutboxUseCase = emergencyCleanupOutboxUseCase
        self.getLatestProgressEntryDateUseCase = getLatestProgressEntryDateUseCase
        self.shouldSyncMetricUseCase = shouldSyncMetricUseCase
        self.getLatestSleepSessionDateUseCase = getLatestSleepSessionDateUseCase
        self.shouldSyncSleepUseCase = shouldSyncSleepUseCase
        self.authManager = authManager
    }

    /// A static factory method to construct AppDependencies with all its components.
    /// - Parameter authManager: The shared AuthManager instance from the application's environment.
    static func build(authManager: AuthManager) -> AppDependencies {
        print("--- AppDependencies.build() called ---")

        // MARK: - Configuration (Load Once, Crash if Missing)
        guard let baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL"), !baseURL.isEmpty
        else {
            fatalError("BACKEND_BASE_URL not configured in config.plist")
        }
        guard let apiKey = ConfigurationProperties.value(for: "API_KEY"), !apiKey.isEmpty else {
            fatalError("API_KEY not configured in config.plist")
        }
        print("AppDependencies: Configuration loaded - baseURL: \(baseURL)")

        let container = buildModelContainer()
        let sharedContext = ModelContext(container)
        // MARK: - Network Client (FitIQCore)
        // Use FitIQCore's URLSessionNetworkClient for all network operations
        let networkClient: NetworkClientProtocol = FitIQCore.URLSessionNetworkClient()
        let keychainAuthTokenAdapter = KeychainAuthTokenAdapter()

        // MARK: - FitIQCore Token Refresh Client
        let tokenRefreshClient = TokenRefreshClient(
            baseURL: baseURL,
            apiKey: apiKey,
            networkClient: networkClient,
            refreshPath: "/api/v1/auth/refresh"
        )

        let authRepository = UserAuthAPIClient(
            authManager: authManager,
            authTokenPersistence: keychainAuthTokenAdapter,
            tokenRefreshClient: tokenRefreshClient
        )

        let userProfileStorageAdapter = SwiftDataUserProfileAdapter(modelContainer: container)

        // NEW: Profile Metadata Client (separated from UserProfileAPIClient)
        let profileMetadataClient = UserProfileMetadataClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            userProfileStorage: userProfileStorageAdapter
        )

        let activitySnapshotEventPublisher = ActivitySnapshotEventPublisher()
        let localDataChangePublisher = LocalDataChangePublisher()
        let localDataChangeMonitor = LocalDataChangeMonitor(
            modelContainer: container, eventPublisher: localDataChangePublisher)

        let swiftDataActivitySnapshotRepository = SwiftDataActivitySnapshotRepository(
            modelContainer: container,
            eventPublisher: activitySnapshotEventPublisher,
            localDataChangeMonitor: localDataChangeMonitor
        )
        let swiftDataLocalHealthDataStore = SwiftDataLocalHealthDataStore(
            modelContainer: container,
            localDataChangeMonitor: localDataChangeMonitor
        )

        let registerUserUseCase = CreateUserUseCase(
            authRepository: authRepository,
            authManager: authManager,
            userProfileStorage: userProfileStorageAdapter,
            authTokenPersistence: keychainAuthTokenAdapter,
            profileMetadataClient: profileMetadataClient
        )

        let healthRepository = HealthKitAdapter()

        let healthKitAuthUseCase = HealthKitAuthorizationUseCase(healthRepository: healthRepository)

        let getLatestBodyMetricsUseCase = GetLatestBodyMetricsUseCase(
            healthRepository: healthRepository)
        let getHistoricalBodyMassUseCase = GetHistoricalBodyMassUseCase(
            healthRepository: healthRepository)

        let getLatestActivitySnapshotUseCase = GetLatestActivitySnapshotUseCase(
            activitySnapshotRepository: swiftDataActivitySnapshotRepository)

        let remoteHealthDataSync = RemoteHealthDataSyncClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager)

        let backgroundOperations = BackgroundOperations()

        let verifyHealthKitAuthorizationUseCase = UserHasHealthKitAuthorizationUseCase(
            healthRepository: healthRepository)

        // NEW: Progress Repository - Composite (Local + Remote)
        // Must be created before RemoteSyncService since it depends on it
        let progressAPIClient = ProgressAPIClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager
        )

        // MARK: - Outbox Pattern Repository
        let outboxRepository = SwiftDataOutboxRepository(
            modelContext: sharedContext
        )

        // MARK: - Sleep Tracking
        let sleepAPIClient = SleepAPIClient(
            networkClient: networkClient,
            baseURL: baseURL,
            apiKey: apiKey,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager
        )

        let sleepRepository = SwiftDataSleepRepository(
            modelContext: sharedContext,
            outboxRepository: outboxRepository
        )

        let getLatestSleepForSummaryUseCase = GetLatestSleepForSummaryUseCaseImpl(
            sleepRepository: sleepRepository,
            authManager: authManager
        )

        // MARK: - Meal Logging / Nutrition Tracking
        let mealLogLocalRepository = SwiftDataMealLogRepository(
            modelContext: sharedContext,
            outboxRepository: outboxRepository
        )

        let nutritionAPIClient = NutritionAPIClient(
            networkClient: networkClient,
            baseURL: baseURL,
            apiKey: apiKey,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager
        )

        let mealLogRepository = CompositeMealLogRepository(
            localRepository: mealLogLocalRepository,
            remoteAPIClient: nutritionAPIClient
        )

        let saveMealLogUseCase = SaveMealLogUseCaseImpl(
            mealLogRepository: mealLogRepository,
            authManager: authManager
        )

        let getMealLogsUseCase = GetMealLogsUseCaseImpl(
            mealLogRepository: mealLogRepository,
            authManager: authManager
        )

        let updateMealLogStatusUseCase = UpdateMealLogStatusUseCaseImpl(
            mealLogRepository: mealLogRepository,
            authManager: authManager
        )

        let syncPendingMealLogsUseCase = SyncPendingMealLogsUseCaseImpl(
            mealLogRepository: mealLogRepository,
            authManager: authManager
        )

        let deleteMealLogUseCase = DeleteMealLogUseCaseImpl(
            mealLogRepository: mealLogRepository,
            authManager: authManager
        )

        // MARK: - Meal Log WebSocket
        // MARK: - WebSocket Client for Meal Logs
        let webSocketURL = ConfigurationProperties.value(for: "WebSocketURL") ?? ""  // should throw an error if missing
        let mealLogWebSocketClient = MealLogWebSocketClient(webSocketURL: webSocketURL)

        // MARK: - WebSocket Service for Meal Logs (wraps protocol following AuthManager pattern)
        let mealLogWebSocketService = MealLogWebSocketService(
            webSocketClient: mealLogWebSocketClient,
            authManager: authManager
        )

        // MARK: - Photo Recognition (Meal Logging via Photo)
        let photoRecognitionRepository = SwiftDataPhotoRecognitionRepository(
            modelContext: sharedContext
        )

        let photoRecognitionAPIClient = PhotoRecognitionAPIClient(
            networkClient: networkClient,
            baseURL: baseURL,
            apiKey: apiKey,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager
        )

        let uploadMealPhotoUseCase = UploadMealPhotoUseCaseImpl(
            photoRecognitionAPI: photoRecognitionAPIClient,
            photoRecognitionRepository: photoRecognitionRepository,
            authManager: authManager
        )

        let getPhotoRecognitionUseCase = GetPhotoRecognitionUseCaseImpl(
            photoRecognitionAPI: photoRecognitionAPIClient,
            photoRecognitionRepository: photoRecognitionRepository,
            authManager: authManager
        )

        let confirmPhotoRecognitionUseCase = ConfirmPhotoRecognitionUseCaseImpl(
            photoRecognitionAPI: photoRecognitionAPIClient,
            photoRecognitionRepository: photoRecognitionRepository,
            authManager: authManager
        )

        // MARK: - Workout Tracking
        let workoutRepository = SwiftDataWorkoutRepository(
            modelContext: sharedContext,
            modelContainer: container,
            outboxRepository: outboxRepository,
            localDataChangeMonitor: localDataChangeMonitor
        )

        let workoutAPIClient = WorkoutAPIClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager
        )

        let saveWorkoutUseCase = SaveWorkoutUseCaseImpl(
            workoutRepository: workoutRepository,
            authManager: authManager
        )

        let getHistoricalWorkoutsUseCase = GetHistoricalWorkoutsUseCaseImpl(
            workoutRepository: workoutRepository,
            authManager: authManager
        )

        let fetchHealthKitWorkoutsUseCase = FetchHealthKitWorkoutsUseCaseImpl(
            healthRepository: healthRepository,
            authManager: authManager
        )

        let workoutSyncService = HealthKitWorkoutSyncService(
            fetchHealthKitWorkoutsUseCase: fetchHealthKitWorkoutsUseCase,
            saveWorkoutUseCase: saveWorkoutUseCase
        )

        // MARK: - Workout Template Management
        let workoutTemplateRepository = SwiftDataWorkoutTemplateRepository(
            modelContext: sharedContext
        )

        let workoutTemplateAPIClient = WorkoutTemplateAPIClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager
        )

        let fetchWorkoutTemplatesUseCase = FetchWorkoutTemplatesUseCaseImpl(
            repository: workoutTemplateRepository
        )

        let syncWorkoutTemplatesUseCase = SyncWorkoutTemplatesUseCaseImpl(
            repository: workoutTemplateRepository,
            apiClient: workoutTemplateAPIClient
        )

        let createWorkoutTemplateUseCase = CreateWorkoutTemplateUseCaseImpl(
            repository: workoutTemplateRepository,
            outboxRepository: outboxRepository,
            authManager: authManager
        )

        let startWorkoutSessionUseCase = StartWorkoutSessionUseCaseImpl(
            authManager: authManager
        )

        let completeWorkoutSessionUseCase = CompleteWorkoutSessionUseCaseImpl(
            saveWorkoutUseCase: saveWorkoutUseCase,
            healthRepository: healthRepository
        )

        let shareWorkoutTemplateUseCase = ShareWorkoutTemplateUseCaseImpl(
            apiClient: workoutTemplateAPIClient,
            repository: workoutTemplateRepository,
            authManager: authManager
        )

        let revokeTemplateShareUseCase = RevokeTemplateShareUseCaseImpl(
            apiClient: workoutTemplateAPIClient,
            repository: workoutTemplateRepository,
            authManager: authManager
        )

        let fetchSharedWithMeTemplatesUseCase = FetchSharedWithMeTemplatesUseCaseImpl(
            apiClient: workoutTemplateAPIClient,
            authManager: authManager
        )

        let copyWorkoutTemplateUseCase = CopyWorkoutTemplateUseCaseImpl(
            apiClient: workoutTemplateAPIClient,
            repository: workoutTemplateRepository,
            authManager: authManager
        )

        let swiftDataProgressRepository = SwiftDataProgressRepository(
            modelContext: sharedContext,
            modelContainer: container,
            outboxRepository: outboxRepository,
            localDataChangeMonitor: localDataChangeMonitor  // NEW: For live UI updates
        )

        let progressRepository = CompositeProgressRepository(
            localRepository: swiftDataProgressRepository,
            remoteAPIClient: progressAPIClient
        )

        // NEW: Save Steps Progress Use Case (needed by HealthDataSyncManager)
        let saveStepsProgressUseCase = SaveStepsProgressUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        // NEW: Save Heart Rate Progress Use Case (needed by HealthDataSyncManager)
        let saveHeartRateProgressUseCase = SaveHeartRateProgressUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        // NEW: Sync Optimization Use Cases (Hexagonal Architecture Compliance)
        let getLatestProgressEntryDateUseCase = GetLatestProgressEntryDateUseCaseImpl(
            progressRepository: progressRepository
        )

        let shouldSyncMetricUseCase = ShouldSyncMetricUseCaseImpl(
            getLatestEntryDateUseCase: getLatestProgressEntryDateUseCase
        )

        // NEW: Sleep Sync Optimization Use Cases (Hexagonal Architecture Compliance)
        let getLatestSleepSessionDateUseCase = GetLatestSleepSessionDateUseCaseImpl(
            sleepRepository: sleepRepository
        )

        let shouldSyncSleepUseCase = ShouldSyncSleepUseCaseImpl(
            getLatestSessionDateUseCase: getLatestSleepSessionDateUseCase
        )

        // NEW: Create Sync Tracking Service (Phase 1 refactoring)
        let syncTrackingService: SyncTrackingServiceProtocol = UserDefaultsSyncTrackingService(
            userDefaults: .standard
        )

        // NEW: Create Metric-Specific Sync Handlers (Phase 2 refactoring - Hexagonal Architecture Compliant)
        let stepsSyncHandler = StepsSyncHandler(
            healthRepository: healthRepository,
            saveStepsProgressUseCase: saveStepsProgressUseCase,
            shouldSyncMetricUseCase: shouldSyncMetricUseCase,
            getLatestEntryDateUseCase: getLatestProgressEntryDateUseCase,
            authManager: authManager,
            syncTracking: syncTrackingService
        )

        let heartRateSyncHandler = HeartRateSyncHandler(
            healthRepository: healthRepository,
            saveHeartRateProgressUseCase: saveHeartRateProgressUseCase,
            shouldSyncMetricUseCase: shouldSyncMetricUseCase,
            getLatestEntryDateUseCase: getLatestProgressEntryDateUseCase,
            authManager: authManager,
            syncTracking: syncTrackingService
        )

        let sleepSyncHandler = SleepSyncHandler(
            healthRepository: healthRepository,
            sleepRepository: sleepRepository,
            shouldSyncSleepUseCase: shouldSyncSleepUseCase,
            getLatestSessionDateUseCase: getLatestSleepSessionDateUseCase,
            syncTracking: syncTrackingService
        )

        // Compose handlers into array
        let syncHandlers: [HealthMetricSyncHandler] = [
            stepsSyncHandler,
            heartRateSyncHandler,
            sleepSyncHandler,
        ]

        // NEW: Create HealthDataSyncOrchestrator (Phase 3 refactoring - replaces 897-line HealthDataSyncManager)
        let healthDataSyncService = HealthDataSyncOrchestrator(
            syncHandlers: syncHandlers,
            activitySnapshotRepository: swiftDataActivitySnapshotRepository
        )

        let processDailyHealthDataUseCase = ProcessDailyHealthDataUseCase(
            healthDataSyncService: healthDataSyncService,
            workoutSyncService: workoutSyncService
        )

        let processConsolidatedDailyHealthDataUseCase = ProcessConsolidatedDailyHealthDataUseCase(
            healthDataSyncService: healthDataSyncService,
            authManager: authManager
        )

        let backgroundSyncManager = BackgroundSyncManager(
            healthDataSyncService: healthDataSyncService,
            backgroundOperations: backgroundOperations,
            healthRepository: healthRepository,
            processDailyHealthDataUseCase: processDailyHealthDataUseCase,
            processConsolidatedDailyHealthDataUseCase: processConsolidatedDailyHealthDataUseCase,
            authManager: authManager
        )

        let remoteSyncService = RemoteSyncService(
            localDataChangePublisher: localDataChangePublisher,
            remoteDataSync: remoteHealthDataSync,
            localHealthDataStore: swiftDataLocalHealthDataStore,
            activitySnapshotRepository: swiftDataActivitySnapshotRepository,
            progressRepository: progressRepository,
            modelContainer: container
        )

        // NEW: Save Weight Progress Use Case
        let saveWeightProgressUseCase = SaveWeightProgressUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        let performInitialHealthKitSyncUseCase = PerformInitialHealthKitSyncUseCase(
            healthDataSyncService: healthDataSyncService,
            userProfileStorage: userProfileStorageAdapter,
            requestHealthKitAuthorizationUseCase: healthKitAuthUseCase,
            healthRepository: healthRepository,
            authManager: authManager,
            saveWeightProgressUseCase: saveWeightProgressUseCase,
            workoutSyncService: workoutSyncService
        )

        // NEW: Perform Initial Data Load Use Case (coordinates initial sync after onboarding)
        let performInitialDataLoadUseCase = PerformInitialDataLoadUseCaseImpl(
            userHasHealthKitAuthorizationUseCase: verifyHealthKitAuthorizationUseCase,
            performInitialHealthKitSyncUseCase: performInitialHealthKitSyncUseCase
        )

        // NEW: Get Historical Weight Use Case
        let getHistoricalWeightUseCase = GetHistoricalWeightUseCaseImpl(
            progressRepository: progressRepository,
            healthRepository: healthRepository,
            authManager: authManager,
            saveWeightProgressUseCase: saveWeightProgressUseCase
        )

        // NEW: Save Mood Progress Use Case
        let saveMoodProgressUseCase = SaveMoodProgressUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager,
            healthRepository: healthRepository
        )

        // NEW: Get Historical Mood Use Case
        let getHistoricalMoodUseCase = GetHistoricalMoodUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        // NEW: Save Water Progress Use Case
        let saveWaterProgressUseCase = SaveWaterProgressUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        // NEW: Get Today Water Intake Use Case
        let getTodayWaterIntakeUseCase = GetTodayWaterIntakeUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        // NEW: Get Latest Heart Rate Use Case (REAL-TIME: Fetches from HealthKit for exact timestamps)
        let getLatestHeartRateUseCase = GetLatestHeartRateUseCaseImpl(
            healthRepository: healthRepository,
            authManager: authManager
        )

        // SUMMARY-SPECIFIC: Use cases for fetching only the data needed for summary cards
        let getLast8HoursHeartRateUseCase = GetLast8HoursHeartRateUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        let getLast8HoursStepsUseCase = GetLast8HoursStepsUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        let getDailyStepsTotalUseCase = GetDailyStepsTotalUseCaseImpl(
            healthRepository: healthRepository,
            authManager: authManager
        )

        let getLast5WeightsForSummaryUseCase = GetLast5WeightsForSummaryUseCaseImpl(
            progressRepository: progressRepository,
            authManager: authManager
        )

        // Instantiate SaveBodyMassUseCase (Domain layer, so it stays here)
        let saveBodyMassUseCase = SaveBodyMassUseCase(
            healthRepository: healthRepository,
            userProfileStorage: userProfileStorageAdapter,
            authManager: authManager,
            saveWeightProgressUseCase: saveWeightProgressUseCase
        )

        // NEW: Instantiate CloudDataManager
        _ = CloudDataManager(modelContainer: container)

        // NEW: User Profile Management
        let userProfileRepository = UserProfileAPIClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            userProfileStorage: userProfileStorageAdapter
        )

        let updateUserProfileUseCase = UpdateUserProfileUseCase(
            userProfileRepository: userProfileRepository,
            userProfileStorage: userProfileStorageAdapter
        )

        // Login use case needs userProfileRepository
        let loginUserUseCase = AuthenticateUserUseCase(
            authRepository: authRepository,
            authManager: authManager,
            authTokenPersistence: keychainAuthTokenAdapter,
            userProfileStorage: userProfileStorageAdapter,
            userProfileRepository: userProfileRepository
        )

        // NEW: Profile Event Publisher
        let profileEventPublisher = ProfileEventPublisher()

        // NEW: Profile Metadata and Physical Profile Use Cases
        let updateProfileMetadataUseCase = UpdateProfileMetadataUseCaseImpl(
            userProfileStorage: userProfileStorageAdapter,
            eventPublisher: profileEventPublisher
        )

        // NEW: Log Height Progress Use Case
        let logHeightProgressUseCase = LogHeightProgressUseCaseImpl(
            progressRepository: progressRepository
        )

        // NEW: Sync Biological Sex from HealthKit Use Case
        let syncBiologicalSexFromHealthKitUseCase = SyncBiologicalSexFromHealthKitUseCaseImpl(
            userProfileStorage: userProfileStorageAdapter
        )

        // NEW: Delete All User Data Use Case
        let deleteAllUserDataUseCase = DeleteAllUserDataUseCaseImpl(
            networkClient: networkClient,
            authManager: authManager,
            authTokenPersistence: keychainAuthTokenAdapter,
            modelContainer: container
        )

        // NEW: Force HealthKit Re-sync Use Case
        let forceHealthKitResyncUseCase = ForceHealthKitResyncUseCaseImpl(
            performInitialHealthKitSyncUseCase: performInitialHealthKitSyncUseCase,
            userProfileStorage: userProfileStorageAdapter,
            progressRepository: progressRepository,
            authManager: authManager,
            healthDataSyncManager: healthDataSyncService
        )

        // NEW: Create ViewModelAppDependencies builder
        // NEW: Profile Sync Services
        let profileSyncService = ProfileSyncService(
            profileEventPublisher: profileEventPublisher,
            userProfileRepository: userProfileRepository,
            userProfileStorage: userProfileStorageAdapter,
            authManager: authManager
        )

        let healthKitProfileSyncService = HealthKitProfileSyncService(
            profileEventPublisher: profileEventPublisher,
            healthKitAdapter: healthRepository,
            userProfileStorage: userProfileStorageAdapter,
            authManager: authManager
        )

        // Start listening to profile events
        profileSyncService.startListening()
        healthKitProfileSyncService.startListening()

        // MARK: - Cleanup Orphaned Outbox Events Use Case
        let cleanupOrphanedOutboxEventsUseCase = CleanupOrphanedOutboxEventsUseCaseImpl(
            outboxRepository: outboxRepository,
            progressRepository: progressRepository
        )

        // MARK: - Debug Outbox Status Use Case
        let debugOutboxStatusUseCase = DebugOutboxStatusUseCaseImpl(
            outboxRepository: outboxRepository,
            progressRepository: progressRepository,
            authManager: authManager
        )

        // MARK: - Emergency Cleanup Outbox Use Case
        let emergencyCleanupOutboxUseCase = EmergencyCleanupOutboxUseCaseImpl(
            outboxRepository: outboxRepository,
            progressRepository: progressRepository
        )

        // MARK: - Outbox Processor Service
        // Created but NOT started here - will be started on login
        let outboxProcessorService = OutboxProcessorService(
            outboxRepository: outboxRepository,
            progressRepository: progressRepository,
            localHealthDataStore: swiftDataLocalHealthDataStore,
            activitySnapshotRepository: swiftDataActivitySnapshotRepository,
            remoteDataSync: remoteHealthDataSync,
            authManager: authManager,
            sleepRepository: sleepRepository,
            sleepAPIClient: sleepAPIClient,
            mealLogRepository: mealLogLocalRepository,
            nutritionAPIClient: nutritionAPIClient,
            workoutRepository: workoutRepository,
            workoutAPIClient: workoutAPIClient,
            workoutTemplateRepository: workoutTemplateRepository,
            workoutTemplateAPIClient: workoutTemplateAPIClient,
            batchSize: 10,
            processingInterval: 2.0,
            cleanupInterval: 3600,
            maxConcurrentOperations: 3
        )

        // MARK: - Progressive Historical Sync Service
        let progressiveHistoricalSyncService = ProgressiveHistoricalSyncService(
            healthDataSyncService: healthDataSyncService,
            progressRepository: progressRepository,
            authManager: authManager
        )

        // MARK: - Database Optimization Use Case
        let optimizeDatabaseUseCase = OptimizeDatabaseUseCaseImpl(
            progressRepository: progressRepository,
            outboxRepository: outboxRepository,
            activitySnapshotRepository: swiftDataActivitySnapshotRepository,
            authManager: authManager
        )

        let appDependenciesInstance = AppDependencies(
            modelContainer: container,
            networkClient: networkClient,
            registerUserUseCase: registerUserUseCase,
            loginUserUseCase: loginUserUseCase,
            authRepository: authRepository,
            healthRepository: healthRepository,
            healthKitAuthUseCase: healthKitAuthUseCase,
            getLatestBodyMetricsUseCase: getLatestBodyMetricsUseCase,
            getHistoricalBodyMassUseCase: getHistoricalBodyMassUseCase,
            userProfileStorage: userProfileStorageAdapter,
            authTokenPersistence: keychainAuthTokenAdapter,
            tokenRefreshClient: tokenRefreshClient,
            healthDataSyncService: healthDataSyncService,
            backgroundOperations: backgroundOperations,
            backgroundSyncManager: backgroundSyncManager,
            activitySnapshotRepository: swiftDataActivitySnapshotRepository,
            getLatestActivitySnapshotUseCase: getLatestActivitySnapshotUseCase,
            localHealthDataStore: swiftDataLocalHealthDataStore,
            activitySnapshotEventPublisher: activitySnapshotEventPublisher,
            userHasHealthKitAuthorizationUseCase: verifyHealthKitAuthorizationUseCase,
            authManager: authManager,
            performInitialHealthKitSyncUseCase: performInitialHealthKitSyncUseCase,
            performInitialDataLoadUseCase: performInitialDataLoadUseCase,
            localDataChangePublisher: localDataChangePublisher,
            localDataChangeMonitor: localDataChangeMonitor,
            remoteSyncService: remoteSyncService,
            processDailyHealthDataUseCase: processDailyHealthDataUseCase,
            processConsolidatedDailyHealthDataUseCase: processConsolidatedDailyHealthDataUseCase,
            saveBodyMassUseCase: saveBodyMassUseCase,
            updateUserProfileUseCase: updateUserProfileUseCase,
            userProfileRepository: userProfileRepository,
            updateProfileMetadataUseCase: updateProfileMetadataUseCase,
            profileEventPublisher: profileEventPublisher,
            profileSyncService: profileSyncService,
            healthKitProfileSyncService: healthKitProfileSyncService,
            profileMetadataClient: profileMetadataClient,
            progressRepository: progressRepository,
            logHeightProgressUseCase: logHeightProgressUseCase,
            saveStepsProgressUseCase: saveStepsProgressUseCase,
            saveHeartRateProgressUseCase: saveHeartRateProgressUseCase,
            saveWeightProgressUseCase: saveWeightProgressUseCase,
            getHistoricalWeightUseCase: getHistoricalWeightUseCase,
            saveMoodProgressUseCase: saveMoodProgressUseCase,
            getHistoricalMoodUseCase: getHistoricalMoodUseCase,
            getLatestHeartRateUseCase: getLatestHeartRateUseCase,
            saveWaterProgressUseCase: saveWaterProgressUseCase,
            getTodayWaterIntakeUseCase: getTodayWaterIntakeUseCase,
            getLast8HoursHeartRateUseCase: getLast8HoursHeartRateUseCase,
            getLast8HoursStepsUseCase: getLast8HoursStepsUseCase,
            getLast5WeightsForSummaryUseCase: getLast5WeightsForSummaryUseCase,
            getDailyStepsTotalUseCase: getDailyStepsTotalUseCase,
            syncBiologicalSexFromHealthKitUseCase: syncBiologicalSexFromHealthKitUseCase,
            deleteAllUserDataUseCase: deleteAllUserDataUseCase,
            forceHealthKitResyncUseCase: forceHealthKitResyncUseCase,
            outboxRepository: outboxRepository,
            outboxProcessorService: outboxProcessorService,
            sleepRepository: sleepRepository,
            sleepAPIClient: sleepAPIClient,
            getLatestSleepForSummaryUseCase: getLatestSleepForSummaryUseCase,
            mealLogLocalRepository: mealLogLocalRepository,
            nutritionAPIClient: nutritionAPIClient,
            mealLogRepository: mealLogRepository,
            saveMealLogUseCase: saveMealLogUseCase,
            getMealLogsUseCase: getMealLogsUseCase,
            updateMealLogStatusUseCase: updateMealLogStatusUseCase,
            syncPendingMealLogsUseCase: syncPendingMealLogsUseCase,
            deleteMealLogUseCase: deleteMealLogUseCase,
            mealLogWebSocketClient: mealLogWebSocketClient,
            mealLogWebSocketService: mealLogWebSocketService,
            photoRecognitionRepository: photoRecognitionRepository,
            photoRecognitionAPIClient: photoRecognitionAPIClient,
            uploadMealPhotoUseCase: uploadMealPhotoUseCase,
            getPhotoRecognitionUseCase: getPhotoRecognitionUseCase,
            confirmPhotoRecognitionUseCase: confirmPhotoRecognitionUseCase,
            workoutRepository: workoutRepository,
            workoutAPIClient: workoutAPIClient,
            saveWorkoutUseCase: saveWorkoutUseCase,
            getHistoricalWorkoutsUseCase: getHistoricalWorkoutsUseCase,
            fetchHealthKitWorkoutsUseCase: fetchHealthKitWorkoutsUseCase,
            workoutTemplateRepository: workoutTemplateRepository,
            workoutTemplateAPIClient: workoutTemplateAPIClient,
            fetchWorkoutTemplatesUseCase: fetchWorkoutTemplatesUseCase,
            syncWorkoutTemplatesUseCase: syncWorkoutTemplatesUseCase,
            createWorkoutTemplateUseCase: createWorkoutTemplateUseCase,
            shareWorkoutTemplateUseCase: shareWorkoutTemplateUseCase,
            revokeTemplateShareUseCase: revokeTemplateShareUseCase,
            fetchSharedWithMeTemplatesUseCase: fetchSharedWithMeTemplatesUseCase,
            copyWorkoutTemplateUseCase: copyWorkoutTemplateUseCase,
            startWorkoutSessionUseCase: startWorkoutSessionUseCase,
            completeWorkoutSessionUseCase: completeWorkoutSessionUseCase,
            progressiveHistoricalSyncService: progressiveHistoricalSyncService,
            optimizeDatabaseUseCase: optimizeDatabaseUseCase,
            cleanupOrphanedOutboxEventsUseCase: cleanupOrphanedOutboxEventsUseCase,
            debugOutboxStatusUseCase: debugOutboxStatusUseCase,
            emergencyCleanupOutboxUseCase: emergencyCleanupOutboxUseCase,
            getLatestProgressEntryDateUseCase: getLatestProgressEntryDateUseCase,
            shouldSyncMetricUseCase: shouldSyncMetricUseCase,
            getLatestSleepSessionDateUseCase: getLatestSleepSessionDateUseCase,
            shouldSyncSleepUseCase: shouldSyncSleepUseCase
        )

        // Observe authentication state to start/stop OutboxProcessorService
        Task { @MainActor in
            // Check if user is already authenticated and start processor
            if let currentUserID = authManager.currentUserProfileID {
                print(
                    "AppDependencies: User already authenticated, starting OutboxProcessorService for user \(currentUserID)"
                )

                // Debug: Print outbox status first (DEBUG builds only)
                #if DEBUG
                    Task {
                        do {
                            let report = try await debugOutboxStatusUseCase.execute(
                                forUserID: currentUserID.uuidString)
                            report.printReport()
                        } catch {
                            print(
                                "AppDependencies: Warning - Failed to get debug status: \(error.localizedDescription)"
                            )
                        }
                    }
                #endif

                // DISABLED: Emergency cleanup was causing massive startup lag
                // Running on EVERY app launch, deleting/recreating ALL outbox events
                // This should only be run manually when debugging outbox issues
                // The normal cleanup loop in OutboxProcessorService handles completed events
                /*
                Task {
                    do {
                        print("AppDependencies: 🚨 Running emergency cleanup...")
                        let result = try await emergencyCleanupOutboxUseCase.execute(
                            forUserID: currentUserID.uuidString)
                        print("AppDependencies: ✅ Emergency cleanup completed")
                        print("  - Deleted \(result.totalEventsDeleted) corrupted events")
                        print("  - Created \(result.newEventsCreated) fresh events")
                    } catch {
                        print(
                            "AppDependencies: ❌ Emergency cleanup failed: \(error.localizedDescription)"
                        )
                    }
                }
                */

                outboxProcessorService.startProcessing(forUserID: currentUserID)
            }

            // Observe changes to authentication state
            for await userID in authManager.$currentUserProfileID.values {
                if let userID = userID {
                    print(
                        "AppDependencies: User logged in, starting OutboxProcessorService for user \(userID)"
                    )

                    // DISABLED: Emergency cleanup was causing massive startup lag
                    // This should only be run manually when debugging outbox issues
                    /*
                    Task {
                        do {
                            print("AppDependencies: 🚨 Running emergency cleanup...")
                            let result = try await emergencyCleanupOutboxUseCase.execute(
                                forUserID: userID.uuidString)
                            print("AppDependencies: ✅ Emergency cleanup completed")
                            print("  - Deleted \(result.totalEventsDeleted) corrupted events")
                            print("  - Created \(result.newEventsCreated) fresh events")
                        } catch {
                            print(
                                "AppDependencies: ❌ Emergency cleanup failed: \(error.localizedDescription)"
                            )
                        }
                    }
                    */

                    outboxProcessorService.startProcessing(forUserID: userID)
                } else {
                    print("AppDependencies: User logged out, stopping OutboxProcessorService")
                    outboxProcessorService.stopProcessing()
                }
            }
        }

        // One-time cleanup: Remove duplicate profiles from database
        // This is a data migration task that runs only once per app version
        Task.detached(priority: .background) {
            let cleanupKey = "duplicateProfileCleanupCompleted_v1"

            // Only run once - skip if already completed
            guard !UserDefaults.standard.bool(forKey: cleanupKey) else {
                print("AppDependencies: Duplicate cleanup already completed, skipping")
                return
            }

            do {
                print("AppDependencies: Running one-time duplicate profile cleanup...")
                try await userProfileStorageAdapter.cleanupAllDuplicateProfiles()
                UserDefaults.standard.set(true, forKey: cleanupKey)
                print("AppDependencies: ✅ Duplicate profile cleanup complete")
            } catch {
                print("AppDependencies: ⚠️ Duplicate cleanup failed (non-critical): \(error)")
            }
        }

        Task {
            let pendingTasks = await BGTaskScheduler.shared.pendingTaskRequests()
            print(
                "AppDependencies: After registration, BGTaskScheduler reports \(pendingTasks.count) pending task requests:"
            )
            for task in pendingTasks {
                print(
                    "  - Task ID: \(task.identifier), Earliest Begin Date: \(task.earliestBeginDate?.description ?? "N/A")"
                )
            }
            if pendingTasks.isEmpty {
                print(
                    "AppDependencies: No tasks are currently scheduled with BGTaskScheduler. This might indicate an issue with scheduling or the system's ability to retain tasks."
                )
            }
        }

        return appDependenciesInstance
    }

    private static func buildModelContainer() -> ModelContainer {
        let container: ModelContainer
        do {
            // Create Schema from CurrentSchema models
            let schema = Schema(
                versionedSchema: CurrentSchema.self
            )

            // Use PersistenceMigrationPlan for automatic schema migrations
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )

            container = try ModelContainer(
                for: schema,
                migrationPlan: PersistenceMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            print(
                "AppDependencies: Successfully initialized ModelContainer with iCloud support and migration plan."
            )

        } catch let error as NSError {
            print("--- CORE DATA MIGRATION ERROR DETAILS ---")
            print("Domain: \(error.domain)")
            print("Code: \(error.code)")
            print("User Info: \(error.userInfo)")

            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("Underlying Error: \(underlyingError)")
                print("Underlying Error User Info: \(underlyingError.userInfo)")
            }
            print("---------------------------------------")
            fatalError("Failed to initialize ModelContainer: \(error)")
        } catch {
            fatalError("ModelContainer creation failed: \(error)")
        }
        return container
    }

}
