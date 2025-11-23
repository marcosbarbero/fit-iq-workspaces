//
//  SwiftDataSleepRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: SwiftData implementation of SleepRepositoryProtocol with Outbox Pattern
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData adapter for sleep session persistence following Hexagonal Architecture
/// Implements Outbox Pattern for reliable backend synchronization
final class SwiftDataSleepRepository: SleepRepositoryProtocol {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol

    // MARK: - Initialization

    init(modelContext: ModelContext, outboxRepository: OutboxRepositoryProtocol) {
        self.modelContext = modelContext
        self.outboxRepository = outboxRepository
    }

    // MARK: - Save Operations

    func save(session: SleepSession, forUserID userID: String) async throws -> UUID {
        print("SwiftDataSleepRepository: Saving sleep session for user \(userID)")

        // 1. Check for duplicate by sourceID if provided
        if let sourceID = session.sourceID {
            if let existingSession = try await fetchSession(bySourceID: sourceID, forUserID: userID)
            {
                print(
                    "SwiftDataSleepRepository: Duplicate session found by sourceID, skipping save")
                return existingSession.id
            }
        }

        // 2. Fetch user profile
        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        let userProfileDescriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate<SDUserProfile> { profile in
                profile.id == userUUID
            }
        )
        guard let userProfile = try modelContext.fetch(userProfileDescriptor).first else {
            throw SleepRepositoryError.userProfileNotFound
        }

        // 3. Convert domain model to SwiftData model
        let sdSession = SDSleepSession(
            id: session.id,
            userProfile: userProfile,
            date: session.date,
            startTime: session.startTime,
            endTime: session.endTime,
            timeInBedMinutes: session.timeInBedMinutes,
            totalSleepMinutes: session.totalSleepMinutes,
            sleepEfficiency: session.sleepEfficiency,
            source: session.source,
            sourceID: session.sourceID,
            notes: session.notes,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            backendID: session.backendID,
            syncStatus: session.syncStatus.rawValue
        )

        // 4. Convert and attach sleep stages
        let sdStages: [SDSleepStage]? = session.stages?.map { stage in
            SDSleepStage(
                id: stage.id,
                stage: stage.stage.rawValue,
                startTime: stage.startTime,
                endTime: stage.endTime,
                durationMinutes: stage.durationMinutes,
                session: sdSession
            )
        }
        sdSession.stages = sdStages

        // 5. Insert into context
        modelContext.insert(sdSession)
        try modelContext.save()

        print("SwiftDataSleepRepository: Sleep session saved with ID \(session.id)")

        // 6. ✅ OUTBOX PATTERN: Create outbox event for backend sync
        let duration = session.endTime.timeIntervalSince(session.startTime)
        let metadata: OutboxMetadata = .sleepSession(
            duration: duration,
            quality: session.sleepEfficiency
        )

        _ = try await outboxRepository.createEvent(
            eventType: .sleepSession,
            entityID: session.id,
            userID: userID,
            isNewRecord: session.backendID == nil,
            metadata: metadata,
            priority: 5
        )

        print("SwiftDataSleepRepository: Outbox event created for sleep session \(session.id)")

