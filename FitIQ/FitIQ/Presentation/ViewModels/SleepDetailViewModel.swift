import Charts
import Foundation
import Observation
import SwiftUI

// MARK: - View Models for Sleep Detail

/// ViewModel for sleep detail view with real repository integration
@Observable
final class SleepDetailViewModel {

    // MARK: - Time Range

    enum TimeRange: String, CaseIterable, Identifiable {
        case daily = "Today"
        case last7Days = "7D"
        case last30Days = "30D"
        case last3Months = "3M"
        var id: String { rawValue }
    }

    // MARK: - Dependencies

    private let sleepRepository: SleepRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - State

    var historicalRecords: [SleepRecord] = []
    var isLoading: Bool = false
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var selectedRange: TimeRange = .last7Days
    var errorMessage: String?

    var averageSleepDuration: String = "N/A"
    var averageEfficiency: String = "N/A"

    // MARK: - Initialization

    init(
        sleepRepository: SleepRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.sleepRepository = sleepRepository
        self.authManager = authManager
    }

    // MARK: - Data Loading

    @MainActor
    func loadDataForSelectedRange() async {
        isLoading = true
        errorMessage = nil

        guard let userID = authManager.currentUserProfileID?.uuidString else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }

        let calendar = Calendar.current
        let now = Date()
        var startDate: Date

        // Determine the start date for filtering based on the selected range
        switch selectedRange {
        case .daily:
            startDate = calendar.startOfDay(for: selectedDate)
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        case .last30Days:
            startDate = calendar.date(
                byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
        case .last3Months:
            startDate = calendar.date(
                byAdding: .month, value: -3, to: calendar.startOfDay(for: now))!
        }

        let endDate = calendar.date(byAdding: .day, value: 1, to: now)!  // Include today

        do {
            // Fetch sleep sessions from repository
            let sessions = try await sleepRepository.fetchSessions(
                forUserID: userID,
                from: startDate,
                to: endDate,
                syncStatus: nil  // Fetch all sessions regardless of sync status
            )

            // Convert domain models to view models
            let records = sessions.map { session in
                convertToSleepRecord(session: session)
            }

            // Filter for daily view if needed
            let filteredRecords =
                selectedRange == .daily
                ? records.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
                : records

            self.historicalRecords = filteredRecords.sorted { $0.date > $1.date }
            calculateAverages(from: self.historicalRecords)

            print("SleepDetailViewModel: ✅ Loaded \(self.historicalRecords.count) sleep records")

        } catch {
            print("SleepDetailViewModel: ❌ Error loading sleep data: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            historicalRecords = []
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func convertToSleepRecord(session: SleepSession) -> SleepRecord {
        // Convert sleep stages to UI segments
        let segments: [SleepStageSegment] = (session.stages ?? []).map { stage in
            SleepStageSegment(
                stage: stage.stage.displayName,
                startTime: stage.startTime,
                endTime: stage.endTime,
                color: colorForStage(stage.stage)
            )
        }

        return SleepRecord(
            date: session.date,
            timeInBedMinutes: session.timeInBedMinutes,
            timeAsleepMinutes: session.totalSleepMinutes,
            efficiencyPercentage: Int(session.sleepEfficiency.rounded()),
            segments: segments
        )
    }

    private func colorForStage(_ stage: SleepStageType) -> Color {
        switch stage {
        case .asleepDeep:
            return .midnightIndigo
        case .asleepCore:
            return .oceanCore
        case .asleepREM:
            return .skyBlue
        case .awake:
            return .warningRed
        case .inBed:
            return Color.gray.opacity(0.3)
        case .asleep:
            return .serenityLavender
        }
    }

    private func calculateAverages(from records: [SleepRecord]) {
        guard !records.isEmpty else {
            averageSleepDuration = "N/A"
            averageEfficiency = "N/A"
            return
        }

        let totalMinutes = records.map { $0.timeAsleepMinutes }.reduce(0, +)
        let totalEfficiency = records.map { $0.efficiencyPercentage }.reduce(0, +)

        let avgMinutes = totalMinutes / records.count
        let avgHours = avgMinutes / 60
        let avgMinsRemainder = avgMinutes % 60

        averageSleepDuration = String(format: "%dhr %02dmin", avgHours, avgMinsRemainder)
        averageEfficiency = String(format: "%d%%", totalEfficiency / records.count)
    }
}

// MARK: - Supporting Types (kept for UI compatibility)

/// Sleep stage segment for visualization
struct SleepStageSegment: Identifiable {
    let id = UUID()
    let stage: String  // Display name: "Awake", "REM", "Core", "Deep"
    let startTime: Date
    let endTime: Date
    let color: Color

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
}

/// Sleep record for detail view display
struct SleepRecord: Identifiable {
    let id = UUID()
    let date: Date
    let timeInBedMinutes: Int
    let timeAsleepMinutes: Int
    let efficiencyPercentage: Int
    let segments: [SleepStageSegment]  // Sequential segments
}
