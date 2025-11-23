//
//  StepsDetailView.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Charts
import SwiftUI

struct StepsDetailView: View {

    @State private var viewModel: StepsDetailViewModel

    // Vitality Teal for Activity/Steps theme
    private let primaryColor = Color.vitalityTeal

    // MARK: - Initializer

    init(viewModel: StepsDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {

                // MARK: - Current Stats Summary
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.selectedRange == .day {
                        Text("Total Steps Today")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(viewModel.formattedTodaySteps)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("steps")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Average Steps")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(viewModel.formattedAverageSteps)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text(viewModel.selectedRange.periodLabel)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        if !viewModel.dateRangeString.isEmpty {
                            Text(viewModel.dateRangeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if viewModel.hasEnoughData && viewModel.selectedRange != .day {
                        HStack(spacing: 15) {
                            Label(viewModel.trend, systemImage: "arrow.up.arrow.down")
                                .font(.subheadline)
                                .foregroundColor(primaryColor)

                            if viewModel.shouldShowGoalLine {
                                Label(
                                    viewModel.formattedGoalRate, systemImage: "flag.checkered"
                                )
                                .font(.subheadline)
                                .foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // MARK: - Statistics Cards
                if viewModel.selectedRange != .day && viewModel.hasEnoughData {
                    HStack(spacing: 15) {
                        StepsStatisticCard(
                            title: "Best",
                            value: viewModel.formattedMaxSteps,
                            unit: "steps",
                            icon: "arrow.up.circle.fill",
                            color: .green
                        )

                        StepsStatisticCard(
                            title: "Lowest",
                            value: viewModel.formattedMinSteps,
                            unit: "steps",
                            icon: "arrow.down.circle.fill",
                            color: .orange
                        )

                        if viewModel.shouldShowGoalLine {
                            StepsStatisticCard(
                                title: "Goal Rate",
                                value: viewModel.formattedGoalRate,
                                unit: "",
                                icon: "flag.checkered.circle.fill",
                                color: primaryColor
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // MARK: - Time Range Picker
                StepsTimeRangePickerView(selectedRange: $viewModel.selectedRange)
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedRange) {
                        Task { await viewModel.loadHistoricalData() }
                    }

                // MARK: - Steps Chart
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                } else if viewModel.historicalData.isEmpty {
                    ContentUnavailableView(
                        "No Steps Data",
                        systemImage: "figure.walk",
                        description: Text(viewModel.emptyStateMessage)
                    )
                    .frame(height: 300)
                } else {
                    StepsChartView(viewModel: viewModel, color: primaryColor)
                }

            }
        }
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task { await viewModel.loadHistoricalData() }
        }
    }
}

// MARK: - Component Views

struct StepsTimeRangePickerView: View {
    @Binding var selectedRange: StepsDetailViewModel.TimeRange

    var body: some View {
        HStack(spacing: 10) {
            ForEach(StepsDetailViewModel.TimeRange.allCases) { range in
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

struct StepsChartView: View {
    let viewModel: StepsDetailViewModel
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chartTitle)
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(Array(viewModel.chartData.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Steps", item.steps)
                    )
                    .foregroundStyle(
                        item.steps >= goalThreshold ? Color.green.gradient : color.gradient
                    )
                }

                // Goal line (only show if goal is set)
                if viewModel.shouldShowGoalLine,
                    viewModel.selectedRange == .day || viewModel.selectedRange == .week
                        || viewModel.selectedRange == .month
                {
                    RuleMark(y: .value("Goal", viewModel.goalThreshold))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .foregroundStyle(.green.opacity(0.6))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundColor(.green)
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
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let steps = value.as(Int.self) {
                            Text(steps >= 1000 ? "\(steps / 1000)K" : "\(steps)")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var chartTitle: String {
        switch viewModel.selectedRange {
        case .day: return "Hourly Breakdown"
        case .week: return "Daily Steps This Week"
        case .month: return "Daily Steps This Month"
        case .sixMonths: return "Monthly Average Steps"
        case .year: return "Monthly Average Steps"
        }
    }

    private var goalThreshold: Int {
        return viewModel.goalThreshold
    }

    private var xAxisValues: AxisMarkValues {
        switch viewModel.selectedRange {
        case .day: return .automatic(desiredCount: 8)
        case .week: return .stride(by: .day, count: 1)
        case .month: return .stride(by: .day, count: viewModel.chartData.count > 15 ? 3 : 1)
        case .sixMonths: return .stride(by: .month, count: 1)
        case .year: return .stride(by: .month, count: 1)
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch viewModel.selectedRange {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day()
        case .sixMonths, .year: return .dateTime.month(.abbreviated)
        }
    }
}

struct StepsStatisticCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