        return session.id
    }

    // MARK: - Fetch Operations

    func fetchSessions(
        forUserID userID: String,
        from: Date,
        to: Date,
        syncStatus: SyncStatus? = nil
    ) async throws -> [SleepSession] {
        print("SwiftDataSleepRepository: Fetching sessions from \(from) to \(to)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        let descriptor: FetchDescriptor<SDSleepSession>

        if let status = syncStatus {
            let statusRaw = status.rawValue
            descriptor = FetchDescriptor<SDSleepSession>(
                predicate: #Predicate { session in
                    session.userProfile?.id == userUUID
                        && session.date >= from
                        && session.date <= to
                        && session.syncStatus == statusRaw
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SDSleepSession>(
                predicate: #Predicate { session in
                    session.userProfile?.id == userUUID
                        && session.date >= from
                        && session.date <= to
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }

        let sdSessions = try modelContext.fetch(descriptor)
        let domainSessions = sdSessions.map { $0.toDomain() }

        print("SwiftDataSleepRepository: Fetched \(domainSessions.count) sessions")
        return domainSessions
    }

    func fetchLatestSession(forUserID userID: String) async throws -> SleepSession? {
        print("SwiftDataSleepRepository: 🔍 Fetching latest session for user \(userID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        // First, fetch ALL sessions to debug date sorting
        let allDescriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { $0.userProfile?.id == userUUID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = try modelContext.fetch(allDescriptor)

        print("\n" + String(repeating: "=", count: 80))
        print("SwiftDataSleepRepository: 🔍 DEBUG - ALL SESSIONS SORTED BY DATE (DESCENDING)")
        print(String(repeating: "=", count: 80))
        print("Total sessions in database: \(allSessions.count)")
        print(String(repeating: "-", count: 80))

        for (index, session) in allSessions.enumerated() {
            print("\nSession \(index + 1):")
            print("  ID: \(session.id)")
            print("  Date (wake date): \(session.date)")
            print("  Start Time: \(session.startTime)")
            print("  End Time: \(session.endTime)")
            print(
                "  Total Sleep: \(session.totalSleepMinutes) min (\(String(format: "%.1f", Double(session.totalSleepMinutes) / 60.0))h)"
            )
            print("  Source ID: \(session.sourceID ?? "nil")")
        }
        print(String(repeating: "=", count: 80))
        print("SwiftDataSleepRepository: Will return session at index 0 (most recent by date)")
        print(String(repeating: "=", count: 80) + "\n")

        var descriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { $0.userProfile?.id == userUUID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let sdSessions = try modelContext.fetch(descriptor)

        if let sdSession = sdSessions.first {
            print("SwiftDataSleepRepository: 🔍 Raw SwiftData session details:")
            print("  - ID: \(sdSession.id)")
            print("  - Date: \(sdSession.date)")
            print("  - Start Time: \(sdSession.startTime)")
            print("  - End Time: \(sdSession.endTime)")
            print("  - Time in Bed Minutes: \(sdSession.timeInBedMinutes)")
            print("  - Total Sleep Minutes: \(sdSession.totalSleepMinutes)")
            print("  - Sleep Efficiency: \(sdSession.sleepEfficiency)")
            print("  - Source: \(sdSession.source ?? "nil")")
            print("  - Source ID: \(sdSession.sourceID ?? "nil")")
            print("  - Stages Count: \(sdSession.stages?.count ?? 0)")

            if let stages = sdSession.stages {
                for (index, stage) in stages.enumerated() {
                    print("    Stage \(index + 1): \(stage.stage) - \(stage.durationMinutes) min")
                }
            }
        }

        let domainSession = sdSessions.first?.toDomain()

        if let session = domainSession {
            print(
                "SwiftDataSleepRepository: ✅ Returning session with ID \(session.id), \(session.totalSleepMinutes) mins sleep"
            )
        } else {
            print("SwiftDataSleepRepository: ⚠️ No sleep sessions found for user")
        }

        return domainSession
    }

    func fetchSession(byID id: UUID, forUserID userID: String) async throws -> SleepSession? {
        print("SwiftDataSleepRepository: Fetching session by ID \(id)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { session in
                session.id == id && session.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        let sdSessions = try modelContext.fetch(descriptor)
        return sdSessions.first?.toDomain()
    }

    func fetchSession(bySourceID sourceID: String, forUserID userID: String) async throws
        -> SleepSession?
    {
        print("SwiftDataSleepRepository: Fetching session by sourceID \(sourceID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { session in
                session.sourceID == sourceID && session.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        let sdSessions = try modelContext.fetch(descriptor)
        return sdSessions.first?.toDomain()
    }

    // MARK: - Update Operations

    func updateSyncStatus(
        forSessionID id: UUID,
        syncStatus: SyncStatus,
        backendID: String? = nil
    ) async throws {
        print("SwiftDataSleepRepository: Updating sync status for session \(id) to \(syncStatus)")

        var descriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let sdSession = try modelContext.fetch(descriptor).first else {
            throw SleepRepositoryError.sessionNotFound
        }

        sdSession.syncStatus = syncStatus.rawValue
        sdSession.updatedAt = Date()

        if let backendID = backendID {
            sdSession.backendID = backendID
        }

        try modelContext.save()
        print("SwiftDataSleepRepository: Sync status updated successfully")
    }

    // MARK: - Delete Operations

    func deleteSession(byID id: UUID, forUserID userID: String) async throws {
        print("SwiftDataSleepRepository: Deleting session \(id)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { session in
                session.id == id && session.userProfile?.id == userUUID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdSession = try modelContext.fetch(descriptor).first else {
            throw SleepRepositoryError.sessionNotFound
        }

        // Break relationship to SDUserProfile before deleting
        sdSession.userProfile = nil

        modelContext.delete(sdSession)
        try modelContext.save()
        print("SwiftDataSleepRepository: Session deleted successfully")
    }

    func deleteAllSessions(forUserID userID: String) async throws {
        print("SwiftDataSleepRepository: Deleting all sessions for user \(userID)")

        guard let userUUID = UUID(uuidString: userID) else {
            throw SleepRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDSleepSession>(
            predicate: #Predicate { $0.userProfile?.id == userUUID }
        )

        let sdSessions = try modelContext.fetch(descriptor)

        // Break relationship to SDUserProfile before deleting to avoid
        // "Expected only Arrays for Relationships" crash
        for session in sdSessions {
            session.userProfile = nil
        }

        // Now delete the sessions
        for session in sdSessions {
            modelContext.delete(session)
        }

        try modelContext.save()
        print("SwiftDataSleepRepository: Deleted \(sdSessions.count) sessions")
    }

    // MARK: - Statistics

    func calculateStatistics(
        forUserID userID: String,
        from: Date,
        to: Date
    ) async throws -> SleepStatistics {
        print("SwiftDataSleepRepository: Calculating statistics from \(from) to \(to)")

        let sessions = try await fetchSessions(forUserID: userID, from: from, to: to)

        guard !sessions.isEmpty else {
            return SleepStatistics(
                averageTimeInBedMinutes: 0,
                averageSleepMinutes: 0,
                averageEfficiency: 0.0,
                totalSessions: 0,
                dateRange: from...to
            )
        }

        let totalTimeInBed = sessions.reduce(0) { $0 + $1.timeInBedMinutes }
        let totalSleep = sessions.reduce(0) { $0 + $1.totalSleepMinutes }
        let totalEfficiency = sessions.reduce(0.0) { $0 + $1.sleepEfficiency }

        let avgTimeInBed = totalTimeInBed / sessions.count
        let avgSleep = totalSleep / sessions.count
        let avgEfficiency = totalEfficiency / Double(sessions.count)

        let stats = SleepStatistics(
            averageTimeInBedMinutes: avgTimeInBed,
            averageSleepMinutes: avgSleep,
            averageEfficiency: avgEfficiency,
            totalSessions: sessions.count,
            dateRange: from...to
        )

        print(
            "SwiftDataSleepRepository: Statistics calculated - \(sessions.count) sessions, avg \(avgSleep) min sleep"
        )
        return stats
    }
}

// MARK: - Domain Model Conversions
// Note: Extensions are defined in PersistenceHelper.swift to avoid duplication
