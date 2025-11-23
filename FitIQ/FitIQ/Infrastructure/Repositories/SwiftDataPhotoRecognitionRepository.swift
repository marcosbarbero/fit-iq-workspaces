//
//  SwiftDataPhotoRecognitionRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Infrastructure adapter for photo recognition persistence using SwiftData
//

import Foundation
import SwiftData

/// SwiftData implementation of PhotoRecognitionRepositoryProtocol
/// Handles local persistence of photo recognition data following Hexagonal Architecture
final class SwiftDataPhotoRecognitionRepository: PhotoRecognitionRepositoryProtocol {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    func save(_ photoRecognition: PhotoRecognition) async throws -> PhotoRecognition {
        // Fetch and link user profile
        guard let userID = UUID(uuidString: photoRecognition.userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        let userDescriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate<SDUserProfile> { profile in
                profile.id == userID
            }
        )

        guard let userProfile = try modelContext.fetch(userDescriptor).first else {
            throw PhotoRecognitionRepositoryError.userProfileNotFound
        }

        // Convert domain model to SwiftData model (SchemaV11 structure)
        let sdPhotoRecognition = SDPhotoRecognition(
            id: photoRecognition.id,
            status: photoRecognition.status.rawValue,
            createdAt: photoRecognition.createdAt,
            updatedAt: photoRecognition.updatedAt,
            processedAt: photoRecognition.processingCompletedAt,
            errorMessage: photoRecognition.errorMessage,
            backendID: photoRecognition.backendID,
            syncStatus: photoRecognition.syncStatus.rawValue,
            photoFileName: photoRecognition.imageURL,
            rawResponse: nil,
            recognizedFoods: [],
            userProfile: userProfile
        )

        // Convert recognized items
        for item in photoRecognition.recognizedItems {
            let sdItem = SDRecognizedFoodItem(
                id: item.id,
                foodName: item.name,
                quantity: item.quantity,
                unit: item.unit,
                calories: Double(item.calories),
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                fiberG: item.fiberG,
                sugarG: item.sugarG,
                confidence: item.confidenceScore,
                orderIndex: item.orderIndex,
                createdAt: photoRecognition.createdAt,
                photoRecognition: sdPhotoRecognition
            )
            sdPhotoRecognition.recognizedFoods?.append(sdItem)
        }

        // Save to context
        modelContext.insert(sdPhotoRecognition)
        try modelContext.save()

        return photoRecognition
    }

    // MARK: - Read

    func fetchAll(
        forUserID userID: String,
        status: PhotoRecognitionStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?,
        offset: Int?
    ) async throws -> [PhotoRecognition] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDPhotoRecognition>(
            sortBy: [SortDescriptor(\SDPhotoRecognition.createdAt, order: .reverse)]
        )

