import Charts
import Observation
import SwiftUI

// Meal Grouping Helper Logic (Simplified)
private func iconForMealType(_ title: String) -> String {
    // This function still needs to be updated to use the MealType enum for consistency
    // However, since it's used within DailyMealListView (which itself uses DailyMealLog),
    // and the request is specific to Meal Plans, I'll leave this as-is for now to avoid
    // modifying unrelated functionality without explicit instruction.
    switch title {
    case "Breakfast": return "sun.max.fill"
    case "Lunch": return "takeoutbag.and.cup.and.straw.fill"
    case "Dinner": return "fork.knife"
    default: return "cup.and.saucer.fill"
    }
}

struct GroupedMealLog: Identifiable {
    let id = UUID()
    let title: String
    let totalCalories: Int
    let meals: [DailyMealLog]
}

private func groupMeals(meals: [DailyMealLog]) -> [GroupedMealLog] {
    var mealGroups: [String: [DailyMealLog]] = [:]

    for meal in meals {
        // Use the MealType enum for proper type safety
        let mealTitle: String
        switch meal.mealType {
        case .breakfast:
            mealTitle = "Breakfast"
        case .lunch:
            mealTitle = "Lunch"
        case .dinner:
            mealTitle = "Dinner"
        case .snack, .drink, .water, .supplements, .other:
            mealTitle = "Snacks & Others"
        }

        mealGroups[mealTitle, default: []].append(meal)
    }

    return mealGroups.map { (title, mealList) in
        GroupedMealLog(
            title: title,
            totalCalories: mealList.reduce(0) { $0 + $1.calories },
            meals: mealList.sorted { $0.time > $1.time }  // Most recent first
        )
    }
    .sorted { g1, g2 in
        let titles = ["Breakfast": 0, "Lunch": 1, "Dinner": 2]
        return (titles[g1.title] ?? 3) < (titles[g2.title] ?? 3)
    }
}

// MARK: - NutritionView and Components

struct NutritionView: View {
    @State private var viewModel: NutritionViewModel

    @State private var addMealViewModel: AddMealViewModel

    @State private var quickSelectViewModel: MealQuickSelectViewModel

    @State private var photoRecognitionViewModel: PhotoRecognitionViewModel

    // `showingAddMealSheet` now triggered by FAB
    @State private var showingAddMealSheet: Bool = false
    // `showingQuickSelectSheet` is no longer directly used by the FAB
    @State private var showingQuickSelectSheet: Bool = false
    // `showingOptionsMenu` is removed
    @State private var showingEditTargetsSheet: Bool = false

    // MARK: - NEW: State for showing MealPlanListView
    @State private var showingMealPlansListSheet: Bool = false

    // For forcing DatePicker dismissal in toolbar
    @State private var datePickerID = UUID()

    // MARK: - State for editing meal
    @State private var mealToEdit: DailyMealLog?

    // `showingMealLoggingOptionsSheet` is no longer needed
    // @State private var showingMealLoggingOptionsSheet: Bool = false

    private let primaryColor = Color.ascendBlue

