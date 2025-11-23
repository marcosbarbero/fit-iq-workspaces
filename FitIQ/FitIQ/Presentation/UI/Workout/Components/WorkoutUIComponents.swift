//
//  WorkoutUIComponents.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI
import Charts

// 1. Source Distinction Pill
struct SourcePill: View {
    let source: WorkoutSource
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source == .appLogged ? "app.badge.checkmark.fill" : "inset.filled.applewatch.case")
                .font(.caption2)
            Text(source == .appLogged ? "FitIQ Logged" : "HealthKit Import")
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(source == .appLogged ? Color.vitalityTeal.opacity(0.15) : Color(.systemGray4))
        .cornerRadius(10)
    }
}

// 2. Metric Display Card (Reusable)
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 3. Performance Chart (Mock data)
struct PerformanceChart: View {
    let durationMinutes: Int
    let color: Color
    
    // Mock data for a simple heart rate curve (Rises quickly, stabilizes, drops)
    private var heartRateData: [(minute: Int, bpm: Int)] {
        (0...durationMinutes).map { minute in
            let base = 90
            let peak = 160
            let variance = 5
            
            if minute < 10 { // Warm-up
                return (minute: minute, bpm: base + minute * 6)
            } else if minute < durationMinutes - 5 { // Working set
                return (minute: minute, bpm: Int.random(in: peak - variance...peak + variance))
            } else { // Cool-down
                return (minute: minute, bpm: Int.random(in: base...peak))
            }
        }
    }
    
    var body: some View {
        Chart {
            ForEach(heartRateData, id: \.minute) { data in
                LineMark(
                    x: .value("Time", data.minute),
                    y: .value("BPM", data.bpm)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(color)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 4. Conditional Action Footer
struct ActionFooter: View {
    let isAppLogged: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            if isAppLogged {
                // Editable/Deletable actions (FitIQ Logged)
                Button("Edit Session Details") {
                    print("Opening Edit Sheet")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.ascendBlue) // Edit uses Ascend Blue
                .foregroundColor(.white)
                .cornerRadius(15)
                
                Button("Delete Session", role: .destructive) {
                    print("Triggering Delete Workout Use Case")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
                .foregroundColor(.attentionOrange)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15).stroke(Color.attentionOrange, lineWidth: 2)
                )
            } else {
                // Read-Only action (HealthKit Imported)
                HStack {
                    Image(systemName: "lock.fill")
                    Text("This workout was logged via your Apple Watch and is read-only.")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemFill))
                .cornerRadius(15)
            }
        }
        .padding(.top, 10)
    }
}

// Helper Components for CompletedWorkoutDetailView

// 1. Effort Indicator Gauge (RPE 1-10)
struct EffortIndicatorGauge: View {
    let rpe: Int // Rate of Perceived Exertion (1-10)
    
    private var color: Color {
        switch rpe {
        case 9...10: return Color.attentionOrange // Very Hard/Max effort
        case 7...8: return Color.vitalityTeal // Hard/Target zone
        default: return Color.ascendBlue // Light/Recovery
        }
    }
    
    private var progress: Double { Double(rpe) / 10.0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Effort (RPE)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ZStack {
                // Background Track
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 10)
                
                // Progress Arc
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: rpe)
                
