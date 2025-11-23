//
//  MoodEntryView.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Redesigned for Mindfulness-Inspired UX (v4.0)
//

import Foundation
import SwiftUI

// MARK: - Mood Options (7 levels inspired by Apple Mindfulness)

enum MindfulMood: Int, CaseIterable, Identifiable {
    case veryUnpleasant = 1
    case unpleasant = 2
    case slightlyUnpleasant = 3
    case neutral = 4
    case slightlyPleasant = 5
    case pleasant = 6
    case veryPleasant = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .veryUnpleasant: return "Very Unpleasant"
        case .unpleasant: return "Unpleasant"
        case .slightlyUnpleasant: return "Slightly Unpleasant"
        case .neutral: return "Neutral"
        case .slightlyPleasant: return "Slightly Pleasant"
        case .pleasant: return "Pleasant"
        case .veryPleasant: return "Very Pleasant"
        }
    }

    var score: Int {
        switch self {
        case .veryUnpleasant: return 2
        case .unpleasant: return 3
        case .slightlyUnpleasant: return 4
        case .neutral: return 5
        case .slightlyPleasant: return 7
        case .pleasant: return 8
        case .veryPleasant: return 10
        }
    }

    var iconName: String {
        switch self {
        case .veryUnpleasant: return "cloud.heavyrain.fill"
        case .unpleasant: return "cloud.drizzle.fill"
        case .slightlyUnpleasant: return "wind"
        case .neutral: return "minus.circle.fill"
        case .slightlyPleasant: return "sun.haze.fill"
        case .pleasant: return "sun.max.fill"
        case .veryPleasant: return "sun.max.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .veryUnpleasant, .unpleasant, .slightlyUnpleasant, .neutral, .slightlyPleasant,
            .pleasant:
            return .white
        case .veryPleasant:
            return Color(hex: "#FFCC33")  // Vibrant yellow-orange
        }
    }

    var glowColor: Color {
        switch self {
        case .veryUnpleasant, .unpleasant, .slightlyUnpleasant, .neutral, .slightlyPleasant,
            .pleasant:
            return .white
        case .veryPleasant:
            return Color(hex: "#FF9900")  // Deep orange
        }
    }

    var backgroundColor: Color {
        switch self {
        // Dark, deep indigo-blue (stormy, heavy emotions)
        case .veryUnpleasant: return Color(hex: "#404059")

        // Muted purple-gray (melancholy, gloomy)
        case .unpleasant: return Color(hex: "#59546B")

        // Cool gray-blue (unsettled, transitional)
        case .slightlyUnpleasant: return Color(hex: "#737885")

        // Balanced gray (neither warm nor cool)
        case .neutral: return Color(hex: "#808085")

        // Soft teal-gray (gentle calm)
        case .slightlyPleasant: return Color(hex: "#7A8C94")

        // Warm blue-green (peaceful, serene)
        case .pleasant: return Color(hex: "#7394A6")

        // Deep purple-blue (rich, regal backdrop for yellow-orange)
        case .veryPleasant: return Color(hex: "#474073")
        }
    }

    var emotions: [String] {
        switch self {
        case .veryUnpleasant: return ["overwhelmed", "sad"]
        case .unpleasant: return ["frustrated", "stressed"]
        case .slightlyUnpleasant: return ["tired", "anxious"]
        case .neutral: return ["calm"]
        case .slightlyPleasant: return ["content", "relaxed"]
        case .pleasant: return ["happy", "peaceful"]
        case .veryPleasant: return ["excited", "motivated"]
        }
    }
}

// MARK: - Main View

