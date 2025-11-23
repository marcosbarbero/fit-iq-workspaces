import Foundation
import SwiftUI


struct LoginView: View {
       
    @StateObject private var viewModel: LoginViewModel
    
    @Binding var isPresented: Bool
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email, password
    }
    
    init(authManager: AuthManager, loginUserUseCase: LoginUserUseCaseProtocol, isPresented: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authManager: authManager, loginUserUseCase: loginUserUseCase))
        _isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. Header and Logo
                    VStack(spacing: 8) {
                        Image("FitIQ_Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                        
                        Text(L10n.Login.subtitle)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 30)

                    // 2. Single Sign-On (SSO) Buttons
                    VStack(spacing: 10) {
                        
                        // Apple Sign In
                        SSOButton(title: L10n.Common.ssoApple, iconName: "apple.logo", color: .black) {
                            // ACTION: Integrate ViewModel SSO action here
                            print("Calling viewModel.signInWithApple()")
                        }

                        // Google Sign In
                        SSOButton(title: L10n.Common.ssoGoogle, iconName: "g.circle.fill", color: Color(hex: "#4285F4")) {
                            // ACTION: Integrate ViewModel SSO action here
                            print("Calling viewModel.signInWithGoogle()")
                        }
                    }
                    .padding(.horizontal, 25)

                    // 3. Separator
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                        Text("OR").font(.caption).foregroundColor(.secondary)
                        Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                    }
                    .padding(.horizontal, 25)
                    
                    // 4. Form Fields
                    VStack(spacing: 15) {
                        
                        // Email Field
                        CustomTextField(
                            placeholder: L10n.Login.email,
                            text: $viewModel.email, // BINDING to ViewModel
                            iconName: "envelope",
                            isSecure: false
                        )
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        
                        // Password Field
                        CustomTextField(
                            placeholder: L10n.Login.password,
                            text: $viewModel.password, // BINDING to ViewModel
                            iconName: "lock",
                            isSecure: true
                        )
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        
                        // Password Reset Link
                        HStack {
                            Spacer()
                            Button(L10n.Login.forgotPassword) {
                                print("Forgot Password Tapped")
                            }
                            .foregroundColor(.ascendBlue)
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 25)

                    // 5. Login Button (Primary CTA)
                    Button {
                        // ACTION: Connect to ViewModel login function
                        viewModel.login()
                    } label: {
                        HStack {
                            Text(viewModel.isLoading ? L10n.Login.signInProgress : L10n.Login.signIn)
                                .fontWeight(.bold)
                            if viewModel.isLoading { // BINDING to ViewModel loading state
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.ascendBlue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    // BINDING: Connect disabled state to ViewModel
                    .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                    .padding(.horizontal, 25)
                    .padding(.top, 10)

                    // 6. Error/Success Message
                    if let message = viewModel.loginMessage { // BINDING to ViewModel message
                        Text(message)
                            // Use brand colors for feedback (assuming "Successful" implies success)
                            .foregroundColor(viewModel.loginMessage?.contains("Successful") == true ? .growthGreen : .attentionOrange)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 25)
                    }
                    
                    Spacer()
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.Login.title)
            .navigationBarTitleDisplayMode(.inline)
            
            // Toolbar and onSubmit for standard iOS functionalty
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        isPresented = false
                    }
                }
            }
            .onSubmit {
                switch focusedField {
                case .email: focusedField = .password
                case .password:
                    viewModel.login() // ACTION: Call login on final submit
                    focusedField = nil
                default:
                    focusedField = nil
                }
            }
        }
    }
}
