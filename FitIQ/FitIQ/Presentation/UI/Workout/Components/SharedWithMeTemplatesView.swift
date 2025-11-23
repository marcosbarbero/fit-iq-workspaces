//
//  SharedWithMeTemplatesView.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

/// View for displaying workout templates shared with the authenticated user
/// FIELD BINDINGS ONLY - Minimal UI for data interaction
struct SharedWithMeTemplatesView: View {
    @Bindable var viewModel: WorkoutTemplateSharingViewModel

    let onCopyTemplate: ((UUID, String) -> Void)?
    let onViewTemplateDetail: ((UUID) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingSharedTemplates && viewModel.sharedWithMeTemplates.isEmpty {
                    ProgressView("Loading shared templates...")
                } else if viewModel.sharedWithMeTemplates.isEmpty {
                    emptyStateView
                } else {
                    templatesList
                }
            }
            .navigationTitle("Shared With Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await viewModel.updateProfessionalTypeFilter(nil)
                            }
                        } label: {
                            Label("All", systemImage: "line.3.horizontal.decrease.circle")
                        }

                        Divider()

                        ForEach(ProfessionalType.allCases, id: \.self) { type in
                            Button {
                                Task {
                                    await viewModel.updateProfessionalTypeFilter(type)
                                }
                            } label: {
                                Label(type.displayName, systemImage: "person.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshSharedTemplates()
            }
            .task {
                if viewModel.sharedWithMeTemplates.isEmpty {
                    await viewModel.loadSharedWithMeTemplates()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Shared Templates")
                .font(.headline)

            Text("Templates shared with you by professionals will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Templates List

    private var templatesList: some View {
        List {
            ForEach(viewModel.sharedWithMeTemplates) { template in
                SharedTemplateRow(
                    template: template,
                    onCopy: { onCopyTemplate?(template.templateId, template.name) },
                    onViewDetail: { onViewTemplateDetail?(template.templateId) }
                )
            }

            if viewModel.hasMoreSharedTemplates {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .task {
                    await viewModel.loadMoreSharedTemplates()
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Shared Template Row

struct SharedTemplateRow: View {
    let template: SharedTemplateInfo
    let onCopy: () -> Void
    let onViewDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Template name and professional badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Image(systemName: professionalIcon)
                            .font(.caption2)
                        Text(template.professionalType.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.serenityLavender)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.serenityLavender.opacity(0.15))
                    .cornerRadius(6)
                }

                Spacer()
            }

            // Template details
            if let description = template.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Stats row
            HStack(spacing: 16) {
                if let duration = template.estimatedDurationMinutes {
                    Label("\(duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(
                    "\(template.exerciseCount) exercises",
                    systemImage: "figure.strengthtraining.traditional"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let difficulty = template.difficultyLevel {
                    Label(difficulty.rawValue.capitalized, systemImage: "chart.bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Professional info and share date
            HStack {
                Label(template.professionalName, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(template.sharedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Notes if available
            if let notes = template.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemFill))
                .cornerRadius(8)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onViewDetail()
                } label: {
                    Label("View", systemImage: "eye")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.vitalityTeal)
            }
        }
        .padding(.vertical, 8)
    }

    private var professionalIcon: String {
        switch template.professionalType {
        case .personalTrainer:
            return "figure.strengthtraining.traditional"
        case .nutritionist:
            return "leaf.fill"
        case .physicalTherapist:
            return "cross.case.fill"
        case .sportsCoach:
            return "sportscourt.fill"
        }
    }
}
