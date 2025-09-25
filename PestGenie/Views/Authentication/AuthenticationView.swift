import SwiftUI
import GoogleSignInSwift
import LocalAuthentication

/// Main authentication view with enhanced Google Sign-In integration and biometric authentication
struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var biometricManager = BiometricAuthenticationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var showingPrivacySheet = false
    @State private var showingError = false
    @State private var showingBiometricSetup = false
    @State private var currentAuthStep: AuthenticationStep = .initial
    @State private var authenticationMessage = ""

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("PestGenie")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Secure Pest Control Management")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Authentication Section
                VStack(spacing: 24) {
                    // Network Status Indicator
                    if !networkMonitor.isConnected {
                        NetworkStatusView()
                    }

                    // Biometric Quick Unlock (for returning users)
                    if biometricManager.isEnabled && !authManager.isAuthenticated {
                        BiometricQuickUnlockButton {
                            await handleBiometricQuickUnlock()
                        }
                    }

                    // Primary Authentication Options
                    VStack(spacing: 16) {
                        // Official Google Sign-In Button with proper branding
                        GoogleSignInButton(action: {
                            Task { await handleGoogleSignIn() }
                        })
                        .frame(height: 50)
                        .disabled(authManager.isLoading || !networkMonitor.isConnected)
                        .opacity((authManager.isLoading || !networkMonitor.isConnected) ? 0.7 : 1.0)

                        // Authentication Status Message
                        if !authenticationMessage.isEmpty {
                            AuthenticationStatusView(message: authenticationMessage)
                        }

                        // Loading State with Progress
                        if authManager.isLoading {
                            AuthenticationLoadingView(step: currentAuthStep)
                        }
                    }

                    // Privacy and Trust Indicators
                    VStack(spacing: 12) {
                        // Trust Indicators Row
                        HStack(spacing: 20) {
                            TrustIndicatorView(icon: "lock.shield.fill", text: "SOC 2 Compliant")
                            TrustIndicatorView(icon: "checkmark.seal.fill", text: "GDPR Ready")
                        }

                        // Privacy Policy Link
                        Button("Privacy Policy & Terms") {
                            showingPrivacySheet = true
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .underline()
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Security Features
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        SecurityFeatureItem(
                            icon: "lock.shield",
                            title: "End-to-End Encryption"
                        )

                        SecurityFeatureItem(
                            icon: "faceid",
                            title: "Biometric Security"
                        )
                    }

                    HStack(spacing: 16) {
                        SecurityFeatureItem(
                            icon: "icloud.and.arrow.up",
                            title: "Secure Cloud Sync"
                        )

                        SecurityFeatureItem(
                            icon: "checkmark.shield",
                            title: "Privacy Compliant"
                        )
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .sheet(isPresented: $showingPrivacySheet) {
            PrivacyConsentView()
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("Try Again") {
                Task { await handleRetryAuthentication() }
            }
            Button("Cancel") {
                authManager.lastError = nil
                currentAuthStep = .initial
                authenticationMessage = ""
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(authManager.lastError?.localizedDescription ?? "An unknown error occurred")

                if let recoveryAction = getRecoveryAction() {
                    Text("Suggestion: \(recoveryAction)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingBiometricSetup) {
            EnhancedBiometricSetupView()
        }
        .onChange(of: authManager.lastError) { error in
            showingError = error != nil
            if error != nil {
                currentAuthStep = .error
                authenticationMessage = error?.localizedDescription ?? "An error occurred"
            }
        }
        .onChange(of: authManager.isAuthenticated) { authenticated in
            if authenticated {
                currentAuthStep = .completed
                authenticationMessage = "Welcome to PestGenie!"
            }
        }
        .onAppear {
            Task {
                await biometricManager.checkBiometricAvailability()
            }
        }
        .task {
            await authManager.initialize()

            // Check for returning user with biometric setup
            if biometricManager.isEnabled && !authManager.isAuthenticated {
                currentAuthStep = .biometricAvailable
                authenticationMessage = "Welcome back! Use \(biometricManager.biometricType.displayName) for quick access."
            }
        }
    }

    // MARK: - Authentication Methods

    private func handleGoogleSignIn() async {
        currentAuthStep = .initiating
        authenticationMessage = "Connecting to Google..."

        await authManager.signInWithGoogle()

        // If successful and biometric is available but not enabled, offer setup
        if authManager.isAuthenticated && biometricManager.isAvailable && !biometricManager.isEnabled {
            showingBiometricSetup = true
        }
    }

    private func handleBiometricQuickUnlock() async {
        currentAuthStep = .biometricAuth
        authenticationMessage = "Authenticating with \(biometricManager.biometricType.displayName)..."

        let result = await biometricManager.quickUnlock()

        if result.isSuccess {
            // Try to restore previous session
            await authManager.initialize()
            currentAuthStep = .completed
            authenticationMessage = "Welcome back!"
        } else {
            currentAuthStep = .initial
            if let error = result.error {
                authenticationMessage = error.localizedDescription
            }
        }
    }

    private func handleRetryAuthentication() async {
        authManager.lastError = nil
        currentAuthStep = .initial
        authenticationMessage = ""

        // Retry the last attempted authentication method
        if biometricManager.isEnabled {
            await handleBiometricQuickUnlock()
        } else {
            await handleGoogleSignIn()
        }
    }

    private func getRecoveryAction() -> String? {
        guard let error = authManager.lastError else { return nil }

        switch error {
        case .networkError:
            return "Check your internet connection and try again"
        case .userDeniedPermissions:
            return "Grant necessary permissions in Settings"
        case .securityError:
            return "Ensure your device security settings allow app access"
        default:
            return "Try signing in again or contact support"
        }
    }
}

// MARK: - Supporting Views

struct SecurityFeatureItem: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Preview

// MARK: - Enhanced Authentication Components


struct BiometricQuickUnlockButton: View {
    @StateObject private var biometricManager = BiometricAuthenticationManager.shared
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: biometricManager.biometricType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)

                Text("Quick Unlock with \(biometricManager.biometricType.displayName)")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .animation(.spring(response: 0.5), value: biometricManager.biometricType)
    }
}

struct AuthenticationLoadingView: View {
    let step: AuthenticationStep

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text(loadingMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var loadingMessage: String {
        switch step {
        case .initial:
            return "Preparing authentication..."
        case .initiating:
            return "Connecting to Google services..."
        case .authenticating:
            return "Verifying your credentials..."
        case .verifying:
            return "Completing sign-in process..."
        case .biometricAuth:
            return "Authenticating with biometrics..."
        case .biometricAvailable:
            return "Biometric authentication is ready"
        case .completed:
            return "Welcome to PestGenie!"
        case .error:
            return "Authentication failed"
        }
    }
}

struct AuthenticationStatusView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.white.opacity(0.15))
            )
            .animation(.easeInOut, value: message)
    }
}

