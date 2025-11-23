//
//  EmptyMoodState.swift
//  lume
//
//  Created by AI Assistant on 2025-01-15.
//

import SwiftUI

/// Empty state view for mood tracking - shown when no moods are logged
struct EmptyMoodState: View {
    let onLogMood: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sun.max.fill")
                .font(.system(size: 60))
                .foregroundColor(LumeColors.accentPrimary.opacity(0.6))

            VStack(spacing: 12) {
                Text("Track Your Mood")
                    .font(LumeTypography.titleLarge)
                    .foregroundColor(LumeColors.textPrimary)

                Text("Check in with yourself and see\nhow you're feeling today")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: onLogMood) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))

                    Text("Log Your First Mood")
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(LumeColors.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(hex: "#F2C9A7"))
                .cornerRadius(24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}
