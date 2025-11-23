//
//  ProfileView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import FitIQCore
import Foundation
import SwiftUI

struct ProfileView: View {
    // Dependencies injected from RootTabView/Environment
    @ObservedObject var viewModel: ProfileViewModel

    // State to handle confirmation modal before logout
    @State private var showingLogoutAlert = false
    @State private var showingDeleteiCloudDataAlert = false  // NEW: State for iCloud data deletion confirmation
    @State private var showingEditSheet = false
    @State private var showingAppSettingsSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 2)
                Text("Account")
                    .font(.headline)
                Spacer()

                profileHeaderView
                settingsOptionsView
                physicalProfileDataView
                deleteDataButton
                logoutButton

                Spacer()
            }
            .padding(.top, 10)
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Confirm Logout", isPresented: $showingLogoutAlert) {
            Button("Log Out", role: .destructive) {
                viewModel.logout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out of FitIQ?")
        }
        .alert("Delete All Data", isPresented: $showingDeleteiCloudDataAlert) {
            Button("Delete All Data", role: .destructive) {
                Task {
                    await viewModel.deleteiCloudData()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will permanently delete ALL your FitIQ data from the server and this device. This action cannot be undone. Are you sure you want to proceed?"
            )
        }
        .overlay {
            if viewModel.isDeletingCloudData {
                ProgressView("Deleting data...")
                    .padding()
                    .background(.ultraThickMaterial)
                    .cornerRadius(10)
            }
        }
        .alert(
            "Deletion Failed",
            isPresented: Binding<Bool>(
                get: { viewModel.deletionError != nil },
                set: { _ in viewModel.deletionError = nil }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(
                "Failed to delete iCloud data: \(viewModel.deletionError?.localizedDescription ?? "An unknown error occurred"). Please try again."
            )
        }
        .task {
            await viewModel.fetchLatestHealthMetrics()
            await viewModel.loadUserProfile()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProfileSheet(viewModel: viewModel, isPresented: $showingEditSheet)
        }
        .onChange(of: showingEditSheet) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task {
                    await viewModel.loadUserProfile()
                }
            }
        }
        .sheet(isPresented: $showingAppSettingsSheet) {
            AppSettingsView(viewModel: viewModel)
        }
        .onChange(of: showingAppSettingsSheet) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task {
                    await viewModel.loadUserProfile()
                }
            }
        }
    }

    // MARK: - Subviews

    private var profileHeaderView: some View {
        VStack(spacing: 15) {
            Image("ProfileImage")
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())

            Text(viewModel.name)
                .font(.title2)
                .fontWeight(.bold)

            if let email = viewModel.userProfile?.email {
                Text(email)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var settingsOptionsView: some View {
        VStack(spacing: 1) {
            SettingRow(icon: "gear", title: "App Settings", color: .gray) {
                showingAppSettingsSheet = true
            }
            SettingRow(
                icon: "person.fill", title: "Edit Profile",
                color: .vitalityTeal
            ) {
                showingEditSheet = true
            }
            SettingRow(
                icon: "lock.shield.fill", title: "Privacy & Security", color: .ascendBlue
            ) {}

            healthKitPermissionsButton
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var healthKitPermissionsButton: some View {
        Button {
            Task {
                await viewModel.reauthorizeHealthKit()
            }
        } label: {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update HealthKit Permissions")
                        .font(.body)
                        .foregroundColor(.primary)

                    if viewModel.isReauthorizingHealthKit {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let message = viewModel.reauthorizationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.hasPrefix("✅") ? .green : .red)
                    } else {
                        Text("Grant access to workout effort scores")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.tertiarySystemBackground))
        }
        .disabled(viewModel.isReauthorizingHealthKit)
    }

    private var physicalProfileDataView: some View {
        VStack(spacing: 1) {
            weightRow
            dateOfBirthRow
            heightRow
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var weightRow: some View {
        SettingRow(
            icon: "scalemass.fill",
            title: viewModel.bodyMetrics?.weightKg.map { String(format: "%.1f kg", $0) }
                ?? "Weight (N/A)", color: .gray
        ) {}
    }

    private var dateOfBirthRow: some View {
        Group {
            if let dob = viewModel.userProfile?.dateOfBirth {
                let dobFormatted = DateFormatHelper.formatMediumDate(dob)
                SettingRow(icon: "calendar", title: dobFormatted, color: .gray) {}
            } else {
                SettingRow(icon: "calendar", title: "Date of Birth (N/A)", color: .gray) {}
            }
        }
    }

    private var heightRow: some View {
        Group {
            if let heightCm = viewModel.userProfile?.heightCm {
                SettingRow(
                    icon: "ruler",
                    title: String(format: "%.0f cm", heightCm),
                    color: .gray
                ) {}
            } else {
                SettingRow(icon: "ruler", title: "Height (N/A)", color: .gray) {}
            }
        }
    }

    private var deleteDataButton: some View {
        Button {
            showingDeleteiCloudDataAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.circle.fill")
                Text("Delete All Data")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.alertRed)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
        .disabled(viewModel.isDeletingCloudData)
    }

    private var logoutButton: some View {
        Button {
            showingLogoutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Log Out")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.alertRed)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground).opacity(0.3),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.vitalityTeal, .ascendBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, 20)

                            Text("Edit Your Profile")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Update your personal information")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)

                        // Personal Information Card
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(
                                icon: "person.fill",
                                title: "Personal Information",
                                color: .vitalityTeal
                            )

                            ModernTextField(
                                icon: "person",
                                placeholder: "Full Name",
                                text: $viewModel.name
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "text.alignleft")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)

                                    Text("Bio")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }

                                TextEditor(text: $viewModel.bio)
                                    .frame(minHeight: 80, maxHeight: 120)
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                UIApplication.shared.sendAction(
                                                    #selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                                            }
                                            .foregroundColor(.ascendBlue)
                                        }
                                    }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)

                                    Text("Date of Birth")
                                        .foregroundColor(.secondary)
                                        .font(.caption)

                                    Spacer()
                                }

                                DatePicker(
                                    "",
                                    selection: $viewModel.dateOfBirth,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .tint(.ascendBlue)

                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color(.separator))
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                        // Physical Profile Card
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(
                                icon: "figure.walk",
                                title: "Physical Profile",
                                color: .ascendBlue
                            )

                            ModernTextField(
                                icon: "arrow.up.arrow.down",
                                placeholder: "Height (cm)",
                                text: $viewModel.heightCm,
                                keyboardType: .decimalPad
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                ModernPicker(
                                    icon: "person.2",
                                    label: "Biological Sex",
                                    selection: $viewModel.biologicalSex,
                                    options: [
                                        ("", "Not set"),
                                        ("male", "Male"),
                                        ("female", "Female"),
                                        ("other", "Other"),
                                    ]
                                )
                                .disabled(true)

                                HStack(spacing: 4) {
                                    Image(systemName: "heart.text.square.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Managed by Apple Health")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 28)
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                        // Status Message
                        if let message = viewModel.profileUpdateMessage {
                            HStack(spacing: 12) {
                                Image(
                                    systemName: message.contains("success")
                                        ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                                )
                                .foregroundColor(message.contains("success") ? .green : .red)

                                Text(message)
                                    .font(.callout)
                                    .foregroundColor(message.contains("success") ? .green : .red)

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                (message.contains("success") ? Color.green : Color.red)
                                    .opacity(0.1)
                            )
                            .cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Save Button
                        Button {
                            Task {
                                await viewModel.saveProfile()
                                if viewModel.profileUpdateMessage?.contains("success") == true {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        isPresented = false
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isSavingProfile {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(viewModel.isSavingProfile ? "Saving..." : "Save Changes")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: viewModel.name.isEmpty || viewModel.isSavingProfile
                                        ? [.gray, .gray.opacity(0.8)]
                                        : [.vitalityTeal, .ascendBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isSavingProfile || viewModel.name.isEmpty)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("Cancel")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                    }
                    .disabled(viewModel.isSavingProfile)
                }
            }
            .onAppear {
                // Populate form fields when sheet opens
                // This also reloads HealthKit data if fields are empty
                Task {
                    await viewModel.startEditing()
                }
            }
        }
    }
}

// MARK: - Modern UI Components

struct SectionHeaderView: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct ModernTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.plain)
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct ModernPicker: View {
    let icon: String
    let label: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.caption)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Picker(label, selection: $selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - Helper Views

struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())  // Ensure the whole row is tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}
