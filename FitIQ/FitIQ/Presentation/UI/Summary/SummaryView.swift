import Foundation
import Observation
import SwiftUI

// NOTE: The Color extension (ascendBlue, vitalityTeal, serenityLavender, hex initializer)
// must be available in the project for this code to compile.

struct SummaryView: View {
    private let profileViewModel: ProfileViewModel

    @State private var viewModel: SummaryViewModel

    private let bodyMassEntryViewModel: BodyMassEntryViewModel

    private let bodyMassDetailViewModel: BodyMassDetailViewModel

    private let moodEntryViewModel: MoodEntryViewModel

    private let moodDetailViewModel: MoodDetailViewModel

    private let nutritionSummaryViewModel: NutritionSummaryViewModel

    private let sleepDetailViewModel: SleepDetailViewModel

    private let heartRateDetailViewModel: HeartRateDetailViewModel

    private let stepsDetailViewModel: StepsDetailViewModel

    @State private var showingQuickLog: Bool = false

    @State private var showingProfile: Bool = false

    @State private var showingMassEntry: Bool = false

    @State private var showingMoodEntry: Bool = false

    // Constant for the header height (approx. 1/3 of a standard screen)
    private let headerHeight: CGFloat = 250

    init(
        profileViewModel: ProfileViewModel,
        summaryViewModel: SummaryViewModel,
        bodyMassEntryViewModel: BodyMassEntryViewModel,
        bodyMassDetailViewModel: BodyMassDetailViewModel,
        moodEntryViewModel: MoodEntryViewModel,
        moodDetailViewModel: MoodDetailViewModel,
        nutritionSummaryViewModel: NutritionSummaryViewModel,
        sleepDetailViewModel: SleepDetailViewModel,
        heartRateDetailViewModel: HeartRateDetailViewModel,
        stepsDetailViewModel: StepsDetailViewModel
    ) {

        self.profileViewModel = profileViewModel
        self._viewModel = State(initialValue: summaryViewModel)
        self.bodyMassEntryViewModel = bodyMassEntryViewModel
        self.bodyMassDetailViewModel = bodyMassDetailViewModel
        self.moodEntryViewModel = moodEntryViewModel
        self.moodDetailViewModel = moodDetailViewModel
        self.nutritionSummaryViewModel = nutritionSummaryViewModel
        self.sleepDetailViewModel = sleepDetailViewModel
        self.heartRateDetailViewModel = heartRateDetailViewModel
        self.stepsDetailViewModel = stepsDetailViewModel
    }