        // Build predicate based on filters
        if let status = status, let startDate = startDate, let endDate = endDate {
            let statusRaw = status.rawValue
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
                    && photo.status == statusRaw
                    && photo.createdAt >= startDate
                    && photo.createdAt <= endDate
            }
        } else if let status = status, let startDate = startDate {
            let statusRaw = status.rawValue
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
                    && photo.status == statusRaw
                    && photo.createdAt >= startDate
            }
        } else if let status = status, let endDate = endDate {
            let statusRaw = status.rawValue
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
                    && photo.status == statusRaw
                    && photo.createdAt <= endDate
            }
        } else if let startDate = startDate, let endDate = endDate {
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
                    && photo.createdAt >= startDate
                    && photo.createdAt <= endDate
            }
        } else if let status = status {
            let statusRaw = status.rawValue
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.status == statusRaw
            }
        } else if let startDate = startDate {
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.createdAt >= startDate
            }
        } else if let endDate = endDate {
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.createdAt <= endDate
            }
        } else {
            descriptor.predicate = #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
            }
        }

        // Apply pagination
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        if let offset = offset {
            descriptor.fetchOffset = offset
        }

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }

    func fetchByID(_ id: UUID) async throws -> PhotoRecognition? {
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.id == id
            }
        )

        guard let sdPhoto = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdPhoto.toDomain()
    }

    func fetchByBackendID(_ backendID: String) async throws -> PhotoRecognition? {
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.backendID == backendID
            }
        )

        guard let sdPhoto = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdPhoto.toDomain()
    }

    func fetchPendingSync(forUserID userID: String) async throws -> [PhotoRecognition] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.syncStatus == "pending"
            },
            sortBy: [SortDescriptor(\SDPhotoRecognition.createdAt, order: .forward)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }

    func fetchAwaitingConfirmation(forUserID userID: String) async throws -> [PhotoRecognition] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.status == "completed"
            },
            sortBy: [SortDescriptor(\SDPhotoRecognition.processedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }

    func fetchPendingForProcessing(userID: String, limit: Int) async throws -> [PhotoRecognition] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        var descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.status == "pending"
            },
            sortBy: [SortDescriptor(\SDPhotoRecognition.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }

    func fetchRecent(userID: String, days: Int) async throws -> [PhotoRecognition] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID && photo.createdAt >= startDate
            },
            sortBy: [SortDescriptor(\SDPhotoRecognition.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }

    // MARK: - Update

    func update(_ photoRecognition: PhotoRecognition) async throws -> PhotoRecognition {
        // Fetch existing record
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.id == photoRecognition.id
            }
        )

        guard let sdPhotoRecognition = try modelContext.fetch(descriptor).first else {
            throw PhotoRecognitionRepositoryError.photoRecognitionNotFound
        }

        // Update fields (SchemaV11 structure)
        sdPhotoRecognition.status = photoRecognition.status.rawValue
        sdPhotoRecognition.updatedAt = photoRecognition.updatedAt
        sdPhotoRecognition.processedAt = photoRecognition.processingCompletedAt
        sdPhotoRecognition.errorMessage = photoRecognition.errorMessage
        sdPhotoRecognition.backendID = photoRecognition.backendID
        sdPhotoRecognition.syncStatus = photoRecognition.syncStatus.rawValue
        sdPhotoRecognition.photoFileName = photoRecognition.imageURL

        // Update recognized items
        // Remove existing items
        if let existingItems = sdPhotoRecognition.recognizedFoods {
            for item in existingItems {
                modelContext.delete(item)
            }
        }

        // Add new items
        var newItems: [SDRecognizedFoodItem] = []
        for item in photoRecognition.recognizedItems {
            let sdItem = SDRecognizedFoodItem(
                id: item.id,
                foodName: item.name,
                quantity: item.quantity,
                unit: item.unit,
                calories: Double(item.calories),
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                fiberG: item.fiberG,
                sugarG: item.sugarG,
                confidence: item.confidenceScore,
                orderIndex: item.orderIndex,
                createdAt: photoRecognition.createdAt,
                photoRecognition: sdPhotoRecognition
            )
            newItems.append(sdItem)
        }
        sdPhotoRecognition.recognizedFoods = newItems

        try modelContext.save()

        return photoRecognition
    }

    func updateStatus(
        _ id: UUID,
        status: PhotoRecognitionStatus,
        errorMessage: String?
    ) async throws -> PhotoRecognition {
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.id == id
            }
        )

        guard let sdPhotoRecognition = try modelContext.fetch(descriptor).first else {
            throw PhotoRecognitionRepositoryError.photoRecognitionNotFound
        }

        sdPhotoRecognition.status = status.rawValue
        sdPhotoRecognition.errorMessage = errorMessage
        sdPhotoRecognition.updatedAt = Date()

        try modelContext.save()

        return sdPhotoRecognition.toDomain()
    }

    func updateSyncStatus(
        _ id: UUID,
        syncStatus: SyncStatus,
        backendID: String?
    ) async throws -> PhotoRecognition {
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.id == id
            }
        )

        guard let sdPhotoRecognition = try modelContext.fetch(descriptor).first else {
            throw PhotoRecognitionRepositoryError.photoRecognitionNotFound
        }

        sdPhotoRecognition.syncStatus = syncStatus.rawValue
        if let backendID = backendID {
            sdPhotoRecognition.backendID = backendID
        }
        sdPhotoRecognition.updatedAt = Date()

        try modelContext.save()

        return sdPhotoRecognition.toDomain()
    }

    func markAsConfirmed(
        _ id: UUID,
        mealLogID: UUID
    ) async throws -> PhotoRecognition {
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.id == id
            }
        )

        guard let sdPhotoRecognition = try modelContext.fetch(descriptor).first else {
            throw PhotoRecognitionRepositoryError.photoRecognitionNotFound
        }

        sdPhotoRecognition.status = PhotoRecognitionStatus.confirmed.rawValue
        sdPhotoRecognition.updatedAt = Date()
        // Note: SchemaV11 doesn't have mealLogID field, so we just update status

        try modelContext.save()

        return sdPhotoRecognition.toDomain()
    }

    // MARK: - Delete

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.id == id
            }
        )

        guard let sdPhotoRecognition = try modelContext.fetch(descriptor).first else {
            throw PhotoRecognitionRepositoryError.photoRecognitionNotFound
        }

        modelContext.delete(sdPhotoRecognition)
        try modelContext.save()
    }

    func deleteAll(forUserID userID: String) async throws {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
            }
        )

        let results = try modelContext.fetch(descriptor)
        for photo in results {
            modelContext.delete(photo)
        }

        try modelContext.save()
    }

    // MARK: - Statistics

    func count(
        forUserID userID: String,
        status: PhotoRecognitionStatus?
    ) async throws -> Int {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        var descriptor: FetchDescriptor<SDPhotoRecognition>

        if let status = status {
            let statusRaw = status.rawValue
            descriptor = FetchDescriptor<SDPhotoRecognition>(
                predicate: #Predicate<SDPhotoRecognition> { photo in
                    photo.userProfile?.id == userUUID && photo.status == statusRaw
                }
            )
        } else {
            descriptor = FetchDescriptor<SDPhotoRecognition>(
                predicate: #Predicate<SDPhotoRecognition> { photo in
                    photo.userProfile?.id == userUUID
                }
            )
        }

        let results = try modelContext.fetch(descriptor)
        return results.count
    }

    func countByStatus(userID: String) async throws -> [PhotoRecognitionStatus: Int] {
        guard let userUUID = UUID(uuidString: userID) else {
            throw PhotoRecognitionRepositoryError.invalidUserID
        }

        let descriptor = FetchDescriptor<SDPhotoRecognition>(
            predicate: #Predicate<SDPhotoRecognition> { photo in
                photo.userProfile?.id == userUUID
            }
        )

        let results = try modelContext.fetch(descriptor)
        var counts: [PhotoRecognitionStatus: Int] = [:]

        for photo in results {
            if let status = PhotoRecognitionStatus(rawValue: photo.status) {
                counts[status, default: 0] += 1
            }
        }

        return counts
    }
}

// MARK: - Errors

enum PhotoRecognitionRepositoryError: LocalizedError {
    case invalidUserID
    case userProfileNotFound
    case photoRecognitionNotFound

    var errorDescription: String? {
        switch self {
        case .invalidUserID:
            return "Invalid user ID format"
        case .userProfileNotFound:
            return "User profile not found"
        case .photoRecognitionNotFound:
            return "Photo recognition not found"
        }
    }
}
