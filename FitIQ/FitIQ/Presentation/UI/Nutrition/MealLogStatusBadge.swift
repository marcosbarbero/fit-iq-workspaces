//
//  MealLogStatusBadge.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Status badge component for meal log processing states
//

import SwiftUI

/// Status badge component for displaying meal log processing status
///
/// Displays visual indicators for meal log states:
/// - Pending: Blue "Processing..." with clock icon
/// - Processing: Orange "AI Analyzing..." with animated spinner
/// - Completed: Green "Analyzed" with checkmark (auto-hides after 2s)
/// - Failed: Red "Analysis Failed" with error icon
///
/// **Usage:**
/// ```swift
/// MealLogStatusBadge(meal: dailyMealLog)
/// ```
struct MealLogStatusBadge: View {
    let meal: DailyMealLog

    @State private var showCompletedBadge = false

    var body: some View {
        Group {
            if meal.status == .pending {
                pendingBadge
            } else if meal.status == .processing {
                processingBadge
            } else if meal.status == .failed {
                errorBadge
            } else if meal.status == .completed && showCompletedBadge {
                completedBadge
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            // Show completed badge briefly when meal appears as completed
            if meal.status == .completed {
                showCompletedBadge = true

                // Auto-hide after 2 seconds
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        showCompletedBadge = false
                    }
                }
            }
        }
        .onChange(of: meal.status) { oldValue, newValue in
            if newValue == .completed {
                // Show badge with animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCompletedBadge = true
                }

                // Haptic feedback for success
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                // Auto-hide after 2 seconds
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        showCompletedBadge = false
                    }
                }
            } else if newValue == .failed {
                // Haptic feedback for error
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }

    // MARK: - Badge Variants

    private var pendingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12))

            Text("Processing...")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
        .accessibilityLabel("Meal log is being processed")
    }

    private var processingBadge: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.small)
                .tint(.orange)

            Text("AI Analyzing...")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
        .accessibilityLabel("AI is analyzing your meal")
    }

    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))

            Text("Analyzed")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
        .accessibilityLabel("Meal analyzed successfully")
    }

    private var errorBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))

                Text("Analysis Failed")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)
        }
        .accessibilityLabel("Meal analysis failed, tap to retry")
        .accessibilityHint("Double tap to retry analysis")
    }
}

// MARK: - Compact Badge Variant

/// Compact version of status badge (icon only)
struct MealLogStatusBadgeCompact: View {
    let meal: DailyMealLog

    var body: some View {
        Group {
            if meal.status == .pending {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
            } else if meal.status == .processing {
                ProgressView()
                    .controlSize(.small)
                    .tint(.orange)
            } else if meal.status == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 14))
        .accessibilityLabel(meal.statusText)
    }
}

// MARK: - Preview

#Preview("Pending Status") {
    VStack(spacing: 16) {
        MealLogStatusBadge(
            meal: DailyMealLog(
                id: UUID(),
                description: "2 eggs, toast, coffee",
                time: Date(),
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                sugar: 0,
                fiber: 0,
                saturatedFat: 0,
                sodiumMg: 0,
                ironMg: 0,
                vitaminCmg: 0,
                status: .pending,
                syncStatus: .pending,
                backendID: nil,
                rawInput: "2 eggs, toast, coffee",
                mealType: .breakfast,
                items: []
            ))
    }
    .padding()
}

#Preview("Processing Status") {
    VStack(spacing: 16) {
        MealLogStatusBadge(
            meal: DailyMealLog(
                id: UUID(),
                description: "2 eggs, toast, coffee",
                time: Date(),
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                sugar: 0,
                fiber: 0,
                saturatedFat: 0,
                sodiumMg: 0,
                ironMg: 0,
                vitaminCmg: 0,
                status: .processing,
                syncStatus: .syncing,
                backendID: "123",
                rawInput: "2 eggs, toast, coffee",
                mealType: .breakfast,
                items: []
            ))
    }
    .padding()
}

#Preview("Completed Status") {
    VStack(spacing: 16) {
        MealLogStatusBadge(
            meal: DailyMealLog(
                id: UUID(),
                description: "2 eggs, toast, coffee",
                time: Date(),
                calories: 295,
                protein: 18,
                carbs: 20,
                fat: 15,
                sugar: 2,
                fiber: 3,
                saturatedFat: 4,
                sodiumMg: 300,
                ironMg: 2.5,
                vitaminCmg: 0,
                status: .completed,
                syncStatus: .synced,
                backendID: "123",
                rawInput: "2 eggs, toast, coffee",
                mealType: .breakfast,
                items: []
            ))
    }
    .padding()
}

#Preview("Failed Status") {
    VStack(spacing: 16) {
        MealLogStatusBadge(
            meal: DailyMealLog(
                id: UUID(),
                description: "2 eggs, toast, coffee",
                time: Date(),
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                sugar: 0,
                fiber: 0,
                saturatedFat: 0,
                sodiumMg: 0,
                ironMg: 0,
                vitaminCmg: 0,
                status: .failed,
                syncStatus: .failed,
                backendID: "123",
                rawInput: "2 eggs, toast, coffee",
                mealType: .breakfast,
                items: []
            ))
    }
    .padding()
}

#Preview("Compact Badges") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            MealLogStatusBadgeCompact(
                meal: DailyMealLog(
                    id: UUID(),
                    description: "Test",
                    time: Date(),
                    calories: 0,
                    protein: 0,
                    carbs: 0,
                    fat: 0,
                    sugar: 0,
                    fiber: 0,
                    saturatedFat: 0,
                    sodiumMg: 0,
                    ironMg: 0,
                    vitaminCmg: 0,
                    status: .pending,
                    syncStatus: .pending,
                    backendID: nil,
                    rawInput: "Test",
                    mealType: .breakfast,
                    items: []
                ))

            MealLogStatusBadgeCompact(
                meal: DailyMealLog(
                    id: UUID(),
                    description: "Test",
                    time: Date(),
                    calories: 0,
                    protein: 0,
                    carbs: 0,
                    fat: 0,
                    sugar: 0,
                    fiber: 0,
                    saturatedFat: 0,
                    sodiumMg: 0,
                    ironMg: 0,
                    vitaminCmg: 0,
                    status: .processing,
                    syncStatus: .syncing,
                    backendID: "123",
                    rawInput: "Test",
                    mealType: .breakfast,
                    items: []
                ))

            MealLogStatusBadgeCompact(
                meal: DailyMealLog(
                    id: UUID(),
                    description: "Test",
                    time: Date(),
                    calories: 0,
                    protein: 0,
                    carbs: 0,
                    fat: 0,
                    sugar: 0,
                    fiber: 0,
                    saturatedFat: 0,
                    sodiumMg: 0,
                    ironMg: 0,
                    vitaminCmg: 0,
                    status: .failed,
                    syncStatus: .failed,
                    backendID: "123",
                    rawInput: "Test",
                    mealType: .breakfast,
                    items: []
                ))
        }
    }
    .padding()
}
