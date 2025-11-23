//
//  TemplateCopySheet.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

/// Sheet view for copying a workout template to user's library
/// FIELD BINDINGS ONLY - Minimal UI for data interaction
struct TemplateCopySheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: WorkoutTemplateSharingViewModel

    let templateId: UUID
    let originalTemplateName: String
    let onCopySuccess: ((WorkoutTemplate) -> Void)?

    // MARK: - State (Field Bindings)
    @State private var newName: String = ""
    @State private var useOriginalName: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Copy Options") {
                    Toggle("Use Original Name", isOn: $useOriginalName)
                        .tint(.vitalityTeal)
                }

                if !useOriginalName {
                    Section("New Template Name") {
                        TextField("Enter new name", text: $newName)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Original Template", systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(originalTemplateName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
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
            .navigationTitle("Copy Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") {
                        Task {
                            await copyTemplate()
                        }
                    }
                    .disabled(viewModel.isCopying || (!useOriginalName && newName.isEmpty))
                }
            }
            .disabled(viewModel.isCopying)
        }
    }

    // MARK: - Actions (Field Binding to Remote Call)
    private func copyTemplate() async {
        let nameToUse =
            useOriginalName ? nil : newName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let copiedTemplate = await viewModel.copyTemplate(
            templateId: templateId,
            newName: nameToUse
        ) {
            // Notify caller of success
            onCopySuccess?(copiedTemplate)

            // Close sheet after successful copy
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}
