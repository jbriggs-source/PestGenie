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

// MARK: - Enhanced User Profile Models

struct UserProfile: Codable {
    let id: String
    let email: String
    var name: String?
    var profileImageURL: URL?
    var customProfileImageData: Data? // For custom uploaded images
    let createdAt: Date
    var updatedAt: Date?
    var lastSyncDate: Date?
    var preferences: UserPreferences
    var workInfo: WorkInformation
    var profileCompleteness: ProfileCompleteness

    // Profile metadata for sync and versioning
    var version: Int = 1
    var isDirty: Bool = false
    var conflictResolutionData: ConflictResolutionData?
}

struct WorkInformation: Codable {
    var jobTitle: String?
    var department: String?
    var employeeId: String?
    var startDate: Date?
    var certifications: [Certification]
    var emergencyContact: EmergencyContact?
}

struct Certification: Codable, Identifiable {
    let id: UUID
    var name: String
    var issuingOrganization: String
    var issueDate: Date
    var expirationDate: Date?
    var certificateNumber: String?
    var isActive: Bool
}

struct EmergencyContact: Codable {
    var name: String
    var relationship: String
    var phoneNumber: String
    var email: String?
}

struct ProfileCompleteness: Codable {
    var score: Double // 0.0 to 1.0
    var missingFields: [String]
    var lastCalculated: Date

    static func calculate(from profile: UserProfile) -> ProfileCompleteness {
        var score = 0.0
        var missing: [String] = []

        // Basic info (40% weight)
        if profile.name?.isEmpty == false { score += 0.15 } else { missing.append("name") }
        if profile.profileImageURL != nil || profile.customProfileImageData != nil { score += 0.15 } else { missing.append("profileImage") }
        if !profile.email.isEmpty { score += 0.10 }

        // Work info (30% weight)
        if profile.workInfo.jobTitle?.isEmpty == false { score += 0.10 } else { missing.append("jobTitle") }
        if profile.workInfo.department?.isEmpty == false { score += 0.10 } else { missing.append("department") }
        if profile.workInfo.employeeId?.isEmpty == false { score += 0.10 } else { missing.append("employeeId") }

        // Emergency contact (20% weight)
        if let contact = profile.workInfo.emergencyContact {
            if !contact.name.isEmpty && !contact.phoneNumber.isEmpty { score += 0.20 }
            else { missing.append("emergencyContact") }
        } else { missing.append("emergencyContact") }

        // Preferences (10% weight)
        score += 0.10 // Always have default preferences

        return ProfileCompleteness(
            score: min(score, 1.0),
            missingFields: missing,
            lastCalculated: Date()
        )
    }
}

struct ConflictResolutionData: Codable {
    let serverVersion: Int
    let localVersion: Int
    let conflictedFields: [String]
    let timestamp: Date
    let resolutionStrategy: ConflictResolutionStrategy

    enum ConflictResolutionStrategy: String, Codable {
        case serverWins
        case localWins
        case manual
        case fieldByField
    }
}

struct UserPreferences: Codable {
    var notificationsEnabled = true
    var locationSharingEnabled = true
    var dataBackupEnabled = true
    var biometricAuthEnabled = true
    var theme: AppTheme = .system

    // Enhanced notification preferences
    var jobReminders = true
    var weatherAlerts = true
    var equipmentMaintenanceAlerts = true
    var routeOptimization = true

    // Data sync preferences
    var autoSyncInterval: SyncInterval = .realTime
    var syncOverCellular = false
    var offlineDataRetention: DataRetentionPeriod = .thirtyDays

    // UI preferences
    var mapStyle: MapStyle = .standard
    var distanceUnits: DistanceUnits = .miles
    var temperatureUnits: TemperatureUnits = .fahrenheit

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

    enum SyncInterval: String, Codable, CaseIterable {
        case realTime = "realTime"
        case every5Minutes = "5min"
        case every15Minutes = "15min"
        case hourly = "hourly"
        case manual = "manual"

        var displayName: String {
            switch self {
            case .realTime: return "Real-time"
            case .every5Minutes: return "Every 5 minutes"
            case .every15Minutes: return "Every 15 minutes"
            case .hourly: return "Hourly"
            case .manual: return "Manual only"
            }
        }
    }

