import XCTest
@testable import PestGenie
import GoogleSignIn

/// Comprehensive tests for Google Sign-In authentication integration
final class AuthenticationTests: XCTestCase {

    var authManager: AuthenticationManager!

    override func setUp() {
        super.setUp()
        authManager = AuthenticationManager.shared
    }

    override func tearDown() {
        authManager = nil
        super.tearDown()
    }

    // MARK: - Authentication Manager Tests

    @MainActor
    func testInitializeAuthenticationManager() async {
        // Test that authentication manager initializes properly
        await authManager.initialize()

        // Should not crash and should have consistent state
        XCTAssertNotNil(authManager, "AuthenticationManager should exist")
    }

    @MainActor
    func testAuthenticationManagerProperties() {
        // Test initial state properties
        XCTAssertFalse(authManager.isLoading, "Should not be loading initially")
        // Note: isAuthenticated and currentUser may vary based on stored state
    }

    // MARK: - Authentication Flow Tests

    @MainActor
    func testSignInWithGoogleConfiguration() async {
        // Test that Google Sign-In can be initiated without crashing
        // This will fail due to template configuration but should not crash
        await authManager.signInWithGoogle()

        // Should complete without crashing
        XCTAssertFalse(authManager.isLoading, "Should not be loading after completion")
    }

    @MainActor
    func testSignOutCleanup() async {
        // Test that sign out completes cleanly
        await authManager.signOut()

        // Should complete without issues
        XCTAssertFalse(authManager.isLoading, "Should not be loading after sign out")
    }

    // MARK: - Component Integration Tests

    func testGoogleSignInProviderInitialization() {
        // Test that Google Sign-In provider can be created
        let provider = GoogleSignInProvider()
        XCTAssertNotNil(provider, "GoogleSignInProvider should initialize")
    }

    func testUserProfileManagerInitialization() {
        // Test that User Profile Manager can be created
        let profileManager = UserProfileManager()
        XCTAssertNotNil(profileManager, "UserProfileManager should initialize")
        XCTAssertNil(profileManager.currentProfile, "Should have no current profile initially")
    }

    func testSessionManagerInitialization() {
        // Test that Session Manager can be created
        let sessionManager = SessionManager()
        XCTAssertNotNil(sessionManager, "SessionManager should initialize")
        XCTAssertNil(sessionManager.currentSessionInfo, "Should have no current session initially")
        XCTAssertEqual(sessionManager.sessionStatus, .inactive, "Session should be inactive initially")
    }

    // MARK: - Authentication Models Tests

    func testAuthenticationErrorModel() {
        // Test AuthenticationError enum
        let error1 = AuthenticationError.userDeniedPermissions
        let error2 = AuthenticationError.userDeniedPermissions
        let error3 = AuthenticationError.invalidCredentials

        XCTAssertEqual(error1, error2, "Same authentication errors should be equal")
        XCTAssertNotEqual(error1, error3, "Different authentication errors should not be equal")

        // Test error descriptions
        XCTAssertNotNil(error1.errorDescription, "Error should have description")
        XCTAssertFalse(error1.errorDescription?.isEmpty ?? true, "Error description should not be empty")
    }

    func testAuthTokensModel() {
        // Test AuthTokens model
        let tokens = AuthTokens(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            idToken: "test-id-token",
            expiresAt: Date().addingTimeInterval(3600)
        )

        XCTAssertEqual(tokens.accessToken, "test-access-token")
        XCTAssertEqual(tokens.refreshToken, "test-refresh-token")
        XCTAssertEqual(tokens.idToken, "test-id-token")
        XCTAssertTrue(tokens.expiresAt > Date(), "Token should not be expired")
    }

