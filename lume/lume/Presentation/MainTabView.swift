//
//  MainTabView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import Combine
import SwiftUI

/// Coordinator for tab navigation and cross-feature actions
@MainActor
class TabCoordinator: ObservableObject {
    @Published var selectedTab = 0
    @Published var goalToShow: Goal?
    @Published var conversationToShow: ChatConversation?

    func switchToGoals(showingGoal goal: Goal? = nil) {
        selectedTab = 3
        goalToShow = goal
    }

    func switchToChat(showingConversation conversation: ChatConversation? = nil) {
        selectedTab = 2  // Chat tab
        conversationToShow = conversation
    }
}

struct MainTabView: View {
    let dependencies: AppDependencies
    let authViewModel: AuthViewModel

    @StateObject private var tabCoordinator = TabCoordinator()
    @State private var showingProfile = false
    @State private var showingMoodEntry = false
    @State private var showingJournalEntry = false

    var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            NavigationStack {
                MoodTrackingView(viewModel: dependencies.makeMoodViewModel())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            ProfileButton { showingProfile = true }
                        }
                    }
            }
            .tabItem {
                Label("Mood", systemImage: "sun.max.fill")
            }
            .tag(0)

            NavigationStack {
                JournalListView(viewModel: dependencies.makeJournalViewModel())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            ProfileButton { showingProfile = true }
                        }
                    }
            }
            .tabItem {
                Label("Journal", systemImage: "book.fill")
            }
            .tag(1)

            NavigationStack {
                ChatListView(viewModel: dependencies.makeChatViewModel())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            ProfileButton { showingProfile = true }
                        }
                    }
                    .environmentObject(tabCoordinator)
            }
            .tabItem {
                Label("AI Chat", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag(2)

            NavigationStack {
                GoalsListView(
                    viewModel: dependencies.makeGoalsViewModel(),
                    goalToShow: $tabCoordinator.goalToShow,
                    dependencies: dependencies
                )
                .toolbar(.visible, for: .tabBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ProfileButton { showingProfile = true }
                    }
                }
                .environmentObject(tabCoordinator)
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }
            .tag(3)

            NavigationStack {
                DashboardView(
                    viewModel: dependencies.makeDashboardViewModel(),
                    insightsViewModel: dependencies.makeAIInsightsViewModel(),
                    onMoodLog: { showingMoodEntry = true },
                    onJournalWrite: { showingJournalEntry = true }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        ProfileButton { showingProfile = true }
                    }
                }
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }
            .tag(4)
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                ProfileDetailView(
                    viewModel: dependencies.makeProfileViewModel(),
                    dependencies: dependencies
                )
            }
            .presentationBackground(LumeColors.appBackground)
        }
        .sheet(isPresented: $showingMoodEntry) {
            NavigationStack {
                LinearMoodSelectorView(
                    viewModel: dependencies.makeMoodViewModel(),
                    onMoodSaved: {
                        showingMoodEntry = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingJournalEntry) {
            NavigationStack {
                JournalEntryView(
                    viewModel: dependencies.makeJournalViewModel(),
                    existingEntry: nil
                )
            }
        }

        .tint(LumeColors.textPrimary)
        .onAppear {

            // Inline state (when you have scrolled)
            let standardAppearance = UINavigationBarAppearance()
            standardAppearance.configureWithOpaqueBackground()
            standardAppearance.backgroundColor = UIColor(LumeColors.appBackground)
            standardAppearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor(LumeColors.textPrimary)
            ]
            standardAppearance.titleTextAttributes = [
                .foregroundColor: UIColor(LumeColors.textPrimary)
            ]

            // Large title at scroll edge (when list is at the top)
            let scrollEdgeAppearance = UINavigationBarAppearance()
            scrollEdgeAppearance.configureWithTransparentBackground()
            scrollEdgeAppearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor(LumeColors.textPrimary)
            ]
            scrollEdgeAppearance.titleTextAttributes = [
                .foregroundColor: UIColor(LumeColors.textPrimary)
            ]

            UINavigationBar.appearance().standardAppearance = standardAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance
        }
    }
}

// MARK: - Placeholder Views

struct MoodPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LumeColors.moodPositive)

                    Text("Mood Tracking")
                        .font(LumeTypography.titleLarge)
                        .foregroundColor(LumeColors.textPrimary)

                    Text("Track your daily mood and emotional well-being")
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Coming Soon")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(LumeColors.accentPrimary)
                        .cornerRadius(20)
                }
            }
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(LumeColors.appBackground, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

struct JournalPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundColor(LumeColors.accentSecondary)

                    Text("Journal")
                        .font(LumeTypography.titleLarge)
                        .foregroundColor(LumeColors.textPrimary)

                    Text("Reflect on your thoughts and experiences")
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Coming Soon")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(LumeColors.accentPrimary)
                        .cornerRadius(20)
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(LumeColors.appBackground, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

struct GoalsPlaceholderView: View {
    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(LumeColors.accentPrimary)

                Text("Goals")
                    .font(LumeTypography.titleLarge)
                    .foregroundColor(LumeColors.textPrimary)

                Text("Set and track your wellness goals with AI support")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("Coming Soon")
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LumeColors.accentPrimary)
                    .cornerRadius(20)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(LumeColors.appBackground, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - Placeholder ProfileView (removed - replaced by ProfileDetailView)
// The full profile implementation is now in:
// - Presentation/Features/Profile/ProfileDetailView.swift
// - Presentation/Features/Profile/ProfileViewModel.swift
// - Presentation/Features/Profile/EditProfileView.swift
// - Presentation/Features/Profile/EditPhysicalProfileView.swift
// - Presentation/Features/Profile/EditPreferencesView.swift

#Preview {
    let dependencies = AppDependencies.preview
    let authViewModel = dependencies.makeAuthViewModel()
    authViewModel.isAuthenticated = true

    return MainTabView(
        dependencies: dependencies,
        authViewModel: authViewModel
    )
}

// MARK: - Profile Button

struct ProfileButton: View {
    let action: () -> Void
    @State private var profileImageData: Data?

    var body: some View {
        Button {
            action()
        } label: {
            if let imageData = profileImageData,
                let uiImage = UIImage(data: imageData)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                LumeColors.accentPrimary,
                                LumeColors.accentSecondary,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
        }
        .onAppear {
            loadProfileImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileImageDidChange)) { _ in
            loadProfileImage()
        }
    }

    private func loadProfileImage() {
        profileImageData = ProfileImageManager.shared.loadProfileImage()
    }
}
