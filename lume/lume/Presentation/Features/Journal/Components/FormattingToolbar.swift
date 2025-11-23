//
//  FormattingToolbar.swift
//  lume
//
//  Created by AI Assistant on 2025-01-16.
//  Minimal formatting toolbar for journal entries
//

import SwiftUI

/// Minimal formatting toolbar that appears above the keyboard
/// Buttons actually apply markdown formatting to the text
struct FormattingToolbar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Bold button
            Button {
                applyBold()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "bold")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LumeColors.textPrimary)
                    Text("Bold")
                        .font(.system(size: 9))
                        .foregroundStyle(LumeColors.textSecondary)
                }
                .frame(minWidth: 50)
            }

            // List button
            Button {
                applyList()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(LumeColors.textPrimary)
                    Text("List")
                        .font(.system(size: 9))
                        .foregroundStyle(LumeColors.textSecondary)
                }
                .frame(minWidth: 50)
            }

            Spacer()

            // Dismiss keyboard button
            Button {
                isFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18))
                    .foregroundStyle(LumeColors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(LumeColors.surface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(LumeColors.textSecondary.opacity(0.2)),
            alignment: .top
        )
    }

    // MARK: - Formatting Actions

    private func applyBold() {
        // Insert bold text template
        if !text.isEmpty && !text.hasSuffix(" ") && !text.hasSuffix("\n") {
            text.append(" ")
        }
        text.append("**bold text**")

        // Provide haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func applyList() {
        // Add a new line with bullet point
        if !text.isEmpty && !text.hasSuffix("\n") {
            text.append("\n")
        }
        text.append("- list item")

        // Provide haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Sample text"
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                FormattingToolbar(
                    text: $text,
                    isFocused: $isFocused
                )
            }
            .background(LumeColors.appBackground)
            .onAppear {
                isFocused = true
            }
        }
    }

    return PreviewWrapper()
}
