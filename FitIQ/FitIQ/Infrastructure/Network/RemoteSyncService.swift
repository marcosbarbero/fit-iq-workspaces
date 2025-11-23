import Combine
// Infrastructure/Services/RemoteSyncService.swift
import Foundation
import SwiftData

/// A service responsible for reacting to local data changes and synchronizing them with the backend.
public final class RemoteSyncService: RemoteSyncServiceProtocol {
    private let localDataChangePublisher: LocalDataChangePublisherProtocol
    private let remoteDataSync: RemoteHealthDataSyncPort  // This remains a port
    private let localHealthDataStore: LocalHealthDataStorePort
    private let activitySnapshotRepository: ActivitySnapshotRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let modelContainer: ModelContainer

    private var cancellables = Set<AnyCancellable>()
    private var currentUserID: UUID?

    // Rate limiting for progress syncs
    private var lastProgressSyncTime: Date?
    private let minimumProgressSyncInterval: TimeInterval = 0.5  // 0.5 seconds between syncs

    init(
        localDataChangePublisher: LocalDataChangePublisherProtocol,
        remoteDataSync: RemoteHealthDataSyncPort,  // The type accepted here is the port
        localHealthDataStore: LocalHealthDataStorePort,
        activitySnapshotRepository: ActivitySnapshotRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        modelContainer: ModelContainer
    ) {
        self.localDataChangePublisher = localDataChangePublisher
        self.remoteDataSync = remoteDataSync  // The concrete client will be passed here
        self.localHealthDataStore = localHealthDataStore
        self.activitySnapshotRepository = activitySnapshotRepository
        self.progressRepository = progressRepository
        self.modelContainer = modelContainer
    }

    public func startSyncing(forUserID userID: UUID) {
        self.currentUserID = userID
        print(
            "RemoteSyncService: Starting to listen for local data sync events for user \(userID).")

        // Stop any previous subscriptions to prevent duplicates if startSyncing is called multiple times
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        localDataChangePublisher.publisher
            .receive(on: DispatchQueue.global(qos: .background))  // Process events on a background queue
            .sink { [weak self] event in
                guard let self = self else { return }
                guard event.userID == userID else {  // Ensure event is for the current user
                    print("RemoteSyncService: Ignoring event for non-current user \(event.userID).")
                    return
                }

                Task {
                    await self.process(event: event)
                }
            }
            .store(in: &cancellables)
    }

