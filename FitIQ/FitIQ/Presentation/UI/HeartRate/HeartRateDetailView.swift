//
//  HeartRateDetailView.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Charts
import SwiftUI

struct HeartRateDetailView: View {

    @State private var viewModel: HeartRateDetailViewModel

    // Vitality Teal for Heart Rate theme
    private let primaryColor = Color.vitalityTeal

    // MARK: - Initializer

    init(viewModel: HeartRateDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {

                // MARK: - Current Stats Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Average Heart Rate")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(viewModel.formattedAverageHeartRate)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("BPM")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    Text(viewModel.trend)
                        .font(.subheadline)
                        .foregroundColor(primaryColor)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // MARK: - Statistics Cards
                HStack(spacing: 15) {
                    StatisticCard(
                        title: "Min",
                        value: viewModel.formattedMinHeartRate,
                        unit: "BPM",
                        color: .blue
                    )

                    StatisticCard(
                        title: "Max",
                        value: viewModel.formattedMaxHeartRate,
                        unit: "BPM",
                        color: .red
                    )

                    StatisticCard(
                        title: "Avg",
                        value: viewModel.formattedAverageHeartRate,
                        unit: "BPM",
                        color: primaryColor
                    )
                }
                .padding(.horizontal)

                // MARK: - Time Range Picker
                HeartRateTimeRangePickerView(selectedRange: $viewModel.selectedRange)
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedRange) {
                        Task { await viewModel.loadHistoricalData() }
                    }

                // MARK: - Heart Rate Chart
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                } else if viewModel.chartData.isEmpty {
                    ContentUnavailableView(
                        "No Heart Rate Data",
                        systemImage: "heart.fill",
                        description: Text(viewModel.emptyStateMessage)
                    )
                    .frame(height: 300)
                } else {
                    HeartRateChartView(
                        viewModel: viewModel,
                        color: primaryColor
                    )
                }

                // MARK: - Recent Entries
                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 5) {
                    Text("All Readings in \(viewModel.selectedRange.displayName)")
                        .font(.headline)
                        .padding(.horizontal)

                    if viewModel.historicalData.isEmpty {
                        Text("No heart rate data recorded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.historicalData) { record in
                            HeartRateLogEntryRow(record: record, color: primaryColor)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task { await viewModel.loadHistoricalData() }
        }
    }
}

// MARK: - Component Views

struct HeartRateTimeRangePickerView: View {
    @Binding var selectedRange: HeartRateDetailViewModel.TimeRange

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HeartRateDetailViewModel.TimeRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selectedRange == range ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedRange == range ? Color.vitalityTeal : Color.gray.opacity(0.2)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HeartRateChartView: View {
    let viewModel: HeartRateDetailViewModel
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chartTitle)
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(Array(viewModel.chartData.enumerated()), id: \.offset) { index, item in
                    if viewModel.selectedRange == .hour {
                        // Bar chart for hour view
                        BarMark(
                            x: .value("Time", item.date),
                            y: .value("Heart Rate", item.heartRate)
                        )
                        .foregroundStyle(
                            item.heartRate > 0
                                ? AnyShapeStyle(color.gradient)
                                : AnyShapeStyle(Color.gray.opacity(0.2))
                        )
                    } else {
                        // Line chart for other views
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Heart Rate", item.heartRate)
                        )
                        .foregroundStyle(color.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Heart Rate", item.heartRate)
                        )
                        .foregroundStyle(color.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }

                // Reference line at 70 BPM (typical resting HR)
                if viewModel.selectedRange != .hour {
                    RuleMark(y: .value("Normal", 70))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Normal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(values: xAxisValues) {
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisValueLabel {
                        if let hr = value.as(Int.self) {
                            Text("\(hr)")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var chartTitle: String {
        switch viewModel.selectedRange {
        case .hour: return "15-Minute Breakdown"
        case .day: return "Hourly Breakdown"
        case .week: return "Daily Heart Rate This Week"
        case .month: return "Daily Heart Rate This Month"
        case .sixMonths: return "Monthly Average"
        case .year: return "Monthly Average"
        }
    }

    private var xAxisValues: AxisMarkValues {
        switch viewModel.selectedRange {
        case .hour: return .automatic(desiredCount: 4)
        case .day: return .stride(by: .hour, count: 4)
        case .week: return .stride(by: .day, count: 1)
        case .month: return .stride(by: .day, count: viewModel.chartData.count > 15 ? 5 : 1)
        case .sixMonths, .year: return .stride(by: .month, count: 1)
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch viewModel.selectedRange {
        case .hour: return .dateTime.hour().minute()
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day()
        case .sixMonths, .year: return .dateTime.month(.abbreviated)
        }
    }

    private var yAxisValues: AxisMarkValues {
        switch viewModel.selectedRange {
        case .hour:
            // For hour view, use 50, 100, 150, 200
            return .stride(by: 50)
        default:
            return .automatic
        }
    }
}

struct HeartRateLogEntryRow: View {
    let record: HeartRateRecord
    let color: Color

    var body: some View {
        HStack {
            // Heart icon
            Image(systemName: "heart.fill")
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(record.formattedHeartRate) BPM")
                        .font(.headline)

                    Spacer()

                    Text(record.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
