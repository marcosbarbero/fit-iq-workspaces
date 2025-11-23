//
//  GoalRepository.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of GoalRepositoryProtocol
/// Handles local persistence of user goals
final class GoalRepository: GoalRepositoryProtocol, UserAuthenticatedRepository {
    private let modelContext: ModelContext
    private let backendService: GoalBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let outboxRepository: OutboxRepositoryProtocol

    init(
        modelContext: ModelContext,
        backendService: GoalBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        outboxRepository: OutboxRepositoryProtocol
    ) {
        self.modelContext = modelContext
        self.backendService = backendService
        self.tokenStorage = tokenStorage
        self.outboxRepository = outboxRepository
    }

    // MARK: - Create & Update

    func create(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?,
        targetValue: Double = 1.0,
        targetUnit: String = "completion"
    ) async throws -> Goal {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let goal = Goal(
            userId: userId,
            title: title,
            description: description,
            targetDate: targetDate,
            category: category,
            targetValue: targetValue,
            targetUnit: targetUnit
        )

        let sdGoal = toSwiftData(goal)
        modelContext.insert(sdGoal)
        try modelContext.save()

        // Create outbox event for backend sync
        do {
            let userID = try getCurrentUserId().uuidString

            let metadata = OutboxMetadata.goal(
                title: title,
                category: category.rawValue
            )

            _ = try await outboxRepository.createEvent(
                eventType: .goal,
                entityID: goal.id,
                userID: userID,
                isNewRecord: true,
                metadata: metadata,
                priority: 5
            )
            print("✅ [GoalRepository] Created outbox event for goal: \(goal.id)")
        } catch {
            print("⚠️ [GoalRepository] Failed to create outbox event: \(error)")
            // Don't fail the creation - outbox will retry later
        }

        return goal
    }

    func update(_ goal: Goal) async throws -> Goal {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == goal.id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            throw GoalRepositoryError.notFound
        }

        updateSDGoal(sdGoal, from: goal)
        try modelContext.save()

        // Create outbox event for backend sync
        do {
            let userID = try getCurrentUserId().uuidString

            let metadata = OutboxMetadata.goal(
                title: goal.title,
                category: goal.category.rawValue
            )

            _ = try await outboxRepository.createEvent(
                eventType: .goal,
                entityID: goal.id,
                userID: userID,
                isNewRecord: false,
                metadata: metadata,
                priority: 5
            )
            print("✅ [GoalRepository] Created outbox event for goal update: \(goal.id)")
        } catch {
            print("⚠️ [GoalRepository] Failed to create outbox event: \(error)")
            // Don't fail the update - outbox will retry later
        }

