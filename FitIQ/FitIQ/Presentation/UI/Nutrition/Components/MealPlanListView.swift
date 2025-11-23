import SwiftUI
import Foundation // For Date formatting

// MARK: - MealPlanRow (Individual Meal Plan Item)

struct MealPlanRow: View {
    let mealPlan: MealPlan
    let onDelete: (UUID) -> Void // Action to delete a meal plan
    let onSelect: (MealPlan) -> Void // Action when the row is tapped (now for edit OR choose)

    // UI-specific logic for MealPlanSource (moved from extension)
    private var sourceIconName: String {
        switch mealPlan.source {
        case .user: return "person.fill"
        case .ai: return "sparkles.2"
        case .nutritionist: return "stethoscope.circle.fill" // Reverted to correct SF Symbol
        }
    }
    
    // UI-specific logic for MealPlanSource tint color (moved from extension)
    private var sourceTintColor: Color {
        switch mealPlan.source {
        case .user: return .secondary // Neutral for user-created
        case .ai: return .ascendBlue // Ascend Blue for AI Companion
        case .nutritionist: return .serenityLavender // Serenity Lavender for Wellness/Guidance
        }
    }

    // UI-specific logic for MealType icon name (moved from extension)
    private var mealTypeIconName: String {
        switch mealPlan.mealType {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        case .drink: return "cup.and.saucer.fill"
        case .water: return "drop.fill"
        case .supplements: return "pills.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var body: some View {
        // Changed: Removed the outer Button and applied modifiers directly to the VStack
        VStack(alignment: .leading, spacing: 8) {
            // Header: Name, Meal Type, Source Icon
            HStack(alignment: .top) {
                Image(systemName: mealTypeIconName) // Using local computed property
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.ascendBlue) // Using Ascend Blue for primary meal type indication
                
                VStack(alignment: .leading) {
                    Text(mealPlan.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mealPlan.mealType.displayString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Source Indicator (AI, User, Nutritionist) - Only icon, no text label as requested
                Image(systemName: sourceIconName) // Using local computed property
                    .font(.caption)
                    .foregroundColor(sourceTintColor) // Using local computed property
            }
            .padding(.bottom, 2)

            // Meal Items Overview
            if !mealPlan.items.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(mealPlan.items.prefix(3)) { item in
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundColor(.secondary)
                            Text(item.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if mealPlan.items.count > 3 {
                        Text(L10n.Format.moreItems(mealPlan.items.count - 3))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
                .padding(.bottom, 4)
            }

            // Macronutrient Breakdown
            HStack(spacing: 12) {
                // Calories
                HStack(spacing: 4) { // Smaller spacing between icon and value
                    Image(systemName: "flame.fill")
                    Text("\(Int(mealPlan.totalCalories))")
                }
                .font(.caption)
                .foregroundColor(.attentionOrange)
                
                // Protein
                HStack(spacing: 4) { // Smaller spacing between icon and value
                    Image(systemName: "p.circle.fill")
                    Text("\(Int(mealPlan.totalProtein))")
                }
                .font(.caption)
                .foregroundColor(.ascendBlue)
                
                // Carbs
                HStack(spacing: 4) { // Smaller spacing between icon and value
                    Image(systemName: "c.circle.fill")
                    Text("\(Int(mealPlan.totalCarbs))\(L10n.Unit.g)")
                }
                .font(.caption)
                .foregroundColor(.growthGreen)
                
                // Fat
                HStack(spacing: 4) { // Smaller spacing between icon and value
                    Image(systemName: "f.circle.fill")
                    Text("\(Int(mealPlan.totalFat))\(L10n.Unit.g)")
                }
                .font(.caption)
                .foregroundColor(.serenityLavender)
            }
            // The outer .font(.caption) and .foregroundColor(.secondary) are now redundant
            // as they are applied to each individual HStack.
        }
        .padding(.vertical, 12) // Internal vertical padding for the card content
        .padding(.horizontal, 15)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle()) // Makes the whole area tappable
        .swipeActions(edge: .trailing) { // Applied directly to the VStack
            Button(role: .destructive) {
                onDelete(mealPlan.id)
            } label: {
                Label(L10n.Common.delete, systemImage: "trash.fill")
            }
            // Add an edit button as a swipe action
            Button {
                onSelect(mealPlan) // Trigger onSelect which will now prepare for editing
            } label: {
                Label(L10n.Common.edit, systemImage: "pencil")
            }
            .tint(.ascendBlue) // Use primary accent color for edit
        }
        .onTapGesture { // Applied directly to the VStack for selection
            onSelect(mealPlan) // This `onSelect` is now handled by MealPlanListView
        }
        // .buttonStyle(.plain) is no longer needed as there's no outer Button
    }
}

// MARK: - MealPlanListView (List of Meal Plans)

struct MealPlanListView: View {
    @Environment(\.dismiss) var dismiss
    // This view will eventually receive meal plan data from a ViewModel.
    // For now, it accepts an array and closures for actions.
    @Binding var mealPlans: [MealPlan] // Data source - Changed to @Binding for live updates in preview
    let onDelete: (UUID) -> Void // Action for deleting a meal plan
    let onUpdate: (MealPlan, String) -> Void // NEW: Action for updating a meal plan
    // NEW: Optional closure for selecting a plan to quick-add (e.g., in AddMealView)
    let onChoosePlan: ((MealPlan) -> Void)?
    
    // NEW: State for showing the new meal plan creation view
    @State private var showingCreateMealPlanSheet: Bool = false
    
    // NEW: State for showing the meal plan edit view
    @State private var showingEditMealPlanSheet: Bool = false
    @State private var selectedMealPlanForEdit: MealPlan? = nil
    @State private var initialRawIngredientsTextForEdit: String = "" // To store original raw text

    var body: some View {
        ZStack(alignment: .bottomTrailing) { // Use ZStack for FAB
            NavigationStack {
                Group {
                    if mealPlans.isEmpty {
                        ContentUnavailableView(
                            L10n.Nutrition.mealPlans,
                            systemImage: "fork.knife.circle",
                            description: Text(L10n.Nutrition.createFirstMealPlan)
                        )
                    } else {
                        // MARK: - CHANGE: Using List with ForEach and listRowInsets for spacing control
                        List {
                            ForEach(mealPlans) { mealPlan in
                                MealPlanRow(mealPlan: mealPlan, onDelete: onDelete) { selectedPlan in
                                    // Conditional logic for `onSelect` in MealPlanRow
                                    if let onChoosePlan = onChoosePlan {
                                        // If onChoosePlan is provided, call it and dismiss
                                        onChoosePlan(selectedPlan)
                                        dismiss() // Dismiss the MealPlanListView sheet
                                    } else {
                                        // Otherwise, trigger the internal editing flow
                                        self.selectedMealPlanForEdit = selectedPlan
                                        // Placeholder for initial raw ingredients text for editing.
                                        // In a real app, this would be retrieved from a data source or ViewModel.
                                        self.initialRawIngredientsTextForEdit = generateMockRawIngredients(for: selectedPlan)
                                        self.showingEditMealPlanSheet = true
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)) // Explicit vertical spacing between rows
                            }
                        }
                        .listStyle(.plain)
                        .padding(.horizontal, 12) // Apply horizontal padding to the List itself
                        .padding(.bottom, 80) // Add padding for FAB
                    }
                }
                .navigationTitle(L10n.Navigation.Title.mealPlans)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.Common.done) { // Renamed "Cancel" to "Done"
                            dismiss()
                        }
                        .foregroundColor(.ascendBlue)
                    }
                    // Removed "Add" button from toolbar as requested
                }
            }

            // NEW: FAB button to add a new meal plan
            ActionFAB(action: {
                showingCreateMealPlanSheet = true
            }, color: .ascendBlue, systemImageName: "plus")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        // NEW: Sheet for the new meal plan creation view
        .sheet(isPresented: $showingCreateMealPlanSheet) {
            CreateMealPlanView { newMealPlan, rawIngredientsText in
                // In a real application, this would pass the newMealPlan and rawIngredientsText
                // to a ViewModel which would then handle persistence via a UseCase and Repository.
                // For this task, we'll just print it.
                print("New Meal Plan Created: \(newMealPlan.name)")
                print("Raw Items for AI processing: \(rawIngredientsText)")
                // For preview/demonstration, add to the local array
                mealPlans.append(newMealPlan)
            }
        }
        // NEW: Sheet for the meal plan edit view
        .sheet(item: $selectedMealPlanForEdit) { mealPlanToEdit in
            EditMealPlanView(
                mealPlan: mealPlanToEdit,
                initialRawIngredientsText: initialRawIngredientsTextForEdit // Pass the stored raw text
            ) { updatedMealPlan, updatedRawIngredientsText in
                onUpdate(updatedMealPlan, updatedRawIngredientsText)
                // For preview/demonstration, update the local array
                if let index = mealPlans.firstIndex(where: { $0.id == updatedMealPlan.id }) {
                    mealPlans[index] = updatedMealPlan
                    // In a real app, you might also store/update updatedRawIngredientsText
                    // associated with the meal plan ID here.
                }
            }
        }
    }
    
    // Helper function to generate mock raw ingredients text for editing
    private func generateMockRawIngredients(for mealPlan: MealPlan) -> String {
        // This is a placeholder. In a real app, this data would come from the backend/storage.
        // For demonstration, we'll construct it from the existing items or just use a generic text.
        if !mealPlan.items.isEmpty {
            return mealPlan.items.map { item in
                "\(item.description) (\(Int(item.estimatedCalories))kcal)"
            }.joined(separator: "\n")
        } else {
            return "No raw ingredients available. Add some now!"
        }
    }
}

// MARK: - Previews (for development purposes)
struct MealPlanListView_Previews: PreviewProvider {
    // Changed to @State to allow modification during preview (for add/edit actions)
    @State static var mockMealPlans: [MealPlan] = [
        MealPlan(
            name: "Lean & Green Lunch",
            description: "A balanced, high-protein meal for muscle recovery.",
            mealType: .lunch,
            items: [
                PlannedMealItem(description: "Grilled Chicken Breast (150g)", estimatedCalories: 250, estimatedProtein: 45, estimatedCarbs: 0, estimatedFat: 7),
                PlannedMealItem(description: "Steamed Broccoli (200g)", estimatedCalories: 55, estimatedProtein: 4, estimatedCarbs: 11, estimatedFat: 1),
                PlannedMealItem(description: "Brown Rice (100g cooked)", estimatedCalories: 130, estimatedProtein: 3, estimatedCarbs: 28, estimatedFat: 1),
                PlannedMealItem(description: "Olive Oil (1 tbsp)", estimatedCalories: 120, estimatedProtein: 0, estimatedCarbs: 0, estimatedFat: 14)
            ],
            source: .user,
            createdAt: Date().addingTimeInterval(-86400 * 2) // 2 days ago
        ),
        MealPlan(
            name: "AI-Generated Power Breakfast",
            description: "Optimized for energy and focus throughout the morning.",
            mealType: .breakfast,
            items: [
                PlannedMealItem(description: "Oatmeal with berries", estimatedCalories: 300, estimatedProtein: 10, estimatedCarbs: 50, estimatedFat: 8),
                PlannedMealItem(description: "Protein shake", estimatedCalories: 150, estimatedProtein: 25, estimatedCarbs: 5, estimatedFat: 3)
            ],
            source: .ai,
            createdAt: Date().addingTimeInterval(-86400) // 1 day ago
        ),
        MealPlan(
            name: "Evening Protein Snack",
            description: nil,
            mealType: .snack,
            items: [
                PlannedMealItem(description: "Greek Yogurt", estimatedCalories: 120, estimatedProtein: 15, estimatedCarbs: 8, estimatedFat: 4)
            ],
            source: .nutritionist,
            createdAt: Date()
        ),
        MealPlan(
            name: "Hydration Focus",
            description: "Just water for today.",
            mealType: .water,
            items: [], // No planned items for water
            source: .user,
            createdAt: Date()
        ),
        MealPlan(
            name: "Dinner Delights",
            description: "A hearty dinner, user-created.",
            mealType: .dinner,
            items: [
                PlannedMealItem(description: "Salmon Fillet (180g)", estimatedCalories: 350, estimatedProtein: 40, estimatedCarbs: 0, estimatedFat: 20),
                PlannedMealItem(description: "Sweet Potato (200g)", estimatedCalories: 170, estimatedProtein: 4, estimatedCarbs: 39, estimatedFat: 0.5),
                PlannedMealItem(description: "Asparagus (100g)", estimatedCalories: 20, estimatedProtein: 2, estimatedCarbs: 4, estimatedFat: 0.2),
                PlannedMealItem(description: "Green Salad", estimatedCalories: 30, estimatedProtein: 1, estimatedCarbs: 6, estimatedFat: 0.5)
            ],
            source: .user,
            createdAt: Date().addingTimeInterval(-86400 * 3)
        )
    ]

