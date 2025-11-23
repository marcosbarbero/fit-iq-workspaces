import Foundation
import SwiftUI

// YourAppRoot/Presentation/UI/WorkoutView.swift (WorkoutRow REVISED)

struct WorkoutRow: View {
    let workout: Workout
    let viewModel: WorkoutViewModel
    let onStart: () -> Void
    let onDelete: (UUID) -> Void
    let onToggleFavorite: (UUID) -> Void
    // MARK: - NEW: onToggleFeatured closure
    let onToggleFeatured: (UUID) -> Void

    @State private var showingDetail: Bool = false  // Controls the preview sheet for this specific workout
    private let primaryColor = Color.vitalityTeal  // Use a defined constant

    // Determine source type (placeholder for future enhancement)
    private var sourceType: String {
        // For now, all mock data is "System". In production, check workout properties
        return "System"
    }

    private var sourceColor: Color {
        switch sourceType {
        case "User Created":
            return .ascendBlue
        case "Professional":
            return .serenityLavender
        default:  // System
            return primaryColor
        }
    }

    private var sourceIcon: String {
        switch sourceType {
        case "User Created":
            return "person.fill"
        case "Professional":
            return "star.circle.fill"
        default:  // System
            return "app.badge.checkmark.fill"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon Circle (Left)
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: workout.category.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(primaryColor)
            }

            // Text Stack (Center)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(workout.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // MARK: - Featured pin indicator
                    if workout.isFeatured {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.serenityLavender)
                    }
                    // Favorite star indicator
                    if workout.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.growthGreen)
                    }
                }

                // Stats row
                HStack(spacing: 10) {
                    Label("\(workout.durationMinutes) min", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if workout.equipmentNeeded {
                        Label("Equipment", systemImage: "dumbbell.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Source badge
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon)
                        .font(.caption2)
                    Text(sourceType)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(sourceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(sourceColor.opacity(0.15))
                .cornerRadius(6)
            }

            Spacer()

            // Start Button (Right)
            Button(action: onStart) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(primaryColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true  // Tap to preview
        }
        // MARK: - NEW: Leading swipe actions for Feature/Unfeature and Favorite/Unfavorite
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onToggleFeatured(workout.id)
            } label: {
                Label(
                    workout.isFeatured ? "Unfeature" : "Feature",
                    systemImage: workout.isFeatured ? "pin.slash.fill" : "pin.fill")
            }
            .tint(workout.isFeatured ? Color(.systemGray) : Color.serenityLavender)  // Changed from .calmIris

            Button {
                onToggleFavorite(workout.id)
            } label: {
                Label(
                    workout.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: workout.isFavorite ? "star.slash.fill" : "star.fill")
            }
            .tint(workout.isFavorite ? Color(.systemGray) : Color.growthGreen)  // Changed from .sustenanceYellow
        }
        // Existing trailing swipe actions for Delete and Edit
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(workout.id)  // Call the passed-in delete action
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                showingDetail = true  // Swipe to edit also opens the detail/edit sheet
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            .tint(Color.ascendBlue)  // Use Ascend Blue for edit action consistency
        }
        // Sheet for workout preview/detail
        .sheet(isPresented: $showingDetail) {
            if let template = viewModel.getWorkoutTemplate(byID: workout.id) {
                WorkoutTemplateDetailView(
                    template: template,
                    onStart: onStart,
                    onToggleFavorite: onToggleFavorite,
                    onToggleFeatured: onToggleFeatured
                )
            } else {
                Text("Template not found")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// NEW HELPER: Completed Workout History Row (Full-Width Card)
struct CompletedWorkoutRow: View {
    let log: CompletedWorkout
    private let primaryColor = Color.vitalityTeal

    // Derived property for conditionality
    private var isAppLogged: Bool { log.source == .appLogged }

    // Format time for display
    private var workoutTime: String {
        log.date.formatted(.dateTime.hour().minute())
    }

    // Show RPE for any workout that has an effort rating (app-logged OR HealthKit with Apple Fitness rating)
    private var shouldShowRPE: Bool {
        log.effortRPE > 0
    }

    // Color for RPE based on intensity level
    private func colorForRPE(_ value: Int) -> Color {
        switch value {
        case 1...3: return Color.green
        case 4...5: return Color.yellow
        case 6...7: return Color.orange
        case 8...9: return Color.red
        case 10: return Color.purple
        default: return Color.gray
        }
    }

    // Height for each bar - increases progressively
    private func heightForBar(_ index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let increment: CGFloat = 2
        return baseHeight + (CGFloat(index) * increment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // MARK: - Top Row: Icon, Title, and Time
            HStack(alignment: .center) {
                // Icon and Title (Left)
                HStack(spacing: 8) {
                    Image(systemName: log.activityType.systemIconName)
                        .font(.title2)
                        .foregroundColor(primaryColor)

                    Text(log.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                // Time and Source Badge (Right)
                HStack(spacing: 8) {
                    Text(workoutTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(isAppLogged ? "FitIQ" : "Watch")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isAppLogged ? primaryColor : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    isAppLogged
                                        ? primaryColor.opacity(0.15) : Color(.tertiarySystemFill))
                        )
                }
            }
            .padding(.horizontal, 5)

            // MARK: - Stats Row: Duration, Calories, and Effort Visualization
            HStack(alignment: .center, spacing: 20) {
                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        String(format: "%d min", log.durationMinutes),
                        systemImage: "clock.fill"
                    )
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 30)

                // Calories
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "\(log.caloriesBurned)",
                        systemImage: "flame.fill"
                    )
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(primaryColor)

                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Effort Visualization (10-bar gradient with increasing heights)
                if shouldShowRPE {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(1...10, id: \.self) { barIndex in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        barIndex <= log.effortRPE
                                            ? colorForRPE(barIndex)
                                            : Color.secondary.opacity(0.2)
                                    )
                                    .frame(width: 6, height: heightForBar(barIndex - 1))
                            }
                        }

                        Text("RPE \(log.effortRPE)/10")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())  // Makes the whole area tappable

        // 🛑 FIX: Conditional Swipe Actions
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isAppLogged {
                // App-Logged (FitIQ) - Allows full CRUD
                Button(role: .destructive) {
                    print("Action: Deleting FitIQ Logged Workout: \(log.name)")
                    // In a real app, you would pass an onDelete closure here too
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    print("Action: Editing FitIQ Logged Workout: \(log.name)")
                    // In a real app, you would present an edit sheet for this log
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .tint(Color.ascendBlue)  // Use Ascend Blue for edit action consistency
            } else {
                // HealthKit Imported - Read-Only
                Button {
                    print("Action: Hiding Read-Only Workout: \(log.name)")
                } label: {
                    Label("Hide", systemImage: "eye.slash.fill")
                }
                .tint(Color(.systemGray))
            }
        }
    }
}

