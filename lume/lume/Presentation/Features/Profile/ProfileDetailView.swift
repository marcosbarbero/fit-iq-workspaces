//
//  ProfileDetailView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-30.
//

import PhotosUI
import SwiftUI
import UIKit

/// Main profile view with improved design and local profile picture support
struct ProfileDetailView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditProfile = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLogoutConfirmation = false
    @State private var showingCameraPicker = false
    @State private var showingLibraryPicker = false
    @State private var showingImageSourcePicker = false
    @State private var imageToCrop: IdentifiableImage?
    @State private var showingCameraUnavailableAlert = false

    let dependencies: AppDependencies

    var body: some View {
        mainContent
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingEditProfile) { editProfileSheet }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                successAlertActions
            } message: {
                successAlertMessage
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                errorAlertActions
            } message: {
                errorAlertMessage
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                deleteAlertActions
            } message: {
                deleteAlertMessage
            }
            .alert("Log Out", isPresented: $showingLogoutConfirmation) {
                logoutAlertActions
            } message: {
                logoutAlertMessage
            }
            .sheet(isPresented: $showingImageSourcePicker) { imageSourcePickerSheet }
            .sheet(isPresented: $showingCameraPicker) { cameraPickerSheet }
            .sheet(isPresented: $showingLibraryPicker) { libraryPickerSheet }
            .sheet(item: $imageToCrop) { image in
                imageCropperSheet(for: image)
            }
            .alert("Camera Unavailable", isPresented: $showingCameraUnavailableAlert) {
                cameraUnavailableAlertActions
            } message: {
                cameraUnavailableAlertMessage
            }
            .task {
                await viewModel.loadProfile()
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoadingProfile {
                        loadingView
                    } else if let profile = viewModel.profile {
                        profileContent(profile: profile)
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.refreshAll()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") {
                dismiss()
            }
            .foregroundColor(LumeColors.textPrimary)
            .fontWeight(.medium)
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private var editProfileSheet: some View {
        if let profile = viewModel.profile {
            NavigationStack {
                EditProfileView(profile: profile, viewModel: viewModel)
            }
            .presentationBackground(LumeColors.appBackground)
        }
    }

    @ViewBuilder
    private var imageSourcePickerSheet: some View {
        ImageSourcePickerView(
            onCameraSelected: {
                print("📸 Camera option selected")
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    print("📸 Camera is available, will show camera picker")
                    showingImageSourcePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        print("📸 About to show camera picker")
                        showingCameraPicker = true
                    }
                } else {
                    print("⚠️ Camera is NOT available")
                    showingImageSourcePicker = false
                    showingCameraUnavailableAlert = true
                }
            },
            onPhotoLibrarySelected: {
                print("📸 Photo Library option selected")
                showingImageSourcePicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    print("📸 About to show library picker")
                    showingLibraryPicker = true
                }
            }
        )
        .presentationDetents([.height(200)])
        .presentationBackground(LumeColors.appBackground)
    }

    @ViewBuilder
    private var cameraPickerSheet: some View {
        ImagePickerView(sourceType: .camera) { image in
            print("📸 Image picked from camera")
            print("📸 Image size: \(image.size)")
            print("📸 Image orientation: \(image.imageOrientation.rawValue)")

            showingCameraPicker = false

            // Show cropper after a short delay to ensure clean sheet transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("📸 Setting imageToCrop to show cropper")
                imageToCrop = IdentifiableImage(image: image)
            }
        }
    }

    @ViewBuilder
    private var libraryPickerSheet: some View {
        ImagePickerView(sourceType: .photoLibrary) { image in
            print("📸 Image picked from photo library")
            print("📸 Image size: \(image.size)")
            showingLibraryPicker = false

            // Show cropper after dismissing picker
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("📸 Setting imageToCrop to show cropper")
                imageToCrop = IdentifiableImage(image: image)
            }
        }
    }

    @ViewBuilder
    private func imageCropperSheet(for identifiableImage: IdentifiableImage) -> some View {
        ImageCropperView(image: identifiableImage.image) { croppedImage in
            if let imageData = croppedImage.jpegData(compressionQuality: 0.7) {
                ProfileImageManager.shared.saveProfileImage(imageData)
                NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
            }
            imageToCrop = nil
        }
        .presentationBackground(LumeColors.appBackground)
        .onAppear {
            print("📸 Cropper sheet showing with image: \(identifiableImage.image.size)")
        }
    }

    // MARK: - Alerts

    @ViewBuilder
    private var successAlertActions: some View {
        Button("OK", role: .cancel) {
            viewModel.clearSuccess()
        }
    }

    @ViewBuilder
    private var successAlertMessage: some View {
        if let message = viewModel.successMessage {
            Text(message)
        }
    }

    @ViewBuilder
    private var errorAlertActions: some View {
        Button("OK", role: .cancel) {
            viewModel.clearError()
        }
    }

    @ViewBuilder
    private var errorAlertMessage: some View {
        if let message = viewModel.errorMessage {
            Text(message)
        }
    }

    @ViewBuilder
    private var deleteAlertActions: some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            Task {
                let success = await viewModel.deleteAccount()
                if success {
                    // Account deleted, user session ended
                }
            }
        }
    }

    @ViewBuilder
    private var deleteAlertMessage: some View {
        Text(
            "Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted."
        )
    }

    @ViewBuilder
    private var logoutAlertActions: some View {
        Button("Cancel", role: .cancel) {}
        Button("Log Out", role: .destructive) {
            Task {
                await handleLogout()
            }
        }
    }

    @ViewBuilder
    private var logoutAlertMessage: some View {
        Text("Are you sure you want to log out?")
    }

    @ViewBuilder
    private var cameraUnavailableAlertActions: some View {
        Button("OK", role: .cancel) {}
    }

    @ViewBuilder
    private var cameraUnavailableAlertMessage: some View {
        Text(
            "The camera is not available on this device. Please choose a photo from your library instead."
        )
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(profile: UserProfile) -> some View {
        VStack(spacing: 24) {
            // Profile Picture Section
            profilePictureSection

            // Profile Information Card
            profileInfoCard(profile: profile)

            // Account Actions
            accountActionsCard()
        }
    }

    // MARK: - Profile Picture Section

    @ViewBuilder
    private var profilePictureSection: some View {
        VStack(spacing: 16) {
            // Profile Picture
            ZStack(alignment: .bottomTrailing) {
                if let imageData = ProfileImageManager.shared.loadProfileImage(),
                    let uiImage = UIImage(data: imageData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(LumeColors.surface, lineWidth: 4)
                        )
                        .shadow(
                            color: LumeColors.textPrimary.opacity(0.1),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                } else {
                    // Default avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    LumeColors.accentPrimary,
                                    LumeColors.accentSecondary,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .overlay(
                            Circle()
                                .stroke(LumeColors.surface, lineWidth: 4)
                        )
                        .shadow(
                            color: LumeColors.textPrimary.opacity(0.1),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                }

                // Camera button
                Button {
                    showingImageSourcePicker = true
                } label: {
                    Circle()
                        .fill(LumeColors.accentPrimary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(LumeColors.textPrimary)
                        )
                        .shadow(
                            color: LumeColors.textPrimary.opacity(0.15),
                            radius: 8,
                            x: 0,
                            y: 2
                        )
                }
                .offset(x: -4, y: -4)
            }
        }
    }

    // MARK: - Profile Info Card

    @ViewBuilder
    private func profileInfoCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card Header with Edit Button
            HStack {
                Text("Personal Information")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingEditProfile = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                        Text("Edit")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LumeColors.accentPrimary)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(LumeColors.appBackground)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                // Name
                infoRow(
                    label: "Name",
                    value: profile.name,
                    icon: "person.fill"
                )

                Divider()
                    .background(LumeColors.appBackground.opacity(0.5))
                    .padding(.leading, 56)

                // Email
                if let email = UserSession.shared.currentUserEmail {
                    infoRow(
                        label: "Email",
                        value: email,
                        icon: "envelope.fill"
                    )
                }

                Divider()
                    .background(LumeColors.appBackground.opacity(0.5))
                    .padding(.leading, 56)

                // Date of Birth
                if let dob = profile.dateOfBirth {
                    infoRow(
                        label: "Date of Birth",
                        value: formattedDate(dob),
                        icon: "calendar"
                    )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(LumeColors.surface)
        .cornerRadius(16)
        .shadow(
            color: LumeColors.textPrimary.opacity(0.06),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    // MARK: - Account Actions Card

    @ViewBuilder
    private func accountActionsCard() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Actions")
                .font(LumeTypography.titleMedium)
                .foregroundColor(LumeColors.textPrimary)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .background(LumeColors.appBackground)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                // Log Out Button
                Button {
                    showingLogoutConfirmation = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20))
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(width: 24)

                        Text("Log Out")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(LumeColors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }

                Divider()
                    .background(LumeColors.appBackground.opacity(0.5))
                    .padding(.leading, 60)

                // Delete Account Button
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 24)

                        Text("Delete Account")
                            .font(LumeTypography.body)
                            .foregroundColor(.red)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(LumeColors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .background(LumeColors.surface)
        .cornerRadius(16)
        .shadow(
            color: LumeColors.textPrimary.opacity(0.06),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    // MARK: - Info Row

    @ViewBuilder
    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(LumeColors.accentPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary)

                Text(value)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(LumeColors.accentPrimary)

            Text("Loading profile...")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundColor(LumeColors.textSecondary)

            VStack(spacing: 8) {
                Text("Profile Not Found")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                Text("Unable to load your profile information")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await viewModel.loadProfile()
                }
            } label: {
                Text("Try Again")
                    .font(LumeTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(LumeColors.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LumeColors.accentPrimary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Helper Methods

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatHeight(_ heightCm: Double, unitSystem: UnitSystem, profile: UserProfile)
        -> String
    {
        if unitSystem == .imperial {
            let totalInches = heightCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        } else {
            return String(format: "%.0f cm", heightCm)
        }
    }

    private func handleLogout() async {
        do {
            try await dependencies.tokenStorage.deleteToken()
            try? await dependencies.userProfileRepository.clearCache()
            UserSession.shared.endSession()
            print("✅ [ProfileDetailView] User logged out successfully")
        } catch {
            viewModel.errorMessage = "Failed to log out: \(error.localizedDescription)"
            viewModel.showingError = true
            print("❌ [ProfileDetailView] Logout failed: \(error)")
        }
    }
}

// MARK: - ProfileImageManager

class ProfileImageManager {
    static let shared = ProfileImageManager()

    private let imageFileName = "profileImage.jpg"
    private let oldUserDefaultsKey = "lume.profile.image"
    private let migrationCompletedKey = "lume.profile.migration.completed"

    private var imageFileURL: URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(imageFileName)
    }

    private init() {
        migrateFromUserDefaultsIfNeeded()
    }

    /// Migrate old UserDefaults storage to file system
    private func migrateFromUserDefaultsIfNeeded() {
        // Check if migration already completed
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
            return
        }

        // Check if old data exists in UserDefaults
        if let oldImageData = UserDefaults.standard.data(forKey: oldUserDefaultsKey) {
            // Try to save to file system
            do {
                try oldImageData.write(to: imageFileURL, options: [.atomic])
                print("✅ Successfully migrated profile image to file system")
            } catch {
                print("⚠️ Failed to migrate profile image: \(error.localizedDescription)")
            }

            // Clean up old data regardless of success
            UserDefaults.standard.removeObject(forKey: oldUserDefaultsKey)
        }

        // Also clean up the old "profileImage" key if it exists
        UserDefaults.standard.removeObject(forKey: "profileImage")

        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        print("✅ Profile image migration completed")
    }

    func saveProfileImage(_ imageData: Data) {
        do {
            try imageData.write(to: imageFileURL, options: [.atomic])
            NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
        } catch {
            print("❌ Error saving profile image: \(error.localizedDescription)")
        }
    }

    func loadProfileImage() -> Data? {
        guard FileManager.default.fileExists(atPath: imageFileURL.path) else {
            return nil
        }
        return try? Data(contentsOf: imageFileURL)
    }

    func deleteProfileImage() {
        try? FileManager.default.removeItem(at: imageFileURL)
        NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
    }
}

extension Notification.Name {
    static let profileImageDidChange = Notification.Name("profileImageDidChange")
}

// MARK: - Identifiable Image Wrapper

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - UIImage Extension (Removed mirroring - keep images as-is)

// MARK: - Image Source Picker

struct ImageSourcePickerView: View {
    let onCameraSelected: () -> Void
    let onPhotoLibrarySelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isCameraAvailable {
                Button {
                    dismiss()
                    onCameraSelected()
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(LumeColors.textPrimary)
                        Text("Take Photo")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textPrimary)
                        Spacer()
                    }
                    .padding()
                    .background(LumeColors.surface)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top)
            }

            Button {
                dismiss()
                onPhotoLibrarySelected()
            } label: {
                HStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20))
                        .foregroundColor(LumeColors.textPrimary)
                    Text("Choose from Library")
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)
                    Spacer()
                }
                .padding()
                .background(LumeColors.surface)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, isCameraAvailable ? 8 : 20)

            Spacer()
        }
        .background(LumeColors.appBackground)
    }
}

