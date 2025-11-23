//
//  JournalEntryDetailView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import SwiftUI

/// Detail view for displaying full journal entry content
/// Shows complete text, metadata, tags, and action buttons
struct JournalEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: JournalEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    // Entry type badge
                    HStack(spacing: 8) {
                        Image(systemName: entry.entryType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: entry.entryType.colorHex))

                        Text(entry.entryType.displayName)
                            .font(LumeTypography.bodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: entry.entryType.colorHex))

                        if entry.isFavorite {
                            Spacer()

                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#FFD700"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: entry.entryType.colorHex).opacity(0.15))
                    .cornerRadius(20)

                    // Title
                    if entry.hasTitle {
                        Text(entry.title!)
                            .font(LumeTypography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(LumeColors.textPrimary)
                    }

                    // Metadata row
                    HStack(spacing: 16) {
                        // Date
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(LumeColors.textSecondary)

                            Text(entry.formattedDateTime)
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        // Word count
                        HStack(spacing: 6) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 12))
                                .foregroundColor(LumeColors.textSecondary)

                            Text("\(entry.wordCount) words")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        // Reading time
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(LumeColors.textSecondary)

                            Text("\(entry.estimatedReadingTime) min read")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Content (with markdown rendering)
                MarkdownTextView(
                    entry.content,
                    font: LumeTypography.body,
                    color: LumeColors.textPrimary
                )
                .padding(.horizontal)

                // Tags section
                if !entry.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(LumeTypography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { tag in
                                TagBadge(tag: tag)
                            }
                        }
                    }
                    .padding()
                    .background(LumeColors.surface)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Mood link indicator
                if entry.isLinkedToMood {
                    HStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#F5DFA8"))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Linked to Mood Entry")
                                .font(LumeTypography.body)
                                .fontWeight(.medium)
                                .foregroundColor(LumeColors.textPrimary)

                            Text("This entry is connected to your mood tracking")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(hex: "#F5DFA8").opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Last updated info
                VStack(alignment: .leading, spacing: 8) {
                    if entry.createdAt != entry.updatedAt {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 11))
                                .foregroundColor(LumeColors.textSecondary.opacity(0.7))

                            Text("Last edited \(entry.timeSinceUpdate)")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary.opacity(0.8))
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                            .foregroundColor(LumeColors.textSecondary.opacity(0.7))

                        Text("Created on \(entry.createdAt, style: .date)")
                            .font(LumeTypography.caption)
                            .foregroundColor(LumeColors.textSecondary.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))

                            Text("Edit Entry")
                                .font(LumeTypography.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(LumeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: entry.entryType.colorHex).opacity(0.2))
                        .cornerRadius(12)
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16))

                            Text("Delete Entry")
                                .font(LumeTypography.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color(hex: "#F0B8A4"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#F0B8A4").opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical, 20)
        }
        .background(LumeColors.appBackground.ignoresSafeArea())
        .navigationTitle("Entry Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(LumeColors.textSecondary)
                }
            }
        }
        .confirmationDialog(
            "Delete Entry",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
    }
}

// MARK: - Previews

#Preview("With Title") {
    let entry = JournalEntry(
        id: UUID(),
        userId: UUID(),
        date: Date(),
        title: "A Beautiful Morning",
        content: """
            Today started with a wonderful sunrise that painted the sky in shades of pink and orange. \
            I took a moment to sit by the window with my coffee and just appreciate the beauty of this new day.

            These quiet moments in the morning have become so precious to me. They remind me to slow down \
            and be present, rather than rushing into the busyness of the day.

            I'm grateful for:
            - This peaceful start to my day
            - The warmth of the sun through the window
            - Having the time to just be

            Setting an intention for today: Stay present and find joy in the small moments.
            """,
        tags: ["gratitude", "morning", "mindfulness", "peace"],
        entryType: .gratitude,
        isFavorite: true,
        linkedMoodId: UUID(),
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date()
    )

    return NavigationStack {
        JournalEntryDetailView(
            entry: entry,
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )
    }
}

#Preview("Without Title") {
    let entry = JournalEntry(
        id: UUID(),
        userId: UUID(),
        date: Date(),
        title: nil,
        content: """
            Just a quick reflection on today. It wasn't perfect, but it was good. \
            Sometimes I need to remind myself that good enough is actually great.

            I accomplished the main things I set out to do, and that's worth celebrating. \
            Progress over perfection, always.
            """,
        tags: ["reflection", "progress"],
        entryType: .freeform,
        isFavorite: false,
        linkedMoodId: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    return NavigationStack {
        JournalEntryDetailView(
            entry: entry,
            onEdit: { print("Edit") },
            onDelete: { print("Delete") }
        )
    }
}
