//
//  SwiftDataMealLogRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: SwiftData implementation of MealLogLocalStorageProtocol with Outbox Pattern
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData adapter for meal log persistence following Hexagonal Architecture
/// Implements Outbox Pattern for reliable backend synchronization
final class SwiftDataMealLogRepository: MealLogLocalStorageProtocol {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol

    // MARK: - Initialization

    init(modelContext: ModelContext, outboxRepository: OutboxRepositoryProtocol) {
        self.modelContext = modelContext
        self.outboxRepository = outboxRepository
    }

    // MARK: - Save Operations

    func save(mealLog: MealLog, forUserID userID: String) async throws -> UUID {
        let saveStartTime = Date()
        print(
            "SwiftDataMealLogRepository: 💾 Saving meal log for user \(userID) at \(saveStartTime)")
        print("SwiftDataMealLogRepository: Raw input: '\(mealLog.rawInput)'")
        print("SwiftDataMealLogRepository: Meal type: \(mealLog.mealType)")

        // 1. Fetch user profile
        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        let userProfileDescriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate<SDUserProfile> { profile in
                profile.id == userUUID
            }
        )
        guard let userProfile = try modelContext.fetch(userProfileDescriptor).first else {
            throw MealLogRepositoryError.userProfileNotFound
        }

        // 2. Convert meal log items to SwiftData models (if present)
        let sdItems = mealLog.items.map { item in
            SDMealLogItem(
                id: item.id,
                mealLog: nil,  // Will be set below via relationship
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                foodType: item.foodType.rawValue,
                fiberG: item.fiber,
                sugarG: item.sugar,
                confidence: item.confidence,
                parsingNotes: item.parsingNotes,
                orderIndex: item.orderIndex,
                createdAt: item.createdAt,
                backendID: item.backendID
            )
        }

        // 3. Convert domain model to SwiftData model
        let sdMealLog = SDMealLog(
            id: mealLog.id,
            userProfile: userProfile,
            rawInput: mealLog.rawInput,
            mealType: mealLog.mealType.rawValue,
            status: mealLog.status.rawValue,
            loggedAt: mealLog.loggedAt,
            items: sdItems,  // Include items (for photo meals and backend-processed meals)
            notes: mealLog.notes,
            totalCalories: mealLog.totalCalories,
            totalProteinG: mealLog.totalProteinG,
            totalCarbsG: mealLog.totalCarbsG,
            totalFatG: mealLog.totalFatG,
            totalFiberG: mealLog.totalFiberG,
            totalSugarG: mealLog.totalSugarG,
            createdAt: mealLog.createdAt,
            updatedAt: mealLog.updatedAt,
            backendID: mealLog.backendID,
            syncStatus: mealLog.syncStatus.rawValue,
            errorMessage: mealLog.errorMessage
        )

        // 4. Insert into context
        modelContext.insert(sdMealLog)
        try modelContext.save()

        print(
            "SwiftDataMealLogRepository: Saved meal log with \(mealLog.items.count) items, totals: \(mealLog.totalCalories ?? 0) cal, \(mealLog.totalProteinG ?? 0)g protein, \(mealLog.totalFiberG ?? 0)g fiber"
        )

        let contextSaveDuration = Date().timeIntervalSince(saveStartTime)
        print(
            "SwiftDataMealLogRepository: Meal log saved to SwiftData with ID \(mealLog.id) (duration: \(String(format: "%.3f", contextSaveDuration))s)"
        )

        // 5. ✅ OUTBOX PATTERN: Create outbox event for backend sync (only if syncStatus is pending)
        guard mealLog.syncStatus == .pending else {
            print(
                "SwiftDataMealLogRepository: Skipping Outbox event creation - meal log already synced (syncStatus: \(mealLog.syncStatus.rawValue))"
            )
            return mealLog.id
        }
        let metadata: OutboxMetadata = .generic([
            "mealLogID": mealLog.id.uuidString,
            "mealType": mealLog.mealType.rawValue,
            "rawInput": mealLog.rawInput,
            "loggedAt": ISO8601DateFormatter().string(from: mealLog.loggedAt),
            "hasNotes": String(mealLog.notes != nil),
        ])

        let outboxStartTime = Date()
        _ = try await outboxRepository.createEvent(
            eventType: .mealLog,
            entityID: mealLog.id,
            userID: userID,
            isNewRecord: mealLog.backendID == nil,
            metadata: metadata,
            priority: 7  // Higher priority for meal logs (user-generated content)
        )

        let outboxDuration = Date().timeIntervalSince(outboxStartTime)
        let totalDuration = Date().timeIntervalSince(saveStartTime)
        print(
            "SwiftDataMealLogRepository: ✅ Outbox event created for meal log \(mealLog.id) (outbox: \(String(format: "%.3f", outboxDuration))s, total: \(String(format: "%.3f", totalDuration))s)"
        )

