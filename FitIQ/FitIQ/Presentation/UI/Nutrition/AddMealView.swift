import AVFoundation
import PhotosUI
import SwiftUI

// Assuming this extension is defined elsewhere or at the top of the file
struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var vm: NutritionViewModel
    let photoRecognitionVM: PhotoRecognitionViewModel

    //    @ObservedObject var mealPlanVm: MealPlanViewModel
    //    @ObservedObject var quickLogVm: QuickLogViewModel
    @State var mealSuggestionsVm: MealSuggestionsViewModel

    @StateObject private var speechRecognizer = SpeechRecognizer()

    @State private var textInput: String
    @State private var mealType: MealType
    @State private var selectedDate = Date()

    // Optional: Meal being edited
    let mealToEdit: DailyMealLog?
    @State private var showingMealPlans = false  // This will now trigger MealPlanListView

    @State private var quickLogEntries: [QuickLogEntry] = []

    // NEW: Mock meal plans for MealPlanListView in AddMealView
    // In a real application, this data would likely come from a ViewModel
    // that manages MealPlan data.
    @State private var mockMealPlans: [MealPlan] = [
        MealPlan(
            name: "Lean & Green Lunch",
            description: "A balanced, high-protein meal for muscle recovery.",
            mealType: .lunch,
            items: [
                PlannedMealItem(
                    description: "Grilled Chicken Breast (150g)",
                    estimatedCalories: 250,
                    estimatedProtein: 45,
                    estimatedCarbs: 0,
                    estimatedFat: 7
                ),
                PlannedMealItem(
                    description: "Steamed Broccoli (200g)",
                    estimatedCalories: 55,
                    estimatedProtein: 4,
                    estimatedCarbs: 11,
                    estimatedFat: 1
                ),
                PlannedMealItem(
                    description: "Brown Rice (100g cooked)",
                    estimatedCalories: 130,
                    estimatedProtein: 3,
                    estimatedCarbs: 28,
                    estimatedFat: 1
                ),
                PlannedMealItem(
                    description: "Olive Oil (1 tbsp)",
                    estimatedCalories: 120,
                    estimatedProtein: 0,
                    estimatedCarbs: 0,
                    estimatedFat: 14
                ),
            ],
            source: .user,
            createdAt: Date().addingTimeInterval(-86400 * 2)  // 2 days ago
        ),
        MealPlan(
            name: "AI-Generated Power Breakfast",
            description:
                "Optimized for energy and focus throughout the morning.",
            mealType: .breakfast,
            items: [
                PlannedMealItem(
                    description: "Oatmeal with berries",
                    estimatedCalories: 300,
                    estimatedProtein: 10,
                    estimatedCarbs: 50,
                    estimatedFat: 8
                ),
                PlannedMealItem(
                    description: "Protein shake",
                    estimatedCalories: 150,
                    estimatedProtein: 25,
                    estimatedCarbs: 5,
                    estimatedFat: 3
                ),
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
                    description: "Greek Yogurt",
                    estimatedCalories: 120,
                    estimatedProtein: 15,
                    estimatedCarbs: 8,
                    estimatedFat: 4
                )
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
        MealPlan(
            name: "Dinner Delights",
            description: "A hearty dinner, user-created.",
            mealType: .dinner,
            items: [
                PlannedMealItem(
                    description: "Salmon Fillet (180g)",
                    estimatedCalories: 350,
                    estimatedProtein: 40,
                    estimatedCarbs: 0,
                    estimatedFat: 20
                ),
                PlannedMealItem(
                    description: "Sweet Potato (200g)",
                    estimatedCalories: 170,
                    estimatedProtein: 4,
                    estimatedCarbs: 39,
                    estimatedFat: 0.5
                ),
                PlannedMealItem(
                    description: "Asparagus (100g)",
                    estimatedCalories: 20,
                    estimatedProtein: 2,
                    estimatedCarbs: 4,
                    estimatedFat: 0.2
                ),
                PlannedMealItem(
                    description: "Green Salad",
                    estimatedCalories: 30,
                    estimatedProtein: 1,
                    estimatedCarbs: 6,
                    estimatedFat: 0.5
                ),
            ],
            source: .user,
            createdAt: Date().addingTimeInterval(-86400 * 3)
        ),
    ]

    // MARK: - Photo Upload State

    // Photo selection and processing
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessingImage = false
    @State private var imageError: String?

    // Photo recognition results
    @State private var recognizedMealLog: DailyMealLog?
    @State private var showingMealDetail = false

    // Image source selection
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    @State private var showingPhotoLibrary = false

    // Legacy states (keeping for backwards compatibility)
    @State private var recognizedItems: [RecognizedFoodItem] = []
    @State private var showingImageReview = false

    // Image meal parser service (optional for now to maintain backwards compatibility)
    //    let imageMealParser: ImageMealParserService?

    // Keep recognized items to avoid re-parsing when logging
    @State private var itemsFromAI: [RecognizedFoodItem]?

    // Changed to internal (default) to be accessible by sub-views
    enum Field: Hashable {
        case mealDescription
    }
    @FocusState private var focusedField: Field?  // Controls keyboard visibility

    // Define the meals you want on the first row and second row
    private let firstRowMeals: [MealType] = [
        .breakfast, .lunch, .dinner, .snack,
    ]
    private let secondRowMeals: [MealType] = [
        .drink, .water, .supplements, .other,
    ]

    // Using Color.ascendBlue from UIHelpers.swift
    private let primaryAccent = Color.ascendBlue
    private let gridColumns: [GridItem] = [
        GridItem(.flexible()), GridItem(.flexible()),
    ]

    init(
        vm: NutritionViewModel,
        photoRecognitionVM: PhotoRecognitionViewModel,
        mealSuggestionsVm: MealSuggestionsViewModel,
        //        mealPlanVm: MealPlanViewModel,
        //        quickLogVm: QuickLogViewModel,
        //        imageMealParser: ImageMealParserService? = nil,
        initialMealType: MealType? = nil,
        initialText: String = "",
        mealToEdit: DailyMealLog? = nil
    ) {
        self.vm = vm
        self.photoRecognitionVM = photoRecognitionVM
        self.mealSuggestionsVm = mealSuggestionsVm
        self.mealToEdit = mealToEdit
        _textInput = State(initialValue: initialText)
        //        self.mealPlanVm = mealPlanVm
        //        self.quickLogVm = quickLogVm
        //        self.imageMealParser = imageMealParser

        // If an initial meal type is provided, use it
        if let providedMealType = initialMealType {
            _mealType = State(initialValue: providedMealType)
        } else {
            // Otherwise, determine the meal type based on the current hour
            let hour = Calendar.current.component(.hour, from: Date())

            let determinedMealType: MealType
            switch hour {
            case 5..<10:  // 5:00 to 9:59
                determinedMealType = .breakfast
            case 12..<16:  // 12:00 to 15:59 (3 PM)
                determinedMealType = .lunch
            case 18..<22:  // 18:00 (6 PM) to 21:59 (9:59 PM)
                determinedMealType = .dinner
            default:  // All other times (0:00-4:59, 10:00-11:59, 16:00-17:59, 22:00-23:59)
                determinedMealType = .snack
            }

            _mealType = State(initialValue: determinedMealType)
        }
        self._mealSuggestionsVm = State(
            wrappedValue: MealSuggestionsViewModel()
        )
    }

    var body: some View {
        Group {  // Wrap the NavigationStack and its modifiers in a Group
            NavigationStack {
                Form {
                    MealDetailsSectionView(
                        selectedDate: $selectedDate,
                        mealType: $mealType,
                        firstRowMeals: firstRowMeals,
                        secondRowMeals: secondRowMeals,
                        primaryAccent: primaryAccent,
                        gridColumns: gridColumns
                    )

                    FoodAndDrinkDescriptionSectionView(
                        quickLogEntries: quickLogEntries,
                        mealType: mealType,
                        mealSuggestionsVm: mealSuggestionsVm,
                        showingMealPlans: $showingMealPlans,
                        showingImageSourcePicker: $showingImageSourcePicker,
                        isProcessingImage: isProcessingImage,
                        textInput: $textInput,
                        focusedField: _focusedField,  // Pass FocusState binding
                        speechRecognizer: speechRecognizer,
                        clearInput: clearInput,
                        startRecording: startRecording,
                        primaryAccent: primaryAccent,
                        onQuickLogSelected: { entryText in
                            textInput = entryText
                            itemsFromAI = nil  // Clear AI items when quick log is used
                        }
                    )
                }
                .navigationTitle(L10n.Nutrition.foodAndDrink)
                .tint(primaryAccent)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(8)
                                .background(Circle().fill(Color(.systemGray5)))
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.save) {
                            Task { await saveEntry() }
                        }
                        .foregroundColor(
                            textInput.isEmpty ? .gray : primaryAccent
                        )
                        .disabled(textInput.isEmpty)
                    }
                }
            }
        }
        // Keep the simultaneous gesture for keyboard dismissal functionality
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if focusedField == .mealDescription {
                        self.focusedField = nil
                    }
                }
        )
        .onAppear {
            speechRecognizer.requestAuthorization()
            // Load meal plans for current meal type
            //            Task {
            //                await mealPlanVm.loadMealPlans(for: mealType)
            //            }
            //            // Load quick log entries
            //            Task {
            //                self.quickLogEntries = await quickLogVm.loadQuickLogEntries()
            //            }
        }
        .onDisappear { speechRecognizer.stopRecording() }
        .onChange(of: mealType) { _, newValue in
            //            Task {
            //                await mealPlanVm.loadMealPlans(for: newValue)
            //            }
        }
        // Process photo when selected
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            // Only process if we have a new non-nil item
            guard let newValue = newValue else { return }

            // Check if it's actually a different photo
            if let oldValue = oldValue, oldValue.itemIdentifier == newValue.itemIdentifier {
                print("AddMealView: ⏭️  Same photo, skipping processing")
                return
            }

            print("AddMealView: 📸 Photo item changed, processing...")

            // Process the photo
            Task { @MainActor in
                await processSelectedPhoto()
            }
        }
        // Apply the new custom modifiers to handle sheets and alerts
        .mealPlanSheet(
            showingMealPlans: $showingMealPlans,
            mockMealPlans: $mockMealPlans,
            textInput: $textInput,
            mealType: $mealType,
            itemsFromAI: $itemsFromAI,
            onMealPlanDelete: { id in
                print(
                    "Deleting meal plan with ID: \(id) from AddMealView (mock)"
                )
                mockMealPlans.removeAll { $0.id == id }
            },
            onMealPlanUpdate: { updatedMealPlan, rawText in
                print(
                    "Updating meal plan: \(updatedMealPlan.name) from AddMealView (mock)"
                )
                if let index = mockMealPlans.firstIndex(where: {
                    $0.id == updatedMealPlan.id
                }) {
                    mockMealPlans[index] = updatedMealPlan
                }
            },
            convertMealPlanItemsToText: convertMealPlanItemsToText
        )
        .imageHandlingModifiers(
            showingImageReview: $showingImageReview,
            recognizedItems: $recognizedItems,
            selectedImage: $selectedImage,
            selectedPhotoItem: $selectedPhotoItem,
            imageError: $imageError,
            showingImageSourcePicker: $showingImageSourcePicker,
            showingCamera: $showingCamera,
            showingPhotoLibrary: $showingPhotoLibrary,
            onImageReviewConfirm: { mealText, confirmedRecognizedItems in
                textInput = mealText
                itemsFromAI = confirmedRecognizedItems
                selectedPhotoItem = nil
                selectedImage = nil
                recognizedItems = []  // Clear AddMealView's recognized items
                showingImageReview = false  // Dismiss the sheet
            },
            onRequestCameraPermissionAndShow: requestCameraPermissionAndShow,
            onProcessImage: processImage,
            recognizedMealLog: $recognizedMealLog,
            showingMealDetail: $showingMealDetail
        )
        .sheet(isPresented: $showingMealDetail) {
            if let mealLog = recognizedMealLog {
                MealDetailView(
                    meal: mealLog,
                    onMealUpdated: { updatedMeal in
                        // Handle confirmation - log the meal
                        if updatedMeal == nil {
                            // User cancelled
                            showingMealDetail = false
                            recognizedMealLog = nil
                            selectedPhotoItem = nil
                            selectedImage = nil
                        } else {
                            // User confirmed - log the meal
                            Task { @MainActor in
                                do {
                                    // Check if user made changes (for now, assume no changes)
                                    // TODO: Implement change detection in MealDetailView
                                    let userMadeChanges = false

                                    try await confirmAndLogPhotoMeal(
                                        mealLog, userMadeChanges: userMadeChanges)

                                    // Close the sheet first
                                    showingMealDetail = false

                                    // Wait for sheet animation to complete
                                    try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

                                    // Clean up state
                                    recognizedMealLog = nil
                                    selectedPhotoItem = nil
                                    selectedImage = nil

                                    // Dismiss AddMealView after sheet is fully dismissed
                                    dismiss()
                                } catch {
                                    // Handle error without showing alert (prevents crash during dismissal)
                                    print(
                                        "AddMealView: ❌ Failed to confirm meal: \(error.localizedDescription)"
                                    )

                                    // Close the sheet first
                                    showingMealDetail = false

                                    // Wait briefly then show error in parent view context
                                    try? await Task.sleep(nanoseconds: 300_000_000)

                                    // Clean up state
                                    recognizedMealLog = nil
                                    selectedPhotoItem = nil
                                    selectedImage = nil

                                    // Set error message - will show alert in AddMealView context (safe)
                                    imageError = "Failed to log meal: \(error.localizedDescription)"
                                }
                            }
                        }
                    },
                    isPhotoRecognition: true,
                    onEditTapped: {
                        // Convert recognized items to natural language text (one item per line)
                        let editableText = mealLog.items
                            .sorted(by: { $0.orderIndex < $1.orderIndex })
                            .map { item in
                                "\(Int(item.quantity))\(item.unit) \(item.name)"
                            }
                            .joined(separator: "\n")

                        print("AddMealView: Edit tapped - converting to natural language")
                        print("AddMealView: Editable text:\n\(editableText)")

                        // Close the meal detail sheet
                        showingMealDetail = false

                        // Pre-populate text input with recognized items
                        textInput = editableText

                        // Clear photo state (user is now editing as text)
                        recognizedMealLog = nil
                        selectedPhotoItem = nil
                        selectedImage = nil
                    },
                    onDeleteTapped: nil  // Not applicable for photo recognition review
                )
            }
        }
    }

    // MARK: - Helper Functions

    private func clearInput() {
        speechRecognizer.stopRecording()
        speechRecognizer.recognizedText = ""
        textInput = ""
        itemsFromAI = nil  // Clear AI items when user clears input
        self.focusedField = .mealDescription
    }

    private func startRecording() {
        self.focusedField = nil
        self.textInput = ""  // Clear before starting a new dictation
        itemsFromAI = nil  // Clear AI items when starting new voice input
        do {
            try speechRecognizer.startRecording()
        } catch {
            print("Error starting recording: \(error.localizedDescription)")
        }
    }

    private func requestCameraPermissionAndShow() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        imageError =
                            "Camera access is required to take photos of meals. Please enable it in Settings."
                    }
                }
            }
        case .denied, .restricted:
            imageError =
                "Camera access is denied. Please enable it in Settings to use this feature."
        @unknown default:
            imageError = "Unable to access camera."
        }
    }

    private func processImage(_ image: UIImage) async {
        isProcessingImage = true
        imageError = nil
        selectedImage = image

        // Upload photo and start recognition
        await photoRecognitionVM.uploadPhoto(
            image: image,
            mealType: mealType,
            notes: nil
        )

        // Check for errors
        if let error = photoRecognitionVM.errorMessage {
            imageError = error
            isProcessingImage = false
            return
        }

        // Wait for recognition to complete (backend processes synchronously)
        // Check if we have results
        if let photoRecognition = photoRecognitionVM.selectedPhotoRecognition,
            photoRecognition.status == .completed
        {
            recognizedItems = photoRecognition.recognizedItems.map { uiItem in
                RecognizedFoodItem(
                    id: uiItem.id,
                    name: uiItem.name,
                    suggestedQuantity: "\(uiItem.quantity) \(uiItem.unit)",
                    confidence: uiItem.confidenceScore,
                    calories: Double(uiItem.calories),
                    protein: uiItem.proteinG,
                    carbs: uiItem.carbsG,
                    fat: uiItem.fatG
                )
            }

            if recognizedItems.isEmpty {
                imageError =
                    "No food items were recognized in the image. Please try a different photo with clearer food items."
            } else {
                // Convert photo recognition to DailyMealLog for detailed view
                recognizedMealLog = convertPhotoRecognitionToMealLog(photoRecognition)
                showingMealDetail = true
            }
        }

        isProcessingImage = false
    }

    private func processSelectedPhoto() async {
        guard let selectedPhotoItem = selectedPhotoItem else {
            return
        }

        // Prevent re-processing if already processing
        guard !isProcessingImage else {
            print("AddMealView: ⚠️ Already processing image, skipping...")
            return
        }

        isProcessingImage = true
        imageError = nil

        print("AddMealView: 📸 Starting photo processing...")

        do {
            // Load image data from PhotosPicker
            guard let imageData = try await selectedPhotoItem.loadTransferable(type: Data.self)
            else {
                imageError = "Failed to load image"
                isProcessingImage = false
                return
            }

            // Convert to UIImage for preview and processing
            guard let uiImage = UIImage(data: imageData) else {
                imageError = "Failed to convert image"
                isProcessingImage = false
                return
            }

            selectedImage = uiImage
            print("AddMealView: ✅ Image loaded successfully")

            // Upload photo and start recognition (backend returns immediate results)
            await photoRecognitionVM.uploadPhoto(
                image: uiImage,
                mealType: mealType,
                notes: nil
            )

            // Check for errors from upload
            if let error = photoRecognitionVM.errorMessage {
                print("AddMealView: ❌ Upload error: \(error)")
                imageError = error
                isProcessingImage = false
                return
            }

            // Backend processes synchronously - results are already complete
            if let photoRecognition = photoRecognitionVM.selectedPhotoRecognition {
                print("AddMealView: ✅ Recognition complete - Status: \(photoRecognition.status)")
                print("AddMealView: Found \(photoRecognition.recognizedItems.count) items")

                // Check if recognition was successful
                guard photoRecognition.status == .completed else {
                    imageError = "Photo analysis incomplete. Please try again."
                    isProcessingImage = false
                    return
                }

                if photoRecognition.recognizedItems.isEmpty {
                    imageError =
                        "No food items were recognized in the image. Please try a different photo with clearer food items."
                    isProcessingImage = false
                    return
                }

                // Convert photo recognition to DailyMealLog for detailed view
                recognizedMealLog = convertPhotoRecognitionToMealLog(photoRecognition)

                // Show meal detail for user review (this is where user can edit)
                // No flickering because we're not changing selectedPhotoItem
                showingMealDetail = true
                print("AddMealView: ✅ Showing meal detail for review")
            } else {
                imageError = "No recognition results received. Please try again."
                isProcessingImage = false
            }

        } catch {
            print("AddMealView: ❌ Processing error: \(error)")
            imageError = "Failed to process image: \(error.localizedDescription)"
        }

        isProcessingImage = false
    }

    // MARK: - Photo Recognition Helpers

    /// Convert photo recognition results to DailyMealLog for detail view
    private func convertPhotoRecognitionToMealLog(_ photoRecognition: PhotoRecognitionUIModel)
        -> DailyMealLog
    {
        let mealLogID = photoRecognition.id
        let mealLogItems = photoRecognition.recognizedItems.map { item in
            MealLogItem(
                id: item.id,
                mealLogID: mealLogID,
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                calories: Double(item.calories),
                protein: item.proteinG,
                carbs: item.carbsG,
                fat: item.fatG,
                foodType: .food,
                fiber: item.fiberG,
                sugar: item.sugarG,
                confidence: item.confidenceScore,
                parsingNotes: nil,
                orderIndex: item.orderIndex,
                createdAt: Date(),
                backendID: nil
            )
        }

        return DailyMealLog(
            id: photoRecognition.id,
            description: photoRecognition.recognizedItems.map { $0.name }.joined(separator: ", "),
            time: photoRecognition.loggedAt,
            calories: Int(photoRecognition.totalCalories ?? 0),
            protein: Int(photoRecognition.totalProteinG ?? 0),
            carbs: Int(photoRecognition.totalCarbsG ?? 0),
            fat: Int(photoRecognition.totalFatG ?? 0),
            sugar: Int(photoRecognition.totalSugarG ?? 0),
            fiber: Int(photoRecognition.totalFiberG ?? 0),
            saturatedFat: 0,
            sodiumMg: 0,
            ironMg: 0.0,
            vitaminCmg: 0,
            status: .completed,
            syncStatus: photoRecognition.syncStatus,
            backendID: photoRecognition.backendID,
            rawInput: "Photo recognition: \(photoRecognition.recognizedItems.count) items",
            mealType: photoRecognition.mealType,
            items: mealLogItems
        )
    }

    /// Confirm and log the photo-recognized meal
    /// If user made no edits: Save directly as completed meal log with all structured data
    /// If user edited: Call PATCH /confirm endpoint to sync changes to backend
    private func confirmAndLogPhotoMeal(_ mealLog: DailyMealLog, userMadeChanges: Bool = false)
        async throws
    {
        guard let photoRecognition = photoRecognitionVM.selectedPhotoRecognition else {
            print("AddMealView: ❌ No photo recognition data available")
            throw PhotoMealLogError.noPhotoRecognition
        }

        if userMadeChanges {
            // USER EDITED - Send changes to backend
            print("AddMealView: 🔄 User edited items - syncing to backend")

            let confirmedItems = photoRecognition.recognizedItems.map { item in
                ConfirmedFoodItem(
                    name: item.name,
                    quantity: item.quantity,
                    unit: item.unit,
                    calories: item.calories,
                    proteinG: item.proteinG,
                    carbsG: item.carbsG,
                    fatG: item.fatG,
                    fiberG: item.fiberG,
                    sugarG: item.sugarG
                )
            }

            _ = try await photoRecognitionVM.confirmPhotoRecognition(
                id: photoRecognition.id,
                confirmedItems: confirmedItems,
                notes: photoRecognition.notes
            )
        } else {
            // NO EDITS - Save directly as completed meal log with all structured data
            // This bypasses text parsing to preserve exact macros from photo recognition
            print("AddMealView: ✅ No edits - saving as completed meal log with structured data")
            print("AddMealView: - Items: \(photoRecognition.recognizedItems.count)")
            print("AddMealView: - Total calories: \(photoRecognition.totalCalories ?? 0)")
            print("AddMealView: - Total protein: \(photoRecognition.totalProteinG ?? 0)g")
            print("AddMealView: - Total carbs: \(photoRecognition.totalCarbsG ?? 0)g")
            print("AddMealView: - Total fat: \(photoRecognition.totalFatG ?? 0)g")
            print("AddMealView: - Confidence: \(Int(photoRecognition.confidenceScore ?? 0))%")

            // Save directly with all structured data
            try await vm.saveCompletedMealLogFromPhoto(photoRecognition: photoRecognition)

            print("AddMealView: ✅ Meal log saved with complete structured data")
        }

        // Refresh to show meal in the UI
        await vm.loadDataForSelectedDate()
    }

    // MARK: - Error Types

    enum PhotoMealLogError: Error, LocalizedError {
        case noPhotoRecognition

        var errorDescription: String? {
            switch self {
            case .noPhotoRecognition:
                return "Photo recognition data not available"
            }
        }
    }

    private func saveEntry() async {
        let textToSave = textInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !textToSave.isEmpty else { return }

        speechRecognizer.stopRecording()

        // If editing an existing meal, delete it first before creating new one
        // This ensures the updated text is re-parsed by AI
        if let existingMeal = mealToEdit {
            print("AddMealView: Editing existing meal - deleting old entry first")
            print("AddMealView: Old meal ID: \(existingMeal.id)")

            // Delete the old meal log
            await vm.deleteMealLog(id: existingMeal.id)
        }

        // ✅ CALL REAL USE CASE: Save meal log via ViewModel (creates new entry with AI parsing)
        await vm.saveMealLog(
            rawInput: textToSave,
            mealType: mealType,
            loggedAt: selectedDate,
            notes: nil
        )

        // Check for errors
        if vm.errorMessage != nil {
            print("AddMealView: Failed to save meal - \(vm.errorMessage ?? "Unknown error")")
            // Error is displayed by the ViewModel
        } else {
            if mealToEdit != nil {
                print(
                    "AddMealView: Meal updated successfully (deleted old + created new), dismissing view"
                )
            } else {
                print("AddMealView: Meal saved successfully, dismissing view")
            }
            dismiss()
        }
    }

    // NEW: Helper to convert meal plan items to a text string for the input field
    private func convertMealPlanItemsToText(_ mealPlan: MealPlan) -> String {
        guard !mealPlan.items.isEmpty else {
            // If there are no specific items, use the plan's name and description
            return mealPlan.name
                + (mealPlan.description.map { "\n\($0)" } ?? "")
        }
        return mealPlan.items.map { item in
            var text = item.description
            if item.estimatedCalories > 0 {
                text += " (\(Int(item.estimatedCalories))kcal)"
            }
            return text
        }.joined(separator: "\n")
    }
}

