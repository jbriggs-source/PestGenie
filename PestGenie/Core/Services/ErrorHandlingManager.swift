import Foundation
import SwiftUI
import LocalAuthentication

/// Enterprise-grade error handling with recovery actions and user guidance
@MainActor
final class ErrorHandlingManager: ObservableObject {
    static let shared = ErrorHandlingManager()

    // MARK: - Published Properties

    @Published var currentError: RecoverableError?
    @Published var isShowingErrorDialog = false
    @Published var errorRecoveryInProgress = false

    // MARK: - Error Handling

    /// Present an error with recovery options to the user
    func presentError(_ error: Error, context: ErrorContext = .general) {
        let recoverableError = RecoverableError.from(error, context: context)
        currentError = recoverableError
        isShowingErrorDialog = true

        logError(error, context: context)
    }

    /// Dismiss the current error
    func dismissError() {
        currentError = nil
        isShowingErrorDialog = false
        errorRecoveryInProgress = false
    }

    /// Attempt to recover from the current error
    func attemptRecovery() async {
        guard let error = currentError else { return }

        errorRecoveryInProgress = true

        let success = await executeRecoveryAction(for: error)

        if success {
            dismissError()
        } else {
            // Recovery failed, update error with additional context
            let updatedError = RecoverableError(
                title: error.title,
                message: "Recovery attempt failed. \(error.message)",
                context: error.context,
                recoveryActions: error.recoveryActions.filter {
                    switch $0.type {
                    case .retry: return false
                    default: return true
                    }
                }, // Remove retry option
                severity: .high
            )
            currentError = updatedError
        }

        errorRecoveryInProgress = false
    }

    // MARK: - Private Methods

    private func executeRecoveryAction(for error: RecoverableError) async -> Bool {
        guard let primaryAction = error.recoveryActions.first else { return false }

        switch primaryAction.type {
        case .retry:
            return await handleRetryAction(for: error)
        case .openSettings:
            return await handleOpenSettingsAction(for: error)
        case .requestPermissions:
            return await handleRequestPermissionsAction(for: error)
        case .checkConnection:
            return await handleCheckConnectionAction(for: error)
        case .enableBiometrics:
            return await handleEnableBiometricsAction(for: error)
        case .clearCache:
            return await handleClearCacheAction(for: error)
        case .contactSupport:
            return handleContactSupportAction(for: error)
        case .custom(let action):
            return await action()
        }
    }

    private func handleRetryAction(for error: RecoverableError) async -> Bool {
        // Generic retry logic - specific implementations would override this
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return true
    }

    private func handleOpenSettingsAction(for error: RecoverableError) async -> Bool {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            return false
        }

        await UIApplication.shared.open(settingsURL)
        return true
    }

    private func handleRequestPermissionsAction(for error: RecoverableError) async -> Bool {
        switch error.context {
        case .location:
            return await LocationManager.shared.requestPermission()
        case .notifications:
            return await NotificationManager.shared.requestPermissions()
        case .biometricAuth:
            let manager = BiometricAuthenticationManager.shared
            let result = await manager.enableBiometricAuthentication()
            return result.isSuccess
        default:
            return false
        }
    }

    private func handleCheckConnectionAction(for error: RecoverableError) async -> Bool {
        let networkMonitor = NetworkMonitor.shared
        // Wait a moment and check connection status
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        return networkMonitor.isConnected
    }

    private func handleEnableBiometricsAction(for error: RecoverableError) async -> Bool {
        let manager = BiometricAuthenticationManager.shared
        await manager.checkBiometricAvailability()

        if manager.isAvailable {
            let result = await manager.enableBiometricAuthentication()
            return result.isSuccess
        }
        return false
    }

    private func handleClearCacheAction(for error: RecoverableError) async -> Bool {
        // Clear various caches based on context
        switch error.context {
        case .authentication:
            // Clear authentication cache by storing empty data
            let securityManager = SecurityManager.shared
            try? securityManager.keychain.store(Data(), for: "cachedUserProfile", requireBiometrics: false)
            return true
        case .dataSync:
            // Clear sync cache
            UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
            return true
        default:
            return false
        }
    }

    private func handleContactSupportAction(for error: RecoverableError) -> Bool {
        let supportEmail = "support@pestgenie.com"
        let subject = "Error Report: \(error.title)"
        let body = "Error Details:\n\(error.message)\n\nContext: \(error.context)"

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let emailURL = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"),
              UIApplication.shared.canOpenURL(emailURL) else {
            return false
        }

        UIApplication.shared.open(emailURL)
        return true
    }

    private func logError(_ error: Error, context: ErrorContext) {
        SecurityLogger.shared.logSecurityEvent(.errorOccurred(error.localizedDescription, context))
    }

    private init() {}
}

