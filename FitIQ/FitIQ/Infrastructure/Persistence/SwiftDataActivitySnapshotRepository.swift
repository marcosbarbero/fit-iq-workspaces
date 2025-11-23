import Combine  // Import Combine for the publisher
// Infrastructure/Persistence/SwiftDataActivitySnapshotRepository.swift
import Foundation
import SwiftData

/// An adapter that implements ActivitySnapshotRepositoryProtocol using SwiftData.
/// This bridges the domain ActivitySnapshot to the SwiftData-specific SDActivitySnapshot model.
class SwiftDataActivitySnapshotRepository: ActivitySnapshotRepositoryProtocol {
    private let modelContainer: ModelContainer
    public let eventPublisher: ActivitySnapshotEventPublisherProtocol  // Conforming to the protocol
    private let localDataChangeMonitor: LocalDataChangeMonitor  // NEW: Dependency for push-based notification

    init(
        modelContainer: ModelContainer, eventPublisher: ActivitySnapshotEventPublisherProtocol,
        localDataChangeMonitor: LocalDataChangeMonitor
    ) {  // NEW: Inject monitor
        self.modelContainer = modelContainer
        self.eventPublisher = eventPublisher
        self.localDataChangeMonitor = localDataChangeMonitor  // NEW: Assign monitor
    }

