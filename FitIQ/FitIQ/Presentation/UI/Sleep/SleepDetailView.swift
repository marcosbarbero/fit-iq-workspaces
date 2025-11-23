import Charts
import Observation  // Need this import in the view file as well
import SwiftUI

struct SleepDetailView: View {
    @State private var viewModel: SleepDetailViewModel

    let onSaveSuccess: () -> Void

    private let primaryColor = Color.serenityLavender

    init(viewModel: SleepDetailViewModel, onSaveSuccess: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {

                // MARK: 1. Time Range Picker
                SleepTimeRangePicker(selectedRange: $viewModel.selectedRange)
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedRange) {
                        // Reset date to today when changing range type
                        viewModel.selectedDate = Calendar.current.startOfDay(for: Date())
                        Task { await viewModel.loadDataForSelectedRange() }
                    }

                // MARK: 1b. Weekly Navigation (Only shows for Last 7 Days range)
                if viewModel.selectedRange == .last7Days && !viewModel.historicalRecords.isEmpty {
                    WeekAtAGlanceView(
                        records: viewModel.historicalRecords,
                        viewModel: viewModel,  // Pass the entire ViewModel to manage selection state
                        onDaySelected: { date in
                            viewModel.selectedDate = date
                            viewModel.selectedRange = .daily
                        }
                    )
                    .padding(.horizontal)
                }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 100)
                } else if viewModel.historicalRecords.isEmpty {
                    ContentUnavailableView("No Sleep Data", systemImage: "bed.double")
                        .frame(height: 250)
                } else {

                    // MARK: 2. Key Metrics Summary (Average Sleep/Efficiency)
                    KeyMetricsSummaryView(viewModel: viewModel)
                        .padding(.horizontal)

                    // MARK: 3. Sleep Stage Timeline Chart (Sequential representation)
                    SleepStageChart(
                        records: viewModel.historicalRecords, selectedDate: viewModel.selectedDate
                    )
                    .frame(height: 250)
                    .padding(.horizontal)

                    // 🛑 NEW: Sleep Stage Breakdown
                    SleepStageBreakdownView(
                        record: viewModel.historicalRecords.first(where: {
                            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
                        }) ?? viewModel.historicalRecords.last!
                    )
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationTitle("Sleep Tracking")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task { await viewModel.loadDataForSelectedRange() }
        }
    }
}

// MARK: - Component Definitions

// Time Range Picker (remains the same)
struct SleepTimeRangePicker: View {
    @Binding var selectedRange: SleepDetailViewModel.TimeRange

    var body: some View {
        HStack {
            ForEach(SleepDetailViewModel.TimeRange.allCases) { range in
                Button(action: { selectedRange = range }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .foregroundColor(selectedRange == range ? .white : .primary)
                        .background {
                            if selectedRange == range {
                                Capsule().fill(Color.serenityLavender)
                            } else {
                                Capsule().fill(Color(.systemGray5))
                            }
                        }
                }
            }
        }
    }
}

// Summary Metrics with efficiency explanation
struct KeyMetricsSummaryView: View {
    @Bindable var viewModel: SleepDetailViewModel
    @State private var showingEfficiencyInfo = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.averageSleepDuration)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    HStack(spacing: 4) {
                        Text("Efficiency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button(action: { showingEfficiencyInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(viewModel.averageEfficiency)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(
                            viewModel.averageEfficiency.starts(with: "9")
                                ? .growthGreen : .serenityLavender)
                }
            }

            // Efficiency explanation (shown when info button is tapped)
            if showingEfficiencyInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sleep Efficiency = (Sleep Time ÷ Time in Bed) × 100")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)

                    HStack(spacing: 12) {
                        Label("85-100%", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Label("70-84%", systemImage: "minus.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Label("<70%", systemImage: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
}

// Sleep Stage Timeline Chart
struct SleepStageChart: View {
    let records: [SleepRecord]
    let selectedDate: Date

    private let stageOrder = ["Awake", "REM", "Core", "Deep"]

    private var currentRecord: SleepRecord {
        // Filter to the single selected date, or use the last record if viewing a range
        records.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })
            ?? records.last!
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sleep Timeline")
                .font(.headline)
                .fontWeight(.bold)

            Chart {
                ForEach(currentRecord.segments) { segment in
                    BarMark(
                        xStart: .value("Start", segment.startTime),
                        xEnd: .value("End", segment.endTime),
                        y: .value("Stage", segment.stage)
                    )
                    .foregroundStyle(segment.color)
                }
            }
            .chartYScale(domain: stageOrder)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                }
            }
            .chartYAxis {
                AxisMarks(values: stageOrder)
            }
            .chartLegend(.hidden)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
}

// Week At A Glance Navigation Filter
struct WeekAtAGlanceView: View {
    let records: [SleepRecord]
    @Bindable var viewModel: SleepDetailViewModel
    let onDaySelected: (Date) -> Void

    private var sortedDays: [SleepRecord] {
        records.sorted { $0.date > $1.date }  // Sort descending (latest first)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Week-at-a-Glance")
                .font(.subheadline)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedDays) { record in
                        let dayOfWeek = record.date.formatted(.dateTime.weekday(.narrow))
                        let timeAsleep = record.timeAsleepMinutes / 60
                        let isSelected = Calendar.current.isDate(
                            record.date, inSameDayAs: viewModel.selectedDate)

                        Button {
                            // Only trigger action if different day is tapped
                            if !isSelected {
                                onDaySelected(record.date)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(dayOfWeek)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(isSelected ? .white : .secondary)

                                Text("\(timeAsleep)h")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(isSelected ? .white : Color.serenityLavender)
                            }
                            .frame(width: 55, height: 75)
                            .background(
                                isSelected
                                    ? Color.serenityLavender : Color(.secondarySystemBackground)
                            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .scaleEffect(isSelected ? 1.05 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

private let stageColors: [String: Color] = [
    "Deep": .midnightIndigo,
    "Core": .oceanCore,
    "REM": .skyBlue,
    "Awake": .warningRed,
]

private func formatDuration(_ duration: Int) -> String {
    let hours = duration / 60
    let minutes = duration % 60
    return "\(hours)hr \(minutes)min"
}

// Split into distinct sub-expressions to aid the compiler
private func sleepDurations(record: SleepRecord) -> [(stage: String, duration: Int)] {
    let grouped = Dictionary(grouping: record.segments, by: { $0.stage })

    let mappedDurations = grouped.map { (stage, segments) in
        let totalMins = segments.reduce(0) { $0 + $1.durationMinutes }  // Sum duration
        return (stage: stage, duration: totalMins)
    }

    let filteredDurations = mappedDurations.filter { $0.duration > 0 }

    let sortedDurations = filteredDurations.sorted { $0.duration > $1.duration }

    return sortedDurations
}

// Sleep Stage Breakdown View
struct SleepStageBreakdownView: View {
    let record: SleepRecord
    private var stageDurations: [(stage: String, duration: Int)]

    init(record: SleepRecord) {
        self.record = record
        self.stageDurations = sleepDurations(record: record)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Breakdown")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                ForEach(stageDurations, id: \.stage) { item in
                    HStack {
                        Circle()
                            .fill(stageColors[item.stage] ?? .secondary)
                            .frame(width: 10, height: 10)

                        Text(item.stage)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(formatDuration(item.duration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
