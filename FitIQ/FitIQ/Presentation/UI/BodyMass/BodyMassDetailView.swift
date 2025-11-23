//
//  BodyMassDetailView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Charts  // Requires the Charts framework
import Foundation
import SwiftUI

struct BodyMassDetailView: View {

    // The Detail ViewModel is observed here
    @State private var viewModel: BodyMassDetailViewModel

    // The Entry ViewModel is passed through for the 'Log Weight' action
    private let bodyMassEntryViewModel: BodyMassEntryViewModel

    // State to trigger the Mass Entry Sheet
    @State private var showingMassEntry: Bool = false

    // Callback to refresh SummaryView when a new weight is logged
    let onSaveSuccess: (Double) -> Void

    init(
        viewModel: BodyMassDetailViewModel, bodyMassEntryViewModel: BodyMassEntryViewModel,
        onSaveSuccess: @escaping (Double) -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.bodyMassEntryViewModel = bodyMassEntryViewModel
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Show full-screen empty state when no data
            if !viewModel.isLoading && viewModel.errorMessage == nil
                && viewModel.currentWeight == nil
            {
                EmptyWeightStateView(showingMassEntry: $showingMassEntry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {

                        // MARK: - Current Stats and Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Weight")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            // Use the current weight (independent of filter)
                            if let currentWeight = viewModel.currentWeight {
                                Text(String(format: "%.1f kg", currentWeight))
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            } else {
                                Text("-- kg")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            // Simple trend indicator based on actual data
                            if let trend = viewModel.weightTrend {
                                Text(trend.displayText)
                                    .font(.subheadline)
                                    .foregroundColor(
                                        trend.isPositive ? Color.attentionOrange : Color.growthGreen
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        // MARK: - Time Range Picker
                        TimeRangePickerView(selectedRange: $viewModel.selectedRange)
                            .padding(.horizontal)
                            // Trigger data load when the range changes
                            .onChange(of: viewModel.selectedRange) {
                                Task { await viewModel.loadHistoricalData() }
                            }

                        // MARK: - Weight Chart
                        if viewModel.isLoading {
                            LoadingChartView()
                                .frame(height: 300)
                                .frame(maxWidth: .infinity)
                        } else if let errorMessage = viewModel.errorMessage {
                            ErrorStateView(errorMessage: errorMessage) {
                                Task { await viewModel.loadHistoricalData() }
                            }
                            .frame(height: 300)
                            .padding(.horizontal)
                        } else if viewModel.historicalData.isEmpty {
                            EmptyWeightStateView(showingMassEntry: $showingMassEntry)
                                .frame(height: 300)
                                .padding(.horizontal)
                        } else {
                            // Chart Visualization (requires Charts framework)
                            WeightChartView(data: viewModel.historicalData)
                                .id(viewModel.selectedRange)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // MARK: - Insights & Data Table (Only show when there's data)
                        if !viewModel.historicalData.isEmpty {
                            Divider().padding(.horizontal)

                            Text("Historical Entries")
                                .font(.headline)
                                .padding(.horizontal)

                            // Simple table of recent entries
                            ForEach(viewModel.historicalData.suffix(5).reversed()) { record in
                                HStack {
                                    Text(record.date.formatted(.dateTime.day().month().year()))
                                    Spacer()
                                    Text(String(format: "%.1f kg", record.weightKg))
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                            }
                        }

                    }
                    .padding(.bottom, 100)  // Space for the FAB
                }
            }

            // MARK: - Floating Action Button (FAB) - Only show when there's data
            if viewModel.currentWeight != nil {
                LogWeightFAB(showingMassEntry: $showingMassEntry)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle("Body Mass Tracking")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadHistoricalData()
        }
        .onAppear {
            Task { await viewModel.loadHistoricalData() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task {
                            await viewModel.diagnoseHealthKitAccess()
                        }
                    } label: {
                        Label("HealthKit Diagnostic", systemImage: "heart.fill")
                    }

                    Button {
                        Task {
                            await viewModel.diagnoseLocalStorage()
                        }
                    } label: {
                        Label("Local Storage Diagnostic", systemImage: "externaldrive.fill")
                    }

                    Divider()

                    Button {
                        Task {
                            await viewModel.forceHealthKitResync(clearExisting: false)
                        }
                    } label: {
                        Label("Force Re-sync (Keep Existing)", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        Task {
                            await viewModel.forceHealthKitResync(clearExisting: true)
                        }
                    } label: {
                        Label(
                            "Force Re-sync (Clear All)", systemImage: "arrow.clockwise.circle.fill")
                    }
                } label: {
                    Image(systemName: "stethoscope")
                        .foregroundColor(.ascendBlue)
                }
            }
        }
        // Sheet for the actual weight entry
        .sheet(isPresented: $showingMassEntry) {
            BodyMassEntryView(
                viewModel: bodyMassEntryViewModel,
                onSaveSuccess: { savedWeight in
                    // 1. Tell parent SummaryView to refresh
                    onSaveSuccess(savedWeight)
                    // 2. Tell DetailView to refresh its chart data
                    Task { await viewModel.loadHistoricalData() }
                }
            )
        }
        .overlay {
            if viewModel.isResyncing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Re-syncing from HealthKit...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 20)
                }
            }
        }
        .alert("Re-sync Successful", isPresented: .constant(viewModel.resyncSuccessMessage != nil))
        {
            Button("OK") {
                viewModel.resyncSuccessMessage = nil
            }
        } message: {
            if let message = viewModel.resyncSuccessMessage {
                Text(message)
            }
        }
        .alert(
            "Error", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.isLoading)
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

}

// MARK: - Component Views for BodyMassDetailView

// Time Range Picker Component (Toggles)
struct TimeRangePickerView: View {
    @Binding var selectedRange: BodyMassDetailViewModel.TimeRange

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BodyMassDetailViewModel.TimeRange.allCases) { range in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedRange = range
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedRange == range ? .semibold : .medium)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .foregroundColor(selectedRange == range ? .white : .primary)
                            .background {
                                if selectedRange == range {
                                    Capsule()
                                        .fill(Color.ascendBlue)
                                        .shadow(
                                            color: Color.ascendBlue.opacity(0.25), radius: 8, x: 0,
                                            y: 4)
                                } else {
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// Weight Chart Component - Beautiful linear graph with Ascend Blue styling
struct WeightChartView: View {
    let data: [WeightRecord]

    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else { return 0...100 }

        let weights = data.map { $0.weightKg }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100

        // Add padding to the range for better visualization (5% on each side)
        let range = maxWeight - minWeight
        let padding = max(range * 0.15, 2.0)  // At least 2kg padding

        print("WeightChartView: === CHART DATA DEBUG ===")
        print("WeightChartView: Total data points: \(data.count)")
        print("WeightChartView: Weight range: \(minWeight) kg to \(maxWeight) kg")
        print("WeightChartView: Variation: \(range) kg")
        print("WeightChartView: Y-axis domain: \(minWeight - padding) to \(maxWeight + padding)")
        if data.count <= 10 {
            print("WeightChartView: All data points:")
            for (index, record) in data.enumerated() {
                print(
                    "  \(index + 1). Date: \(record.date.formatted(date: .abbreviated, time: .omitted)), Weight: \(record.weightKg) kg"
                )
            }
        }

        return (minWeight - padding)...(maxWeight + padding)
    }

    var body: some View {
        Chart(data) { record in
            // Clean line mark
            LineMark(
                x: .value("Date", record.date),
                y: .value("Weight", record.weightKg)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(Color.ascendBlue)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Data point markers
            PointMark(
                x: .value("Date", record.date),
                y: .value("Weight", record.weightKg)
            )
            .foregroundStyle(Color.ascendBlue)
            .symbolSize(50)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYScale(domain: yAxisDomain)
        .frame(height: 300)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Loading State Component
struct LoadingChartView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.ascendBlue)

            Text("Loading your weight data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .opacity(isAnimating ? 0.5 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Error State Component
struct ErrorStateView: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.attentionOrange)

            Text("Unable to Load Data")
                .font(.headline)
                .foregroundColor(.primary)

            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.ascendBlue)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Empty State Component
struct EmptyWeightStateView: View {
    @Binding var showingMassEntry: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 50))
                .foregroundColor(Color.ascendBlue.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Weight Data Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Start tracking your weight to see your progress over time")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: { showingMassEntry = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Weight")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.ascendBlue, Color.ascendBlue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.ascendBlue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding()
    }
}

// Floating Action Button Component
struct LogWeightFAB: View {
    @Binding var showingMassEntry: Bool

    var body: some View {
        Button {
            showingMassEntry = true
        } label: {
            // 💡 UX Change: Icon-only, circular design for classic FAB look
            Image(systemName: "plus")
                .font(.title2)  // Slightly larger icon size
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(20)  // Generous padding for a clear circle
                .background(Color.ascendBlue)  // Core data/entry color
                .clipShape(Circle())  // Apply circular shape
                // Use a subtle, modern shadow
                .shadow(color: Color.ascendBlue.opacity(0.5), radius: 15, x: 0, y: 5)
        }
    }
}
