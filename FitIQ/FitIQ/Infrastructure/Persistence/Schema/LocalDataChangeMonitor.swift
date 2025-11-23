import Combine
// Infrastructure/Services/LocalDataChangeMonitor.swift
import Foundation
import SwiftData

/// A monitor that reacts to explicit notifications of local SwiftData changes that need to be synced to the backend.
/// It publishes `LocalDataNeedsSyncEvent` for any `SDPhysicalAttribute` or `SDActivitySnapshot`
/// where `backendID` is nil (new record) or `updatedAt` is more recent than `backendSyncedAt` (updated record).
public final class LocalDataChangeMonitor {
    private let modelContainer: ModelContainer
    public let eventPublisher: LocalDataChangePublisherProtocol  // This publisher is now the output of this monitor

    // No need for cancellables or timer as it's no longer polling.

    public init(modelContainer: ModelContainer, eventPublisher: LocalDataChangePublisherProtocol) {
        self.modelContainer = modelContainer
        self.eventPublisher = eventPublisher
    }

    /// Notifies the monitor that a specific local record has been changed and should be checked for remote sync.
    /// This method replaces the polling mechanism and is intended to be called by SwiftData repositories
    /// immediately after saving or updating a record.
    ///
    /// - Parameters:
    ///   - localID: The UUID of the local SwiftData record that was changed.
    ///   - userID: The UUID of the user profile associated with the record.
    ///   - modelType: The type of the model that was changed (`.physicalAttribute` or `.activitySnapshot`).
    @MainActor  // All SwiftData operations should ideally be on the main actor or a dedicated actor
    public func notifyLocalRecordChanged(
        forLocalID localID: UUID, userID: UUID, modelType: LocalDataNeedsSyncEvent.ModelType
    ) async {
        let context = ModelContext(modelContainer)

        do {
            switch modelType {
            case .physicalAttribute:
                let predicate = #Predicate<SDPhysicalAttribute> {
                    $0.id == localID && $0.userProfile?.id == userID
                }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1

                if let attribute = try context.fetch(descriptor).first {
                    let isNew = attribute.backendID == nil
                    let isUpdatedButNeverSynced =
                        (attribute.updatedAt != nil && attribute.backendSyncedAt == nil)
                    let isMoreRecentlyUpdated =
                        (attribute.updatedAt ?? .distantPast)
                        > (attribute.backendSyncedAt ?? .distantPast)

                    if isNew || isUpdatedButNeverSynced || isMoreRecentlyUpdated {
                        print(
                            "LocalDataChangeMonitor: Publishing sync event for PhysicalAttribute (ID: \(localID), new: \(isNew))"
                        )
                        eventPublisher.publish(
                            event: LocalDataNeedsSyncEvent(
                                localID: attribute.id,
                                userID: userID,
                                modelType: .physicalAttribute,
                                isNewRecord: isNew
                            ))
                    } else {
                        print(
                            "LocalDataChangeMonitor: PhysicalAttribute (ID: \(localID)) does not require sync (already up-to-date with backend or not modified)."
                        )
                    }
                } else {
                    print(
                        "LocalDataChangeMonitor: PhysicalAttribute with ID \(localID) not found for user \(userID)."
                    )
                }

            case .activitySnapshot:
                let predicate = #Predicate<SDActivitySnapshot> {
                    $0.id == localID && $0.userProfile?.id == userID
                }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1

                if let snapshot = try context.fetch(descriptor).first {
                    let isNew = snapshot.backendID == nil
                    let isUpdatedButNeverSynced =
                        (snapshot.updatedAt != nil && snapshot.backendSyncedAt == nil)
                    let isMoreRecentlyUpdated =
                        (snapshot.updatedAt ?? .distantPast)
                        > (snapshot.backendSyncedAt ?? .distantPast)

                    if isNew || isUpdatedButNeverSynced || isMoreRecentlyUpdated {
                        print(
                            "LocalDataChangeMonitor: Publishing sync event for ActivitySnapshot (ID: \(localID), new: \(isNew))"
                        )
                        eventPublisher.publish(
                            event: LocalDataNeedsSyncEvent(
                                localID: snapshot.id,
                                userID: userID,
                                modelType: .activitySnapshot,
                                isNewRecord: isNew
                            ))
                    } else {
                        print(
                            "LocalDataChangeMonitor: ActivitySnapshot (ID: \(localID)) does not require sync (already up-to-date with backend or not modified)."
                        )
                    }
                } else {
                    print(
                        "LocalDataChangeMonitor: ActivitySnapshot with ID \(localID) not found for user \(userID)."
                    )
                }

            case .progressEntry:
                // FIXED: Context isolation issue - don't try to fetch from SwiftData
                // The repository already saved the entry as .pending, so we can trust it needs sync
                // Fetching from a different ModelContext causes context isolation issues

                print(
                    "LocalDataChangeMonitor: Publishing sync event for ProgressEntry (ID: \(localID))"
                )
                print("  - User ID: \(userID)")
                print("  - Assuming new record (backendID: nil, syncStatus: pending)")

                // Directly publish the sync event without querying SwiftData
                // The repository knows the entry was just saved with syncStatus: .pending
                eventPublisher.publish(
                    event: LocalDataNeedsSyncEvent(
                        localID: localID,
                        userID: userID,
                        modelType: .progressEntry,
                        isNewRecord: true  // Assume new since we just saved it
                    ))

                print("LocalDataChangeMonitor: ✅ Published sync event successfully")
            }
        } catch {
            print(
                "LocalDataChangeMonitor: Error processing local change for ID \(localID), type \(modelType): \(error.localizedDescription)"
            )
        }
    }

    // The startMonitoring and stopMonitoring methods are no longer needed for a polling mechanism.
    // They can be removed, or adapted if they serve another purpose (e.g., setting up subscriptions, though that's not its primary role here).

    // Leaving empty stubs for now, if they are called elsewhere. Best to remove them if truly unused.
    public func startMonitoring(forUserID userID: UUID) {
        print(
            "LocalDataChangeMonitor: Note: startMonitoring called, but this monitor is now push-based. No polling started."
        )
    }

    public func stopMonitoring() {
        print(
            "LocalDataChangeMonitor: Note: stopMonitoring called, but this monitor is now push-based. No polling stopped."
        )
    }
}