// MARK: - Extracted Sub-Views
private struct MealDetailsSectionView: View {
    @Binding var selectedDate: Date
    @Binding var mealType: MealType
    let firstRowMeals: [MealType]
    let secondRowMeals: [MealType]
    let primaryAccent: Color
    let gridColumns: [GridItem]

    var body: some View {
        Section {
            DatePicker("Date & Time", selection: $selectedDate, in: ...Date())
                .datePickerStyle(.compact)

            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(firstRowMeals, id: \.self) { type in
                        MealTypeButton(
                            type: type,
                            selectedMealType: $mealType,
                            primaryAccent: primaryAccent
                        )
                    }
                }
                .padding(.horizontal, 15)

                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(secondRowMeals, id: \.self) { type in
                        MealTypeButton(
                            type: type,
                            selectedMealType: $mealType,
                            primaryAccent: primaryAccent
                        )
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
            }
            .listRowInsets(EdgeInsets())
        }
    }
}

private struct FoodAndDrinkDescriptionSectionView: View {
    let quickLogEntries: [QuickLogEntry]
    let mealType: MealType
    @State var mealSuggestionsVm: MealSuggestionsViewModel
    @Binding var showingMealPlans: Bool
    @Binding var showingImageSourcePicker: Bool
    let isProcessingImage: Bool
    @Binding var textInput: String
    @FocusState<AddMealView.Field?> var focusedField: AddMealView.Field?  // Using external Field enum
    @ObservedObject var speechRecognizer: SpeechRecognizer
    let clearInput: () -> Void
    let startRecording: () -> Void
    let primaryAccent: Color
    let onQuickLogSelected: (String) -> Void  // New closure for quick log selection