    init(
        nutritionViewModel: NutritionViewModel,
        addMealViewModel: AddMealViewModel,
        quickSelectViewModel: MealQuickSelectViewModel,
        photoRecognitionViewModel: PhotoRecognitionViewModel
    ) {
        self._viewModel = State(initialValue: nutritionViewModel)
        self._addMealViewModel = State(initialValue: addMealViewModel)
        self._quickSelectViewModel = State(initialValue: quickSelectViewModel)
        self._photoRecognitionViewModel = State(initialValue: photoRecognitionViewModel)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                // VStack spacing to 20 to manage gaps between sections
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: 2. Nutrition Action Cards
                    NutritionActionCards(
                        showingEditTargetsSheet: $showingEditTargetsSheet,
                        manageMealPlansAction: {
                            print("Action: Open sheet to manage existing meal plans.")
                            // MARK: - CHANGE: Set state to show MealPlanListView
                            self.showingMealPlansListSheet = true
                        },
                        color: primaryColor
                    )
                    .padding(.horizontal)  // Horizontal padding for the cards

                    Divider()
                        .padding(.horizontal)  // Aligned with cards

                    // MARK: 3. Daily Macro Progress Card
                    DailyMacroProgressCard(viewModel: viewModel)
                        .padding(.horizontal)  // Horizontal padding for the card

                    // Second Divider after Progress Card
                    Divider()
                        .padding(.horizontal)  // Aligned with cards

                    // NEW: Section Title for Daily Meal List (Styled for consistency)
                    Text("Daily Meal Log")
                        .font(.subheadline)  // Smaller font size
                        .fontWeight(.semibold)  // Semi-bold weight
                        .foregroundColor(.secondary)  // System gray color
                        .padding(.horizontal)  // Align with other cards/dividers
                        .padding(.top, 5)  // Add a little extra top padding
                        .padding(.bottom, -10)  // Reduce gap to the list below (VStack spacing handles most)

                    // MARK: 4. Daily Meal List
                    DailyMealListView(
                        meals: viewModel.meals,
                        viewModel: viewModel,
                        mealToEdit: $mealToEdit
                    )

                    Spacer()
                }
                .padding(.bottom, 100)
                .padding(.top, 10)  // Added to match WorkoutView's spacing
            }
            .refreshable {
                await viewModel.manualSyncPendingMeals()
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Toolbar Leader: Date Picker (Reverted to direct DatePicker with dismissal trick)
                ToolbarItem(placement: .topBarLeading) {
                    DatePicker(
                        "Filter Date", selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .id(datePickerID)  // Assign an ID to the DatePicker
                    .onChange(of: viewModel.selectedDate) {
                        // This ensures the popover dismisses after selection
                        Task {
                            try? await Task.sleep(for: .milliseconds(50))  // Small delay
                            datePickerID = UUID()  // Change the ID to force recreation and dismissal
                        }
                        // Data reload handled by the .onChange below
                    }
                }
            }
            .onAppear {
                Task { await viewModel.loadDataForSelectedDate() }
            }
            // Catch changes to viewModel.selectedDate here to trigger data reload
            .onChange(of: viewModel.selectedDate) {
                Task { await viewModel.loadDataForSelectedDate() }
            }

            // Logging FAB (Now directly opens AddMealView)
            ActionFAB(
                action: { showingAddMealSheet = true }, color: primaryColor, systemImageName: "plus"
            )
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingAddMealSheet) {
            AddMealView(
                vm: viewModel,
                photoRecognitionVM: photoRecognitionViewModel,
                mealSuggestionsVm: MealSuggestionsViewModel()
            )
        }
        .sheet(item: $mealToEdit) { meal in
            // Construct the edit text from the meal
            let editText = meal.items
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .map { item in
                    // Format quantity properly - use whole number if it's an integer, otherwise 1 decimal
                    let quantityStr =
                        item.quantity.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(item.quantity))"
                        : String(format: "%.1f", item.quantity)
                    return "\(quantityStr) \(item.unit) \(item.name)"
                }
                .joined(separator: "\n")

            AddMealView(
                vm: viewModel,
                photoRecognitionVM: photoRecognitionViewModel,
                mealSuggestionsVm: MealSuggestionsViewModel(),
                initialMealType: meal.mealType,
                initialText: editText,
                mealToEdit: meal
            )
        }
        .sheet(isPresented: $showingEditTargetsSheet) {
            NutritionGoalSettingsView(viewModel: viewModel)
        }
        // MARK: - NEW: Sheet for MealPlanListView
        .sheet(isPresented: $showingMealPlansListSheet) {
            // Placeholder mock data and actions for now
            // In a real app, these would come from the NutritionViewModel or a dedicated MealPlanListViewModel
            @State var mockMealPlansForNutritionView: [MealPlan] = [  // Use @State here for demonstration
                MealPlan(
                    name: "Lean & Green Lunch",
                    description: "A balanced, high-protein meal for muscle recovery.",
                    mealType: .lunch,
                    items: [
                        PlannedMealItem(
                            description: "Grilled Chicken Breast (150g)", estimatedCalories: 250,
                            estimatedProtein: 45, estimatedCarbs: 0, estimatedFat: 7),
                        PlannedMealItem(
                            description: "Steamed Broccoli (200g)", estimatedCalories: 55,
                            estimatedProtein: 4, estimatedCarbs: 11, estimatedFat: 1),
                        PlannedMealItem(
                            description: "Brown Rice (100g cooked)", estimatedCalories: 130,
                            estimatedProtein: 3, estimatedCarbs: 28, estimatedFat: 1),
                        PlannedMealItem(
                            description: "Olive Oil (1 tbsp)", estimatedCalories: 120,
                            estimatedProtein: 0, estimatedCarbs: 0, estimatedFat: 14),
                    ],
                    source: .user,
                    createdAt: Date().addingTimeInterval(-86400 * 2)  // 2 days ago
                ),
                MealPlan(
                    name: "AI-Generated Power Breakfast",
                    description: "Optimized for energy and focus throughout the morning.",
                    mealType: .breakfast,
                    items: [
                        PlannedMealItem(
                            description: "Oatmeal with berries", estimatedCalories: 300,
                            estimatedProtein: 10, estimatedCarbs: 50, estimatedFat: 8),
                        PlannedMealItem(
                            description: "Protein shake", estimatedCalories: 150,
                            estimatedProtein: 25, estimatedCarbs: 5, estimatedFat: 3),
                    ],
                    source: .ai,
                    createdAt: Date().addingTimeInterval(-86400)  // 1 day ago
                ),
                MealPlan(
                    name: "Evening Protein Snack",
                    description: nil,
                    mealType: .snack,
                    items: [
                        PlannedMealItem(
                            description: "Greek Yogurt", estimatedCalories: 120,
                            estimatedProtein: 15, estimatedCarbs: 8, estimatedFat: 4)
                    ],
                    source: .nutritionist,
                    createdAt: Date()
                ),
                MealPlan(
                    name: "Hydration Focus",
                    description: "Just water for today.",
                    mealType: .water,
                    items: [],  // No planned items for water
                    source: .user,
                    createdAt: Date()
                ),
            ]

            MealPlanListView(
                mealPlans: $mockMealPlansForNutritionView,  // Use mock data for now
                onDelete: { mealPlanID in
                    print("Attempted to delete meal plan with ID: \(mealPlanID)")
                    mockMealPlansForNutritionView.removeAll { $0.id == mealPlanID }
                    // In a real implementation, you would call a method on your ViewModel here
                },
                onUpdate: { updatedMealPlan, rawText in
                    print(
                        "Updated Meal Plan from NutritionView: \(updatedMealPlan.name) with raw text: \(rawText)"
                    )
                    if let index = mockMealPlansForNutritionView.firstIndex(where: {
                        $0.id == updatedMealPlan.id
                    }) {
                        mockMealPlansForNutritionView[index] = updatedMealPlan
                    }
                    // In a real implementation, this would involve a UseCase call to update the meal plan
                    // and trigger potential AI re-processing of raw text.
                },
                onChoosePlan: nil  // Explicitly pass nil as this sheet is for management/editing
            )
        }
    }
}

