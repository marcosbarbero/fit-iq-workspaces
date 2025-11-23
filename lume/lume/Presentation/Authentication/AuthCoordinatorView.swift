import SwiftData
import SwiftUI

struct AuthCoordinatorView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showingRegistration = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                if showingRegistration {
                    RegisterView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .trailing)
                            ))
                } else {
                    LoginView(viewModel: viewModel)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading),
                                removal: .move(edge: .leading)
                            ))
                }
            }

            // Toggle Button - Fixed at bottom, no overlap
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingRegistration.toggle()
                    viewModel.errorMessage = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Text(
                        showingRegistration
                            ? "Already have an account?" : "Don't have an account?"
                    )
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textSecondary)

                    Text(showingRegistration ? "Sign In" : "Sign Up")
                        .font(LumeTypography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(LumeColors.accentPrimary)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            }
            .disabled(viewModel.isLoading)
            .background(LumeColors.appBackground)
            .padding(.bottom, 32)
        }
        .background(LumeColors.appBackground)
        .onChange(of: viewModel.isAuthenticated) { _, newValue in
            // When user logs out, reset to login view
            if !newValue {
                showingRegistration = false
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview
    return AuthCoordinatorView(
        viewModel: dependencies.makeAuthViewModel()
    )
}