                VStack {
                    Text("\(rpe)")
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                    Text("/ 10")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)
        }
        .frame(width: 150, alignment: .leading) // Set a fixed width for spacing
        .padding(15)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 2. Workout Plan Fidelity Breakdown
struct WorkoutPlanBreakdown: View {
    let exercises: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                ForEach(exercises.sorted(by: { $0.key < $1.key }), id: \.key) { (exercise, details) in
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundColor(.vitalityTeal)
                        
                        Text(exercise) // Exercise Name
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(details) // Load/Set x Reps
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// Helper Component: IntensityBarChart (Replaces EffortIndicatorGauge)

struct IntensityBarChart: View {
    let rpe: Int // Rate of Perceived Exertion (1-10)
    private let primaryColor = Color.vitalityTeal
    
    // Determine the color of the filled bar based on RPE
    private var barColor: Color {
        switch rpe {
        case 9...10: return Color.attentionOrange // Max effort (High Warning)
        case 7...8: return primaryColor // Target effort (Teal)
        case 5...6: return Color.ascendBlue // Moderate effort
        default: return Color(.systemGray)
        }
    }
    
    private var progress: Double { Double(rpe) / 10.0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            HStack {
                Text("Effort (RPE)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(rpe) / 10")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // The Horizontal Bar Visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 8)
                    
                    // Progress Fill (Gradient from Teal to Bar Color)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.8), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        .animation(.easeInOut, value: rpe)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 15) // Inner padding for the bar itself
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// Helper Components for AddWorkoutView

// 1. Conditional Settings View
struct ConditionalWorkoutSettings: View {
    @State var viewModel: AddWorkoutViewModel
    
    var body: some View {
        switch viewModel.selectedCategory {
        case .strength:
            StrengthSettingsView(config: $viewModel.strengthConfig)
        case .cardio:
            CardioSettingsView(config: $viewModel.cardioConfig)
        default:
            EmptyView()
        }
    }
}

// 1a. Strength Specific Settings
struct StrengthSettingsView: View {
    @Binding var config: StrengthConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Strength Configuration").font(.headline).foregroundColor(.secondary)
            
            HStack {
                Text("Default Rest Time:")
                Spacer()
                Text("\(config.defaultRestSeconds) sec")
                Stepper("", value: $config.defaultRestSeconds, in: 30...300, step: 15).labelsHidden()
            }
            
            HStack {
                Text("Default Sets per Exercise:")
                Spacer()
                Text("\(config.defaultSets)")
                Stepper("", value: $config.defaultSets, in: 1...10, step: 1).labelsHidden()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 1b. Cardio Specific Settings
struct CardioSettingsView: View {
    @Binding var config: CardioConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cardio Configuration").font(.headline).foregroundColor(.secondary)
            
            HStack {
                Text("Target Pace:")
                Spacer()
                Text(config.targetPace) // Placeholder for more complex input
            }
            
            HStack {
                Text("Default Interval Time:")
                Spacer()
                Text("\(config.intervalTimeSeconds / 60) min")
                Stepper("", value: $config.intervalTimeSeconds, in: 60...600, step: 60).labelsHidden()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 2. Planned Exercises List View
struct PlannedExercisesListView: View {
    // 🛑 Binding is required here to allow reordering/deletion (CRITICAL for Hex Arch input)
    @Binding var exercises: [PlanExercise]
    
    var body: some View {
        List {
            ForEach($exercises) { $exercise in
                // Each row allows in-place editing of sets, reps, and load
                ExerciseRowInput(exercise: $exercise)
            }
            .onMove { indices, newOffset in
                exercises.move(fromOffsets: indices, toOffset: newOffset)
            }
            .onDelete { indices in
                exercises.remove(atOffsets: indices)
            }
        }
        // Set fixed height based on item count for display within ScrollView
        .frame(height: CGFloat(exercises.count) * 60 + 100)
        .listStyle(.plain)
    }
}

// 2a. Exercise Row Input
struct ExerciseRowInput: View {
    @Binding var exercise: PlanExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name).font(.headline)
            
            HStack(spacing: 15) {
                // Sets Input
                Stepper("\(exercise.sets) Sets", value: $exercise.sets, in: 1...10)
                
                // Reps/Time Input (Conditional display)
                if exercise.reps != nil {
                    Stepper("\(exercise.reps!) Reps", value: $exercise.reps.toUnwrapped(defaultValue: 0), in: 0...50)
                } else if exercise.timeSeconds != nil {
                    Text("Time: \(exercise.timeSeconds! / 60)m") // Placeholder
                }
                
                // Load Input
                HStack {
                    Text("Load:")
                    TextField("Weight", value: $exercise.loadKg, format: .number)
                        .keyboardType(.decimalPad)
                    Text("kg")
                }
            }
            .font(.subheadline)
        }
    }
}

// 3. Save Footer
struct SaveWorkoutFooter: View {
    @State var viewModel: AddWorkoutViewModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Save Routine (\(viewModel.estimatedDurationMinutes) min)")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.vitalityTeal)
        .foregroundColor(.white)
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

// Note: Requires optional Binding helper `toUnwrapped` for PlanExercise fields.
// You will also need to add the `move` and `delete` functions to the List closure in AddWorkoutView.
