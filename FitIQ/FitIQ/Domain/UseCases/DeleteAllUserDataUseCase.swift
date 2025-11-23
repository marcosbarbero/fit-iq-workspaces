//
//  DeleteAllUserDataUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import SwiftData

/// Protocol defining the contract for deleting all user data
protocol DeleteAllUserDataUseCase {
    /// Deletes all user data from backend and local storage
    /// - Throws: Error if deletion fails
    func execute() async throws
}

/// Implementation of DeleteAllUserDataUseCase
/// Deletes all user data from backend via /api/v1/users/me endpoint
/// Also clears local storage to ensure complete data removal
final class DeleteAllUserDataUseCaseImpl: DeleteAllUserDataUseCase {

    // MARK: - Dependencies

    private let networkClient: NetworkClientProtocol
    private let authManager: AuthManager
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let modelContainer: ModelContainer
    private let baseURL: String
    private let apiKey: String

    // MARK: - Initialization

    init(
        networkClient: NetworkClientProtocol,
        authManager: AuthManager,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        modelContainer: ModelContainer
    ) {
        self.networkClient = networkClient
        self.authManager = authManager
        self.authTokenPersistence = authTokenPersistence
        self.modelContainer = modelContainer
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
    }

    // MARK: - Execute

    func execute() async throws {
        print("DeleteAllUserDataUseCase: Starting deletion of all user data")

        // 1. Verify user is authenticated
        guard let userID = authManager.currentUserProfileID else {
            throw DeleteAllUserDataError.userNotAuthenticated
        }

        guard let authToken = try? authTokenPersistence.fetchAccessToken() else {
            throw DeleteAllUserDataError.authTokenNotFound
        }

        print("DeleteAllUserDataUseCase: Deleting data for user \(userID)")

        // 2. Call backend DELETE /api/v1/users/me
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw DeleteAllUserDataError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DeleteAllUserDataError.invalidResponse
            }

            print("DeleteAllUserDataUseCase: Backend DELETE response: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to parse error message
                if let errorResponse = try? JSONDecoder().decode(
                    BackendErrorResponse.self, from: data)
                {
                    throw DeleteAllUserDataError.backendError(errorResponse.message)
                }
                throw DeleteAllUserDataError.httpError(httpResponse.statusCode)
            }

