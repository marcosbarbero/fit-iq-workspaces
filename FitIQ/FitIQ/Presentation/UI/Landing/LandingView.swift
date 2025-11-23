import Foundation
import SwiftUI

struct LandingView: View {
    var authManager: AuthManager
    @EnvironmentObject var deps: AppDependencies
    @Environment(\.colorScheme) var colorScheme  // Correctly declared

    @State private var showingRegistration = false
    @State private var showingLogin = false

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var body: some View {
        VStack(spacing: 0) {

            // ... (Marketing/Hero Section content remains the same) ...
            Spacer()

            // 1. App Icon/Logo - Conditional for Light/Dark Mode
            Image("FitIQ_Logo")  // The single name of the asset set
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.bottom, 20)

            // Refined Main Headline
            Text(L10n.LandingPage.welcome)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.primary)  // .primary automatically switches between black/white
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            // Sub-Headline highlighting the core value: the AI Companion
            Text(L10n.LandingPage.subtitle)
                .font(.title3)
                .foregroundColor(.secondary)  // .secondary automatically adjusts opacity for readability
                .padding(.top, 5)
                .padding(.horizontal)

            // Key Value Props - A brief, easy-to-scan list
            VStack(alignment: .leading, spacing: 10) {

                // 1. Precise Workout (Fitness/Activity - Teal)
                FeatureRow(icon: "figure.walk.circle.fill", text: L10n.LandingPage.trackingWorkout)
                    .foregroundColor(.vitalityTeal)

                // 2. Macronutrient Tracking (Data/AI/Nutrition - Blue)
                FeatureRow(icon: "fork.knife.circle.fill", text: L10n.LandingPage.trackingNutrition)
                    .foregroundColor(.ascendBlue)

                // 4. Goal Setting (Data/Guidance - Blue)
                FeatureRow(icon: "target", text: L10n.LandingPage.trackingGoals)
                    .foregroundColor(.ascendBlue)

                // 3. Sleep Analysis (Wellness/Rest - Lavender)
                FeatureRow(icon: "bed.double.circle.fill", text: L10n.LandingPage.trackingSleep)
                    .foregroundColor(.serenityLavender)

                // 5. Mood Logging (Wellness/Mindfulness - Lavender)
                FeatureRow(icon: "face.smiling", text: L10n.LandingPage.trackingMood)
                    .foregroundColor(.serenityLavender)
            }
            .padding(.top, 30)
            .padding(.horizontal, 40)

            Spacer()

            // 2. Authentication Section

            // Register Button (Primary CTA)
            Button(L10n.LandingPage.signUp) {
                showingRegistration = true
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.ascendBlue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: Color.ascendBlue.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.top, 20)

            // Login Link (Secondary Action)
            Button {
                showingLogin = true
            } label: {
                Text(L10n.LandingPage.signIn)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 15)
            .foregroundColor(.secondary)
            .padding(.bottom, 20)

        }
        .padding(.horizontal, 30)
        // ✨ THE FIX IS HERE ✨
        .background(
            colorScheme == .dark
                ? Color.cleanSlateDark.edgesIgnoringSafeArea(.all)
                : Color.cleanSlateLight.edgesIgnoringSafeArea(.all)
        )
        .sheet(isPresented: $showingRegistration) {
            RegistrationView(
                authRepository: deps.authRepository,
                authManager: authManager,
                userProfileStorage: deps.userProfileStorage,  // Added
                authTokenPersistence: deps.authTokenPersistence,  // Added
                profileMetadataClient: deps.profileMetadataClient,  // Added for profile creation
                isPresented: $showingRegistration
            )
        }.sheet(isPresented: $showingLogin) {
            LoginView(
                authManager: authManager, loginUserUseCase: deps.loginUserUseCase,
                isPresented: $showingLogin)
        }
    }
}

// MARK: - Helper Views (FeatureRow and Color Extension)

// Assuming FeatureRow is correct
private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}
