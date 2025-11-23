//
//  InsightFiltersSheet.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import SwiftUI

/// Sheet for filtering AI insights
struct InsightFiltersSheet: View {
    @Bindable var viewModel: AIInsightsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Insight Type Filter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Insight Type")
                                .font(LumeTypography.titleMedium)
                                .foregroundColor(LumeColors.textPrimary)

                            VStack(spacing: 8) {
                                ForEach(InsightType.allCases, id: \.self) { type in
                                    InsightTypeFilterRow(
                                        type: type,
                                        isSelected: viewModel.filterType == type,
                                        onTap: {
                                            if viewModel.filterType == type {
                                                viewModel.setFilterType(nil)
                                            } else {
                                                viewModel.setFilterType(type)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        Divider()
                            .background(LumeColors.textSecondary.opacity(0.2))

                        // Status Filters
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status")
                                .font(LumeTypography.titleMedium)
                                .foregroundColor(LumeColors.textPrimary)

                            VStack(spacing: 8) {
                                InsightFilterToggleRow(
                                    title: "Unread Only",
                                    icon: "envelope.badge",
                                    isOn: viewModel.showUnreadOnly,
                                    onToggle: { viewModel.toggleUnreadFilter() }
                                )

                                InsightFilterToggleRow(
                                    title: "Favorites Only",
                                    icon: "star.fill",
                                    isOn: viewModel.showFavoritesOnly,
                                    onToggle: { viewModel.toggleFavoritesFilter() }
                                )

                                InsightFilterToggleRow(
                                    title: "Show Archived",
                                    icon: "archivebox.fill",
                                    isOn: viewModel.showArchived,
                                    onToggle: { viewModel.toggleArchivedFilter() }
                                )
                            }
                        }

                        // Summary
                        if viewModel.hasActiveFilters {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Active Filters")
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)

                                HStack {
                                    Text(filterSummary)
                                        .font(LumeTypography.bodySmall)
                                        .foregroundColor(LumeColors.textPrimary)

                                    Spacer()

                                    Button("Clear All") {
                                        viewModel.clearFilters()
                                    }
                                    .font(LumeTypography.bodySmall)
                                    .foregroundColor(LumeColors.accentPrimary)
                                }
                                .padding(12)
                                .background(LumeColors.surface)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.hasActiveFilters {
                        Button("Clear All") {
                            viewModel.clearFilters()
                        }
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.accentPrimary)
                    }
                }
            }
        }
    }

    private var filterSummary: String {
        var parts: [String] = []

        if let type = viewModel.filterType {
            parts.append(type.displayName)
        }
        if viewModel.showUnreadOnly {
            parts.append("Unread")
        }
        if viewModel.showFavoritesOnly {
            parts.append("Favorites")
        }
        if viewModel.showArchived {
            parts.append("Archived")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Supporting Views

struct InsightTypeFilterRow: View {
    let type: InsightType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: type.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : LumeColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected
                            ? Color(hex: type.color)
                            : Color(hex: type.color).opacity(0.15)
                    )
                    .cornerRadius(8)

                // Title
                Text(type.displayName)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary)

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: type.color))
                }
            }
            .padding(12)
            .background(isSelected ? LumeColors.surface : LumeColors.appBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: type.color).opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct InsightFilterToggleRow: View {
    let title: String
    let icon: String
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isOn ? LumeColors.accentPrimary : LumeColors.textSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary)

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { isOn },
                        set: { _ in onToggle() }
                    )
                )
                .labelsHidden()
                .tint(LumeColors.accentPrimary)
            }
            .padding(12)
            .background(LumeColors.surface)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        InsightFiltersSheet(viewModel: AIInsightsViewModel.preview)
    }
#endif
