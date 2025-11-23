//
//  StatCard.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Extracted from SummaryView for reusability
//

import SwiftUI

/// Standard grid card for displaying a single stat value
struct StatCard: View {
    let currentValue: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(currentValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
