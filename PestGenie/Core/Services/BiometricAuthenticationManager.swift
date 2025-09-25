import Foundation
import LocalAuthentication
import SwiftUI

/// Enhanced biometric authentication manager with comprehensive Face ID/Touch ID support
@MainActor
final class BiometricAuthenticationManager: ObservableObject {
    static let shared = BiometricAuthenticationManager()

    // MARK: - Published Properties

    @Published var biometricType: BiometricType = .none
    @Published var isAvailable = false
    @Published var isEnabled = false
    @Published var lastAuthenticationResult: BiometricAuthResult?

    // MARK: - Private Properties

    private let context = LAContext()
    private let userDefaults = UserDefaults.standard
    private let biometricEnabledKey = "BiometricAuthenticationEnabled"

    // MARK: - Initialization

    private init() {
        Task {
            await checkBiometricAvailability()
            isEnabled = userDefaults.bool(forKey: biometricEnabledKey)
        }
    }

    // MARK: - Public Interface

    /// Check if biometric authentication is available on device
    func checkBiometricAvailability() async {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        isAvailable = canEvaluate

        if canEvaluate {
            biometricType = getBiometricType()
        } else {
            biometricType = .none
            if let error = error {
                await logBiometricEvent(.availabilityCheckFailed(error.localizedDescription))
            }
        }
    }

    /// Enable biometric authentication for the user
    func enableBiometricAuthentication() async -> BiometricAuthResult {
        guard isAvailable else {
            return .failure(.biometricsNotAvailable)
        }

        // Test biometric authentication before enabling
        let authResult = await authenticateWithBiometrics(reason: "Enable biometric authentication for secure access to PestGenie")

        if case .success = authResult {
            isEnabled = true
            userDefaults.set(true, forKey: biometricEnabledKey)
            await logBiometricEvent(.biometricEnabled)
            return .success
        }

        return authResult
    }

    /// Disable biometric authentication
    func disableBiometricAuthentication() {
        isEnabled = false
        userDefaults.set(false, forKey: biometricEnabledKey)
        Task {
            await logBiometricEvent(.biometricDisabled)
        }
    }

    /// Authenticate user with biometrics
    func authenticateWithBiometrics(reason: String) async -> BiometricAuthResult {
        guard isAvailable && isEnabled else {
            let error: BiometricError = isAvailable ? .biometricsNotEnabled : .biometricsNotAvailable
            return .failure(error)
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            let result: BiometricAuthResult = success ? .success : .failure(.authenticationFailed)
            lastAuthenticationResult = result

            await logBiometricEvent(success ? .authenticationSuccess : .authenticationFailure("User authentication failed"))
            return result

        } catch let error as LAError {
            let biometricError = mapLAErrorToBiometricError(error)
            let result: BiometricAuthResult = .failure(biometricError)
            lastAuthenticationResult = result

            await logBiometricEvent(.authenticationFailure(error.localizedDescription))
            return result
        } catch {
            let result: BiometricAuthResult = .failure(.unknownError(error.localizedDescription))
            lastAuthenticationResult = result

            await logBiometricEvent(.authenticationFailure(error.localizedDescription))
            return result
        }
    }

    /// Quick unlock flow for returning users
    func quickUnlock() async -> BiometricAuthResult {
        let reason = "Quick unlock to access your routes and job information"
        return await authenticateWithBiometrics(reason: reason)
    }

    /// Secure token access with biometric protection
    func authenticateForTokenAccess() async -> BiometricAuthResult {
        let reason = "Authenticate to access your secure authentication tokens"
        return await authenticateWithBiometrics(reason: reason)
    }

    // MARK: - Private Methods

    private func getBiometricType() -> BiometricType {
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    private func mapLAErrorToBiometricError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .userCancel:
            return .userCanceled
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCanceled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometricsNotAvailable
        case .biometryNotEnrolled:
            return .biometricsNotEnrolled
        case .biometryLockout:
            return .biometricsLocked
        case .authenticationFailed:
            return .authenticationFailed
        default:
            return .unknownError(error.localizedDescription)
        }
    }

    private func logBiometricEvent(_ event: BiometricEvent) async {
        SecurityLogger.shared.logSecurityEvent(.biometricEvent(event))
    }
}

// MARK: - Supporting Types

enum BiometricType: String, CaseIterable {
    case none = "None"
    case touchID = "Touch ID"
    case faceID = "Face ID"
    case opticID = "Optic ID"

    var icon: String {
        switch self {
        case .none:
            return "lock"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }

    var displayName: String {
        return rawValue
    }
}

enum BiometricAuthResult: Equatable {
    case success
    case failure(BiometricError)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var error: BiometricError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

enum BiometricError: Error, LocalizedError, Equatable {
    case biometricsNotAvailable
    case biometricsNotEnabled
    case biometricsNotEnrolled
    case biometricsLocked
    case passcodeNotSet
    case userCanceled
    case userFallback
    case systemCanceled
    case authenticationFailed
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricsNotEnabled:
            return "Biometric authentication is not enabled in the app"
        case .biometricsNotEnrolled:
            return "No biometric data is enrolled on this device. Please set up Face ID or Touch ID in Settings"
        case .biometricsLocked:
            return "Biometric authentication is locked. Please use your passcode"
        case .passcodeNotSet:
            return "Please set up a passcode in Settings to use biometric authentication"
        case .userCanceled:
            return "Authentication was canceled by the user"
        case .userFallback:
            return "User chose to use passcode instead"
        case .systemCanceled:
            return "Authentication was canceled by the system"
        case .authenticationFailed:
            return "Biometric authentication failed. Please try again"
        case .unknownError(let message):
            return "An unknown error occurred: \(message)"
        }
    }

    var recoveryAction: String? {
        switch self {
        case .biometricsNotEnrolled:
            return "Open Settings to set up Face ID or Touch ID"
        case .biometricsLocked:
            return "Use your device passcode to unlock biometrics"
        case .passcodeNotSet:
            return "Set up a passcode in Settings"
        case .authenticationFailed:
            return "Try again or use passcode"
        default:
            return nil
        }
    }
}

enum BiometricEvent {
    case availabilityCheckFailed(String)
    case biometricEnabled
    case biometricDisabled
    case authenticationSuccess
    case authenticationFailure(String)
}

// MARK: - Extensions

extension SecurityEvent {
    static func biometricEvent(_ event: BiometricEvent) -> SecurityEvent {
        switch event {
        case .authenticationSuccess:
            return .biometricAuthenticationAttempt(success: true)
        case .authenticationFailure, .availabilityCheckFailed:
            return .biometricAuthenticationAttempt(success: false)
        case .biometricEnabled:
            return .dataEncryptionEnabled
        case .biometricDisabled:
            return .securityIssueDetected(.biometricAuthenticationUnavailable)
        }
    }
}

// MARK: - SwiftUI Helpers

extension BiometricAuthenticationManager {
    /// Get user-friendly description of current biometric status
    var statusDescription: String {
        if !isAvailable {
            return "Biometric authentication is not available on this device"
        } else if !isEnabled {
            return "\(biometricType.displayName) is available but not enabled"
        } else {
            return "\(biometricType.displayName) is enabled and ready to use"
        }
    }

    /// Get color for status indication
    var statusColor: Color {
        if !isAvailable {
            return .secondary
        } else if !isEnabled {
            return .orange
        } else {
            return .green
        }
    }
}