//
//  MoodDetailView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

// YourAppRoot/Presentation/UI/MoodDetailView.swift

import Charts
import SwiftUI

struct MoodDetailView: View {

    @State private var viewModel: MoodDetailViewModel

    // Dependency for the actual logging sheet
    private let moodEntryViewModel: MoodEntryViewModel

    // State to trigger the Mood Entry Sheet (using the existing sheet view)
    @State private var showingMoodEntry: Bool = false

    // Callback to refresh SummaryView when a new mood is logged
    private let onSaveSuccess: () -> Void

    // Serenity Lavender for Wellness/Mood theme
    private let primaryColor = Color.serenityLavender

    // MARK: - Initializer

    init(
        viewModel: MoodDetailViewModel, moodEntryViewModel: MoodEntryViewModel,
        onSaveSuccess: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.moodEntryViewModel = moodEntryViewModel
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {

                    // MARK: - Current Stats and Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average Mood Score")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        let averageScore =
                            viewModel.historicalData.isEmpty
                            ? 0.0
                            : viewModel.historicalData.map { Double($0.score) }.reduce(0, +)
                                / Double(viewModel.historicalData.count)

                        Text(String(format: "%.1f / 10", averageScore))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(viewModel.moodTrend)
                            .font(.subheadline)
                            .foregroundColor(primaryColor)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    // MARK: - Time Range Picker
                    MoodTimeRangePickerView(selectedRange: $viewModel.selectedRange)
                        .padding(.horizontal)
                        .onChange(of: viewModel.selectedRange) {
                            Task { await viewModel.loadHistoricalData() }
                        }

                    // MARK: - Mood Chart
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                    } else if viewModel.historicalData.isEmpty {
                        ContentUnavailableView(
                            "No Mood Data", systemImage: "face.smiling",
                            description: Text(
                                "Log your first daily check-in to view your mood trends.")
                        )
                        .frame(height: 300)
                    } else {
                        MoodChartView(data: viewModel.historicalData, color: primaryColor)
                    }

                    // MARK: - Recent Entries
                    Divider().padding(.horizontal)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("All Check-Ins in \(viewModel.selectedRange.rawValue)")
                            .font(.headline)
                            .padding(.horizontal)

                        // Use the new MoodLogEntryRow to display interactive entries
                        // We iterate over the entire filtered dataset (already sorted by date in ViewModel)
                        ForEach(viewModel.historicalData.reversed()) { record in
                            // This row now handles displaying notes and showing time
                            MoodLogEntryRow(record: record, color: primaryColor)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 100)  // Space for the FAB
            }
            .navigationTitle("Mood History")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task { await viewModel.loadHistoricalData() }
            }

            // MARK: - Floating Action Button (FAB)
            LogMoodFAB(showingMoodEntry: $showingMoodEntry, color: primaryColor)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        // Sheet for the actual mood entry (using the existing MoodEntryView)
        .sheet(isPresented: $showingMoodEntry) {
            MoodEntryView(
                viewModel: moodEntryViewModel
            )
            .onDisappear {
                // Always refresh when sheet dismisses (user may have saved)
                onSaveSuccess()

                // Refresh DetailView chart data
                Task {
                    await viewModel.loadHistoricalData()
                }
            }
        }
    }

}

// MARK: - Component Views for MoodDetailView

struct MoodTimeRangePickerView: View {
    @Binding var selectedRange: MoodDetailViewModel.TimeRange
    private let primaryColor = Color.serenityLavender

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MoodDetailViewModel.TimeRange.allCases) { range in
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
                                        .fill(primaryColor)
                                        .shadow(
                                            color: primaryColor.opacity(0.25), radius: 8, x: 0,
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

struct MoodChartView: View {
    let data: [MoodRecord]
    let color: Color

    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else { return 1...10 }

        let scores = data.map { Double($0.score) }
        let minScore = scores.min() ?? 1
        let maxScore = scores.max() ?? 10

        // Add padding to the range for better visualization
        let range = maxScore - minScore
        let padding = max(range * 0.2, 1.0)  // At least 1 point padding

        // Clamp to mood scale bounds (1-10)
        let lower = max(1, minScore - padding)
        let upper = min(10, maxScore + padding)

        return lower...upper
    }

    var body: some View {
        Chart(data) { record in
            // Clean line mark
            LineMark(
                x: .value("Date", record.date),
                y: .value("Score", record.score)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Data point markers
            PointMark(
                x: .value("Date", record.date),
                y: .value("Score", record.score)
            )
            .foregroundStyle(color)
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
        .chartYScale(domain: yAxisDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: [1, 3, 5, 7, 10]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(height: 300)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct LogMoodFAB: View {
    @Binding var showingMoodEntry: Bool
    let color: Color

    var body: some View {
        Button {
            showingMoodEntry = true
        } label: {
            Image(systemName: "face.smiling.fill")  // Use a more expressive icon for mood
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(20)
                .background(color)  // Serenity Lavender
                .clipShape(Circle())
                .shadow(color: color.opacity(0.5), radius: 15, x: 0, y: 5)
        }
    }
}