    var body: some View {
        ZStack(alignment: .top) {

            // 1. BRANDED BLURRY HEADER (Background Layer)
            VStack {
                LinearGradient(
                    colors: [
                        Color.ascendBlue.opacity(0.9),
                        Color.vitalityTeal.opacity(0.8),
                        Color.serenityLavender.opacity(0.9),  // Increased opacity for better visibility
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: headerHeight)
                .blur(radius: 60)
                .edgesIgnoringSafeArea(.top)

                Spacer()
            }

            // 2. SCROLLABLE CONTENT (Foreground Layer)
            ScrollView {
                VStack(spacing: 20) {

                    // Spacer pulls content up over the blurry header area.
                    Spacer(minLength: headerHeight / 8)

                    // DEBUG: Refresh indicator (remove in production)
                    // VStack(spacing: 8) {
                    //     HStack {
                    //         Text(
                    //             "🔄 Last refresh: \(viewModel.lastRefreshTime, style: .time)"
                    //         )
                    //         .font(.caption2)
                    //         .foregroundColor(.secondary)
                    //         Text("Count: \(viewModel.refreshCount)")
                    //             .font(.caption2)
                    //             .foregroundColor(.secondary)
                    //     }

                    //     HStack {
                    //         Text("🚶 Steps: \(viewModel.formattedStepsCount)")
                    //             .font(.caption2)
                    //             .foregroundColor(.blue)
                    //         Text(
                    //             "❤️ HR: \(viewModel.formattedLatestHeartRate) BPM"
                    //         )
                    //         .font(.caption2)
                    //         .foregroundColor(.red)
                    //         Text("🕐 \(viewModel.lastHeartRateRecordedTime)")
                    //             .font(.caption2)
                    //             .foregroundColor(.secondary)
                    //     }

                    //     // DEBUG: Manual test buttons
                    //     HStack(spacing: 8) {
                    //         Button {
                    //             Task {
                    //                 print(
                    //                     "🧪 DEBUG: Manual refresh button tapped"
                    //                 )
                    //                 await viewModel.reloadAllData()
                    //             }
                    //         } label: {
                    //             HStack {
                    //                 Image(systemName: "arrow.clockwise")
                    //                 Text("Reload All")
                    //             }
                    //             .font(.caption)
                    //             .padding(.horizontal, 8)
                    //             .padding(.vertical, 4)
                    //             .background(Color.blue)
                    //             .foregroundColor(.white)
                    //             .cornerRadius(6)
                    //         }

                    //         Button {
                    //             print(
                    //                 "🧪 DEBUG: Test notification button tapped"
                    //             )
                    //             viewModel.testNotification()
                    //         } label: {
                    //             HStack {
                    //                 Image(systemName: "bell.badge")
                    //                 Text("Test Event")
                    //             }
                    //             .font(.caption)
                    //             .padding(.horizontal, 8)
                    //             .padding(.vertical, 4)
                    //             .background(Color.orange)
                    //             .foregroundColor(.white)
                    //             .cornerRadius(6)
                    //         }
                    //     }
                    // }
                    // .padding(.horizontal)
                    // .padding(.vertical, 8)
                    // .background(Color.yellow.opacity(0.2))
                    // .cornerRadius(8)

                    // 1. Welcome Header (MODIFIED: Now an HStack for button placement)
                    HStack(alignment: .top) {

                        // LEFT SIDE: Greeting and Subtitle
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hello, Marcos!")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .foregroundColor(Color.primary)

                            Text("You're 75% towards your daily goals.")  // Placeholder for now
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .padding(.top, 13)
                                .padding(.bottom, 8)
                        }

                        Spacer()

                        Button {
                            showingProfile = true
                        } label: {
                            Image("ProfileImage")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 38, height: 38)
                                .clipShape(Circle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // 2. AI Companion Insight Card
                    // Pull the card up to visually overlap the header and the welcome text
                    AICardView()
                        .padding(.horizontal)
                        .padding(.top, -30)

                    // 3. Daily Stats Grid (Three Pillars)
                    DailyStatsGridView(
                        viewModel: viewModel,
                        nutritionViewModel: nutritionSummaryViewModel
                    )
                    .padding(.horizontal)

                    NavigationLink(value: "stepsDetail") {
                        FullWidthStepsStatCard(
                            stepsCount: viewModel.formattedStepsCount,
                            lastRecordedTime: viewModel.lastStepsRecordedTime,
                            hourlyData: viewModel.last8HoursStepsData
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    NavigationLink(value: "heartRateDetail") {
                        FullWidthHeartRateStatCard(
                            latestHeartRate: viewModel.formattedLatestHeartRate,
                            lastRecordedTime: viewModel
                                .lastHeartRateRecordedTime,
                            hourlyData: viewModel.last8HoursHeartRateData
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    NavigationLink(value: "sleepDetail") {
                        FullWidthSleepStatCard(
                            sleepHours: viewModel.latestSleepHours,
                            sleepEfficiency: viewModel.latestSleepEfficiency,
                            lastSleepDate: viewModel.latestSleepDate
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    NavigationLink(value: "nutritionDetail") {  // Navigate to the dedicated Nutrition Tab/View
                        FullWidthNutritionCard(
                            viewModel: nutritionSummaryViewModel
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    NavigationLink(value: "bodyMassDetail") {  // Use a hardcoded string or Enum case for simplicity here
                        FullWidthBodyMassStatCard(
                            healthMetrics: viewModel.latestHealthMetrics,
                            historicalWeightData: viewModel.historicalWeightData
                        )
                    }
                    .buttonStyle(.plain)  // Use plain style to keep the card's visual integrity
                    .padding(.horizontal)

                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showingQuickLog) {
            Text("Quick Log View Placeholder")
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(viewModel: self.profileViewModel)  // Assuming ProfileView takes a binding to isPresented
        }
        .navigationDestination(for: String.self) { value in
            switch value {
            case "bodyMassDetail":
                BodyMassDetailView(
                    viewModel: bodyMassDetailViewModel,
                    bodyMassEntryViewModel: bodyMassEntryViewModel,
                    onSaveSuccess: { savedWeight in
                        Task { await viewModel.reloadAllData() }
                    }
                )
            case "moodDetail":
                MoodDetailView(
                    viewModel: moodDetailViewModel,
                    moodEntryViewModel: moodEntryViewModel,
                    onSaveSuccess: {
                        Task { await viewModel.reloadAllData() }
                    }
                )
            case "heartRateDetail":
                HeartRateDetailView(viewModel: heartRateDetailViewModel)
            case "nutritionDetail":
                // Since Nutrition has its own tab, this link should ideally just change the tab selection.
                // For now, we'll keep it as a fallback navigation destination or simply direct the user
                // to the main NutritionView if they're forced to use NavigationLink.
                // Given we are designing the SummaryView, a simple NavigationLink to the new root NutritionView is sufficient.
                //                        NutritionView(viewModel: viewDeps.nutritionViewModel)
                Text("Content Not Found for \(value)")
            case "sleepDetail":  // NEW DESTINATION
                SleepDetailView(
                    viewModel: sleepDetailViewModel,
                    onSaveSuccess: {
                        // After returning to summary, reload the sleep stat if needed
                        Task { await viewModel.reloadAllData() }
                    }
                )
            case "stepsDetail":  // NEW DESTINATION
                StepsDetailView(viewModel: stepsDetailViewModel)
            default:
                // Fallback for unknown paths
                Text("Content Not Found for \(value)")
            }
        }
        .task {
            // Load data when view appears
            // Initial sync is already done in FitIQApp before this view appears
            await viewModel.reloadAllData()

            // If data is stale (>5 minutes old), trigger a background sync
            let timeSinceLastRefresh = Date().timeIntervalSince(
                viewModel.lastRefreshTime
            )
            if timeSinceLastRefresh > 300 {  // 5 minutes
                print(
                    "SummaryView: ⏰ Data is stale (\(Int(timeSinceLastRefresh))s old), triggering sync..."
                )
                await viewModel.refreshData()
            }
        }
        .onChange(of: viewModel.isSyncing) { oldValue, newValue in
            // When sync completes (isSyncing changes from true to false), reload data
            if oldValue && !newValue {
                Task {
                    // Wait a bit for database to settle
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await viewModel.reloadAllData()
                }
            }
        }
        .refreshable {
            // Pull-to-refresh: sync from HealthKit and reload
            await viewModel.refreshData()
        }
    }
}

// MARK: - Helper Views (AICardView, DailyStatsGridView, StatCard, QuickLogButton)

// --- AICardView (Remains the same) ---
struct AICardView: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COMPANION INSIGHT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))

                Text(
                    "Great work on your steps! Remember to drink water today; your resting heart rate is slightly elevated."
                )
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(3)

                HStack {
                    Text("Chat Now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
            .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity)
        // Use Ascend Blue for the AI Companion card
        .background(Color.ascendBlue)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)  // Added shadow for consistency
    }
}

// --- DailyStatsGridView (MODIFIED: Now accepts SummaryViewModel) ---
struct DailyStatsGridView: View {
    @Bindable var viewModel: SummaryViewModel

    let nutritionViewModel: NutritionSummaryViewModel

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 15
        ) {

            // Steps now shown as full-width card above
            // Sleep now shown as full-width card above

            // 4. Mood Stat (Wellness - Lavender)
            NavigationLink(value: "moodDetail") {  // Navigate to new detail view
                MoodStatCard(
                    emoji: viewModel.moodEmoji,
                    displayText: viewModel.moodDisplayText,
                    color: .serenityLavender
                )
            }
            .buttonStyle(.plain)

            // 6. Water Stat (Fitness/Habit - Teal)
            StatCard(
                currentValue:
                    "\(nutritionViewModel.waterIntakeFormatted) / \(nutritionViewModel.waterGoalFormatted)",
                unit: "Liters",
                icon: "drop.fill",
                color: .vitalityTeal
            )
        }
    }
}

struct MoodStatCard: View {
    let emoji: String
    let displayText: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji)
                .font(.title2)
                .frame(height: 28)  // Match icon height

            Text(displayText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Current Mood")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct FullWidthBodyMassStatCard: View {
    let healthMetrics: HealthMetricsSnapshot?  // Accept optional HealthMetricsSnapshot
    let historicalWeightData: [Double]  // NEW: Accept historical weight data

    private var lastEntryDate: String {
        guard let date = healthMetrics?.date else { return "N/A" }
        return date.formattedMonthDay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Top Row: Icon, Title, and Date (Now includes micro-graph logic)
            HStack(alignment: .center) {

                // Icon and Title (Left)
                HStack(spacing: 8) {
                    Image(systemName: "scalemass.fill")
                        .font(.title2)
                        .foregroundColor(.ascendBlue)

                    Text("Body Mass")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                // Spacer pushes the date to the right
                Spacer()

                // Last Entry Date (Right) - Font weight is now .regular
                Text(lastEntryDate)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 5)

            HStack(alignment: .center) {
                // Center Row: Current Value (Actual Weight)
                Text(
                    healthMetrics?.weightKg.map {
                        String(format: "%.1f kg", $0)
                    } ?? "N/A"
                )  // Use real weight
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 5)

                Spacer()

                // Reintroduce LineGraphView with actual historical data
                if !historicalWeightData.isEmpty {
                    LineGraphView(
                        data: historicalWeightData,
                        color: .ascendBlue
                    )
                    .frame(width: 80, height: 20)
                }
            }.padding(.horizontal, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// --- LineGraphView (The Micro-Visualization) ---
struct LineGraphView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard let firstValue = data.first else { return }

                let minValue = data.min() ?? 0
                let maxValue = data.max() ?? 1
                let range = maxValue - minValue

                let xStep = geometry.size.width / CGFloat(data.count - 1)

                let yStart: CGFloat
                if range == 0 {
                    yStart = geometry.size.height / 2
                } else {
                    yStart =
                        CGFloat(1.0 - (firstValue - minValue) / range)
                        * geometry.size.height
                }

                path.move(to: CGPoint(x: 0, y: yStart))

                for (index, value) in data.enumerated().dropFirst() {
                    let x = xStep * CGFloat(index)
                    let y: CGFloat
                    if range == 0 {
                        y = geometry.size.height / 2
                    } else {
                        y =
                            CGFloat(1.0 - (value - minValue) / range)
                            * geometry.size.height
                    }
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}

// --- QuickLogButton (Remains the same) ---
struct QuickLogButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Quick Log: Meal or Workout")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            // Use Vitality Teal as the action color for logging/activity
            .background(Color.vitalityTeal)
            .foregroundColor(.white)
            .cornerRadius(15)
            .shadow(
                color: Color.vitalityTeal.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
}

// --- FullWidthStepsStatCard (Hourly Bar Chart) ---
struct FullWidthStepsStatCard: View {
    let stepsCount: Int
    let lastRecordedTime: String
    let hourlyData: [(hour: Int, steps: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Top Row: Icon, Title, and Last Hour
            HStack(alignment: .center) {

                // Icon and Title (Left)
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundColor(.vitalityTeal)

                    Text("Steps")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Last Recorded Time (Right)
                Text(lastRecordedTime)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 5)

            HStack(alignment: .center) {
                // Center Row: Current Step Count
                let formatter = NumberFormatter()
                let _ = {
                    formatter.numberStyle = .decimal
                    formatter.groupingSeparator = ","
                }()

                Text(
                    formatter.string(from: NSNumber(value: stepsCount))
                        ?? "\(stepsCount)"
                )
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 5)

                Spacer()

                // Hourly bar chart (last 8 hours)
                if !hourlyData.isEmpty {
                    HourlyStepsBarChart(data: hourlyData, color: .vitalityTeal)
                        .frame(width: 100, height: 30)
                } else {
                    // Placeholder for when no hourly data is available
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 30)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// --- HourlyStepsBarChart (Micro Bar Chart for last 8 hours) ---
struct HourlyStepsBarChart: View {
    let data: [(hour: Int, steps: Int)]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let maxSteps = data.map { $0.steps }.max() ?? 1
            let barWidth = geometry.size.width / CGFloat(data.count) - 2

            HStack(spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(
                                item.steps > 0 ? color : Color.gray.opacity(0.2)
                            )
                            .frame(
                                width: barWidth,
                                height: item.steps > 0
                                    ? CGFloat(item.steps) / CGFloat(maxSteps)
                                        * geometry.size.height
                                    : 4
                            )
                            .cornerRadius(2)
                    }
                }
            }
        }
    }
}

// MARK: - Full Width Heart Rate Card

struct FullWidthHeartRateStatCard: View {
    let latestHeartRate: String
    let lastRecordedTime: String
    let hourlyData: [(hour: Int, heartRate: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Top Row: Icon, Title, and Last Hour
            HStack(alignment: .center) {

                // Icon and Title (Left)
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.red)

                    Text("Heart Rate")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Last Recorded Time (Right)
                Text(lastRecordedTime)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 5)

            HStack(alignment: .center) {
                // Center Row: Current Heart Rate
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latestHeartRate)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("BPM")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)

                Spacer()

                // Hourly bar chart (last 8 hours)
                if !hourlyData.isEmpty {
                    HourlyHeartRateBarChart(data: hourlyData, color: .red)
                        .frame(width: 100, height: 30)
                } else {
                    // Placeholder for when no hourly data is available
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 30)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct HourlyHeartRateBarChart: View {
    let data: [(hour: Int, heartRate: Int)]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            // Use normalized heart rate range for consistent visualization
            // Typical range: 40 bpm (low resting) to 180 bpm (high exercise)
            let minHeartRate: CGFloat = 40
            let maxHeartRate: CGFloat = 180
            let heartRateRange = maxHeartRate - minHeartRate
            let barWidth = geometry.size.width / CGFloat(data.count) - 2

            HStack(spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(
                                item.heartRate > 0
                                    ? color : Color.gray.opacity(0.2)
                            )
                            .frame(
                                width: barWidth,
                                height: item.heartRate > 0
                                    ? max(
                                        (CGFloat(item.heartRate) - minHeartRate)
                                            / heartRateRange
                                            * geometry.size.height,
                                        4
                                    )
                                    : 4
                            )
                            .cornerRadius(2)
                    }
                }
            }
        }
    }
}

// MARK: - Full Width Sleep Card

/// Sleep stat card displaying total sleep duration and sleep efficiency
/// Sleep efficiency = (Total Sleep Time / Time in Bed) × 100
/// - Good: 85-100%
/// - Fair: 70-84%
/// - Poor: <70%
struct FullWidthSleepStatCard: View {
    let sleepHours: Double?
    let sleepEfficiency: Int?
    let lastSleepDate: Date?

    var formattedSleepHours: String {
        guard let hours = sleepHours else { return "No Data" }
        let totalMinutes = Int(hours * 60)
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60

        if mins == 0 {
            return "\(hrs)hr"
        } else {
            return "\(hrs)hr \(mins)min"
        }
    }

    var formattedEfficiency: String {
        guard let efficiency = sleepEfficiency else { return "--" }
        return "\(efficiency)%"
    }

    var lastSleepTime: String {
        guard let date = lastSleepDate else { return "Not tracked" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var sleepQualityColor: Color {
        guard let efficiency = sleepEfficiency else { return .gray }
        switch efficiency {
        case 85...100: return .green
        case 70..<85: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Top Row: Icon, Title, and Last Sleep Time
            HStack(alignment: .center) {

                // Icon and Title (Left)
                HStack(spacing: 8) {
                    Image(systemName: "bed.double.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)

                    Text("Sleep")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Last Recorded Time (Right)
                Text(lastSleepTime)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 5)

            HStack(alignment: .center) {
                // Center Row: Sleep Duration
                Text(formattedSleepHours)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 5)

                Spacer()

                // Sleep Quality/Efficiency Indicator
                HStack(spacing: 4) {
                    Text(formattedEfficiency)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("quality")
                        .font(.caption)
                }
                .foregroundColor(sleepQualityColor)
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
