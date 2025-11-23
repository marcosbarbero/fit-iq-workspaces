//
//  NutritionUIHelpers.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

struct NaturalLanguageInputView: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let isProcessing: Bool
    let onCommit: () -> Void

    var body: some View {
        HStack {
            TextField("e.g., 1 scoop of protein powder and 1 banana", text: $query, axis: .vertical)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(onCommit)

            if isProcessing {
                ProgressView()
            } else if !query.isEmpty {
                Button(action: onCommit) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.ascendBlue)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct InputToolBarView: View {
    let onMicTap: () -> Void
    let onCameraTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onMicTap) {
                Label("Voice", systemImage: "mic.fill")
            }
            .padding(.horizontal, 10)

            Button(action: onCameraTap) {
                Label("Photo", systemImage: "camera.fill")
            }
            .padding(.horizontal, 10)

            Spacer()
        }
    }
}

// Helper Component: LoggedItemsListView (REVISED)

struct LoggedItemsListView: View {
    let items: [LoggedItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(items) { item in
                VStack(spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.growthGreen)
                            .padding(.top, 2)

                        // Item Name (Primary label)
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            // 🛑 NEW: Quantity/Serving Size
                            Text(item.quantityDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Calories (Right aligned, primary focus)
                        Text("\(item.calories) kcal")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.ascendBlue)
                    }

                    // 🛑 NEW: Macro Breakdown Bar (Secondary info)
                    MacroSummaryBar(item: item)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color(.secondarySystemBackground))
            }
        }
        .cornerRadius(10)
    }
}

// Helper struct for compact macro display
struct MacroSummaryBar: View {
    let item: LoggedItem

    var body: some View {
        HStack(spacing: 8) {
            // Protein
            MacroDetailView(value: item.protein, unit: "P", color: .sustenanceYellow)
            // Carbs
            MacroDetailView(value: item.carbs, unit: "C", color: .vitalityTeal)
            // Fat
            MacroDetailView(value: item.fat, unit: "F", color: .serenityLavender)
            Spacer()
        }
        .padding(.horizontal, 25)  // Indent to align below the main name
    }
}

// Helper struct for each individual macro value
struct MacroDetailView: View {
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text("\(String(format: "%.1f", value))")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct SaveMealFooter: View {
    let totalCalories: Int
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Add Meal")
                    .fontWeight(.bold)
                Spacer()
                Text("\(totalCalories) kcal")
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isReady ? Color.ascendBlue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(15)
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .disabled(!isReady)
    }
}

// Macro Summary Pills
struct MacroPillSummary: View {
    let meal: DailyMealLog