    static var previews: some View {
        NavigationView {
            MealPlanListView(
                mealPlans: $mockMealPlans, // Pass as binding
                onDelete: { id in
                    print("Delete \(id)")
                    mockMealPlans.removeAll { $0.id == id }
                },
                onUpdate: { updatedMealPlan, rawText in
                    print("Updated Meal Plan: \(updatedMealPlan.name) with raw text: \(rawText)")
                    if let index = mockMealPlans.firstIndex(where: { $0.id == updatedMealPlan.id }) {
                        mockMealPlans[index] = updatedMealPlan
                    }
                },
                // When used for preview where editing is default, pass nil for onChoosePlan
                onChoosePlan: nil
            )
        }
        .previewDisplayName("Meal Plans List - Populated (Edit Mode)")

        NavigationView {
            MealPlanListView(
                mealPlans: .constant([]), // For empty state, use a constant binding
                onDelete: { _ in },
                onUpdate: { _, _ in },
                onChoosePlan: nil
            )
        }
        .previewDisplayName("Meal Plans List - Empty State (Edit Mode)")
        
        // Preview for selection mode (e.g., from AddMealView)
        NavigationView {
            MealPlanListView(
                mealPlans: $mockMealPlans,
                onDelete: { _ in },
                onUpdate: { _, _ in },
                onChoosePlan: { selectedPlan in
                    print("Selected meal plan for quick add: \(selectedPlan.name)")
                    // In a real scenario, this would populate AddMealView's fields
                }
            )
        }
        .previewDisplayName("Meal Plans List - Selection Mode")
    }
}

