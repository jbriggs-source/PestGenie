import Foundation
import UIKit

/// Manages user authentication sessions and handles session lifecycle
final class SessionManager {

    // MARK: - Properties

    private var currentSession: UserSession?
    private var sessionTimer: Timer?
    var onSessionExpired: (() async -> Void)?

    // MARK: - Configuration

    private let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
    private let refreshThreshold: TimeInterval = 5 * 60 // 5 minutes before expiry

    // MARK: - Session Management

    /// Create a new user session
    func createSession(for user: AuthenticatedUser) async {
        let deviceInfo = DeviceInfo(
            deviceId: await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )

        currentSession = UserSession(
            id: UUID(),
            userId: user.id,
            userEmail: user.email,
            createdAt: Date(),
            lastActivity: Date(),
            deviceInfo: deviceInfo
        )

        startSessionTimer()
        await logSessionEvent(.sessionCreated(user.id))
    }

    /// Restore an existing session
    func restoreSession(for user: AuthenticatedUser) async {
        // Check if we have a valid stored session
        if let storedSession = loadStoredSession(),
           storedSession.userId == user.id,
           !isSessionExpired(storedSession) {
            currentSession = storedSession
            refreshActivity()
            startSessionTimer()
            await logSessionEvent(.sessionRestored(user.id))
        } else {
            // Create new session if stored session is invalid or expired
            await createSession(for: user)
        }
    }

    /// Refresh session activity
    func refreshSession(for user: AuthenticatedUser) async {
        guard var session = currentSession, session.userId == user.id else {
            // Create new session if no current session
            await createSession(for: user)
            return
        }

        session.lastActivity = Date()
        currentSession = session
        storeSession(session)
        await logSessionEvent(.sessionRefreshed(user.id))
    }

    /// End the current session
    func endSession() async {
        guard let session = currentSession else { return }

        stopSessionTimer()
        clearStoredSession()
        currentSession = nil

        await logSessionEvent(.sessionEnded(session.userId))
    }

    /// Refresh session activity (called when user is active)
    func refreshActivity() {
        guard var session = currentSession else { return }

        session.lastActivity = Date()
        currentSession = session
        storeSession(session)
    }

    // MARK: - Session State

    /// Check if user has an active session
    var hasActiveSession: Bool {
        guard let session = currentSession else { return false }
        return !isSessionExpired(session)
    }

    /// Get current session status
    var sessionStatus: SessionStatus {
        guard let session = currentSession else { return .inactive }

        if isSessionExpired(session) {
            return .expired
        }

        let timeSinceActivity = Date().timeIntervalSince(session.lastActivity)
        if timeSinceActivity > sessionTimeout - refreshThreshold {
            return .ending
        }

        return .active
    }

    /// Get current session info
    var currentSessionInfo: UserSession? {
        return currentSession
    }

    // MARK: - Private Methods

    private func startSessionTimer() {
        stopSessionTimer()

        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.checkSessionExpiry()
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func checkSessionExpiry() async {
        guard let session = currentSession else { return }

        if isSessionExpired(session) {
            await handleSessionExpiry()
        }
    }

    private func handleSessionExpiry() async {
        guard let session = currentSession else { return }

        await logSessionEvent(.sessionExpired(session.userId))
        stopSessionTimer()
        clearStoredSession()
        currentSession = nil

        // Notify delegate of session expiry
        await onSessionExpired?()
    }

    private func isSessionExpired(_ session: UserSession) -> Bool {
        let timeSinceActivity = Date().timeIntervalSince(session.lastActivity)
        return timeSinceActivity > sessionTimeout
    }

    private func storeSession(_ session: UserSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "currentUserSession")
        }
    }

    private func loadStoredSession() -> UserSession? {
        guard let data = UserDefaults.standard.data(forKey: "currentUserSession"),
              let session = try? JSONDecoder().decode(UserSession.self, from: data) else {
            return nil
        }
        return session
    }

    private func clearStoredSession() {
        UserDefaults.standard.removeObject(forKey: "currentUserSession")
    }

    private func logSessionEvent(_ event: SessionEvent) async {
        // Map session events to security events
        let securityEvent: SecurityEvent
        switch event {
        case .sessionCreated, .sessionRestored, .sessionRefreshed:
            securityEvent = .biometricAuthenticationAttempt(success: true)
        case .sessionEnded, .sessionExpired, .networkReconnected:
            securityEvent = .dataEncryptionEnabled
        }
        SecurityLogger.shared.logSecurityEvent(securityEvent)
    }
}

// MARK: - Background App Handling

extension SessionManager {
    /// Handle app entering background
    func handleAppWillEnterBackground() {
        refreshActivity()
    }

    /// Handle app returning to foreground
    func handleAppDidBecomeActive() {
        refreshActivity()

        // Check if session has expired while app was in background
        Task {
            await checkSessionExpiry()
        }
    }
}