//
//  PhysicalProfileViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import Observation

@Observable
final class PhysicalProfileViewModel {
    // MARK: - State

    var physicalProfile: PhysicalProfile?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let getPhysicalProfileUseCase: GetPhysicalProfileUseCase
    private let updatePhysicalProfileUseCase: UpdatePhysicalProfileUseCase

    // MARK: - Initialization

    init(
        getPhysicalProfileUseCase: GetPhysicalProfileUseCase,
        updatePhysicalProfileUseCase: UpdatePhysicalProfileUseCase
    ) {
        self.getPhysicalProfileUseCase = getPhysicalProfileUseCase
        self.updatePhysicalProfileUseCase = updatePhysicalProfileUseCase
    }

    // MARK: - Actions

    @MainActor
    func loadPhysicalProfile(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            physicalProfile = try await getPhysicalProfileUseCase.execute(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func updatePhysicalProfile(
        userId: String,
        heightCm: Double? = nil,
        dateOfBirth: Date? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            physicalProfile = try await updatePhysicalProfileUseCase.execute(
                userId: userId,
                heightCm: heightCm,
                dateOfBirth: dateOfBirth
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