    public func stopSyncing() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        self.currentUserID = nil
        print("RemoteSyncService: Stopped listening for local data sync events.")
    }

    @MainActor  // Using MainActor for context operations for now, or could use a dedicated SwiftData actor
    private func process(event: LocalDataNeedsSyncEvent) async {
        guard let userID = currentUserID else {
            print("RemoteSyncService: Cannot process event, no current user ID set.")
            return
        }

        do {
            switch event.modelType {
            case .physicalAttribute:
                // Fetch the full SDPhysicalAttribute to get its value and type
                guard
                    let sdAttribute = try await localHealthDataStore.fetchPhysicalAttribute(
                        forLocalID: event.localID, for: userID)
                else {
                    print(
                        "RemoteSyncService: SDPhysicalAttribute with localID \(event.localID) not found for remote sync."
                    )
                    return
                }

                // Prepare parameters for remoteDataSync
                let backendID: String?
                // The current API only supports bodyMass, so we focus on that attribute type for upload.
                // Height will be handled once its API is available.
                switch sdAttribute.type {
                case .bodyMass:
                    if event.isNewRecord {
                        // This is a new record locally, upload it
                        backendID = try await remoteDataSync.uploadBodyMass(
                            kg: sdAttribute.value ?? 0,
                            date: sdAttribute.createdAt,
                            for: userID,
                            localID: sdAttribute.id
                        )
                    } else {
                        // This is an existing record with local updates, typically a PATCH/PUT operation on backend
                        // For now, re-using uploadBodyMass, which implies an upsert capability on the backend.
                        // A real API might need a separate 'update' method with the existing backendID.
                        backendID = try await remoteDataSync.uploadBodyMass(
                            kg: sdAttribute.value ?? 0,
                            date: sdAttribute.createdAt,
                            for: userID,
                            localID: sdAttribute.id  // Always send localID, backend can use it for idempotency check
                        )
                    }
                case .height:
                    // Height API is not yet available, so we log and skip.
                    print(
                        "RemoteSyncService: Skipping sync for height (SDPhysicalAttribute with localID \(event.localID)). Backend API not yet supported."
                    )
                    backendID = nil  // No backend ID can be obtained for height yet
                case .bodyFatPercentage:
                    backendID = try await remoteDataSync.uploadBodyFatPercentage(
                        percentage: sdAttribute.value ?? 0,
                        date: sdAttribute.createdAt,
                        for: userID,
                        localID: sdAttribute.id
                    )
                    print(
                        "RemoteSyncService: Attempted upload of Body Fat Percentage (\(sdAttribute.value ?? 0)%) for localID \(sdAttribute.id)"
                    )

                case .bmi:
                    backendID = try await remoteDataSync.uploadBMI(
                        bmi: sdAttribute.value ?? 0,
                        date: sdAttribute.createdAt,
                        for: userID,
                        localID: sdAttribute.id
                    )
                    print(
                        "RemoteSyncService: Attempted upload of BMI (\(sdAttribute.value ?? 0)) for localID \(sdAttribute.id)"
                    )
                }

                // If a backendID is received, update the local record
                if let receivedBackendID = backendID {
                    try await localHealthDataStore.updatePhysicalAttributeBackendID(
                        forLocalID: event.localID, newBackendID: receivedBackendID, for: userID)
                    print(
                        "RemoteSyncService: Successfully synced SDPhysicalAttribute \(event.localID). BackendID: \(receivedBackendID)"
                    )
                } else {
                    // This else block will now also catch the case where height sync was skipped.
                    print(
                        "RemoteSyncService: No backend ID returned or sync skipped for SDPhysicalAttribute \(event.localID). Status not updated."
                    )
                }

            case .activitySnapshot:
                // Fetch the full ActivitySnapshot (domain model)
                guard
                    let activitySnapshot =
                        try await activitySnapshotRepository.fetchActivitySnapshot(
                            forLocalID: event.localID, for: userID.uuidString)
                else {
                    print(
                        "RemoteSyncService: ActivitySnapshot with localID \(event.localID) not found for remote sync."
                    )
                    return
                }

                // This call will likely throw an error from RemoteHealthDataSyncClient
                // as its API is not yet defined. The catch block will handle it.
                let backendID = try await remoteDataSync.uploadActivitySnapshot(
                    snapshot: activitySnapshot, for: userID)

                if let receivedBackendID = backendID {
                    try await activitySnapshotRepository.updateActivitySnapshotBackendID(
                        forLocalID: event.localID, newBackendID: receivedBackendID,
                        for: userID.uuidString)
                    print(
                        "RemoteSyncService: Successfully synced SDActivitySnapshot \(event.localID). BackendID: \(receivedBackendID)"
                    )
                } else {
                    print(
                        "RemoteSyncService: Uploaded SDActivitySnapshot \(event.localID), but no backend ID returned. Status not updated."
                    )
                }

            case .progressEntry:
                // Rate limiting: Add delay if we synced recently
                if let lastSync = lastProgressSyncTime {
                    let timeSinceLastSync = Date().timeIntervalSince(lastSync)
                    if timeSinceLastSync < minimumProgressSyncInterval {
                        let delayNeeded = minimumProgressSyncInterval - timeSinceLastSync
                        print(
                            "RemoteSyncService: ⏱️ Rate limiting: Waiting \(String(format: "%.2f", delayNeeded))s before next sync"
                        )
                        try? await Task.sleep(nanoseconds: UInt64(delayNeeded * 1_000_000_000))
                    }
                }

                // Fetch the progress entry from local storage
                print(
                    "RemoteSyncService: 📤 Processing progressEntry sync event for localID \(event.localID)"
                )

                let entries = try await progressRepository.fetchLocal(
                    forUserID: userID.uuidString,
                    type: nil,
                    syncStatus: nil,
                    limit: 100  // Limit to recent entries for performance
                )

                guard let progressEntry = entries.first(where: { $0.id == event.localID }) else {
                    print(
                        "RemoteSyncService: ❌ ProgressEntry with localID \(event.localID) not found for remote sync."
                    )
                    return
                }

                print("RemoteSyncService: Found progress entry to sync:")
                print("  - Type: \(progressEntry.type.rawValue)")
                print("  - Quantity: \(progressEntry.quantity)")
                print("  - Date: \(progressEntry.date)")
                print("  - Time: \(progressEntry.time ?? "nil")")
                print("  - Current sync status: \(progressEntry.syncStatus.rawValue)")

                // Update status to syncing
                try await progressRepository.updateSyncStatus(
                    forLocalID: event.localID,
                    status: .syncing,
                    forUserID: userID.uuidString
                )
                print("RemoteSyncService: Updated sync status to 'syncing'")

                do {
                    // Upload to backend via progress API
                    print(
                        "RemoteSyncService: 🌐 Calling /api/v1/progress API to upload progress entry..."
                    )

                    // Combine date and time into a single loggedAt timestamp
                    let calendar = Calendar.current
                    let dateComponents = calendar.dateComponents(
                        [.year, .month, .day], from: progressEntry.date)

                    var loggedAtDate = progressEntry.date
                    if let time = progressEntry.time {
                        let timeComponents = time.split(separator: ":").compactMap { Int($0) }
                        if timeComponents.count >= 2 {
                            var components = dateComponents
                            components.hour = timeComponents[0]
                            components.minute = timeComponents[1]
                            components.second = timeComponents.count > 2 ? timeComponents[2] : 0
                            if let combinedDate = calendar.date(from: components) {
                                loggedAtDate = combinedDate
                            }
                        }
                    }

                    let backendEntry = try await progressRepository.logProgress(
                        type: progressEntry.type,
                        quantity: progressEntry.quantity,
                        loggedAt: loggedAtDate,
                        notes: progressEntry.notes
                    )

                    print("RemoteSyncService: ✅ /api/v1/progress API call successful!")
                    print("  - Backend ID: \(backendEntry.backendID ?? "nil")")
                    print("  - Backend created at: \(backendEntry.createdAt)")

                    // Update local entry with backend ID
                    guard let backendID = backendEntry.backendID else {
                        print("RemoteSyncService: ❌ No backend ID in response!")
                        throw RemoteSyncError.missingBackendID
                    }

                    try await progressRepository.updateBackendID(
                        forLocalID: event.localID,
                        backendID: backendID,
                        forUserID: userID.uuidString
                    )
                    print("RemoteSyncService: Updated local entry with backend ID")

                    // Mark as synced
                    try await progressRepository.updateSyncStatus(
                        forLocalID: event.localID,
                        status: .synced,
                        forUserID: userID.uuidString
                    )

                    print(
                        "RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry \(event.localID). Type: \(progressEntry.type.rawValue), Quantity: \(progressEntry.quantity), Backend ID: \(backendID)"
                    )

                    // Update last sync time for rate limiting
                    lastProgressSyncTime = Date()
                } catch {
                    // Mark as failed for retry
                    print("RemoteSyncService: ❌ /api/v1/progress API call FAILED!")
                    print("  - Error: \(error)")
                    print("  - Error description: \(error.localizedDescription)")

                    try await progressRepository.updateSyncStatus(
                        forLocalID: event.localID,
                        status: .failed,
                        forUserID: userID.uuidString
                    )
                    print(
                        "RemoteSyncService: Marked ProgressEntry \(event.localID) as 'failed' for retry"
                    )
                    throw error
                }
            }
        } catch {
            print(
                "RemoteSyncService: Error processing event for localID \(event.localID), type \(event.modelType): \(error.localizedDescription)"
            )
            // Future improvement: Implement a retry mechanism or error queue
        }
    }
}

// MARK: - Errors

enum RemoteSyncError: Error, LocalizedError {
    case missingBackendID

    var errorDescription: String? {
        switch self {
        case .missingBackendID:
            return "Backend ID missing in API response"
        }
    }
}
