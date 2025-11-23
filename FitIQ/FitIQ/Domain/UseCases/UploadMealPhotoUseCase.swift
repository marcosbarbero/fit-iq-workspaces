//
//  UploadMealPhotoUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Use case for uploading meal photos for AI recognition
//

import Foundation
import UIKit

// MARK: - Protocol

/// Use case for uploading meal photo and starting AI recognition
protocol UploadMealPhotoUseCase {
    /// Upload a meal photo for AI recognition
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - mealType: Type of meal (breakfast, lunch, dinner, snack)
    ///   - loggedAt: When the meal was consumed (defaults to now)
    ///   - notes: Optional user notes about the meal
    /// - Returns: The photo recognition entry with initial status
    func execute(
        image: UIImage,
        mealType: MealType,
        loggedAt: Date,
        notes: String?
    ) async throws -> PhotoRecognition
}

// MARK: - Implementation

final class UploadMealPhotoUseCaseImpl: UploadMealPhotoUseCase {

    // MARK: - Dependencies

    private let photoRecognitionAPI: PhotoRecognitionAPIProtocol
    private let photoRecognitionRepository: PhotoRecognitionRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Constants

    private let maxImageSizeBytes = 20 * 1024 * 1024  // 20MB (backend limit)
    private let targetImageSizeBytes = 750 * 1024  // 750KB target (leaves room for multipart form overhead)
    private let maxImageDimension: CGFloat = 2048  // Max width/height
    private let compressionQuality: CGFloat = 0.7

    // MARK: - Initialization

    init(
        photoRecognitionAPI: PhotoRecognitionAPIProtocol,
        photoRecognitionRepository: PhotoRecognitionRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.photoRecognitionAPI = photoRecognitionAPI
        self.photoRecognitionRepository = photoRecognitionRepository
        self.authManager = authManager
    }

    // MARK: - UploadMealPhotoUseCase Implementation

    func execute(
        image: UIImage,
        mealType: MealType,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) async throws -> PhotoRecognition {
        print("UploadMealPhotoUseCase: Starting photo upload")
        print("UploadMealPhotoUseCase: Meal type: \(mealType.rawValue)")

        // 1. Validate user authentication
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("UploadMealPhotoUseCase: ❌ User not authenticated")
            throw UploadMealPhotoError.userNotAuthenticated
        }

        // 2. Aggressively compress image to under 1MB
        var workingImage = image
        var currentDimension = maxImageDimension
        var imageData: Data?
        var currentQuality: CGFloat = 1.0

        // Try progressively smaller dimensions and quality settings
        let dimensionSteps: [CGFloat] = [2048, 1536, 1024, 768]

        for dimension in dimensionSteps {
            currentDimension = dimension
            workingImage = resizeImageToMaxDimension(image, maxDimension: dimension)

            // Try at full quality first
            imageData = workingImage.jpegData(compressionQuality: 1.0)

            guard let data = imageData else {
                print("UploadMealPhotoUseCase: ❌ Failed to convert image to JPEG")
                throw UploadMealPhotoError.imageProcessingFailed
            }

            // If already under 750KB at this dimension, we're done
            if data.count <= targetImageSizeBytes {
                print(
                    "UploadMealPhotoUseCase: Image is \(data.count / 1024) KB at \(Int(dimension))px (quality: 100%), under 750KB target ✅"
                )
                currentQuality = 1.0
                imageData = data
                break
            }

            // Try compression at this dimension
            currentQuality = compressionQuality
            imageData = workingImage.jpegData(compressionQuality: currentQuality)

            while let data = imageData, data.count > targetImageSizeBytes && currentQuality > 0.3 {
                currentQuality -= 0.1
                imageData = workingImage.jpegData(compressionQuality: currentQuality)
            }

            // Check if we got under 750KB
            if let data = imageData, data.count <= targetImageSizeBytes {
                print(
                    "UploadMealPhotoUseCase: Compressed to \(data.count / 1024) KB at \(Int(dimension))px (quality: \(Int(currentQuality * 100))%) ✅"
                )
                break
            }

            // Continue to next smaller dimension
            print(
                "UploadMealPhotoUseCase: Still \(imageData?.count ?? 0 / 1024) KB at \(Int(dimension))px, trying smaller dimension..."
            )
        }

        // 3. Validate we got under 1MB
        guard let finalImageData = imageData else {
            print("UploadMealPhotoUseCase: ❌ Failed to process image")
            throw UploadMealPhotoError.imageProcessingFailed
        }

        let imageSizeBytes = finalImageData.count
        let imageSizeKB = imageSizeBytes / 1024

        if imageSizeBytes > targetImageSizeBytes {
            print(
                "UploadMealPhotoUseCase: ❌ Could not reduce image below 750KB (final: \(imageSizeKB) KB at \(Int(currentDimension))px, quality: \(Int(currentQuality * 100))%)"
            )
            throw UploadMealPhotoError.imageTooLarge
        }

        print(
            "UploadMealPhotoUseCase: ✅ Final image: \(imageSizeKB) KB at \(Int(currentDimension))px (quality: \(Int(currentQuality * 100))%)"
        )

        // 4. Convert to base64
        let base64String = finalImageData.base64EncodedString()
        print("UploadMealPhotoUseCase: Base64 encoded, length: \(base64String.count)")

        // 5. Upload to backend
        do {
            let photoRecognition = try await photoRecognitionAPI.uploadPhoto(
                imageData: base64String,
                mealType: mealType.rawValue,
                loggedAt: loggedAt,
                notes: notes
            )

            print(
                "UploadMealPhotoUseCase: ✅ Photo uploaded successfully - ID: \(photoRecognition.id)"
            )
            print("UploadMealPhotoUseCase: Status: \(photoRecognition.status.rawValue)")

            // 8. Save to local repository
            let saved = try await photoRecognitionRepository.save(photoRecognition)

            print("UploadMealPhotoUseCase: ✅ Photo recognition saved to local repository")

            return saved

        } catch let error as PhotoRecognitionAPIError {
            print("UploadMealPhotoUseCase: ❌ API error: \(error.localizedDescription)")
            throw UploadMealPhotoError.uploadFailed(error)
        } catch {
            print("UploadMealPhotoUseCase: ❌ Unexpected error: \(error)")
            throw UploadMealPhotoError.unknownError(error)
        }
    }

    // MARK: - Private Helpers

    /// Resize image to max dimension, maintaining aspect ratio
    private func resizeImageToMaxDimension(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resizing is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
        }

        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }
}

// MARK: - Errors

enum UploadMealPhotoError: Error, LocalizedError {
    case userNotAuthenticated
    case imageProcessingFailed
    case imageTooLarge
    case uploadFailed(PhotoRecognitionAPIError)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .imageTooLarge:
            return
                "Image size exceeds 750KB limit even after compression. Please try a smaller or less detailed image."
        case .uploadFailed(let apiError):
            return "Upload failed: \(apiError.localizedDescription)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
