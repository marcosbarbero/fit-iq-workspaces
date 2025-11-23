//
//  CompactMoodCard.swift
//  lume
//
//  Created by AI Assistant on 2025-01-15.
//

import SwiftUI

/// Compact mood card for grid display
struct CompactMoodCard: View {
    let mood: MoodLabel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon with color background
                ZStack {
                    Circle()
                        .fill(Color(hex: mood.color).opacity(0.8))
                        .frame(width: 48, height: 48)

                    Image(systemName: mood.systemImage)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LumeColors.textPrimary)
                }

                // Text content
                VStack(spacing: 2) {
                    Text(mood.displayName)
                        .font(LumeTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)

                    Text(mood.description)
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: mood.color).opacity(0.08) : LumeColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color(hex: mood.color).opacity(0.9) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected
                    ? Color(hex: mood.color).opacity(0.15)
                    : LumeColors.textPrimary.opacity(0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
    }
}
