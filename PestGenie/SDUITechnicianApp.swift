import SwiftUI
import GoogleSignIn

/// Entry point for the SDUI Technician mobile application. The app features an
/// engaging home dashboard with quick access to routes, equipment, chemicals,
/// and profile management. The UI configuration can be server-driven via JSON
/// files while maintaining domain data through view models.
@main
struct SDUITechnicianApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onAppear {
                    configureGoogleSignIn()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private func configureGoogleSignIn() {
        let firebaseConfig = FirebaseConfig.shared

        // Validate configuration
        let validation = firebaseConfig.validateConfiguration()
        if !validation.isValid {
            print("❌ Firebase Configuration Issues:")
            validation.issues.forEach { print("  - \($0)") }
        }

        // Configure Google Sign-In
        if !firebaseConfig.configureGoogleSignIn() {
            print("❌ Failed to configure Google Sign-In")
            print("📝 Please ensure you have a valid Firebase configuration file:")
            print("   - Development: GoogleService-Info-Dev.plist")
            print("   - Production: GoogleService-Info.plist")
            print("   - Replace template values with actual Firebase credentials")
        }
    }
}