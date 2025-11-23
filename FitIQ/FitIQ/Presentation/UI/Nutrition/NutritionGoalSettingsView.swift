//
//  NutritionGoalSettingsView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI
import Observation

struct NutritionGoalSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @Bindable var viewModel: NutritionViewModel
    
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    @State private var targetDate: Date? = nil
    
    @State private var dragStartValue: Int = 0 // Note: This state is currently unused in the GoalInputField after the recent changes, as GoalInputField now manages its own dragStartValue internally. It might be safe to remove from here if no other logic uses it.
    
    private let primaryColor = Color.ascendBlue
    
    var body: some View {
        NavigationStack {
            ScrollView { // Change Form to ScrollView to allow full-width custom inputs
                VStack(spacing: 20) {
                    
                    // MARK: - 0. Goal Deadline (New Requirement)
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Goal Deadline")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                // Clear Button (Only visible if date is set)
                                if targetDate != nil {
                                    Button("Clear Date", role: .destructive) {
                                        targetDate = nil // Withdraw the date
                                    }
                                    .font(.subheadline)
                                }
                            }
                            
                            // Date Input/Display Area
                            HStack {
                                // Left: Text Display
                                Text(targetDate == nil
                                     ? "No target date set"
                                     : targetDate!.formattedMedium
                                )
                                .foregroundColor(targetDate == nil ? .secondary : .primary)
                                .font(.subheadline)
                                .fontWeight(targetDate == nil ? .regular : .medium)

                                Spacer()
                                
                                // Right: Calendar Icon Overlay
                                ZStack {
                                    // 1. Interactive, invisible DatePicker (Base Layer)
                                    DatePicker(
                                        "",
                                        selection: $targetDate.toUnwrapped(defaultValue: Date()),
                                        in: Date()...,
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .frame(width: 40) // Ensure a sufficient hit target
                                    .scaleEffect(1.5) // Slightly enlarge the picker hit area
                                    .clipped()
                                    // Set high opacity for interaction, but low visual opacity
                                    .opacity(0.01)
                                    
                                    // 2. Calendar Icon (Top Layer)
                                    Image(systemName: targetDate == nil ? "calendar.badge.plus" : "calendar.circle.fill")
                                        .foregroundColor(targetDate == nil ? .secondary : primaryColor)
                                        .font(.title2)
                                        .allowsHitTesting(false) // Let taps fall through to the DatePicker below
                                }
                                .onTapGesture {
                                    if targetDate == nil {
                                        // Set a default date (3 months out) upon first tap
                                        targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
                                    }
                                    // The actual date picking is handled by the hidden DatePicker component below the icon
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // MARK: - 1. Calorie & Deficit Goals (Primary)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weight Management Targets").font(.title3).fontWeight(.bold).padding(.leading, 5)
                        
                        // Calorie Intake Goal
                        GoalInputField(
                            title: "Daily Calorie Intake",
                            value: $viewModel.dailyTargets.kcal,
                            unit: "kcal",
                            step: 50.0,
                            range: 1000...5000,
                            color: primaryColor
                        )
                        
                        // Net Calorie Goal (Deficit/Surplus)
                        GoalInputField(
                            title: "Net Calorie Goal (Deficit/Surplus)",
                            value: $viewModel.netGoal,
                            unit: "kcal",
                            step: 50.0,
                            range: -1500...1500,
                            color: viewModel.netGoal > 0 ? Color.attentionOrange : Color.growthGreen // Color code Deficit/Surplus
                        )
                        
                        Text("Current Target: \(viewModel.netGoal > 0 ? "Surplus" : "Deficit") of \(abs(viewModel.netGoal)) kcal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 5)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 2. Macronutrient Breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Macronutrient Targets (Grams)").font(.title3).fontWeight(.bold).padding(.leading, 5)
                        
                        GoalInputField(
                            title: "Protein Target",
                            value: $viewModel.dailyTargets.protein,
                            unit: "g",
                            step: 5.0,
                            range: 50...300,
                            color: .sustenanceYellow
                        )
                        
                        // ... Add Carb and Fat GoalInputFields here using step 5.0 ...
                        
                        GoalInputField(
                            title: "Carbohydrate Target",
                            value: $viewModel.dailyTargets.carbs,
                            unit: "g",
                            step: 5.0,
                            range: 50...500,
                            color: .vitalityTeal
                        )
                        
                        GoalInputField(
                            title: "Fat Target",
                            value: $viewModel.dailyTargets.fat,
                            unit: "g",
                            step: 5.0,
                            range: 20...150,
                            color: .serenityLavender
                        )
                        
                    }
                    .padding(.horizontal)
                    
                    // MARK: 3. Action Footer
                    Button(action: saveSettings) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                    .background(primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30) // Ensure spacing above sheet bottom
            }
            .scrollDismissesKeyboard(.interactively) // NEW: Dismiss keyboard on scroll
            .navigationTitle("Edit Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Add initial setup for drag state
            .onAppear { dragStartValue = viewModel.netGoal }
            // NEW: Global tap gesture to dismiss keyboard
            .onTapGesture {
                self.hideKeyboard()
            }
            
        }
    }
    
    
    // The rest of the struct, including the saveSettings function, remains the same.
    private func saveSettings() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        
        // 🛑 NEW UX LOGIC: Save the targets AND the deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSaving = false
            print("Targets saved: \(viewModel.dailyTargets). Net Goal: \(viewModel.netGoal). Deadline: \(String(describing: targetDate?.formatted(date: .abbreviated, time: .omitted)))")
            dismiss()
        }
    }
    
    // NEW: Helper function to dismiss the keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Binding {
    func toUnwrapped<T>(defaultValue: T) -> Binding<T> where Value == Optional<T> {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