        return mealLog.id
    }

    // MARK: - Fetch Operations

    func fetchLocal(
        forUserID userID: String,
        status: MealLogStatus?,
        syncStatus: SyncStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [MealLog] {
        print("SwiftDataMealLogRepository: Fetching meal logs for user \(userID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        // Build predicate for user and date filters only
        // (Status and syncStatus will be filtered in memory to avoid predicate macro issues)
        var descriptor: FetchDescriptor<SDMealLog>

        switch (startDate, endDate) {
        case (.some(let start), .some(let end)):
            descriptor = FetchDescriptor<SDMealLog>(
                predicate: #Predicate { meal in
                    meal.userProfile?.id == userUUID
                        && meal.loggedAt >= start
                        && meal.loggedAt <= end
                },
                sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
            )
        case (.some(let start), nil):
            descriptor = FetchDescriptor<SDMealLog>(
                predicate: #Predicate { meal in
                    meal.userProfile?.id == userUUID && meal.loggedAt >= start
                },
                sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
            )
        case (nil, .some(let end)):
            descriptor = FetchDescriptor<SDMealLog>(
                predicate: #Predicate { meal in
                    meal.userProfile?.id == userUUID && meal.loggedAt <= end
                },
                sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
            )
        case (nil, nil):
            descriptor = FetchDescriptor<SDMealLog>(
                predicate: #Predicate { meal in
                    meal.userProfile?.id == userUUID
                },
                sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
            )
        }

        // Apply limit if provided
        if let limit = limit {
            descriptor.fetchLimit = limit
        }

        var sdMealLogs = try modelContext.fetch(descriptor)

        // Filter by status in memory if provided
        if let status = status {
            sdMealLogs = sdMealLogs.filter { $0.status == status.rawValue }
        }

        // Filter by syncStatus in memory if provided
        if let syncStatus = syncStatus {
            sdMealLogs = sdMealLogs.filter { $0.syncStatus == syncStatus.rawValue }
        }

        let domainMealLogs = sdMealLogs.map { $0.toDomain() }

        print("SwiftDataMealLogRepository: Fetched \(domainMealLogs.count) meal logs")
        return domainMealLogs
    }

    func fetchByID(_ id: UUID, forUserID userID: String) async throws -> MealLog? {
        print("SwiftDataMealLogRepository: Fetching meal log by ID \(id)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDMealLog>(
            predicate: #Predicate { mealLog in
                mealLog.id == id && mealLog.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        let sdMealLogs = try modelContext.fetch(descriptor)
        return sdMealLogs.first?.toDomain()
    }

    // MARK: - Update Operations

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
        print("SwiftDataMealLogRepository: Updating status for meal log \(localID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDMealLog>(
            predicate: #Predicate { mealLog in
                mealLog.id == localID && mealLog.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdMealLog = try modelContext.fetch(descriptor).first else {
            throw MealLogRepositoryError.mealLogNotFound
        }

        // Update status
        sdMealLog.status = status.rawValue
        print("SwiftDataMealLogRepository: Updated status to \(status)")

        // Update items if provided
        if let items = items {
            // Convert domain items to SwiftData items
            let sdItems = items.map { item in
                SDMealLogItem(
                    id: item.id,
                    mealLog: sdMealLog,
                    name: item.name,
                    quantity: item.quantity,
                    unit: item.unit,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    foodType: item.foodType.rawValue,
                    fiberG: item.fiber,
                    sugarG: item.sugar,
                    confidence: item.confidence,
                    parsingNotes: item.parsingNotes,
                    orderIndex: item.orderIndex,
                    createdAt: item.createdAt,
                    backendID: item.backendID
                )
            }
            sdMealLog.items = sdItems
            print("SwiftDataMealLogRepository: Updated items count: \(items.count)")
        }

        // Update total nutritional values if provided
        if let totalCalories = totalCalories {
            sdMealLog.totalCalories = totalCalories
            print("SwiftDataMealLogRepository: Updated totalCalories: \(totalCalories)")
        }

        if let totalProteinG = totalProteinG {
            sdMealLog.totalProteinG = totalProteinG
            print("SwiftDataMealLogRepository: Updated totalProteinG: \(totalProteinG)")
        }

        if let totalCarbsG = totalCarbsG {
            sdMealLog.totalCarbsG = totalCarbsG
            print("SwiftDataMealLogRepository: Updated totalCarbsG: \(totalCarbsG)")
        }

        if let totalFatG = totalFatG {
            sdMealLog.totalFatG = totalFatG
            print("SwiftDataMealLogRepository: Updated totalFatG: \(totalFatG)")
        }

        if let totalFiberG = totalFiberG {
            sdMealLog.totalFiberG = totalFiberG
            print("SwiftDataMealLogRepository: Updated totalFiberG: \(totalFiberG)")
        }

        if let totalSugarG = totalSugarG {
            sdMealLog.totalSugarG = totalSugarG
            print("SwiftDataMealLogRepository: Updated totalSugarG: \(totalSugarG)")
        }

        // Update error message if provided
        if let errorMessage = errorMessage {
            sdMealLog.errorMessage = errorMessage
            print("SwiftDataMealLogRepository: Updated errorMessage")
        }

        sdMealLog.updatedAt = Date()

        try modelContext.save()
        print("SwiftDataMealLogRepository: Meal log updated successfully")
    }

    func updateBackendID(
        forLocalID localID: UUID,
        backendID: String,
        forUserID userID: String
    ) async throws {
        print("SwiftDataMealLogRepository: Updating backend ID for meal log \(localID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDMealLog>(
            predicate: #Predicate { mealLog in
                mealLog.id == localID && mealLog.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdMealLog = try modelContext.fetch(descriptor).first else {
            throw MealLogRepositoryError.mealLogNotFound
        }

        sdMealLog.backendID = backendID
        sdMealLog.updatedAt = Date()

        try modelContext.save()
        print("SwiftDataMealLogRepository: Backend ID updated successfully")
    }

    func updateSyncStatus(
        forLocalID localID: UUID,
        syncStatus: SyncStatus,
        forUserID userID: String
    ) async throws {
        print(
            "SwiftDataMealLogRepository: Updating sync status for meal log \(localID) to \(syncStatus)"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDMealLog>(
            predicate: #Predicate { mealLog in
                mealLog.id == localID && mealLog.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdMealLog = try modelContext.fetch(descriptor).first else {
            throw MealLogRepositoryError.mealLogNotFound
        }

        sdMealLog.syncStatus = syncStatus.rawValue
        sdMealLog.updatedAt = Date()

        try modelContext.save()
        print("SwiftDataMealLogRepository: Sync status updated successfully")
    }

    // MARK: - Delete Operations

    func delete(_ id: UUID, forUserID userID: String) async throws {
        print("SwiftDataMealLogRepository: Deleting meal log \(id)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDMealLog>(
            predicate: #Predicate { mealLog in
                mealLog.id == id && mealLog.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdMealLog = try modelContext.fetch(descriptor).first else {
            throw MealLogRepositoryError.mealLogNotFound
        }

        // ✅ OUTBOX PATTERN: If meal was synced to backend, create deletion event
        if let backendID = sdMealLog.backendID, !backendID.isEmpty {
            print(
                "SwiftDataMealLogRepository: Creating outbox event for backend deletion (backendID: \(backendID))"
            )

            let metadata: OutboxMetadata = .generic([
                "operation": "delete",
                "backendID": backendID,
                "deletedAt": ISO8601DateFormatter().string(from: Date()),
            ])

            let _ = try await outboxRepository.createEvent(
                eventType: .mealLog,
                entityID: id,
                userID: userID,
                isNewRecord: false,
                metadata: metadata,
                priority: 5
            )

            print("SwiftDataMealLogRepository: ✅ Outbox event created for backend deletion")
        } else {
            print("SwiftDataMealLogRepository: No backendID, skipping remote deletion")
        }

        // Break relationship to SDUserProfile before deleting
        sdMealLog.userProfile = nil

        // Cascade delete will automatically delete associated items
        modelContext.delete(sdMealLog)
        try modelContext.save()

        print("SwiftDataMealLogRepository: ✅ Meal log deleted locally")
    }

    func deleteAll(forUserID userID: String) async throws {
        print("SwiftDataMealLogRepository: Deleting all meal logs for user \(userID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw MealLogRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDMealLog>(
            predicate: #Predicate { $0.userProfile?.id == userUUID }
        )

        let sdMealLogs = try modelContext.fetch(descriptor)

        // Break relationship to SDUserProfile before deleting
        for mealLog in sdMealLogs {
            mealLog.userProfile = nil
        }

        // Delete all meal logs (cascade delete will handle items)
        for mealLog in sdMealLogs {
            modelContext.delete(mealLog)
        }

        try modelContext.save()
        print("SwiftDataMealLogRepository: Deleted \(sdMealLogs.count) meal logs")
    }
}

// MARK: - Error Types

enum MealLogRepositoryError: Error, LocalizedError {
    case mealLogNotFound
    case invalidUserID
    case userProfileNotFound
    case saveFailed(reason: String)
    case fetchFailed(reason: String)
    case updateFailed(reason: String)
    case deleteFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .mealLogNotFound:
            return "Meal log not found"
        case .invalidUserID:
            return "Invalid user ID"
        case .userProfileNotFound:
            return "User profile not found"
        case .saveFailed(let reason):
            return "Failed to save meal log: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch meal logs: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update meal log: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete meal log: \(reason)"
        }
    }
}