    /// Fetches the latest activity snapshot for a given user from SwiftData.
    func fetchLatestActivitySnapshot(forUserID userID: String) async throws -> ActivitySnapshot? {
        let context = ModelContext(modelContainer)

        guard let userUUID = UUID(uuidString: userID) else {
            throw ActivitySnapshotRepositoryError.invalidUserID
        }

        // Fetch the user profile first to ensure it exists and get its ID
        let _ = try fetchSDUserProfile(id: userUUID, in: context)  // Ensure user profile exists

        // Fetch the latest activity snapshot for this user, ordered by date descending
        let snapshotPredicate = #Predicate<SDActivitySnapshot> { snapshot in
            snapshot.userProfile?.id == userUUID
        }
        var descriptor = FetchDescriptor(predicate: snapshotPredicate)
        descriptor.sortBy = [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse),
        ]
        descriptor.fetchLimit = 1

        guard let latestSDSnapshot = try context.fetch(descriptor).first else {
            return nil  // No activity snapshots found for this user
        }

        return latestSDSnapshot.toDomain()
    }

    /// Fetches an activity snapshot for a specific date and user.
    /// - Parameters:
    ///   - userID: The ID of the user whose activity snapshot is to be fetched.
    ///   - date: The date for which to fetch the snapshot (typically `startOfDay`).
    /// - Returns: The `ActivitySnapshot` for the specified date, or `nil` if none exists.
    func fetchActivitySnapshot(forUserID userID: String, date: Date) async throws
        -> ActivitySnapshot?
    {
        let context = ModelContext(modelContainer)

        guard let userUUID = UUID(uuidString: userID) else {
            throw ActivitySnapshotRepositoryError.invalidUserID
        }

        // Predicate to find snapshots for the given user and date (start of day)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let snapshotPredicate = #Predicate<SDActivitySnapshot> { snapshot in
            snapshot.userProfile?.id == userUUID && snapshot.date == startOfDay
        }

        var descriptor = FetchDescriptor(predicate: snapshotPredicate)
        descriptor.fetchLimit = 1  // We expect at most one snapshot per user per day

        guard let sdSnapshot = try context.fetch(descriptor).first else {
            return nil  // No activity snapshot found for this user on this specific date
        }

        return sdSnapshot.toDomain()
    }

    /// Fetches an activity snapshot by its local UUID.
    /// - Parameters:
    ///   - localID: The local UUID of the `ActivitySnapshot` to fetch.
    ///   - userID: The ID of the user this snapshot belongs to.
    /// - Returns: The `ActivitySnapshot` if found, otherwise `nil`.
    func fetchActivitySnapshot(forLocalID localID: UUID, for userID: String) async throws
        -> ActivitySnapshot?
    {
        let context = ModelContext(modelContainer)

        guard let userUUID = UUID(uuidString: userID) else {
            throw ActivitySnapshotRepositoryError.invalidUserID
        }

        // Fetch the user profile first
        let _ = try fetchSDUserProfile(id: userUUID, in: context)

        let predicate = #Predicate<SDActivitySnapshot> { snapshot in
            snapshot.id == localID && snapshot.userProfile?.id == userUUID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            guard let sdSnapshot = try context.fetch(descriptor).first else {
                return nil  // No SDActivitySnapshot found
            }
            return sdSnapshot.toDomain()  // Convert to domain model before returning
        } catch {
            print(
                "Failed to fetch SDActivitySnapshot with local ID \(localID) for user \(userID): \(error.localizedDescription)"
            )
            throw ActivitySnapshotRepositoryError.fetchFailed(error)
        }
    }

    /// Saves or updates an activity snapshot for a user.
    /// This method will create a new snapshot if `snapshot.id` does not exist locally,
    /// or update an existing one if a snapshot with the same `id` is found.
    /// - Parameters:
    ///   - snapshot: The `ActivitySnapshot` to save or update.
    ///   - userID: The ID of the user this snapshot belongs to.
    /// - Returns: The local UUID of the saved/updated `ActivitySnapshot` entry.
    func save(snapshot: ActivitySnapshot, forUserID userID: String) async throws -> UUID {
        let context = ModelContext(modelContainer)

        guard let userUUID = UUID(uuidString: userID) else {
            throw ActivitySnapshotRepositoryError.invalidUserID
        }

        // Fetch the SDUserProfile for the given userID
        guard let sdUserProfile = try fetchSDUserProfile(id: userUUID, in: context) else {
            print(
                "SwiftDataActivitySnapshotRepository: UserProfile not found for ID \(userID). Cannot save activity snapshot."
            )
            throw ActivitySnapshotRepositoryError.userProfileNotFound
        }

        // Capture snapshot.id into a local constant to avoid predicate macro confusion
        let localSnapshotID = snapshot.id

        // Check if an SDActivitySnapshot with the same local ID already exists
        let existingSDSnapshotPredicate = #Predicate<SDActivitySnapshot> { sdSnapshot in
            sdSnapshot.id == localSnapshotID && sdSnapshot.userProfile?.id == userUUID
        }
        var existingSDSnapshotDescriptor = FetchDescriptor(predicate: existingSDSnapshotPredicate)
        existingSDSnapshotDescriptor.fetchLimit = 1

        if let existingSDSnapshot = try context.fetch(existingSDSnapshotDescriptor).first {
            // Update existing snapshot
            existingSDSnapshot.activeMinutes = snapshot.activeMinutes
            existingSDSnapshot.activityLevel = snapshot.activityLevel
            existingSDSnapshot.caloriesBurned = snapshot.caloriesBurned
            existingSDSnapshot.date = snapshot.date
            existingSDSnapshot.distanceKm = snapshot.distanceKm
            existingSDSnapshot.heartRateAvg = snapshot.heartRateAvg
            existingSDSnapshot.steps = snapshot.steps
            existingSDSnapshot.workoutDurationMinutes = snapshot.workoutDurationMinutes
            existingSDSnapshot.workoutSessions = snapshot.workoutSessions
            // createdAt is immutable, keep original
            existingSDSnapshot.updatedAt = Date()
            existingSDSnapshot.backendID = snapshot.backendID  // Update backendID if provided in the domain model

            print(
                "Successfully updated SDActivitySnapshot with local ID: \(snapshot.id) for user ID: \(userID)"
            )
        } else {
            // Create a new snapshot
            let newSDActivitySnapshot = SDActivitySnapshot(
                id: snapshot.id,
                activeMinutes: snapshot.activeMinutes,
                activityLevel: snapshot.activityLevel,
                caloriesBurned: snapshot.caloriesBurned,
                date: snapshot.date,
                distanceKm: snapshot.distanceKm,
                heartRateAvg: snapshot.heartRateAvg,
                steps: snapshot.steps,
                workoutDurationMinutes: snapshot.workoutDurationMinutes,
                workoutSessions: snapshot.workoutSessions,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt,
                backendID: snapshot.backendID,  // Assign backendID from the domain model
                userProfile: sdUserProfile
            )
            context.insert(newSDActivitySnapshot)
            print(
                "Successfully inserted new SDActivitySnapshot with local ID: \(snapshot.id) for user ID: \(userID), date: \(snapshot.date)"
            )
        }

        do {
            try context.save()
            // NEW: Publish the event after successful save/update to activitySnapshotEventPublisher
            eventPublisher.publish(
                event: ActivitySnapshotEvent(userID: userID, date: snapshot.date))

            // NEW: Notify the LocalDataChangeMonitor after a successful save
            await localDataChangeMonitor.notifyLocalRecordChanged(
                forLocalID: snapshot.id, userID: userUUID, modelType: .activitySnapshot)

            return snapshot.id  // Return the local UUID of the saved/updated snapshot
        } catch {
            print(
                "Failed to save/update SDActivitySnapshot for user ID: \(userID): \(error.localizedDescription)"
            )
            throw error
        }
    }

    /// Updates the backend ID for an existing activity snapshot.
    /// - Parameters:
    ///   - localID: The local UUID of the `SDActivitySnapshot` to update.
    ///   - newBackendID: The backend ID received from the API.
    ///   - userID: The ID of the user this snapshot belongs to (for verification).
    func updateActivitySnapshotBackendID(
        forLocalID localID: UUID, newBackendID: String, for userID: String
    ) async throws {
        let context = ModelContext(modelContainer)

        guard let userUUID = UUID(uuidString: userID) else {
            throw ActivitySnapshotRepositoryError.invalidUserID
        }

        // Fetch the user profile first
        let _ = try fetchSDUserProfile(id: userUUID, in: context)  // Ensure user exists

        // Fetch the existing snapshot
        let predicate = #Predicate<SDActivitySnapshot> { snapshot in
            snapshot.id == localID && snapshot.userProfile?.id == userUUID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let existingSnapshot = try context.fetch(descriptor).first else {
            print(
                "Failed to find SDActivitySnapshot with local ID \(localID) for user \(userID) to update backendID."
            )
            throw ActivitySnapshotRepositoryError.snapshotNotFound
        }

        existingSnapshot.backendID = newBackendID
        existingSnapshot.backendSyncedAt = Date()  // Mark as synced
        existingSnapshot.updatedAt = Date()

        do {
            try context.save()
            print(
                "Successfully updated backendID for ActivitySnapshot with local ID \(localID) to \(newBackendID)."
            )
            // No need to notify LocalDataChangeMonitor here as this update specifically marks it as synced.
        } catch {
            print(
                "Failed to update backendID for local ID: \(localID) - \(error.localizedDescription)"
            )
            throw ActivitySnapshotRepositoryError.saveFailed(error)
        }
    }

    // Helper to fetch SDUserProfile for use in predicates
    private func fetchSDUserProfile(id: UUID, in context: ModelContext) throws -> SDUserProfile? {
        let predicate = #Predicate<SDUserProfile> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

// MARK: - Error Types
enum ActivitySnapshotRepositoryError: Error, LocalizedError {
    case invalidUserID
    case userProfileNotFound
    case snapshotNotFound  // NEW: Added for when a snapshot isn't found for update
    case fetchFailed(Error)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUserID:
            return "The provided user ID is not a valid UUID format."
        case .userProfileNotFound:
            return "The associated user profile could not be found in the database."
        case .snapshotNotFound:
            return "The activity snapshot with the specified local ID could not be found."
        case .fetchFailed(let error):
            return "Failed to fetch activity snapshot: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save activity snapshot: \(error.localizedDescription)"
        }
    }
}
