//
//  JournalEntryCard.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import SwiftUI

/// Card component for displaying journal entries in lists
/// Shows preview, tags, metadata with warm, calm design
struct JournalEntryCard: View {
    let entry: JournalEntry
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingSyncInfo = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Entry type icon with color
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(Color(hex: entry.entryType.colorHex).opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: entry.entryType.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: entry.entryType.colorHex))
                }

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Header: Title or preview + favorite
                    HStack(alignment: .top, spacing: 8) {
                        MarkdownTextView(
                            truncateForPreview(entry.displayTitle, maxLines: 2),
                            font: LumeTypography.body,
                            color: LumeColors.textPrimary
                        )

                        Spacer(minLength: 4)

                        if entry.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FFD700"))
                        }
                    }

                    // Content preview (if has title)
                    if entry.hasTitle {
                        MarkdownTextView(
                            truncateForPreview(entry.preview, maxLines: 2),
                            font: LumeTypography.bodySmall,
                            color: LumeColors.textSecondary
                        )
                    }

                    // Metadata row
                    HStack(spacing: 12) {
                        // Date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(LumeColors.textSecondary.opacity(0.7))

                            Text(entry.relativeDateString)
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        // Word count
                        HStack(spacing: 4) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 11))
                                .foregroundColor(LumeColors.textSecondary.opacity(0.7))

                            Text("\(entry.wordCount) words")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        // Mood link indicator
                        if entry.isLinkedToMood {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 11))
                                    .foregroundColor(LumeColors.textSecondary.opacity(0.7))

                                Text("Mood")
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)
                            }
                        }

                        // Sync status indicator
                        syncStatusIndicator
                    }

                    // Tags (if any)
                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.tags.prefix(5), id: \.self) { tag in
                                    TagBadge(tag: tag)
                                }

                                if entry.tags.count > 5 {
                                    Text("+\(entry.tags.count - 5)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(LumeColors.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(LumeColors.surface)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(14)
            .background(LumeColors.surface)
            .cornerRadius(16)
            .shadow(color: LumeColors.textPrimary.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(CardButtonStyle())
        .sheet(isPresented: $showingSyncInfo) {
            SyncExplanationSheet()
        }
    }

    // MARK: - Sync Status Indicator

    // MARK: - Helper Methods

    private func truncateForPreview(_ text: String, maxLines: Int) -> String {
        let lines = text.components(separatedBy: .newlines)
        let limitedLines = Array(lines.prefix(maxLines))
        let result = limitedLines.joined(separator: "\n")

        // If we truncated, add ellipsis
        if lines.count > maxLines {
            return result + "..."
        }

        return result
    }

    @ViewBuilder
    private var syncStatusIndicator: some View {
        // Note: Sync status is now managed by Outbox pattern
        // This view component is deprecated but kept for future sync UI enhancement
        EmptyView()
    }
}

// MARK: - Supporting Components

/// Tag badge component
struct TagBadge: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(LumeColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LumeColors.textSecondary.opacity(0.15)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LumeColors.textSecondary.opacity(0.4), lineWidth: 1)
            )
    }
}

/// Custom button style for cards
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Single Entry") {
    let entry = JournalEntry(
        id: UUID(),
        userId: UUID(),
        date: Date(),
        title: "A Beautiful Morning",
        content:
            "Today started with a wonderful sunrise. I took a moment to appreciate the small things in life and felt grateful for this peaceful moment.",
        tags: ["gratitude", "morning", "peace"],
        entryType: .gratitude,
        isFavorite: true,
        linkedMoodId: UUID(),
        createdAt: Date(),
        updatedAt: Date()
    )

    return ScrollView {
        VStack(spacing: 16) {
            JournalEntryCard(
                entry: entry,
                onTap: { print("Tapped") },
                onEdit: { print("Edit") },
                onDelete: { print("Delete") }
            )
            .padding(.horizontal)
        }
    }
    .background(LumeColors.appBackground)
}

#Preview("Multiple Entries") {
    let entries = [
        JournalEntry(
            id: UUID(),
            userId: UUID(),
            date: Date(),
            title: "Morning Reflections",
            content:
                "Started the day with meditation and coffee. Feeling centered and ready for whatever comes my way.",
            tags: ["morning", "meditation"],
            entryType: .reflection,
            isFavorite: true,
            linkedMoodId: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        JournalEntry(
            id: UUID(),
            userId: UUID(),
            date: Date().addingTimeInterval(-86400),
            title: nil,
            content:
                "Just a quick note about how grateful I am for the support of my friends. They really showed up for me today when I needed them most.",
            tags: ["gratitude", "friendship"],
            entryType: .gratitude,
            isFavorite: false,
            linkedMoodId: UUID(),
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-86400)
        ),
        JournalEntry(
            id: UUID(),
            userId: UUID(),
            date: Date().addingTimeInterval(-172800),
            title: "Progress on Goals",
            content:
                "Reviewing my weekly goals. Accomplished 4 out of 5 tasks. Need to work on consistency with morning routine.",
            tags: ["goals", "progress", "routine"],
            entryType: .goalReview,
            isFavorite: false,
            linkedMoodId: nil,
            createdAt: Date().addingTimeInterval(-172800),
            updatedAt: Date().addingTimeInterval(-172800)
        ),
    ]

    return ScrollView {
        VStack(spacing: 12) {
            ForEach(entries) { entry in
                JournalEntryCard(
                    entry: entry,
                    onTap: { print("Tapped: \(entry.id)") },
                    onEdit: { print("Edit: \(entry.id)") },
                    onDelete: { print("Delete: \(entry.id)") }
                )
            }
        }
        .padding(.horizontal)
    }
    .background(LumeColors.appBackground)
}

#Preview("No Title Entry") {
    let entry = JournalEntry(
        id: UUID(),
        userId: UUID(),
        date: Date(),
        title: nil,
        content:
            "Sometimes I just need to write without a title. These stream-of-consciousness entries help me process my thoughts.",
        tags: ["freeform"],
        entryType: .freeform,
        isFavorite: false,
        linkedMoodId: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    return ScrollView {
        VStack(spacing: 16) {
            JournalEntryCard(
                entry: entry,
                onTap: { print("Tapped") },
                onEdit: { print("Edit") },
                onDelete: { print("Delete") }
            )
            .padding(.horizontal)
        }
    }
    .background(LumeColors.appBackground)
}
