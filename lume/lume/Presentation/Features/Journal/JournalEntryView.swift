//
//  JournalEntryView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//  Redesigned: 2025-01-16
//

import SwiftUI

/// Redesigned journal entry view with clean, unified note-taking experience
/// Single block design inspired by iOS Notes app
struct JournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: JournalViewModel
    let existingEntry: JournalEntry?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var entryType: EntryType = .freeform
    @State private var isFavorite: Bool = false
    @State private var entryDate: Date = Date()
    @State private var showingDatePicker = false
    @State private var showingMoodLinkPicker = false

    @State private var linkedMoodId: UUID?
    @State private var isSaving = false
    @FocusState private var titleIsFocused: Bool
    @FocusState private var contentIsFocused: Bool

    private var isEditing: Bool {
        existingEntry != nil
    }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && content.count <= JournalEntry.maxContentLength
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: entryDate)
    }

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Top metadata bar (entry type, date/time, favorite)
                    HStack(spacing: 12) {
                        // Entry type selector
                        Menu {
                            ForEach(EntryType.allCases, id: \.self) { type in
                                Button {
                                    entryType = type
                                } label: {
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.displayName)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: entryType.icon)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: entryType.colorHex))
                        }

                        // Date/time button
                        Button {
                            showingDatePicker = true
                        } label: {
                            Text(formattedDate)
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        Spacer()

                        // Mood link button
                        Button {
                            showingMoodLinkPicker = true
                        } label: {
                            Image(
                                systemName: linkedMoodId != nil
                                    ? "link.circle.fill" : "link.circle"
                            )
                            .font(.system(size: 18))
                            .foregroundColor(
                                linkedMoodId != nil
                                    ? Color(hex: "#F2C9A7") : LumeColors.textSecondary
                            )
                        }

                        // Favorite button
                        Button {
                            isFavorite.toggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(
                                    isFavorite ? Color(hex: "#FFD700") : LumeColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Unified note block
                    VStack(alignment: .leading, spacing: 0) {
                        // Title with placeholder
                        ZStack(alignment: .leading) {
                            if title.isEmpty {
                                Text("Title (optional)")
                                    .font(LumeTypography.titleLarge)
                                    .foregroundColor(LumeColors.textSecondary.opacity(0.5))
                            }
                            TextField("", text: $title)
                                .font(LumeTypography.titleLarge)
                                .foregroundColor(LumeColors.textPrimary)
                                .focused($titleIsFocused)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        // Divider
                        Divider()
                            .background(LumeColors.textSecondary.opacity(0.15))
                            .padding(.horizontal, 20)

                        // Content with hashtag hint
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What's on your mind?")
                                        .font(LumeTypography.body)
                                        .foregroundColor(LumeColors.textSecondary.opacity(0.6))

                                    Text("Use #hashtags to organize your thoughts")
                                        .font(LumeTypography.bodySmall)
                                        .foregroundColor(LumeColors.textSecondary.opacity(0.4))
                                        .italic()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                            }

                            TextEditor(text: $content)
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .focused($contentIsFocused)
                                .frame(minHeight: 300)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .onChange(of: content) { newValue in
                                    extractHashtags(from: newValue)
                                }
                        }

                        // Tags display (if any)
                        if !tags.isEmpty {
                            Divider()
                                .background(LumeColors.textSecondary.opacity(0.15))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        TagChip(
                                            tag: tag,
                                            color: Color(hex: entryType.colorHex),
                                            onRemove: {
                                                tags.removeAll { $0 == tag }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                titleIsFocused = false
                contentIsFocused = false
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if contentIsFocused {
                FormattingToolbar(
                    text: $content,
                    isFocused: $contentIsFocused
                )
            }
        }
        .navigationTitle("What's on your mind?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(LumeColors.textPrimary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await saveEntry()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(LumeColors.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(
                                canSave ? LumeColors.textPrimary : LumeColors.textSecondary)
                    }
                }
                .disabled(!canSave || isSaving)
            }
        }
        .sheet(isPresented: $showingMoodLinkPicker) {
            MoodLinkPickerView(
                currentMoodId: linkedMoodId,
                viewModel: viewModel,
                onSelect: { moodId in
                    linkedMoodId = moodId
                    if let entry = existingEntry {
                        Task {
                            await viewModel.linkToMood(moodId, for: entry)
                        }
                    }
                },
                onUnlink: {
                    linkedMoodId = nil
                    if let entry = existingEntry {
                        Task {
                            await viewModel.unlinkFromMood(for: entry)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Select Date & Time",
                        selection: $entryDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.light)
                    .tint(Color(hex: entryType.colorHex))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LumeColors.surface)
                            .shadow(
                                color: LumeColors.textPrimary.opacity(0.05),
                                radius: 8,
                                x: 0,
                                y: 2
                            )
                    )
                    .padding(.horizontal, 20)

                    Spacer()

                    // Now button
                    Button {
                        entryDate = Date()
                        showingDatePicker = false
                    } label: {
                        Text("Now")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: entryType.colorHex))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .background(LumeColors.appBackground.ignoresSafeArea())
                .navigationTitle("When?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                        .foregroundColor(LumeColors.textPrimary)
                    }
                }
            }
        }
        .onAppear {
            loadExistingEntry()
            if !isEditing {
                titleIsFocused = true
            }
        }
    }

    func loadExistingEntry() {
        guard let entry = existingEntry else { return }
        title = entry.title ?? ""
        content = entry.content
        tags = entry.tags
        entryType = entry.entryType
        isFavorite = entry.isFavorite
        entryDate = entry.date
        linkedMoodId = entry.linkedMoodId
    }

    func saveEntry() async {
        isSaving = true

        do {
            if let existing = existingEntry {
                // Update existing entry
                try await viewModel.updateEntry(
                    existing,
                    title: title.isEmpty ? nil : title,
                    content: content,
                    tags: tags,
                    entryType: entryType,
                    isFavorite: isFavorite
                )
            } else {
                // Create new entry
                try await viewModel.createEntry(
                    title: title.isEmpty ? nil : title,
                    content: content,
                    tags: tags,
                    entryType: entryType,
                    isFavorite: isFavorite,
                    date: entryDate
                )
            }

            dismiss()
        } catch {
            // Error handling - could show alert
            print("Failed to save entry: \(error)")
        }

        isSaving = false
    }

    func extractHashtags(from text: String) {
        // Find all hashtags in the content
        let pattern = "#[a-zA-Z0-9_]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        var foundTags: [String] = []
        for match in matches {
            let hashtag = nsString.substring(with: match.range)
            let tag = String(hashtag.dropFirst()).lowercased()  // Remove # and lowercase
            if !tag.isEmpty && !foundTags.contains(tag) && foundTags.count < JournalEntry.maxTags {
                foundTags.append(tag)
            }
        }

        // Update tags if they've changed
        if foundTags != tags {
            tags = foundTags
        }
    }
}

// MARK: - Tag Components

struct TagChip: View {
    let tag: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("#\(tag)")
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(LumeColors.textPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LumeColors.textSecondary.opacity(0.12)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 1.5)
        )
    }
}

struct SuggestedTagChip: View {
    let tag: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                    .foregroundColor(LumeColors.textPrimary)

                Text("#\(tag)")
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LumeColors.textSecondary.opacity(0.08)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.6), lineWidth: 1)
            )
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.frames[index].minX,
                    y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(
                    CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
