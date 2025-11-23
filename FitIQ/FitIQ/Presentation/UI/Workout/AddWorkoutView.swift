//
//  AddWorkoutView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import SwiftUI
import Observation


struct AddWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var viewModel: AddWorkoutViewModel
    
    let onSave: () -> Void
    
    private let primaryColor = Color.vitalityTeal // Fitness Theme

    init(viewModel: AddWorkoutViewModel, onSave: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // MARK: 1. Routine Metadata
                        VStack(alignment: .leading, spacing: 15) {
                            
                            // Name Input
                            TextField("Routine Name (e.g., Leg Day)", text: $viewModel.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .textFieldStyle(.roundedBorder)
                            
                            // Category Picker
                            Picker("Category", selection: $viewModel.selectedCategory) {
                                ForEach(WorkoutCategory.allCases.filter { $0 != .all }) { category in
                                    Label(category.rawValue, systemImage: category.iconName).tag(category)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            // Estimated Duration
                            HStack {
                                Text("Estimated Duration:")
                                Spacer()
                                Text("\(viewModel.estimatedDurationMinutes) min")
                                Stepper("", value: $viewModel.estimatedDurationMinutes, in: 10...180, step: 5).labelsHidden()
                            }
                            
                            // Equipment Toggle
                            Toggle("Equipment Required", isOn: $viewModel.equipmentRequired)
                        }
                        .padding(.horizontal)
                        
                        // MARK: 2. CONDITIONAL SETTINGS (Goal 1)
                        ConditionalWorkoutSettings(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        Divider()
                        
                        // MARK: 3. Exercise List (Placeholder for now)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Exercises (\(viewModel.plannedExercises.count))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                // Placeholder for ADD EXERCISE / AI BUTTONS (Next Step)
                                Button("Add/AI") { print("Open Exercise Selector / AI Chat") }
                            }
                            .padding(.horizontal)
                            
                            PlannedExercisesListView(exercises: $viewModel.plannedExercises)
                        }
                    }
                    .padding(.vertical)
                }
                
                // MARK: 4. Sticky Footer
                SaveWorkoutFooter(viewModel: viewModel, action: {
                    viewModel.saveWorkoutPlan()
                    dismiss()
                })
            }
            .navigationTitle("Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
