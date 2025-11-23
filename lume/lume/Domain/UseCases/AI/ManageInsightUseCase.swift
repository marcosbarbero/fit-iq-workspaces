//
//  ManageInsightUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

// MARK: - Mark As Read Use Case

/// Protocol for marking an insight as read
protocol MarkInsightAsReadUseCaseProtocol {
    /// Mark an insight as read
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Use case error if marking fails
    func execute(id: UUID) async throws -> AIInsight
}

/// Use case for marking an insight as read
final class MarkInsightAsReadUseCase: MarkInsightAsReadUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol
    ) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> AIInsight {
        // Update locally - backend sync handled by Outbox pattern
        let updatedInsight = try await repository.markAsRead(id: id)
        return updatedInsight
    }
}

// MARK: - Toggle Favorite Use Case

/// Protocol for toggling insight favorite status
protocol ToggleInsightFavoriteUseCaseProtocol {
    /// Toggle favorite status of an insight
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Use case error if toggle fails
    func execute(id: UUID) async throws -> AIInsight
}

/// Use case for toggling insight favorite status
final class ToggleInsightFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol
    ) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> AIInsight {
        // Update locally - backend sync handled by Outbox pattern
        let updatedInsight = try await repository.toggleFavorite(id: id)
        return updatedInsight
    }
}

// MARK: - Archive Insight Use Case

/// Protocol for archiving an insight
protocol ArchiveInsightUseCaseProtocol {
    /// Archive an insight
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Use case error if archive fails
    func execute(id: UUID) async throws -> AIInsight
}

/// Use case for archiving an insight
final class ArchiveInsightUseCase: ArchiveInsightUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol
    ) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> AIInsight {
        // Update locally - backend sync handled by Outbox pattern
        let updatedInsight = try await repository.archive(id: id)
        return updatedInsight
    }
}

// MARK: - Unarchive Insight Use Case

/// Protocol for unarchiving an insight
protocol UnarchiveInsightUseCaseProtocol {
    /// Unarchive an insight
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Use case error if unarchive fails
    func execute(id: UUID) async throws -> AIInsight
}

/// Use case for unarchiving an insight
final class UnarchiveInsightUseCase: UnarchiveInsightUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol
    ) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> AIInsight {
        // Update locally - backend sync handled by Outbox pattern
        let updatedInsight = try await repository.unarchive(id: id)
        return updatedInsight
    }
}

// MARK: - Delete Insight Use Case

/// Protocol for deleting an insight
protocol DeleteInsightUseCaseProtocol {
    /// Delete an insight permanently
    /// - Parameter id: The UUID of the insight
    /// - Throws: Use case error if delete fails
    func execute(id: UUID) async throws
}

/// Use case for deleting an insight
final class DeleteInsightUseCase: DeleteInsightUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol
    ) {
        self.repository = repository
    }

    func execute(id: UUID) async throws {
        // Delete locally - backend sync handled by Outbox pattern
        try await repository.delete(id)
    }
}
