//
//  SplashScreenView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import SwiftUI

/// Splash screen with Lume branding
/// Provides a warm welcome with the app icon, name, and ambient design elements
struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var nameOpacity: Double = 0
    @State private var circle1Scale: CGFloat = 0.8
    @State private var circle2Scale: CGFloat = 0.8
    @State private var circle3Scale: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Warm background
            LumeColors.appBackground
                .ignoresSafeArea()

            // Ambient circles - soft, subtle decoration
            Circle()
                .fill(LumeColors.accentPrimary.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: -100, y: -200)
                .scaleEffect(circle1Scale)

            Circle()
                .fill(LumeColors.accentSecondary.opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 40)
                .offset(x: 120, y: 150)
                .scaleEffect(circle2Scale)

            Circle()
                .fill(LumeColors.moodPositive.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .offset(x: -80, y: 200)
                .scaleEffect(circle3Scale)

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // App Icon
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26.4, style: .continuous))
                    .shadow(color: LumeColors.textPrimary.opacity(0.1), radius: 20, x: 0, y: 10)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                // App Name
                Text("Lume")
                    .font(LumeTypography.titleLarge)
                    .fontWeight(.medium)
                    .foregroundColor(LumeColors.textPrimary)
                    .opacity(nameOpacity)

                // Tagline
                Text("Your wellness companion")
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textSecondary)
                    .opacity(nameOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Ambient circles gentle pulsing
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                circle1Scale = 1.0
            }

            withAnimation(.easeInOut(duration: 2.5).delay(0.3).repeatForever(autoreverses: true)) {
                circle2Scale = 1.1
            }

            withAnimation(.easeInOut(duration: 2.2).delay(0.6).repeatForever(autoreverses: true)) {
                circle3Scale = 1.05
            }

            // Icon entrance animation
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Text fade in
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                nameOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
