//
//  MoodLinkPickerView.swift
//  lume
//
//  Created by Lume Team on 2025-01-15.
//

import SwiftUI

/// View for selecting a mood to link with a journal entry
struct MoodLinkPickerView: View {
    @Environment(\.dismiss) var dismiss

    let currentMoodId: UUID?
    let viewModel: JournalViewModel
    let onSelect: (UUID) -> Void
    let onUnlink: () -> Void

    @State private var availableMoods: [MoodEntry] = []
    @State private var isLoading = true

    var body: some View {
        let _ = print("🎨 [MoodLinkPickerView] Rendering with \(availableMoods.count) moods")
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                List {
                    // Unlink section (if already linked)
                    if currentMoodId != nil {
                        Section {
                            Button(role: .destructive) {
                                onUnlink()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "link.badge.minus")
                                        .font(.system(size: 18))
                                    Text("Unlink from Mood")
                                        .font(LumeTypography.body)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowBackground(LumeColors.surface)
                    }

                    // Available moods section
                    Section {
                        let _ = print(
                            "🎨 [MoodLinkPickerView] Section - availableMoods.isEmpty = \(availableMoods.isEmpty), count = \(availableMoods.count)"
                        )
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 32)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if availableMoods.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 48))
                                    .foregroundColor(LumeColors.textSecondary.opacity(0.5))

                                Text("No Recent Mood Entries")
                                    .font(LumeTypography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(LumeColors.textPrimary)

                                Text("Track your mood first to link it with your journal entries")
                                    .font(LumeTypography.bodySmall)
                                    .foregroundColor(LumeColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(availableMoods) { mood in
                                MoodLinkRow(
                                    mood: mood,
                                    isSelected: mood.id == currentMoodId,
                                    onTap: {
                                        onSelect(mood.id)
                                        dismiss()
                                    }
                                )
                                .listRowBackground(LumeColors.surface)
                            }
                        }
                    } header: {
                        Text("Recent Moods (Last 7 Days)")
                            .font(LumeTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textSecondary)
                            .textCase(nil)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Link to Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                }
            }
        }
        .task {
            print("🎨 [MoodLinkPickerView] Loading moods in .task modifier")
            availableMoods = await viewModel.getRecentMoodsForLinking()
            print("🎨 [MoodLinkPickerView] Loaded \(availableMoods.count) moods")
            isLoading = false
        }
    }
}

// MARK: - Mood Link Row

struct MoodLinkRow: View {
    let mood: MoodEntry
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Mood icon
                if let primaryMood = mood.primaryMoodLabel {
                    ZStack {
                        Circle()
                            .fill(Color(hex: primaryMood.color).opacity(0.8))
                            .frame(width: 44, height: 44)

                        Image(systemName: primaryMood.systemImage)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(LumeColors.textPrimary)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(LumeColors.textSecondary.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: "face.smiling")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(LumeColors.textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Mood name
                    Text(mood.primaryMoodDisplayName)
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)

                    // Date and time
                    HStack(spacing: 8) {
                        Text(mood.date.formatted(date: .abbreviated, time: .shortened))
                            .font(LumeTypography.caption)
                            .foregroundColor(LumeColors.textSecondary)

                        if let notes = mood.notes, !notes.isEmpty {
                            Text("•")
                                .foregroundColor(LumeColors.textSecondary.opacity(0.5))

                            Text("Has note")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#059669"))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(LumeColors.textSecondary.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("With Moods") {
    let mockViewModel = JournalViewModel.preview
    return MoodLinkPickerView(
        currentMoodId: UUID(),
        viewModel: mockViewModel,
        onSelect: { _ in },
        onUnlink: {}
    )
}

#Preview("Empty State") {
    let mockViewModel = JournalViewModel.preview
    return MoodLinkPickerView(
        currentMoodId: nil,
        viewModel: mockViewModel,
        onSelect: { _ in },
        onUnlink: {}
    )
}
