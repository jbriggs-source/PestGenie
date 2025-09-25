import SwiftUI
import GoogleSignIn

/// Root view that manages authentication state and app navigation
struct AppRootView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var complianceManager = AppStoreComplianceManager.shared
    @StateObject private var routeViewModel = RouteViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @AppStorage("demoMode") private var useDashboardView = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Demo toggle interface
                VStack(spacing: 0) {
                    // Demo mode toggle bar
                    HStack {
                        Text("Demo Mode:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Interface", selection: $useDashboardView) {
                            Text("SDUI Demo").tag(false)
                            Text("Dashboard").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .font(.caption)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))

                    // Main content based on selection
                    if useDashboardView {
                        // MainDashboard interface with profile pictures
                        MainDashboardView()
                            .environmentObject(authManager)
                            .environmentObject(routeViewModel)
                            .environmentObject(locationManager)
                    } else {
                        // SDUI interface with profile pictures
                        SDUIContentView()
                            .environmentObject(authManager)
                            .environmentObject(routeViewModel)
                            .environmentObject(locationManager)
                    }
                }
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