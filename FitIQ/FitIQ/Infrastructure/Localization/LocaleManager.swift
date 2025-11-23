//
//  LocaleManager.swift
//
//  Manages the app's locale and language preference
//  Provides dynamic language switching support
//

import Foundation
import SwiftUI
import Combine

/// Manages the application's locale and provides dynamic language switching
@MainActor
final class LocaleManager: ObservableObject {
    static let shared = LocaleManager()
    
    /// Current language code (e.g., "en", "es", "pt-BR", "fr", "de")
    /// When changed, triggers a UI refresh by updating objectWillChange
    @Published var currentLanguageCode: String {
        willSet {
            objectWillChange.send()
        }
        didSet {
            UserDefaults.standard.set(currentLanguageCode, forKey: languageKey)
            updateBundle()
        }
    }
    
    /// The bundle to use for localized strings
    private(set) var bundle: Bundle = .main
    
    /// Cache for localized strings to improve performance
    private var stringCache: [String: String] = [:]
    
    private let languageKey = "AppLanguageCode"
    
    private init() {
        // Load saved language or use device default
        if let saved = UserDefaults.standard.string(forKey: languageKey) {
            self.currentLanguageCode = saved
        } else {
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguageCode = deviceLanguage
        }
        updateBundle()
    }
    
    /// Updates the localization bundle based on current language
    private func updateBundle() {
        // Clear cache when language changes
        stringCache.removeAll()
        
        guard let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to English if language bundle not found
            if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let enBundle = Bundle(path: enPath) {
                self.bundle = enBundle
            } else {
                self.bundle = .main
            }
            return
        }
        self.bundle = bundle
    }
    
    /// Changes the app's language and forces UI refresh
    /// - Parameter languageCode: The language code to switch to
    func setLanguage(_ languageCode: String) {
        currentLanguageCode = languageCode
    }
    
    /// Gets a localized string using the current bundle with caching for performance
    /// - Parameter key: The localization key
    /// - Returns: The localized string
    func localizedString(forKey key: String) -> String {
        // Check cache first
        if let cached = stringCache[key] {
            return cached
        }
        
        // Fetch from bundle and cache it
        let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
        stringCache[key] = localized
        return localized
    }
}

// MARK: - Environment Key
struct LocaleManagerKey: EnvironmentKey {
    static let defaultValue = LocaleManager.shared
}

extension EnvironmentValues {
    var localeManager: LocaleManager {
        get { self[LocaleManagerKey.self] }
        set { self[LocaleManagerKey.self] = newValue }
    }
}
