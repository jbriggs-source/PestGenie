import Foundation
import GoogleSignIn
import SwiftUI

/// Google Sign-In integration provider
final class GoogleSignInProvider {

    // MARK: - Configuration

    /// Configure Google Sign-In with app's client configuration
    func configure() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ Google Service Info plist not found or CLIENT_ID missing")
            return
        }

        let config = GIDConfiguration(clientID: clientId)

        GIDSignIn.sharedInstance.configuration = config
    }

    // MARK: - Sign In

    /// Perform Google Sign-In
    func signIn() async throws -> GoogleUser {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw GoogleSignInError.noRootViewController
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: GoogleSignInError.signInFailed(error.localizedDescription))
                    return
                }

                guard let result = result,
                      let user = result.user.profile else {
                    continuation.resume(throwing: GoogleSignInError.noUserProfile)
                    return
                }

                // Extract tokens
                let accessToken = result.user.accessToken.tokenString
                let refreshToken = result.user.refreshToken.tokenString
                let idToken = result.user.idToken?.tokenString

                let tokens = AuthTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    idToken: idToken,
                    expiresAt: result.user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
                )

                let googleUser = GoogleUser(
                    id: result.user.userID ?? "",
                    email: user.email,
                    name: user.name,
                    profileImageURL: user.imageURL(withDimension: 120),
                    tokens: tokens
                )

                continuation.resume(returning: googleUser)
            }
        }
    }

    // MARK: - Sign Out

    /// Sign out from Google
    func signOut() async {
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Session Restoration

    /// Restore previous sign-in session
    func restorePreviousSignIn() async -> GoogleUser? {
        return await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                guard let user = user,
                      let profile = user.profile,
                      error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract current tokens
                let accessToken = user.accessToken.tokenString
                let refreshToken = user.refreshToken.tokenString
                let idToken = user.idToken?.tokenString

                let tokens = AuthTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    idToken: idToken,
                    expiresAt: user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
                )

                let googleUser = GoogleUser(
                    id: user.userID ?? "",
                    email: profile.email,
                    name: profile.name,
                    profileImageURL: profile.imageURL(withDimension: 120),
                    tokens: tokens
                )

                continuation.resume(returning: googleUser)
            }
        }
    }

    // MARK: - Token Refresh

    /// Refresh authentication tokens
    func refreshTokens() async throws -> AuthTokens {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleSignInError.noCurrentUser
        }

        return try await withCheckedThrowingContinuation { continuation in
            currentUser.refreshTokensIfNeeded { user, error in
                if let error = error {
                    continuation.resume(throwing: GoogleSignInError.tokenRefreshFailed(error.localizedDescription))
                    return
                }

                guard let user = user else {
                    continuation.resume(throwing: GoogleSignInError.noCurrentUser)
                    return
                }

                let tokens = AuthTokens(
                    accessToken: user.accessToken.tokenString,
                    refreshToken: user.refreshToken.tokenString,
                    idToken: user.idToken?.tokenString,
                    expiresAt: user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
                )

                continuation.resume(returning: tokens)
            }
        }
    }

    // MARK: - Current User

    /// Get current signed-in user
    var currentUser: GoogleUser? {
        guard let user = GIDSignIn.sharedInstance.currentUser,
              let profile = user.profile else {
            return nil
        }

        let tokens = AuthTokens(
            accessToken: user.accessToken.tokenString,
            refreshToken: user.refreshToken.tokenString,
            idToken: user.idToken?.tokenString,
            expiresAt: user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
        )

        return GoogleUser(
            id: user.userID ?? "",
            email: profile.email,
            name: profile.name,
            profileImageURL: profile.imageURL(withDimension: 120),
            tokens: tokens
        )
    }

    // MARK: - URL Handling

    /// Handle URL redirects from Google Sign-In
    func handleURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Google Sign-In Errors

enum GoogleSignInError: Error, LocalizedError {
    case noRootViewController
    case signInFailed(String)
    case noUserProfile
    case noCurrentUser
    case tokenRefreshFailed(String)
    case configurationMissing

    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Unable to find root view controller for sign-in presentation"
        case .signInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .noUserProfile:
            return "No user profile available from Google Sign-In"
        case .noCurrentUser:
            return "No current Google user session"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .configurationMissing:
            return "Google Sign-In configuration is missing or invalid"
        }
    }
}