    var body: some View {
        HStack {
            MacroPill(value: "\(meal.protein)", unit: "P", color: .sustenanceYellow)
            MacroPill(value: "\(meal.carbs)", unit: "C", color: .vitalityTeal)
            MacroPill(value: "\(meal.fat)", unit: "F", color: .serenityLavender)
            Spacer()
            // Total Calories as main anchor
            Text("\(meal.calories) kcal")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.ascendBlue)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct MacroPill: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// Full Micronutrient Breakdown List
struct NutrientBreakdownList: View {
    let nutrients: [(name: String, amount: String, color: Color)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(nutrients, id: \.name) { nutrient in
                HStack {
                    Circle()
                        .fill(nutrient.color.opacity(0.7))
                        .frame(width: 8, height: 8)
                    Text(nutrient.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(nutrient.amount)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal)

                Divider()  // Visual separator between nutrients
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
}

// Helper struct for Stepper input fields

struct StepperField: View {
    let title: String
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>
    let step: Int
    var color: Color = .primary  // Defaults to system primary color

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                Text("Target: \(value) \(unit)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            Spacer()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding(.vertical, 5)
    }
}

// Helper Component: GoalInputField (Adapted from BodyMassEntryView UX)

struct GoalInputField: View {
    let title: String
    @Binding var value: Int  // We bind to an Int for kcal/gram targets
    let unit: String
    let step: Double  // Drag step size (e.g., 50 for kcal, 1 for grams)
    let minRange: Int
    let maxRange: Int
    let color: Color

    @State private var inputString: String = ""
    @State private var dragStartValue: Int = 0
    @FocusState private var isInputFocused: Bool

    @State private var lastReportedValueForHaptics: Int = 0  // For haptic feedback during drag

    init(
        title: String, value: Binding<Int>, unit: String, step: Double, range: ClosedRange<Int>,
        color: Color
    ) {
        self.title = title
        self._value = value
        self.unit = unit
        self.step = step
        self.minRange = range.lowerBound
        self.maxRange = range.upperBound
        self.color = color
    }

    // MARK: Helpers
    private var parsedValue: Int? {
        // Only consider the input as a valid number if it can be converted to an Int
        Int(inputString)
    }

    // This function commits the typed value, parsing, clamping, and updating the bound 'value'
    private func commitChanges() {
        if let parsed = parsedValue {
            // Clamp the parsed value to the allowed range
            let clamped = max(minRange, min(maxRange, parsed))
            value = clamped
            // Ensure inputString reflects the clamped, valid value
            inputString = String(clamped)
        } else {
            // If inputString is invalid (e.g., empty or non-numeric), revert to the current bound 'value'
            inputString = String(value)
        }
        dragStartValue = value  // Update dragStartValue for consistency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                ZStack {
                    // Large Text Display (Default view, when not focused)
                    Text(String(value))  // Explicitly convert Int to String to avoid commas
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .contentTransition(.numericText())
                        .opacity(isInputFocused ? 0 : 1)
                        .lineLimit(1)

                    // TextField (Input view, when focused)
                    TextField("", text: $inputString)
                        .keyboardType(.numberPad)  // Reverted to .numberPad as requested
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .focused($isInputFocused)
                        // The onChange for inputString is removed to allow typing arbitrary values
                        .opacity(isInputFocused ? 1 : 0)
                }
                .onTapGesture { isInputFocused = true }  // Tapping on display text focuses the TextField

                Text(unit)
                    .font(.callout)
                    .foregroundColor(.secondary)

                if !isInputFocused {
                    Text("Drag vertically to adjust or tap to edit")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(color.opacity(isInputFocused ? 0.6 : 0.3), lineWidth: 2)
            )
            // MARK: Drag Gesture (Revised for smoother control and haptics)
            .gesture(
                isInputFocused
                    ? nil
                    : DragGesture()  // Disable drag while focused for typing
                        .onChanged { gesture in
                            // Define how many pixels of vertical drag correspond to one full 'step' change.
                            // A higher value means less sensitive (more drag needed for one step change).
                            let pixelsForOneStep: Double = 30.0  // Adjust this value to fine-tune sensitivity

                            // Calculate how many 'steps' have been traversed based on drag distance
                            let numberOfStepsTraversed =
                                -gesture.translation.height / pixelsForOneStep

                            // Calculate the raw value change by multiplying steps traversed by the step size
                            let rawValueChange = numberOfStepsTraversed * step

                            // Calculate the proposed value based on dragStartValue and the raw value change
                            let proposedValue = Double(dragStartValue) + rawValueChange

                            // Snap the proposed value to the nearest multiple of 'step'
                            let snappedValue = Int(round(proposedValue / step) * step)

                            // Clamp the value to the defined range
                            let clampedValue = max(minRange, min(maxRange, snappedValue))

                            // Only update if there's a real change to avoid unnecessary re-renders
                            if clampedValue != value {
                                value = clampedValue
                                // Keep inputString in sync with dragged value for display consistency
                                inputString = String(clampedValue)

                                // Haptic feedback for each 'step' increment/decrement
                                if abs(value - lastReportedValueForHaptics) >= Int(step) {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    lastReportedValueForHaptics = value
                                }
                            }
                        }
                        .onEnded { _ in
                            dragStartValue = value  // Update dragStartValue for the next gesture
                        }
            )
            .onAppear {
                // Initialize inputString with the current bound value and drag state
                inputString = String(value)  // Explicitly convert Int to String
                dragStartValue = value
                lastReportedValueForHaptics = value
            }
            // MARK: Handle focus changes to commit typed value
            .onChange(of: isInputFocused) { oldFocus, newFocus in
                if oldFocus && !newFocus {  // Lost focus: commit changes
                    commitChanges()
                } else if newFocus {  // Gained focus: ensure inputString reflects current value for editing
                    inputString = String(value)  // Explicitly convert Int to String
                }
            }
            // Dismiss keyboard on drag start, but only if it's currently focused
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    if isInputFocused { isInputFocused = false }
                }
            )
        }
        // Removed the conflicting .onTapGesture and .contentShape from here.
    }
}
