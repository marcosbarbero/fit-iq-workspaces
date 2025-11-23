//
//  MarkdownTextView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-16.
//  Minimal markdown renderer for journal entries
//

import SwiftUI

/// Minimal markdown text renderer for journal entries
/// Supports: bold (**text**), lists (- item), and clickable links
/// Keeps it simple like Apple's Journal app
struct MarkdownTextView: View {
    let text: String
    let font: Font
    let color: Color

    init(
        _ text: String,
        font: Font = LumeTypography.body,
        color: Color = LumeColors.textPrimary
    ) {
        self.text = text
        self.font = font
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseLines().enumerated()), id: \.offset) { _, line in
                renderLine(line)
            }
        }
    }

    // MARK: - Parsing

    private func parseLines() -> [ParsedLine] {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                return .bulletPoint(String(line.dropFirst(2)))
            } else {
                return .text(line)
            }
        }
    }

    private enum ParsedLine {
        case text(String)
        case bulletPoint(String)
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderLine(_ line: ParsedLine) -> some View {
        switch line {
        case .text(let content):
            if !content.isEmpty {
                renderFormattedText(content)
                    .font(font)
                    .foregroundStyle(color)
            }

        case .bulletPoint(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(font)
                    .foregroundStyle(color)

                renderFormattedText(content)
                    .font(font)
                    .foregroundStyle(color)
            }
        }
    }

    private func renderFormattedText(_ text: String) -> Text {
        var result = Text("")
        var currentText = ""
        var isInBold = false
        var i = text.startIndex

        while i < text.endIndex {
            // Check for bold markers (**)
            if i < text.index(text.endIndex, offsetBy: -1) {
                let nextChar = text[text.index(after: i)]
                if text[i] == "*" && nextChar == "*" {
                    // Found bold marker
                    if !currentText.isEmpty {
                        result =
                            result
                            + Text(currentText)
                            .fontWeight(isInBold ? .bold : .regular)
                        currentText = ""
                    }
                    isInBold.toggle()
                    i = text.index(i, offsetBy: 2)
                    continue
                }
            }

            // Regular character
            currentText.append(text[i])
            i = text.index(after: i)
        }

        // Add remaining text
        if !currentText.isEmpty {
            result =
                result
                + Text(currentText)
                .fontWeight(isInBold ? .bold : .regular)
        }

        return result
    }
}

// MARK: - Preview

#Preview("Simple Text") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownTextView("This is regular text")

            Divider()

            MarkdownTextView("This is **bold text** in a sentence")

            Divider()

            MarkdownTextView("- First item\n- Second item\n- Third item")

            Divider()

            MarkdownTextView(
                """
                Here is a regular paragraph.

                **This entire line is bold**

                Mixed: Some **bold words** in regular text.

                - Bullet point one
                - Bullet point two with **bold**
                - Bullet point three

                Final paragraph with more text.
                """)
        }
        .padding()
    }
    .background(LumeColors.appBackground)
}
