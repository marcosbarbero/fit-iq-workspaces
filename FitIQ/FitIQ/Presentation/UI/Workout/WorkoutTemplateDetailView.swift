//
//  WorkoutTemplateDetailView.swift
//  FitIQ
//
//  Created by Copilot on 2025-11-11.
//

import SwiftUI

/// Preview/detail view for workout templates
/// Shows workout information before the user decides to start or pin it
struct WorkoutTemplateDetailView: View {
    @Environment(\.dismiss) var dismiss
    let template: WorkoutTemplate
    let onStart: () -> Void
    let onToggleFavorite: (UUID) -> Void
    let onToggleFeatured: (UUID) -> Void

    // NEW: Sharing ViewModel (optional - only if user has access)
    var sharingViewModel: WorkoutTemplateSharingViewModel?

    // NEW: Sheet presentation state
    @State private var showingShareSheet = false
    @State private var showingCopySheet = false

    private let primaryColor = Color.vitalityTeal

    // Determine source type based on template properties
    private var sourceType: String {
        if template.isSystem {
            return "System"
        } else if template.userID != nil {
            return "User Created"
        } else {
            return "Professional"
        }
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

    private var categoryIcon: String {
        switch template.category?.lowercased() {
        case "strength": return "figure.strengthtraining.traditional"
        case "cardio": return "figure.run"
        case "flexibility", "mobility": return "figure.flexibility"
        case "sports": return "sportscourt"
        case "hiit": return "flame.fill"
        default: return "figure.mixed.cardio"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    HStack(alignment: .top, spacing: 16) {
                        // Icon
                        Image(systemName: categoryIcon)
                            .font(.system(size: 40))
                            .foregroundColor(primaryColor)
                            .frame(width: 60, height: 60)
                            .background(primaryColor.opacity(0.15))
                            .cornerRadius(12)

                        // Title and badge
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            // Source badge
                            HStack(spacing: 6) {
                                Image(systemName: sourceIcon)
                                    .font(.caption2)
                                Text(sourceType)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(sourceColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(sourceColor.opacity(0.15))
                            .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // NEW: Action buttons (Share & Copy)
                    if sharingViewModel != nil {
                        HStack(spacing: 12) {
                            // Share button (only for owned templates)
                            if template.userID != nil && template.status == .published {
                                Button {
                                    showingShareSheet = true
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }

                            // Copy button (for any accessible template)
                            Button {
                                showingCopySheet = true
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.vitalityTeal)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Quick Stats Section
                    HStack(spacing: 20) {
                        StatItem(
                            icon: "clock.fill",
                            value: "\(template.estimatedDurationMinutes ?? 60)",
                            label: "Minutes",
                            color: primaryColor
                        )

                        Divider()
                            .frame(height: 40)

                        StatItem(
                            icon: categoryIcon,
                            value: template.categoryDisplayName,
                            label: "Category",
                            color: primaryColor
                        )

                        Divider()
                            .frame(height: 40)

                        StatItem(
                            icon: "figure.strengthtraining.traditional",
                            value: "\(template.exerciseCount)",
                            label: "Exercises",
                            color: .growthGreen
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Description Section
                    if let description = template.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About This Workout")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    // Exercises Section
                    if !template.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises (\(template.exercises.count))")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(Array(template.exercises.enumerated()), id: \.element.id) {
                                    index, exercise in
                                    ExerciseRowView(
                                        exercise: exercise,
                                        isLast: index == template.exercises.count - 1
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    } else {
                        // Show message if no exercises
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)

                            HStack {
                                Image(systemName: "dumbbell")
                                    .foregroundColor(.secondary)
                                Text("No exercises added to this template yet.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }

                    // Favorite & Featured Controls
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferences")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            Toggle(
                                isOn: .init(
                                    get: { template.isFeatured },
                                    set: { _ in onToggleFeatured(template.id) }
                                )
                            ) {
                                HStack(spacing: 12) {
                                    Image(systemName: "pin.fill")
                                        .foregroundColor(.serenityLavender)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pin to Home")
                                            .font(.body)
                                        Text("Show this workout on your main screen")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.serenityLavender)
                            .padding()

                            Divider()
                                .padding(.leading, 56)

                            Toggle(
                                isOn: .init(
                                    get: { template.isFavorite },
                                    set: { _ in onToggleFavorite(template.id) }
                                )
                            ) {
                                HStack(spacing: 12) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.growthGreen)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add to Favorites")
                                            .font(.body)
                                        Text("Quick access to this workout")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.growthGreen)
                            .padding()
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Start Workout Button (Fixed at bottom)
                Button(action: {
                    dismiss()
                    onStart()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Start Workout")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let sharingViewModel = sharingViewModel {
                TemplateShareSheet(
                    viewModel: sharingViewModel,
                    templateId: template.id,
                    templateName: template.name
                )
            }
        }
        .sheet(isPresented: $showingCopySheet) {
            if let sharingViewModel = sharingViewModel {
                TemplateCopySheet(
                    viewModel: sharingViewModel,
                    templateId: template.id,
                    originalTemplateName: template.name,
                    onCopySuccess: { copiedTemplate in
                        // Template copied successfully
                        print("Template copied: \(copiedTemplate.name)")
                    }
                )
            }
        }
    }
}

// Helper component for exercise row
struct ExerciseRowView: View {
    let exercise: TemplateExercise
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Order index badge
                Text("\(exercise.orderIndex + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.vitalityTeal)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.exerciseName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Exercise details
                    HStack(spacing: 16) {
                        if let sets = exercise.sets, let reps = exercise.reps {
                            Label("\(sets) × \(reps)", systemImage: "repeat")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let weightKg = exercise.weightKg {
                            Label(
                                "\(String(format: "%.1f", weightKg)) kg", systemImage: "scalemass"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        if let restSeconds = exercise.restSeconds {
                            Label("\(restSeconds)s rest", systemImage: "timer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding()

            if !isLast {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }
}

// Helper component for stat items
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