        return toDomain(sdGoal)
    }

    func updateProgress(id: UUID, progress: Double) async throws -> Goal {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            throw GoalRepositoryError.notFound
        }

        // Clamp progress between 0.0 and 1.0
        sdGoal.progress = min(max(progress, 0.0), 1.0)
        sdGoal.updatedAt = Date()

        // Auto-complete if progress reaches 100%
        if sdGoal.progress >= 1.0 && sdGoal.status == "active" {
            sdGoal.status = "completed"
        }

        try modelContext.save()

        let updatedGoal = toDomain(sdGoal)

        // Create outbox event for backend sync
        do {
            let userID = try getCurrentUserId().uuidString

            let metadata = OutboxMetadata.goal(
                title: updatedGoal.title,
                category: updatedGoal.category.rawValue
            )

            _ = try await outboxRepository.createEvent(
                eventType: .goal,
                entityID: id,
                userID: userID,
                isNewRecord: false,
                metadata: metadata,
                priority: 5
            )
            print("✅ [GoalRepository] Created outbox event for progress update: \(id)")
        } catch {
            print("⚠️ [GoalRepository] Failed to create outbox event: \(error)")
            // Don't fail the update - outbox will retry later
        }

        return updatedGoal
    }

    func updateStatus(id: UUID, status: GoalStatus) async throws -> Goal {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            throw GoalRepositoryError.notFound
        }

        sdGoal.status = status.rawValue
        sdGoal.updatedAt = Date()

        try modelContext.save()

        let updatedGoal = toDomain(sdGoal)

        // Create outbox event for backend sync
        do {
            let userID = try getCurrentUserId().uuidString

            let metadata = OutboxMetadata.goal(
                title: updatedGoal.title,
                category: updatedGoal.category.rawValue
            )

            _ = try await outboxRepository.createEvent(
                eventType: .goal,
                entityID: id,
                userID: userID,
                isNewRecord: false,
                metadata: metadata,
                priority: 5
            )
            print("✅ [GoalRepository] Created outbox event for status update: \(id)")
        } catch {
            print("⚠️ [GoalRepository] Failed to create outbox event: \(error)")
            // Don't fail the update - outbox will retry later
        }

        return updatedGoal
    }

    // MARK: - Read

    func fetchAll() async throws -> [Goal] {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\SDGoal.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchByStatus(_ status: GoalStatus) async throws -> [Goal] {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let statusString = status.rawValue

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { goal in
                goal.userId == userId && goal.status == statusString
            },
            sortBy: [SortDescriptor(\SDGoal.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchByCategory(_ category: GoalCategory) async throws -> [Goal] {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let categoryString = category.rawValue

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { goal in
                goal.userId == userId && goal.category == categoryString
            },
            sortBy: [SortDescriptor(\SDGoal.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchActive() async throws -> [Goal] {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { goal in
                goal.userId == userId && goal.status == "active"
            },
            sortBy: [SortDescriptor(\SDGoal.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchOverdue() async throws -> [Goal] {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let now = Date()

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { goal in
                goal.userId == userId
                    && goal.status == "active"
                    && goal.targetDate != nil
                    && goal.targetDate! < now
                    && goal.progress < 1.0
            },
            sortBy: [SortDescriptor(\SDGoal.targetDate, order: .forward)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchById(_ id: UUID) async throws -> Goal? {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return toDomain(sdGoal)
    }

    func getBackendId(for id: UUID) async throws -> String? {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdGoal.backendId
    }

    func getCachedTips(for goalId: UUID) async throws -> [GoalTip]? {
        let descriptor = FetchDescriptor<SDGoalTipCache>(
            predicate: #Predicate { $0.goalId == goalId }
        )

        guard let cache = try modelContext.fetch(descriptor).first else {
            return nil
        }

        // Check if cache is still valid
        guard cache.isValid else {
            // Delete expired cache
            modelContext.delete(cache)
            try modelContext.save()
            return nil
        }

        return convertCacheToDomain(cache)
    }

    func cacheTips(
        for goalId: UUID,
        backendId: String?,
        tips: [GoalTip],
        expirationDays: Int = 7
    ) async throws {
        // Remove existing cache for this goal
        let descriptor = FetchDescriptor<SDGoalTipCache>(
            predicate: #Predicate { $0.goalId == goalId }
        )

        if let existingCache = try modelContext.fetch(descriptor).first {
            modelContext.delete(existingCache)
        }

        // Create new cache entry
        guard
            let cache = createCacheFromDomain(
                goalId: goalId,
                backendId: backendId,
                tips: tips,
                expirationDays: expirationDays
            )
        else {
            throw GoalRepositoryError.cacheFailed
        }

        modelContext.insert(cache)
        try modelContext.save()

        print("✅ [GoalRepository] Cached \(tips.count) tips for goal \(goalId)")
    }

    func clearExpiredTipCaches() async throws {
        let descriptor = FetchDescriptor<SDGoalTipCache>()
        let allCaches = try modelContext.fetch(descriptor)

        var deletedCount = 0
        for cache in allCaches where cache.isExpired {
            modelContext.delete(cache)
            deletedCount += 1
        }

        if deletedCount > 0 {
            try modelContext.save()
            print("✅ [GoalRepository] Cleared \(deletedCount) expired tip caches")
        }
    }

    // MARK: - Delete & Archive

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            throw GoalRepositoryError.notFound
        }

        modelContext.delete(sdGoal)
        try modelContext.save()
    }

    func archive(_ id: UUID) async throws -> Goal {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            throw GoalRepositoryError.notFound
        }

        sdGoal.status = "archived"
        sdGoal.updatedAt = Date()

        try modelContext.save()

        return toDomain(sdGoal)
    }

    func complete(_ id: UUID) async throws -> Goal {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdGoal = try modelContext.fetch(descriptor).first else {
            throw GoalRepositoryError.notFound
        }

        sdGoal.status = "completed"
        sdGoal.progress = 1.0
        sdGoal.updatedAt = Date()

        try modelContext.save()

        return toDomain(sdGoal)
    }

    // MARK: - Statistics

    func count() async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.userId == userId }
        )

        return try modelContext.fetchCount(descriptor)
    }

    func countByStatus(_ status: GoalStatus) async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw GoalRepositoryError.notAuthenticated
        }

        let statusString = status.rawValue

        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { goal in
                goal.userId == userId && goal.status == statusString
            }
        )

        return try modelContext.fetchCount(descriptor)
    }
}

// MARK: - Domain <-> SwiftData Mapping

extension GoalRepository {
    /// Convert domain Goal to SwiftData SDGoal
    private func toSwiftData(_ goal: Goal) -> SDGoal {
        let sdGoal = SDGoal(
            id: goal.id,
            userId: goal.userId,
            title: goal.title,
            goalDescription: goal.description,
            category: goal.category.rawValue,
            status: goal.status.rawValue,
            progress: goal.progress,
            targetDate: goal.targetDate,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt
        )
        // Note: SDGoal doesn't have targetValue/targetUnit fields yet
        // These are tracked via backend only for now
        return sdGoal
    }

    /// Convert SwiftData SDGoal to domain Goal
    private func toDomain(_ sdGoal: SDGoal) -> Goal {
        Goal(
            id: sdGoal.id,
            userId: sdGoal.userId,
            title: sdGoal.title,
            description: sdGoal.goalDescription,
            createdAt: sdGoal.createdAt,
            updatedAt: sdGoal.updatedAt,
            targetDate: sdGoal.targetDate,
            progress: sdGoal.progress,
            status: GoalStatus(rawValue: sdGoal.status) ?? .active,
            category: GoalCategory(rawValue: sdGoal.category) ?? .general,
            targetValue: 1.0,  // Default value, will be updated from backend
            targetUnit: "completion",  // Default unit
            currentValue: sdGoal.progress,  // Use progress as current value for now
            backendId: sdGoal.backendId  // Backend goal ID for API sync
        )
    }

    /// Update SwiftData model from domain model
    private func updateSDGoal(_ sdGoal: SDGoal, from goal: Goal) {
        sdGoal.title = goal.title
        sdGoal.goalDescription = goal.description
        sdGoal.category = goal.category.rawValue
        sdGoal.status = goal.status.rawValue
        sdGoal.progress = goal.progress
        sdGoal.targetDate = goal.targetDate
        sdGoal.updatedAt = goal.updatedAt
        sdGoal.backendId = goal.backendId  // Sync backend ID
    }

    // getCurrentUserId() is provided by UserAuthenticatedRepository protocol

    // MARK: - GoalTip Cache Conversion

    /// Convert cached tips data to domain GoalTip array
    private func convertCacheToDomain(_ cache: SDGoalTipCache) -> [GoalTip]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([GoalTip].self, from: cache.tipsData)
        } catch {
            print("❌ [GoalRepository] Failed to decode tips: \(error)")
            return nil
        }
    }

    /// Create cache entry from domain GoalTip array
    private func createCacheFromDomain(
        goalId: UUID,
        backendId: String?,
        tips: [GoalTip],
        expirationDays: Int = 7
    ) -> SDGoalTipCache? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let tipsData = try encoder.encode(tips)
            let expiresAt =
                Calendar.current.date(
                    byAdding: .day,
                    value: expirationDays,
                    to: Date()
                ) ?? Date().addingTimeInterval(TimeInterval(expirationDays * 24 * 60 * 60))

            return SDGoalTipCache(
                goalId: goalId,
                backendId: backendId,
                tipsData: tipsData,
                expiresAt: expiresAt
            )
        } catch {
            print("❌ [GoalRepository] Failed to encode tips: \(error)")
            return nil
        }
    }
}

// MARK: - Repository Errors

enum GoalRepositoryError: Error, LocalizedError {
    case notAuthenticated
    case notFound
    case validationFailed(String)
    case persistenceFailed(Error)
    case cacheFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated."
        case .notFound:
            return "Goal not found."
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .persistenceFailed(let error):
            return "Failed to persist goal: \(error.localizedDescription)"
        case .cacheFailed:
            return "Failed to cache tips data."
        }
    }
}
