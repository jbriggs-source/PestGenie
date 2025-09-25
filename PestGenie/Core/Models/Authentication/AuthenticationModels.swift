import Foundation

// MARK: - Authentication Data Models

struct AuthenticatedUser {
    let id: String
    let email: String
    let name: String?
    let profileImageURL: URL?
    let createdAt: Date
    let lastSignInAt: Date
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresAt: Date
}

struct GoogleUser {
    let id: String
    let email: String
    let name: String?
    let profileImageURL: URL?
    let tokens: AuthTokens
}

// MARK: - Authentication Errors

enum AuthenticationError: Error, LocalizedError, Equatable {
    case userDeniedPermissions
    case noStoredCredentials
    case invalidCredentials
    case networkError(String)
    case securityError(String)
    case unknownError(String)

    static func from(_ error: Error) -> AuthenticationError {
        if let authError = error as? AuthenticationError {
            return authError
        } else if error.localizedDescription.contains("network") {
            return .networkError(error.localizedDescription)
        } else if error.localizedDescription.contains("security") {
            return .securityError(error.localizedDescription)
        } else {
            return .unknownError(error.localizedDescription)
        }
    }

    var errorDescription: String? {
        switch self {
        case .userDeniedPermissions:
            return "Permission to access your data was denied"
        case .noStoredCredentials:
            return "No stored authentication credentials found"
        case .invalidCredentials:
            return "Invalid or expired credentials"
        case .networkError(let message):
            return "Network error: \(message)"
        case .securityError(let message):
            return "Security error: \(message)"
        case .unknownError(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}

// MARK: - Authentication Events

enum AuthenticationEvent {
    case signInSuccess
    case signInFailure(String)
    case signOutSuccess
    case signOutFailure(String)
    case sessionRestored
    case sessionRestoreFailure(String)
    case tokenRefreshFailure(String)
}

// MARK: - User Profile Models

struct UserProfile: Codable {
    let id: String
    let email: String
    var name: String?
    let profileImageURL: URL?
    let createdAt: Date
    var updatedAt: Date?
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var notificationsEnabled = true
    var locationSharingEnabled = true
    var dataBackupEnabled = true
    var biometricAuthEnabled = true
    var theme: AppTheme = .system

    enum AppTheme: String, Codable, CaseIterable {
        case light, dark, system

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
    }
}

struct UserProfileUpdate {
    let name: String?
    let preferences: UserPreferences?
}

struct UserProfileExport: Codable {
    let id: String
    let email: String
    let name: String?
    let createdAt: Date
    let updatedAt: Date?
    let preferences: UserPreferences
    let exportDate: Date

    static func empty() -> UserProfileExport {
        return UserProfileExport(
            id: "",
            email: "",
            name: nil,
            createdAt: Date.distantPast,
            updatedAt: nil,
            preferences: UserPreferences(),
            exportDate: Date()
        )
    }
}

// MARK: - User Profile Errors

enum UserProfileError: Error, LocalizedError {
    case noCurrentProfile
    case invalidProfileData
    case imageDownloadFailed
    case cachingFailed

    var errorDescription: String? {
        switch self {
        case .noCurrentProfile:
            return "No current user profile available"
        case .invalidProfileData:
            return "Invalid profile data provided"
        case .imageDownloadFailed:
            return "Failed to download profile image"
        case .cachingFailed:
            return "Failed to cache profile data"
        }
    }
}

// MARK: - Session Models

struct UserSession: Codable {
    let id: UUID
    let userId: String
    let userEmail: String
    let createdAt: Date
    var lastActivity: Date
    let deviceInfo: DeviceInfo
}

struct DeviceInfo: Codable {
    let deviceId: String
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
}

enum SessionStatus {
    case inactive
    case active
    case ending
    case expired
}

// MARK: - Events

enum SessionEvent {
    case sessionCreated(String)
    case sessionRestored(String)
    case sessionRefreshed(String)
    case sessionEnded(String)
    case sessionExpired(String)
    case networkReconnected(String)
}

enum UserProfileEvent {
    case profileUpdated(String)
    case profileCleared(String)
    case profileImageDownloadFailed(String, String)
    case profileImageCacheFailed(String, String)
}