    enum DataRetentionPeriod: String, Codable, CaseIterable {
        case sevenDays = "7d"
        case thirtyDays = "30d"
        case ninetyDays = "90d"
        case oneYear = "1y"
        case indefinite = "indefinite"

        var displayName: String {
            switch self {
            case .sevenDays: return "7 days"
            case .thirtyDays: return "30 days"
            case .ninetyDays: return "90 days"
            case .oneYear: return "1 year"
            case .indefinite: return "Keep forever"
            }
        }
    }

    enum MapStyle: String, Codable, CaseIterable {
        case standard, satellite, hybrid

        var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .satellite: return "Satellite"
            case .hybrid: return "Hybrid"
            }
        }
    }

    enum DistanceUnits: String, Codable, CaseIterable {
        case miles, kilometers

        var displayName: String {
            switch self {
            case .miles: return "Miles"
            case .kilometers: return "Kilometers"
            }
        }
    }

    enum TemperatureUnits: String, Codable, CaseIterable {
        case fahrenheit, celsius

        var displayName: String {
            switch self {
            case .fahrenheit: return "Fahrenheit"
            case .celsius: return "Celsius"
            }
        }
    }
}

struct UserProfileUpdate {
    let name: String?
    let preferences: UserPreferences?
    let workInfo: WorkInformation?
    let customProfileImage: Data?
    let removeCustomImage: Bool = false

    // For partial updates
    let updatedFields: Set<String>
    let timestamp: Date = Date()

    func isValid() -> ProfileValidationResult {
        var errors: [ValidationError] = []

        // Validate name
        if let name = name {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyName)
            } else if name.count > 100 {
                errors.append(.nameTooLong)
            }
        }

        // Validate work info
        if let workInfo = workInfo {
            if let jobTitle = workInfo.jobTitle, jobTitle.count > 50 {
                errors.append(.jobTitleTooLong)
            }
            if let department = workInfo.department, department.count > 50 {
                errors.append(.departmentTooLong)
            }
            if let employeeId = workInfo.employeeId, employeeId.count > 20 {
                errors.append(.employeeIdTooLong)
            }
        }

        // Validate image size
        if let imageData = customProfileImage {
            let maxSize = 5 * 1024 * 1024 // 5MB
            if imageData.count > maxSize {
                errors.append(.imageTooLarge)
            }
        }

        return errors.isEmpty ? .success : .failure(errors)
    }
}

enum ValidationError: Error, LocalizedError {
    case emptyName
    case nameTooLong
    case jobTitleTooLong
    case departmentTooLong
    case employeeIdTooLong
    case imageTooLarge
    case invalidPhoneNumber
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Name cannot be empty"
        case .nameTooLong: return "Name must be less than 100 characters"
        case .jobTitleTooLong: return "Job title must be less than 50 characters"
        case .departmentTooLong: return "Department must be less than 50 characters"
        case .employeeIdTooLong: return "Employee ID must be less than 20 characters"
        case .imageTooLarge: return "Profile image must be less than 5MB"
        case .invalidPhoneNumber: return "Please enter a valid phone number"
        case .invalidEmail: return "Please enter a valid email address"
        }
    }
}

enum ProfileValidationResult {
    case success
    case failure([ValidationError])

    var isValid: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    var errors: [ValidationError] {
        switch self {
        case .success: return []
        case .failure(let errors): return errors
        }
    }
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
    case syncConflict(ConflictResolutionData)
    case validationFailed([ValidationError])
    case networkError(Error)
    case storageError(Error)
    case imageProcessingFailed
    case profileLocked
    case insufficientPermissions
    case dataTooLarge

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
        case .syncConflict:
            return "Profile data conflict detected during sync"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .imageProcessingFailed:
            return "Failed to process profile image"
        case .profileLocked:
            return "Profile is locked by another process"
        case .insufficientPermissions:
            return "Insufficient permissions to modify profile"
        case .dataTooLarge:
            return "Profile data exceeds size limits"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .cachingFailed, .storageError:
            return true
        default:
            return false
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
    case profileImageUploaded(String)
    case profileValidationFailed(String, [ValidationError])
    case syncConflictDetected(String, ConflictResolutionData)
    case syncConflictResolved(String, ConflictResolutionData.ConflictResolutionStrategy)
    case offlineChangesQueued(String, Int)
    case profileCompletedCalculated(String, Double)
}