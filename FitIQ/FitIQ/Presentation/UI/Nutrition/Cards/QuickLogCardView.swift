import SwiftUI

struct QuickLogCardView: View {
    let entries: [QuickLogEntry]
    let onTap: (QuickLogEntry) -> Void
    
    private let primaryAccent = Color.orange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(primaryAccent)
                Text("Quick Add")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(entries) { entry in
                        QuickLogCardButton(entry: entry) {
                            onTap(entry)
                        }
                    }
                }
            }
        }
    }
}

/// Individual quick log tile button
private struct QuickLogCardButton: View {
    let entry: QuickLogEntry
    let action: () -> Void
    
    private let primaryAccent = Color.orange
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon based on meal type and name
                Image(systemName: iconForEntry(entry))
                    .font(.title2)
                    .foregroundColor(primaryAccent)
                
                VStack(spacing: 2) {
                    Text(entry.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let quantity = entry.quantity {
                        Text(quantity)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(primaryAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    /// Returns an appropriate SF Symbol icon based on meal type and name
    private func iconForEntry(_ entry: QuickLogEntry) -> String {
        // First check meal type
        switch entry.mealType {
        case .water:
            return "drop.fill"
        case .drink:
            return iconForDrink(entry.name)
        case .breakfast:
            return "sun.and.horizon.fill"
        case .lunch:
            return "sun.max.fill"
        case .dinner:
            return "moon.stars.fill"
        case .snack:
            return "leaf.fill"
        case .supplements:
            return "pills.fill"
        case .other:
            return "fork.knife"
        }
    }
    
    /// Returns an appropriate SF Symbol icon based on drink name
    private func iconForDrink(_ drinkName: String) -> String {
        let lowercased = drinkName.lowercased()
        
        if lowercased.contains("water") {
            return "drop.fill"
        } else if lowercased.contains("coffee") || lowercased.contains("espresso") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("tea") {
            return "leaf.fill"
        } else if lowercased.contains("juice") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("soda") || lowercased.contains("pop") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("milk") {
            return "drop.fill"
        } else if lowercased.contains("smoothie") {
            return "cup.and.saucer.fill"
        } else {
            return "cup.and.saucer.fill"
        }
    }
}

#Preview {
    QuickLogCardView(
        entries: [
            QuickLogEntry(name: "Water", quantity: "350 ml", mealType: .water, frequency: 10),
            QuickLogEntry(name: "Coffee", quantity: "250 ml", mealType: .drink, frequency: 5),
            QuickLogEntry(name: "Green Tea", quantity: "500 ml", mealType: .drink, frequency: 3),
            QuickLogEntry(name: "Chicken Breast", quantity: nil, mealType: .lunch, frequency: 2)
        ],
        onTap: { entry in
            print("Tapped: \(entry.displayText)")
        }
    )
    .padding()
}
