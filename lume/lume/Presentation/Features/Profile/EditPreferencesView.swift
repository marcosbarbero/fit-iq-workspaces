//
//  EditPreferencesView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI

/// View for editing dietary preferences and restrictions
struct EditPreferencesView: View {
    let preferences: DietaryActivityPreferences?
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var allergies: [String]
    @State private var dietaryRestrictions: [String]
    @State private var foodDislikes: [String]

    @State private var newAllergy = ""
    @State private var newRestriction = ""
    @State private var newDislike = ""

    @State private var showingDeleteConfirmation = false

    init(preferences: DietaryActivityPreferences?, viewModel: ProfileViewModel) {
        self.preferences = preferences
        self.viewModel = viewModel

        _allergies = State(initialValue: preferences?.allergies ?? [])
        _dietaryRestrictions = State(initialValue: preferences?.dietaryRestrictions ?? [])
        _foodDislikes = State(initialValue: preferences?.foodDislikes ?? [])
    }

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Allergies Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Allergies")
                            .font(.custom("SF Pro Rounded", size: 20, relativeTo: .title3))
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Foods you're allergic to")
                            .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                            .foregroundColor(LumeColors.textSecondary)

                        // Add new allergy
                        HStack(spacing: 8) {
                            TextField("Add allergy", text: $newAllergy)
                                .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                                .padding(12)
                                .background(LumeColors.surface)
                                .cornerRadius(10)
                                .foregroundColor(LumeColors.textPrimary)
                                .submitLabel(.done)
                                .onSubmit {
                                    addAllergy()
                                }

                            Button {
                                addAllergy()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(LumeColors.accentSecondary)
                            }
                            .disabled(
                                newAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            .opacity(
                                newAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? 0.5 : 1.0)
                        }

                        // List of allergies
                        if !allergies.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(allergies, id: \.self) { allergy in
                                    ChipView(
                                        text: allergy,
                                        color: LumeColors.moodAngry.opacity(0.3),
                                        onDelete: {
                                            removeAllergy(allergy)
                                        }
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(LumeColors.surface.opacity(0.5))
                    .cornerRadius(16)

                    // Dietary Restrictions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dietary Restrictions")
                            .font(.custom("SF Pro Rounded", size: 20, relativeTo: .title3))
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Diets you follow (e.g., vegetarian, vegan, gluten-free)")
                            .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                            .foregroundColor(LumeColors.textSecondary)

                        // Add new restriction
                        HStack(spacing: 8) {
                            TextField("Add restriction", text: $newRestriction)
                                .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                                .padding(12)
                                .background(LumeColors.surface)
                                .cornerRadius(10)
                                .foregroundColor(LumeColors.textPrimary)
                                .submitLabel(.done)
                                .onSubmit {
                                    addRestriction()
                                }

                            Button {
                                addRestriction()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(LumeColors.accentSecondary)
                            }
                            .disabled(
                                newRestriction.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty
                            )
                            .opacity(
                                newRestriction.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty ? 0.5 : 1.0)
                        }

                        // List of restrictions
                        if !dietaryRestrictions.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(dietaryRestrictions, id: \.self) { restriction in
                                    ChipView(
                                        text: restriction,
                                        color: LumeColors.accentPrimary.opacity(0.4),
                                        onDelete: {
                                            removeRestriction(restriction)
                                        }
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(LumeColors.surface.opacity(0.5))
                    .cornerRadius(16)

                    // Food Dislikes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Food Dislikes")
                            .font(.custom("SF Pro Rounded", size: 20, relativeTo: .title3))
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Foods you prefer to avoid")
                            .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                            .foregroundColor(LumeColors.textSecondary)

                        // Add new dislike
                        HStack(spacing: 8) {
                            TextField("Add food dislike", text: $newDislike)
                                .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                                .padding(12)
                                .background(LumeColors.surface)
                                .cornerRadius(10)
                                .foregroundColor(LumeColors.textPrimary)
                                .submitLabel(.done)
                                .onSubmit {
                                    addDislike()
                                }

                            Button {
                                addDislike()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(LumeColors.accentSecondary)
                            }
                            .disabled(
                                newDislike.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            .opacity(
                                newDislike.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? 0.5 : 1.0)
                        }

                        // List of dislikes
                        if !foodDislikes.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(foodDislikes, id: \.self) { dislike in
                                    ChipView(
                                        text: dislike,
                                        color: LumeColors.moodAnxious.opacity(0.5),
                                        onDelete: {
                                            removeDislike(dislike)
                                        }
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(LumeColors.surface.opacity(0.5))
                    .cornerRadius(16)

                    // Buttons
                    VStack(spacing: 12) {
                        // Save Button
                        Button {
                            Task {
                                await savePreferences()
                            }
                        } label: {
                            ZStack {
                                if viewModel.isSavingPreferences {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save Changes")
                                        .font(
                                            .custom("SF Pro Rounded", size: 17, relativeTo: .body)
                                        )
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LumeColors.accentSecondary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isSavingPreferences)

                        // Delete All Preferences Button (if preferences exist)
                        if preferences != nil {
                            Button {
                                showingDeleteConfirmation = true
                            } label: {
                                Text("Delete All Preferences")
                                    .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(LumeColors.moodAngry.opacity(0.2))
                                    .cornerRadius(12)
                            }
                            .disabled(viewModel.isSavingPreferences)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Dietary Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(LumeColors.textSecondary)
            }
        }
        .alert("Delete All Preferences", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAllPreferences()
                }
            }
        } message: {
            Text(
                "Are you sure you want to delete all your dietary preferences? This action cannot be undone."
            )
        }
    }

    // MARK: - Actions

    private func addAllergy() {
        let trimmed = newAllergy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !allergies.contains(trimmed) else { return }
        allergies.append(trimmed)
        newAllergy = ""
    }

    private func removeAllergy(_ allergy: String) {
        allergies.removeAll { $0 == allergy }
    }

    private func addRestriction() {
        let trimmed = newRestriction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !dietaryRestrictions.contains(trimmed) else { return }
        dietaryRestrictions.append(trimmed)
        newRestriction = ""
    }

    private func removeRestriction(_ restriction: String) {
        dietaryRestrictions.removeAll { $0 == restriction }
    }

    private func addDislike() {
        let trimmed = newDislike.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !foodDislikes.contains(trimmed) else { return }
        foodDislikes.append(trimmed)
        newDislike = ""
    }

    private func removeDislike(_ dislike: String) {
        foodDislikes.removeAll { $0 == dislike }
    }

    private func savePreferences() async {
        await viewModel.updatePreferences(
            allergies: allergies,
            dietaryRestrictions: dietaryRestrictions,
            foodDislikes: foodDislikes
        )

        // Dismiss on success
        if viewModel.showingSuccess {
            dismiss()
        }
    }

    private func deleteAllPreferences() async {
        await viewModel.deletePreferences()

        // Dismiss on success
        if viewModel.showingSuccess {
            dismiss()
        }
    }
}

// MARK: - ChipView Component

/// A chip view with text and delete button
struct ChipView: View {
    let text: String
    let color: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.custom("SF Pro Rounded", size: 14, relativeTo: .caption))
                .foregroundColor(LumeColors.textPrimary)

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(LumeColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color)
        .cornerRadius(12)
    }
}
