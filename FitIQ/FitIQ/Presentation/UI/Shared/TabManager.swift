//
//  TabManager.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftUI
import Combine
import Observation

class TabManager: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case summary
        case nutrition
        case profile
        case workouts
        case plan
        case coach
        case community
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .summary: return L10n.Navigation.summary
            case .nutrition: return "Nutrition"
            case .profile: return L10n.Navigation.profile
            case .workouts: return L10n.Navigation.workouts
            case .plan: return L10n.Navigation.plan
            case .coach: return L10n.Navigation.coach
            case .community: return L10n.Navigation.community
            }
        }
        
        var iconName: String {
            switch self {
            // Refined Icons for modern look:
            case .summary: return "chart.bar.fill" // Robust Data/Dashboard view
            case .profile: return "person.fill"
            case .nutrition: return "fork.knife"
            case .workouts: return "figure.strengthtraining.traditional" // More specific than figure.walk
            case .plan: return "calendar.badge.checkmark" // Focuses on plan completion
            case .coach: return "figure.mind.and.body" // Aligns with our AI Companion branding
            case .community: return "rectangle.grid.1x2.fill"
            }
        }
    }

    @Published var selectedTab: Tab = .summary

    // Individual navigation paths
    @Published var summaryPath = NavigationPath()
    @Published var nutritionPath = NavigationPath()
    @Published var profilePath = NavigationPath()
    @Published var workoutsPath = NavigationPath()
    @Published var planPath = NavigationPath()
    @Published var coachPath = NavigationPath()
    @Published var communityPath = NavigationPath() // Not used, but for consistency

    // NEW: Unique keys to force NavigationStack rebuild when changed
    @Published var summaryPathID = UUID()
    @Published var nutritionPathID = UUID()
    @Published var profilePathID = UUID()
    @Published var workoutsPathID = UUID()
    @Published var planPathID = UUID()
    @Published var coachPathID = UUID()
    @Published var communityPathID = UUID() // Not used, but for consistency

    var isPathDeep: Bool {
        switch selectedTab {
        case .summary: return !summaryPath.isEmpty
        case .nutrition: return !nutritionPath.isEmpty
        case .profile: return !profilePath.isEmpty
        case .workouts: return !workoutsPath.isEmpty
        case .plan: return !planPath.isEmpty
        case .coach: return !coachPath.isEmpty
        case .community: return !communityPath.isEmpty // No navigation stack for Community tab
        }
    }

    // UPDATED: Resets path AND updates the ID to force the view back to root
    func popToRoot() {
        if isPathDeep {
            switch selectedTab {
            case .summary:
                summaryPath = NavigationPath()
                summaryPathID = UUID() // Force rebuild!
            case .nutrition:
                nutritionPath = NavigationPath()
                nutritionPathID = UUID() // Force rebuild!
            case .profile:
                profilePath = NavigationPath()
                profilePathID = UUID() // Force rebuild!
            case .workouts:
                workoutsPath = NavigationPath()
                workoutsPathID = UUID() // Force rebuild!
            case .plan:
                planPath = NavigationPath()
                planPathID = UUID() // Force rebuild!
            case .coach:
                coachPath = NavigationPath()
                coachPathID = UUID() // Force rebuild!
            case .community:
                communityPath = NavigationPath()
                communityPathID = UUID() // Force rebuild!
            }
        }
    }
}