// Nutrition Action Cards View
struct NutritionActionCards: View {
    @Binding var showingEditTargetsSheet: Bool
    let manageMealPlansAction: () -> Void
    let color: Color  // To keep consistent branding color

    var body: some View {
        HStack(spacing: 15) {
            // Card for "Daily Goals" (title changed)
            Button(action: { showingEditTargetsSheet = true }) {
                ActionCardContent(title: L10n.Goals.daily, icon: "target", color: color)  // Using L10n
            }
            .buttonStyle(.plain)

            // Card for "Meal Plans"
            Button(action: manageMealPlansAction) {
                ActionCardContent(
                    title: L10n.Nutrition.mealPlans, icon: "book.closed.fill", color: color)  // Using L10n
            }
            .buttonStyle(.plain)
        }
    }
}

// The ActionCardContent struct has been moved to UIHelpers.swift for reusability.
// The local declaration here is now removed to resolve the redeclaration error.

// `MealLogSearchField` struct is removed as it's no longer used.

// Daily Meal List View (remains the same)
struct DailyMealListView: View {
    let meals: [DailyMealLog]
    let viewModel: NutritionViewModel
    @Binding var mealToEdit: DailyMealLog?
    private let nutritionColor = Color.ascendBlue

    var body: some View {
        let groupedMeals = groupMeals(meals: meals)

        VStack(alignment: .leading, spacing: 15) {

            if groupedMeals.isEmpty {
                ContentUnavailableView(
                    L10n.Nutrition.noMealPlansFor(""), systemImage: "fork.knife",
                    description: Text(L10n.Nutrition.createFirstMealPlan))
            } else {
                ForEach(groupedMeals) { group in
                    MealSectionView(
                        group: group,
                        color: nutritionColor,
                        viewModel: viewModel,
                        mealToEdit: $mealToEdit
                    )
                }
            }
        }
    }
}

// Meal Section View (remains the same)
struct MealSectionView: View {
    let group: GroupedMealLog
    let color: Color
    let viewModel: NutritionViewModel
    @Binding var mealToEdit: DailyMealLog?

    @State private var currentlySwipedMealID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Section Header
            HStack {
                Image(systemName: iconForMealType(group.title))
                    .foregroundColor(color)
                    .font(.headline)

                Text(group.title)
                    .font(.headline)
                    .fontWeight(.heavy)
                Spacer()
                Text("\(group.totalCalories) \(L10n.Unit.kcal)")  // Using L10n
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(color)
            }
            .padding([.horizontal, .top], 15)

