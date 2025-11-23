//
//  FilterView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import SwiftUI

/// Filter view for filtering journal entries by various criteria
struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: JournalViewModel

    @State private var localFilterType: EntryType?
    @State private var localFilterTag: String?
    @State private var localFilterFavoritesOnly: Bool = false
    @State private var localFilterLinkedToMood: Bool = false

    var hasChanges: Bool {
        localFilterType != viewModel.filterType || localFilterTag != viewModel.filterTag
            || localFilterFavoritesOnly != viewModel.filterFavoritesOnly
            || localFilterLinkedToMood != viewModel.filterLinkedToMood
    }

    var availableTags: [String] {
        var allTags: [String: Int] = [:]
        for entry in viewModel.entries {
            for tag in entry.tags {
                allTags[tag, default: 0] += 1
            }
        }
        return allTags.sorted { $0.value > $1.value }.map { $0.key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Entry Type Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Entry Type")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        VStack(spacing: 8) {
                            ForEach(EntryType.allCases) { type in
                                FilterTypeButton(
                                    type: type,
                                    isSelected: localFilterType == type,
                                    onTap: {
                                        if localFilterType == type {
                                            localFilterType = nil
                                        } else {
                                            localFilterType = type
                                        }
                                    }
                                )
                            }
                        }
                    }

                    Divider()

                    // Tag Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        if availableTags.isEmpty {
                            Text("No tags available")
                                .font(LumeTypography.bodySmall)
                                .foregroundColor(LumeColors.textSecondary)
                                .italic()
                                .padding(.vertical, 8)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(availableTags.prefix(20), id: \.self) { tag in
                                    FilterTagButton(
                                        tag: tag,
                                        isSelected: localFilterTag == tag,
                                        onTap: {
                                            if localFilterTag == tag {
                                                localFilterTag = nil
                                            } else {
                                                localFilterTag = tag
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }

                    Divider()

                    // Quick Filters
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Filters")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        VStack(spacing: 12) {
                            // Favorites
                            FilterToggleRow(
                                icon: "star.fill",
                                label: "Favorites Only",
                                iconColor: Color(hex: "#FFD700"),
                                isOn: $localFilterFavoritesOnly
                            )

                            // Mood linked
                            FilterToggleRow(
                                icon: "link",
                                label: "Linked to Mood",
                                iconColor: Color(hex: "#F5DFA8"),
                                isOn: $localFilterLinkedToMood
                            )
                        }
                    }

                    // Active filters summary
                    if hasActiveLocalFilters {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Filters")
                                .font(LumeTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(LumeColors.textPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                if let type = localFilterType {
                                    FilterSummaryRow(
                                        label: "Type: \(type.displayName)",
                                        icon: type.icon,
                                        color: Color(hex: type.colorHex)
                                    )
                                }

                                if let tag = localFilterTag {
                                    FilterSummaryRow(
                                        label: "Tag: #\(tag)",
                                        icon: "tag",
                                        color: LumeColors.accentPrimary
                                    )
                                }

                                if localFilterFavoritesOnly {
                                    FilterSummaryRow(
                                        label: "Favorites only",
                                        icon: "star.fill",
                                        color: Color(hex: "#FFD700")
                                    )
                                }

                                if localFilterLinkedToMood {
                                    FilterSummaryRow(
                                        label: "Linked to mood",
                                        icon: "link",
                                        color: Color(hex: "#F5DFA8")
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(LumeColors.appBackground.ignoresSafeArea())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if hasActiveLocalFilters {
                            Button("Clear") {
                                clearAllFilters()
                            }
                            .foregroundColor(Color(hex: "#F0B8A4"))
                        }

                        Button("Apply") {
                            applyFilters()
                            dismiss()
                        }
                        .foregroundColor(Color(hex: "#F2C9A7"))
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
    }

    private var hasActiveLocalFilters: Bool {
        localFilterType != nil || localFilterTag != nil || localFilterFavoritesOnly
            || localFilterLinkedToMood
    }

    private func loadCurrentFilters() {
        localFilterType = viewModel.filterType
        localFilterTag = viewModel.filterTag
        localFilterFavoritesOnly = viewModel.filterFavoritesOnly
        localFilterLinkedToMood = viewModel.filterLinkedToMood
    }

    private func applyFilters() {
        viewModel.filterType = localFilterType
        viewModel.filterTag = localFilterTag
        viewModel.filterFavoritesOnly = localFilterFavoritesOnly
        viewModel.filterLinkedToMood = localFilterLinkedToMood
    }

    private func clearAllFilters() {
        localFilterType = nil
        localFilterTag = nil
        localFilterFavoritesOnly = false
        localFilterLinkedToMood = false
    }
}

// MARK: - Filter Components

struct FilterTypeButton: View {
    let type: EntryType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: type.colorHex))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)

                    Text(type.description)
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: type.colorHex))
                }
            }
            .padding()
            .background(
                isSelected
                    ? Color(hex: type.colorHex).opacity(0.15)
                    : LumeColors.surface
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? Color(hex: type.colorHex).opacity(0.3)
                            : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

struct FilterTagButton: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("#\(tag)")
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(
                        isSelected
                            ? Color(hex: "#F2C9A7")
                            : LumeColors.textPrimary
                    )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#F2C9A7"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color(hex: "#F2C9A7").opacity(0.2)
                    : LumeColors.surface
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? Color(hex: "#F2C9A7").opacity(0.4)
                            : LumeColors.textSecondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
    }
}

struct FilterToggleRow: View {
    let icon: String
    let label: String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 32)

            Text(label)
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(iconColor)
        }
        .padding()
        .background(LumeColors.surface)
        .cornerRadius(12)
    }
}

struct FilterSummaryRow: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(label)
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - Previews

#Preview("No Filters") {
    let viewModel = JournalViewModel(
        journalRepository: MockJournalRepository(),
        moodRepository: MockMoodRepository()
    )

    FilterView(viewModel: viewModel)
}

#Preview("With Entries") {
    let viewModel = JournalViewModel(
        journalRepository: MockJournalRepository(),
        moodRepository: MockMoodRepository()
    )

    FilterView(viewModel: viewModel)
}

#Preview("With Active Filters") {
    let viewModel: JournalViewModel = {
        let vm = JournalViewModel(
            journalRepository: MockJournalRepository(),
            moodRepository: MockMoodRepository()
        )
        vm.filterType = .gratitude
        vm.filterFavoritesOnly = true
        return vm
    }()

    return FilterView(viewModel: viewModel)
}
