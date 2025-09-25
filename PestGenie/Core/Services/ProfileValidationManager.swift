import Foundation
import UIKit

/// Simplified profile validation for basic functionality
final class ProfileValidationManager {

    // MARK: - Validation Rules Configuration

    static let shared = ProfileValidationManager()

    private let nameMinLength = 2
    private let nameMaxLength = 100

    private init() {}

    // MARK: - Profile Validation

    func validateProfile(_ profile: UserProfile) -> String? {
        // Basic email validation
        if profile.email.isEmpty {
            return "Email is required"
        }

        if !profile.email.contains("@") {
            return "Invalid email format"
        }

        // Basic name validation
        if let name = profile.name {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).count < nameMinLength {
                return "Name is too short (minimum \(nameMinLength) characters)"
            }
        } else {
            return "Name is required"
        }

        return nil // Valid
    }

    func validateProfileUpdate(_ update: UserProfileUpdate, currentProfile: UserProfile) -> String? {
        // Validate name if provided
        if let name = update.name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                return "Name cannot be empty"
            }
            if trimmedName.count < nameMinLength {
                return "Name is too short (minimum \(nameMinLength) characters)"
            }
            if trimmedName.count > nameMaxLength {
                return "Name is too long (maximum \(nameMaxLength) characters)"
            }
        }

        // Validate custom image if provided
        if let imageData = update.customProfileImage {
            let maxSize = 5 * 1024 * 1024 // 5MB
            if imageData.count > maxSize {
                return "Image file is too large (maximum 5MB)"
            }

            if UIImage(data: imageData) == nil {
                return "Invalid image format"
            }
        }

        // Check for conflicting image operations
        if update.customProfileImage != nil && update.removeCustomImage {
            return "Cannot add and remove profile image simultaneously"
        }

        return nil // Valid
    }

}