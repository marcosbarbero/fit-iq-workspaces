//
//  RegistrationView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftUI

// Assuming necessary helper structs (CustomTextField, SSOButton) are defined below
// and Color extensions (ascendBlue, etc.) are available.

struct RegistrationView: View {

    // 1. STATE MANAGEMENT: Revert to @StateObject for ViewModel
    @StateObject private var viewModel: RegistrationViewModel

    @Binding var isPresented: Bool

    init(
        authRepository: AuthRepositoryProtocol,
        authManager: AuthManager,
        userProfileStorage: UserProfileStoragePortProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        profileMetadataClient: UserProfileMetadataClient,
        isPresented: Binding<Bool>
    ) {
        _viewModel = StateObject(
            wrappedValue: RegistrationViewModel(
                authManager: authManager,
                authRepository: authRepository,
                userProfileStorage: userProfileStorage,
                authTokenPersistence: authTokenPersistence,
                profileMetadataClient: profileMetadataClient
            ))
        _isPresented = isPresented
    }

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, name, dateOfBirth, password
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

                        Text(L10n.Registration.subtitle)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 30)

                    // 2. Single Sign-On (SSO) Buttons
                    VStack(spacing: 10) {

                        // Apple Sign In
                        SSOButton(
                            title: L10n.Common.ssoApple, iconName: "apple.logo", color: .black
                        ) {
                            // ACTION: Integrate ViewModel SSO action here later
                            print("Calling viewModel.signInWithApple()")
                        }

                        // Google Sign In
                        SSOButton(
                            title: L10n.Common.ssoGoogle, iconName: "g.circle.fill",
                            color: Color(hex: "#4285F4")
                        ) {
                            // ACTION: Integrate ViewModel SSO action here later
                            print("Calling viewModel.signInWithGoogle()")
                        }
                    }
                    .padding(.horizontal, 25)

                    // 3. Separator
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                        Text(L10n.Registration.or).font(.caption).foregroundColor(.secondary)
                        Rectangle().frame(height: 1).foregroundColor(Color(.separator))
                    }
                    .padding(.horizontal, 25)

                    // 4. Form Fields
                    VStack(spacing: 15) {

                        // Account Information
                        Group {
                            CustomTextField(
                                placeholder: L10n.Registration.email,
                                text: $viewModel.email,  // BINDING to ViewModel
                                iconName: "envelope",
                                isSecure: false
                            )
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                        }

                        // Personal Details
                        Group {
                            CustomTextField(
                                placeholder: L10n.Registration.name,
                                text: $viewModel.name,  // BINDING to ViewModel
                                iconName: "person",
                                isSecure: false
                            )
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                        }

                        // Date of Birth
                        CustomDateField(
                            placeholder: L10n.Registration.dateOfBirth,
                            date: $viewModel.dateOfBirth,
                            iconName: "calendar",
                            dateRange: ...Date()
                        )
                        .focused($focusedField, equals: .dateOfBirth)

                        // Password
                        CustomTextField(
                            placeholder: L10n.Registration.password,
                            text: $viewModel.password,  // BINDING to ViewModel
                            iconName: "lock",
                            isSecure: true
                        )
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                    }
                    .padding(.horizontal, 25)

                    // 5. Register Button (Primary CTA)
                    Button {
                        // ACTION: Connect to ViewModel register function
                        viewModel.register()
                    } label: {
                        HStack {
                            Text(
                                viewModel.isLoading
                                    ? L10n.Registration.registerProgress
                                    : L10n.Registration.createAccount
                            )
                            .fontWeight(.bold)
                            if viewModel.isLoading {  // BINDING to ViewModel loading state
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
                    .disabled(
                        viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty
                    )
                    .padding(.horizontal, 25)
                    .padding(.top, 10)

                    // 6. Error/Success Message
                    if let message = viewModel.registrationMessage {
                        Text(message)
                            // Use brand colors for feedback
                            .foregroundColor(
                                viewModel.registeredUser != nil ? .growthGreen : .attentionOrange
                            )
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
            .navigationTitle(L10n.Registration.title)
            .navigationBarTitleDisplayMode(.inline)

            // Toolbar and onSubmit remain the same, ensuring the keyboard flow works
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel) {
                        isPresented = false
                    }
                }
            }
            .onSubmit {
                switch focusedField {
                case .email: focusedField = .name
                case .name: focusedField = .dateOfBirth
                case .dateOfBirth: focusedField = .password
                case .password:
                    viewModel.register()  // ACTION: Call register on final submit
                    focusedField = nil
                default:
                    focusedField = nil
                }
            }
        }
        // NEW: Dismiss the sheet when registration is successful
        .onChange(of: viewModel.registrationSuccessful) { successful in
            if successful {
                isPresented = false
            }
        }
    }
}
