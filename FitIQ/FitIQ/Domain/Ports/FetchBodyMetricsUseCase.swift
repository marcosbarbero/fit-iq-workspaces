// Domain/UseCases/FetchBodyMetricsUseCase.swift
import Foundation

// MARK: - Protocol

protocol FetchBodyMetricsUseCaseProtocol {
    /// Fetches historical body metrics for the current user, optionally filtered by date range and limit.
    /// - Parameters:
    ///   - userID: The ID of the user for whom to fetch metrics.
    ///   - startDate: Optional start date for filtering.
    ///   - endDate: Optional end date for filtering.
    ///   - limit: Optional maximum number of records to fetch.
    /// - Returns: An array of `SDPhysicalAttribute` representing the fetched body metrics.
    @MainActor
    func execute(
        forUserID userID: UUID,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [SDPhysicalAttribute]
}

// MARK: - Implementation

final class FetchBodyMetricsUseCase: FetchBodyMetricsUseCaseProtocol {
    private let remoteHealthDataSyncPort: RemoteHealthDataSyncPort
    private let localHealthDataStorePort: LocalHealthDataStorePort

    init(remoteHealthDataSyncPort: RemoteHealthDataSyncPort, localHealthDataStorePort: LocalHealthDataStorePort) {
        self.remoteHealthDataSyncPort = remoteHealthDataSyncPort
        self.localHealthDataStorePort = localHealthDataStorePort
    }

    @MainActor
    func execute(
        forUserID userID: UUID,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [SDPhysicalAttribute] {

        print("FetchBodyMetricsUseCase: Executing fetch body metrics for user \(userID).")

        do {
            let remoteMetrics = try await remoteHealthDataSyncPort.fetchBodyMetrics(
                forUserID: userID,
                startDate: startDate,
                endDate: endDate,
                limit: limit
            )

            var savedLocalMetrics: [SDPhysicalAttribute] = []

            for snapshot in remoteMetrics {
                for metricInput in snapshot.metrics {
                    // Map metricInput.type string to PhysicalAttributeType enum
                    guard let type = PhysicalAttributeType(rawValue: metricInput.type.rawValue) else {
                        print("FetchBodyMetricsUseCase: Warning - Unknown metric type: \(metricInput.type). Skipping.")
                        continue
                    }

                    let attributeBackendID = snapshot.id.uuidString

                    var existingAttribute: SDPhysicalAttribute? = nil
                    do {
                        existingAttribute = try await localHealthDataStorePort.fetchPhysicalAttribute(
                            forBackendID: attributeBackendID,
                            of: type,
                            for: userID
                        )
                    } catch {
                        print("FetchBodyMetricsUseCase: Error fetching existing attribute for backendID \(attributeBackendID), type \(type.rawValue): \(error.localizedDescription). Proceeding as new.")
                    }

                    if let attribute = existingAttribute {
                        // Update existing attribute if its value or recorded date has changed remotely
                        if attribute.value != metricInput.value || !Calendar.current.isDate(attribute.createdAt, equalTo: snapshot.recordedAt, toGranularity: .second) {
                            attribute.value = metricInput.value
                            attribute.createdAt = snapshot.recordedAt
                            try await localHealthDataStorePort.updatePhysicalAttribute(attribute, for: userID)
                            savedLocalMetrics.append(attribute)
                            print("FetchBodyMetricsUseCase: Updated local SDPhysicalAttribute (ID: \(attribute.id), BackendID: \(attributeBackendID), Type: \(type.rawValue)) from remote data.")
                        } else {
                            savedLocalMetrics.append(attribute)
                            print("FetchBodyMetricsUseCase: SDPhysicalAttribute (ID: \(attribute.id), BackendID: \(attributeBackendID), Type: \(type.rawValue)) unchanged from remote.")
                        }
                    } else {
                        // Save as new attribute
                        let newAttributeID = try await localHealthDataStorePort.savePhysicalAttribute(
                            value: metricInput.value,
                            type: type,
                            date: snapshot.recordedAt,
                            for: userID,
                            backendID: attributeBackendID
                        )
                        if let newAttribute = try await localHealthDataStorePort.fetchPhysicalAttribute(forLocalID: newAttributeID, for: userID) {
                            savedLocalMetrics.append(newAttribute)
                            print("FetchBodyMetricsUseCase: Saved new local SDPhysicalAttribute (ID: \(newAttributeID), BackendID: \(attributeBackendID), Type: \(type.rawValue)) from remote data.")
                        } else {
                            print("FetchBodyMetricsUseCase: Warning: Could not re-fetch newly saved attribute with ID \(newAttributeID).")
                        }
                    }
                }
            }
            return savedLocalMetrics.sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            print("FetchBodyMetricsUseCase: Failed to fetch and store body metrics: \(error.localizedDescription)")
            throw error
        }
    }
}
