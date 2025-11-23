//
//  TemplateShareSheet.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

/// Sheet view for sharing a workout template with users
/// FIELD BINDINGS ONLY - Minimal UI for data interaction
struct TemplateShareSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: WorkoutTemplateSharingViewModel

    let templateId: UUID
    let templateName: String

    // MARK: - State (Field Bindings)
    @State private var selectedUserIds: String = ""  // Comma-separated UUIDs
    @State private var selectedProfessionalType: ProfessionalType = .personalTrainer
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("User IDs to Share With") {
                    TextField(
                        "Enter user IDs (comma-separated)", text: $selectedUserIds, axis: .vertical
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                Section("Professional Type") {
                    Picker("Type", selection: $selectedProfessionalType) {
                        ForEach(ProfessionalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add notes about this share", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Share \(templateName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        Task {
                            await shareTemplate()
                        }
                    }
                    .disabled(viewModel.isSharing || selectedUserIds.isEmpty)
                }
            }
            .disabled(viewModel.isSharing)
        }
    }

    // MARK: - Actions (Field Binding to Remote Call)
    private func shareTemplate() async {
        // Parse comma-separated UUIDs
        let userIds =
            selectedUserIds
            .split(separator: ",")
            .compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        guard !userIds.isEmpty else {
            viewModel.errorMessage = "Please enter valid user IDs"
            return
        }

        await viewModel.shareTemplate(
            templateId: templateId,
            userIds: userIds,
            professionalType: selectedProfessionalType,
            notes: notes.isEmpty ? nil : notes
        )

        if viewModel.successMessage != nil {
            // Close sheet after successful share
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}
