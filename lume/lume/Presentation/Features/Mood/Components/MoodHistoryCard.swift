//
//  MoodHistoryCard.swift
//  lume
//
//  Created by AI Assistant on 2025-01-15.
//

import SwiftUI

/// Mood history card - displays a single mood entry in the history list
struct MoodHistoryCard: View {
    let entry: MoodEntry
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Mood icon with improved contrast
            if let mood = entry.primaryMoodLabel {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)

                    Circle()
                        .fill(Color(hex: mood.color).opacity(0.3))
                        .frame(width: 40, height: 40)

                    Image(systemName: mood.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: mood.color).darkened(amount: 0.4))
                }
            }

            // Content - Compact layout
            VStack(alignment: .leading, spacing: 6) {
                // First row: Mood name and description
                HStack(spacing: 8) {
                    if let mood = entry.primaryMoodLabel {
                        Text(mood.displayName)
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("•")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        Text(mood.description)
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }

                // Second row: Time
                Text(entry.date, style: .time)
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)

                // Note indicator or expanded note
                if entry.hasNote && isExpanded {
                    Text(entry.notes ?? "")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textSecondary)
                        .padding(.top, 4)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                } else if entry.hasNote {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundColor(LumeColors.textSecondary.opacity(0.7))

                        Text("Tap to view note")
                            .font(.system(size: 11))
                            .foregroundColor(LumeColors.textSecondary.opacity(0.7))
                            .italic()
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Valence bar chart - counterbalances icon on the right
            ValenceBarChart(
                valence: entry.valence,
                color: entry.primaryMoodColor,
                animated: false
            )
            .frame(width: 60, height: 20)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LumeColors.surface)
        .cornerRadius(12)
        .shadow(color: LumeColors.textPrimary.opacity(0.04), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.hasNote {
                onTap()
            }
        }
    }
}
