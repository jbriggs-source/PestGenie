import SwiftUI

/// Comprehensive side menu for PestGenie navigation.
/// Provides access to all major app features, settings, and support resources.
/// Follows iOS Human Interface Guidelines and includes accessibility features.
/// Now integrated with dynamic authentication and profile data.
struct MenuView: View {
    @Binding var isPresented: Bool
    @Binding var selectedMenuItem: MenuItem?
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    @EnvironmentObject private var userProfileManager: UserProfileManager
    @State private var showingAppInfo = false
    @State private var showingLogout = false

    // Demo fallback values - used when no user is authenticated
    private let demoTechnicianName = "John Smith"
    private let demoTechnicianId = "T-12345"
    private let demoCompanyName = "PestControl Pro"

    init(
        isPresented: Binding<Bool>,
        selectedMenuItem: Binding<MenuItem?>
    ) {
        self._isPresented = isPresented
        self._selectedMenuItem = selectedMenuItem
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Menu content
                menuContent
                    .frame(width: min(300, geometry.size.width * 0.8))
                    .background(PestGenieDesignSystem.Colors.background)
                    .clipped()

                // Tap-to-dismiss area
                Color.black.opacity(0.3)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .transition(.asymmetric(
            insertion: .move(edge: .leading),
            removal: .move(edge: .leading)
        ))
        .sheet(isPresented: $showingAppInfo) {
            appInfoSheet
        }
        .alert("Sign Out", isPresented: $showingLogout) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Menu Content

    private var menuContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header section
                menuHeader

                // Navigation sections
                quickActionsSection

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                safetyResourcesSection

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                accountSettingsSection

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                supportSection

                Spacer(minLength: PestGenieDesignSystem.Spacing.xxl)

                // Footer
                menuFooter
            }
            .padding(.bottom, PestGenieDesignSystem.Spacing.xl)
        }
    }

    // MARK: - Header Section

    private var menuHeader: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PestGenieDesignSystem.Colors.surface)
                        .clipShape(Circle())
                }
            }
            .padding(.top, PestGenieDesignSystem.Spacing.md)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

            // User profile section
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Profile avatar - using dynamic profile picture or initials
                if authenticationManager.isAuthenticated {
                    UserProfilePictureView(
                        profileImageURL: currentUser?.profileImageURL ?? userProfileManager.currentProfile?.profileImageURL,
                        size: 60,
                        fallbackColor: PestGenieDesignSystem.Colors.primary
                    )
                    .overlay(
                        // Custom profile image overlay if available
                        Group {
                            if let customImageData = userProfileManager.currentProfile?.customProfileImageData,
                               let uiImage = UIImage(data: customImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            }
                        }
                    )
                } else {
                    // Demo avatar with initials
                    ZStack {
                        Circle()
                            .fill(PestGenieDesignSystem.Colors.primary)
                            .frame(width: 60, height: 60)

                        Text(displayName.prefix(2).uppercased())
                            .font(PestGenieDesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }

                // User info
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(displayName)
                        .font(PestGenieDesignSystem.Typography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("User name: \(displayName)")

                    Text("ID: \(displayId)")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .accessibilityLabel("User ID: \(displayId)")

                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Text(displayCompany)
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                            .accessibilityLabel("Company: \(displayCompany)")

                        // Authentication status indicator
                        if authenticationManager.isAuthenticated {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(PestGenieDesignSystem.Colors.success)
                                .accessibilityLabel("Authenticated user")
                                .accessibilityHint("User is signed in and data is synced")
                        } else {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(PestGenieDesignSystem.Colors.warning)
                                .accessibilityLabel("Demo mode")
                                .accessibilityHint("Using demo data, sign in for personalized experience")
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityUserInfoLabel)
                .accessibilityHint("User profile information. Tap to edit profile if authenticated.")

                Spacer()
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
            .padding(.bottom, PestGenieDesignSystem.Spacing.lg)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    PestGenieDesignSystem.Colors.primary.opacity(0.1),
                    PestGenieDesignSystem.Colors.background
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Quick Actions")

            menuItem(
                title: "Customer Communications",
                icon: "message.circle.fill",
                badge: customerCommunicationsBadge,
                item: .customerCommunication
            )

            menuItem(
                title: "Call Dispatch",
                icon: "phone.circle.fill",
                badge: nil,
                item: .callDispatch
            )

            menuItem(
                title: "Emergency",
                icon: "exclamationmark.triangle.fill",
                badge: nil,
                item: .emergency
            )

            menuItem(
                title: "Equipment Status",
                icon: "wrench.and.screwdriver.fill",
                badge: equipmentStatusBadge,
                item: .equipmentStatus
            )

            menuItem(
                title: "Weather Conditions",
                icon: "cloud.sun.fill",
                badge: nil,
                item: .weatherConditions
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Safety & Resources Section

    private var safetyResourcesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Safety & Resources")

            menuItem(
                title: "Safety Checklist",
                icon: "checkmark.shield.fill",
                badge: nil,
                item: .safetyChecklist
            )

            menuItem(
                title: "Emergency Protocols",
                icon: "cross.circle.fill",
                badge: nil,
                item: .emergencyProtocols
            )

            menuItem(
                title: "Training Resources",
                icon: "graduationcap.fill",
                badge: "New",
                item: .trainingResources
            )

            menuItem(
                title: "Performance Metrics",
                icon: "chart.bar.fill",
                badge: performanceMetricsBadge,
                item: .performanceMetrics
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Account & Settings Section

    private var accountSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Account & Settings")

            // Sync status with real-time indicator
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                Image(systemName: syncStatusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(syncStatusColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text("Sync Status")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(syncStatusText)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                if !routeViewModel.isOnline && routeViewModel.pendingActions.count > 0 {
                    Image(systemName: "clock")
                        .foregroundColor(PestGenieDesignSystem.Colors.warning)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
            .padding(.vertical, PestGenieDesignSystem.Spacing.sm)

            menuItem(
                title: "Preferences",
                icon: "gearshape.fill",
                badge: nil,
                item: .settingsPreferences
            )

            menuItem(
                title: "Notifications",
                icon: "bell.fill",
                badge: notificationsBadge,
                item: .notifications
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Support")

            menuItem(
                title: "Help & Documentation",
                icon: "questionmark.circle.fill",
                badge: nil,
                item: .helpSupport
            )

            menuItem(
                title: "Send Feedback",
                icon: "envelope.fill",
                badge: nil,
                item: .sendFeedback
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Menu Footer

    private var menuFooter: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.md) {
            // App info button
            Button(action: {
                showingAppInfo = true
            }) {
                HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text("PestGenie v2.1.0")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Sign out button
            Button(action: {
                showingLogout = true
            }) {
                HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(PestGenieDesignSystem.Colors.error)
                    Text("Sign Out")
                        .font(PestGenieDesignSystem.Typography.labelMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.error)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(PestGenieDesignSystem.Colors.error.opacity(0.1))
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(PestGenieDesignSystem.Typography.labelSmall)
            .fontWeight(.semibold)
            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
            .padding(.top, PestGenieDesignSystem.Spacing.xs)
    }

    private func menuItem(
        title: String,
        icon: String,
        badge: String?,
        item: MenuItem
    ) -> some View {
        Button(action: {
            selectedMenuItem = item
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    .frame(width: 24, height: 24)

                // Title
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(.white)
                        .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(badge == "New" ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.accent)
                        )
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
            .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Navigate to \(title)")
        .accessibilityValue(badge != nil ? "Has \(badge!) notifications" : "")
    }

    // MARK: - App Info Sheet

    private var appInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    // App icon and info
                    VStack(spacing: PestGenieDesignSystem.Spacing.md) {
                        // App icon placeholder
                        RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.lg)
                            .fill(PestGenieDesignSystem.Colors.primary)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "bug.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )

                        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            Text("PestGenie")
                                .font(PestGenieDesignSystem.Typography.titleLarge)
                                .fontWeight(.bold)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            Text("Professional Pest Control Assistant")
                                .font(PestGenieDesignSystem.Typography.bodyMedium)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)

                            Text("Version 2.1.0 (Build 105)")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, PestGenieDesignSystem.Spacing.xl)

                    // App details
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                        appInfoRow("Company", displayCompany)
                        appInfoRow("Device", "iPhone 15 Pro")
                        appInfoRow("iOS Version", "17.5")
                        appInfoRow("Last Update", "September 15, 2024")
                        appInfoRow("License", "Enterprise License")
                    }
                    .pestGenieCard()
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                    // Copyright
                    Text("© 2024 PestGenie Technologies. All rights reserved.")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, PestGenieDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("About PestGenie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAppInfo = false
                    }
                }
            }
        }
    }

    private func appInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Helper Methods

    private func performLogout() {
        Task {
            await authenticationManager.signOut()
            // Menu will automatically update due to @EnvironmentObject binding
        }
    }

    // MARK: - Computed Properties for Dynamic User Data

    /// Current authenticated user from AuthenticationManager
    private var currentUser: AuthenticatedUser? {
        authenticationManager.currentUser
    }

    /// Current user profile from UserProfileManager
    private var currentProfile: UserProfile? {
        userProfileManager.currentProfile
    }

    /// Display name with fallback logic
    private var displayName: String {
        if authenticationManager.isAuthenticated {
            // Try profile name first, then authenticated user name, then email prefix
            if let profileName = currentProfile?.name, !profileName.isEmpty {
                return profileName
            } else if let userName = currentUser?.name, !userName.isEmpty {
                return userName
            } else if let email = currentUser?.email {
                return String(email.prefix(while: { $0 != "@" }))
            }
        }
        return demoTechnicianName
    }

    /// Display ID with fallback logic
    private var displayId: String {
        if authenticationManager.isAuthenticated {
            // Try employee ID from work info, then user ID
            if let employeeId = currentProfile?.workInfo.employeeId, !employeeId.isEmpty {
                return employeeId
            } else if let userId = currentUser?.id {
                return "U-" + String(userId.prefix(8))
            }
        }
        return demoTechnicianId
    }

    /// Display company with fallback logic
    private var displayCompany: String {
        if authenticationManager.isAuthenticated {
            // Try department from work info first
            if let department = currentProfile?.workInfo.department, !department.isEmpty {
                return department
            }
            // Could also check for organization from authentication
            return "PestControl Pro" // Default for authenticated users
        }
        return demoCompanyName
    }

    /// Comprehensive accessibility label for user information section
    private var accessibilityUserInfoLabel: String {
        let authStatus = authenticationManager.isAuthenticated ? "Authenticated user" : "Demo mode"
        return "\(displayName), ID \(displayId), \(displayCompany), \(authStatus)"
    }

    // MARK: - Dynamic Badge Properties

    /// Equipment status badge based on equipment health
    private var equipmentStatusBadge: String? {
        // Mock implementation - in real app, would check equipment status
        let criticalEquipment = 2 // Example: 2 pieces of equipment need attention
        return criticalEquipment > 0 ? "\(criticalEquipment)" : nil
    }

    /// Customer communications badge for unread messages
    private var customerCommunicationsBadge: String? {
        // Mock implementation - in real app, would show unread messages count
        let unreadMessages = 3 // Example: 3 unread customer messages
        return unreadMessages > 0 ? "\(unreadMessages)" : nil
    }

    /// Performance metrics badge for technician stats
    private var performanceMetricsBadge: String? {
        // Mock implementation - could show unread performance updates
        return routeViewModel.completedJobsCount > 5 ? "Good" : nil
    }

    /// Notifications badge count
    private var notificationsBadge: String? {
        // Mock implementation - in real app, would check notification count
        let unreadNotifications = 3
        return unreadNotifications > 0 ? "\(unreadNotifications)" : nil
    }

    // MARK: - Sync Status Properties

    /// Icon for current sync status
    private var syncStatusIcon: String {
        if !routeViewModel.isOnline {
            return "wifi.slash"
        } else {
            return "checkmark.icloud.fill"
        }
    }

    /// Color for sync status icon
    private var syncStatusColor: Color {
        if !routeViewModel.isOnline {
            return PestGenieDesignSystem.Colors.warning
        } else {
            return PestGenieDesignSystem.Colors.success
        }
    }

    /// Text description of sync status
    private var syncStatusText: String {
        if !routeViewModel.isOnline {
            return "Offline mode - \(routeViewModel.pendingActions.count) actions queued"
        } else {
            let lastSync = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            return "Last synced: \(lastSync)"
        }
    }
}

// MARK: - Menu Item Enum

enum MenuItem: String, CaseIterable, Identifiable {
    // Quick Actions
    case callDispatch = "call_dispatch"
    case emergency = "emergency"
    case equipmentStatus = "equipment_status"
    case weatherConditions = "weather_conditions"

    // Safety & Resources
    case safetyChecklist = "safety_checklist"
    case emergencyProtocols = "emergency_protocols"
    case trainingResources = "training_resources"
    case performanceMetrics = "performance_metrics"

    // Account & Settings
    case settingsPreferences = "settings_preferences"
    case notifications = "notifications"

    // Support
    case helpSupport = "help_support"
    case sendFeedback = "send_feedback"

    // Legacy items (keep for backward compatibility)
    case dashboard = "dashboard"
    case route = "route"
    case equipment = "equipment"
    case chemicals = "chemicals"
    case customerCommunication = "customer_communication"
    case reportsDocumentation = "reports_documentation"
    case analyticsDashboard = "analytics_dashboard"
    case syncBackup = "sync_backup"
    case emergencyContacts = "emergency_contacts"
    case demoControls = "demo_controls"

    var id: String { rawValue }

    var title: String {
        switch self {
        // Quick Actions
        case .callDispatch: return "Call Dispatch"
        case .emergency: return "Emergency"
        case .equipmentStatus: return "Equipment Status"
        case .weatherConditions: return "Weather Conditions"

        // Safety & Resources
        case .safetyChecklist: return "Safety Checklist"
        case .emergencyProtocols: return "Emergency Protocols"
        case .trainingResources: return "Training & Resources"
        case .performanceMetrics: return "Performance Metrics"

        // Account & Settings
        case .settingsPreferences: return "Settings & Preferences"
        case .notifications: return "Notifications"

        // Support
        case .helpSupport: return "Help & Support"
        case .sendFeedback: return "Send Feedback"

        // Legacy items
        case .dashboard: return "Dashboard"
        case .route: return "Route"
        case .equipment: return "Equipment"
        case .chemicals: return "Chemicals"
        case .customerCommunication: return "Customer Communication"
        case .reportsDocumentation: return "Reports & Documentation"
        case .analyticsDashboard: return "Analytics Dashboard"
        case .syncBackup: return "Sync & Backup"
        case .emergencyContacts: return "Emergency Contacts"
        case .demoControls: return "Demo Controls"
        }
    }
}

// MARK: - Preview

#Preview("Menu View - Authenticated") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        MenuView(
            isPresented: .constant(true),
            selectedMenuItem: .constant(nil)
        )
        .environmentObject(RouteViewModel())
        .environmentObject({
            let authManager = AuthenticationManager.shared
            authManager.isAuthenticated = true
            authManager.currentUser = AuthenticatedUser(
                id: "user123",
                email: "john.smith@pestcontrol.com",
                name: "John Smith",
                profileImageURL: URL(string: "https://example.com/profile.jpg"),
                createdAt: Date(),
                lastSignInAt: Date()
            )
            return authManager
        }())
        .environmentObject({
            let profileManager = UserProfileManager()
            profileManager.currentProfile = UserProfile(
                id: "user123",
                email: "john.smith@pestcontrol.com",
                name: "John Smith",
                profileImageURL: URL(string: "https://example.com/profile.jpg"),
                customProfileImageData: nil,
                createdAt: Date(),
                updatedAt: Date(),
                lastSyncDate: Date(),
                preferences: UserPreferences(),
                workInfo: WorkInformation(
                    jobTitle: "Senior Technician",
                    department: "PestControl Pro",
                    employeeId: "T-12345",
                    startDate: Date(),
                    certifications: []
                ),
                profileCompleteness: ProfileCompleteness(score: 0.8, missingFields: [], lastCalculated: Date())
            )
            return profileManager
        }())
    }
}

#Preview("Menu View - Demo Mode") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        MenuView(
            isPresented: .constant(true),
            selectedMenuItem: .constant(nil)
        )
        .environmentObject(RouteViewModel())
        .environmentObject({
            let authManager = AuthenticationManager.shared
            authManager.isAuthenticated = false
            authManager.currentUser = nil
            return authManager
        }())
        .environmentObject(UserProfileManager())
        .preferredColorScheme(.dark)
    }
}