// 3. Full Workout Running View (Live Update View)
struct WorkoutRunningView: View {
    @Environment(\.dismiss) var dismiss
    let workout: Workout

    var body: some View {
        VStack {
            HStack {
                Text(workout.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.vitalityTeal)
                Spacer()
                Button("End Session") {
                    dismiss()
                }
                .tint(.attentionOrange)
            }
            .padding()

            Text("--- LIVE WORKOUT DATA PLACEHOLDER ---")
                .font(.headline)
                .padding()

            Text("00:00:15")  // Mock Timer
                .font(.system(size: 80, weight: .thin, design: .monospaced))

            Text("Heart Rate: 145 BPM")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Next: \(workout.category.rawValue) Set")
                .padding(.top, 40)
                .font(.title)

            Spacer()

            // Mock Input Button
            Button("Log Reps / Set Complete") {
                print("Set Logged for \(workout.name)")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.ascendBlue)
            .foregroundColor(.white)
            .cornerRadius(15)
            .padding(.horizontal)
            .padding(.bottom, 30)

        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

struct WorkoutCategoryFilterSheet: View {
    @Environment(\.dismiss) var dismiss

    @Binding var searchText: String
    @Binding var selectedFilter: WorkoutCategory

    private let primaryColor = Color.vitalityTeal

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Search Field (Always Visible)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search workout names...", text: $searchText)
                        .autocorrectionDisabled(true)
                }
                .padding(12)
                .background(Color(.systemFill))
                .cornerRadius(10)

                // Category Picker
                Text("Filter by Category")
                    .font(.headline)

                // Use a Grid for visual elegance instead of a basic list
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(WorkoutCategory.allCases) { category in
                        CategoryFilterButton(
                            category: category,
                            isSelected: selectedFilter == category,
                            color: primaryColor
                        ) {
                            selectedFilter = category
                            dismiss()  // Close the sheet immediately on selection
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Filter Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// Helper button for the grid layout
struct CategoryFilterButton: View {
    let category: WorkoutCategory
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80)
            .background(isSelected ? color : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct MultiRingActivityGauge: View {
    let rings: [ActivityRingSnapshot]

    // This is the core visual component
    var body: some View {
        ZStack {
            // Draw rings from outside (Move) inward (Stand)
            ForEach(rings.indices.reversed(), id: \.self) { index in
                let ring = rings[index]
                let ringSize = 100.0 - (Double(index) * 20.0)  // Outer: 100, Mid: 80, Inner: 60
                let lineWidth = 10.0

                ZStack {
                    // 🛑 FIX 1: Subtle colored background track (Inner Grey Circle Fix)
                    Circle()
                        .stroke(ring.color.opacity(0.2), lineWidth: lineWidth)
                        .frame(width: ringSize, height: ringSize)

                    // Progress Track
                    Circle()
                        .trim(from: 0.0, to: ring.progress)
                        .stroke(
                            ring.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                }
            }
        }
        .frame(width: 110, height: 110)  // Consistent size for the whole ring component
    }
}

struct ActivityRingSnapshot: Identifiable {
    let id = UUID()
    let name: String
    let current: Double
    let goal: Double
    let unit: String
    let color: Color
    var progress: Double { min(1.0, Double(current) / Double(goal)) }
}