// MARK: - Supporting Types

/// Recoverable error with user-friendly messaging and recovery actions
struct RecoverableError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let context: ErrorContext
    let recoveryActions: [RecoveryAction]
    let severity: ErrorSeverity

    static func from(_ error: Error, context: ErrorContext = .general) -> RecoverableError {
        if let authError = error as? AuthenticationError {
            return fromAuthenticationError(authError, context: context)
        } else if let biometricError = error as? BiometricError {
            return fromBiometricError(biometricError, context: context)
        } else if let securityError = error as? SecurityError {
            return fromSecurityError(securityError, context: context)
        } else {
            return fromGenericError(error, context: context)
        }
    }

    private static func fromAuthenticationError(_ error: AuthenticationError, context: ErrorContext) -> RecoverableError {
        switch error {
        case .networkError(let message):
            return RecoverableError(
                title: "Connection Error",
                message: "Unable to connect to authentication services. \(message)",
                context: .authentication,
                recoveryActions: [
                    RecoveryAction(title: "Check Connection", type: .checkConnection),
                    RecoveryAction(title: "Try Again", type: .retry),
                    RecoveryAction(title: "Contact Support", type: .contactSupport)
                ],
                severity: .medium
            )

        case .userDeniedPermissions:
            return RecoverableError(
                title: "Permissions Required",
                message: "PestGenie needs permission to access your Google account to sign you in.",
                context: .authentication,
                recoveryActions: [
                    RecoveryAction(title: "Grant Permissions", type: .requestPermissions),
                    RecoveryAction(title: "Open Settings", type: .openSettings)
                ],
                severity: .high
            )

        case .securityError(let message):
            return RecoverableError(
                title: "Security Error",
                message: "A security issue occurred during authentication: \(message)",
                context: .authentication,
                recoveryActions: [
                    RecoveryAction(title: "Try Again", type: .retry),
                    RecoveryAction(title: "Clear Cache", type: .clearCache),
                    RecoveryAction(title: "Contact Support", type: .contactSupport)
                ],
                severity: .high
            )

        default:
            return RecoverableError(
                title: "Authentication Failed",
                message: error.localizedDescription,
                context: .authentication,
                recoveryActions: [
                    RecoveryAction(title: "Try Again", type: .retry),
                    RecoveryAction(title: "Contact Support", type: .contactSupport)
                ],
                severity: .medium
            )
        }
    }

    private static func fromBiometricError(_ error: BiometricError, context: ErrorContext) -> RecoverableError {
        switch error {
        case .biometricsNotEnrolled:
            return RecoverableError(
                title: "Biometrics Not Set Up",
                message: "Face ID or Touch ID is not set up on this device. Set it up in Settings to use biometric authentication.",
                context: .biometricAuth,
                recoveryActions: [
                    RecoveryAction(title: "Open Settings", type: .openSettings),
                    RecoveryAction(title: "Skip for Now", type: .retry)
                ],
                severity: .low
            )

        case .biometricsLocked:
            return RecoverableError(
                title: "Biometrics Locked",
                message: "Biometric authentication is temporarily locked. Please use your device passcode to unlock it.",
                context: .biometricAuth,
                recoveryActions: [
                    RecoveryAction(title: "Use Passcode", type: .openSettings),
                    RecoveryAction(title: "Try Again Later", type: .retry)
                ],
                severity: .medium
            )

        case .biometricsNotAvailable:
            return RecoverableError(
                title: "Biometrics Not Available",
                message: "Biometric authentication is not available on this device.",
                context: .biometricAuth,
                recoveryActions: [
                    RecoveryAction(title: "Continue without Biometrics", type: .retry)
                ],
                severity: .low
            )

        default:
            return RecoverableError(
                title: "Biometric Authentication Failed",
                message: error.localizedDescription,
                context: .biometricAuth,
                recoveryActions: [
                    RecoveryAction(title: "Try Again", type: .retry),
                    RecoveryAction(title: "Use Alternative Method", type: .openSettings)
                ],
                severity: .medium
            )
        }
    }

    private static func fromSecurityError(_ error: SecurityError, context: ErrorContext) -> RecoverableError {
        return RecoverableError(
            title: "Security Error",
            message: error.localizedDescription,
            context: .security,
            recoveryActions: [
                RecoveryAction(title: "Try Again", type: .retry),
                RecoveryAction(title: "Clear Cache", type: .clearCache),
                RecoveryAction(title: "Contact Support", type: .contactSupport)
            ],
            severity: .high
        )
    }

    private static func fromGenericError(_ error: Error, context: ErrorContext) -> RecoverableError {
        return RecoverableError(
            title: "Unexpected Error",
            message: error.localizedDescription,
            context: context,
            recoveryActions: [
                RecoveryAction(title: "Try Again", type: .retry),
                RecoveryAction(title: "Contact Support", type: .contactSupport)
            ],
            severity: .medium
        )
    }
}

