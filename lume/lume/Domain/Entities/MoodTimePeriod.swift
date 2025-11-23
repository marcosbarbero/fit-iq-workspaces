//
//  MoodTimePeriod.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Domain model for mood analytics time periods
//

import Foundation

/// Time period options for mood analytics and charts
enum MoodTimePeriod: String, CaseIterable {
    case today = "Today"
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case sixMonths = "6M"
    case year = "1Y"

    /// Number of days in the period
    var days: Int {
        switch self {
        case .today:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .quarter:
            return 90
        case .sixMonths:
            return 180
        case .year:
            return 365
        }
    }

    /// Display name for UI
    var displayName: String {
        rawValue
    }

    /// Long-form description
    var description: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "Last 7 days"
        case .month:
            return "Last 30 days"
        case .quarter:
            return "Last 90 days"
        case .sixMonths:
            return "Last 6 months"
        case .year:
            return "Last year"
        }
    }

    /// Calculate start date from end date
    func startDate(from endDate: Date = Date()) -> Date? {
        Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: endDate
        )
    }
}
