//
//  WorkoutSessionView.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import SwiftUI

/// View for tracking an active workout session
struct WorkoutSessionView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: WorkoutViewModel
    
    @State private var showingIntensitySelector = false
    @State private var selectedIntensity = 5
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    private let primaryColor = Color.vitalityTeal
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let session = viewModel.activeSession {
                    // Active workout content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Timer display
                            VStack(spacing: 8) {
                                Text("Workout Duration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(formatDuration(elapsedTime))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(primaryColor)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            
                            // Workout info
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: session.activityType.systemIconName)
                                        .font(.title2)
                                        .foregroundColor(primaryColor)
                                    
                                    VStack(alignment: .leading) {
                                        Text(session.name)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        
                                        Text(session.activityType.displayName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                
                                // Exercise count
                                if !session.exercises.isEmpty {
                                    HStack {
                                        Image(systemName: "list.bullet")
                                            .foregroundColor(primaryColor)
                                        Text("\(session.exercises.count) exercises")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    
                                    // Exercise list
                                    ForEach(session.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                                        HStack {
                                            Text("\(exercise.orderIndex + 1).")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(width: 30, alignment: .trailing)
                                            
                                            Text(exercise.name)
                                                .font(.body)
                                            
                                            Spacer()
                                            
                                            // Show set count if any
                                            if !exercise.sets.isEmpty {
                                                Text("\(exercise.sets.filter { $0.isCompleted }.count)/\(exercise.sets.count)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                } else {
                                    Text("Free-form workout")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            
                            // Instructions
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(primaryColor)
                                    Text("Workout in Progress")
                                        .font(.headline)
                                }
                                
                                Text("Complete your workout, then tap 'Finish Workout' to rate the intensity and save to your activity history.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding()
                    }
                    
                    // Bottom action buttons
                    VStack(spacing: 12) {
                        Divider()
                        
                        HStack(spacing: 16) {
                            // Cancel button
                            Button(action: {
                                viewModel.cancelWorkout()
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red, lineWidth: 2)
                                    )
                            }
                            
                            // Finish button
                            Button(action: {
                                showingIntensitySelector = true
                            }) {
                                Text("Finish Workout")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(primaryColor)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color(.systemBackground))
                } else {
                    // No active session
                    ContentUnavailableView(
                        "No Active Workout",
                        systemImage: "figure.run",
                        description: Text("Start a workout from the workouts list")
                    )
                }
            }
            .navigationTitle("Active Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingIntensitySelector) {
                IntensitySelector(
                    selectedIntensity: $selectedIntensity,
                    onComplete: {
                        Task {
                            await viewModel.completeWorkout(intensity: selectedIntensity)
                            showingIntensitySelector = false
                            dismiss()
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        guard let session = viewModel.activeSession else { return }
        
        // Calculate initial elapsed time
        elapsedTime = Date().timeIntervalSince(session.startedAt)
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(session.startedAt)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
