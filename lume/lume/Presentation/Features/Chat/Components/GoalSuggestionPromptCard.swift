//
//  GoalSuggestionPromptCard.swift
//  lume
//
//  Created by AI Assistant on 29/01/2025.
//

import SwiftUI

/// Inline card that prompts user to generate goal suggestions from the conversation
struct GoalSuggestionPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#F2C9A7"),
                                    Color(hex: "#D8C8EA"),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to set goals?")
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)

                    Text("Based on our conversation, I can suggest personalized goals for you")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Arrow
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#F2C9A7"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#F2C9A7").opacity(0.3),
                                Color(hex: "#D8C8EA").opacity(0.3),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LumeColors.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            GoalSuggestionPromptCard {
                print("Generate goals tapped")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 40)
    }
}
