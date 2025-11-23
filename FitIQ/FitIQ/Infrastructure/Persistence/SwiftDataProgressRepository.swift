// SwiftDataProgressRepository.swift
// FitIQ
//
// Created by AI Assistant on 27/01/2025.
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of ProgressLocalStorageProtocol
/// Provides local storage for progress entries with sync capabilities
final class SwiftDataProgressRepository: ProgressLocalStorageProtocol {

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol
    private let localDataChangeMonitor: LocalDataChangeMonitor  // NEW: For live UI updates

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        outboxRepository: OutboxRepositoryProtocol,
        localDataChangeMonitor: LocalDataChangeMonitor  // NEW: Inject monitor
    ) {
        self.modelContext = modelContext
        self.modelContainer = modelContainer
        self.outboxRepository = outboxRepository
        self.localDataChangeMonitor = localDataChangeMonitor  // NEW: Assign monitor
    }

    // MARK: - Local Storage Operations

    func save(progressEntry: ProgressEntry, forUserID userID: String) async throws -> UUID {
        print(
            "SwiftDataProgressRepository: Saving progress entry - Type: \(progressEntry.type.rawValue), Quantity: \(progressEntry.quantity), User: \(userID)"
        )

        // Convert String userID to UUID for predicate comparison
        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }

        // DEDUPLICATION: Check if entry already exists for this user, type, date, and time
        let typeRawValue = progressEntry.type.rawValue
        let targetDate = progressEntry.date

        print("SwiftDataProgressRepository: 🔍 DEDUPLICATION CHECK")
        print("  UserID: \(userID)")
        print("  Type: \(progressEntry.type.rawValue)")
        print("  Date: \(targetDate)")
        print("  Time: \(progressEntry.time ?? "nil")")
        print("  Quantity: \(progressEntry.quantity)")

        let existingEntries: [SDProgressEntry]

        if let time = progressEntry.time {
            // Entries WITH time field (steps, heart rate, etc.)
            let targetTime = time
            let predicate = #Predicate<SDProgressEntry> { entry in
                entry.userProfile?.id == userUUID
                    && entry.type == typeRawValue
                    && entry.date == targetDate
                    && entry.time == targetTime
            }
            let descriptor = FetchDescriptor<SDProgressEntry>(predicate: predicate)
            existingEntries = try modelContext.fetch(descriptor)
        } else {
            // Entries WITHOUT time field (water_liters, weight, mood, etc.)
            // Match by userID, type, and date (ignoring timestamp differences)
            let calendar = Calendar.current
            let startOfTargetDay = calendar.startOfDay(for: targetDate)
            let endOfTargetDay = calendar.date(byAdding: .day, value: 1, to: startOfTargetDay)!

            let predicate = #Predicate<SDProgressEntry> { entry in
                entry.userProfile?.id == userUUID
                    && entry.type == typeRawValue
                    && entry.time == nil
                    && entry.date >= startOfTargetDay
                    && entry.date < endOfTargetDay
            }
            let descriptor = FetchDescriptor<SDProgressEntry>(predicate: predicate)
            existingEntries = try modelContext.fetch(descriptor)
        }

        print("  Existing entries found: \(existingEntries.count)")

        if let existing = existingEntries.first {
            print(
                "SwiftDataProgressRepository: ⏭️ ✅ DUPLICATE DETECTED - Entry already exists: \(existing.id)"
            )
            print("  Existing quantity: \(existing.quantity)")
            print("  New quantity: \(progressEntry.quantity)")
            print("  Existing backendID: \(existing.backendID ?? "nil")")

            // Check if quantity has changed
            let quantityChanged =
                abs(existing.quantity - progressEntry.quantity) > 0.01

            if quantityChanged {
                // UPDATE: Quantity changed - update the existing entry
                print(
                    "SwiftDataProgressRepository: 🔄 UPDATING quantity: \(existing.quantity) → \(progressEntry.quantity)"
                )
                existing.quantity = progressEntry.quantity
                existing.updatedAt = Date()

                // Clear backend ID and mark as pending sync to trigger re-upload with new quantity
                existing.backendID = nil
                existing.syncStatus = SyncStatus.pending.rawValue
                print(
                    "SwiftDataProgressRepository: 🔄 Marked existing entry as pending sync due to quantity update"
                )

                // Create outbox event to sync updated quantity to backend
                do {
                    let outboxEvent = try await outboxRepository.createEvent(
                        eventType: .progressEntry,
                        entityID: existing.id,
                        userID: userID,
                        isNewRecord: true,  // Treat as new since backend ID was cleared
                        metadata: .progressEntry(
                            metricType: existing.type,
                            value: progressEntry.quantity,
                            unit: ""
                        ),
                        priority: 0
                    )
                    print(
                        "SwiftDataProgressRepository: ✅ Created outbox event \(outboxEvent.id) for updated entry"
                    )
                } catch {
                    print(
                        "SwiftDataProgressRepository: ❌ Failed to create outbox event for updated entry: \(error.localizedDescription)"
                    )
                }

                try modelContext.save()
                print(
                    "SwiftDataProgressRepository: ✅ Successfully updated quantity")
            }

            // Notify LocalDataChangeMonitor to trigger UI refresh
            if let userUUID = UUID(uuidString: userID) {
                await localDataChangeMonitor.notifyLocalRecordChanged(
                    forLocalID: existing.id,
                    userID: userUUID,
                    modelType: .progressEntry
                )
                print(
                    "SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor of \(quantityChanged ? "UPDATED" : "DUPLICATE") entry"
                )
            } else {
                print(
                    "SwiftDataProgressRepository: ⚠️ Invalid user UUID string: \(userID), skipping notification for duplicate"
                )
            }

            // CRITICAL: If the existing entry hasn't been synced yet, ensure it has an outbox event
            if existing.backendID == nil && !quantityChanged {
                print(
                    "SwiftDataProgressRepository: 🔄 Existing entry not synced yet - ensuring outbox event exists"
                )

                // Check if outbox event already exists for this entry
                let existingEvent = try? await outboxRepository.fetchPendingEvents(
                    forUserID: userID,
                    limit: 100
                ).first { $0.entityID == existing.id }

                if existingEvent == nil {
                    // Create outbox event for the existing unsynced entry
                    do {
                        let outboxEvent = try await outboxRepository.createEvent(
                            eventType: .progressEntry,
                            entityID: existing.id,
                            userID: userID,
                            isNewRecord: true,
                            metadata: .progressEntry(
                                metricType: existing.type,
                                value: existing.quantity,
                                unit: ""
                            ),
                            priority: 0
                        )
                        print(
                            "SwiftDataProgressRepository: ✅ Created outbox event \(outboxEvent.id) for existing unsynced entry \(existing.id)"
                        )
                    } catch {
                        print(
                            "SwiftDataProgressRepository: ❌ Failed to create outbox event for existing entry: \(error.localizedDescription)"
                        )
                    }
                }
            }

            return existing.id
        }

        print("SwiftDataProgressRepository: ✅ NEW ENTRY - No duplicate found, saving to database")

        // CRITICAL: Check if entry with this exact ID already exists (prevents duplicate registration)
        do {
            let entryID = progressEntry.id
            let idCheckDescriptor = FetchDescriptor<SDProgressEntry>(
                predicate: #Predicate<SDProgressEntry> { entry in
                    entry.id == entryID
                }
            )
            if let existingByID = try modelContext.fetch(idCheckDescriptor).first {
                print(
                    "SwiftDataProgressRepository: ⚠️ Entry with ID \(progressEntry.id) already exists in database - returning existing ID"
                )
                return existingByID.id
            }
        } catch {
            print(
                "SwiftDataProgressRepository: ⚠️ Failed to check for existing ID: \(error.localizedDescription)"
            )
        }

        // 1. Fetch user profile
        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.saveFailed(
                NSError(
                    domain: "SwiftDataProgressRepository", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"]))
        }

        let userProfilePredicate = #Predicate<SDUserProfile> { profile in
            profile.id == userUUID
        }
        let userProfileDescriptor = FetchDescriptor<SDUserProfile>(predicate: userProfilePredicate)
        guard let sdUserProfile = try modelContext.fetch(userProfileDescriptor).first else {
            throw ProgressRepositoryError.saveFailed(
                NSError(
                    domain: "SwiftDataProgressRepository", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "User profile not found"]))
        }

        // 2. Convert domain model to SwiftData model
        let sdProgressEntry = SDProgressEntry(
            type: progressEntry.type.rawValue,
            quantity: progressEntry.quantity,
            date: progressEntry.date,
            time: progressEntry.time,
            notes: progressEntry.notes,
            createdAt: progressEntry.createdAt,
            updatedAt: Date(),
            backendID: progressEntry.backendID,
            syncStatus: progressEntry.syncStatus.rawValue,
            userProfile: sdUserProfile
        )
        sdProgressEntry.id = progressEntry.id

        modelContext.insert(sdProgressEntry)

        do {
            try modelContext.save()
            print(
                "SwiftDataProgressRepository: Successfully saved progress entry with ID: \(progressEntry.id)"
            )

            // NEW: Notify LocalDataChangeMonitor for live UI updates
            if let userUUID = UUID(uuidString: userID) {
                await localDataChangeMonitor.notifyLocalRecordChanged(
                    forLocalID: progressEntry.id,
                    userID: userUUID,
                    modelType: .progressEntry
                )
                print(
                    "SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor of new progress entry"
                )
            } else {
                print(
                    "SwiftDataProgressRepository: ⚠️ Invalid user UUID string: \(userID), skipping notification (but continuing with save)"
                )
            }

            // Create Outbox event for reliable sync
            let isNewRecord = progressEntry.backendID == nil

            // CRITICAL: Create outbox event synchronously to ensure it's created before returning
            do {
                let outboxEvent = try await outboxRepository.createEvent(
                    eventType: .progressEntry,
                    entityID: progressEntry.id,
                    userID: userID,
                    isNewRecord: isNewRecord,
                    metadata: .progressEntry(
                        metricType: progressEntry.type.rawValue,
                        value: progressEntry.quantity,
                        unit: ""
                    ),
                    priority: 0
                )
                print(
                    "SwiftDataProgressRepository: ✅ Created outbox event \(outboxEvent.id) for progress entry \(progressEntry.id)"
                )
            } catch {
                print(
                    "SwiftDataProgressRepository: ❌ Failed to create outbox event: \(error.localizedDescription)"
                )
            }

            return progressEntry.id
        } catch {
            print(
                "SwiftDataProgressRepository: Error saving progress entry: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.saveFailed(error)
        }
    }

    func fetchLocal(
        forUserID userID: String,
        type: ProgressMetricType?,
        syncStatus: SyncStatus?,
        limit: Int? = nil
    ) async throws -> [ProgressEntry] {
        print(
            "SwiftDataProgressRepository: Fetching local entries for user: \(userID), type: \(type?.rawValue ?? "all"), syncStatus: \(syncStatus?.rawValue ?? "all")"
        )

        do {
            // Use compatibility layer to handle schema version mismatches
            let results = try SchemaCompatibilityLayer.safeFetchProgressEntries(
                from: modelContext,
                userID: userID,
                type: type?.rawValue,
                syncStatus: syncStatus?.rawValue,
                limit: limit
            )

            print("SwiftDataProgressRepository: Fetched \(results.count) local entries")

            // DEBUG: Log what types we're returning
            let typeCounts = Dictionary(grouping: results, by: { $0.type }).mapValues { $0.count }
            print("SwiftDataProgressRepository: Entry types: \(typeCounts)")

            // Convert to domain models
            let domainModels = results.compactMap { toDomain($0) }

            // DEBUG: Log first few entries
            print("SwiftDataProgressRepository: === DEBUG: First entries ===")
            for (index, entry) in domainModels.prefix(5).enumerated() {
                print(
                    "  Entry \(index + 1): Type=\(entry.type.rawValue), Quantity=\(entry.quantity), Date=\(entry.date)"
                )
            }

            return domainModels
        } catch {
            print(
                "SwiftDataProgressRepository: Error fetching local entries: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.fetchFailed(error)
        }
    }

    func fetchRecent(
        forUserID userID: String,
        type: ProgressMetricType?,
        startDate: Date,
        endDate: Date,
        limit: Int = 100
    ) async throws -> [ProgressEntry] {
        print(
            "SwiftDataProgressRepository: Fetching recent entries for user: \(userID), type: \(type?.rawValue ?? "all"), range: \(startDate) to \(endDate), limit: \(limit)"
        )

        do {
            // Build predicate with date range - split into two cases to avoid compiler timeout
            let results: [SDProgressEntry]

            if let typeRawValue = type?.rawValue {
                // Filter by specific type
                guard let userUUID = UUID(uuidString: userID) else {
                    throw ProgressRepositoryError.invalidUserID
                }
                let predicate = #Predicate<SDProgressEntry> { entry in
                    entry.userProfile?.id == userUUID
                        && entry.type == typeRawValue
                        && entry.date >= startDate
                        && entry.date < endDate
                }

                var descriptor = FetchDescriptor<SDProgressEntry>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                descriptor.fetchLimit = limit

                results = try modelContext.fetch(descriptor)
            } else {
                // No type filter - all types
                guard let userUUID = UUID(uuidString: userID) else {
                    throw ProgressRepositoryError.invalidUserID
                }
                let predicate = #Predicate<SDProgressEntry> { entry in
                    entry.userProfile?.id == userUUID
                        && entry.date >= startDate
                        && entry.date < endDate
                }

                var descriptor = FetchDescriptor<SDProgressEntry>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                descriptor.fetchLimit = limit

                results = try modelContext.fetch(descriptor)
            }

            print(
                "SwiftDataProgressRepository: ✅ Fetched \(results.count) recent entries (optimized query)"
            )

            // Convert to domain models
            return results.compactMap { toDomain($0) }
        } catch {
            print(
                "SwiftDataProgressRepository: ❌ Error fetching recent entries: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.fetchFailed(error)
        }
    }

    func fetchLatestEntryDate(
        forUserID userID: String,
        type: ProgressMetricType
    ) async throws -> Date? {
        print(
            "SwiftDataProgressRepository: Fetching latest entry date for user: \(userID), type: \(type.rawValue)"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }

        let typeRawValue = type.rawValue

        var descriptor = FetchDescriptor<SDProgressEntry>(
            predicate: #Predicate { entry in
                entry.userProfile?.id == userUUID && entry.type == typeRawValue
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            let entries = try modelContext.fetch(descriptor)
            let latestDate = entries.first?.date

            if let date = latestDate {
                print(
                    "SwiftDataProgressRepository: ✅ Latest entry date for \(type.rawValue): \(date)"
                )
            } else {
                print(
                    "SwiftDataProgressRepository: ℹ️ No entries found for \(type.rawValue)"
                )
            }

            return latestDate
        } catch {
            print(
                "SwiftDataProgressRepository: ❌ Error fetching latest entry date: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.fetchFailed(error)
        }
    }

    func updateBackendID(
        forLocalID localID: UUID,
        backendID: String,
        forUserID userID: String
    ) async throws {
        print(
            "SwiftDataProgressRepository: Updating backend ID for local ID: \(localID) to \(backendID)"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }
        var descriptor = FetchDescriptor<SDProgressEntry>(
            predicate: #Predicate { $0.id == localID && $0.userProfile?.id == userUUID }
        )
        descriptor.fetchLimit = 1

        do {
            guard let entry = try modelContext.fetch(descriptor).first else {
                throw ProgressRepositoryError.entryNotFound
            }

            entry.backendID = backendID
            entry.updatedAt = Date()

            try modelContext.save()
            print("SwiftDataProgressRepository: Successfully updated backend ID")
        } catch {
            print(
                "SwiftDataProgressRepository: Error updating backend ID: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.updateFailed(error)
        }
    }

    func updateSyncStatus(
        forLocalID localID: UUID,
        status: SyncStatus,
        forUserID userID: String
    ) async throws {
        print(
            "SwiftDataProgressRepository: Updating sync status for local ID: \(localID) to \(status.rawValue)"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }
        var descriptor = FetchDescriptor<SDProgressEntry>(
            predicate: #Predicate { $0.id == localID && $0.userProfile?.id == userUUID }
        )
        descriptor.fetchLimit = 1

        do {
            guard let entry = try modelContext.fetch(descriptor).first else {
                throw ProgressRepositoryError.entryNotFound
            }

            entry.syncStatus = status.rawValue
            entry.updatedAt = Date()

            try modelContext.save()
            print("SwiftDataProgressRepository: Successfully updated sync status")
        } catch {
            print(
                "SwiftDataProgressRepository: Error updating sync status: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.updateFailed(error)
        }
    }

    // MARK: - Maintenance Operations

    /// Deletes all progress entries for a user (useful for clearing corrupted data)
    func deleteAll(forUserID userID: String, type: ProgressMetricType?) async throws {
        print(
            "SwiftDataProgressRepository: Deleting all entries for user: \(userID), type: \(type?.rawValue ?? "all")"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }

        do {
            // CRITICAL: Clean up orphaned outbox events first
            // Fetch all progress entry IDs before deleting them
            let typeRawValue = type?.rawValue
            let predicate = #Predicate<SDProgressEntry> { entry in
                entry.userProfile?.id == userUUID
                    && (typeRawValue == nil || entry.type == typeRawValue!)
            }
            var descriptor = FetchDescriptor<SDProgressEntry>(predicate: predicate)

            let entriesToDelete = try modelContext.fetch(descriptor)
            let entryIDs = entriesToDelete.map { $0.id }

            print(
                "SwiftDataProgressRepository: Found \(entryIDs.count) progress entries to delete"
            )

            // Delete corresponding outbox events
            if !entryIDs.isEmpty {
                do {
                    let deletedCount = try await outboxRepository.deleteEvents(
                        forEntityIDs: entryIDs)
                    print(
                        "SwiftDataProgressRepository: Deleted \(deletedCount) orphaned outbox events"
                    )
                } catch {
                    print(
                        "SwiftDataProgressRepository: Warning - Failed to delete outbox events: \(error.localizedDescription)"
                    )
                    // Continue with progress entry deletion even if outbox cleanup fails
                }
            }

            // Use compatibility layer to handle schema version mismatches
            try SchemaCompatibilityLayer.safeDeleteProgressEntries(
                from: modelContext,
                userID: userID,
                type: type?.rawValue
            )

            print(
                "SwiftDataProgressRepository: Successfully deleted all entries"
            )
        } catch {
            print(
                "SwiftDataProgressRepository: Error deleting entries: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.deleteFailed(error)
        }
    }

    /// Deletes a single progress entry
    func delete(progressEntryID: UUID, forUserID userID: String) async throws {
        print(
            "SwiftDataProgressRepository: Deleting progress entry with ID: \(progressEntryID)"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDProgressEntry>(
            predicate: #Predicate {
                $0.id == progressEntryID && $0.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        do {
            guard let entry = try modelContext.fetch(descriptor).first else {
                throw ProgressRepositoryError.entryNotFound
            }

            // CRITICAL: Delete corresponding outbox event first to prevent orphaned references
            do {
                let deletedCount = try await outboxRepository.deleteEvents(forEntityIDs: [
                    progressEntryID
                ])
                print(
                    "SwiftDataProgressRepository: Deleted \(deletedCount) orphaned outbox event(s) for entry \(progressEntryID)"
                )
            } catch {
                print(
                    "SwiftDataProgressRepository: Warning - Failed to delete outbox event: \(error.localizedDescription)"
                )
                // Continue with progress entry deletion even if outbox cleanup fails
            }

            // Break relationship to SDUserProfile before deleting to avoid
            // "Expected only Arrays for Relationships" crash
            entry.userProfile = nil

            modelContext.delete(entry)

            try modelContext.save()
            print("SwiftDataProgressRepository: Successfully deleted progress entry")
        } catch {
            print(
                "SwiftDataProgressRepository: Error deleting progress entry: \(error.localizedDescription)"
            )
            throw ProgressRepositoryError.deleteFailed(error)
        }
    }

    /// Removes duplicate progress entries for a specific user and type
    /// Keeps the earliest entry (by createdAt) and removes all duplicates
    /// Duplicates are identified by: userID, type, date, and time
    func removeDuplicates(forUserID userID: String, type: ProgressMetricType) async throws {
        print(
            "SwiftDataProgressRepository: Removing duplicates for user: \(userID), type: \(type.rawValue)"
        )

        guard let userUUID = UUID(uuidString: userID) else {
            throw ProgressRepositoryError.invalidUserID
        }

        let typeRawValue = type.rawValue

        let predicate = #Predicate<SDProgressEntry> { entry in
            entry.userProfile?.id == userUUID && entry.type == typeRawValue
        }

        let descriptor = FetchDescriptor<SDProgressEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.time), SortDescriptor(\.createdAt)]
        )

        let allEntries = try modelContext.fetch(descriptor)

        // Group by date+time combination
        var uniqueKeys = Set<String>()
        var duplicatesToDelete: [SDProgressEntry] = []
        var keptCount = 0
        var deletedCount = 0

        for entry in allEntries {
            let key = "\(entry.date.timeIntervalSince1970)_\(entry.time ?? "")"

            if uniqueKeys.contains(key) {
                // This is a duplicate - mark for deletion
                duplicatesToDelete.append(entry)
                deletedCount += 1
            } else {
                // This is the first occurrence - keep it
                uniqueKeys.insert(key)
                keptCount += 1
            }
        }

        // Delete duplicates
        for duplicate in duplicatesToDelete {
            duplicate.userProfile = nil
            modelContext.delete(duplicate)
        }

        if !duplicatesToDelete.isEmpty {
            try modelContext.save()
        }

        print(
            "SwiftDataProgressRepository: ✅ Removed \(deletedCount) duplicates, kept \(keptCount) unique entries"
        )
    }

    // MARK: - Helper Methods

    private func toDomain(_ sdEntry: SDProgressEntry) -> ProgressEntry {
        return ProgressEntry(
            id: sdEntry.id,
            userID: sdEntry.userProfile?.id.uuidString ?? "",
            type: ProgressMetricType(rawValue: sdEntry.type) ?? .weight,
            quantity: sdEntry.quantity,
            date: sdEntry.date,
            time: sdEntry.time,
            notes: sdEntry.notes,
            createdAt: sdEntry.createdAt,
            updatedAt: sdEntry.updatedAt,
            backendID: sdEntry.backendID,
            syncStatus: SyncStatus(rawValue: sdEntry.syncStatus) ?? .pending
        )
    }
}

// MARK: - Errors

enum ProgressRepositoryError: Error, LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case entryNotFound
    case invalidUserID

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save progress entry: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch progress entries: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update progress entry: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete progress entries: \(error.localizedDescription)"
        case .entryNotFound:
            return "Progress entry not found"
        case .invalidUserID:
            return "Invalid user ID format"
        }
    }
}
