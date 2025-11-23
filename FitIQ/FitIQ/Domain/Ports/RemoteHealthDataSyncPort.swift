// RemoteHealthDataSyncPort.swift
import Foundation

protocol RemoteHealthDataSyncPort {
    /// Uploads body mass data to the remote service.
    /// - Parameters:
    ///   - kg: The body mass in kilograms.
    ///   - date: The date of the measurement.
    ///   - userProfileID: The ID of the user.
    ///   - localID: The local UUID of the physical attribute (optional, for tracking).
    /// - Returns: The backend ID of the uploaded record, or `nil` if not applicable/provided.
    func uploadBodyMass(kg: Double, date: Date, for userProfileID: UUID, localID: UUID?) async throws -> String?

    /// Uploads height data to the remote service.
    /// - Parameters:
    ///   - cm: The height in centimeters.
    ///   - date: The date of the measurement.
    ///   - userProfileID: The ID of the user.
    ///   - localID: The local UUID of the physical attribute (optional, for tracking).
    /// - Returns: The backend ID of the uploaded record, or `nil` if not applicable/provided.
    func uploadHeight(cm: Double, date: Date, for userProfileID: UUID, localID: UUID?) async throws -> String?

    /// Uploads body fat percentage data to the remote service.
    /// - Parameters:
    ///   - percentage: The body fat percentage (e.g., 18.5 for 18.5%).
    ///   - date: The date of the measurement.
    ///   - userProfileID: The ID of the user.
    ///   - localID: The local UUID of the physical attribute (optional, for tracking).
    /// - Returns: The backend ID of the uploaded record, or `nil` if not applicable/provided.
    func uploadBodyFatPercentage(percentage: Double, date: Date, for userProfileID: UUID, localID: UUID?) async throws -> String?

    /// Uploads BMI data to the remote service.
    /// - Parameters:
    ///   - bmi: The Body Mass Index value.
    ///   - date: The date of the measurement.
    ///   - userProfileID: The ID of the user.
    ///   - localID: The local UUID of the physical attribute (optional, for tracking).
    /// - Returns: The backend ID of the uploaded record, or `nil` if not applicable/provided.
    func uploadBMI(bmi: Double, date: Date, for userProfileID: UUID, localID: UUID?) async throws -> String?
        
    /// Uploads an activity snapshot to the remote service.
    /// - Parameters:
    ///   - snapshot: The `ActivitySnapshot` to upload.
    ///   - userProfileID: The ID of the user.
    /// - Returns: The backend ID of the uploaded record, or `nil` if not applicable/provided.
    func uploadActivitySnapshot(snapshot: ActivitySnapshot, for userProfileID: UUID) async throws -> String?

    /// Fetches a history of body metric snapshots for a user.
    /// - Parameters:
    ///   - userID: The ID of the user.
    ///   - startDate: Optional. Filters metrics recorded on or after this date.
    ///   - endDate: Optional. Filters metrics recorded on or before this date.
    ///   - limit: Optional. Maximum number of records to return.
    /// - Returns: An array of `BodyMetricResponse` DTOs.
    func fetchBodyMetrics(
        forUserID userID: UUID,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [BodyMetricResponse]
}
