import SwiftUI

/// Optimized launch screen that displays immediately while app initializes
struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var opacity = 1.0

    var body: some View {
        ZStack {
            // Background gradient - uses simple colors for fast rendering
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.09, green: 0.63, blue: 0.52),
                    Color(red: 0.05, green: 0.40, blue: 0.35)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Logo/Icon placeholder - using SF Symbol for instant load
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Text("PestGenie")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Professional Pest Control")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .opacity(opacity)
        }
        .onAppear {
            isAnimating = true
        }
    }

    /// Fade out the launch screen
    func fadeOut(completion: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion()
        }
    }
}

/// Wrapper view that handles transition from launch to main app
struct LegacyAppRootView: View {
    @State private var showLaunchScreen = true
    @StateObject private var appInitializer = AppInitializer()
    @StateObject private var authManager = AuthenticationManager.shared

    let persistenceController = PersistenceController.shared

    var body: some View {
        ZStack {
            if !showLaunchScreen {
                MainDashboardView()
                    .environmentObject(authManager)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .transition(.opacity)
            }

            if showLaunchScreen {
                LaunchScreenView()
                    .transition(.opacity)
            }
        }
        .onReceive(appInitializer.$isInitialized) { initialized in
            if initialized {
                // Add small delay for smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}

/// Handles app initialization in background
class AppInitializer: ObservableObject {
    @Published var isInitialized = false
    private let performanceMonitor = StartupPerformanceMonitor.shared

    init() {
        performanceMonitor.markAppLaunchStart()
        performanceMonitor.markCheckpoint("AppInitializer created")
        performInitialization()
    }

    private func performInitialization() {
        Task {
            // Perform minimal critical initialization
            // Everything else is deferred to after launch
            performanceMonitor.markCheckpoint("Starting async initialization")

            // Small delay to ensure launch screen shows
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds (reduced from 0.5)

            await MainActor.run {
                self.performanceMonitor.markCheckpoint("Main UI ready")
                self.isInitialized = true
                self.performanceMonitor.markAppReady()
            }
        }
    }
}