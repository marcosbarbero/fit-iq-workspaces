// Domain/UseCases/GetLatestActivitySnapshotUseCase.swift
import Foundation

/// Defines the contract for fetching an activity snapshot for a user on a specific date.
public protocol GetLatestActivitySnapshotUseCaseProtocol {
    /// Executes the use case to retrieve an activity snapshot for a given date.
    /// - Parameters:
    ///   - userID: The ID of the user.
    ///   - date: The specific date (typically start of day) for which to fetch the snapshot.
    /// - Returns: The `ActivitySnapshot` for the specified date, or `nil` if none is found.
    func execute(forUserID userID: String, date: Date) async throws -> ActivitySnapshot?
}

/// Implementation of the use case to get an activity snapshot for a specific date.
public final class GetLatestActivitySnapshotUseCase: GetLatestActivitySnapshotUseCaseProtocol {
    private let activitySnapshotRepository: ActivitySnapshotRepositoryProtocol

    init(activitySnapshotRepository: ActivitySnapshotRepositoryProtocol) {
        self.activitySnapshotRepository = activitySnapshotRepository
    }

    public func execute(forUserID userID: String, date: Date) async throws -> ActivitySnapshot? {
        do {
            // Now, this use case specifically fetches for a given date,
            // which aligns with the SummaryView's requirement for "current day".
            return try await activitySnapshotRepository.fetchActivitySnapshot(forUserID: userID, date: date)
        } catch {
            print("GetLatestActivitySnapshotUseCase: Failed to fetch activity snapshot for user \(userID) on date \(date): \(error.localizedDescription)")
            throw error // Re-throw for upstream handling
        }
    }
}

