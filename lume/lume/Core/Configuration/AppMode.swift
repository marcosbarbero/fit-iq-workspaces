//
//  AppMode.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation
import FitIQCore

/// Application mode configuration
/// Controls whether app uses local mock data or real backend
enum AppMode {
    case local  // Uses mock data, no backend needed
    case production  // Uses real backend API

    /// Current mode - change this to switch between local and production
    /// Set to .local to test without backend (uses mock services)
    /// Set to .production to connect to real backend API
    static var current: AppMode = .production

    /// Whether the app should use mock data
    static var useMockData: Bool {
        current == .local
    }

    /// Whether the app should connect to backend
    static var useBackend: Bool {
        current == .production
    }

    /// Display name for current mode
    var displayName: String {
        switch self {
        case .local:
            return "Local Development"
        case .production:
            return "Production"
        }
    }
}

/// Mock user for local development
struct MockUser {
    static let shared = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        email: "demo@lume.app",
        name: "Demo User",
        dateOfBirth: Calendar.current.date(byAdding: .year, value: -25, to: Date())!,
        createdAt: Date()
    )
}

/// Mock token for local development
struct MockToken {
    static let shared = AuthToken(
        accessToken: "mock-access-token",
        refreshToken: "mock-refresh-token",
        expiresAt: Date().addingTimeInterval(86400 * 365)  // 1 year
    )
}
