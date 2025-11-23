import SwiftData
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with subtle branding
                VStack(spacing: 16) {
                    // Small app icon at top
                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12.3, style: .continuous))
                        .shadow(color: LumeColors.textPrimary.opacity(0.06), radius: 8, x: 0, y: 4)

                    // Main heading
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(LumeTypography.titleLarge)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Sign in to your Lume account")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                    }
                }
                .padding(.top, 60)

                // Form
                VStack(spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        TextField("your@email.com", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .padding()
                            .foregroundColor(LumeColors.textPrimary)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .email
                                            ? LumeColors.accentPrimary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        SecureField("••••••••", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .padding()
                            .foregroundColor(LumeColors.textPrimary)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .password
                                            ? LumeColors.accentPrimary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)

                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.moodLow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale))
                }

                // Login Button
                Button {
                    focusedField = nil
                    Task {
                        await viewModel.login()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(LumeColors.textPrimary)
                        } else {
                            Text("Sign In")
                                .font(LumeTypography.body)
                                .fontWeight(.medium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(LumeColors.textPrimary)
                    .background(LumeColors.accentPrimary)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading || !isFormValid)
                .opacity(isFormValid ? 1.0 : 0.6)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
        }
        .background(LumeColors.appBackground)
        .onSubmit {
            if focusedField == .email {
                focusedField = .password
            } else if focusedField == .password {
                Task {
                    await viewModel.login()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    private var isFormValid: Bool {
        !viewModel.email.isEmpty && viewModel.email.contains("@") && !viewModel.password.isEmpty
    }
}

#Preview {
    let dependencies = AppDependencies.preview
    return LoginView(
        viewModel: dependencies.makeAuthViewModel()
    )
}