            print("DeleteAllUserDataUseCase: ✅ Backend data deleted successfully")

        } catch let error as DeleteAllUserDataError {
            throw error
        } catch {
            print(
                "DeleteAllUserDataUseCase: ❌ Backend deletion failed: \(error.localizedDescription)"
            )
            throw DeleteAllUserDataError.networkError(error)
        }

        // 3. Clear all local SwiftData
        print("DeleteAllUserDataUseCase: Clearing all local SwiftData")
        do {
            try await clearAllLocalData()
            print("DeleteAllUserDataUseCase: ✅ Local data cleared successfully")
        } catch {
            print(
                "DeleteAllUserDataUseCase: ⚠️ Failed to clear local data: \(error.localizedDescription)"
            )
            // Don't throw - backend data is deleted, which is most important
        }

        // 4. Clear auth token
        print("DeleteAllUserDataUseCase: Clearing auth tokens")
        do {
            try authTokenPersistence.deleteTokens()
            print("DeleteAllUserDataUseCase: ✅ Auth tokens cleared")
        } catch {
            print(
                "DeleteAllUserDataUseCase: ⚠️ Failed to clear auth tokens: \(error.localizedDescription)"
            )
        }

        print("DeleteAllUserDataUseCase: ✅ All user data deletion complete")
    }

    // MARK: - Private Helpers

    @MainActor
    private func clearAllLocalData() async throws {
        let context = ModelContext(modelContainer)

        // Manual fetch-and-delete approach to avoid SwiftData relationship issues
        // The issue is that SDUserProfile has a one-to-one relationship (dietaryAndActivityPreferences)
        // which causes "Expected only Arrays for Relationships" crash

        print("DeleteAllUserDataUseCase: Starting manual deletion of all entities")

        // Delete all outbox events
        do {
            let descriptor = FetchDescriptor<SDOutboxEvent>()
            let events = try context.fetch(descriptor)
            for event in events {
                context.delete(event)
            }
            print("DeleteAllUserDataUseCase: Deleted \(events.count) SDOutboxEvent records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDOutboxEvent: \(error)")
        }

        // Delete all sleep stages first (deepest child)
        do {
            let descriptor = FetchDescriptor<SDSleepStage>()
            let stages = try context.fetch(descriptor)
            for stage in stages {
                context.delete(stage)
            }
            print("DeleteAllUserDataUseCase: Deleted \(stages.count) SDSleepStage records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDSleepStage: \(error)")
        }

        // Delete all sleep sessions
        do {
            let descriptor = FetchDescriptor<SDSleepSession>()
            let sessions = try context.fetch(descriptor)

            // Break relationship to SDUserProfile before deleting
            for session in sessions {
                session.userProfile = nil
            }

            // Now delete the sessions
            for session in sessions {
                context.delete(session)
            }
            print("DeleteAllUserDataUseCase: Deleted \(sessions.count) SDSleepSession records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDSleepSession: \(error)")
        }

        // Delete all progress entries
        do {
            let descriptor = FetchDescriptor<SDProgressEntry>()
            let entries = try context.fetch(descriptor)

            // Break relationship to SDUserProfile before deleting
            for entry in entries {
                entry.userProfile = nil
            }

            // Now delete the entries
            for entry in entries {
                context.delete(entry)
            }
            print("DeleteAllUserDataUseCase: Deleted \(entries.count) SDProgressEntry records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDProgressEntry: \(error)")
        }

        // Delete all activity snapshots
        do {
            let descriptor = FetchDescriptor<SDActivitySnapshot>()
            let snapshots = try context.fetch(descriptor)

            // Break relationship to SDUserProfile before deleting
            for snapshot in snapshots {
                snapshot.userProfile = nil
            }

            // Now delete the snapshots
            for snapshot in snapshots {
                context.delete(snapshot)
            }
            print("DeleteAllUserDataUseCase: Deleted \(snapshots.count) SDActivitySnapshot records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDActivitySnapshot: \(error)")
        }

        // Delete all physical attributes
        do {
            let descriptor = FetchDescriptor<SDPhysicalAttribute>()
            let attributes = try context.fetch(descriptor)

            // Break relationship to SDUserProfile before deleting
            for attribute in attributes {
                attribute.userProfile = nil
            }

            // Now delete the attributes
            for attribute in attributes {
                context.delete(attribute)
            }
            print(
                "DeleteAllUserDataUseCase: Deleted \(attributes.count) SDPhysicalAttribute records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDPhysicalAttribute: \(error)")
        }

        // Delete dietary and activity preferences (one-to-one relationship)
        do {
            let descriptor = FetchDescriptor<SDDietaryAndActivityPreferences>()
            let preferences = try context.fetch(descriptor)

            // Break relationship to SDUserProfile before deleting
            for pref in preferences {
                pref.userProfile = nil
            }

            // Now delete the preferences
            for pref in preferences {
                context.delete(pref)
            }
            print(
                "DeleteAllUserDataUseCase: Deleted \(preferences.count) SDDietaryAndActivityPreferences records"
            )
        } catch {
            print(
                "DeleteAllUserDataUseCase: Error deleting SDDietaryAndActivityPreferences: \(error)"
            )
        }

        // Finally, delete all user profiles (parent entity)
        do {
            let descriptor = FetchDescriptor<SDUserProfile>()
            let profiles = try context.fetch(descriptor)
            for profile in profiles {
                context.delete(profile)
            }
            print("DeleteAllUserDataUseCase: Deleted \(profiles.count) SDUserProfile records")
        } catch {
            print("DeleteAllUserDataUseCase: Error deleting SDUserProfile: \(error)")
        }

        // Save context to persist all deletions
        try context.save()
        print("DeleteAllUserDataUseCase: All local data cleared and saved")
    }
}

// MARK: - Errors

enum DeleteAllUserDataError: Error, LocalizedError {
    case userNotAuthenticated
    case authTokenNotFound
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case backendError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to delete data"
        case .authTokenNotFound:
            return "Authentication token not found"
        case .invalidURL:
            return "Invalid backend URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: HTTP \(code)"
        case .backendError(let message):
            return "Backend error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response DTOs

private struct BackendErrorResponse: Decodable {
    let message: String
    let error: String?
}
