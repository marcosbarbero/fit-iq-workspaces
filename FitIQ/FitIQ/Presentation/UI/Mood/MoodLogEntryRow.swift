//
//  MoodLogEntryRow.swift
//  FitIQ
//
//  Created by Marcos Barbero on 17/10/2025.
//

import Foundation
import SwiftUI

// MARK: - Helper for Mood Display

private struct MoodMoodMapper {
    static func description(for score: Int) -> (emoji: String, text: String) {
        switch score {
        case 1...2: return ("😢", "Awful")
        case 3: return ("😔", "Down")
        case 4: return ("🙁", "Bad")
        case 5...6: return ("😐", "Okay")
        case 7: return ("🙂", "Good")
        case 8: return ("😊", "Great")
        case 9...10: return ("🤩", "Amazing")
        default: return ("😐", "Okay")
        }
    }
}

private var primaryDateTimeFormatter: Date.FormatStyle {
    .dateTime.month(.abbreviated).day().hour(.twoDigits(amPM: .abbreviated)).minute()
}

struct MoodLogEntryRow: View {
    let record: MoodRecord
    let color: Color

    @State private var showingNotes: Bool = false

    var body: some View {
        Button {
            // Allow tap interaction if notes exist OR just for visual feedback
            showingNotes = true  // We'll assume the tap always leads to a detail view, even if notes are nil, to maintain a consistent UX affordance.
        } label: {
            HStack(spacing: 0) {

                // 1. LEFT COLUMN: Themed Bar + Mood

                // Themed Vertical Bar
                Capsule()
                    .fill(color)  // Serenity Lavender
                    .frame(width: 4)
                    .padding(.vertical, 0)  // No extra padding needed here

                VStack(alignment: .leading, spacing: 4) {
                    // --- TOP LINE: Mood Description (Primary Focus) ---
                    Text(
                        "\(MoodMoodMapper.description(for: record.score).emoji) \(MoodMoodMapper.description(for: record.score).text)"
                    )
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)

                    // --- SECONDARY LINE: Notes Preview (Condensed) ---
                    if record.notes?.isEmpty == false {
                        Text(record.notes ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                }
                .padding(.vertical, 18)  // 💡 FIX: Increased vertical padding (Back to TALLER row)
                .padding(.leading, 10)

                Spacer()

                // 2. RIGHT COLUMN: Date/Time + Disclosure

                VStack(alignment: .trailing, spacing: 4) {

                    // 💡 FIX: Date/Time Moved to the far right, top-aligned
                    Text(record.date.formatted(primaryDateTimeFormatter))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    // Notes Icon
                    if record.notes?.isEmpty == false {
                        Image(systemName: "text.rectangle.fill")  // Use fill for better visibility
                            .font(.subheadline)
                            .foregroundColor(color)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 18)  // Match vertical padding
                .padding(.trailing, 10)

                // Disclosure Indicator (Fixed position)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 15)  // Consistent right alignment padding
            }
            // 💡 FIX: Restored TALLER row size
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingNotes) {
            NotesDetailSheet(record: record, color: color)
        }
    }
}

// Location: MoodLogEntryRow.swift (Helper Struct) - FINAL REVISION

struct NotesDetailSheet: View {
    let record: MoodRecord
    let color: Color
    @Environment(\.dismiss) var dismiss

    private var scoreInt: Int { record.score }
    private var moodDescription: (emoji: String, text: String) {
        MoodMoodMapper.description(for: scoreInt)
    }

    // Formatter for the Navigation Title
    private var navigationTitleDate: String {
        // e.g., "Oct 17, 4:24 PM"
        record.date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {

                    // Spacer added for padding under the navigation bar
                    Spacer().frame(height: 20)

                    // MARK: - 1. Mood Visual Recap
                    VStack(spacing: 15) {

                        // Circular Display Area (Remains the focus)
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray4), lineWidth: 10)
                                .frame(width: 200, height: 200)

                            // Center Content: Score and Emoji
                            VStack {
                                Text(moodDescription.emoji)
                                    .font(.system(size: 60))

                                Text("\(scoreInt) / 10")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundColor(color)

                                Text(moodDescription.text)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // MARK: - 2. Notes Content (Read-Only)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("User Notes")
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Read-Only Text Block
                        ScrollView {
                            Text(
                                record.notes ?? "No detailed notes were recorded for this check-in."
                            )
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .frame(height: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 25)

                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground))

            // 💡 FINAL FIX: Use Date/Time as the primary Navigation Title
            .navigationTitle(navigationTitleDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Only keep the dismiss button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                // REMOVED: The date/time ToolbarItem
            }
        }
    }
}
