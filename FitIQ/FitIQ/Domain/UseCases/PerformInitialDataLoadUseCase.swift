//
//  PerformInitialDataLoadUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Protocol defining the initial data load operation after onboarding
protocol PerformInitialDataLoadUseCase {
    /// Performs initial data load: syncs HealthKit data and loads it into ViewModels
    /// - Parameter userID: The user's profile ID
    /// - Returns: True if successful, false otherwise
    func execute(forUserID userID: UUID) async throws
}

/// Implementation of the initial data load use case
/// Coordinates HealthKit sync and ViewModel data loading after onboarding
final class PerformInitialDataLoadUseCaseImpl: PerformInitialDataLoadUseCase {

    // MARK: - Dependencies (Ports)
    private let userHasHealthKitAuthorizationUseCase: UserHasHealthKitAuthorizationUseCase
    private let performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol

    // MARK: - Init
    init(
        userHasHealthKitAuthorizationUseCase: UserHasHealthKitAuthorizationUseCase,
        performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol
    ) {
        self.userHasHealthKitAuthorizationUseCase = userHasHealthKitAuthorizationUseCase
        self.performInitialHealthKitSyncUseCase = performInitialHealthKitSyncUseCase
    }

    // MARK: - Execute
    func execute(forUserID userID: UUID) async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("🔄 PerformInitialDataLoadUseCase: Starting initial data load")
        print(String(repeating: "=", count: 60))

        // Step 1: Check HealthKit authorization
        guard try await userHasHealthKitAuthorizationUseCase.execute() else {
            print("⚠️ HealthKit not authorized. Skipping sync.")
            throw InitialDataLoadError.healthKitNotAuthorized
        }
        print("✓ HealthKit authorization confirmed")

        // Step 2: Perform initial HealthKit sync (handles configuration internally)
        print("\n🔄 Syncing data from HealthKit...")
        let syncStart = Date()

        try await performInitialHealthKitSyncUseCase.execute(forUserID: userID)

        let syncDuration = Date().timeIntervalSince(syncStart)
        print("✅ HealthKit sync completed in \(String(format: "%.2f", syncDuration))s")

        // Step 3: Allow data to stabilize in SwiftData
        print("\n⏳ Waiting for data stabilization...")
        try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms
        print("✓ Data stabilization complete")

        print("\n" + String(repeating: "=", count: 60))
        print("✅ PerformInitialDataLoadUseCase: Initial data load complete")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Errors
enum InitialDataLoadError: LocalizedError {
    case healthKitNotAuthorized
    case userIDNotFound
    case syncFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .healthKitNotAuthorized:
            return "HealthKit authorization is required to sync your health data."
        case .userIDNotFound:
            return "User ID not found. Please log in again."
        case .syncFailed(let error):
            return "Failed to sync health data: \(error.localizedDescription)"
        }
    }
}
