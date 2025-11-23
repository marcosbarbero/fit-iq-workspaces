//
//  SearchView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import SwiftUI

/// Search view for filtering journal entries by text query
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: JournalViewModel

    @State private var localSearchQuery: String = ""
    @FocusState private var searchFieldFocused: Bool

    var filteredEntries: [JournalEntry] {
        if localSearchQuery.isEmpty {
            return []
        }

        let query = localSearchQuery.lowercased()
        return viewModel.entries.filter { entry in
            entry.content.lowercased().contains(query)
                || (entry.title?.lowercased().contains(query) ?? false)
                || entry.tags.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(LumeColors.textSecondary)

                    TextField("Search entries...", text: $localSearchQuery)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)
                        .focused($searchFieldFocused)
                        .autocorrectionDisabled()

                    if !localSearchQuery.isEmpty {
                        Button {
                            localSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LumeColors.surface, lineWidth: 1)
                )
                .padding()

                Divider()

                // Results
                if localSearchQuery.isEmpty {
                    EmptySearchPrompt()
                } else if filteredEntries.isEmpty {
                    NoSearchResults(query: localSearchQuery)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredEntries) { entry in
                                SearchResultCard(
                                    entry: entry,
                                    searchQuery: localSearchQuery,
                                    onTap: {
                                        viewModel.searchQuery = localSearchQuery
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LumeColors.appBackground.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                }
            }
            .onAppear {
                searchFieldFocused = true
                localSearchQuery = viewModel.searchQuery
            }
            .onDisappear {
                if !localSearchQuery.isEmpty {
                    viewModel.searchQuery = localSearchQuery
                }
            }
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let entry: JournalEntry
    let searchQuery: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: entry.entryType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: entry.entryType.colorHex))

                    Text(entry.displayTitle)
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FFD700"))
                    }
                }

                // Content preview with search highlighting
                Text(highlightedText(entry.preview, query: searchQuery))
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textSecondary)
                    .lineLimit(3)

                // Metadata
                HStack(spacing: 12) {
                    Text(entry.relativeDateString)
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)

                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 10))

                            Text(entry.tags.prefix(2).map { "#\($0)" }.joined(separator: ", "))
                                .lineLimit(1)
                        }
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                    }
                }
            }
            .padding()
            .background(LumeColors.surface)
            .cornerRadius(12)
        }
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributedString = AttributedString(text)

        if let range = text.range(of: query, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            if let attributedRange = Range<AttributedString.Index>(nsRange, in: attributedString) {
                attributedString[attributedRange].foregroundColor = Color(hex: "#F2C9A7")
                attributedString[attributedRange].font = .system(size: 15, weight: .semibold)
            }
        }

        return attributedString
    }
}

// MARK: - Empty States

struct EmptySearchPrompt: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(LumeColors.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Search Your Journal")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                Text("Find entries by content, title, or tags")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

struct NoSearchResults: View {
    let query: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(LumeColors.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Results")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                Text("No entries found for \"\(query)\"")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Previews

#Preview("Empty Search") {
    let viewModel = JournalViewModel(
        journalRepository: MockJournalRepository(),
        moodRepository: MockMoodRepository()
    )

    SearchView(viewModel: viewModel)
}

#Preview("With Results") {
    let viewModel = JournalViewModel(
        journalRepository: MockJournalRepository(),
        moodRepository: MockMoodRepository()
    )

    SearchView(viewModel: viewModel)
}
