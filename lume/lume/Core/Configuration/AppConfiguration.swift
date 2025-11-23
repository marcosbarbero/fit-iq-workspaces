//
//  AppConfiguration.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import Foundation

/// Application configuration management
/// Reads values from config.plist and provides type-safe access
final class AppConfiguration {

    // MARK: - Singleton

    static let shared = AppConfiguration()

    // MARK: - Properties

    private let configuration: [String: Any]

    // MARK: - Configuration Keys

    private enum ConfigKey: String {
        case backendBaseURL = "BACKEND_BASE_URL"
        case apiKey = "API_KEY"
        case webSocketURL = "WebSocketURL"
    }

    // MARK: - Public Properties

    /// Backend base URL for API calls
    var backendBaseURL: URL {
        guard let urlString = getString(for: .backendBaseURL),
            let url = URL(string: urlString)
        else {
            fatalError("BACKEND_BASE_URL not configured or invalid in config.plist")
        }
        return url
    }

    /// API key for backend authentication
    var apiKey: String {
        guard let key = getString(for: .apiKey), !key.isEmpty else {
            fatalError("API_KEY not configured in config.plist")
        }
        return key
    }

    /// WebSocket URL for real-time connections (optional for future use)
    var webSocketURL: URL? {
        guard let urlString = getString(for: .webSocketURL),
            let url = URL(string: urlString)
        else {
            return nil
        }
        return url
    }

    // MARK: - Initialization

    private init() {
        guard let path = Bundle.main.path(forResource: "config", ofType: "plist"),
            let config = NSDictionary(contentsOfFile: path) as? [String: Any]
        else {
            fatalError("config.plist not found in main bundle")
        }

        self.configuration = config
    }

    // MARK: - Private Helpers

    private func getString(for key: ConfigKey) -> String? {
        return configuration[key.rawValue] as? String
    }

    private func getBool(for key: ConfigKey, defaultValue: Bool = false) -> Bool {
        return configuration[key.rawValue] as? Bool ?? defaultValue
    }

    private func getInt(for key: ConfigKey, defaultValue: Int = 0) -> Int {
        return configuration[key.rawValue] as? Int ?? defaultValue
    }
}

// MARK: - Environment-Specific Configuration

extension AppConfiguration {

    /// Check if running in production environment
    var isProduction: Bool {
        return backendBaseURL.absoluteString.contains("lume.app")
            || backendBaseURL.absoluteString.contains("production")
    }

    /// Check if running in development/staging environment
    var isDevelopment: Bool {
        return !isProduction
    }

    /// API endpoint configurations
    struct Endpoints {
        static let authRegister = "/api/v1/auth/register"
        static let authLogin = "/api/v1/auth/login"
        static let authRefresh = "/api/v1/auth/refresh"
        static let authLogout = "/api/v1/auth/logout"
    }
}

// MARK: - Debug Helpers

extension AppConfiguration {

    /// Print configuration for debugging (masks sensitive data)
    func printConfiguration() {
        #if DEBUG
            print("=== App Configuration ===")
            print("Backend URL: \(backendBaseURL.absoluteString)")
            print("API Key: \(String(repeating: "*", count: apiKey.count))")
            print("Environment: \(isProduction ? "Production" : "Development")")
            if let wsURL = webSocketURL {
                print("WebSocket URL: \(wsURL.absoluteString)")
            }
            print("========================")
        #endif
    }
}
