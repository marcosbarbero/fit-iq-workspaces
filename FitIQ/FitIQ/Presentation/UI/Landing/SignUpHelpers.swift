//
//  SignUpHelpers.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftUI

// MARK: - SSOButton Helper

struct SSOButton: View {
    let title: String
    let iconName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(title)
                    .fontWeight(.semibold)

                Spacer()  // Pushes content to the left
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundColor(color == .black ? .white : .black)  // Text color contrast
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Adding a subtle border for visual separation from the background
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: color == .black ? 0 : 1)  // No border on black Apple button
            )
        }
    }
}

// MARK: - CustomTextField Helper (Required)

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let iconName: String
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }

            // Separator Line
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))
        }
    }
}

// MARK: - CustomDateField Helper

struct CustomDateField: View {
    let placeholder: String
    @Binding var date: Date
    let iconName: String
    let dateRange: PartialRangeThrough<Date>

    // Format date for display
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // Check if date is effectively a placeholder (today or future)
    private var isPlaceholderState: Bool {
        Calendar.current.isDateInToday(date) || date > Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(isPlaceholderState ? placeholder : formattedDate)
                    .foregroundColor(isPlaceholderState ? .secondary : .primary)

                Spacer()
            }

            // Wheel-style Date Picker (always visible, better for DoB)
            DatePicker(
                "",
                selection: $date,
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .tint(.ascendBlue)

            // Separator Line
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))
        }
    }
}
