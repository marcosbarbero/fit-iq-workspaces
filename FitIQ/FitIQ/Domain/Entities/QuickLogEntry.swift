import Foundation

/// Value Object representing a frequently logged meal entry
/// Used to provide quick-add shortcuts for common meals, drinks, and supplements
public struct QuickLogEntry: Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let quantity: String?
    public let mealType: MealType
    public let frequency: Int // Number of times this combination was logged
    public let lastUsed: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        quantity: String? = nil,
        mealType: MealType,
        frequency: Int,
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.mealType = mealType
        self.frequency = frequency
        self.lastUsed = lastUsed
    }
    
    // Legacy initializer for backward compatibility with drink-specific code
    public init(
        id: UUID = UUID(),
        drinkName: String,
        volume: String,
        frequency: Int,
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.name = drinkName
        self.quantity = volume
        self.mealType = .drink
        self.frequency = frequency
        self.lastUsed = lastUsed
    }
    
    /// Legacy property for backward compatibility
    public var drinkName: String { name }
    
    /// Legacy property for backward compatibility
    public var volume: String { quantity ?? "" }
    
    /// Returns the display text for this entry
    /// For drinks/water: "Water, 250 ml"
    /// For meals/supplements: "Chicken Breast" or "Multivitamin"
    public var displayText: String {
        if let quantity = quantity, !quantity.isEmpty {
            return "\(name), \(quantity)"
        }
        return name
    }
}

/// Default quick log entries for new users
/// Only drinks and water have defaults (opinionated); meals and supplements are history-based only
public struct DefaultQuickLogEntries {
    public static let defaults: [QuickLogEntry] = [
        QuickLogEntry(name: "Water", quantity: "250 ml", mealType: .water, frequency: 0),
        QuickLogEntry(name: "Water", quantity: "350 ml", mealType: .water, frequency: 0),
        QuickLogEntry(name: "Water", quantity: "500 ml", mealType: .water, frequency: 0),
        QuickLogEntry(name: "Coffee", quantity: "250 ml", mealType: .drink, frequency: 0),
        QuickLogEntry(name: "Coffee", quantity: "350 ml", mealType: .drink, frequency: 0)
    ]
}
