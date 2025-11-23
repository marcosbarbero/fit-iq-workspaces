import SwiftUI

/// A view for creating a new meal plan.
/// It allows the user to define the meal plan's name, description, meal type,
/// and provide raw text input for ingredients to be processed by AI later.
struct CreateMealPlanView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var description: String = "" // Retaining for plan's purpose/summary
    @State private var selectedMealType: MealType = .breakfast // Default meal type
    @State private var rawIngredientsText: String = "" // This state variable is now properly declared
    
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // Closure now correctly accepts both MealPlan and rawIngredientsText
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField(L10n.Navigation.Title.createMealPlan, text: $name)
                }
                
                Section(header: Text("Description")) { // Retained for plan summary
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    // Placeholder text for clarity
                                    Text("e.g., High-protein post-workout meal, Quick healthy dinner")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .allowsHitTesting(false) // Allows text editor to receive taps
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text(L10n.Nutrition.meal)) {
                    // Custom two-row grid for meal type selection, mimicking AddMealView
                    // This VStack correctly wraps the grid and applies listRowInsets
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
                    // Remove default row padding to let the grid fill the space
                    .listRowInsets(EdgeInsets())
                }
                
                // Section for raw ingredients input - Now correctly inside the Form
                Section(header: Text(L10n.Nutrition.foodAndDrink)) {
                    TextEditor(text: $rawIngredientsText)
                        .frame(minHeight: 150) // Larger input area for multiple lines
                        .overlay(
                            Group {
                                if rawIngredientsText.isEmpty {
                                    Text("e.g.,\n120g chicken breast\n100ml water\n60g of white rice\n\nAI will analyze this later...") // Example placeholder
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                // REMOVED: The macronutrient breakdown section entirely, as it's not relevant for raw input.
            } // This brace now correctly closes the Form
            .navigationTitle(L10n.Navigation.Title.createMealPlan)
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
            // REMOVED: .sheet(isPresented: $showingAddPlannedItemSheet) as `AddPlannedMealItemView` is no longer used.
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
        
        // When saving, we create a MealPlan entity with an empty `items` array initially.
        // The `rawIngredientsText` will be passed separately to the backend/use case
        // which will then parse this text and update the MealPlan with actual items.
        let newMealPlan = MealPlan(
            name: name,
            description: description.isEmpty ? nil : description,
            mealType: selectedMealType,
            items: [], // Items will be filled by AI after parsing `rawIngredientsText`
            source: .user, // Defaulting to .user for now, UI to select could be added later
            createdAt: Date()
        )
        
        // Pass both the basic plan and the raw ingredients text to the handler.
        onSave(newMealPlan, rawIngredientsText) 
        
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

struct CreateMealPlanView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview closure to correctly match the new `onSave` signature
        CreateMealPlanView { mealPlan, rawText in 
            print("Saved basic meal plan: \(mealPlan.name)")
            print("Raw Ingredients for AI processing: \n\(rawText)")
        }
    }
}
