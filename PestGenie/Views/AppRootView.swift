import SwiftUI
import GoogleSignIn

/// Root view that manages authentication state and app navigation
struct AppRootView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var complianceManager = AppStoreComplianceManager.shared
    @StateObject private var routeViewModel = RouteViewModel()
    @StateObject private var locationManager = LocationManager.shared

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Main dashboard interface (no more demo toggle)
                MainDashboardView()
                    .environmentObject(authManager)
                    .environmentObject(routeViewModel)
                    .environmentObject(locationManager)
            } else {
                // Authentication flow
                AuthenticationView()
                    .environmentObject(authManager)
            }
        }
        .onOpenURL { url in
            // Handle Google Sign-In URL callbacks
            _ = GoogleSignInProvider().handleURL(url)
        }
        .task {
            // Initialize authentication system
            await authManager.initialize()

            // Set authentication manager on route view model
            await routeViewModel.setAuthenticationManager(authManager)

            // Check App Store compliance
            let complianceResult = complianceManager.validateAppStoreCompliance()
            if !complianceResult.isCompliant {
                // Handle compliance issues if needed
                print("⚠️ App Store compliance issues detected: \(complianceResult.issues)")
            }
        }
    }
}

#Preview {
    AppRootView()
}