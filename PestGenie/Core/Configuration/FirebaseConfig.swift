import Foundation
import GoogleSignIn

/// Secure Firebase configuration management
/// Handles different environments and keeps sensitive data secure
final class FirebaseConfig {

    // MARK: - Environment

    enum Environment {
        case development
        case staging
        case production

        var plistName: String {
            switch self {
            case .development:
                return "GoogleService-Info-Dev"
            case .staging:
                return "GoogleService-Info-Staging"
            case .production:
                return "GoogleService-Info"
            }
        }
    }

    // MARK: - Configuration

    static let shared = FirebaseConfig()

    private let currentEnvironment: Environment
    private var configuration: [String: Any]?

    private init() {
        // Determine environment based on build configuration
        #if DEBUG
        self.currentEnvironment = .development
        #elseif STAGING
        self.currentEnvironment = .staging
        #else
        self.currentEnvironment = .production
        #endif

        loadConfiguration()
    }

    // MARK: - Public Interface

    var clientId: String? {
        return configuration?["CLIENT_ID"] as? String
    }

    var reversedClientId: String? {
        return configuration?["REVERSED_CLIENT_ID"] as? String
    }

    var apiKey: String? {
        return configuration?["API_KEY"] as? String
    }

    var projectId: String? {
        return configuration?["PROJECT_ID"] as? String
    }

    var bundleId: String? {
        return configuration?["BUNDLE_ID"] as? String
    }

    var isConfigured: Bool {
        guard let clientId = clientId,
              !clientId.isEmpty,
              !clientId.contains("YOUR_GOOGLE_CLIENT_ID") else {
            return false
        }
        return true
    }

    // MARK: - Configuration Loading

    private func loadConfiguration() {
        let plistName = currentEnvironment.plistName

        guard let path = Bundle.main.path(forResource: plistName, ofType: "plist") else {
            // Silently fallback to default GoogleService-Info.plist for development
            if let fallbackPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
                if currentEnvironment != .production {
                    print("📝 Firebase Config: Using production config for \(currentEnvironment) environment")
                }
                configuration = NSDictionary(contentsOfFile: fallbackPath) as? [String: Any]
            } else {
                print("❌ Firebase Config: No GoogleService-Info.plist found")
            }
            return
        }

        configuration = NSDictionary(contentsOfFile: path) as? [String: Any]

        if !isConfigured {
            print("⚠️ Firebase Config: Configuration file found but contains template values")
            print("📝 Replace \(plistName).plist with actual Firebase configuration")
        } else {
            print("✅ Firebase Config: Loaded configuration for \(currentEnvironment)")
        }
    }

    // MARK: - Google Sign-In Configuration

    func configureGoogleSignIn() -> Bool {
        guard isConfigured, let clientId = clientId else {
            print("❌ Firebase Config: Cannot configure Google Sign-In - missing or invalid CLIENT_ID")
            return false
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Firebase Config: Google Sign-In configured successfully")
        return true
    }

    // MARK: - Validation

    func validateConfiguration() -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []

        // Check if configuration is loaded
        guard let config = configuration else {
            issues.append("Configuration file not found or invalid")
            return (false, issues)
        }

        // Validate required fields
        let requiredFields = ["CLIENT_ID", "REVERSED_CLIENT_ID", "API_KEY", "PROJECT_ID", "BUNDLE_ID"]

        for field in requiredFields {
            guard let value = config[field] as? String, !value.isEmpty else {
                issues.append("Missing or empty field: \(field)")
                continue
            }

            // Check for template values
            if value.contains("YOUR_") {
                issues.append("Template value detected in field: \(field)")
            }
        }

        // Validate bundle identifier matches app
        if let configBundleId = bundleId,
           let appBundleId = Bundle.main.bundleIdentifier,
           configBundleId != appBundleId {
            issues.append("Bundle ID mismatch - Config: \(configBundleId), App: \(appBundleId)")
        }

        return (issues.isEmpty, issues)
    }
}

// MARK: - Environment Detection Extensions

extension FirebaseConfig {

    /// Check if running in development environment
    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Check if running in production environment
    static var isProduction: Bool {
        return !isDevelopment
    }

    /// Current environment string for logging
    static var environmentString: String {
        return shared.currentEnvironment.plistName
    }
}