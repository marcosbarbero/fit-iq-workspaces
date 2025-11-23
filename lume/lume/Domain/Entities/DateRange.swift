//
//  DateRange.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//  Shared domain entity for date ranges
//

import Foundation

/// Represents a date range with start and end dates
/// Used across domain entities for filtering and context building
struct DateRange: Codable, Equatable, Hashable {
    let startDate: Date
    let endDate: Date

    /// Initialize a date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Number of days in the range
    var dayCount: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    /// Check if a date falls within this range
    /// - Parameter date: The date to check
    /// - Returns: True if the date is within the range (inclusive)
    func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }

    /// Create a date range for the last N days from today
    /// - Parameter days: Number of days to go back
    /// - Returns: DateRange representing the last N days
    static func lastDays(_ days: Int) -> DateRange {
        let today = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: today) ?? today
        return DateRange(startDate: startDate, endDate: today)
    }

    /// Create a date range for the current week
    /// - Returns: DateRange representing the current week (Sunday to Saturday)
    static var currentWeek: DateRange {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1

        let startDate = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) ?? today
        let endDate = calendar.date(byAdding: .day, value: 6 - daysFromSunday, to: today) ?? today

        return DateRange(startDate: startDate, endDate: endDate)
    }

    /// Create a date range for the current month
    /// - Returns: DateRange representing the current month
    static var currentMonth: DateRange {
        let calendar = Calendar.current
        let today = Date()

        let components = calendar.dateComponents([.year, .month], from: today)
        let startDate = calendar.date(from: components) ?? today

        let endComponents = DateComponents(year: components.year, month: components.month, day: 31)
        let endDate = calendar.date(from: endComponents) ?? today

        return DateRange(startDate: startDate, endDate: endDate)
    }
}