    var body: some View {
        Section("Food & Drink Description") {
            VStack(alignment: .trailing) {
                QuickLogAndSuggestionsView(
                    quickLogEntries: quickLogEntries,
                    mealType: mealType,
                    mealSuggestionsVm: mealSuggestionsVm,
                    showingMealPlans: $showingMealPlans,
                    onQuickLogSelected: onQuickLogSelected,  // Pass the new closure
                    primaryAccent: primaryAccent
                )

                ImageInputButtonsView(
                    showingImageSourcePicker: $showingImageSourcePicker,
                    isProcessingImage: isProcessingImage,
                    primaryAccent: primaryAccent
                )

                ClearInputButtonView(
                    textInput: textInput,
                    clearInput: clearInput
                )

                TextInputAndVoiceInputView(
                    textInput: $textInput,
                    focusedField: _focusedField,  // Pass FocusState binding
                    speechRecognizer: speechRecognizer,
                    primaryAccent: primaryAccent,
                    startRecording: startRecording  // Pass the closure from AddMealView
                )
            }
        }
    }
}

private struct QuickLogAndSuggestionsView: View {
    let quickLogEntries: [QuickLogEntry]
    let mealType: MealType
    @State var mealSuggestionsVm: MealSuggestionsViewModel
    @Binding var showingMealPlans: Bool
    let onQuickLogSelected: (String) -> Void  // Now a closure

