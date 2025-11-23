//
//  GoalCreationSheet.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

struct GoalCreationSheet: View {
    @Bindable var viewModel: CoachViewModel
    @Environment(\.dismiss) var dismiss
    
    // States for flexible user input
    @State private var goalDescription: String = ""
    @State private var targetUnit: String = "kg" // Simplified unit selection
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!

    private var isSaveDisabled: Bool {
        goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("What is your goal?") {
                    // Flexible Text Field for natural language input
                    TextField("E.g., Lose 5kg by Christmas, or workout 3x a week", text: $goalDescription, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                
                // MARK: - Dynamic Input Fields (Simplified for this phase)
                Section("Specific Target Details (Optional)") {
                    // Time/Date Input
                    DatePicker("Target Deadline", selection: $targetDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Goal") {
                        viewModel.createDeclarativeGoal(
                            title: goalDescription,
                            targetValue: 0,
                            unit: targetUnit,
                            date: targetDate
                        )
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                    .font(.headline)
                    .foregroundStyle(Color.ascendBlue)
                }
            }
        }
    }
}
