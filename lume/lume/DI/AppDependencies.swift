import FitIQCore
import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    // MARK: - SwiftData

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    // MARK: - Network Monitoring

    private(set) lazy var networkMonitor: NetworkMonitor = {
        NetworkMonitor.shared
    }()

    // MARK: - Infrastructure

    // MARK: - FitIQCore - Authentication

    private(set) lazy var authTokenStorage: AuthTokenPersistenceProtocol = {
        KeychainAuthTokenStorage()
    }()

    private(set) lazy var authManager: AuthManager = {
        AuthManager(
            authTokenPersistence: authTokenStorage,
            onboardingKey: "lume_onboarding_complete"
        )
    }()

    private(set) lazy var tokenStorage: TokenStorageProtocol = {
        KeychainTokenStorage()
    }()

    private(set) lazy var authService: AuthServiceProtocol = {
        if AppMode.useMockData {
            return MockAuthService()
        } else {
            return RemoteAuthService()
        }
    }()

    private(set) lazy var outboxRepository: OutboxRepositoryProtocol = {
        SwiftDataOutboxRepository(modelContext: modelContext)
    }()

    // MARK: - FitIQCore - Token Refresh Client

    private(set) lazy var tokenRefreshClient: TokenRefreshClient = {
        TokenRefreshClient(
            baseURL: AppConfiguration.shared.backendBaseURL.absoluteString,
            apiKey: AppConfiguration.shared.apiKey,
            networkClient: FitIQCore.URLSessionNetworkClient(),
            refreshPath: AppConfiguration.Endpoints.authRefresh
        )
    }()

    // MARK: - Backend Services

    private(set) lazy var moodBackendService: MoodBackendServiceProtocol = {
        if AppMode.useMockData {
            return InMemoryMoodBackendService()
        } else {
            return MoodBackendService()
        }
    }()

    private(set) lazy var journalBackendService: JournalBackendServiceProtocol = {
        if AppMode.useMockData {
            return InMemoryJournalBackendService()
        } else {
            return JournalBackendService()
        }
    }()

    private(set) lazy var aiInsightBackendService: AIInsightBackendServiceProtocol = {
        if AppMode.useMockData {
            return InMemoryAIInsightBackendService()
        } else {
            return AIInsightBackendService(httpClient: httpClient)
        }
    }()

    private(set) lazy var goalBackendService: GoalBackendServiceProtocol = {
        if AppMode.useMockData {
            return InMemoryGoalBackendService()
        } else {
            return GoalBackendService(httpClient: httpClient)
        }
    }()

    private(set) lazy var goalAIService: GoalAIServiceProtocol = {
        if AppMode.useMockData {
            return InMemoryGoalAIService()
        } else {
            return GoalAIService(httpClient: httpClient, tokenStorage: tokenStorage)
        }
    }()

    private(set) lazy var chatBackendService: ChatBackendServiceProtocol = {
        if AppMode.useMockData {
            return InMemoryChatBackendService()
        } else {
            return ChatBackendService(httpClient: httpClient)
        }
    }()

    private(set) lazy var chatService: ChatServiceProtocol = {
        if AppMode.useMockData {
            return MockChatService()
        } else {
            return ChatService(
                backendService: chatBackendService,
                tokenStorage: tokenStorage
            )
        }
    }()

    // MARK: - User Services

    private(set) lazy var httpClient: HTTPClient = {
        HTTPClient(
            baseURL: AppConfiguration.shared.backendBaseURL,
            apiKey: AppConfiguration.shared.apiKey
        )
    }()

    private(set) lazy var userProfileService: UserProfileServiceProtocol = {
        if AppMode.useMockData {
            return MockUserProfileService()
        } else {
            return UserProfileService(
                httpClient: httpClient,
                baseURL: AppConfiguration.shared.backendBaseURL
            )
        }
    }()

    private(set) lazy var userProfileBackendService: UserProfileBackendServiceProtocol = {
        if AppMode.useMockData {
            return MockUserProfileBackendService()
        } else {
            return UserProfileBackendService(httpClient: httpClient)
        }
    }()

    // MARK: - Sync Services

    private(set) lazy var moodSyncService: MoodSyncPort = {
        MoodSyncService(
            moodBackendService: moodBackendService,
            tokenStorage: tokenStorage,
            modelContext: modelContext,
            outboxRepository: outboxRepository
        )
    }()

    // MARK: - Use Cases (Domain)

    private(set) lazy var syncMoodEntriesUseCase: SyncMoodEntriesUseCase = {
        SyncMoodEntriesUseCaseImpl(syncPort: moodSyncService)
    }()

    // MARK: - Outbox Processing

    private(set) lazy var outboxProcessorService: OutboxProcessorService = {
        OutboxProcessorService(
            outboxRepository: outboxRepository,
            tokenStorage: tokenStorage,
            moodBackendService: moodBackendService,
            journalBackendService: journalBackendService,
            goalBackendService: goalBackendService,
            chatBackendService: chatBackendService,
            modelContext: modelContext,
            refreshTokenUseCase: refreshTokenUseCase,
            networkMonitor: networkMonitor
        )
    }()

    // MARK: - Repositories

    private(set) lazy var authRepository: AuthRepositoryProtocol = {
        AuthRepository(
            authService: authService,
            tokenStorage: tokenStorage,
            userProfileService: userProfileService,
            modelContext: modelContext,
            tokenRefreshClient: tokenRefreshClient
        )
    }()

    // MARK: - Use Cases

    private(set) lazy var registerUserUseCase: RegisterUserUseCase = {
        RegisterUserUseCaseImpl(authRepository: authRepository)
    }()

    private(set) lazy var loginUserUseCase: LoginUserUseCase = {
        LoginUserUseCaseImpl(authRepository: authRepository)
    }()

    private(set) lazy var logoutUserUseCase: LogoutUserUseCase = {
        LogoutUserUseCaseImpl(authRepository: authRepository)
    }()

    private(set) lazy var refreshTokenUseCase: RefreshTokenUseCase = {
        RefreshTokenUseCaseImpl(authRepository: authRepository)
    }()

    // MARK: - View Models

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            registerUserUseCase: registerUserUseCase,
            loginUserUseCase: loginUserUseCase,
            logoutUserUseCase: logoutUserUseCase
        )
    }

    // MARK: - Mood Dependencies

    private(set) lazy var moodRepository: MoodRepositoryProtocol = {
        MoodRepository(
            modelContext: modelContext,
            outboxRepository: outboxRepository,
            backendService: moodBackendService,
            tokenStorage: tokenStorage
        )
    }()

    func makeMoodViewModel() -> MoodViewModel {
        MoodViewModel(
            moodRepository: moodRepository,
            authRepository: authRepository,
            syncMoodEntriesUseCase: syncMoodEntriesUseCase
        )
    }

    // MARK: - Statistics Dependencies

    private(set) lazy var statisticsRepository: StatisticsRepositoryProtocol = {
        StatisticsRepository(modelContext: modelContext)
    }()

    private(set) lazy var dashboardViewModel: DashboardViewModel = {
        DashboardViewModel(statisticsRepository: statisticsRepository)
    }()

    func makeDashboardViewModel() -> DashboardViewModel {
        dashboardViewModel
    }

    // MARK: - Journal Dependencies

    private(set) lazy var journalRepository: JournalRepositoryProtocol = {
        SwiftDataJournalRepository(
            modelContext: modelContext,
            outboxRepository: outboxRepository
        )
    }()

    func makeJournalViewModel() -> JournalViewModel {
        JournalViewModel(
            journalRepository: journalRepository,
            moodRepository: moodRepository
        )
    }

    // MARK: - AI Features Repositories

    private(set) lazy var aiInsightRepository: AIInsightRepositoryProtocol = {
        AIInsightRepository(
            modelContext: modelContext,
            backendService: aiInsightBackendService,
            tokenStorage: tokenStorage
        )
    }()

    private(set) lazy var userProfileRepository: UserProfileRepositoryProtocol = {
        UserProfileRepository(
            modelContext: modelContext,
            backendService: userProfileBackendService,
            tokenStorage: tokenStorage
        )
    }()

    private(set) lazy var goalRepository: GoalRepositoryProtocol = {
        GoalRepository(
            modelContext: modelContext,
            backendService: goalBackendService,
            tokenStorage: tokenStorage,
            outboxRepository: outboxRepository
        )
    }()

    private(set) lazy var chatRepository: ChatRepositoryProtocol = {
        ChatRepository(
            modelContext: modelContext,
            backendService: chatBackendService,
            tokenStorage: tokenStorage,
            outboxRepository: outboxRepository
        )
    }()

    // MARK: - AI Insights Use Cases

    private(set) lazy var fetchAIInsightsUseCase: FetchAIInsightsUseCaseProtocol = {
        FetchAIInsightsUseCase(
            repository: aiInsightRepository
        )
    }()

    private(set) lazy var generateInsightUseCase: GenerateInsightUseCaseProtocol = {
        GenerateInsightUseCase(
            repository: aiInsightRepository,
            backendService: aiInsightBackendService,
            tokenStorage: tokenStorage,
            moodRepository: moodRepository,
            journalRepository: journalRepository,
            goalRepository: goalRepository
        )
    }()

    private(set) lazy var markInsightAsReadUseCase: MarkInsightAsReadUseCaseProtocol = {
        MarkInsightAsReadUseCase(
            repository: aiInsightRepository
        )
    }()

    private(set) lazy var toggleInsightFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol = {
        ToggleInsightFavoriteUseCase(
            repository: aiInsightRepository
        )
    }()

    private(set) lazy var archiveInsightUseCase: ArchiveInsightUseCaseProtocol = {
        ArchiveInsightUseCase(
            repository: aiInsightRepository
        )
    }()

    private(set) lazy var unarchiveInsightUseCase: UnarchiveInsightUseCaseProtocol = {
        UnarchiveInsightUseCase(
            repository: aiInsightRepository
        )
    }()

    private(set) lazy var deleteInsightUseCase: DeleteInsightUseCaseProtocol = {
        DeleteInsightUseCase(
            repository: aiInsightRepository
        )
    }()

    // MARK: - Goal Use Cases

    private(set) lazy var fetchGoalsUseCase: FetchGoalsUseCase = {
        FetchGoalsUseCase(
            goalRepository: goalRepository
        )
    }()

    private(set) lazy var createGoalUseCase: CreateGoalUseCase = {
        CreateGoalUseCase(
            goalRepository: goalRepository,
            outboxRepository: outboxRepository
        )
    }()

    private(set) lazy var updateGoalUseCase: UpdateGoalUseCase = {
        UpdateGoalUseCase(
            goalRepository: goalRepository,
            outboxRepository: outboxRepository
        )
    }()

    private(set) lazy var generateGoalSuggestionsUseCase: GenerateGoalSuggestionsUseCase = {
        GenerateGoalSuggestionsUseCase(
            goalAIService: goalAIService,
            moodRepository: moodRepository,
            journalRepository: journalRepository,
            goalRepository: goalRepository
        )
    }()

    private(set) lazy var getGoalTipsUseCase: GetGoalTipsUseCase = {
        GetGoalTipsUseCase(
            goalAIService: goalAIService,
            goalRepository: goalRepository,
            moodRepository: moodRepository,
            journalRepository: journalRepository
        )
    }()

    // MARK: - Chat Use Cases

    private(set) lazy var createConversationUseCase: CreateConversationUseCase = {
        CreateConversationUseCase(
            chatRepository: chatRepository,
            chatService: chatService
        )
    }()

    private(set) lazy var sendChatMessageUseCase: SendChatMessageUseCase = {
        SendChatMessageUseCase(
            chatRepository: chatRepository,
            chatService: chatService
        )
    }()

    private(set) lazy var fetchConversationsUseCase: FetchConversationsUseCase = {
        FetchConversationsUseCase(
            chatRepository: chatRepository,
            chatService: chatService
        )
    }()

    // MARK: - AI Features View Models

    private(set) lazy var aiInsightsViewModel: AIInsightsViewModel = {
        AIInsightsViewModel(
            fetchInsightsUseCase: fetchAIInsightsUseCase,
            generateInsightUseCase: generateInsightUseCase,
            markAsReadUseCase: markInsightAsReadUseCase,
            toggleFavoriteUseCase: toggleInsightFavoriteUseCase,
            archiveUseCase: archiveInsightUseCase,
            unarchiveUseCase: unarchiveInsightUseCase,
            deleteUseCase: deleteInsightUseCase
        )
    }()

    func makeAIInsightsViewModel() -> AIInsightsViewModel {
        aiInsightsViewModel
    }

    func makeGoalsViewModel() -> GoalsViewModel {
        GoalsViewModel(
            fetchGoalsUseCase: fetchGoalsUseCase,
            createGoalUseCase: createGoalUseCase,
            updateGoalUseCase: updateGoalUseCase,
            generateSuggestionsUseCase: generateGoalSuggestionsUseCase,
            getGoalTipsUseCase: getGoalTipsUseCase
        )
    }

    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            createConversationUseCase: createConversationUseCase,
            sendMessageUseCase: sendChatMessageUseCase,
            fetchConversationsUseCase: fetchConversationsUseCase,
            chatRepository: chatRepository,
            chatService: chatService,
            tokenStorage: tokenStorage,
            goalAIService: goalAIService,
            createGoalUseCase: createGoalUseCase
        )
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            repository: userProfileRepository
        )
    }

    // MARK: - Data Restore

    /// Restore mood entries from backend if local database is empty
    /// Restore mood entries from backend if local database is empty
    func restoreMoodDataIfNeeded() async {
        do {
            // Check if database is empty
            let descriptor = FetchDescriptor<SDMoodEntry>()
            let existingEntries = try modelContext.fetch(descriptor)

            if existingEntries.isEmpty {
                print("⚠️ [AppDependencies] Local database is empty, attempting restore...")
                let result = try await syncMoodEntriesUseCase.execute()
                if result.totalSynced > 0 {
                    print("✅ [AppDependencies] \(result.description)")
                } else {
                    print("ℹ️ [AppDependencies] No mood entries found on backend")
                }
            } else {
                print(
                    "ℹ️ [AppDependencies] Database has \(existingEntries.count) entries, skipping restore"
                )
            }
        } catch {
            print("⚠️ [AppDependencies] Restore failed: \(error.localizedDescription)")
            // Don't crash - restore is best-effort
        }
    }

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }

    convenience init() {
        do {
            // Use versioned schema with auto-migration
            let schema = Schema(versionedSchema: SchemaVersioning.current)

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            let container: ModelContainer
            do {
                container = try ModelContainer(
                    for: schema,
                    migrationPlan: SchemaVersioning.MigrationPlan.self,
                    configurations: [modelConfiguration]
                )
            } catch {
                // If migration fails due to duplicate checksums, delete the database and recreate
                print("⚠️ [AppDependencies] Migration failed: \(error.localizedDescription)")
                print("⚠️ [AppDependencies] Deleting database and recreating...")

                // Delete the database files
                let url = modelConfiguration.url
                try? FileManager.default.removeItem(at: url)
                print("✅ [AppDependencies] Deleted database at: \(url.path)")

                // Recreate container with fresh database
                container = try ModelContainer(
                    for: schema,
                    migrationPlan: SchemaVersioning.MigrationPlan.self,
                    configurations: [modelConfiguration]
                )
                print("✅ [AppDependencies] Created fresh database with current schema")
            }

            self.init(modelContainer: container)

            // Configure UserSession to use FitIQCore's AuthManager
            UserSession.shared.configure(authManager: authManager)
            print("✅ [AppDependencies] UserSession configured with FitIQCore's AuthManager")
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

// MARK: - Preview Dependencies

extension AppDependencies {
    static var preview: AppDependencies {
        // Use versioned schema for previews too (in-memory, no migrations needed)
        let schema = Schema(
            versionedSchema: SchemaVersioning.current
        )

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try! ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        return AppDependencies(modelContainer: container)
    }
}