    let primaryAccent: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if self.quickLogEntries.contains(where: { $0.mealType == mealType }) {
                QuickLogCardView(
                    entries: self.quickLogEntries.filter {
                        $0.mealType == mealType
                    }
                ) { entry in
                    onQuickLogSelected(entry.displayText)  // Call the closure
                    Task {
                        //                                    await quickLogVm.recordUsage(of: entry)
                    }
                }
                .padding(.bottom, 12)
            }

            MealSuggestionsCardView(vm: mealSuggestionsVm)
                .padding(.bottom, 12)

            HStack {
                Button {
                    showingMealPlans = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                        Text(L10n.Nutrition.quickAddFromPlans)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(primaryAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(primaryAccent.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.bottom, 8)
        }
    }
}

private struct ImageInputButtonsView: View {
    @Binding var showingImageSourcePicker: Bool
    let isProcessingImage: Bool
    let primaryAccent: Color

    var body: some View {
        HStack {
            Button {
                showingImageSourcePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                    Text(L10n.Nutrition.snapPhoto)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(primaryAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(primaryAccent.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(primaryAccent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isProcessingImage)

            if isProcessingImage {
                ProgressView()
                    .padding(.leading, 8)
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }
}

private struct ClearInputButtonView: View {
    let textInput: String
    let clearInput: () -> Void

    var body: some View {
        HStack {
            Spacer()
            if !textInput.isEmpty {
                Button(L10n.Common.clear) {
                    clearInput()
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

private struct TextInputAndVoiceInputView: View {
    @Binding var textInput: String
    @FocusState<AddMealView.Field?> var focusedField: AddMealView.Field?
    @ObservedObject var speechRecognizer: SpeechRecognizer
    let primaryAccent: Color
    let startRecording: () -> Void  // Now a closure

    var body: some View {
        VStack(alignment: .trailing) {
            ZStack(alignment: .topLeading) {
                if textInput.isEmpty {
                    Text(L10n.Nutrition.enterFoodDescription)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }

                TextEditor(text: $textInput)
                    .frame(minHeight: 150)
                    .opacity(textInput.isEmpty ? 0.85 : 1)
                    .focused($focusedField, equals: .mealDescription)
                    .onChange(of: speechRecognizer.recognizedText) {
                        if speechRecognizer.isRecording {
                            self.textInput = speechRecognizer.recognizedText
                        }
                    }
            }

            Image(
                systemName: speechRecognizer.isRecording
                    ? "mic.fill" : "mic.circle"
            )
            .font(.largeTitle)
            .foregroundStyle(
                speechRecognizer.isRecording ? .red : primaryAccent
            )
            .scaleEffect(speechRecognizer.isRecording ? 1.3 : 1.0)
            .animation(
                speechRecognizer.isRecording
                    ? .easeInOut(duration: 0.7).repeatForever(
                        autoreverses: true
                    ) : .default,
                value: speechRecognizer.isRecording
            )
            .padding(.vertical, 4)
            .disabled(!speechRecognizer.isAuthorized)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !speechRecognizer.isRecording {
                            startRecording()  // Call the passed-in closure
                        }
                    }
                    .onEnded { _ in
                        speechRecognizer.stopRecording()
                    }
            )
            .padding(20)
        }
    }
}

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
        .buttonStyle(.plain)  // Essential in a Form
    }
}

// REMOVED: MealPlanQuickSelectView is no longer needed.
// REMOVED: MealTypeChipButton is no longer needed.

// MARK: - ImagePicker (UIKit wrapper for camera)
struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary
    }

    let sourceType: SourceType
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType == .camera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            completion(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }
    }
}

// MARK: - PhotosPickerView (wrapper for photo library selection)
struct PhotosPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(Color.ascendBlue)  // Using Color.ascendBlue

                        Text("Select a Photo")
                            .font(.headline)

                        Text("Choose a photo of your meal from your library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhotoItem) { oldValue, newValue in
                    // Dismiss immediately when photo is selected
                    if newValue != nil {
                        print("PhotosPickerView: Photo selected, dismissing picker")
                        // Dismiss sheet immediately to prevent flickering
                        dismiss()
                    }
                }
            }
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - New ViewModifiers for Sheets and Alerts (Split for clarity)

/// Modifier for Meal Plan related sheets
private struct MealPlanSheetModifier: ViewModifier {
    @Environment(\.dismiss) var dismiss

    @Binding var showingMealPlans: Bool
    @Binding var mockMealPlans: [MealPlan]
    @Binding var textInput: String
    @Binding var mealType: MealType
    @Binding var itemsFromAI: [RecognizedFoodItem]?

    let onMealPlanDelete: (UUID) -> Void
    let onMealPlanUpdate: (MealPlan, String) -> Void
    let convertMealPlanItemsToText: (MealPlan) -> String

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: self.$showingMealPlans) {
                MealPlanListView(
                    mealPlans: self.$mockMealPlans,
                    onDelete: self.onMealPlanDelete,
                    onUpdate: self.onMealPlanUpdate,
                    onChoosePlan: { selectedPlan in
                        self.textInput = self.convertMealPlanItemsToText(
                            selectedPlan
                        )
                        self.mealType = selectedPlan.mealType
                        self.itemsFromAI = nil
                        self.showingMealPlans = false
                    }
                )
            }
    }
}

/// Modifier for Image input related sheets, dialogs, and alerts
private struct ImageHandlingModifiers: ViewModifier {
    @Environment(\.dismiss) var dismiss