// MARK: - UIImagePickerController Wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        print(
            "📸 [ImagePickerView] Created picker with source type: \(sourceType == .camera ? "Camera" : "Photo Library")"
        )
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Ensure source type is correct even if view updates
        if uiViewController.sourceType != sourceType {
            print(
                "📸 [ImagePickerView] Updating source type from \(uiViewController.sourceType == .camera ? "Camera" : "Photo Library") to \(sourceType == .camera ? "Camera" : "Photo Library")"
            )
            uiViewController.sourceType = sourceType
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            print(
                "📸 [ImagePickerView] Image picked successfully from \(picker.sourceType == .camera ? "Camera" : "Photo Library")"
            )
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image Cropper

struct ImageCropperView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                VStack {
                    Text("Adjust Your Photo")
                        .font(LumeTypography.titleMedium)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.top, 20)

                    Text("Pinch to zoom, drag to reposition")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textSecondary)
                        .padding(.bottom, 20)

                    // Crop area
                    GeometryReader { geometry in
                        let size = min(geometry.size.width, geometry.size.height) - 40

                        ZStack {
                            // Image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(scale)
                                .offset(offset)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, 1.0), 5.0)
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                            },
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                offset = CGSize(
                                                    width: lastOffset.width
                                                        + value.translation.width,
                                                    height: lastOffset.height
                                                        + value.translation.height
                                                )
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                                )

                            // Crop circle overlay
                            Circle()
                                .stroke(LumeColors.accentPrimary, lineWidth: 3)
                                .frame(width: size, height: size)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func cropImage() {
        let size: CGFloat = 300  // Output size (smaller for better storage)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        let croppedImage = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)

            // Create circular clipping path
            UIBezierPath(ovalIn: rect).addClip()

            // Calculate the image drawing rect
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height
            var drawRect: CGRect

            if aspectRatio > 1 {
                // Landscape
                let drawHeight = size * scale
                let drawWidth = drawHeight * aspectRatio
                drawRect = CGRect(
                    x: (size - drawWidth) / 2 + offset.width,
                    y: (size - drawHeight) / 2 + offset.height,
                    width: drawWidth,
                    height: drawHeight
                )
            } else {
                // Portrait or square
                let drawWidth = size * scale
                let drawHeight = drawWidth / aspectRatio
                drawRect = CGRect(
                    x: (size - drawWidth) / 2 + offset.width,
                    y: (size - drawHeight) / 2 + offset.height,
                    width: drawWidth,
                    height: drawHeight
                )
            }

            image.draw(in: drawRect)
        }

        onCropped(croppedImage)
        dismiss()
    }
}

// MARK: - FlowLayout Helper

/// FlowLayout is defined in JournalEntryView.swift and reused here

#Preview {
    let dependencies = AppDependencies.preview
    let viewModel = dependencies.makeProfileViewModel()

    return NavigationStack {
        ProfileDetailView(
            viewModel: viewModel,
            dependencies: dependencies
        )
    }
}
