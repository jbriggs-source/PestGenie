import SwiftUI

/// Professional skeleton loading screens for authentication and app initialization
struct SkeletonLoadingViews {
    // Empty struct to namespace the skeleton views
}

// MARK: - Authentication Skeleton

extension SkeletonLoadingViews {

    /// Skeleton screen shown during app initialization
    struct AuthenticationSkeleton: View {
        @State private var animationOffset: CGFloat = -1

        var body: some View {
            ZStack {
                // Background matching AuthenticationView
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // App Logo Skeleton
                    VStack(spacing: 16) {
                        SkeletonShape(width: 80, height: 80)
                            .clipShape(Circle())

                        SkeletonShape(width: 200, height: 30)
                        SkeletonShape(width: 280, height: 16)
                    }

                    Spacer()

                    // Authentication Button Skeleton
                    VStack(spacing: 24) {
                        SkeletonShape(width: nil, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 25))

                        SkeletonShape(width: 120, height: 12)
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    // Security Features Skeleton
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            SecurityFeatureSkeleton()
                            SecurityFeatureSkeleton()
                        }

                        HStack(spacing: 16) {
                            SecurityFeatureSkeleton()
                            SecurityFeatureSkeleton()
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
            }
            .onAppear {
                startSkeletonAnimation()
            }
        }

        private func startSkeletonAnimation() {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationOffset = 1
            }
        }
    }

    /// Skeleton for security feature items
    struct SecurityFeatureSkeleton: View {
        var body: some View {
            VStack(spacing: 8) {
                SkeletonShape(width: 24, height: 24)
                    .clipShape(Circle())

                SkeletonShape(width: 60, height: 10)
                SkeletonShape(width: 80, height: 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Profile Loading Skeleton

extension SkeletonLoadingViews {

    /// Skeleton shown while loading user profile data
    struct ProfileLoadingSkeleton: View {
        var body: some View {
            VStack(spacing: 20) {
                // Profile Image Skeleton
                SkeletonShape(width: 80, height: 80)
                    .clipShape(Circle())

                // Profile Info Skeleton
                VStack(spacing: 8) {
                    SkeletonShape(width: 180, height: 20)
                    SkeletonShape(width: 220, height: 16)
                    SkeletonShape(width: 160, height: 14)
                }

                // Settings Options Skeleton
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack {
                            SkeletonShape(width: 24, height: 24)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                SkeletonShape(width: 120, height: 14)
                                SkeletonShape(width: 200, height: 12)
                            }

                            Spacer()

                            SkeletonShape(width: 40, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Route Loading Skeleton

extension SkeletonLoadingViews {

    /// Skeleton shown while loading route data
    struct RouteLoadingSkeleton: View {
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { _ in
                        RouteItemSkeleton()
                    }
                }
                .padding()
            }
        }
    }

    /// Skeleton for individual route items
    struct RouteItemSkeleton: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonShape(width: 150, height: 16)
                        SkeletonShape(width: 200, height: 14)
                    }

                    Spacer()

                    SkeletonShape(width: 60, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Address and details
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(width: 250, height: 14)
                    SkeletonShape(width: 180, height: 12)
                }

                // Action buttons
                HStack(spacing: 12) {
                    SkeletonShape(width: 80, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    SkeletonShape(width: 100, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
    }
}

// MARK: - Base Skeleton Shape

/// Base skeleton shape with shimmer animation
struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var animationOffset: CGFloat = -1

    init(width: CGFloat?, height: CGFloat) {
        self.width = width
        self.height = height
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGray5),
                        Color(.systemGray4),
                        Color(.systemGray5)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : width)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                // Shimmer effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: animationOffset * (width ?? 300))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: animationOffset)
            )
            .onAppear {
                animationOffset = 1
            }
    }
}

// MARK: - Network Aware Components

/// Network status banner with retry functionality
struct NetworkStatusBanner: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    let onRetry: () async -> Void

    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Internet Connection")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Please check your connection and try again")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Retry") {
                        Task { await onRetry() }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Loading overlay with network awareness
struct NetworkAwareLoadingOverlay: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    let isLoading: Bool
    let message: String
    let onRetry: (() async -> Void)?

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    if networkMonitor.isConnected {
                        // Normal loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.blue)

                            Text(message)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        // Network disconnected state
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)

                            VStack(spacing: 8) {
                                Text("Connection Lost")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text("Waiting for internet connection to continue")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            if let onRetry = onRetry {
                                Button("Retry Now") {
                                    Task { await onRetry() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                )
                .padding(.horizontal, 32)
            }
        }
    }
}

/// Adaptive content view that shows skeleton while loading
struct AdaptiveContentView<Content: View, Skeleton: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let skeleton: () -> Skeleton

    var body: some View {
        ZStack {
            if isLoading {
                skeleton()
                    .transition(.opacity)
            } else {
                content()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Previews

#Preview("Authentication Skeleton") {
    SkeletonLoadingViews.AuthenticationSkeleton()
}

#Preview("Profile Skeleton") {
    SkeletonLoadingViews.ProfileLoadingSkeleton()
}

#Preview("Route Skeleton") {
    SkeletonLoadingViews.RouteLoadingSkeleton()
}

#Preview("Network Banner") {
    VStack {
        NetworkStatusBanner {
            // Retry action
        }
        Spacer()
    }
}