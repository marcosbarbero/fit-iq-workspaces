//
//  FormattingHelpers.swift
//
//  Locale-aware formatting utilities for numbers, dates, and measurements
//  Ensures proper formatting based on user's locale settings
//

import Foundation

// MARK: - Number Formatting

/// Formats numbers according to the user's locale
struct NumberFormatHelper {
    
    /// Formats an integer with locale-appropriate grouping separators
    /// - Parameter number: The integer to format
    /// - Returns: Formatted string (e.g., "1,234" in US, "1.234" in Germany)
    static func formatInteger(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    /// Formats a decimal number with locale-appropriate formatting
    /// - Parameters:
    ///   - number: The decimal number to format
    ///   - fractionDigits: Number of decimal places (default: 1)
    /// - Returns: Formatted string (e.g., "70.5" in US, "70,5" in Germany)
    static func formatDecimal(_ number: Double, fractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: number)) ?? String(format: "%.\(fractionDigits)f", number)
    }
    
    /// Formats calories with locale-appropriate formatting
    /// - Parameter calories: Calorie value
    /// - Returns: Formatted calories (e.g., "2,340 kcal")
    static func formatCalories(_ calories: Int) -> String {
        let formattedNumber = formatInteger(calories)
        return "\(formattedNumber) \(L10n.Unit.kcal)"
    }
    
    /// Formats macronutrient grams
    /// - Parameter grams: Gram value
    /// - Returns: Formatted grams (e.g., "45 g")
    static func formatGrams(_ grams: Double) -> String {
        let formattedNumber = formatDecimal(grams, fractionDigits: 1)
        return "\(formattedNumber) \(L10n.Unit.g)"
    }
    
    /// Formats weight in kilograms
    /// - Parameter kg: Weight in kilograms
    /// - Returns: Formatted weight (e.g., "70.5 kg")
    static func formatWeight(_ kg: Double) -> String {
        let formattedNumber = formatDecimal(kg, fractionDigits: 1)
        return "\(formattedNumber) \(L10n.Unit.kg)"
    }
    
    /// Decimal formatter with grouping separators (e.g., "1,234")
    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale.current
        return f
    }()
    
    /// Decimal formatter without grouping (e.g., "1234")
    static let decimalNoGrouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ""
        f.locale = Locale.current
        return f
    }()
    
    /// Integer formatter for TextFields
    static let integerInput: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.allowsFloats = false
        f.locale = Locale.current
        return f
    }()
    
    /// Decimal formatter with 1 fraction digit (e.g., "70.5")
    static let decimalOneFraction: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        f.locale = Locale.current
        return f
    }()
    
    /// Create custom formatter (use sparingly)
    static func custom(
        style: NumberFormatter.Style = .decimal,
        fractionDigits: Int = 0,
        groupingSeparator: String? = nil
    ) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = style
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        if let separator = groupingSeparator {
            f.groupingSeparator = separator
        }
        f.locale = Locale.current
        return f
    }
}

// MARK: - Date Formatting

/// Formats dates according to the user's locale
struct DateFormatHelper {
    
    /// Formats date in long style (e.g., "January 15, 2025" in English, "15 de enero de 2025" in Spanish)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    static func formatLongDate(_ date: Date) -> String {

        return formatLongDateFormatter.string(from: date)
    }
    
    private static let formatLongDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Formats date in medium style (e.g., "Jan 15, 2025")
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    static func formatMediumDate(_ date: Date) -> String {
        return formatMediumDateFormatter.string(from: date)
    }
    
    private static let formatMediumDateFormatter : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Formats date in short style (e.g., "1/15/25" in US, "15/01/25" in Europe)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    static func formatShortDate(_ date: Date) -> String {
        return formatShortDateFormatter.string(from: date)
    }
    
    private static let formatShortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    } ()
    
    /// Formats time in locale-appropriate format (12h vs 24h)
    /// - Parameter date: The date/time to format
    /// - Returns: Formatted time string (e.g., "2:30 PM" in US, "14:30" in Europe)
    static func formatTime(_ date: Date) -> String {
        return formatTimeFormatter.string(from: date)
    }
    
    private static let formatTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Formats date and time together
    /// - Parameter date: The date/time to format
    /// - Returns: Formatted date and time string
    static func formatDateTime(_ date: Date) -> String {
        return formatDateTimeFormatter.string(from: date)
    }
    
    private static let formatDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Returns relative date string (Today, Yesterday, Tomorrow, or formatted date)
    /// - Parameter date: The date to format
    /// - Returns: Relative or formatted date string
    static func formatRelativeDate(_ date: Date) -> String {
        return formatRelativeDateFormatter.string(from: date)
    }
    
    private static let formatRelativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    static func formatGroupDate(_ date: Date) -> String {
        return formatGroupDateFormatter.string(from: date)
    }
    
    private static let formatGroupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.currentLanguageCode)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    static func formatMonthDayDate(_ date: Date) -> String {
        return formatMonthDayDateFormatter.string(from: date)
    }
    
    private static let formatMonthDayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.currentLanguageCode)
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static func formatDayAbbreviation(_ date: Date) -> String {
        return dayAbbreviationFormatter.string(from: date)
    }
    
    private static let dayAbbreviationFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.currentLanguageCode)
        formatter.dateFormat = "E" // Mon, Tue, Wed, etc.
        return formatter
    }()
    
    static func formatDay(_ date: Date) -> String {
        return dayFormatter.string(from: date)
    }
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.currentLanguageCode)
        formatter.dateFormat = "EEE" // Mon, Tue, Wed, etc.
        return formatter
    }()
    
    static func shortMonthDayShortWeekDay(_ date: Date) -> String {
        return shortMonthDayShortWeekDayFormatter.string(from: date)
    }
    
    private static let shortMonthDayShortWeekDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d (E)"
        return formatter
    }()
    
    static func weekDayMonthNumericDay(_ date: Date) -> String {
        return weekDayMonthNumericDayFormatter.string(from: date)
    }
    
    private static let weekDayMonthNumericDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocaleManager.shared.currentLanguageCode)
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

