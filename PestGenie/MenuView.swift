import SwiftUI

/// Comprehensive side menu for PestGenie navigation.
/// Provides access to all major app features, settings, and support resources.
/// Follows iOS Human Interface Guidelines and includes accessibility features.
struct MenuView: View {
    @Binding var isPresented: Bool
    @Binding var selectedMenuItem: MenuItem?
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @State private var showingAppInfo = false
    @State private var showingLogout = false

    let technicianName: String
    let technicianId: String
    let companyName: String

    init(
        isPresented: Binding<Bool>,
        selectedMenuItem: Binding<MenuItem?>,
        technicianName: String = "John Smith",
        technicianId: String = "T-12345",
        companyName: String = "PestControl Pro"
    ) {
        self._isPresented = isPresented
        self._selectedMenuItem = selectedMenuItem
        self.technicianName = technicianName
        self.technicianId = technicianId
        self.companyName = companyName
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
                primaryNavigationSection

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                featuresSection

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                settingsSection

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
                // Profile avatar
                ZStack {
                    Circle()
                        .fill(PestGenieDesignSystem.Colors.primary)
                        .frame(width: 60, height: 60)

                    Text(technicianName.prefix(2).uppercased())
                        .font(PestGenieDesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // User info
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(technicianName)
                        .font(PestGenieDesignSystem.Typography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text("ID: \(technicianId)")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text(companyName)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                }

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

    // MARK: - Primary Navigation

    private var primaryNavigationSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Navigation")

            menuItem(
                title: "Dashboard",
                icon: "house.fill",
                badge: nil,
                item: .dashboard
            )

            menuItem(
                title: "Today's Route",
                icon: "map.fill",
                badge: routeViewModel.remainingJobsCount > 0 ? "\(routeViewModel.remainingJobsCount)" : nil,
                item: .route
            )

            menuItem(
                title: "Equipment",
                icon: "wrench.and.screwdriver.fill",
                badge: nil,
                item: .equipment
            )

            menuItem(
                title: "Chemicals",
                icon: "testtube.2",
                badge: nil,
                item: .chemicals
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Features")

            menuItem(
                title: "Customer Communication",
                icon: "message.fill",
                badge: "3",
                item: .customerCommunication
            )

            menuItem(
                title: "Reports & Documentation",
                icon: "doc.text.fill",
                badge: nil,
                item: .reportsDocumentation
            )

            menuItem(
                title: "Analytics Dashboard",
                icon: "chart.bar.fill",
                badge: nil,
                item: .analyticsDashboard
            )

            menuItem(
                title: "Training & Resources",
                icon: "graduationcap.fill",
                badge: "New",
                item: .trainingResources
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Settings")

            menuItem(
                title: "Preferences",
                icon: "gearshape.fill",
                badge: nil,
                item: .settingsPreferences
            )

            menuItem(
                title: "Notifications",
                icon: "bell.fill",
                badge: nil,
                item: .notifications
            )

            menuItem(
                title: "Sync & Backup",
                icon: "icloud.fill",
                badge: nil,
                item: .syncBackup
            )
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            sectionHeader("Support")

            menuItem(
                title: "Help & Support",
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

            menuItem(
                title: "Emergency Contacts",
                icon: "phone.badge.plus",
                badge: nil,
                item: .emergencyContacts
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
            .buttonStyle(PlainButtonStyle())

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
            .buttonStyle(PlainButtonStyle())
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
        .accessibilityHint("Navigate to \(title)")
        .accessibilityValue(badge != nil ? "Has \(badge!) notifications" : "")
    }

    // MARK: - App Info Sheet

    private var appInfoSheet: some View {
        NavigationView {
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
                        appInfoRow("Company", companyName)
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
        // Implement logout functionality
        print("Logging out user...")
        // In a real app, this would clear user data, tokens, etc.
    }
}

// MARK: - Menu Item Enum

enum MenuItem: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case route = "route"
    case equipment = "equipment"
    case chemicals = "chemicals"
    case customerCommunication = "customer_communication"
    case reportsDocumentation = "reports_documentation"
    case analyticsDashboard = "analytics_dashboard"
    case trainingResources = "training_resources"
    case settingsPreferences = "settings_preferences"
    case notifications = "notifications"
    case syncBackup = "sync_backup"
    case helpSupport = "help_support"
    case sendFeedback = "send_feedback"
    case emergencyContacts = "emergency_contacts"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .route: return "Route"
        case .equipment: return "Equipment"
        case .chemicals: return "Chemicals"
        case .customerCommunication: return "Customer Communication"
        case .reportsDocumentation: return "Reports & Documentation"
        case .analyticsDashboard: return "Analytics Dashboard"
        case .trainingResources: return "Training & Resources"
        case .settingsPreferences: return "Settings & Preferences"
        case .notifications: return "Notifications"
        case .syncBackup: return "Sync & Backup"
        case .helpSupport: return "Help & Support"
        case .sendFeedback: return "Send Feedback"
        case .emergencyContacts: return "Emergency Contacts"
        }
    }
}

// MARK: - Preview

#Preview("Menu View") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        MenuView(
            isPresented: .constant(true),
            selectedMenuItem: .constant(nil),
            technicianName: "John Smith",
            technicianId: "T-12345",
            companyName: "PestControl Pro"
        )
        .environmentObject(RouteViewModel())
    }
}

#Preview("Menu View Dark Mode") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        MenuView(
            isPresented: .constant(true),
            selectedMenuItem: .constant(nil),
            technicianName: "Sarah Johnson",
            technicianId: "T-67890",
            companyName: "Elite Pest Solutions"
        )
        .environmentObject(RouteViewModel())
        .preferredColorScheme(.dark)
    }
}