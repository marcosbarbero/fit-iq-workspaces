//
//  ProfileImageView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI

/// Reusable profile image view for navigation bar icons
/// Displays user's profile picture or default gradient avatar
struct ProfileImageView: View {
    let size: CGFloat
    @State private var profileImageData: Data?

    init(size: CGFloat = 32) {
        self.size = size
    }

    var body: some View {
        if let imageData = profileImageData,
            let uiImage = UIImage(data: imageData)
        {
            // User's profile picture
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .onAppear {
                    loadProfileImage()
                }
                .onReceive(NotificationCenter.default.publisher(for: .profileImageDidChange)) { _ in
                    loadProfileImage()
                }
        } else {
            // Default gradient avatar
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
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundColor(.white.opacity(0.8))
                )
                .onAppear {
                    loadProfileImage()
                }
                .onReceive(NotificationCenter.default.publisher(for: .profileImageDidChange)) { _ in
                    loadProfileImage()
                }
        }
    }

    private func loadProfileImage() {
        profileImageData = ProfileImageManager.shared.loadProfileImage()
    }
}

#Preview {
    HStack(spacing: 20) {
        ProfileImageView(size: 32)
        ProfileImageView(size: 48)
        ProfileImageView(size: 64)
    }
    .padding()
    .background(LumeColors.appBackground)
}
