//
//  AppSettingsView.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Extracted from ProfileView - App-level preferences separate from profile editing
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var deps: AppDependencies

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground).opacity(0.3),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 8) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.serenityLavender, .vitalityTeal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, 20)

                            Text("App Settings")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Customize your app experience")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)

                        // Preferences Card
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(
                                icon: "slider.horizontal.3",
                                title: "Preferences",
                                color: .serenityLavender
                            )

                            // Unit System
                            ModernPicker(
                                icon: "ruler",
                                label: "Unit System",
                                selection: $viewModel.preferredUnitSystem,
                                options: [
                                    ("metric", "Metric (kg, cm)"),
                                    ("imperial", "Imperial (lb, in)"),
                                ]
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Changes will apply throughout the app")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 28)
                            }

                            Divider()
                                .padding(.vertical, 4)

                            // Language
                            ModernPicker(
                                icon: "globe",
                                label: "Language",
                                selection: $viewModel.languageCode,
                                options: [
                                    ("en", "English"),
                                    ("es", "Español"),
                                    ("pt", "Português"),
                                    ("fr", "Français"),
                                    ("de", "Deutsch"),
                                ]
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("App will restart to apply language changes")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 28)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                        // Status Message
                        if let message = viewModel.profileUpdateMessage {
                            HStack(spacing: 12) {
                                Image(
                                    systemName: message.contains("success")
                                        ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                                )
                                .foregroundColor(message.contains("success") ? .green : .red)

                                Text(message)
                                    .font(.callout)
                                    .foregroundColor(message.contains("success") ? .green : .red)

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                (message.contains("success") ? Color.green : Color.red)
                                    .opacity(0.1)
                            )
                            .cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Save Button
                        Button {
                            Task {
                                await saveSettings()
                            }
                        } label: {
                            HStack {
                                if viewModel.isSavingProfile {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Settings")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.serenityLavender, .vitalityTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(
                                color: Color.serenityLavender.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isSavingProfile)

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.ascendBlue)
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Actions

    @MainActor
    private func saveSettings() async {
        print("AppSettingsView: Saving preferences...")
        print("AppSettingsView:   Unit System: '\(viewModel.preferredUnitSystem)'")
        print("AppSettingsView:   Language: '\(viewModel.languageCode)'")

        // Save only metadata (which includes preferences)
        await viewModel.saveProfileMetadata()

        // Dismiss after a short delay to show success message
        if viewModel.profileUpdateMessage?.contains("success") == true {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            dismiss()
        }
    }

}

extension AppSettingsView {
}

// Add this modifier to the NavigationStack
extension View {
    func withCleanupDialog(_ dialog: some View) -> some View {
        self.background(dialog)
    }
}