    func testUserProfileModel() {
        // Test UserProfile model
        let preferences = UserPreferences()
        XCTAssertTrue(preferences.notificationsEnabled, "Notifications should be enabled by default")
        XCTAssertTrue(preferences.locationSharingEnabled, "Location sharing should be enabled by default")
        XCTAssertTrue(preferences.dataBackupEnabled, "Data backup should be enabled by default")
        XCTAssertTrue(preferences.biometricAuthEnabled, "Biometric auth should be enabled by default")
        XCTAssertEqual(preferences.theme, .system, "Theme should be system by default")

        let profile = UserProfile(
            id: "test-user-id",
            email: "test@example.com",
            name: "Test User",
            profileImageURL: nil,
            createdAt: Date(),
            preferences: preferences
        )

        XCTAssertEqual(profile.id, "test-user-id")
        XCTAssertEqual(profile.email, "test@example.com")
        XCTAssertEqual(profile.name, "Test User")
        XCTAssertNil(profile.profileImageURL)
        XCTAssertNotNil(profile.createdAt)
        XCTAssertEqual(profile.preferences.theme, .system)
    }

    func testGoogleUserModel() {
        // Test GoogleUser model
        let tokens = AuthTokens(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: "id-token",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let googleUser = GoogleUser(
            id: "google-user-id",
            email: "google@example.com",
            name: "Google User",
            profileImageURL: URL(string: "https://example.com/avatar.jpg"),
            tokens: tokens
        )

        XCTAssertEqual(googleUser.id, "google-user-id")
        XCTAssertEqual(googleUser.email, "google@example.com")
        XCTAssertEqual(googleUser.name, "Google User")
        XCTAssertNotNil(googleUser.profileImageURL)
        XCTAssertEqual(googleUser.tokens.accessToken, "access-token")
    }

    // MARK: - Configuration Tests

    func testGoogleServiceInfoPlistExists() {
        // Test that configuration file exists
        let bundle = Bundle.main
        let plistPath = bundle.path(forResource: "GoogleService-Info", ofType: "plist")

        XCTAssertNotNil(plistPath, "GoogleService-Info.plist should exist in main bundle")

        if let path = plistPath {
            let plist = NSDictionary(contentsOfFile: path)
            XCTAssertNotNil(plist, "GoogleService-Info.plist should be valid")

            let clientId = plist?["CLIENT_ID"] as? String
            XCTAssertNotNil(clientId, "CLIENT_ID should be present in plist")
            XCTAssertFalse(clientId?.isEmpty ?? true, "CLIENT_ID should not be empty")
        }
    }

    // MARK: - Privacy Compliance Tests

    func testUserProfileDataExport() {
        // Test user profile data export functionality
        let profileManager = UserProfileManager()
        let exportData = profileManager.exportUserProfileData()

        XCTAssertNotNil(exportData, "Should be able to export user data")
        XCTAssertNotNil(exportData.exportDate, "Export should have export date")
    }

    @MainActor
    func testGDPRCompliantDataExport() {
        // Test GDPR compliant data export
        let profileManager = UserProfileManager()
        let exportDict = profileManager.exportAllUserData()

        XCTAssertTrue(exportDict.keys.contains("userProfile"), "Should contain user profile data")
        XCTAssertTrue(exportDict.keys.contains("exportDate"), "Should contain export date")

        if let userProfile = exportDict["userProfile"] as? [String: Any] {
            XCTAssertTrue(userProfile.keys.contains("id"), "Should contain user ID")
            XCTAssertTrue(userProfile.keys.contains("email"), "Should contain user email")
            XCTAssertTrue(userProfile.keys.contains("preferences"), "Should contain user preferences")
        }
    }

    // MARK: - Performance Tests

    func testAuthenticationModelPerformance() {
        // Test performance of authentication model creation
        measure {
            for _ in 0..<100 {
                let tokens = AuthTokens(
                    accessToken: "test-token",
                    refreshToken: "test-refresh",
                    idToken: "test-id",
                    expiresAt: Date().addingTimeInterval(3600)
                )

                let googleUser = GoogleUser(
                    id: "user-id",
                    email: "user@example.com",
                    name: "Test User",
                    profileImageURL: nil,
                    tokens: tokens
                )

                // Access properties to ensure they're evaluated
                _ = googleUser.id
                _ = googleUser.email
                _ = googleUser.tokens.accessToken
            }
        }
    }
}