struct MoodEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State var viewModel: MoodEntryViewModel

    @State private var selectedMood: MindfulMood = .neutral
    @State private var showingDetails = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background color
                selectedMood.backgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: selectedMood)

                VStack(spacing: 0) {
                    // Main mood selector
                    MoodSelectorView(
                        selectedMood: $selectedMood,
                        onMoodChange: { mood in
                            // Update viewmodel when mood changes
                            viewModel.setMoodScore(mood.score)
                        }
                    )
                    .frame(maxHeight: .infinity)

                    // Details section (collapsible)
                    if showingDetails {
                        DetailsSection(viewModel: viewModel)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingDetails.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showingDetails ? "Hide Details" : "Add Details")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.save()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Done")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Mood Selector (Swipeable)

struct MoodSelectorView: View {
    @Binding var selectedMood: MindfulMood
    let onMoodChange: (MindfulMood) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isPulsing = true

    var body: some View {
        VStack(spacing: 50) {
            // Question
            Text("How are you feeling?")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 60)

            // Animated icon (Mindfulness-inspired breathing animation)
            MindfulnessIconView(
                mood: selectedMood,
                isPulsing: isPulsing
            )
            .frame(height: 220)
            .onChange(of: selectedMood) { _, _ in
                // Restart pulsing animation on mood change
                isPulsing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isPulsing = true
                }
            }

            // Mood label
            Text(selectedMood.label)
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.3), value: selectedMood)

            // Swipe indicators
            HStack(spacing: 12) {
                ForEach(MindfulMood.allCases) { mood in
                    Circle()
                        .fill(selectedMood == mood ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: selectedMood)
                }
            }
            .padding(.top, 20)

            // Swipe hint
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .opacity(selectedMood != .veryUnpleasant ? 0.6 : 0.2)

                Text("Swipe to change")
                    .font(.subheadline)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(selectedMood != .veryPleasant ? 0.6 : 0.2)
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.top, 10)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50

                    if value.translation.width > threshold {
                        // Swipe right - previous mood
                        if let currentIndex = MindfulMood.allCases.firstIndex(of: selectedMood),
                            currentIndex > 0
                        {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedMood = MindfulMood.allCases[currentIndex - 1]
                                onMoodChange(selectedMood)
                            }
                        }
                    } else if value.translation.width < -threshold {
                        // Swipe left - next mood
                        if let currentIndex = MindfulMood.allCases.firstIndex(of: selectedMood),
                            currentIndex < MindfulMood.allCases.count - 1
                        {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedMood = MindfulMood.allCases[currentIndex + 1]
                                onMoodChange(selectedMood)
                            }
                        }
                    }

                    dragOffset = 0
                }
        )
    }
}

// MARK: - Details Section

struct DetailsSection: View {
    @State var viewModel: MoodEntryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Handle for dragging
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.5))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // Contributing Factors
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's contributing?")
                            .font(.headline)
                            .foregroundColor(.white)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                            ],
                            spacing: 12
                        ) {
                            ForEach(MoodFactor.allCases) { factor in
                                FactorChip(
                                    factor: factor,
                                    isSelected: viewModel.selectedFactors.contains(factor)
                                ) {
                                    viewModel.toggleFactor(factor)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundColor(.white)

                        ZStack(alignment: .topLeading) {
                            if viewModel.notes.isEmpty {
                                Text("Any additional thoughts?")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }

                            TextEditor(text: $viewModel.notes)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: 500)
        .background(
            Color.black.opacity(0.2)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

// MARK: - Factor Chip

struct FactorChip: View {
    let factor: MoodFactor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: factor.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                Text(factor.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Mindfulness-Inspired Animated Icon

struct MindfulnessIconView: View {
    let mood: MindfulMood
    let isPulsing: Bool

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Outer pulsing rings
            ForEach(0..<3, id: \.self) { index in
                let baseOpacity = 0.5 - Double(index) * 0.15
                let ringSize = 160 + CGFloat(index * 30)
                let displayOpacity = 0.7 - Double(index) * 0.2

                return Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                mood.glowColor.opacity(baseOpacity),
                                mood.glowColor.opacity(0.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .opacity(isAnimating ? 0.0 : displayOpacity)
                    .animation(
                        .easeOut(duration: 1.2 + Double(index) * 0.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }

            // Inner glow circle (pulsing)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mood.glowColor.opacity(0.5),
                            mood.glowColor.opacity(0.2),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(isAnimating ? 1.15 : 0.95)
                .opacity(isAnimating ? 0.3 : 0.8)
                .animation(
                    .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Core icon with pulsing effect
            ZStack {
                // Soft shadow/depth
                Image(systemName: mood.iconName)
                    .font(.system(size: 70, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                mood.iconColor.opacity(0.3),
                                mood.iconColor.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 8)
                    .offset(y: 4)

                // Main icon
                Image(systemName: mood.iconName)
                    .font(.system(size: 70, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                mood.iconColor,
                                mood.iconColor.opacity(0.9),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: mood.glowColor.opacity(0.6), radius: 15, x: 0, y: 0)
            }
            .scaleEffect(isAnimating ? 1.12 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )

            // Energetic particles (for very pleasant mood)
            if mood == .veryPleasant {
                ForEach(0..<12, id: \.self) { index in
                    let angle = Double(index) * .pi / 6
                    let distance = isAnimating ? 110.0 : 85.0

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 6, height: 6)
                        .offset(
                            x: cos(angle) * distance,
                            y: sin(angle) * distance
                        )
                        .opacity(isAnimating ? 0.0 : 1.0)
                        .scaleEffect(isAnimating ? 0.5 : 1.0)
                        .animation(
                            .easeOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                            value: isAnimating
                        )
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onChange(of: isPulsing) { _, newValue in
            if newValue {
                // Restart animations on mood change
                isAnimating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isAnimating = true
                }
            }
        }
    }
}
