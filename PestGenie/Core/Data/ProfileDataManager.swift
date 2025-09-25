import Foundation

/// Simplified profile data manager using UserDefaults for now
/// TODO: Migrate to Core Data with proper entities later
@MainActor
final class ProfileDataManager: ObservableObject {

    // MARK: - UserDefaults Storage (Temporary)

    private let userDefaults = UserDefaults.standard

    // MARK: - Profile Persistence

    func saveProfile(_ profile: UserProfile) async throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)

            userDefaults.set(data, forKey: "userProfile_\(profile.id)")
            userDefaults.set(data, forKey: "userProfile_\(profile.id)_backup")
        } catch {
            throw ProfileDataError.saveFailed(error)
        }
    }

    func loadProfile(for userId: String) async throws -> UserProfile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try primary storage first
        if let data = userDefaults.data(forKey: "userProfile_\(userId)"),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            return profile
        }

        // Try backup storage
        if let data = userDefaults.data(forKey: "userProfile_\(userId)_backup"),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            return profile
        }

        return nil
    }

    func deleteProfile(_ userId: String) async throws {
        userDefaults.removeObject(forKey: "userProfile_\(userId)")
        userDefaults.removeObject(forKey: "userProfile_\(userId)_backup")
    }

    func getAllProfiles() async throws -> [UserProfile] {
        // This is a simplified implementation
        // In a real Core Data version, we'd use a fetch request
        return []
    }

    // MARK: - Profile Changes (Simplified)

    func clearProfileData() async throws {
        // Clear all profile-related data
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("userProfile_") || key.hasPrefix("profileChanges") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Error Types

enum ProfileDataError: Error, LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save profile: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load profile: \(error.localizedDescription)"
        case .notFound:
            return "Profile not found"
        }
    }
}