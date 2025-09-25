import Foundation
import SwiftUI
import GoogleSignIn
import LocalAuthentication

/// Central authentication manager that coordinates Google Sign-In with existing security infrastructure
@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    // MARK: - Published Properties

    @Published var isAuthenticated = false
    @Published var currentUser: AuthenticatedUser?
    @Published var isLoading = false
    @Published var lastError: AuthenticationError?

    // MARK: - Dependencies

    private let securityManager = SecurityManager.shared
    private let complianceManager = AppStoreComplianceManager.shared
    private let googleSignInProvider = GoogleSignInProvider()
    private let sessionManager = SessionManager()
    private let userProfileManager = UserProfileManager()

    // MARK: - Initialization

    private init() {
        setupAuthenticationState()
    }

    // MARK: - Public Interface

    /// Initialize authentication system and restore previous session
    func initialize() async {
        await restorePreviousSession()
    }

    /// Sign in with Google
    func signInWithGoogle() async {
        isLoading = true
        lastError = nil

        do {
            // Request privacy consent if needed
            let hasConsent = await requestPrivacyConsent()
            guard hasConsent else {
                throw AuthenticationError.userDeniedPermissions
            }

            // Perform Google Sign-In
            let googleUser = try await googleSignInProvider.signIn()

            // Store authentication data securely
            try await storeAuthenticationData(googleUser)

            // Create user profile
            let user = try await userProfileManager.createUser(from: googleUser)

            // Set up session
            await sessionManager.createSession(for: user)

            // Update state
            currentUser = user
            isAuthenticated = true

            // Log authentication event
            await logAuthenticationEvent(.signInSuccess)

        } catch {
            lastError = AuthenticationError.from(error)
            await logAuthenticationEvent(.signInFailure(error.localizedDescription))
        }

        isLoading = false
    }

    /// Sign out current user
    func signOut() async {
        isLoading = true

        do {
            // Sign out from Google
            await googleSignInProvider.signOut()

            // Clear stored authentication data
            try await clearAuthenticationData()

            // End session
            await sessionManager.endSession()

            // Update state
            currentUser = nil
            isAuthenticated = false

            await logAuthenticationEvent(.signOutSuccess)

        } catch {
            lastError = AuthenticationError.from(error)
            await logAuthenticationEvent(.signOutFailure(error.localizedDescription))
        }

        isLoading = false
    }

    /// Refresh authentication tokens
    func refreshAuthentication() async -> Bool {
        do {
            guard let currentUser = currentUser else { return false }

            let refreshedTokens = try await googleSignInProvider.refreshTokens()
            try await storeTokens(refreshedTokens)

            // Update session
            await sessionManager.refreshSession(for: currentUser)

            return true
        } catch {
            lastError = AuthenticationError.from(error)
            await logAuthenticationEvent(.tokenRefreshFailure(error.localizedDescription))
            return false
        }
    }

    // MARK: - Private Methods

    private func setupAuthenticationState() {
        // Configure Google Sign-In
        googleSignInProvider.configure()

        // Set up session monitoring
        sessionManager.onSessionExpired = { [weak self] in
            await self?.handleSessionExpiry()
        }
    }

    private func restorePreviousSession() async {
        do {
            // Try to restore Google Sign-In session
            if let googleUser = await googleSignInProvider.restorePreviousSignIn() {
                // Validate stored authentication data exists
                _ = try await retrieveStoredTokens()

                // Create user profile
                let user = try await userProfileManager.createUser(from: googleUser)

                // Restore session
                await sessionManager.restoreSession(for: user)

                // Update state
                currentUser = user
                isAuthenticated = true

                await logAuthenticationEvent(.sessionRestored)
            }
        } catch {
            // Clear invalid session data
            try? await clearAuthenticationData()
            await logAuthenticationEvent(.sessionRestoreFailure(error.localizedDescription))
        }
    }

    private func requestPrivacyConsent() async -> Bool {
        // Check if user has already consented
        if complianceManager.privacySettings.hasConsentedToDataUsage {
            return true
        }

        // Request consent through compliance manager
        return await complianceManager.requestDataUsageConsent()
    }

    private func storeAuthenticationData(_ googleUser: GoogleUser) async throws {
        // Store tokens securely using existing security infrastructure
        try await storeTokens(googleUser.tokens)

        // Update privacy settings with user info
        var privacySettings = complianceManager.privacySettings
        privacySettings.userEmail = googleUser.email
        privacySettings.hasConsentedToDataUsage = true
        complianceManager.privacySettings = privacySettings
    }

    private func storeTokens(_ tokens: AuthTokens) async throws {
        let tokenData = try JSONEncoder().encode(tokens)
        try securityManager.keychain.store(tokenData, for: "googleAuthTokens", requireBiometrics: true)
    }

    private func retrieveStoredTokens() async throws -> AuthTokens {
        guard let tokenData = try securityManager.keychain.retrieve(for: "googleAuthTokens") else {
            throw AuthenticationError.noStoredCredentials
        }
        return try JSONDecoder().decode(AuthTokens.self, from: tokenData)
    }

    private func clearAuthenticationData() async throws {
        // Remove tokens from keychain
        // Note: KeychainManager in SecurityManager doesn't have a remove method,
        // but we can store empty data to effectively clear it
        try? securityManager.keychain.store(Data(), for: "googleAuthTokens", requireBiometrics: false)

        // Clear user profile data
        await userProfileManager.clearUserData()

        // Reset privacy settings if needed
        var privacySettings = complianceManager.privacySettings
        privacySettings.userEmail = ""
        complianceManager.privacySettings = privacySettings
    }

    private func handleSessionExpiry() async {
        // Try to refresh authentication
        let refreshed = await refreshAuthentication()

        if !refreshed {
            // Force sign out if refresh failed
            await signOut()
        }
    }

    private func logAuthenticationEvent(_ event: AuthenticationEvent) async {
        let securityEvent: SecurityEvent
        switch event {
        case .signInSuccess:
            securityEvent = .biometricAuthenticationAttempt(success: true)
        case .signInFailure, .signOutFailure, .sessionRestoreFailure, .tokenRefreshFailure:
            securityEvent = .unauthorizedAccessAttempt
        default:
            securityEvent = .biometricAuthenticationAttempt(success: false)
        }
        SecurityLogger.shared.logSecurityEvent(securityEvent)
    }
}


