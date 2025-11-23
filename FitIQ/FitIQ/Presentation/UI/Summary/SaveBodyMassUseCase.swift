// Domain/UseCases/SaveBodyMassUseCase.swift
import Foundation
import HealthKit  // For HKQuantityTypeIdentifier and HKUnit

public protocol SaveBodyMassUseCaseProtocol {
    func execute(weightKg: Double, date: Date) async throws
}

public final class SaveBodyMassUseCase: SaveBodyMassUseCaseProtocol {
    private let healthRepository: HealthRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase

    init(
        healthRepository: HealthRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManager,
        saveWeightProgressUseCase: SaveWeightProgressUseCase
    ) {
        self.healthRepository = healthRepository
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

        // 1. Save the body mass to HealthKit
        // The HealthKitAdapter now has a saveQuantitySample method
        try await healthRepository.saveQuantitySample(
            value: weightKg,
            unit: .gramUnit(with: .kilo),
            typeIdentifier: .bodyMass,
            date: date
        )
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

        // 3. OPTIONAL: Manually trigger a data update for bodyMass to ensure immediate UI refresh
        // This can be useful if the observer query takes a moment to fire or if UI needs immediate feedback.
        // The HealthDataSyncManager.processNewHealthData will then process this.
        // It's already set up to be called by HealthKitAdapter's onDataUpdate closure.
        healthRepository.onDataUpdate?(.bodyMass)
        print("SaveBodyMassUseCase: Signaled onDataUpdate for .bodyMass.")
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
