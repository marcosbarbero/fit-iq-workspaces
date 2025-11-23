import SwiftUI

struct LoadingView: View {
    // Determine the color scheme to use the correct background colors
    @Environment(\.colorScheme) var colorScheme

    // State to control the pulsing animation
    @State private var pulse = false

    // Define the colors used in your LandingView background
    // Fallback to system colors if custom colors are not defined
    private var lightBackgroundColor: Color {
        Color("cleanSlateLight") ?? Color(.systemBackground)
    }
    private var darkBackgroundColor: Color {
        Color("cleanSlateDark") ?? Color(.systemBackground)
    }

    var body: some View {
        ZStack {
            // 1. Full-screen OPAQUE background - completely covers content underneath
            (colorScheme == .dark ? darkBackgroundColor : lightBackgroundColor)
                .ignoresSafeArea()

            // 2. Blurry Gradient Effect (in the background layer)
            // Mimics the blurry header from your authenticated view for brand consistency
            VStack {
                LinearGradient(
                    colors: [
                        (Color("ascendBlue") ?? Color.blue).opacity(0.3),
                        (Color("vitalityTeal") ?? Color.teal).opacity(0.2),
                        (Color("serenityLavender") ?? Color.purple).opacity(0.3),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 300)
                .blur(radius: 80)  // A heavy blur for a soft light effect
                .offset(y: -250)  // Position it near the top

                Spacer()
            }

            // 3. Content (logo, spinner, text) on top
            VStack {
                Spacer()

                // Logo/Icon
                Image("FitIQ_Logo")  // Use your primary logo asset
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.05 : 1.0)  // Subtle scaling effect
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )

                // Branded Progress Indicator
                ProgressView()
                    .progressViewStyle(
                        CircularProgressViewStyle(tint: Color("ascendBlue") ?? .blue)
                    )  // Use a primary brand color
                    .scaleEffect(1.5)  // Make the spinner more visible
                    .padding(.top, 40)

                // Loading Text
                Text("Your AI Companion Awaits...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .onAppear {
            // Start the pulse animation when the view appears
            pulse = true
        }
    }
}
