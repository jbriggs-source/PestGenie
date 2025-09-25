import XCTest
@testable import PestGenie

/// Tests for Google Sign-In authentication integration
final class GoogleAuthenticationIntegrationTests: XCTestCase {

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
    func testAuthenticationManagerInitialization() {
        XCTAssertNotNil(authManager, "AuthenticationManager should initialize")
        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated initially")
        XCTAssertFalse(authManager.isLoading, "Should not be loading initially")
        XCTAssertNil(authManager.currentUser, "Should have no current user initially")
        XCTAssertNil(authManager.lastError, "Should have no error initially")
    }

    func testGoogleSignInProviderInitialization() {
        let provider = GoogleSignInProvider()
        XCTAssertNotNil(provider, "GoogleSignInProvider should initialize")
    }

    func testUserProfileManagerInitialization() {
        let profileManager = UserProfileManager()
        XCTAssertNotNil(profileManager, "UserProfileManager should initialize")
        XCTAssertNil(profileManager.currentProfile, "Should have no current profile initially")
    }

    func testSessionManagerInitialization() {
        let sessionManager = SessionManager()
        XCTAssertNotNil(sessionManager, "SessionManager should initialize")
        XCTAssertNil(sessionManager.currentSessionInfo, "Should have no current session initially")
        XCTAssertEqual(sessionManager.sessionStatus, .inactive, "Session should be inactive initially")
    }

    // MARK: - Authentication Models Tests

    func testAuthenticationErrorEquality() {
        let error1 = AuthenticationError.userDeniedPermissions
        let error2 = AuthenticationError.userDeniedPermissions
        let error3 = AuthenticationError.invalidCredentials

        XCTAssertEqual(error1, error2, "Same authentication errors should be equal")
        XCTAssertNotEqual(error1, error3, "Different authentication errors should not be equal")
    }

    func testAuthTokensModel() {
        let tokens = AuthTokens(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            idToken: "test-id-token",
            expiresAt: Date().addingTimeInterval(3600)
        )

        XCTAssertEqual(tokens.accessToken, "test-access-token")
        XCTAssertEqual(tokens.refreshToken, "test-refresh-token")
        XCTAssertEqual(tokens.idToken, "test-id-token")
        XCTAssertTrue(tokens.expiresAt > Date())
    }

    func testUserProfileModel() {
        let preferences = UserPreferences()
        XCTAssertTrue(preferences.notificationsEnabled)
        XCTAssertTrue(preferences.locationSharingEnabled)
        XCTAssertTrue(preferences.dataBackupEnabled)
        XCTAssertTrue(preferences.biometricAuthEnabled)
        XCTAssertEqual(preferences.theme, .system)

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

    // MARK: - Integration Tests

    @MainActor
    func testAuthenticationFlow() async {
        // Test that authentication flow can be initiated
        // Note: This won't complete without actual Google credentials
        // but tests that the flow can start without crashing

        // This will fail due to missing configuration, but shouldn't crash
        await authManager.signInWithGoogle()

        // After failed sign in, should have error state
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(authManager.isLoading)
        // May or may not have an error depending on configuration
    }

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

    func testUserProfileExport() {
        let profileManager = UserProfileManager()
        let exportData = profileManager.exportUserProfileData()

        XCTAssertNotNil(exportData, "Should be able to export user data")
        XCTAssertEqual(exportData.id, "", "Empty export should have empty ID")
        XCTAssertEqual(exportData.email, "", "Empty export should have empty email")
        XCTAssertNotNil(exportData.exportDate, "Export should have export date")
    }

    func testGDPRCompliantDataExport() {
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
}

// MARK: - Performance Tests

extension GoogleAuthenticationIntegrationTests {

    func testAuthenticationModelPerformance() {
        measure {
            for _ in 0..<1000 {
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

                _ = googleUser.id
                _ = googleUser.email
                _ = googleUser.tokens.accessToken
            }
        }
    }
}