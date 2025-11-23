//
//  CreateGoalView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//  Redesigned to match JournalEntryView pattern
//

import SwiftUI

/// View for creating a new goal with unified note-taking style
/// Matches JournalEntryView's clean, single-block design
struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GoalsViewModel

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedCategory = GoalCategory.general
    @State private var targetDate: Date?
    @State private var useTargetDate = false
    @State private var showingDatePicker = false
    @State private var isSaving = false
    @FocusState private var titleIsFocused: Bool
    @FocusState private var descriptionIsFocused: Bool

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && title.count <= 100
    }

    private var formattedDate: String? {
        guard let date = targetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Top metadata bar (category, target date)
                    HStack(spacing: 12) {
                        // Category selector
                        Menu {
                            ForEach(GoalCategory.allCases, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text(category.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: selectedCategory.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(selectedCategory.displayName)
                                    .font(LumeTypography.caption)
                            }
                            .foregroundColor(Color(hex: selectedCategory.colorHex))
                        }

                        Spacer()

                        // Target date button
                        Button {
                            if !useTargetDate && targetDate == nil {
                                targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
                            }
                            showingDatePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(
                                    systemName: useTargetDate
                                        ? "calendar.circle.fill" : "calendar.circle"
                                )
                                .font(.system(size: 18))
                                if let date = formattedDate, useTargetDate {
                                    Text(date)
                                        .font(LumeTypography.caption)
                                }
                            }
                            .foregroundColor(
                                useTargetDate
                                    ? Color(hex: "#F2C9A7")
                                    : LumeColors.textSecondary
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Unified goal block
                    VStack(alignment: .leading, spacing: 0) {
                        // Title with placeholder
                        ZStack(alignment: .leading) {
                            if title.isEmpty {
                                Text("Goal Title")
                                    .font(LumeTypography.titleLarge)
                                    .foregroundColor(LumeColors.textSecondary.opacity(0.5))
                            }
                            TextField("", text: $title)
                                .font(LumeTypography.titleLarge)
                                .foregroundColor(LumeColors.textPrimary)
                                .focused($titleIsFocused)
                                .onChange(of: title) { _, newValue in
                                    if newValue.count > 100 {
                                        title = String(newValue.prefix(100))
                                    }
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        // Divider
                        Divider()
                            .background(LumeColors.textSecondary.opacity(0.15))
                            .padding(.horizontal, 20)

                        // Description with hint
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What do you want to achieve?")
                                        .font(LumeTypography.body)
                                        .foregroundColor(LumeColors.textSecondary.opacity(0.6))

                                    Text("Describe your goal and how you'll measure success")
                                        .font(LumeTypography.bodySmall)
                                        .foregroundColor(LumeColors.textSecondary.opacity(0.4))
                                        .italic()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            }

                            TextEditor(text: $description)
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .focused($descriptionIsFocused)
                                .onChange(of: description) { _, newValue in
                                    if newValue.count > 500 {
                                        description = String(newValue.prefix(500))
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(16)
                    .shadow(
                        color: LumeColors.textPrimary.opacity(0.04),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
                    .padding(.horizontal, 20)

                    // Character counts
                    HStack(spacing: 16) {
                        if !title.isEmpty {
                            Text("Title: \(title.count)/100")
                                .font(LumeTypography.caption)
                                .foregroundColor(
                                    title.count > 100
                                        ? Color(hex: "#F0B8A4")
                                        : LumeColors.textSecondary
                                )
                        }

                        if !description.isEmpty {
                            Text("Description: \(description.count)/500")
                                .font(LumeTypography.caption)
                                .foregroundColor(
                                    description.count > 500
                                        ? Color(hex: "#F0B8A4")
                                        : LumeColors.textSecondary
                                )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Bottom padding for keyboard
                    Color.clear.frame(height: 100)
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping background
                titleIsFocused = false
                descriptionIsFocused = false
            }
        }
        .navigationTitle("What's your goal?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .foregroundColor(LumeColors.textPrimary)
                }
                .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    createGoal()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(LumeColors.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(
                                canSave
                                    ? LumeColors.textPrimary
                                    : LumeColors.textSecondary
                            )
                    }
                }
                .disabled(!canSave || isSaving)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Target Date",
                        selection: Binding(
                            get: {
                                targetDate ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
                            },
                            set: { targetDate = $0 }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.light)
                    .tint(Color(hex: selectedCategory.colorHex))
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

                    // No Target Date button
                    Button {
                        useTargetDate = false
                        targetDate = nil
                        showingDatePicker = false
                    } label: {
                        Text("No Target Date")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: selectedCategory.colorHex))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .background(LumeColors.appBackground.ignoresSafeArea())
                .navigationTitle("Target Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            useTargetDate = true
                            showingDatePicker = false
                        }
                        .foregroundColor(LumeColors.textPrimary)
                    }
                }
            }
            .presentationBackground(LumeColors.appBackground)
        }
        .onAppear {
            // Auto-focus title field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                titleIsFocused = true
            }
        }
    }

    private func createGoal() {
        guard canSave && !isSaving else { return }

        isSaving = true

        Task {
            await viewModel.createGoal(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory,
                targetDate: useTargetDate ? targetDate : nil
            )

            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    let deps = AppDependencies.preview
    return NavigationStack {
        CreateGoalView(viewModel: deps.makeGoalsViewModel())
    }
}
