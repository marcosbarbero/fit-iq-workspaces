//
//  SyncComponents.swift
//  lume
//
//  Created by Lume Team on 2025-01-15.
//

import SwiftUI

// MARK: - Sync Explanation Sheet

struct SyncExplanationSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero section
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#F2C9A7").opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: "cloud.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "#F2C9A7"))
                        }
                        .padding(.top, 8)

                        Text("Your Entries Are Safe")
                            .font(LumeTypography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(LumeColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("We automatically backup your journal to the cloud")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    Divider()
                        .padding(.horizontal, 20)

                    // Benefits
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Why This Matters")
                            .font(LumeTypography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .padding(.horizontal, 20)

                        BenefitRow(
                            icon: "ipad.landscape.and.iphone",
                            title: "Access Anywhere",
                            description: "Your entries are available on all your devices"
                        )

                        BenefitRow(
                            icon: "lock.shield.fill",
                            title: "Never Lose Data",
                            description: "Even if you lose your phone, your journal is safe"
                        )

                        BenefitRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Always Up to Date",
                            description: "Changes sync automatically in the background"
                        )
                    }

                    Divider()
                        .padding(.horizontal, 20)

                    // Status indicators
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Status Indicators")
                            .font(LumeTypography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .padding(.horizontal, 20)

                        StatusIndicatorRow(
                            icon: "arrow.clockwise",
                            color: LumeColors.textSecondary,
                            title: "Syncing",
                            description: "Your entry is being backed up (takes ~10 seconds)"
                        )

                        StatusIndicatorRow(
                            icon: "checkmark.circle.fill",
                            color: Color(hex: "#059669"),
                            title: "Synced",
                            description: "Your entry is safely stored in the cloud"
                        )
                    }

                    // Reassurance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You Don't Need to Do Anything")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text(
                            "Sync happens automatically in the background. Just write, and we'll take care of keeping your entries safe."
                        )
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#F2C9A7").opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(LumeColors.appBackground)
            .navigationTitle("About Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "#F2C9A7"))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)

                Text(description)
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct StatusIndicatorRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)

                Text(description)
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Previews

#Preview("Sync Explanation Sheet") {
    SyncExplanationSheet()
}

#Preview("Benefit Row") {
    VStack(spacing: 16) {
        BenefitRow(
            icon: "ipad.landscape.and.iphone",
            title: "Access Anywhere",
            description: "Your entries are available on all your devices"
        )

        BenefitRow(
            icon: "lock.shield.fill",
            title: "Never Lose Data",
            description: "Even if you lose your phone, your journal is safe"
        )
    }
    .padding()
    .background(LumeColors.appBackground)
}

#Preview("Status Indicator Row") {
    VStack(spacing: 16) {
        StatusIndicatorRow(
            icon: "arrow.clockwise",
            color: LumeColors.textSecondary,
            title: "Syncing",
            description: "Your entry is being backed up (takes ~10 seconds)"
        )

        StatusIndicatorRow(
            icon: "checkmark.circle.fill",
            color: Color(hex: "#059669"),
            title: "Synced",
            description: "Your entry is safely stored in the cloud"
        )
    }
    .padding()
    .background(LumeColors.appBackground)
}