/// Recovery action that can be taken to resolve an error
struct RecoveryAction: Identifiable {
    let id = UUID()
    let title: String
    let type: RecoveryActionType
    let isDestructive: Bool

    init(title: String, type: RecoveryActionType, isDestructive: Bool = false) {
        self.title = title
        self.type = type
        self.isDestructive = isDestructive
    }
}

enum RecoveryActionType {
    case retry
    case openSettings
    case requestPermissions
    case checkConnection
    case enableBiometrics
    case clearCache
    case contactSupport
    case custom(() async -> Bool)
}

// Note: ErrorContext is now defined in ErrorManager.swift

// Note: ErrorSeverity is now defined in ErrorManager.swift

// MARK: - Error Dialog View

struct ErrorDialogView: View {
    @ObservedObject var errorManager = ErrorHandlingManager.shared
    let error: RecoverableError

    var body: some View {
        VStack(spacing: 20) {
            // Error Icon and Title
            VStack(spacing: 12) {
                Image(systemName: error.severity.icon)
                    .font(.system(size: 40))
                    .foregroundColor(error.severity.color)

                Text(error.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }

            // Error Message
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Recovery Actions
            VStack(spacing: 12) {
                ForEach(Array(error.recoveryActions.prefix(3)), id: \.id) { action in
                    Button {
                        Task {
                            let isRetryAction = {
                                if case .retry = action.type {
                                    return true
                                }
                                return action.title.contains("Try")
                            }()

                            if isRetryAction {
                                await errorManager.attemptRecovery()
                            } else {
                                await errorManager.attemptRecovery()
                            }
                        }
                    } label: {
                        HStack {
                            if errorManager.errorRecoveryInProgress {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }

                            Text(errorManager.errorRecoveryInProgress ? "Please wait..." : action.title)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(action.isDestructive ? .red : .blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .disabled(errorManager.errorRecoveryInProgress)
                }

                // Dismiss button
                Button("Dismiss") {
                    errorManager.dismissError()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 32)
    }
}

// MARK: - Security Logger Extension

extension SecurityEvent {
    static func errorOccurred(_ message: String, _ context: ErrorContext) -> SecurityEvent {
        switch context {
        case .authentication, .biometricAuth:
            return .unauthorizedAccessAttempt
        case .security:
            return .securityIssueDetected(.insecureKeychainConfiguration)
        default:
            return .dataEncryptionEnabled // Generic event for other errors
        }
    }
}

// MARK: - Preview

#Preview {
    ErrorDialogView(
        error: RecoverableError(
            title: "Authentication Failed",
            message: "Unable to sign in with your Google account. Please check your internet connection and try again.",
            context: .authentication,
            recoveryActions: [
                RecoveryAction(title: "Try Again", type: .retry),
                RecoveryAction(title: "Check Connection", type: .checkConnection),
                RecoveryAction(title: "Contact Support", type: .contactSupport)
            ],
            severity: .medium
        )
    )
}