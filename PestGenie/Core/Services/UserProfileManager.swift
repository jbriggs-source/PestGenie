import Foundation
import SwiftUI

/// Manages user profile data and integrates with existing privacy compliance
final class UserProfileManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentProfile: UserProfile?

    // MARK: - Dependencies

    private let complianceManager = AppStoreComplianceManager.shared

    // MARK: - User Profile Management

    func createUser(from googleUser: GoogleUser) async throws -> AuthenticatedUser {
        let profile = UserProfile(
            id: googleUser.id,
            email: googleUser.email,
            name: googleUser.name,
            profileImageURL: googleUser.profileImageURL,
            createdAt: Date(),
            preferences: UserPreferences()
        )

        // Store profile data
        await storeUserProfile(profile)

        // Update existing privacy settings with Google account info
        await updatePrivacySettings(with: googleUser)

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

        // Apply updates
        if let name = updates.name {
            profile.name = name
        }

        if let preferences = updates.preferences {
            profile.preferences = preferences
        }

        profile.updatedAt = Date()

        // Store updated profile
        await storeUserProfile(profile)
        currentProfile = profile

        await logProfileEvent(.profileUpdated(profile.id))
    }

    func loadUserProfile(for userId: String) async -> UserProfile? {
        return getStoredProfile(for: userId)
    }

    func clearUserData() async {
        guard let profile = currentProfile else { return }

        // Clear stored profile
        clearStoredProfile(for: profile.id)

        // Clear cached profile image
        await clearProfileImageCache(for: profile.id)

        await logProfileEvent(.profileCleared(profile.id))

        currentProfile = nil
    }

    // MARK: - Privacy Integration

    @MainActor
    private func updatePrivacySettings(with googleUser: GoogleUser) {
        var privacySettings = complianceManager.privacySettings

        // Update email and user info
        privacySettings.userEmail = googleUser.email
        privacySettings.userId = googleUser.id

        // Add Google-specific privacy preferences
        privacySettings.dataProcessingPreferences["googleSignIn"] = true
        privacySettings.dataProcessingPreferences["profileData"] = true

        // Update consent status
        privacySettings.hasConsentedToDataUsage = true

        complianceManager.privacySettings = privacySettings
    }

    func exportUserProfileData() -> UserProfileExport {
        guard let profile = currentProfile else {
            return UserProfileExport.empty()
        }

        return UserProfileExport(
            id: profile.id,
            email: profile.email,
            name: profile.name,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
            preferences: profile.preferences,
            exportDate: Date()
        )
    }

    // MARK: - Profile Image Management

    func downloadProfileImage() async -> UIImage? {
        guard let profile = currentProfile,
              let imageURL = profile.profileImageURL else { return nil }

        // Check cache first
        if let cachedImage = getCachedProfileImage(for: profile.id) {
            return cachedImage
        }

        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: data) else { return nil }

            // Cache the image
            await cacheProfileImage(image, for: profile.id)

            return image
        } catch {
            await logProfileEvent(.profileImageDownloadFailed(profile.id, error.localizedDescription))
            return nil
        }
    }

    // MARK: - Storage

    private func storeUserProfile(_ profile: UserProfile) async {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: "userProfile_\(profile.id)")
    }

    private func getStoredProfile(for userId: String) -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "userProfile_\(userId)"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    private func clearStoredProfile(for userId: String) {
        UserDefaults.standard.removeObject(forKey: "userProfile_\(userId)")
    }

    // MARK: - Profile Image Caching

    private func getCachedProfileImage(for userId: String) -> UIImage? {
        let cacheURL = getProfileImageCacheURL(for: userId)
        guard let imageData = try? Data(contentsOf: cacheURL) else { return nil }
        return UIImage(data: imageData)
    }

    private func cacheProfileImage(_ image: UIImage, for userId: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let cacheURL = getProfileImageCacheURL(for: userId)

        do {
            try imageData.write(to: cacheURL)
        } catch {
            await logProfileEvent(.profileImageCacheFailed(userId, error.localizedDescription))
        }
    }

    private func clearProfileImageCache(for userId: String) async {
        let cacheURL = getProfileImageCacheURL(for: userId)
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private func getProfileImageCacheURL(for userId: String) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("profile_\(userId).jpg")
    }

    // MARK: - Logging

    private func logProfileEvent(_ event: UserProfileEvent) async {
        let securityEvent = convertProfileEventToSecurityEvent(event)
        SecurityLogger.shared.logSecurityEvent(securityEvent)
    }
}

// MARK: - Supporting Types (now imported from AuthenticationModels)

// MARK: - Profile Event Logging

private extension UserProfileManager {
    func convertProfileEventToSecurityEvent(_ event: UserProfileEvent) -> SecurityEvent {
        switch event {
        case .profileUpdated:
            return .dataEncryptionEnabled
        case .profileCleared:
            return .dataEncryptionEnabled
        case .profileImageDownloadFailed, .profileImageCacheFailed:
            return .unauthorizedAccessAttempt
        }
    }
}

// MARK: - GDPR/CCPA Integration

extension UserProfileManager {
    /// Export all user profile data for GDPR/CCPA compliance
    func exportAllUserData() -> [String: Any] {
        let profileExport = exportUserProfileData()

        return [
            "userProfile": [
                "id": profileExport.id,
                "email": profileExport.email,
                "name": profileExport.name ?? "",
                "createdAt": ISO8601DateFormatter().string(from: profileExport.createdAt),
                "updatedAt": profileExport.updatedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "preferences": [
                    "notifications": profileExport.preferences.notificationsEnabled,
                    "locationSharing": profileExport.preferences.locationSharingEnabled,
                    "dataBackup": profileExport.preferences.dataBackupEnabled,
                    "biometricAuth": profileExport.preferences.biometricAuthEnabled,
                    "theme": profileExport.preferences.theme.rawValue
                ]
            ],
            "exportDate": ISO8601DateFormatter().string(from: profileExport.exportDate)
        ]
    }
}