            // Individual Meal Rows
            VStack(spacing: 8) {
                ForEach(group.meals) { meal in
                    SwipeToDeleteMealRow(
                        meal: meal,
                        color: color,
                        isOpen: Binding(
                            get: { currentlySwipedMealID == meal.id },
                            set: { isOpen in
                                if isOpen {
                                    currentlySwipedMealID = meal.id
                                } else if currentlySwipedMealID == meal.id {
                                    currentlySwipedMealID = nil
                                }
                            }
                        ),
                        onDelete: {
                            currentlySwipedMealID = nil
                            Task {
                                await viewModel.deleteMealLog(id: meal.id)
                            }
                        },
                        onEdit: { meal in
                            // Edit callback - open AddMealView with pre-populated text
                            mealToEdit = meal
                        },
                        viewModel: viewModel
                    )
                }
            }
            .padding(.bottom, 10)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// Meal Row Card (remains the same)
// MARK: - Swipe to Delete Wrapper
struct SwipeToDeleteMealRow: View {
    let meal: DailyMealLog
    let color: Color
    @Binding var isOpen: Bool
    let onDelete: () -> Void
    let onEdit: (DailyMealLog) -> Void
    let viewModel: NutritionViewModel

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isDragging = false

    private let deleteButtonWidth: CGFloat = 80
    private let showButtonThreshold: CGFloat = 50
    private let deleteThreshold: CGFloat = 150  // Full swipe to delete

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (revealed when swiping)
            HStack {
                Spacer()
                Button(action: {
                    #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                    onDelete()
                }) {
                    VStack {
                        Image(
                            systemName: offset < -deleteThreshold
                                ? "trash.slash.fill" : "trash.fill"
                        )
                        .font(.title3)
                        Text(offset < -deleteThreshold ? "Release" : "Delete")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteButtonWidth)
                    .frame(maxHeight: .infinity)
                }
                .background(offset < -deleteThreshold ? Color.orange : Color.red)
            }

            // Main content
            MealRowCard(
                meal: meal, color: color, isInteractionEnabled: !isDragging, onEdit: onEdit,
                viewModel: viewModel
            )
            .background(Color(.secondarySystemBackground))
            .offset(x: offset)
            .scaleEffect(offset < 0 ? 0.98 : 1.0)
            .opacity(offset < 0 ? 0.95 : 1.0)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { gesture in
                        isDragging = true
                        // Only allow left swipe (negative translation)
                        let translation = gesture.translation.width
                        if translation < 0 {
                            // Allow swipe beyond button width for full delete
                            let maxSwipe = max(translation, -250)
                            offset = maxSwipe
                            isSwiping = true

                            // Haptic feedback when crossing delete threshold
                            if abs(offset) >= deleteThreshold && abs(maxSwipe) < deleteThreshold {
                                #if os(iOS)
                                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                                    generator.impactOccurred()
                                #endif
                            }
                        }
                    }
                    .onEnded { gesture in
                        let finalOffset = offset

                        // Check if full swipe to delete
                        if finalOffset < -deleteThreshold {
                            // Full swipe - delete immediately with animation
                            #if os(iOS)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            #endif
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = -500  // Slide off screen
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDelete()
                            }
                        } else if finalOffset < -showButtonThreshold {
                            // Partial swipe - show delete button
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = -deleteButtonWidth
                                isOpen = true
                            }
                        } else {
                            // Small swipe - snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                                isOpen = false
                            }
                        }

                        isSwiping = false
                        // Delay resetting isDragging to prevent tap from firing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isDragging = false
                        }
                    }
            )
            // Tap to close when swiped open
            .onTapGesture {
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                        isOpen = false
                    }
                }
            }
            .onChange(of: isOpen) { oldValue, newValue in
                if !newValue && offset < 0 {
                    // Close this row when another row is opened
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}

struct MealRowCard: View {
    let meal: DailyMealLog
    let color: Color
    var isInteractionEnabled: Bool = true
    let onEdit: (DailyMealLog) -> Void
    let viewModel: NutritionViewModel

    @State private var showingDetail = false

    var body: some View {
        Button(action: {
            if isInteractionEnabled {
                showingDetail = true
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.description)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(meal.time.formatted(.dateTime.hour().minute()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(meal.calories)")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(color)

                        Text(L10n.Unit.kcal)  // Using L10n
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Show status badge for pending/processing/failed meals
                if meal.status != .completed || meal.syncStatus == .failed {
                    MealLogStatusBadge(meal: meal)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingDetail) {
            MealDetailView(
                meal: meal,
                onMealUpdated: { _ in
                    print("Meal updated/deleted. Notifying parent to refresh.")
                },
                isPhotoRecognition: false,
                onEditTapped: {
                    print("NutritionView: Edit tapped for meal: \(meal.id)")
                    showingDetail = false
                    onEdit(meal)
                },
                onDeleteTapped: {
                    print("NutritionView: Delete tapped for meal: \(meal.id)")
                    showingDetail = false
                    Task {
                        await viewModel.deleteMealLog(id: meal.id)
                    }
                }
            )
        }

    }
}
