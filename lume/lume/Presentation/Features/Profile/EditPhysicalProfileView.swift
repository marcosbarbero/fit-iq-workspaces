//
//  EditPhysicalProfileView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI

/// View for editing physical profile attributes
struct EditPhysicalProfileView: View {
    let profile: UserProfile
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var biologicalSex: String
    @State private var heightCm: Double?
    @State private var dateOfBirth: Date?
    @State private var showingDatePicker = false

    // Height input fields
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 6
    @State private var heightCmInput: String = ""

    init(profile: UserProfile, viewModel: ProfileViewModel) {
        self.profile = profile
        self.viewModel = viewModel

        _biologicalSex = State(initialValue: profile.biologicalSex ?? "")
        _heightCm = State(initialValue: profile.heightCm)
        _dateOfBirth = State(initialValue: profile.dateOfBirth)

        // Initialize height inputs
        if let heightCm = profile.heightCm {
            _heightCmInput = State(initialValue: String(format: "%.0f", heightCm))

            if profile.preferredUnitSystem == .imperial {
                let totalInches = heightCm / 2.54
                let feet = Int(totalInches / 12)
                let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
                _heightFeet = State(initialValue: feet)
                _heightInches = State(initialValue: inches)
            }
        }
    }

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Date of Birth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        Button {
                            showingDatePicker = true
                        } label: {
                            HStack {
                                if let dob = dateOfBirth {
                                    Text(formattedDate(dob))
                                        .foregroundColor(LumeColors.textPrimary)
                                } else {
                                    Text("Select date of birth")
                                        .foregroundColor(LumeColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "calendar")
                                    .foregroundColor(LumeColors.textSecondary)
                            }
                            .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                            .padding(16)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                        }

                        if let age = calculateAge(from: dateOfBirth) {
                            Text("Age: \(age)")
                                .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }

                    // Biological Sex
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Biological Sex")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Optional - Used for personalized health insights")
                            .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                            .foregroundColor(LumeColors.textSecondary)

                        Menu {
                            Button {
                                biologicalSex = ""
                            } label: {
                                HStack {
                                    Text("Not specified")
                                    if biologicalSex.isEmpty {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                biologicalSex = "male"
                            } label: {
                                HStack {
                                    Text("Male")
                                    if biologicalSex == "male" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                biologicalSex = "female"
                            } label: {
                                HStack {
                                    Text("Female")
                                    if biologicalSex == "female" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button {
                                biologicalSex = "other"
                            } label: {
                                HStack {
                                    Text("Other")
                                    if biologicalSex == "other" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(
                                    biologicalSex.isEmpty
                                        ? "Not specified" : biologicalSex.capitalized
                                )
                                .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                                .foregroundColor(
                                    biologicalSex.isEmpty
                                        ? LumeColors.textSecondary : LumeColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(LumeColors.textSecondary)
                            }
                            .padding(16)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                        }
                    }

                    // Height
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Height")
                            .font(.custom("SF Pro Rounded", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                            .foregroundColor(LumeColors.textPrimary)

                        if profile.preferredUnitSystem == .imperial {
                            // Imperial units (feet and inches)
                            HStack(spacing: 12) {
                                // Feet
                                VStack(spacing: 4) {
                                    Picker("Feet", selection: $heightFeet) {
                                        ForEach(3...8, id: \.self) { feet in
                                            Text("\(feet) ft")
                                                .tag(feet)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100, height: 120)
                                    .clipped()
                                }
                                .padding(8)
                                .background(LumeColors.surface)
                                .cornerRadius(12)

                                // Inches
                                VStack(spacing: 4) {
                                    Picker("Inches", selection: $heightInches) {
                                        ForEach(0...11, id: \.self) { inches in
                                            Text("\(inches) in")
                                                .tag(inches)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100, height: 120)
                                    .clipped()
                                }
                                .padding(8)
                                .background(LumeColors.surface)
                                .cornerRadius(12)
                            }
                            .onChange(of: heightFeet) { _, _ in
                                updateHeightFromImperial()
                            }
                            .onChange(of: heightInches) { _, _ in
                                updateHeightFromImperial()
                            }
                        } else {
                            // Metric units (cm)
                            HStack {
                                TextField("Height in cm", text: $heightCmInput)
                                    .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                                    .keyboardType(.decimalPad)
                                    .onChange(of: heightCmInput) { _, newValue in
                                        updateHeightFromMetric(newValue)
                                    }

                                Text("cm")
                                    .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                                    .foregroundColor(LumeColors.textSecondary)
                            }
                            .padding(16)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                            .foregroundColor(LumeColors.textPrimary)
                        }

                        if let heightCm = heightCm {
                            Text(heightConversionText(heightCm))
                                .font(.custom("SF Pro Rounded", size: 13, relativeTo: .caption))
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }

                    // Save Button
                    Button {
                        Task {
                            await savePhysicalProfile()
                        }
                    } label: {
                        ZStack {
                            if viewModel.isSavingProfile {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(.custom("SF Pro Rounded", size: 17, relativeTo: .body))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LumeColors.accentSecondary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isSavingProfile)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Physical Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(LumeColors.textSecondary)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker(
                        "Date of Birth",
                        selection: Binding(
                            get: { dateOfBirth ?? Date() },
                            set: { dateOfBirth = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
                .background(LumeColors.appBackground)
                .navigationTitle("Date of Birth")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                        .foregroundColor(LumeColors.accentSecondary)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(LumeColors.appBackground)
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func calculateAge(from date: Date?) -> Int? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
        return ageComponents.year
    }

    private func updateHeightFromImperial() {
        let totalInches = Double(heightFeet * 12 + heightInches)
        heightCm = totalInches * 2.54
    }

    private func updateHeightFromMetric(_ value: String) {
        if let cm = Double(value), cm > 0 {
            heightCm = cm
        } else {
            heightCm = nil
        }
    }

    private func heightConversionText(_ cm: Double) -> String {
        if profile.preferredUnitSystem == .imperial {
            // Show metric conversion
            return String(format: "%.0f cm", cm)
        } else {
            // Show imperial conversion
            let totalInches = cm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)' \(inches)\""
        }
    }

    private func savePhysicalProfile() async {
        await viewModel.updatePhysicalProfile(
            biologicalSex: biologicalSex.isEmpty ? nil : biologicalSex,
            heightCm: heightCm,
            dateOfBirth: dateOfBirth
        )

        // Dismiss on success
        if viewModel.showingSuccess {
            dismiss()
        }
    }
}
