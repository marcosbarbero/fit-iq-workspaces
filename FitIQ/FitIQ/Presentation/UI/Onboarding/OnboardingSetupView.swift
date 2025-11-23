//
//  OnboardingSetupView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftUI
import UserNotifications

// NOTE: You'll likely need an OnboardingViewModel to handle the actual permission requests
// and navigate the user to the main tab view (e.g., via AuthManager).

struct OnboardingSetupView: View {
    let authManager: AuthManager
    let viewModel: OnboardingSetupViewModel
    
    
    // State to track step completion
    @State private var healthAccessGranted: Bool = false
    @State private var notificationsEnabled: Bool = false
    
    // State for overall progress/loading
    @State private var isLoading: Bool = false
    
    init(authManager: AuthManager, viewModel: OnboardingSetupViewModel) {
        self.authManager = authManager
        self.viewModel = viewModel
    }
    
    var isSetupComplete: Bool {
        healthAccessGranted && notificationsEnabled
    }
    
    var body: some View {
        VStack(spacing: 30) {
            
            Spacer()
            
            // Branding and Header
            VStack(spacing: 10) {
                Image("FitIQ_Logo") // Dynamic Logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                
                Text("Your Personal Health Companion")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("To unlock FitIQ's full potential, please grant the following permissions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            // MARK: - Permission Steps
            VStack(spacing: 20) {
                
                // 1. Health App Data Access
                PermissionRow(
                    icon: "heart.circle.fill",
                    title: "Access Health Data",
                    description: "Allows the Companion AI to analyze your workouts, sleep, and activity for personalized insights and goal setting.",
                    color: .vitalityTeal, // Fitness/Activity Color
                    isGranted: healthAccessGranted
                ) {
                    requestHealthKitPermission()
                }
                
                // 2. Notification Permissions
                PermissionRow(
                    icon: "bell.circle.fill",
                    title: "Enable Notifications",
                    description: "Receive timely nudges, rest day reminders, and progress updates from your Health Companion.",
                    color: .serenityLavender, // Wellness/Mindfulness Color
                    isGranted: notificationsEnabled
                ) {
                    requestNotificationPermission()
                }
            }
            .padding(.horizontal, 25)
            
            Spacer()
            
            // MARK: - Final Action Button
            Button {
                self.authManager.completeOnboarding()
            } label: {
                HStack {
                    Text(isLoading ? "Finalizing Setup..." : "Start My Journey")
                        .fontWeight(.bold)
                    if isLoading { ProgressView() }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSetupComplete ? Color.ascendBlue : Color.gray.opacity(0.5)) // Enable/Disable color
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(!isSetupComplete || isLoading) // Only enable when both are granted
            .padding(.horizontal, 25)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
    }
    
    // MARK: - Permission Handlers (Stubs)
    
    func requestHealthKitPermission() {
        // NOTE: In a real app, this function contains the HKHealthStore request.
        print("Requesting HealthKit permission...")
        isLoading = true
        
        Task {
            await viewModel.requestHealthKitAuthorization()
            isLoading = false
            healthAccessGranted = true // this needs to set based on actual authorization result
        }
    }
    
    func requestNotificationPermission() {
        // NOTE: In a real app, this function contains UNUserNotificationCenter request.
        print("Requesting Notification permission...")
        isLoading = true

        // Simulating the delay and result of the OS prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            // Assume success for UI testing
            notificationsEnabled = true
        }
    }
}

// MARK: - PermissionRow Helper View

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        // 1. Wrap the entire UI in a Button
        Button(action: {
            // Only allow action if permission hasn't been granted yet
            if !isGranted {
                action()
            }
        }) {
            // 2. The entire HStack is now the button's label
            HStack(alignment: .top, spacing: 15) {
                
                // Icon (Left)
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                
                // Text Content (Center)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary) // Ensure text color adapts to Dark/Light Mode
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Indicator (Right)
                Image(systemName: isGranted ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(isGranted ? .growthGreen : .gray)
            }
            .padding()
            .background(Color(.secondarySystemBackground)) // Light background card
            .cornerRadius(12)
        }
        // 3. Apply custom button style to remove default blue tint/press effects
        .buttonStyle(PlainButtonStyle())
        // 4. Disable the entire button if access is granted
        .disabled(isGranted)
    }
}