struct NetworkStatusView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("No internet connection")
                .font(.caption)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.orange.opacity(0.2))
        )
    }
}

struct TrustIndicatorView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.green)

            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct EnhancedBiometricSetupView: View {
    @StateObject private var biometricManager = BiometricAuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabling = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: biometricManager.biometricType.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .symbolEffect(.pulse)

                    Text("Enhanced Security")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enable \(biometricManager.biometricType.displayName) for quick and secure access to your PestGenie account.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                VStack(spacing: 16) {
                    FeatureBulletPoint(
                        icon: "lock.shield.fill",
                        title: "Secure Authentication",
                        description: "Your biometric data never leaves your device"
                    )

                    FeatureBulletPoint(
                        icon: "bolt.fill",
                        title: "Quick Access",
                        description: "Sign in instantly without entering passwords"
                    )

                    FeatureBulletPoint(
                        icon: "checkmark.seal.fill",
                        title: "Privacy First",
                        description: "Complete control over your authentication preferences"
                    )
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await enableBiometricAuth() }
                    } label: {
                        HStack {
                            if isEnabling {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isEnabling ? "Setting up..." : "Enable \(biometricManager.biometricType.displayName)")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.blue)
                        .foregroundColor(.white)
                        .font(.system(.body, weight: .semibold))
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .disabled(isEnabling)

                    Button("Skip for Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Security Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func enableBiometricAuth() async {
        isEnabling = true
        let result = await biometricManager.enableBiometricAuthentication()
        isEnabling = false

        if result.isSuccess {
            dismiss()
        }
        // Error handling would show an alert here
    }
}

struct FeatureBulletPoint: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Authentication State

enum AuthenticationStep {
    case initial
    case initiating
    case authenticating
    case verifying
    case biometricAuth
    case biometricAvailable
    case completed
    case error
}

// MARK: - Previews

#Preview {
    AuthenticationView()
}

#Preview("Biometric Setup") {
    EnhancedBiometricSetupView()
}