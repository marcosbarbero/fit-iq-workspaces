import SwiftData
import SwiftUI

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case name
        case email
        case password
        case day
        case month
        case year
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
                        Text("Create Your Account")
                            .font(LumeTypography.titleLarge)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Begin your wellness journey with Lume")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                    }
                }
                .padding(.top, 60)

                // Form
                VStack(spacing: 20) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        TextField("Your name", text: $viewModel.name)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .focused($focusedField, equals: .name)
                            .padding()
                            .foregroundColor(LumeColors.textPrimary)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .name
                                            ? LumeColors.accentPrimary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }

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

                        SecureField("At least 8 characters", text: $viewModel.password)
                            .textContentType(.newPassword)
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

                        if !viewModel.password.isEmpty {
                            HStack(spacing: 4) {
                                Image(
                                    systemName: viewModel.password.count >= 8
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .foregroundColor(
                                    viewModel.password.count >= 8
                                        ? LumeColors.moodPositive : LumeColors.textSecondary
                                )
                                .font(.system(size: 12))

                                Text("At least 8 characters")
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Date of Birth Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        HStack(spacing: 12) {
                            // Day
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DD")
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)

                                TextField("15", text: $dayText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .focused($focusedField, equals: .day)
                                    .frame(height: 48)
                                    .foregroundColor(LumeColors.textPrimary)
                                    .background(LumeColors.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                focusedField == .day
                                                    ? LumeColors.accentPrimary : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .onChange(of: dayText) { _, newValue in
                                        handleDayChange(newValue)
                                    }
                            }
                            .frame(maxWidth: .infinity)

                            // Month
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MM")
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)

                                TextField("05", text: $monthText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .focused($focusedField, equals: .month)
                                    .frame(height: 48)
                                    .foregroundColor(LumeColors.textPrimary)
                                    .background(LumeColors.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                focusedField == .month
                                                    ? LumeColors.accentPrimary : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .onChange(of: monthText) { _, newValue in
                                        handleMonthChange(newValue)
                                    }
                            }
                            .frame(maxWidth: .infinity)

                            // Year
                            VStack(alignment: .leading, spacing: 4) {
                                Text("YYYY")
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)

                                TextField("1990", text: $yearText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .focused($focusedField, equals: .year)
                                    .frame(height: 48)
                                    .foregroundColor(LumeColors.textPrimary)
                                    .background(LumeColors.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                focusedField == .year
                                                    ? LumeColors.accentPrimary : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .onChange(of: yearText) { _, newValue in
                                        handleYearChange(newValue)
                                    }
                            }
                            .frame(maxWidth: 1.5 * (.infinity))
                        }

                        HStack(spacing: 4) {
                            Image(
                                systemName: isAgeValid && isDateValid
                                    ? "checkmark.circle.fill" : "exclamationmark.circle"
                            )
                            .foregroundColor(
                                isAgeValid && isDateValid
                                    ? LumeColors.moodPositive : LumeColors.moodLow
                            )
                            .font(.system(size: 12))

                            Text(dateValidationMessage)
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                        .padding(.top, 4)
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

                // Register Button
                Button {
                    focusedField = nil
                    Task {
                        await viewModel.register()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(LumeColors.textPrimary)
                        } else {
                            Text("Create Account")
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

                // Privacy Note
                Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
            }
        }
        .background(LumeColors.appBackground)
        .onSubmit {
            if focusedField == .name {
                focusedField = .email
            } else if focusedField == .email {
                focusedField = .password
            } else if focusedField == .password {
                Task {
                    await viewModel.register()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // MARK: - State for date fields
    @State private var dayText: String = ""
    @State private var monthText: String = ""
    @State private var yearText: String = ""

    private var isFormValid: Bool {
        !viewModel.name.isEmpty && !viewModel.email.isEmpty && viewModel.email.contains("@")
            && viewModel.password.count >= 8 && isAgeValid && isDateValid
    }

    private var isDateValid: Bool {
        guard let day = Int(dayText), day >= 1, day <= 31,
            let month = Int(monthText), month >= 1, month <= 12,
            let year = Int(yearText), year >= 1900,
            year <= Calendar.current.component(.year, from: Date())
        else {
            return false
        }

        // Validate actual date (e.g., no Feb 31)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        return Calendar.current.date(from: components) != nil
    }

    private var isAgeValid: Bool {
        guard isDateValid,
            let day = Int(dayText),
            let month = Int(monthText),
            let year = Int(yearText)
        else {
            return false
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        guard let birthDate = Calendar.current.date(from: components) else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()
        guard let age = calendar.dateComponents([.year], from: birthDate, to: now).year else {
            return false
        }

        // Update viewModel dateOfBirth when valid
        if age >= 13 {
            viewModel.dateOfBirth = birthDate
        }

        return age >= 13
    }

    private var dateValidationMessage: String {
        if dayText.isEmpty && monthText.isEmpty && yearText.isEmpty {
            return "Must be at least 13 years old"
        }
        if !isDateValid {
            return "Please enter a valid date"
        }
        if !isAgeValid {
            return "Must be at least 13 years old"
        }
        return "Date looks good!"
    }

    // MARK: - Date field handlers
    private func handleDayChange(_ newValue: String) {
        // Only allow digits
        let filtered = newValue.filter { $0.isNumber }

        // Limit to 2 digits
        if filtered.count > 2 {
            dayText = String(filtered.prefix(2))
        } else {
            dayText = filtered
        }

        // Auto-advance to month after 2 digits
        if dayText.count == 2 {
            focusedField = .month
        }
    }

    private func handleMonthChange(_ newValue: String) {
        // Only allow digits
        let filtered = newValue.filter { $0.isNumber }

        // Limit to 2 digits
        if filtered.count > 2 {
            monthText = String(filtered.prefix(2))
        } else {
            monthText = filtered
        }

        // Auto-advance to year after 2 digits
        if monthText.count == 2 {
            focusedField = .year
        }
    }

    private func handleYearChange(_ newValue: String) {
        // Only allow digits
        let filtered = newValue.filter { $0.isNumber }

        // Limit to 4 digits
        if filtered.count > 4 {
            yearText = String(filtered.prefix(4))
        } else {
            yearText = filtered
        }

        // Dismiss keyboard after 4 digits
        if yearText.count == 4 {
            focusedField = nil
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview
    return RegisterView(
        viewModel: dependencies.makeAuthViewModel()
    )
}
