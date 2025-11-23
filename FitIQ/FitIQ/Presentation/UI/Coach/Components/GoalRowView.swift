//
//  GoalRowView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

struct GoalRowView: View {
    let goal: TriageGoal
    
    private var sourceIcon: (name: String, color: Color) {
        switch goal.source {
        case .declarative:
            return ("hand.raised.fill", Color(.systemGray))
        case .aiTriage:
            return ("sparkles", .ascendBlue)
        case .professional:
            return ("person.text.rectangle.fill", .serenityLavender)
        }
    }
    
    var body: some View {
        HStack(alignment: .top) { // Use HStack for horizontal alignment of icon and text
            
            // 1. Source Indicator Icon
            Image(systemName: sourceIcon.name)
                .font(.callout)
                .foregroundStyle(sourceIcon.color)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 5) {
                
                // 2. Goal Title
                Text(goal.title)
                    .font(.headline)
                
                // 3. Mapped Focus Areas (Unchanged)
                HStack(spacing: 8) {
                    ForEach(Array(goal.mappedTypes), id: \.self) { type in
                        HStack(spacing: 4) {
                            Image(systemName: type.systemIcon)
                            Text(type.rawValue.capitalized)
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(type.accentColor.opacity(0.15))
                        .foregroundStyle(type.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
