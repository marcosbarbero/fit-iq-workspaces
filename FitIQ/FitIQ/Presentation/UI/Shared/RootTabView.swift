//
//  RootTabView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftData
import SwiftUI

struct RootTabView: View {
    @StateObject private var viewDependencies: ViewDependencies
    @StateObject private var authManager: AuthManager
    @StateObject private var deps: AppDependencies
    @StateObject private var viewModelDeps: ViewModelAppDependencies
    @StateObject private var tabManager = TabManager()

    // State to track the last tap for the double-tap logic
    @State private var lastTabTapTime: Date = Date.distantPast
    private let doubleTapDelay: TimeInterval = 0.35  // 350ms window

    // State for notification-driven alerts
    @StateObject private var navigator = AppNavigator.shared

    init(deps: AppDependencies, authManager: AuthManager) {
        let appearance = UITabBarAppearance()
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(.ascendBlue)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(.ascendBlue)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        _authManager = StateObject(wrappedValue: authManager)
        _deps = StateObject(wrappedValue: deps)

        let viewModelDeps = ViewModelAppDependencies.build(
            authManager: authManager, appDependencies: deps)
        _viewModelDeps = StateObject(wrappedValue: viewModelDeps)

        let viewDependencies = ViewDependencies.build(viewModelDependencies: viewModelDeps)
        _viewDependencies = StateObject(wrappedValue: viewDependencies)
    }

    // MARK: - Double-Tap Handling
    private func handleTabTap() {
        let now = Date()
        let isDoubleTap = now.timeIntervalSince(lastTabTapTime) < doubleTapDelay

        // Check for double tap on the currently selected tab
        if isDoubleTap {
            tabManager.popToRoot()
            // Reset time after action to prevent triple taps from counting
            lastTabTapTime = Date.distantPast
        } else {
            // Record the first tap time
            lastTabTapTime = now
        }
    }

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {

            // MARK: - Summary Tab
            NavigationStack(path: $tabManager.summaryPath) {
                viewDependencies.summaryView
                    .navigationBarTitleDisplayMode(.inline)
            }
            .id(tabManager.summaryPathID)
            .tag(TabManager.Tab.summary)
            .tabItem {
                Label(
                    TabManager.Tab.summary.displayName, systemImage: TabManager.Tab.summary.iconName
                )
            }

            NavigationStack(path: $tabManager.coachPath) {
                viewDependencies.coachView
            }
            .id(tabManager.coachPathID)
            .tag(TabManager.Tab.coach)
            .tabItem {
                Label(TabManager.Tab.coach.displayName, systemImage: TabManager.Tab.coach.iconName)
            }

            NavigationStack(path: $tabManager.nutritionPath) {
                viewDependencies.nutritionView
            }
            .id(tabManager.nutritionPathID)
            .tag(TabManager.Tab.nutrition)
            .tabItem {
                Label(L10n.Navigation.nutrition, systemImage: TabManager.Tab.nutrition.iconName)
            }

            // MARK: - Workouts Tab
            NavigationStack(path: $tabManager.workoutsPath) {
                WorkoutView()
            }
            .id(tabManager.workoutsPathID)
            .tag(TabManager.Tab.workouts)
            .tabItem {
                Label(L10n.Navigation.workouts, systemImage: TabManager.Tab.workouts.iconName)
            }

            // MARK: - Community Tab
            NavigationStack(path: $tabManager.communityPath) {
                CommunityView()
            }
            .id(tabManager.communityPathID)
            .tag(TabManager.Tab.community)
            .tabItem {
                Label(L10n.Navigation.community, systemImage: TabManager.Tab.community.iconName)
            }
        }
        .task {
            // Only proceed if user is authenticated
            guard let userID = authManager.currentUserProfileID else {
                print("RootTabView: User ID is nil. Skipping HealthKit setup and monitoring.")
                deps.localDataChangeMonitor.stopMonitoring()
                deps.remoteSyncService.stopSyncing()
                return
            }

            // Ensure HealthDataSyncService is configured
            deps.healthDataSyncService.configure(withUserProfileID: userID)

            // Register background tasks (always do this if we are in RootTabView)
            deps.backgroundSyncManager.registerBackgroundTasks()

            do {
                if try await deps.userHasHealthKitAuthorizationUseCase.execute() {
                    print(
                        "RootTabView: HealthKit authorization granted. Starting observers and monitoring."
                    )

                    // Start HealthKit observers (non-blocking)
                    try await deps.backgroundSyncManager.startHealthKitObservations()

                    // Start local data monitoring (non-blocking)
                    deps.localDataChangeMonitor.startMonitoring(forUserID: userID)
                    deps.remoteSyncService.startSyncing(forUserID: userID)

                    print("RootTabView: ✅ HealthKit observers and monitoring started")

                    // Load data into ViewModels (initial sync already done in FitIQApp)
                    print("\n" + String(repeating: "=", count: 60))
                    print("📊 RootTabView: Loading data into SummaryViewModel...")
                    print(String(repeating: "=", count: 60) + "\n")

                    await viewModelDeps.summaryViewModel.reloadAllData()

                    print("\n" + String(repeating: "=", count: 60))
                    print("✅ RootTabView: Data loaded into SummaryViewModel")
                    print(String(repeating: "=", count: 60) + "\n")

                    // Start progressive historical sync in background (90 days total)
                    // ONLY run once per user to prevent database bloat from duplication
                    let hasCompletedProgressiveSync = UserDefaults.standard.bool(
                        forKey: "hasCompletedProgressiveSync_\(userID)")

                    if !hasCompletedProgressiveSync
                        && !deps.progressiveHistoricalSyncService.isSyncing
                    {
                        print(
                            "\n🚀 RootTabView: Starting progressive historical sync (7-90 days)..."
                        )
                        deps.progressiveHistoricalSyncService.startProgressiveSync(
                            forUserID: userID)
                        print("✓ RootTabView: Progressive sync started in background\n")

                        // Mark as started (will be marked complete when done)
                        UserDefaults.standard.set(
                            true, forKey: "hasStartedProgressiveSync_\(userID)")
                    } else {
                        print(
                            "⏭️ RootTabView: Progressive sync already completed or in progress - skipping"
                        )
                    }

                } else {
                    print(
                        "RootTabView: HealthKit authorization not fully granted. Skipping observers and monitoring."
                    )
                    deps.localDataChangeMonitor.stopMonitoring()
                    deps.remoteSyncService.stopSyncing()
                }
            } catch {
                print("RootTabView: Error during HealthKit setup: \(error.localizedDescription)")
                deps.localDataChangeMonitor.stopMonitoring()
                deps.remoteSyncService.stopSyncing()
            }
        }
        .onDisappear {
            deps.localDataChangeMonitor.stopMonitoring()
            deps.remoteSyncService.stopSyncing()  // NEW: Stop remote sync service on disappear
            deps.progressiveHistoricalSyncService.stopProgressiveSync()  // Stop progressive sync
        }
        .onTapGesture(perform: handleTabTap)
        .environmentObject(tabManager)
    }
}
