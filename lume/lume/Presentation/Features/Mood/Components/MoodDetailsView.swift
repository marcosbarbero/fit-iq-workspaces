//
//  MoodDetailsView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-15.
//

import SwiftUI

/// Mood details view - allows user to add notes and set date for a mood entry
struct MoodDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: MoodViewModel
    let selectedMood: MoodLabel
    var existingEntry: MoodEntry?
    var onMoodSaved: () -> Void

    @State private var note = ""
    @State private var isSaving = false
    @State private var moodDate = Date()
    @State private var showingDatePicker = false
    @FocusState private var isNoteFocused: Bool

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: moodDate)
    }

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Mood visual and details at top
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedMood.color).opacity(0.8))
                                .frame(width: 80, height: 80)

                            Image(systemName: selectedMood.systemImage)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(LumeColors.textPrimary)
                        }

                        VStack(spacing: 8) {
                            Text(selectedMood.displayName)
                                .font(LumeTypography.titleMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(LumeColors.textPrimary)

                            Text(selectedMood.description)
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                    // Top metadata bar with date (closer to note input)
                    HStack(spacing: 12) {
                        // Calendar icon
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: selectedMood.color))

                        // Date/time button
                        Button {
                            withAnimation {
                                showingDatePicker = true
                            }
                        } label: {
                            Text(formattedDate)
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Unified note block with white background (matching journal entry style)
                    VStack(alignment: .leading, spacing: 0) {
                        // Optional label
                        Text("optional")
                            .font(LumeTypography.caption)
                            .foregroundColor(LumeColors.textSecondary.opacity(0.6))
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        // Divider at top to show text area boundary
                        Divider()
                            .background(LumeColors.textSecondary.opacity(0.15))
                            .padding(.horizontal, 20)

                        // Content with reflection prompt hint
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(selectedMood.reflectionPrompt)
                                        .font(LumeTypography.body)
                                        .foregroundColor(LumeColors.textSecondary.opacity(0.6))
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                            }

                            TextEditor(text: $note)
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .focused($isNoteFocused)
                                .frame(minHeight: 300)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isNoteFocused = false
            }

            // Date picker sheet
            if showingDatePicker {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showingDatePicker = false
                        }
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Button("Cancel") {
                                withAnimation {
                                    showingDatePicker = false
                                }
                            }
                            .foregroundColor(LumeColors.textSecondary)

                            Spacer()

                            Text("Select Date & Time")
                                .font(LumeTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(LumeColors.textPrimary)

                            Spacer()

                            Button("Done") {
                                withAnimation {
                                    showingDatePicker = false
                                }
                            }
                            .foregroundColor(Color(hex: selectedMood.color))
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(LumeColors.surface)

                        Divider()

                        DatePicker(
                            "Select date and time",
                            selection: $moodDate,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(Color(hex: selectedMood.color))
                        .padding(20)
                        .background(LumeColors.surface)
                    }
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
                    .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("How are you feeling?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(LumeColors.textSecondary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await saveMood()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(LumeColors.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(LumeColors.textPrimary)
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            // Load existing note and date if editing
            if let entry = existingEntry {
                note = entry.notes ?? ""
                moodDate = entry.date
            } else {
                moodDate = Date()
            }
        }
    }

    private func saveMood() async {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isNoteFocused = false
        isSaving = true

        if let entry = existingEntry {
            // Update existing entry
            await viewModel.updateMood(
                entry,
                moodLabel: selectedMood,
                notes: note.isEmpty ? nil : note,
                date: moodDate
            )
        } else {
            // Create new entry
            await viewModel.saveMood(
                moodLabel: selectedMood,
                notes: note.isEmpty ? nil : note,
                date: moodDate
            )
        }

        isSaving = false

        if viewModel.errorMessage == nil {
            // Call callback and dismiss after a brief delay to prevent flicker
            onMoodSaved()

            // Wait for state to settle before dismissing
            try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
            dismiss()
        }
    }
}
