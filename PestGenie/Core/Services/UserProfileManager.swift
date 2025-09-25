import Foundation
import SwiftUI

/// Simplified user profile manager for basic functionality
@MainActor
final class UserProfileManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentProfile: UserProfile?
    @Published var isLoading = false
    @Published var syncStatus = "idle"

    // MARK: - Initialization

    init() {
        // Simple initialization
    }

    // MARK: - User Profile Management

    func createUser(from googleUser: GoogleUser) async throws -> AuthenticatedUser {
        isLoading = true
        defer { isLoading = false }

        let profile = UserProfile(
            id: googleUser.id,
            email: googleUser.email,
            name: googleUser.name,
            profileImageURL: googleUser.profileImageURL,
            customProfileImageData: nil,
            createdAt: Date(),
            updatedAt: nil,
            lastSyncDate: Date(),
            preferences: UserPreferences(),
            workInfo: WorkInformation(certifications: []),
            profileCompleteness: ProfileCompleteness(score: 0.4, missingFields: [], lastCalculated: Date()),
            version: 1,
            isDirty: false,
            conflictResolutionData: nil
        )

        currentProfile = profile

        return AuthenticatedUser(
            id: profile.id,
            email: profile.email,
            name: profile.name,
            profileImageURL: profile.profileImageURL,
            createdAt: profile.createdAt,
            lastSignInAt: Date()
        )
    }

    func updateProfile(_ updates: UserProfileUpdate) async throws {
        guard var profile = currentProfile else {
            throw UserProfileError.noCurrentProfile
        }

        isLoading = true
        defer { isLoading = false }

        // Apply updates
        if let name = updates.name {
            profile.name = name
        }

        if let preferences = updates.preferences {
            profile.preferences = preferences
        }

        if let workInfo = updates.workInfo {
            profile.workInfo = workInfo
        }

        if let imageData = updates.customProfileImage {
            profile.customProfileImageData = imageData
        }

        if updates.removeCustomImage {
            profile.customProfileImageData = nil
        }

        profile.updatedAt = Date()

        // Store updated profile
        currentProfile = profile
    }

    func loadUserProfile(for userId: String) async -> UserProfile? {
        // Simplified - return current profile if ID matches
        if currentProfile?.id == userId {
            return currentProfile
        }
        return nil
    }

    func clearUserData() async {
        currentProfile = nil
        syncStatus = "idle"
    }
}