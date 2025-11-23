//
//  LinearMoodSelectorView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-15.
//

import SwiftUI

/// Linear mood selector view - displays mood options in a 2-column grid
struct LinearMoodSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: MoodViewModel
    var onMoodSaved: () -> Void
    var existingEntry: MoodEntry? = nil

    @State private var selectedMood: MoodLabel?
    @State private var navigateToDetails = false

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Gentle header
                    VStack(spacing: 12) {
                        Text(existingEntry != nil ? "Update your mood" : "How are you feeling?")
                            .font(LumeTypography.titleLarge)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Take a moment to check in with yourself")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 32)

                    // Mood options in a 2-column grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ],
                        spacing: 12
                    ) {
                        ForEach(
                            MoodLabel.allCases.sorted(by: { $0.defaultValence > $1.defaultValence })
                        ) { mood in
                            CompactMoodCard(
                                mood: mood,
                                isSelected: selectedMood == mood
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedMood = mood
                                }

                                // Auto-navigate after selection with slight delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    viewModel.selectedMoodLabel = mood
                                    navigateToDetails = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $navigateToDetails) {
            if let mood = selectedMood {
                NavigationStack {
                    MoodDetailsView(
                        viewModel: viewModel,
                        selectedMood: mood,
                        existingEntry: existingEntry,
                        onMoodSaved: onMoodSaved
                    )
                }
            }
        }
        .onAppear {
            // Set existing mood if editing
            if let entry = existingEntry {
                selectedMood = entry.primaryMoodLabel
            } else {
                selectedMood = nil
            }
            navigateToDetails = false
        }
    }
}
