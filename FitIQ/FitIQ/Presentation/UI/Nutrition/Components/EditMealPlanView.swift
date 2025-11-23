//
//  EditMealPlanView.swift
//
//  A view for editing an existing meal plan.
//  It pre-fills fields with the existing meal plan data and allows modifications.
//

import SwiftUI

/// A view for editing an existing meal plan.
/// It pre-fills fields with the existing meal plan's name, description, meal type,
/// and raw text input for ingredients. Changes are passed back via a closure.
struct EditMealPlanView: View {
    @Environment(\.dismiss) var dismiss
    
    // The original meal plan being edited
    let originalMealPlan: MealPlan
    
    // State variables for editing
    @State private var name: String
    @State private var description: String
    @State private var selectedMealType: MealType
    @State private var rawIngredientsText: String
    
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // Closure now correctly accepts the UPDATED MealPlan and rawIngredientsText
    var onSave: (MealPlan, String) -> Void
    
    // Determines if the save button should be enabled.
    // Requires a non-empty name and non-empty raw ingredients text.
    private var isSaveButtonEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !rawIngredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Colors
    private let primaryAccent = Color.ascendBlue
    // Grid layout for meal type buttons
    private let gridColumns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    // Define the meal types for each row, excluding .water as per original logic
    private let firstRowMealTypes: [MealType] = [.breakfast, .lunch, .dinner, .snack]
    private let secondRowMealTypes: [MealType] = [.drink, .supplements, .other]
    
    /// Initializes the view with an existing meal plan.
    /// - Parameters:
    ///   - mealPlan: The `MealPlan` object to be edited.
    ///   - rawIngredientsText: The original raw ingredients text associated with the meal plan (if available).
    ///   - onSave: A closure to call when the meal plan is saved, providing the updated `MealPlan` and raw text.
    init(mealPlan: MealPlan, initialRawIngredientsText: String, onSave: @escaping (MealPlan, String) -> Void) {
        self.originalMealPlan = mealPlan
        self._name = State(initialValue: mealPlan.name)
        self._description = State(initialValue: mealPlan.description ?? "")
        self._selectedMealType = State(initialValue: mealPlan.mealType)
        self._rawIngredientsText = State(initialValue: initialRawIngredientsText) // Use the provided raw text
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField(L10n.Navigation.Title.editMealPlan, text: $name)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("e.g., High-protein post-workout meal, Quick healthy dinner")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text(L10n.Nutrition.meal)) {
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(firstRowMealTypes, id: \.self) { type in
                                MealTypeButton(
                                    type: type,
                                    selectedMealType: $selectedMealType,
                                    primaryAccent: primaryAccent
                                )
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 15)
                        
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(secondRowMealTypes, id: \.self) { type in
                                MealTypeButton(
                                    type: type,
                                    selectedMealType: $selectedMealType,
                                    primaryAccent: primaryAccent
                                )
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.bottom, 15)
                    }
                    .listRowInsets(EdgeInsets())
                }
                
                Section(header: Text(L10n.Nutrition.foodAndDrink)) {
                    TextEditor(text: $rawIngredientsText)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if rawIngredientsText.isEmpty {
                                    Text("e.g.,\n120g chicken breast\n100ml water\n60g of white rice\n\nAI will analyze this later...")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
            }
            .navigationTitle(L10n.Navigation.Title.editMealPlan)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        saveMealPlan()
                    }
                    .disabled(!isSaveButtonEnabled)
                    .foregroundColor(isSaveButtonEnabled ? .ascendBlue : .secondary)
                }
            }
            .alert(L10n.Error.generic, isPresented: $showingAlert) {
                Button(L10n.Common.ok) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveMealPlan() {
        guard isSaveButtonEnabled else {
            alertMessage = L10n.Error.saveFailed
            showingAlert = true
            return
        }
        
        // Create a new MealPlan instance with updated values, retaining the original ID
        let updatedMealPlan = MealPlan(
            id: originalMealPlan.id, // Crucially, retain the original ID
            name: name,
            description: description.isEmpty ? nil : description,
            mealType: selectedMealType,
            items: originalMealPlan.items, // Keep original items for now, AI will re-parse raw text
            source: originalMealPlan.source,
            createdAt: originalMealPlan.createdAt,
            createdBy: originalMealPlan.createdBy
        )
        
        // Pass both the updated plan and the raw ingredients text to the handler.
        onSave(updatedMealPlan, rawIngredientsText)
        
        dismiss()
    }
}

/// A reusable button component for selecting a MealType.
/// Copied from AddMealView to ensure consistent styling.
private struct MealTypeButton: View {
    let type: MealType
    @Binding var selectedMealType: MealType
    let primaryAccent: Color
    
    var isSelected: Bool {
        selectedMealType == type
    }
    
    var body: some View {
        Button(action: {
            selectedMealType = type
        }) {
            Text(type.displayString)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? primaryAccent : Color(.systemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain) // Essential in a Form
    }
}

struct EditMealPlanView_Previews: PreviewProvider {
    static var previews: some View {
        let mockMealPlan = MealPlan(
            id: UUID(),
            name: "Edited Breakfast Plan",
            description: "A high-fiber breakfast, now with more protein.",
            mealType: .breakfast,
            items: [], // Assuming items would be re-parsed from raw text
            source: .user,
            createdAt: Date()
        )
        
        let initialRawText = "2 eggs\n1 whole-wheat toast\n50g spinach\n50g berries"
        
        EditMealPlanView(mealPlan: mockMealPlan, initialRawIngredientsText: initialRawText) { updatedMealPlan, rawText in
            print("Updated meal plan: \(updatedMealPlan.name)")
            print("Updated raw ingredients: \(rawText)")
        }
    }
}
