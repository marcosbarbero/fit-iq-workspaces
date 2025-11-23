//
//  SwiftDataWorkoutRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of WorkoutRepositoryProtocol
/// Provides local storage for workout entries with Outbox Pattern sync
final class SwiftDataWorkoutRepository: WorkoutRepositoryProtocol {

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol
    private let localDataChangeMonitor: LocalDataChangeMonitor

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        outboxRepository: OutboxRepositoryProtocol,
        localDataChangeMonitor: LocalDataChangeMonitor
    ) {
        self.modelContext = modelContext
        self.modelContainer = modelContainer
        self.outboxRepository = outboxRepository
        self.localDataChangeMonitor = localDataChangeMonitor
    }

    // MARK: - Save Operation

    func save(workoutEntry: WorkoutEntry, forUserID userID: String) async throws -> UUID {
        print(
            "SwiftDataWorkoutRepository: Saving workout entry - Activity: \(workoutEntry.activityType), User: \(userID)"
        )

        // Convert String userID to UUID for predicate comparison
        guard let userUUID = UUID(uuidString: userID) else {
            throw WorkoutRepositoryError.invalidUserID
        }

        // DEDUPLICATION: Check if workout with same sourceID already exists
        if let sourceID = workoutEntry.sourceID {
            let predicate = #Predicate<SDWorkout> { workout in
                workout.userProfile?.id == userUUID && workout.sourceID == sourceID
            }
            let descriptor = FetchDescriptor<SDWorkout>(predicate: predicate)
            let existingWorkouts = try modelContext.fetch(descriptor)

            if let existing = existingWorkouts.first {
                print(
                    "SwiftDataWorkoutRepository: ⏭️ DUPLICATE DETECTED - Workout with sourceID '\(sourceID)' already exists: \(existing.id)"
                )
                return existing.id
            }
        }

        // Fetch user profile
        let userProfileDescriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate { $0.id == userUUID }
        )
        guard let userProfile = try modelContext.fetch(userProfileDescriptor).first else {
            throw WorkoutRepositoryError.saveFailed("User profile not found")
        }

        // Create SDWorkout from domain model (convert enum to raw string)
        let sdWorkout = SDWorkout(
            id: workoutEntry.id,
            activityType: workoutEntry.activityType.rawValue,
            title: workoutEntry.title,
            notes: workoutEntry.notes,
            startedAt: workoutEntry.startedAt,
            endedAt: workoutEntry.endedAt,
            durationMinutes: workoutEntry.durationMinutes,
            caloriesBurned: workoutEntry.caloriesBurned,
            distanceMeters: workoutEntry.distanceMeters,
            intensity: workoutEntry.intensity,
            source: workoutEntry.source,
            sourceID: workoutEntry.sourceID,
            createdAt: workoutEntry.createdAt,
            updatedAt: workoutEntry.updatedAt,
            backendID: workoutEntry.backendID,
            syncStatus: workoutEntry.syncStatus.rawValue,
            userProfile: userProfile
        )

        // Insert into context
        modelContext.insert(sdWorkout)
        try modelContext.save()

        print("SwiftDataWorkoutRepository: ✅ Saved workout locally with ID: \(sdWorkout.id)")

        // Create outbox event for backend sync (Outbox Pattern)
        do {
            let metadata: OutboxMetadata = .generic([
                "activityType": workoutEntry.activityType.rawValue,
                "startedAt": String(workoutEntry.startedAt.timeIntervalSince1970),
                "source": workoutEntry.source,
            ])

            let outboxEvent = try await outboxRepository.createEvent(
                eventType: .workout,
                entityID: sdWorkout.id,
                userID: userID,
                isNewRecord: true,
                metadata: metadata,
                priority: 5
            )
            print(
                "SwiftDataWorkoutRepository: ✅ Created outbox event \(outboxEvent.id) for workout sync"
            )
        } catch {
            print(
                "SwiftDataWorkoutRepository: ❌ Failed to create outbox event: \(error.localizedDescription)"
            )
        }

        // Notify LocalDataChangeMonitor for UI updates
        // Note: workout is not yet added to LocalDataNeedsSyncEvent.ModelType
        // Skip notification for now until ModelType enum is updated
        // await localDataChangeMonitor.notifyLocalRecordChanged(
        //     forLocalID: sdWorkout.id,
        //     userID: userUUID,
        //     modelType: .workout  // TODO: Add .workout case to LocalDataNeedsSyncEvent.ModelType
        // )

        return sdWorkout.id
    }

    // MARK: - Fetch Operations

    func fetchLocal(
        forUserID userID: String,
        syncStatus: SyncStatus?,
        from startDate: Date?,
        to endDate: Date?,
        limit: Int?
    ) async throws -> [WorkoutEntry] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw WorkoutRepositoryError.invalidUserID
        }

        // Build predicate with optional filters
        var descriptor: FetchDescriptor<SDWorkout>

        if let syncStatus = syncStatus {
            let statusRawValue = syncStatus.rawValue
            descriptor = FetchDescriptor<SDWorkout>(
                predicate: #Predicate { workout in
                    workout.userProfile?.id == userUUID && workout.syncStatus == statusRawValue
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SDWorkout>(
                predicate: #Predicate { workout in
                    workout.userProfile?.id == userUUID
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        }

        // Apply limit if specified
        if let limit = limit {
            descriptor.fetchLimit = limit
        }

        let sdWorkouts = try modelContext.fetch(descriptor)

        // Filter by date range if specified (post-fetch filtering for date ranges)
        var filteredWorkouts = sdWorkouts
        if let startDate = startDate {
            filteredWorkouts = filteredWorkouts.filter { $0.startedAt >= startDate }
        }
        if let endDate = endDate {
            filteredWorkouts = filteredWorkouts.filter { $0.startedAt <= endDate }
        }

        // Convert to domain models
        let workoutEntries = filteredWorkouts.map { $0.toDomain() }

        print(
            "SwiftDataWorkoutRepository: Fetched \(workoutEntries.count) workouts for user \(userID)"
        )
        return workoutEntries
    }

    func fetchByID(_ id: UUID) async throws -> WorkoutEntry? {
        let descriptor = FetchDescriptor<SDWorkout>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdWorkout = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdWorkout.toDomain()
    }

    func fetchBySourceID(_ sourceID: String, forUserID userID: String) async throws -> WorkoutEntry?
    {
        guard let userUUID = UUID(uuidString: userID) else {
            throw WorkoutRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDWorkout>(
            predicate: #Predicate { workout in
                workout.userProfile?.id == userUUID && workout.sourceID == sourceID
            }
        )

        guard let sdWorkout = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdWorkout.toDomain()
    }

    // MARK: - Update Operations

    func updateSyncStatus(
        forID id: UUID,
        syncStatus: SyncStatus,
        backendID: String?
    ) async throws {
        let descriptor = FetchDescriptor<SDWorkout>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdWorkout = try modelContext.fetch(descriptor).first else {
            throw WorkoutRepositoryError.workoutNotFound
        }

        sdWorkout.syncStatus = syncStatus.rawValue
        sdWorkout.backendID = backendID
        sdWorkout.updatedAt = Date()

        try modelContext.save()

        print(
            "SwiftDataWorkoutRepository: Updated sync status for workout \(id) to \(syncStatus.rawValue)"
        )
    }

    // MARK: - Delete Operations

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<SDWorkout>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdWorkout = try modelContext.fetch(descriptor).first else {
            throw WorkoutRepositoryError.workoutNotFound
        }

        modelContext.delete(sdWorkout)
        try modelContext.save()

        print("SwiftDataWorkoutRepository: Deleted workout \(id)")
    }

    // MARK: - Query Operations

    func getTotalCount(
        forUserID userID: String,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> Int {
        let workouts = try await fetchLocal(
            forUserID: userID,
            syncStatus: nil,
            from: startDate,
            to: endDate,
            limit: nil
        )

        return workouts.count
    }

    func getWorkoutsByActivityType(
        forUserID userID: String,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> [String: Int] {
        let workouts = try await fetchLocal(
            forUserID: userID,
            syncStatus: nil,
            from: startDate,
            to: endDate,
            limit: nil
        )

        // Group by activity type
        var counts: [String: Int] = [:]
        for workout in workouts {
            counts[workout.activityType.rawValue, default: 0] += 1
        }

        return counts
    }
}
