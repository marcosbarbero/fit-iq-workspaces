import SwiftUI

/// A view for adding or editing a single planned meal item within a meal plan.
/// This view collects the description and estimated nutritional values for an item.
struct AddPlannedMealItemView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var description: String = ""
    @State private var estimatedCalories: String = ""
    @State private var estimatedProtein: String = ""
    @State private var estimatedCarbs: String = ""
    @State private var estimatedFat: String = ""
    
    var onAddItem: (PlannedMealItem) -> Void
    
    // Helper to convert String to Double safely, defaulting to 0.0 for invalid input
    private func doubleFromString(_ string: String) -> Double {
        Double(string) ?? 0.0
    }
    
    // Determines if the form is valid for submission.
    // Requires a non-empty description and at least one macro value greater than zero.
    private var isFormValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (doubleFromString(estimatedCalories) > 0 ||
         doubleFromString(estimatedProtein) > 0 ||
         doubleFromString(estimatedCarbs) > 0 ||
         doubleFromString(estimatedFat) > 0)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.Nutrition.meal)) {
                    // Changed L10n.Common.name to literal string "Name"
                    TextField("Name", text: $description)
                }
                
                Section(header: Text(L10n.Nutrition.calories)) {
                    HStack {
                        TextField(L10n.Nutrition.caloriesKcal, text: $estimatedCalories)
                            .keyboardType(.numberPad)
                        Text(L10n.Unit.kcal)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text(L10n.Nutrition.protein)) {
                    HStack {
                        TextField(L10n.Nutrition.proteinG, text: $estimatedProtein)
                            .keyboardType(.numberPad)
                        Text(L10n.Unit.g)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text(L10n.Nutrition.carbs)) {
                    HStack {
                        TextField(L10n.Nutrition.carbsG, text: $estimatedCarbs)
                            .keyboardType(.numberPad)
                        Text(L10n.Unit.g)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text(L10n.Nutrition.fat)) {
                    HStack {
                        TextField(L10n.Nutrition.fatG, text: $estimatedFat)
                            .keyboardType(.numberPad)
                        Text(L10n.Unit.g)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.Common.add)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        let newItem = PlannedMealItem(
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            estimatedCalories: doubleFromString(estimatedCalories),
                            estimatedProtein: doubleFromString(estimatedProtein),
                            estimatedCarbs: doubleFromString(estimatedCarbs),
                            estimatedFat: doubleFromString(estimatedFat)
                        )
                        onAddItem(newItem)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? .ascendBlue : .secondary)
                }
            }
        }
    }
}

struct AddPlannedMealItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddPlannedMealItemView { item in
            print("Added item: \(item.description)")
        }
    }
}