extension Date {
    func formattedHourMinute() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

// MARK: - Measurement Formatting

/// Formats measurements with automatic unit conversion based on locale
struct MeasurementFormatHelper {
    
    /// Formats weight measurement, converting to user's preferred unit system
    /// - Parameter kg: Weight in kilograms
    /// - Returns: Formatted weight (e.g., "154.3 lb" in US, "70.0 kg" in Europe)
    static func formatWeight(_ kg: Double) -> String {
        let measurement = Measurement(value: kg, unit: UnitMass.kilograms)
        return formatMeasurement(measurement)
    }
    
    /// Formats height measurement, converting to user's preferred unit system
    /// - Parameter cm: Height in centimeters
    /// - Returns: Formatted height (e.g., "5'9\"" in US, "175 cm" in Europe)
    static func formatHeight(_ cm: Double) -> String {
        let measurement = Measurement(value: cm, unit: UnitLength.centimeters)
        
        // Check if locale uses imperial system
        if usesImperialSystem() {
            // Convert to feet and inches
            let totalInches = measurement.converted(to: .inches).value
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        } else {
            return formatMeasurement(measurement)
        }
    }
    
    /// Formats distance measurement
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted distance (e.g., "3.2 mi" in US, "5.0 km" in Europe)
    static func formatDistance(_ meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        
        if usesImperialSystem() {
            let miles = measurement.converted(to: .miles)
            return formatMeasurement(miles)
        } else {
            let kilometers = measurement.converted(to: .kilometers)
            return formatMeasurement(kilometers)
        }
    }
    
    /// Generic measurement formatter
    /// - Parameter measurement: Any measurement to format
    /// - Returns: Formatted measurement string
    static func formatMeasurement<T: Unit>(_ measurement: Measurement<T>) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale.current
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
    
    /// Determines if the current locale uses the imperial system
    /// - Returns: true if imperial, false if metric
    static func usesImperialSystem() -> Bool {
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == "Metric"
        return !usesMetric
    }
}

// MARK: - Duration Formatting

/// Formats time durations in a user-friendly way
struct DurationFormatHelper {
    
    /// Formats duration in hours and minutes
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration (e.g., "1h 30m", "45m")
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)\(L10n.Unit.hours) \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formats duration in decimal hours
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration (e.g., "7.5h")
    static func formatHours(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        return String(format: "%.1f\(L10n.Unit.hours)", hours)
    }
    
    /// Formats sleep duration in a readable format
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration (e.g., "8h 30m" or "7.5h")
    static func formatSleepDuration(_ seconds: TimeInterval) -> String {
        return formatDuration(seconds)
    }
    
    /// Formats workout duration
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted duration (e.g., "45m" or "1h 15m")
    static func formatWorkoutDuration(_ seconds: TimeInterval) -> String {
        return formatDuration(seconds)
    }
}

// MARK: - SwiftUI Extensions

import SwiftUI

extension Foundation.Date {
    /// Returns a locale-aware formatted string for the date
    var formattedLong: String {
        DateFormatHelper.formatLongDate(self)
    }
    
    var formattedMedium: String {
        DateFormatHelper.formatMediumDate(self)
    }
    
    var formattedShort: String {
        DateFormatHelper.formatShortDate(self)
    }
    
    var formattedRelative: String {
        DateFormatHelper.formatRelativeDate(self)
    }
    
    var formattedTime: String {
        DateFormatHelper.formatTime(self)
    }
    
    var formattedDateTime: String {
        DateFormatHelper.formatDateTime(self)
    }
    
    var formattedGroupDate: String {
        DateFormatHelper.formatGroupDate(self)
    }
    
    var formattedMonthDay: String {
        DateFormatHelper.formatMonthDayDate(self)
    }
    
    var formattedDayAbbreviation: String {
        DateFormatHelper.formatDayAbbreviation(self)
    }
    
    var formattedDay: String {
        DateFormatHelper.formatDay(self)
    }
    
    var formattedShortMonthDayShortWeekDay: String {
        DateFormatHelper.shortMonthDayShortWeekDay(self)
    }
    
    var formattedWeekDayMonthNumericDay: String {
        DateFormatHelper.weekDayMonthNumericDay(self)
    }
        
    
}

extension Double {
    /// Formats the number as calories
    var asCalories: String {
        NumberFormatHelper.formatCalories(Int(self))
    }
    
    /// Formats the number as grams
    var asGrams: String {
        NumberFormatHelper.formatGrams(self)
    }
    
    /// Formats the number as weight (kg with locale conversion)
    var asWeight: String {
        MeasurementFormatHelper.formatWeight(self)
    }
    
    /// Formats the number as height (cm with locale conversion)
    var asHeight: String {
        MeasurementFormatHelper.formatHeight(self)
    }
}

extension Int {
    /// Formats the integer with locale-appropriate grouping
    var formatted: String {
        NumberFormatHelper.formatInteger(self)
    }
    
    /// Formats the integer as calories
    var asCalories: String {
        NumberFormatHelper.formatCalories(self)
    }
}

extension TimeInterval {
    /// Formats the time interval as a duration
    var asDuration: String {
        DurationFormatHelper.formatDuration(self)
    }
    
    /// Formats the time interval as hours
    var asHours: String {
        DurationFormatHelper.formatHours(self)
    }
}

