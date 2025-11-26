// Domain/UseCases/SaveBodyMassUseCase.swift
// Migrated to FitIQCore on 2025-01-27 - Phase 5
import FitIQCore
import Foundation

public protocol SaveBodyMassUseCaseProtocol {
    func execute(weightKg: Double, date: Date) async throws
}

public final class SaveBodyMassUseCase: SaveBodyMassUseCaseProtocol {
    private let healthKitService: HealthKitServiceProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase

    init(
        healthKitService: HealthKitServiceProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManager,
        saveWeightProgressUseCase: SaveWeightProgressUseCase
    ) {
        self.healthKitService = healthKitService
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager
        self.saveWeightProgressUseCase = saveWeightProgressUseCase
    }

    public func execute(weightKg: Double, date: Date) async throws {
        guard let currentUserID = authManager.currentUserProfileID else {
            print("SaveBodyMassUseCase: No current user ID available. Cannot save body mass.")
            throw BodyMassError.userNotAuthenticated
        }

        print(
            "SaveBodyMassUseCase: Attempting to save \(weightKg)kg for user \(currentUserID) on \(date)..."
        )

        // 1. Save the body mass to HealthKit using FitIQCore
        let metric = FitIQCore.HealthMetric(
            type: .bodyMass,
            value: weightKg,
            unit: "kg",
            date: date,
            source: "FitIQ",
            metadata: [:]
        )
        try await healthKitService.save(metric: metric)
        print(
            "SaveBodyMassUseCase: Successfully saved \(weightKg)kg to HealthKit for user \(currentUserID) on \(date)."
        )

        // 2. Save to progress tracking (local + backend sync)
        // This will handle deduplication and backend sync automatically
        do {
            let localID = try await saveWeightProgressUseCase.execute(
                weightKg: weightKg,
                date: date
            )
            print(
                "SaveBodyMassUseCase: Successfully saved weight to progress tracking. Local ID: \(localID)"
            )
        } catch {
            print(
                "SaveBodyMassUseCase: Failed to save weight to progress tracking: \(error.localizedDescription)"
            )
            // We don't throw here because HealthKit save succeeded
            // The sync will be retried by RemoteSyncService
        }

        // 3. Note: FitIQCore handles data updates automatically via observers
        // No manual trigger needed - UI will refresh automatically
        print("SaveBodyMassUseCase: Body mass saved. FitIQCore will handle data updates.")
    }
}

// Custom Error for Body Mass operations
public enum BodyMassError: Error, LocalizedError {
    case userNotAuthenticated
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated. Please log in to save body mass data."
        case .saveFailed(let error):
            return "Failed to save body mass: \(error.localizedDescription)"
        }
    }
}
