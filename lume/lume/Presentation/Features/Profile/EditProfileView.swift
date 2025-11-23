//
//  EditProfileView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI

/// View for editing basic profile information
struct EditProfileView: View {
    let profile: UserProfile
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var bio: String
    @State private var unitSystem: UnitSystem
    @State private var languageCode: String

    init(profile: UserProfile, viewModel: ProfileViewModel) {
        self.profile = profile
        self.viewModel = viewModel

        _name = State(initialValue: profile.name)
        _bio = State(initialValue: profile.bio ?? "")
        _unitSystem = State(initialValue: profile.preferredUnitSystem)
        _languageCode = State(initialValue: profile.languageCode)
    }

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        TextField("Enter your name", text: $name)
                            .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                            .padding(16)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                            .foregroundColor(LumeColors.textPrimary)
                    }

                    // Bio Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Optional - Tell us a bit about yourself")
                            .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                            .foregroundColor(LumeColors.textSecondary)

                        TextEditor(text: $bio)
                            .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                            .foregroundColor(LumeColors.textPrimary)
                            .scrollContentBackground(.hidden)
                    }

                    // Unit System Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unit System")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        Picker("Unit System", selection: $unitSystem) {
                            ForEach(UnitSystem.allCases, id: \.self) { system in
                                Text(system.displayName)
                                    .tag(system)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(4)
                        .background(LumeColors.surface)
                        .cornerRadius(12)
                    }

                    // Language Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Language")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        Menu {
                            Button {
                                languageCode = "en"
                            } label: {
                                HStack {
                                    Text("English")
                                    if languageCode == "en" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                languageCode = "es"
                            } label: {
                                HStack {
                                    Text("Español")
                                    if languageCode == "es" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                languageCode = "fr"
                            } label: {
                                HStack {
                                    Text("Français")
                                    if languageCode == "fr" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                languageCode = "de"
                            } label: {
                                HStack {
                                    Text("Deutsch")
                                    if languageCode == "de" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                languageCode = "pt"
                            } label: {
                                HStack {
                                    Text("Português")
                                    if languageCode == "pt" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(languageDisplayName)
                                    .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                                    .foregroundColor(LumeColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(LumeColors.textSecondary)
                            }
                            .padding(16)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                        }
                    }

                    // Save Button
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        ZStack {
                            if viewModel.isSavingProfile {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LumeColors.accentSecondary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isSavingProfile || !isValid)
                    .opacity(isValid ? 1.0 : 0.6)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(LumeColors.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var languageDisplayName: String {
        Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
    }

    private func saveProfile() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.updateProfile(
            name: trimmedName,
            bio: trimmedBio.isEmpty ? nil : trimmedBio,
            unitSystem: unitSystem,
            languageCode: languageCode
        )

        // Dismiss on success
        if viewModel.showingSuccess {
            dismiss()
        }
    }
}
