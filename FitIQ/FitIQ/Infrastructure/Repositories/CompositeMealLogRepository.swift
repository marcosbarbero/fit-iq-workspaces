//
//  CompositeMealLogRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Composite repository combining local storage and remote API operations
//

import Foundation

/// Composite repository that implements local-first architecture for meal logs
///
/// This repository combines local storage (SwiftData) and remote API operations,
/// delegating to the appropriate adapter based on the operation type.
///
/// **Architecture Pattern:**
/// - Local-first: Always save locally first for offline capability
/// - Background sync: Use Outbox Pattern for reliable backend synchronization
/// - Read operations: Can read from local or remote based on use case needs
///
/// **Responsibilities:**
/// - Delegate local storage operations to `SwiftDataMealLogRepository`
/// - Delegate remote API operations to `NutritionAPIClient`
/// - Maintain single point of access for meal log operations
///
final class CompositeMealLogRepository: MealLogRepositoryProtocol {

    // MARK: - Dependencies

    private let localRepository: MealLogLocalStorageProtocol
    private let remoteAPIClient: MealLogRemoteAPIProtocol

    // MARK: - Initialization

    init(
        localRepository: MealLogLocalStorageProtocol,
        remoteAPIClient: MealLogRemoteAPIProtocol
    ) {
        self.localRepository = localRepository
        self.remoteAPIClient = remoteAPIClient
    }

    // MARK: - MealLogLocalStorageProtocol

    func save(mealLog: MealLog, forUserID userID: String) async throws -> UUID {
        return try await localRepository.save(mealLog: mealLog, forUserID: userID)
    }

    func fetchLocal(
        forUserID userID: String,
        status: MealLogStatus?,
        syncStatus: SyncStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [MealLog] {
        return try await localRepository.fetchLocal(
            forUserID: userID,
            status: status,
            syncStatus: syncStatus,
            startDate: startDate,
            endDate: endDate,
            limit: limit
        )
    }

    func fetchByID(_ id: UUID, forUserID userID: String) async throws -> MealLog? {
        return try await localRepository.fetchByID(id, forUserID: userID)
    }

    func updateStatus(
        forLocalID localID: UUID,
        status: MealLogStatus,
        items: [MealLogItem]?,
        totalCalories: Int?,
        totalProteinG: Double?,
        totalCarbsG: Double?,
        totalFatG: Double?,
        totalFiberG: Double?,
        totalSugarG: Double?,
        errorMessage: String?,
        forUserID userID: String
    ) async throws {
        try await localRepository.updateStatus(
            forLocalID: localID,
            status: status,
            items: items,
            totalCalories: totalCalories,
            totalProteinG: totalProteinG,
            totalCarbsG: totalCarbsG,
            totalFatG: totalFatG,
            totalFiberG: totalFiberG,
            totalSugarG: totalSugarG,
            errorMessage: errorMessage,
            forUserID: userID
        )
    }

    func updateBackendID(
        forLocalID localID: UUID,
        backendID: String,
        forUserID userID: String
    ) async throws {
        try await localRepository.updateBackendID(
            forLocalID: localID,
            backendID: backendID,
            forUserID: userID
        )
    }

    func updateSyncStatus(
        forLocalID localID: UUID,
        syncStatus: SyncStatus,
        forUserID userID: String
    ) async throws {
        try await localRepository.updateSyncStatus(
            forLocalID: localID,
            syncStatus: syncStatus,
            forUserID: userID
        )
    }

    func delete(_ id: UUID, forUserID userID: String) async throws {
        try await localRepository.delete(id, forUserID: userID)
    }

    func deleteAll(forUserID userID: String) async throws {
        try await localRepository.deleteAll(forUserID: userID)
    }

    // MARK: - MealLogRemoteAPIProtocol

    func submitMealLog(
        rawInput: String,
        mealType: String,
        loggedAt: Date,
        notes: String?
    ) async throws -> MealLog {
        return try await remoteAPIClient.submitMealLog(
            rawInput: rawInput,
            mealType: mealType,
            loggedAt: loggedAt,
            notes: notes
        )
    }

    func getMealLogs(
        status: MealLogStatus?,
        mealType: String?,
        startDate: Date?,
        endDate: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [MealLog] {
        return try await remoteAPIClient.getMealLogs(
            status: status,
            mealType: mealType,
            startDate: startDate,
            endDate: endDate,
            page: page,
            limit: limit
        )
    }

    func getMealLogByID(_ id: String) async throws -> MealLog {
        return try await remoteAPIClient.getMealLogByID(id)
    }

    func deleteMealLog(backendID: String) async throws {
        return try await remoteAPIClient.deleteMealLog(backendID: backendID)
    }
}
