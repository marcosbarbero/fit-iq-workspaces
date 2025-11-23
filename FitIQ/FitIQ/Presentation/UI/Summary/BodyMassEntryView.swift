//
//  BodyMassEntryView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 16/10/2025.
//

import Foundation
import SwiftUI

struct BodyMassEntryView: View {
    @Environment(\.dismiss) var dismiss
    
    // Inject and observe the ViewModel for logic and data
    @StateObject var viewModel: BodyMassEntryViewModel
    
    // UI-specific states from the original working version
    @State private var currentWeightInput: String = "" // Initialized in onAppear
    @State private var selectedWeight: Double = 0.0    // Initialized in onAppear
    @State private var dragStartWeight: Double = 0     // Initialized in onAppear
    @FocusState private var isInputFocused: Bool
    
    // Bind to ViewModel's isSaving state
    private var isSaving: Bool {
        viewModel.isSaving
    }
    
    private let primaryColor: Color = Color.ascendBlue
    
    // Callback for the parent view AFTER a successful save via ViewModel
    let onSaveSuccess: (Double) -> Void
    
    // MARK: - Initializer
    
    // Now takes the ViewModel and the success callback
    init(viewModel: BodyMassEntryViewModel, onSaveSuccess: @escaping (Double) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSaveSuccess = onSaveSuccess
        
        // Initial values for @State properties will be set in .onAppear
        // based on the ViewModel's data once it has loaded.
    }
    
    // MARK: - Computed Properties
    
    private var parsedWeight: Double? {
        NumberFormatHelper.decimal.number(from: currentWeightInput)?.doubleValue
    }
    
    private var isInputValid: Bool {
        // Use the ViewModel's validation logic, which also depends on parsedWeight
        // This effectively keeps the validation consistent with the original logic.
        viewModel.isInputValid
    }
    
    private var displayWeight: String {
        String(format: "%.1f", selectedWeight)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    
                    // MARK: - Visual Feedback (Scale Icon)
                    VStack(spacing: 16) {
                        Image(systemName: "scalemass.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .foregroundColor(primaryColor)
                            .scaleEffect(isInputValid ? 1.05 : 1.0)
                            .animation(.spring(duration: 0.3), value: isInputValid)
                        
                        Text(L10n.Profile.enterWeight) // Localized
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 30)
                    
                    // MARK: - Weight Input Field with Drag Gesture
                    VStack(spacing: 12) {
                        // Drag instruction (hide when typing)
                        if !isInputFocused {
                            Text(L10n.Profile.swipeAdjust) // Localized
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Weight display with drag gesture OR typing
                        VStack(spacing: 4) {
                            ZStack {
                                // Text display (hidden when typing)
                                Text(displayWeight)
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundColor(primaryColor)
                                    .contentTransition(.numericText())
                                    .opacity(isInputFocused ? 0 : 1)
                                
                                // TextField (hidden when not typing)
                                TextField("0.0", text: $currentWeightInput)
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(primaryColor)
                                    .focused($isInputFocused)
                                    .onChange(of: currentWeightInput) { oldValue, newValue in
                                        if let weight = parsedWeight {
                                            selectedWeight = weight
                                            // Update drag start weight when typing changes the value
                                            dragStartWeight = weight
                                        }
                                    }
                                    .opacity(isInputFocused ? 1 : 0)
                            }
                            .onTapGesture {
                                // Tap on the number to enable typing
                                isInputFocused = true
                            }
                            
                            Text(L10n.Unit.kg) // Localized
                                .font(.callout)
                                .foregroundColor(.secondary)
                            
                            // Visual indicator (hide when typing)
                            if !isInputFocused {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.caption2)
                                    Text(L10n.Profile.swipeIncrement) // Localized
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(primaryColor.opacity(isInputFocused ? 0.6 : 0.3), lineWidth: 2)
                                )
                        )
                        .gesture(
                            // Only enable drag when not typing
                            isInputFocused ? nil : DragGesture()
                                .onChanged { value in
                                    // Calculate how many increments based on drag distance
                                    let dragDistance = value.translation.height
                                    let steps = Int(-round(dragDistance / 20))
                                    let increment = Double(steps) * 0.1
                                    
                                    // Calculate new weight from the drag start weight
                                    let newWeight = max(0, min(500, dragStartWeight + increment))
                                    
                                    // Only update if there's a change of at least 0.1kg
                                    if abs(newWeight - selectedWeight) >= 0.05 {
                                        selectedWeight = newWeight
                                        currentWeightInput = String(format: "%.1f", newWeight)
                                        
                                        // Haptic feedback for each 0.1kg change
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }
                                }
                                .onEnded { _ in
                                    // Update drag start weight for next gesture
                                    dragStartWeight = selectedWeight
                                }
                        )
                        .onAppear {
                            // Initialize drag start weight
                            dragStartWeight = selectedWeight
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // MARK: - Error Message
                    // Display error message from ViewModel
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    
                    // MARK: - Save Button
                    Button {
                        saveAction()
                    } label: {
                        HStack {
                            if isSaving { // Use local isSaving, which is bound to ViewModel's
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text(L10n.Profile.saveWeight) // Localized
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isInputValid && !isSaving ? primaryColor : Color.gray)
                        .cornerRadius(16)
                    }
                    .disabled(!isInputValid || isSaving)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
                .animation(.easeInOut(duration: 0.2), value: isInputValid)
            }
            .scrollDismissesKeyboard(.interactively)
            // Use localized title
//            .navigationTitle(L10n.Navigation.Title.bodyMass) // Ensure 'bodyMass' is added to L10n.Navigation.Title
            .navigationTitle("Update your body mass") // Ensure 'bodyMass' is added to L10n.Navigation.Title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { // Localized
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize local @State properties from the ViewModel's loaded data
                selectedWeight = viewModel.selectedWeight
                currentWeightInput = String(format: "%.1f", viewModel.selectedWeight)
                dragStartWeight = viewModel.selectedWeight
                
                // Ensure ViewModel has loaded the latest weight
                Task { await viewModel.loadLastWeight() }
            }
            // Synchronize ViewModel's isInputFocused with local FocusState
            .onChange(of: isInputFocused) { _, newValue in
                viewModel.isInputFocused = newValue
            }
            // Synchronize ViewModel's selectedWeight to local selectedWeight if ViewModel updates it
            // (e.g., after loading latest weight or if external changes occur)
            .onChange(of: viewModel.selectedWeight) { _, newValue in
                if !isInputFocused { // Only update if not actively typing
                    selectedWeight = newValue
                    currentWeightInput = String(format: "%.1f", newValue)
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Save Logic
    
    private func saveAction() {
        hideKeyboard()
        
        // Update ViewModel's selectedWeight from the UI's final selectedWeight
        // This ensures the ViewModel has the latest value from the UI, especially if typed.
        viewModel.selectedWeight = selectedWeight
        
        Task {
            // Tell ViewModel to save
            await viewModel.saveWeight()
            
            // Only dismiss if the save operation was successful (no error message)
            if viewModel.errorMessage == nil {
                onSaveSuccess(selectedWeight) // Use the view's selectedWeight as the final saved value
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Functions
        
    private func hideKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
