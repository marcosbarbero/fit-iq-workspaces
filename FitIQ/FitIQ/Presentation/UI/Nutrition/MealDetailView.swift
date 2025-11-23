//
//  MealDetailView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

struct MealDetailView: View {
    @Environment(\.dismiss) var dismiss

    let meal: DailyMealLog  // Data passed directly from the tapped row
    let onMealUpdated: (DailyMealLog?) -> Void  // Callback for confirmation (photo recognition only)
    let isPhotoRecognition: Bool  // Flag to determine if this is a photo recognition review
    let onEditTapped: (() -> Void)?  // Callback for Edit button
    let onDeleteTapped: (() -> Void)?  // Callback for Delete button

    @State private var isEditing = false

    // Colors assumed to be available
    private let primaryColor = Color.ascendBlue
    private let primaryMacroColor = Color.sustenanceYellow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {

                    // MARK: 1. Meal Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.description)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Text("Logged at \(meal.time.formatted(.dateTime.hour().minute()))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: 2. Macro Summary Pills (Visual anchor)
                    MacroPillSummary(meal: meal)
                        .padding(.horizontal)

                    // MARK: 3. Food Items List
                    if !meal.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Items")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            ForEach(meal.items.sorted(by: { $0.orderIndex < $1.orderIndex })) {
                                item in
                                MealItemRow(item: item)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // MARK: 4. Full Nutritional Panel (Micronutrient Breakdown)
                    VStack(alignment: .leading) {
                        Text("Detailed Nutritional Analysis")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)
                            .padding(.horizontal)

                        NutrientBreakdownList(nutrients: meal.fullNutrientList)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle(meal.mealType.displayString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPhotoRecognition {
                    // Photo Recognition Flow: Show Cancel and Save
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onMealUpdated(nil)  // Signal cancellation - parent handles dismiss
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onMealUpdated(meal)  // Signal confirmation/save - parent handles dismiss
                        }
                        .fontWeight(.semibold)
                    }

                    // Optional: Edit button for photo recognition
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if let onEditTapped = onEditTapped {
                                onEditTapped()
                            }
                        } label: {
                            Text("Edit")
                        }
                    }
                } else {
                    // Normal Meal Detail Flow: Show Done and Menu
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }

                    // Action Menu for Edit/Delete
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit Meal") {
                                if let onEditTapped = onEditTapped {
                                    onEditTapped()
                                } else {
                                    print("Action: Edit not implemented for this view")
                                    dismiss()
                                }
                            }
                            Button("Delete Meal", role: .destructive) {
                                if let onDeleteTapped = onDeleteTapped {
                                    onDeleteTapped()
                                } else {
                                    print("Action: Delete not implemented for this view")
                                    dismiss()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Meal Item Row

struct MealItemRow: View {
    let item: MealLogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Food type indicator
                Text(item.foodType.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(item.quantityDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Calories
                Text("\(Int(item.calories)) kcal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.ascendBlue)
            }

            // Macros
            HStack(spacing: 16) {
                MacroLabel(label: "P", value: item.protein, color: .sustenanceYellow)
                MacroLabel(label: "C", value: item.carbs, color: .vitalityTeal)
                MacroLabel(label: "F", value: item.fat, color: .serenityLavender)

                Spacer()

                // Confidence indicator (if available)
                if let confidence = item.confidence {
                    ConfidenceBadge(confidence: confidence)
                }
            }
            .font(.caption2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Macro Label

struct MacroLabel: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text("\(Int(value))g")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: Double

    private var badgeColor: Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    private var badgeText: String {
        let percentage = Int(confidence * 100)
        return "\(percentage)% confident"
    }

    var body: some View {
        Text(badgeText)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(4)
    }
}
