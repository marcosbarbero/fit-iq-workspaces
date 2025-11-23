//
//  SyncDebugViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 31/01/2025.
//

import Foundation
import Observation

@Observable
final class SyncDebugViewModel {

    // MARK: - State

    var syncStatus: SyncStatusSummary?
    var pendingEntries: [PendingSyncEntry] = []
    var consistencyReport: ConsistencyReport?
    var manualSyncResult: ManualSyncResult?

    var isLoading = false
    var errorMessage: String?

    // UI state
    var selectedType: ProgressMetricType = .weight
    var autoRefreshEnabled = false

    // MARK: - Dependencies

    private let verifySyncUseCase: VerifyRemoteSyncUseCase
    private var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    init(verifySyncUseCase: VerifyRemoteSyncUseCase) {
        self.verifySyncUseCase = verifySyncUseCase
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Actions

    @MainActor
    func loadSyncStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            syncStatus = try await verifySyncUseCase.getSyncStatus()
        } catch {
            errorMessage = "Failed to load sync status: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func loadPendingEntries(limit: Int? = 20) async {
        isLoading = true
        errorMessage = nil

        do {
            pendingEntries = try await verifySyncUseCase.getPendingEntries(limit: limit)
        } catch {
            errorMessage = "Failed to load pending entries: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func triggerManualSync() async {
        isLoading = true
        errorMessage = nil

        do {
            manualSyncResult = try await verifySyncUseCase.triggerManualSync()

            // Wait a moment for sync to start
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

            // Reload status to show updated counts
            await loadSyncStatus()
            await loadPendingEntries()

        } catch {
            errorMessage = "Failed to trigger sync: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func verifyConsistency(for type: ProgressMetricType? = nil) async {
        isLoading = true
        errorMessage = nil

        let typeToVerify = type ?? selectedType

        do {
            consistencyReport = try await verifySyncUseCase.verifyConsistency(
                for: typeToVerify,
                limit: 100
            )
        } catch {
            errorMessage = "Failed to verify consistency: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func refreshAll() async {
        await loadSyncStatus()
        await loadPendingEntries()
        await verifyConsistency()
    }

    @MainActor
    func toggleAutoRefresh() {
        autoRefreshEnabled.toggle()

        if autoRefreshEnabled {
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTask?.cancel()

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

                guard !Task.isCancelled else { break }

                await self?.loadSyncStatus()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Computed Properties

    var syncHealthStatus: String {
        guard let status = syncStatus else { return "Unknown" }

        if status.failedCount > 0 {
            return "⚠️ Needs Attention"
        } else if status.pendingCount > 10 {
            return "⏳ Syncing..."
        } else if status.syncPercentage > 95 {
            return "✅ Healthy"
        } else {
            return "🔄 In Progress"
        }
    }

    var consistencyStatus: String {
        guard let report = consistencyReport else { return "Not verified" }

        if report.isConsistent {
            return "✅ Consistent"
        } else if report.consistency > 90 {
            return "⚠️ Minor issues"
        } else {
            return "❌ Inconsistent"
        }
    }
}
