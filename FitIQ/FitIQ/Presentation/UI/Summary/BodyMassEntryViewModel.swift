// Presentation/ViewModels/BodyMassEntryViewModel.swift
import Foundation
import Observation
import HealthKit // For HKUnit
import SwiftUI // For @MainActor
import Combine

final class BodyMassEntryViewModel: ObservableObject {
    private let saveBodyMassUseCase: SaveBodyMassUseCaseProtocol
    private let getLatestBodyMetricsUseCase: GetLatestBodyMetricsUseCase // To get initial value

    var currentWeightInput: String = ""
    var selectedWeight: Double = 0.0
    var isSaving: Bool = false
    var lastWeight: Double? // Holds the last fetched weight for initial view setup
    var errorMessage: String?
    
    // For UI focus management
    @MainActor @Published var isInputFocused: Bool = false

    init(saveBodyMassUseCase: SaveBodyMassUseCaseProtocol,
         getLatestBodyMetricsUseCase: GetLatestBodyMetricsUseCase) {
        self.saveBodyMassUseCase = saveBodyMassUseCase
        self.getLatestBodyMetricsUseCase = getLatestBodyMetricsUseCase
        
        // Load initial weight when ViewModel is created
        Task { await loadLastWeight() }
        
        // Initialize with default or last known weight (will be updated by loadLastWeight)
        self.selectedWeight = lastWeight ?? 70.0
        self.currentWeightInput = String(format: "%.1f", self.selectedWeight)
    }
    
    @MainActor
    func loadLastWeight() async {
        do {
            let metrics = try await getLatestBodyMetricsUseCase.execute()
            self.lastWeight = metrics.weightKg
            if let weight = metrics.weightKg {
                self.selectedWeight = weight
                self.currentWeightInput = String(format: "%.1f", weight)
            } else {
                // If no last weight, default to 70kg (as per view's current default)
                self.selectedWeight = 70.0
                self.currentWeightInput = String(format: "%.1f", 70.0)
            }
            print("BodyMassEntryViewModel: Loaded last weight: \(String(describing: self.lastWeight))")
        } catch {
            print("BodyMassEntryViewModel: Failed to load last weight: \(error.localizedDescription)")
            self.errorMessage = "Failed to load previous weight: \(error.localizedDescription)"
            // Still initialize with a default if loading fails
            self.selectedWeight = 70.0
            self.currentWeightInput = String(format: "%.1f", 70.0)
        }
    }

    var isInputValid: Bool {
        if isInputFocused {
            guard let weight = NumberFormatHelper.decimal.number(from: currentWeightInput)?.doubleValue else { return false }
            return weight > 0 && weight < 500
        } else {
            return selectedWeight > 0 && selectedWeight < 500
        }
    }
    
    var displayWeight: String {
        String(format: "%.1f", selectedWeight)
    }

    @MainActor
    func saveWeight() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        do {
            // Ensure selectedWeight is derived from parsed input when typing, otherwise use the drag value
            let weightToSave = isInputFocused ? (NumberFormatHelper.decimal.number(from: currentWeightInput)?.doubleValue ?? selectedWeight) : selectedWeight
            
            guard isInputValid else {
                errorMessage = "Please enter a valid weight (0-500 kg)."
                isSaving = false
                return
            }
            
            print("BodyMassEntryViewModel: Saving weight: \(weightToSave)kg")
            
            // The UseCase handles HealthKit authorization and saving.
            // HealthKit observer queries will trigger local and remote sync.
            try await saveBodyMassUseCase.execute(weightKg: weightToSave, date: Date())
            
            print("BodyMassEntryViewModel: Weight saved successfully.")
            // Optionally, refresh last weight after successful save
            await loadLastWeight()

        } catch let error as LocalizedError {
            self.errorMessage = error.errorDescription ?? "An unknown error occurred."
            print("BodyMassEntryViewModel: Error saving weight: \(error.localizedDescription)")
        } catch {
            self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            print("BodyMassEntryViewModel: Unexpected error saving weight: \(error.localizedDescription)")
        }
        
        isSaving = false
    }
    
    // Helper to update selectedWeight from input string (used by TextField onChange)
    @MainActor
    func updateSelectedWeight(from input: String) {
        if let weight = NumberFormatHelper.decimal.number(from: input)?.doubleValue {
            selectedWeight = weight
        }
    }
}
