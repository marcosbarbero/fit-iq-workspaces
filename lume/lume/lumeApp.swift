//
//  lumeApp.swift
//  lume
//
//  Created by Marcos Barbero on 14/11/2025.
//

import SwiftData
import SwiftUI

@main
struct lumeApp: App {
    @State private var dependencies: AppDependencies
    @State private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let deps = AppDependencies()
        self.dependencies = deps
        self.authViewModel = deps.makeAuthViewModel()

        // Set up authentication callback
        deps.outboxProcessorService.onAuthenticationRequired = { [weak authViewModel] in
            Task { @MainActor in
                print("🔐 [lumeApp] Authentication required - logging out user")
                authViewModel?.isAuthenticated = false

                // Clear token
                try? await deps.tokenStorage.deleteToken()
            }
        }

        // Run user data migration (UserDefaults → Keychain)
        Task { @MainActor in
            await UserSessionMigration.migrateIfNeeded(authManager: deps.authManager)
        }

        // Log app startup configuration
        print("🚀 [lumeApp] Starting Lume app")
        print("📱 [lumeApp] App Mode: \(AppMode.current.displayName)")
        print("🔧 [lumeApp] Backend enabled: \(AppMode.useBackend)")
        if AppMode.useBackend {
            print(
                "🌐 [lumeApp] Backend URL: \(AppConfiguration.shared.backendBaseURL.absoluteString)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authViewModel: authViewModel,
                dependencies: dependencies
            )
            .onAppear {
                startOutboxProcessing()
                restoreDataIfNeeded()
            }
        }
        .modelContainer(dependencies.modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    // MARK: - Outbox Processing Lifecycle

    private func startOutboxProcessing() {
        // Only start if in production mode
        guard AppMode.useBackend else {
            print(
                "🔵 [lumeApp] Outbox processing disabled (AppMode: \(AppMode.current.displayName))")
            print(
                "💡 [lumeApp] To enable backend sync: Set AppMode.current = .production in AppMode.swift"
            )
            return
        }

        Task { @MainActor in
            // Start periodic processing every 10 seconds (for faster dev validation)
            dependencies.outboxProcessorService.startProcessing(interval: 10)
            print("✅ [lumeApp] Outbox processing started (interval: 10s)")
            print("📦 [lumeApp] Outbox will sync mood data to backend automatically")
        }
    }

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active, trigger immediate processing
            if AppMode.useBackend {
                print("🔄 [lumeApp] App became active, triggering outbox processing")
                Task { @MainActor in
                    await dependencies.outboxProcessorService.processOutbox()
                }
            }

        case .background:
            // App moved to background, events will be processed on next activation
            print("🔵 [lumeApp] App in background, outbox processing continues")

        case .inactive:
            // App becoming inactive
            break

        @unknown default:
            break
        }
    }

    // MARK: - Data Restore

    private func restoreDataIfNeeded() {
        Task { @MainActor in
            await dependencies.restoreMoodDataIfNeeded()
        }
    }
}