    @Binding var showingImageReview: Bool
    @Binding var recognizedItems: [RecognizedFoodItem]
    @Binding var selectedImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var imageError: String?
    @Binding var showingImageSourcePicker: Bool
    @Binding var showingCamera: Bool
    @Binding var showingPhotoLibrary: Bool
    @Binding var recognizedMealLog: DailyMealLog?
    @Binding var showingMealDetail: Bool

    let onImageReviewConfirm: (String, [RecognizedFoodItem]) -> Void
    let onRequestCameraPermissionAndShow: () -> Void
    let onProcessImage: (UIImage) async -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: self.$showingImageReview) {
                if !self.recognizedItems.isEmpty {
                    // ImageMealReviewView is commented out in the original AddMealView.
                    // This placeholder view will ensure compilation and provide a basic interaction.
                    VStack {
                        Text("ImageMealReviewView Placeholder")
                            .font(.headline)
                            .padding()
                        Text(
                            "Recognized items: \(self.recognizedItems.map(\.name).joined(separator: ", "))"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                        Button("Simulate Confirm & Dismiss") {
                            self.onImageReviewConfirm(
                                self.recognizedItems.map(\.name).joined(
                                    separator: "\n"
                                ),
                                self.recognizedItems
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .onDisappear {
                        // Ensure state is cleared if sheet is dismissed, even without explicit confirm button
                        if self.showingImageReview {
                            self.onImageReviewConfirm(
                                self.recognizedItems.map(\.name).joined(
                                    separator: "\n"
                                ),
                                self.recognizedItems
                            )
                        }
                    }
                }
            }
            .photosPicker(
                isPresented: self.$showingPhotoLibrary, selection: self.$selectedPhotoItem,
                matching: .images
            )
            .confirmationDialog(
                L10n.Nutrition.choosePhotoSource,
                isPresented: self.$showingImageSourcePicker,
                titleVisibility: .visible
            ) {
                Button(L10n.Nutrition.takePhoto) {
                    self.onRequestCameraPermissionAndShow()
                }
                Button(L10n.Nutrition.chooseFromLibrary) {
                    self.showingPhotoLibrary = true
                }
                Button(L10n.Common.cancel, role: .cancel) {
                    self.showingImageSourcePicker = false
                }
            }
            .sheet(isPresented: self.$showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    if let image = image {
                        self.selectedImage = image
                        Task {
                            await self.onProcessImage(image)
                        }
                    }
                    self.showingCamera = false
                }
            }
            .alert(
                "Image Processing Error",
                isPresented: Binding(
                    get: { self.imageError != nil },
                    set: { if !$0 { self.imageError = nil } }
                )
            ) {
                Button("OK") {
                    self.imageError = nil
                }
            } message: {
                if let error = self.imageError {
                    Text(error)
                }
            }
    }
}

// MARK: - Extensions to apply modifiers easily
extension View {
    func mealPlanSheet(
        showingMealPlans: Binding<Bool>,
        mockMealPlans: Binding<[MealPlan]>,
        textInput: Binding<String>,
        mealType: Binding<MealType>,
        itemsFromAI: Binding<[RecognizedFoodItem]?>,
        onMealPlanDelete: @escaping (UUID) -> Void,
        onMealPlanUpdate: @escaping (MealPlan, String) -> Void,
        convertMealPlanItemsToText: @escaping (MealPlan) -> String
    ) -> some View {
        modifier(
            MealPlanSheetModifier(
                showingMealPlans: showingMealPlans,
                mockMealPlans: mockMealPlans,
                textInput: textInput,
                mealType: mealType,
                itemsFromAI: itemsFromAI,
                onMealPlanDelete: onMealPlanDelete,
                onMealPlanUpdate: onMealPlanUpdate,
                convertMealPlanItemsToText: convertMealPlanItemsToText
            )
        )
    }

    func imageHandlingModifiers(
        showingImageReview: Binding<Bool>,
        recognizedItems: Binding<[RecognizedFoodItem]>,
        selectedImage: Binding<UIImage?>,
        selectedPhotoItem: Binding<PhotosPickerItem?>,
        imageError: Binding<String?>,
        showingImageSourcePicker: Binding<Bool>,
        showingCamera: Binding<Bool>,
        showingPhotoLibrary: Binding<Bool>,
        onImageReviewConfirm: @escaping (String, [RecognizedFoodItem]) -> Void,
        onRequestCameraPermissionAndShow: @escaping () -> Void,
        onProcessImage: @escaping (UIImage) async -> Void,
        recognizedMealLog: Binding<DailyMealLog?>,
        showingMealDetail: Binding<Bool>
    ) -> some View {
        self.modifier(
            ImageHandlingModifiers(
                showingImageReview: showingImageReview,
                recognizedItems: recognizedItems,
                selectedImage: selectedImage,
                selectedPhotoItem: selectedPhotoItem,
                imageError: imageError,
                showingImageSourcePicker: showingImageSourcePicker,
                showingCamera: showingCamera,
                showingPhotoLibrary: showingPhotoLibrary,
                recognizedMealLog: recognizedMealLog,
                showingMealDetail: showingMealDetail,
                onImageReviewConfirm: onImageReviewConfirm,
                onRequestCameraPermissionAndShow: onRequestCameraPermissionAndShow,
                onProcessImage: onProcessImage
            )
        )
    }
}
