//
//  AddMealViewModel.swift
//  HealthRestart
//
//  Created by Marcos Barbero on 10/10/2025.
//

import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UIKit

// Mock structure for an item added via AI/Search
struct LoggedItem: Identifiable {
    let id = UUID()
    let name: String  // e.g., "Banana"
    let quantity: String  // e.g., "1 medium" or "1 scoop"
    let calories: Int
    let protein: Double
    let carbs: Double  // NEW: Added Carbs and Fat
    let fat: Double

    /// For UI display compatibility - returns the quantity string as-is
    var quantityDescription: String {
        quantity
    }
}

// MARK: - AddMealViewModel (The Adapter)

@Observable
final class AddMealViewModel {

    // --- State Properties (formerly @State in the View) ---
    var textInput: String = ""
    var mealType: MealType
    var selectedDate: Date = Date()
    var isProcessingImage: Bool = false
    var recognizedItems: [RecognizedFoodItem] = []
    var imageError: String?

    var showingMealPlans: Bool = false
    var showingImageSourcePicker: Bool = false
    var showingImageReview: Bool = false
    var showingCamera: Bool = false
    var showingPhotoLibrary: Bool = false

    // Properties specific to image/speech handling
    var selectedPhotoItem: PhotosPickerItem?
    var selectedImage: UIImage?  // For review

    private var itemsFromAI: [RecognizedFoodItem]?  // Internal state for pre-parsed data

    // --- Dependencies (Ports) ---
    //    private let addMealUseCase: CreateMealGroupFromInputUseCase
    //    private let imageMealParser: ImageMealParserService? // Optional dependency
    //    private let quickLogVm: QuickLogViewModel
    //    private let mealPlanVm: MealPlanViewModel

    // External components managed by the VM
    let speechRecognizer = SpeechRecognizer()

    // Computed Properties for View
    var isSaveButtonEnabled: Bool {
        !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Initialization

    init(
        //        addMealUseCase: CreateMealGroupFromInputUseCase,
        //        imageMealParser: ImageMealParserService? = nil,
        //        quickLogVm: QuickLogViewModel,
        //        mealPlanVm: MealPlanViewModel,
        initialMealType: MealType? = nil
    ) {
        //        self.addMealUseCase = addMealUseCase
        //        self.imageMealParser = imageMealParser
        //        self.quickLogVm = quickLogVm
        //        self.mealPlanVm = mealPlanVm

        // Logic moved from the View's init
        self.mealType = initialMealType ?? Self.determineInitialMealType()

        // Initial setup for quick log entries is now managed in the View's .onAppear,
        // calling a loading function on the respective VMs.

        // This VM is tightly coupled to the meal plans VM and QuickLog VM,
        // as the AddMealView is the "orchestrator" for these features.
    }

    // MARK: - State Management

    func clearInput() {
        speechRecognizer.stopRecording()
        speechRecognizer.recognizedText = ""
        textInput = ""
        itemsFromAI = nil
    }

    // MARK: - Speech Recognition Logic

    func startRecording() {
        self.clearInput()  // Clear before starting a new dictation
        do {
            try speechRecognizer.startRecording()
        } catch {
            print("Error starting recording: \(error.localizedDescription)")
            // Future: Set an error state property on the VM
        }
    }

    // The View will listen to `speechRecognizer.recognizedText` directly
    // but the VM encapsulates the action.

    // MARK: - Image Parsing Logic (SRP & Liskov Substitution Principle adherence)

    func requestCameraPermissionAndShow() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showingCamera = true
                    } else {
                        self?.imageError =
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

    func processImage(_ image: UIImage) async {
        print("ProcessImage called")
        //        guard let parser = imageMealParser else { return }

        //        await MainActor.run {
        //            isProcessingImage = true
        //            imageError = nil
        //            selectedImage = image
        //        }
        //
        //        do {
        //            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        //                throw ImageProcessingError.conversionFailed
        //            }
        //
        //            let items = try await parser.parseImageToMeal(imageData: imageData)
        //
        //            await MainActor.run {
        //                self.recognizedItems = items
        //                if items.isEmpty {
        //                    self.imageError = "No food items were recognized."
        //                } else {
        //                    self.showingImageReview = true
        //                }
        //            }
        //        } catch {
        //            await MainActor.run {
        //                self.imageError = "Failed to process image: \(error.localizedDescription)"
        //            }
        //        }
        //
        //        await MainActor.run {
        //            isProcessingImage = false
        //        }
    }

    func processSelectedPhoto() async {
        print("ProcessSelectedPhoto called")
        //        guard let selectedPhotoItem = selectedPhotoItem,
        //              let parser = imageMealParser else {
        //            return
        //        }
        //
        //        await MainActor.run {
        //            isProcessingImage = true
        //            imageError = nil
        //        }
        //
        //        do {
        //            guard let imageData = try await selectedPhotoItem.loadTransferable(type: Data.self) else {
        //                throw ImageProcessingError.loadFailed
        //            }
        //
        //            if let uiImage = UIImage(data: imageData) {
        //                await MainActor.run { selectedImage = uiImage }
        //            }
        //
        //            let items = try await parser.parseImageToMeal(imageData: imageData)
        //
        //            await MainActor.run {
        //                self.recognizedItems = items
        //                if items.isEmpty {
        //                    self.imageError = "No food items were recognized."
        //                } else {
        //                    self.showingImageReview = true
        //                }
        //            }
        //        } catch {
        //            await MainActor.run {
        //                self.imageError = "Failed to process image: \(error.localizedDescription)"
        //            }
        //        }
        //
        //        await MainActor.run {
        //            isProcessingImage = false
        //        }
    }

    // MARK: - Meal Completion

    // Called when user confirms items from ImageMealReviewView
    func confirmRecognizedItems(mealText: String) {
        textInput = mealText
        itemsFromAI = recognizedItems

        // Clear temporary image states
        selectedPhotoItem = nil
        selectedImage = nil
        recognizedItems = []
        showingImageReview = false
    }

    func saveMeal() async {
        print("SaveMeal called")
        //        let textToSave = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        //
        //        guard !textToSave.isEmpty else { return }
        //
        //        // Stop recording
        //        speechRecognizer.stopRecording()
        //
        //        // The AddMealData DTO no longer includes recognizedItems during the initial save.
        //        let data = Meal(
        //            text: textToSave,
        //            mealType: mealType,
        //            date: selectedDate,
        //            recognizedItems: nil // No AI items at this stage
        //        )
        //
        //        do {
        //            // Step 3: Execute use case to save PENDING meal and dispatch event
        //            try await addMealUseCase.execute(mealData: data)
        //        } catch {
        //            // Handle and display persistence error
        //            print("Error saving initial meal: \(error)")
        //        }

    }

    // MARK: - Static Helpers (Cohesive to the ViewModel, not reusable core logic)

    private static func determineInitialMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return .breakfast
        case 12..<16: return .lunch
        case 18..<22: return .dinner
        default: return .snack
        }
    }

    private enum ImageProcessingError: Error {
        case conversionFailed
        case loadFailed
    }
}
