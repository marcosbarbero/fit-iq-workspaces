// Infrastructure/Persistence/SwiftDataLocalHealthDataStore.swift
import Foundation
import SwiftData

/// An adapter that implements LocalHealthDataStorePort using SwiftData.
/// It persists individual body metrics like mass and height as SDPhysicalAttribute.
class SwiftDataLocalHealthDataStore: LocalHealthDataStorePort {
    private let modelContainer: ModelContainer
    private let localDataChangeMonitor: LocalDataChangeMonitor

    init(modelContainer: ModelContainer, localDataChangeMonitor: LocalDataChangeMonitor) {
        self.modelContainer = modelContainer
        self.localDataChangeMonitor = localDataChangeMonitor
    }

    /// Saves a physical attribute, optionally with a pre-existing backend ID.
    func savePhysicalAttribute(
        value: Double, type: PhysicalAttributeType, date: Date, for userProfileID: UUID,
        backendID: String?
    ) async throws -> UUID {
        let context = ModelContext(modelContainer)

        guard let sdUserProfile = try fetchSDUserProfile(id: userProfileID, in: context) else {
            throw LocalHealthDataStoreError.userProfileNotFound
        }

        let newAttribute = SDPhysicalAttribute(
            value: value,
            type: type,
            createdAt: date,
            updatedAt: date,
            backendID: backendID,
            backendSyncedAt: backendID != nil ? Date() : nil,
            userProfile: sdUserProfile
        )
        context.insert(newAttribute)

        do {
            try context.save()
            print(
                "Successfully saved \(type.rawValue) \(value) with local ID \(newAttribute.id) for user ID: \(userProfileID)"
            )

            if backendID == nil {
                await localDataChangeMonitor.notifyLocalRecordChanged(
                    forLocalID: newAttribute.id, userID: userProfileID,
                    modelType: .physicalAttribute)
            }

            return newAttribute.id
        } catch {
            print(
                "Failed to save \(type.rawValue) for user ID: \(userProfileID): \(error.localizedDescription)"
            )
            throw LocalHealthDataStoreError.saveFailed(error)
        }
    }

    /// Updates the backend ID for an existing physical attribute.
    func updatePhysicalAttributeBackendID(
        forLocalID localID: UUID, newBackendID: String, for userProfileID: UUID
    ) async throws {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SDPhysicalAttribute> { attribute in
            attribute.id == localID && attribute.userProfile?.id == userProfileID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let existingAttribute = try context.fetch(descriptor).first else {
            print(
                "Failed to find SDPhysicalAttribute with local ID \(localID) for user \(userProfileID) to update backendID."
            )
            throw LocalHealthDataStoreError.attributeNotFound
        }

        existingAttribute.backendID = newBackendID
        existingAttribute.backendSyncedAt = Date()
        existingAttribute.updatedAt = Date()

        do {
            try context.save()
            print(
                "Successfully updated backendID for \(existingAttribute.type.rawValue) with local ID \(localID) to \(newBackendID)."
            )
        } catch {
            print(
                "Failed to update backendID for local ID \(localID): \(error.localizedDescription)")
            throw LocalHealthDataStoreError.saveFailed(error)
        }
    }

    /// Fetches a physical attribute by its local UUID.
    func fetchPhysicalAttribute(forLocalID localID: UUID, for userProfileID: UUID) async throws
        -> SDPhysicalAttribute?
    {
        let context = ModelContext(modelContainer)

        let predicate = #Predicate<SDPhysicalAttribute> { attribute in
            attribute.id == localID && attribute.userProfile?.id == userProfileID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            print(
                "Failed to fetch SDPhysicalAttribute with local ID \(localID) for user \(userProfileID): \(error.localizedDescription)"
            )
            throw LocalHealthDataStoreError.fetchFailed(error)
        }
    }

    /// Fetches a physical attribute by its backend ID and type.
    func fetchPhysicalAttribute(
        forBackendID backendID: String, of type: PhysicalAttributeType, for userProfileID: UUID
    ) async throws -> SDPhysicalAttribute? {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<SDPhysicalAttribute> { attribute in
            attribute.backendID == backendID && attribute.type == type
                && attribute.userProfile?.id == userProfileID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            print(
                "Failed to fetch SDPhysicalAttribute with backend ID \(backendID) and type \(type.rawValue) for user \(userProfileID): \(error.localizedDescription)"
            )
            throw LocalHealthDataStoreError.fetchFailed(error)
        }
    }

    /// Updates an existing SDPhysicalAttribute object directly.
    func updatePhysicalAttribute(_ attribute: SDPhysicalAttribute, for userProfileID: UUID)
        async throws
    {
        let context = ModelContext(modelContainer)

        // Fetch the managed object to update. This ensures we're working with the current context's managed instance.
        guard
            let existingAttribute = try await fetchPhysicalAttribute(
                forLocalID: attribute.id, for: userProfileID)
        else {
            print(
                "Attempted to update non-existent SDPhysicalAttribute (ID: \(attribute.id)) for user \(userProfileID)."
            )
            throw LocalHealthDataStoreError.attributeNotFound
        }

        // Apply changes from the detached 'attribute' to the managed 'existingAttribute'
        existingAttribute.value = attribute.value
        existingAttribute.type = attribute.type
        existingAttribute.createdAt = attribute.createdAt
        existingAttribute.updatedAt = Date()
        existingAttribute.backendID = attribute.backendID
        existingAttribute.backendSyncedAt = Date()

        do {
            try context.save()
            print(
                "Successfully updated SDPhysicalAttribute (ID: \(existingAttribute.id), Type: \(existingAttribute.type.rawValue)) for user ID: \(userProfileID)."
            )
        } catch {
            print(
                "Failed to update SDPhysicalAttribute (ID: \(attribute.id)) for user ID: \(userProfileID): \(error.localizedDescription)"
            )
            throw LocalHealthDataStoreError.saveFailed(error)
        }
    }

    private func fetchSDUserProfile(id: UUID, in context: ModelContext) throws -> SDUserProfile? {
        let predicate = #Predicate<SDUserProfile> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

// MARK: - Error Types
enum LocalHealthDataStoreError: Error, LocalizedError {
    case userProfileNotFound
    case attributeNotFound
    case saveFailed(Error)
    case fetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .userProfileNotFound:
            return "The associated user profile could not be found in the database."
        case .attributeNotFound:
            return "The physical attribute with the specified local ID could not be found."
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        }
    }
}
