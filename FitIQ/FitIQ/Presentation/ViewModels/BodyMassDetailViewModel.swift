//
//  BodyMassDetailViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//  Updated by AI Assistant on 27/01/2025.
//  Migrated to FitIQCore on 2025-01-27 - Phase 5
//

import Combine
import FitIQCore
import Foundation
import HealthKit
import Observation

// Weight record structure for UI display
struct WeightRecord: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

// Weight trend information
struct WeightTrend {
    let changeKg: Double
    let periodDays: Int
    let isPositive: Bool  // true = gained weight, false = lost weight

    var displayText: String {
        let sign = isPositive ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(changeKg))) kg in \(periodDays) days"
    }
}

@Observable
final class BodyMassDetailViewModel {

    // MARK: - Dependencies

    private let getHistoricalWeightUseCase: GetHistoricalWeightUseCase
    private let authManager: AuthManager
    private let healthKitService: HealthKitServiceProtocol
    private let forceHealthKitResyncUseCase: ForceHealthKitResyncUseCase?

    // MARK: - Time Range

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7d"
        case month = "30d"
        case quarter = "90d"
        case year = "1y"
        case all = "All"

        var id: String { rawValue }
    }

    // MARK: - State

    var historicalData: [WeightRecord] = []
    var currentWeight: Double?  // Latest weight independent of filter
    var isLoading: Bool = false
    var selectedRange: TimeRange = .month
    var errorMessage: String?
    var weightTrend: WeightTrend?
    var isResyncing: Bool = false
    var resyncSuccessMessage: String?

    // MARK: - Initialization

    init(
        getHistoricalWeightUseCase: GetHistoricalWeightUseCase,
        authManager: AuthManager,
        healthKitService: HealthKitServiceProtocol,
        forceHealthKitResyncUseCase: ForceHealthKitResyncUseCase? = nil
    ) {
        self.getHistoricalWeightUseCase = getHistoricalWeightUseCase
        self.authManager = authManager
        self.healthKitService = healthKitService
        self.forceHealthKitResyncUseCase = forceHealthKitResyncUseCase
    }

    // MARK: - Public Methods

    @MainActor
    func loadHistoricalData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Calculate date range based on selected range
            let endDate = Date()
            let startDate = calculateStartDate(for: selectedRange, from: endDate)

            print("BodyMassDetailViewModel: ===== LOADING DATA FOR FILTER =====")
            print("BodyMassDetailViewModel: Selected filter: \(selectedRange.rawValue)")
            print("BodyMassDetailViewModel: Start date: \(startDate.formatted())")
            print("BodyMassDetailViewModel: End date: \(endDate.formatted())")

            let calendar = Calendar.current
            let daysDifference =
                calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            print("BodyMassDetailViewModel: Date range spans \(daysDifference) days")

            // Fetch historical weight for the selected range
            let entries = try await getHistoricalWeightUseCase.execute(
                startDate: startDate,
                endDate: endDate
            )

            print("BodyMassDetailViewModel: Received \(entries.count) entries from use case")

            // DEBUG: Print first 5 entries to see actual values
            print("BodyMassDetailViewModel: === DEBUG: First entries ===")
            for (index, entry) in entries.prefix(5).enumerated() {
                print("  Entry \(index + 1): Date=\(entry.date), Quantity=\(entry.quantity) kg")
            }
            if entries.count > 5 {
                print("  ... and \(entries.count - 5) more entries")
            }

            // Convert to WeightRecord for UI
            historicalData = entries.map { entry in
                WeightRecord(
                    date: entry.date,
                    weightKg: entry.quantity
                )
            }

            // DEBUG: Print converted data
            print("BodyMassDetailViewModel: === DEBUG: Converted to UI records ===")
            for (index, record) in historicalData.prefix(5).enumerated() {
                print("  Record \(index + 1): Date=\(record.date), Weight=\(record.weightKg) kg")
            }

            print("BodyMassDetailViewModel: ===== FILTER RESULTS =====")
            print("BodyMassDetailViewModel: Total records loaded: \(historicalData.count)")

            if !historicalData.isEmpty {
                let firstDate = historicalData.first?.date.formatted() ?? "N/A"
                let lastDate = historicalData.last?.date.formatted() ?? "N/A"
                print("BodyMassDetailViewModel: Date range in data: \(firstDate) to \(lastDate)")

                // Check if data is actually filtered
                let allInRange = historicalData.allSatisfy { record in
                    record.date >= startDate && record.date <= endDate
                }
                print(
                    "BodyMassDetailViewModel: All data within filter range: \(allInRange ? "✅ YES" : "❌ NO")"
                )
            } else {
                print("BodyMassDetailViewModel: ⚠️ No data returned for this filter")
            }
            print("BodyMassDetailViewModel: =====================================")

            // Fetch current weight separately (not filtered by date range)
            await loadCurrentWeight()

            // Calculate trend if we have enough data
            calculateWeightTrend()

        } catch {
            errorMessage = error.localizedDescription
            print(
                "BodyMassDetailViewModel: Failed to load weight data: \(error.localizedDescription)"
            )
        }

        isLoading = false
    }

    @MainActor
    private func loadCurrentWeight() async {
        do {
            // Fetch all-time data to get the absolute latest weight
            let allTimeStart =
                Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            let allTimeEntries = try await getHistoricalWeightUseCase.execute(
                startDate: allTimeStart,
                endDate: Date()
            )

            // Get the latest entry (sorted newest first)
            currentWeight = allTimeEntries.first?.quantity

            print(
                "BodyMassDetailViewModel: Current weight (latest ever): \(currentWeight.map { String(format: "%.1f", $0) } ?? "N/A") kg"
            )
        } catch {
            print(
                "BodyMassDetailViewModel: Failed to load current weight: \(error.localizedDescription)"
            )
            // Fallback to historical data if available
            currentWeight = historicalData.last?.weightKg
        }
    }

    @MainActor
    func onRangeChanged(_ newRange: TimeRange) {
        selectedRange = newRange
        Task {
            await loadHistoricalData()
        }
    }

    // MARK: - Private Helpers

    private func calculateStartDate(for range: TimeRange, from endDate: Date) -> Date {
        let calendar = Calendar.current

        let startDate: Date
        switch range {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        case .quarter:
            startDate = calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            // Go back 5 years for "all"
            startDate = calendar.date(byAdding: .year, value: -5, to: endDate) ?? endDate
        }

        print(
            "BodyMassDetailViewModel: calculateStartDate(\(range.rawValue)) = \(startDate.formatted())"
        )
        return startDate
    }

    private func calculateWeightTrend() {
        // Need at least 2 data points to calculate a trend
        guard historicalData.count >= 2,
            let firstWeight = historicalData.first?.weightKg,
            let lastWeight = historicalData.last?.weightKg,
            let firstDate = historicalData.first?.date,
            let lastDate = historicalData.last?.date
        else {
            weightTrend = nil
            return
        }

        // Calculate the weight change and time period
        let changeKg = lastWeight - firstWeight
        let daysDifference =
            Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0

        // Only show trend if there's a meaningful time period (at least 1 day)
        guard daysDifference > 0 else {
            weightTrend = nil
            return
        }

        weightTrend = WeightTrend(
            changeKg: changeKg,
            periodDays: daysDifference,
            isPositive: changeKg > 0
        )
    }

    // MARK: - Diagnostics

    @MainActor
    func diagnoseHealthKitAccess() async {
        print("\n" + String(repeating: "=", count: 60))
        print("HEALTHKIT DIAGNOSTIC - START")
        print(String(repeating: "=", count: 60))

        // Check HealthKit availability
        let isAvailable = HKHealthStore.isHealthDataAvailable()
        print("HealthKit Available: \(isAvailable ? "✅ YES" : "❌ NO")")

        if !isAvailable {
            print("❌ CRITICAL: HealthKit is not available on this device!")
            print(String(repeating: "=", count: 60) + "\n")
            return
        }

        // Check authorization status
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let healthStore = HKHealthStore()
        let authStatus = healthStore.authorizationStatus(for: weightType)

        print("Weight Authorization Status: ", terminator: "")
        switch authStatus {
        case .notDetermined:
            print("⚠️ NOT DETERMINED - Need to request permission")
        case .sharingDenied:
            print("❌ DENIED - User denied permission")
        case .sharingAuthorized:
            print("✅ AUTHORIZED - Permission granted")
        @unknown default:
            print("⚠️ UNKNOWN")
        }

        // Try to fetch weight samples
        do {
            print("Fetching weight samples from HealthKit directly...")
            let startDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()

            print("\nFetching weight samples from last 10 years...")
            let options = HealthQueryOptions(
                limit: nil,
                sortOrder: .ascending,
                aggregation: .none
            )

            let metrics = try await healthKitService.query(
                type: .bodyMass,
                from: startDate,
                to: Date(),
                options: options
            )

            let samples = metrics.map { ($0.value, $0.date) }

            print("✅ Fetch successful!")
            print("Total samples found: \(samples.count)")

            if samples.isEmpty {
                print("⚠️ WARNING: No weight samples found in HealthKit!")
                print("Please check Apple Health app for weight entries.")
            } else {
                let dates = samples.map { $0.1 }
                if let latest = dates.max() {
                    print("Latest entry: \(latest)")
                }
                if let oldest = dates.min() {
                    print("Oldest entry: \(oldest)")
                }

                // Show first 5 samples
                print("\nFirst 5 samples:")
                for (index, sample) in samples.prefix(5).enumerated() {
                    print("  \(index + 1). \(sample.1): \(sample.0) kg")
                }
            }

        } catch {
            print("❌ FETCH FAILED!")
            print("Error: \(error.localizedDescription)")
            print("Error type: \(type(of: error))")
        }

        print(String(repeating: "=", count: 60))
        print("HEALTHKIT DIAGNOSTIC - END")
        print(String(repeating: "=", count: 60) + "\n")
    }

    // MARK: - Local Storage Diagnostic

    @MainActor
    func diagnoseLocalStorage() async {
        print("\n" + String(repeating: "=", count: 60))
        print("LOCAL STORAGE DIAGNOSTIC - START")
        print(String(repeating: "=", count: 60))

        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("❌ No user ID available")
            print(String(repeating: "=", count: 60) + "\n")
            return
        }

        print("User ID: \(userID)")

        do {
            // Fetch ALL local weight entries (no filters)
            let allEntries = try await getHistoricalWeightUseCase.execute(
                startDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                endDate: Date()
            )

            print("\n📊 RESULTS:")
            print("Total weight entries found: \(allEntries.count)")

            if allEntries.isEmpty {
                print("\n⚠️ WARNING: No weight data found in local storage!")
                print("\nPossible causes:")
                print("  1. Initial sync never ran")
                print("  2. HealthKit has no weight data")
                print("  3. HealthKit permission denied")
                print("  4. Data fetch is failing")
            } else {
                // Show date range
                let dates = allEntries.map { $0.date }
                if let oldest = dates.min(), let newest = dates.max() {
                    print("\n📅 Date Range:")
                    print("  Oldest: \(oldest)")
                    print("  Newest: \(newest)")

                    let daysDifference =
                        Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
                    print("  Span: \(daysDifference) days")
                }

                // Show sync status breakdown
                let pending = allEntries.filter { $0.syncStatus == .pending }.count
                let syncing = allEntries.filter { $0.syncStatus == .syncing }.count
                let synced = allEntries.filter { $0.syncStatus == .synced }.count
                let failed = allEntries.filter { $0.syncStatus == .failed }.count

                print("\n🔄 Sync Status:")
                print("  Pending: \(pending)")
                print("  Syncing: \(syncing)")
                print("  Synced: \(synced)")
                print("  Failed: \(failed)")

                // Show first 5 and last 5 entries
                print("\n📝 First 5 Entries:")
                for (index, entry) in allEntries.prefix(5).enumerated() {
                    print(
                        "  \(index + 1). \(entry.date): \(String(format: "%.1f", entry.quantity)) kg - Status: \(entry.syncStatus.rawValue)"
                    )
                }

                if allEntries.count > 5 {
                    print("\n📝 Last 5 Entries:")
                    for (index, entry) in allEntries.suffix(5).enumerated() {
                        print(
                            "  \(allEntries.count - 4 + index). \(entry.date): \(String(format: "%.1f", entry.quantity)) kg - Status: \(entry.syncStatus.rawValue)"
                        )
                    }
                }

                // Check if backend is empty but local has data
                if synced == 0 && allEntries.count > 0 {
                    print("\n⚠️ WARNING: Local data exists but NOTHING synced to backend!")
                    print("  This explains why server has no data.")
                    print("  Possible causes:")
                    print("    - Background sync not running")
                    print("    - Network issues")
                    print("    - Backend API errors")
                    print("    - Authentication issues")
                }
            }

        } catch {
            print("\n❌ ERROR fetching local storage:")
            print("  \(error.localizedDescription)")
        }

        print(String(repeating: "=", count: 60))
        print("LOCAL STORAGE DIAGNOSTIC - END")
        print(String(repeating: "=", count: 60) + "\n")
    }

    // MARK: - Force Re-sync

    @MainActor
    func forceHealthKitResync(clearExisting: Bool = false) async {
        guard let forceResyncUseCase = forceHealthKitResyncUseCase else {
            errorMessage = "Re-sync feature not available (use case not configured)"
            print("❌ ForceHealthKitResyncUseCase not configured in dependencies")
            return
        }

        isResyncing = true
        errorMessage = nil
        resyncSuccessMessage = nil

        do {
            print("\n🔄 Starting force re-sync from UI...")
            print("Clear existing: \(clearExisting)")

            try await forceResyncUseCase.execute(clearExisting: clearExisting)

            resyncSuccessMessage = "Successfully re-synced weight data from HealthKit"
            print("✅ Force re-sync completed successfully")

            // Reload data to show new entries
            await loadHistoricalData()

        } catch {
            errorMessage = "Re-sync failed: \(error.localizedDescription)"
            print("❌ Force re-sync failed: \(error.localizedDescription)")
        }

        isResyncing = false
    }

    // MARK: - UUID Mismatch Diagnostic

    @MainActor
    func diagnoseUUIDMismatch() async {
        print("\n" + String(repeating: "=", count: 60))
        print("UUID MISMATCH DIAGNOSTIC - START")
        print(String(repeating: "=", count: 60))

        guard let authUserID = authManager.currentUserProfileID else {
            print("❌ No authenticated user ID in AuthManager")
            print(String(repeating: "=", count: 60) + "\n")
            return
        }

        print("Auth Manager User ID: \(authUserID)")

        // Try to fetch profile with auth ID
        do {
            let profileStorage = await getProfileStorage()
            let profile = try await profileStorage?.fetch(forUserID: authUserID)

            if let profile = profile {
                print("✅ Profile found with auth ID")
                print("  Profile ID: \(profile.id)")
                print("  Name: '\(profile.name)'")
                print("  Auth ID matches: \(profile.id == authUserID ? "YES" : "NO")")
            } else {
                print("❌ No profile found with auth ID: \(authUserID)")
                print("\n⚠️ UUID MISMATCH DETECTED!")
                print("This means the user ID in keychain doesn't match any profile in database.")
                print("\nRECOMMENDATION:")
                print("1. Log out and log back in to reset the user ID")
                print("2. Or manually update keychain with correct profile ID")
            }
        } catch {
            print("❌ Error fetching profile: \(error.localizedDescription)")
        }

        print(String(repeating: "=", count: 60))
        print("UUID MISMATCH DIAGNOSTIC - END")
        print(String(repeating: "=", count: 60) + "\n")
    }

    private func getProfileStorage() async -> UserProfileStoragePortProtocol? {
        // This is a workaround to access profile storage from ViewModel
        // In production, this should be passed as a dependency
        // For now, returning nil as we don't have access to it
        print("⚠️ Profile storage not available from ViewModel")
        print("⚠️ Need to add userProfileStorage as dependency to BodyMassDetailViewModel")
        return nil
    }
}
