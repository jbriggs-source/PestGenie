import SwiftUI
import PhotosUI

/// Main dashboard view that combines the home dashboard content with bottom navigation.
/// This serves as the primary entry point after app launch, providing an engaging
/// overview of the technician's day and quick access to key features.
struct MainDashboardView: View {
    @StateObject private var routeViewModel = RouteViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var userProfileManager = UserProfileManager()
    @StateObject private var profileImageManager = ProfileImageManager()
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var selectedTab: NavigationTab = .home
    @State private var showingRouteView = false
    @State private var showingRouteStartView = false
    @State private var showingDemoPanel = false
    @State private var showingEmergencyAlert = false
    @State private var showingEquipmentView = false
    @State private var showingChemicalView = false
    @State private var showingProfileView = false
    @State private var showingMenu = false
    @State private var selectedMenuItem: MenuItem?

    // Profile-specific sheet states
    @State private var showingProfileEditSheet = false
    @State private var showingSecuritySheet = false
    @State private var showingPrivacySheet = false
    @State private var showingDataExportSheet = false
    @State private var showingNotificationSheet = false
    @State private var showingOfflineDataSheet = false
    @State private var showingSDUIDemoSheet = false

    // Image picker states
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showingImageOptions = false

    // Error handling
    @State private var profileError: String?
    @State private var showingProfileError = false

    // Loading states
    @State private var isUpdatingProfile = false

    let persistenceController = PersistenceController.shared

    var body: some View {
        ZStack {
            // Background using design system
            LinearGradient(
                gradient: Gradient(colors: [PestGenieDesignSystem.Colors.background, PestGenieDesignSystem.Colors.backgroundSecondary]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation bar
                TopNavigationBar(technicianName: routeViewModel.technicianName, showingMenu: $showingMenu)

                // Main content area
                Group {
                    if let selectedMenuItem = selectedMenuItem {
                        // Show feature page based on menu selection
                        menuFeatureView(for: selectedMenuItem)
                    } else {
                        // Show main app navigation
                        switch selectedTab {
                        case .home:
                            homeDashboardView
                        case .route:
                            routeView
                        case .equipment:
                            equipmentView
                        case .chemicals:
                            chemicalView
                        case .profile:
                            profileView
                        }
                    }
                }

                // Bottom navigation (hidden when menu item is selected)
                if selectedMenuItem == nil {
                    bottomNavigationView
                }
            }

            // Menu overlay
            if showingMenu {
                MenuView(
                    isPresented: $showingMenu,
                    selectedMenuItem: $selectedMenuItem,
                    technicianName: routeViewModel.technicianName,
                    technicianId: "T-12345",
                    companyName: "PestControl Pro"
                )
                .environmentObject(routeViewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
                .zIndex(1)
            }
        }
        .environmentObject(routeViewModel)
        .environmentObject(locationManager)
        .environmentObject(notificationManager)
        .environmentObject(userProfileManager)
        .onAppear {
            setupInitialData()
        }
        .confirmationDialog("Change Profile Photo", isPresented: $showingImageOptions) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingImagePicker = true
            }
            if userProfileManager.currentProfile?.customProfileImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    removeCustomProfilePhoto()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedImageItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                processCameraImage(image)
                showingCamera = false
            }
        }
        .onChange(of: selectedImageItem) { _, newItem in
            if let newItem = newItem {
                processSelectedImage(newItem)
            }
        }
        .alert("Profile Error", isPresented: $showingProfileError) {
            Button("OK") {
                profileError = nil
            }
        } message: {
            Text(profileError ?? "An unknown error occurred")
        }
        .onChange(of: selectedMenuItem) { _, newItem in
            if newItem != nil {
                // Reset tab selection when showing menu feature
                selectedTab = .home
            }
        }
        .sheet(isPresented: $showingRouteView) {
            routeDetailView
        }
        .sheet(isPresented: $showingEquipmentView) {
            equipmentDetailView
        }
        .sheet(isPresented: $showingChemicalView) {
            chemicalDetailView
        }
        .sheet(isPresented: $showingProfileView) {
            profileDetailView
        }
        .sheet(isPresented: $showingProfileEditSheet) {
            profileEditSheet
        }
        .sheet(isPresented: $showingSecuritySheet) {
            securitySettingsSheet
        }
        .sheet(isPresented: $showingPrivacySheet) {
            privacySettingsSheet
        }
        .sheet(isPresented: $showingDataExportSheet) {
            dataExportSheet
        }
        .sheet(isPresented: $showingNotificationSheet) {
            notificationSettingsSheet
        }
        .sheet(isPresented: $showingOfflineDataSheet) {
            offlineDataSheet
        }
        .sheet(isPresented: $showingSDUIDemoSheet) {
            sduiDemoSheet
        }
        .sheet(isPresented: $showingRouteStartView) {
            RouteStartView(routeViewModel: routeViewModel)
        }
        .sheet(isPresented: $showingDemoPanel) {
            NavigationView {
                ScrollView {
                    DemoControlPanel(routeViewModel: routeViewModel)
                        .padding()
                }
                .navigationTitle("Demo Controls")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDemoPanel = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEmergencyAlert) {
            EmergencyAlertView(
                routeViewModel: routeViewModel,
                emergency: .beeSwarm
            )
        }
    }

    // MARK: - Menu Feature View

    @ViewBuilder
    private func menuFeatureView(for menuItem: MenuItem) -> some View {
        Group {
            switch menuItem {
            case .dashboard:
                homeDashboardView
            case .route:
                routeView
            case .equipment:
                equipmentView
            case .chemicals:
                chemicalView
            case .customerCommunication:
                menuFeatureWrapper {
                    CustomerCommunicationView()
                }
            case .reportsDocumentation:
                menuFeatureWrapper {
                    ReportsDocumentationView()
                }
            case .analyticsDashboard:
                menuFeatureWrapper {
                    AnalyticsDashboardView()
                }
            case .trainingResources:
                menuFeatureWrapper {
                    TrainingResourcesView()
                }
            case .settingsPreferences:
                menuFeatureWrapper {
                    SettingsPreferencesView()
                }
            case .helpSupport:
                menuFeatureWrapper {
                    HelpSupportView()
                }
            case .demoControls:
                menuFeatureWrapper {
                    DemoControlPanel(routeViewModel: routeViewModel)
                }
            case .notifications, .syncBackup, .sendFeedback, .emergencyContacts:
                placeholderFeatureView(for: menuItem)
            }
        }
    }

    private func menuFeatureWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationView {
            content()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            selectedMenuItem = nil
                        }) {
                            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                            }
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        }
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func placeholderFeatureView(for menuItem: MenuItem) -> some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 64))
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)

                VStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    Text(menuItem.title)
                        .font(PestGenieDesignSystem.Typography.headlineLarge)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text("This feature is coming soon!")
                        .font(PestGenieDesignSystem.Typography.bodyLarge)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("We're working hard to bring you this functionality. Stay tuned for updates!")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PestGenieDesignSystem.Spacing.xl)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PestGenieDesignSystem.Colors.background)
            .navigationTitle(menuItem.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedMenuItem = nil
                    }) {
                        HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(PestGenieDesignSystem.Typography.bodyMedium)
                        }
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Home Dashboard

    private var homeDashboardView: some View {
        Group {
            if let screen = loadHomeDashboard() {
                let context = createSDUIContext()
                SDUIScreenRenderer.render(screen: screen, context: context)
            } else {
                fallbackDashboardView
            }
        }
    }

    private var fallbackDashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                // Welcome section with design system styling
                HStack {
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                        Text("Dashboard Overview")
                            .font(PestGenieDesignSystem.Typography.headlineMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text("Monitor your progress and manage daily tasks")
                            .font(PestGenieDesignSystem.Typography.bodySmall)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28))
                        .foregroundColor(PestGenieDesignSystem.Colors.accent)
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                // Quick stats card
                quickStatsCard

                // Quick actions grid
                quickActionsGrid

                // Recent alerts
                alertsCard

                Spacer(minLength: 80) // Space for bottom navigation and safe area
            }
            .padding(.top, PestGenieDesignSystem.Spacing.md)
            .padding(.bottom, PestGenieDesignSystem.Spacing.xxxl)
        }
    }

    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
                    .font(.system(size: 18))
                Text("Today's Schedule")
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Spacer()
                Text(Date(), style: .date)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                statItem(title: "Total Jobs", value: "\(routeViewModel.jobs.count)", color: PestGenieDesignSystem.Colors.accent)
                Divider()
                    .frame(height: 28)
                    .background(PestGenieDesignSystem.Colors.border)
                statItem(title: "Completed", value: "\(routeViewModel.completedJobsCount)", color: PestGenieDesignSystem.Colors.success)
                Divider()
                    .frame(height: 28)
                    .background(PestGenieDesignSystem.Colors.border)
                statItem(title: "Remaining", value: "\(routeViewModel.remainingJobsCount)", color: PestGenieDesignSystem.Colors.warning)
            }

            ProgressView(value: routeViewModel.completionPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.success))
                .background(PestGenieDesignSystem.Colors.surfaceSecondary)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)

            // Emergency Alert (shown when there's an active emergency)
            if routeViewModel.hasActiveEmergency {
                emergencyAlertBanner
            }

            // Live Route Metrics (shown when route is active)
            if routeViewModel.isRouteStarted {
                liveRouteMetricsView
            }
        }
        .pestGenieCard()
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Text(value)
                .font(PestGenieDesignSystem.Typography.displaySmall)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            Text("Quick Actions")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.xs) {
                actionButton(
                    title: routeViewModel.isRouteStarted ? "Route Active" : "Start Route",
                    icon: routeViewModel.isRouteStarted ? "location.circle.fill" : "play.circle.fill",
                    color: routeViewModel.isRouteStarted ? PestGenieDesignSystem.Colors.primary : PestGenieDesignSystem.Colors.success
                ) {
                    if routeViewModel.isRouteStarted {
                        selectedTab = .route
                    } else {
                        showingRouteStartView = true
                    }
                }
                actionButton(title: "Equipment", icon: "wrench.and.screwdriver.fill", color: PestGenieDesignSystem.Colors.accent) {
                    selectedTab = .equipment
                }
                actionButton(title: "QR Scanner", icon: "qrcode.viewfinder", color: PestGenieDesignSystem.Colors.secondary) {
                    openQRScanner()
                }
                actionButton(title: "Chemicals", icon: "testtube.2", color: PestGenieDesignSystem.Colors.warning) {
                    selectedTab = .chemicals
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                Text(title)
                    .font(PestGenieDesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
            .shadow(
                color: color.opacity(0.3),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
        .accessibilityHint("Tap to \(title.lowercased())")
    }

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(PestGenieDesignSystem.Colors.warning)
                    .font(.system(size: 20))
                Text("Recent Alerts")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Spacer()
                HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Circle()
                        .fill(PestGenieDesignSystem.Colors.warning)
                        .frame(width: 8, height: 8)
                    Text("3 new")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.warning)
                }
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                alertItem(icon: "exclamationmark.triangle.fill", text: "Equipment maintenance due: Sprayer Unit A", color: PestGenieDesignSystem.Colors.warning)
                alertItem(icon: "cloud.rain.fill", text: "Weather advisory: Rain expected 2-4 PM", color: PestGenieDesignSystem.Colors.info)
                alertItem(icon: "clock.fill", text: "Next job starts in 45 minutes", color: PestGenieDesignSystem.Colors.success)
            }
        }
        .pestGenieCard()
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
    }

    private var liveRouteMetricsView: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.green)
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                Text("Live Route Metrics")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Spacer()
                if routeViewModel.demoMode {
                    Button("Demo") {
                        showingDemoPanel = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: PestGenieDesignSystem.Spacing.sm) {
                liveMetricItem(
                    title: "Current Speed",
                    value: "\(Int(routeViewModel.currentSpeed)) mph",
                    icon: "speedometer",
                    color: .blue
                )

                liveMetricItem(
                    title: "Distance Today",
                    value: String(format: "%.1f mi", routeViewModel.totalDistanceTraveled),
                    icon: "location.north.line",
                    color: .green
                )

                liveMetricItem(
                    title: "Route Duration",
                    value: formatRouteDuration(),
                    icon: "clock.circle",
                    color: .orange
                )

                liveMetricItem(
                    title: "Next Job ETA",
                    value: formatTimeInterval(routeViewModel.estimatedTimeToNextJob),
                    icon: "clock.arrow.circlepath",
                    color: .purple
                )
            }

            // Weather Banner
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(routeViewModel.weatherConditions)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
            .background(Color.cyan.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .pestGenieCard()
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
    }

    private func liveMetricItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }

            Text(value)
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .fontWeight(.bold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }

    private func formatRouteDuration() -> String {
        guard let startTime = routeViewModel.routeStartTime else { return "0h 0m" }
        let duration = Date().timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    private var emergencyAlertBanner: some View {
        Button(action: {
            showingEmergencyAlert = true
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("EMERGENCY ALERT")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let emergency = routeViewModel.currentEmergency {
                        Text(emergency)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .font(.title3)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Route Management Components

    private var routeHeaderCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Today's Route")
                        .font(PestGenieDesignSystem.Typography.headlineMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text("Route \(routeViewModel.currentRouteId)")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(routeViewModel.isRouteStarted ? "ACTIVE" : "NOT STARTED")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(.white)
                        .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                        .background(routeViewModel.isRouteStarted ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.textSecondary)
                        .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)

                    if let startTime = routeViewModel.routeStartTime {
                        Text("Started \(startTime, formatter: timeFormatter)")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }
                }
            }

            // Progress Overview
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                HStack {
                    Text("Progress")
                        .font(PestGenieDesignSystem.Typography.labelMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("\(routeViewModel.completedJobsCount)/\(routeViewModel.jobs.count) jobs")
                        .font(PestGenieDesignSystem.Typography.labelMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                ProgressView(value: routeViewModel.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.success))
                    .background(PestGenieDesignSystem.Colors.surfaceSecondary)
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
            }
        }
        .pestGenieCard()
    }

    private var routeMetricsCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("Live Route Metrics")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Spacer()
                if routeViewModel.demoMode {
                    Text("DEMO")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: PestGenieDesignSystem.Spacing.sm) {
                routeMetricItem(
                    title: "Current Speed",
                    value: "\(Int(routeViewModel.currentSpeed)) mph",
                    icon: "speedometer",
                    color: .blue
                )

                routeMetricItem(
                    title: "Distance Today",
                    value: String(format: "%.1f mi", routeViewModel.totalDistanceTraveled),
                    icon: "location.north.line",
                    color: .green
                )

                routeMetricItem(
                    title: "Time on Route",
                    value: formatRouteDuration(),
                    icon: "clock.circle",
                    color: .orange
                )

                routeMetricItem(
                    title: "Next Job ETA",
                    value: formatTimeInterval(routeViewModel.estimatedTimeToNextJob),
                    icon: "clock.arrow.circlepath",
                    color: .purple
                )
            }
        }
        .pestGenieCard()
    }

    private var emergencyAlertCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE EMERGENCY")
                        .font(PestGenieDesignSystem.Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    if let emergency = routeViewModel.currentEmergency {
                        Text(emergency)
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    }
                }

                Spacer()

                Button("Respond") {
                    showingEmergencyAlert = true
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
                .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }
        }
        .pestGenieCard()
        .background(Color.red.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.md)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var routeActionsCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Quick Actions")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .fontWeight(.semibold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                if !routeViewModel.isRouteStarted {
                    routeActionButton(
                        title: "Start Route",
                        icon: "play.circle.fill",
                        color: PestGenieDesignSystem.Colors.success
                    ) {
                        showingRouteStartView = true
                    }
                } else {
                    routeActionButton(
                        title: "End Route",
                        icon: "stop.circle.fill",
                        color: PestGenieDesignSystem.Colors.error
                    ) {
                        routeViewModel.endRoute()
                    }
                }

                routeActionButton(
                    title: "Navigation",
                    icon: "map.fill",
                    color: .blue
                ) {
                    // Open navigation to next job
                }

                routeActionButton(
                    title: "Weather",
                    icon: "cloud.sun.fill",
                    color: .cyan
                ) {
                    // Show weather details
                }

                routeActionButton(
                    title: "Emergency",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    routeViewModel.loadEmergencyScenario()
                }
            }
        }
        .pestGenieCard()
    }

    private func routeActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.labelMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PestGenieDesignSystem.Spacing.md)
            .background(color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func routeMetricItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }

            Text(value)
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .fontWeight(.bold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }

    private var jobListSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Today's Jobs")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("\(routeViewModel.jobs.count) total")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            ForEach(routeViewModel.jobs, id: \.id) { job in
                jobCard(job)
            }
        }
        .pestGenieCard()
    }

    private func jobCard(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(job.customerName)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(job.address)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                    jobStatusBadge(job.status)

                    Text(job.scheduledDate, style: .time)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            if let notes = job.notes {
                Text("📋 \(notes)")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .padding(.top, PestGenieDesignSystem.Spacing.xs)
            }

            if let pinnedNotes = job.pinnedNotes {
                Text("📌 \(pinnedNotes)")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
                    .padding(.top, PestGenieDesignSystem.Spacing.xs)
            }

            // Job Actions
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                if job.status == .pending {
                    Button("Start Job") {
                        routeViewModel.start(job: job)
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                    .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                    .background(PestGenieDesignSystem.Colors.success)
                    .foregroundColor(.white)
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)

                    Button("Skip") {
                        routeViewModel.skip(job: job)
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                    .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                    .background(PestGenieDesignSystem.Colors.warning)
                    .foregroundColor(.white)
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
                } else if job.status == .inProgress {
                    Button("Complete Job") {
                        let signature = "Demo Signature".data(using: .utf8) ?? Data()
                        routeViewModel.complete(job: job, signature: signature)
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                    .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                    .background(PestGenieDesignSystem.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
                }

                Button("Navigate") {
                    // Open navigation to this job
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)

                Spacer()
            }
            .padding(.top, PestGenieDesignSystem.Spacing.sm)
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(job.status == .inProgress ? PestGenieDesignSystem.Colors.primary.opacity(0.05) : PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .stroke(job.status == .inProgress ? PestGenieDesignSystem.Colors.primary.opacity(0.3) : PestGenieDesignSystem.Colors.border, lineWidth: 1)
        )
    }

    private func jobStatusBadge(_ status: JobStatus) -> some View {
        Text(status.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(.white)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(status.color)
            .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
    }

    private var demoControlsCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Demo Controls")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Button("Load Demo Data") {
                    routeViewModel.loadDemoData()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)

                Button("Start Demo Progression") {
                    routeViewModel.progressDemoJobs()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)

                Button("Emergency Scenario") {
                    routeViewModel.loadEmergencyScenario()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }
        }
        .pestGenieCard()
        .background(Color.blue.opacity(0.02))
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private func alertItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
                .frame(width: 20)
            Text(text)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
    }

    // MARK: - Navigation Views

    private var routeView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Route Header with Status
                    routeHeaderCard

                    // Live Route Metrics (if route is active)
                    if routeViewModel.isRouteStarted {
                        routeMetricsCard
                    }

                    // Emergency Alert (if active)
                    if routeViewModel.hasActiveEmergency {
                        emergencyAlertCard
                    }

                    // Route Actions
                    routeActionsCard

                    // Job List
                    jobListSection

                    // Demo Controls (if in demo mode)
                    if routeViewModel.demoMode {
                        demoControlsCard
                    }
                }
                .padding(PestGenieDesignSystem.Spacing.md)
            }
            .navigationTitle("Route Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        routeViewModel.toggleDemoMode()
                    }) {
                        Image(systemName: routeViewModel.demoMode ? "waveform.badge.magnifyingglass" : "waveform")
                            .foregroundColor(routeViewModel.demoMode ? .blue : PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
    }

    private var equipmentView: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
            Text("Equipment Center")
                .font(PestGenieDesignSystem.Typography.displayMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            Text("Equipment management and inspections")
                .font(PestGenieDesignSystem.Typography.bodyLarge)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            // Enhanced equipment content would go here
            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.md)
    }

    private var chemicalView: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
            Text("Chemical Management")
                .font(PestGenieDesignSystem.Typography.displayMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            Text("Chemical inventory and safety management")
                .font(PestGenieDesignSystem.Typography.bodyLarge)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            // Enhanced chemical content would go here
            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.md)
    }

    private var profileView: some View {
        Group {
            if let screen = loadProfileScreen() {
                let context = createProfileSDUIContext()
                SDUIScreenRenderer.render(screen: screen, context: context)
                    .onAppear {
                        populateProfileData()
                    }
            } else {
                fallbackProfileView
            }
        }
    }

    private var fallbackProfileView: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
            Text("Profile & Settings")
                .font(PestGenieDesignSystem.Typography.displayMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            Text("User profile and application settings")
                .font(PestGenieDesignSystem.Typography.bodyLarge)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            // Enhanced profile content would go here
            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.md)
    }

    // MARK: - Bottom Navigation

    private var bottomNavigationView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(NavigationTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: PestGenieDesignSystem.Components.Navigation.BottomTab.spacing) {
                            Image(systemName: tab.icon)
                                .font(.system(size: PestGenieDesignSystem.Components.Navigation.BottomTab.iconSize, weight: PestGenieDesignSystem.Components.Navigation.BottomTab.iconWeight))
                                .symbolRenderingMode(.monochrome)
                                .foregroundColor(selectedTab == tab ? tab.designSystemColor : PestGenieDesignSystem.Colors.textTertiary)
                                .frame(width: PestGenieDesignSystem.Components.Navigation.BottomTab.iconSize, height: PestGenieDesignSystem.Components.Navigation.BottomTab.iconSize)

                            Text(tab.title)
                                .font(.system(size: PestGenieDesignSystem.Components.Navigation.BottomTab.fontSize, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundColor(selectedTab == tab ? tab.designSystemColor : PestGenieDesignSystem.Colors.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PestGenieDesignSystem.Components.Navigation.BottomTab.verticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                                .fill(selectedTab == tab ? tab.designSystemColor.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(tab.title)
                    .accessibilityHint("Navigate to \(tab.title.lowercased()) section")
                    .padding(.horizontal, PestGenieDesignSystem.Components.Navigation.BottomTab.horizontalPadding)
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Components.Navigation.BottomTab.containerHorizontalPadding)
            .padding(.vertical, PestGenieDesignSystem.Components.Navigation.BottomTab.containerVerticalPadding)
            .background(PestGenieDesignSystem.Colors.background)
        }
    }

    // MARK: - Detail Views

    private var routeDetailView: some View {
        NavigationView {
            Text("Route Details")
                .navigationTitle("Today's Route")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingRouteView = false
                        }
                    }
                }
        }
    }

    private var equipmentDetailView: some View {
        NavigationView {
            Text("Equipment Details")
                .navigationTitle("Equipment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingEquipmentView = false
                        }
                    }
                }
        }
    }

    private var chemicalDetailView: some View {
        NavigationView {
            Text("Chemical Details")
                .navigationTitle("Chemicals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingChemicalView = false
                        }
                    }
                }
        }
    }

    private var profileDetailView: some View {
        NavigationView {
            Text("Profile Details")
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingProfileView = false
                        }
                    }
                }
        }
    }

    // MARK: - Profile Sheets

    private var profileEditSheet: some View {
        NavigationView {
            Group {
                if let screen = loadProfileEditScreen() {
                    let context = createProfileEditSDUIContext()
                    SDUIScreenRenderer.render(screen: screen, context: context)
                } else {
                    fallbackProfileEditView
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingProfileEditSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfileChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var fallbackProfileEditView: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
            Text("Edit Profile")
                .font(PestGenieDesignSystem.Typography.displayMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            Text("Profile editing functionality will be available soon")
                .font(PestGenieDesignSystem.Typography.bodyLarge)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.md)
    }

    private var securitySettingsSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                Text("Security Settings")
                    .font(PestGenieDesignSystem.Typography.displayMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Text("Manage your security preferences")
                    .font(PestGenieDesignSystem.Typography.bodyLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSecuritySheet = false
                    }
                }
            }
        }
    }

    private var privacySettingsSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                Text("Privacy Settings")
                    .font(PestGenieDesignSystem.Typography.displayMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Text("Control your data privacy preferences")
                    .font(PestGenieDesignSystem.Typography.bodyLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingPrivacySheet = false
                    }
                }
            }
        }
    }

    private var dataExportSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                Text("Data Export & Privacy")
                    .font(PestGenieDesignSystem.Typography.displayMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Text("Export your data and manage privacy controls")
                    .font(PestGenieDesignSystem.Typography.bodyLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Data Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDataExportSheet = false
                    }
                }
            }
        }
    }

    private var notificationSettingsSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                Text("Notification Preferences")
                    .font(PestGenieDesignSystem.Typography.displayMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Text("Customize your notification settings")
                    .font(PestGenieDesignSystem.Typography.bodyLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingNotificationSheet = false
                    }
                }
            }
        }
    }

    private var offlineDataSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                Text("Offline Data Management")
                    .font(PestGenieDesignSystem.Typography.displayMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Text("Manage offline storage and sync settings")
                    .font(PestGenieDesignSystem.Typography.bodyLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Offline Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingOfflineDataSheet = false
                    }
                }
            }
        }
    }

    private var sduiDemoSheet: some View {
        SDUIComponentsDemo()
            .environmentObject(routeViewModel)
            .environmentObject(locationManager)
            .environmentObject(authManager)
    }

    // MARK: - Helper Methods

    private func loadHomeDashboard() -> SDUIScreen? {
        guard let url = Bundle.main.url(forResource: "HomeDashboard", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load HomeDashboard.json")
            return nil
        }

        do {
            return try JSONDecoder().decode(SDUIScreen.self, from: data)
        } catch {
            print("Failed to decode HomeDashboard.json: \(error)")
            return nil
        }
    }

    private func loadProfileScreen() -> SDUIScreen? {
        guard let url = Bundle.main.url(forResource: "ProfileScreen", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load ProfileScreen.json")
            return nil
        }

        do {
            return try JSONDecoder().decode(SDUIScreen.self, from: data)
        } catch {
            print("Failed to decode ProfileScreen.json: \(error)")
            return nil
        }
    }

    private func createSDUIContext() -> SDUIContext {
        let actions: [String: (Job?) -> Void] = [
            "start_route": { _ in
                selectedTab = .route
            },
            "emergency_call": { _ in
                makeEmergencyCall()
            },
            "equipment_check": { _ in
                selectedTab = .equipment
            },
            "qr_scanner": { _ in
                openQRScanner()
            },
            "navigate_home": { _ in
                selectedTab = .home
            },
            "navigate_route": { _ in
                selectedTab = .route
            },
            "navigate_equipment": { _ in
                selectedTab = .equipment
            },
            "navigate_chemicals": { _ in
                selectedTab = .chemicals
            },
            "navigate_profile": { _ in
                selectedTab = .profile
            },
            "view_all_equipment": { _ in
                selectedTab = .equipment
            }
        ]

        return SDUIContext(
            jobs: routeViewModel.jobs,
            routeViewModel: routeViewModel,
            actions: actions,
            currentJob: nil,
            persistenceController: persistenceController,
            authManager: authManager
        )
    }

    private func createProfileSDUIContext() -> SDUIContext {
        let profileActions: [String: (Job?) -> Void] = [
            "edit_profile": { _ in
                self.showProfileEditSheet()
            },
            "account_settings": { _ in
                self.selectedMenuItem = .settingsPreferences
            },
            "security_settings": { _ in
                self.showSecuritySettings()
            },
            "privacy_settings": { _ in
                self.showPrivacySettings()
            },
            "data_export": { _ in
                self.showDataExportSheet()
            },
            "notification_preferences": { _ in
                self.showNotificationSettings()
            },
            "offline_data": { _ in
                self.showOfflineDataManagement()
            },
            "help_support": { _ in
                self.selectedMenuItem = .helpSupport
            },
            "sdui_demo": { _ in
                self.showSDUIDemo()
            },
            "sign_out": { _ in
                self.handleSignOut()
            }
        ]

        return SDUIContext(
            jobs: routeViewModel.jobs,
            routeViewModel: routeViewModel,
            actions: profileActions,
            currentJob: nil,
            persistenceController: persistenceController,
            authManager: authManager
        )
    }

    private func setupInitialData() {
        // Set up UserProfileManager with AuthenticationManager
        routeViewModel.setAuthenticationManager(authManager)

        // Defer non-critical operations for better startup performance
        Task {
            // Small delay to let UI render first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Load route data after initial render
            await MainActor.run {
                routeViewModel.loadTodaysRoute()
            }

            // Initialize profile data if user is authenticated
            if let user = authManager.currentUser {
                do {
                    // Try to load existing profile or create from auth data
                    if let existingProfile = await userProfileManager.loadUserProfile(for: user.id) {
                        userProfileManager.currentProfile = existingProfile
                    } else {
                        // Create profile from Google auth data
                        let googleUser = GoogleUser(
                            id: user.id,
                            email: user.email,
                            name: user.name,
                            profileImageURL: user.profileImageURL,
                            tokens: AuthTokens(accessToken: "", refreshToken: nil, idToken: nil, expiresAt: Date())
                        )
                        _ = try await userProfileManager.createUser(from: googleUser)
                    }
                } catch {
                    print("Failed to initialize profile data: \(error)")
                }
            }

            // Request notification permissions in background
            _ = await notificationManager.requestPermissions()
            notificationManager.setupNotificationCategories()
        }
    }

    private func makeEmergencyCall() {
        // Implement emergency call functionality
        print("Emergency call initiated")
    }

    private func openQRScanner() {
        // Implement QR scanner functionality
        print("QR scanner opened")
    }

    // MARK: - Profile Action Methods

    private func loadProfileEditScreen() -> SDUIScreen? {
        guard let url = Bundle.main.url(forResource: "ProfileEditScreen", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load ProfileEditScreen.json")
            return nil
        }

        do {
            return try JSONDecoder().decode(SDUIScreen.self, from: data)
        } catch {
            print("Failed to decode ProfileEditScreen.json: \(error)")
            return nil
        }
    }

    private func createProfileEditSDUIContext() -> SDUIContext {
        let profileEditActions: [String: (Job?) -> Void] = [
            "change_photo": { _ in
                self.changeProfilePhoto()
            },
            "save_profile": { _ in
                self.saveProfileChanges()
            },
            "cancel_edit": { _ in
                self.showingProfileEditSheet = false
            }
        ]

        return SDUIContext(
            jobs: routeViewModel.jobs,
            routeViewModel: routeViewModel,
            actions: profileEditActions,
            currentJob: nil,
            persistenceController: persistenceController,
            authManager: authManager
        )
    }

    private func showProfileEditSheet() {
        showingProfileEditSheet = true
    }

    private func showSecuritySettings() {
        showingSecuritySheet = true
    }

    private func showPrivacySettings() {
        showingPrivacySheet = true
    }

    private func showDataExportSheet() {
        showingDataExportSheet = true
    }

    private func showNotificationSettings() {
        showingNotificationSheet = true
    }

    private func showOfflineDataManagement() {
        showingOfflineDataSheet = true
    }

    private func showSDUIDemo() {
        showingSDUIDemoSheet = true
    }

    private func changeProfilePhoto() {
        showingImageOptions = true
    }

    private func saveProfileChanges() {
        guard !isUpdatingProfile else { return }

        Task { @MainActor in
            isUpdatingProfile = true
            defer { isUpdatingProfile = false }

            do {
                // Collect form data from RouteViewModel SDUI values
                let userName = routeViewModel.textFieldValues["user_name"] ?? ""
                let notificationsEnabled = routeViewModel.toggleValues["notifications_enabled"] ?? true
                let locationSharingEnabled = routeViewModel.toggleValues["location_sharing_enabled"] ?? true
                let dataBackupEnabled = routeViewModel.toggleValues["data_backup_enabled"] ?? true
                let biometricAuthEnabled = routeViewModel.toggleValues["biometric_auth_enabled"] ?? true
                let themeIndex = routeViewModel.segmentedValues["app_theme"] ?? 0

                // Create preferences from form data
                var preferences = UserPreferences()
                preferences.notificationsEnabled = notificationsEnabled
                preferences.locationSharingEnabled = locationSharingEnabled
                preferences.dataBackupEnabled = dataBackupEnabled
                preferences.biometricAuthEnabled = biometricAuthEnabled

                // Map theme index to enum
                let themeOptions: [UserPreferences.AppTheme] = [.light, .dark, .system]
                if themeIndex < themeOptions.count {
                    preferences.theme = themeOptions[themeIndex]
                }

                // Create work info if needed
                let workInfo = userProfileManager.currentProfile?.workInfo ?? WorkInformation(certifications: [])

                // Get any custom profile image data
                let customImageData = routeViewModel.textFieldValues["profile_image_data"]?.data(using: .utf8)

                // Create profile update
                let update = UserProfileUpdate(
                    name: userName.isEmpty ? nil : userName,
                    preferences: preferences,
                    workInfo: workInfo,
                    customProfileImage: customImageData,
                    updatedFields: Set(["name", "preferences", "workInfo"])
                )

                // Update profile through manager
                try await userProfileManager.updateProfile(update)

                // Close the edit sheet on success
                showingProfileEditSheet = false

                // Show success feedback
                await showTemporaryFeedback("Profile updated successfully")

            } catch {
                profileError = error.localizedDescription
                showingProfileError = true
            }
        }
    }

    private func handleSignOut() {
        Task {
            await authManager.signOut()
        }
    }

    private func populateProfileData() {
        Task { @MainActor in
            // Get comprehensive profile data
            let profile = userProfileManager.currentProfile
            let user = authManager.currentUser

            // Populate user information
            if let profile = profile {
                routeViewModel.setSDUIValue("user.name", value: profile.name ?? "User")
                routeViewModel.setSDUIValue("user.email", value: profile.email)

                // Handle profile image - prefer custom image over Google image
                if profile.customProfileImageData != nil {
                    routeViewModel.setSDUIValue("user.profileImageURL", value: "custom://profile_image")
                } else {
                    routeViewModel.setSDUIValue("user.profileImageURL", value: profile.profileImageURL?.absoluteString ?? "")
                }

                // Populate form fields with current values
                routeViewModel.setTextValue(forKey: "user_name", value: profile.name ?? "")
                routeViewModel.setToggleValue(forKey: "notifications_enabled", value: profile.preferences.notificationsEnabled)
                routeViewModel.setToggleValue(forKey: "location_sharing_enabled", value: profile.preferences.locationSharingEnabled)
                routeViewModel.setToggleValue(forKey: "data_backup_enabled", value: profile.preferences.dataBackupEnabled)
                routeViewModel.setToggleValue(forKey: "biometric_auth_enabled", value: profile.preferences.biometricAuthEnabled)

                // Set theme segmented control
                let themeOptions: [UserPreferences.AppTheme] = [.light, .dark, .system]
                let themeIndex = themeOptions.firstIndex(of: profile.preferences.theme) ?? 2
                routeViewModel.setSegmentedValue(forKey: "app_theme", value: themeIndex)

            } else if let user = user {
                // Fallback to authentication data
                routeViewModel.setSDUIValue("user.name", value: user.name ?? "User")
                routeViewModel.setSDUIValue("user.email", value: user.email)
                routeViewModel.setSDUIValue("user.profileImageURL", value: user.profileImageURL?.absoluteString ?? "")

                // Set default form values
                routeViewModel.setTextValue(forKey: "user_name", value: user.name ?? "")
            } else {
                // No user data available
                routeViewModel.setSDUIValue("user.name", value: "Guest User")
                routeViewModel.setSDUIValue("user.email", value: "Not signed in")
                routeViewModel.setSDUIValue("user.profileImageURL", value: "")
            }

            // Set activity summary data
            routeViewModel.setSDUIValue("todayJobsCompleted", value: "\(routeViewModel.completedJobsCount)")
            routeViewModel.setSDUIValue("weekJobsCompleted", value: "\(routeViewModel.weeklyJobsCompleted)")
            routeViewModel.setSDUIValue("activeStreak", value: "\(routeViewModel.activeStreak)")

            // Set sync status
            let syncText = userProfileManager.syncStatus
            routeViewModel.setSDUIValue("lastSync", value: syncText)

            // Set profile completeness if available
            if let completeness = profile?.profileCompleteness {
                routeViewModel.setSDUIValue("profileCompleteness", value: String(format: "%.0f%%", completeness.score * 100))
            }
        }
    }

    // MARK: - Image Processing Methods

    private func processSelectedImage(_ item: PhotosPickerItem) {
        Task {
            do {
                let result = try await profileImageManager.processSelectedImage(item)
                await handleProcessedImage(result)
            } catch {
                await MainActor.run {
                    profileError = "Failed to process image: \(error.localizedDescription)"
                    showingProfileError = true
                }
            }
        }
    }

    private func processCameraImage(_ image: UIImage) {
        Task {
            do {
                let result = try await profileImageManager.processCameraImage(image)
                await handleProcessedImage(result)
            } catch {
                await MainActor.run {
                    profileError = "Failed to process image: \(error.localizedDescription)"
                    showingProfileError = true
                }
            }
        }
    }

    private func handleProcessedImage(_ result: ProcessedImageResult) async {
        await MainActor.run {
            // Store the processed image data for saving
            routeViewModel.setTextValue(forKey: "profile_image_data", value: result.optimizedData.base64EncodedString())

            // Update the UI immediately for better UX
            routeViewModel.setSDUIValue("user.profileImageURL", value: "custom://profile_image")
        }
    }

    private func removeCustomProfilePhoto() {
        Task { @MainActor in
            do {
                let update = UserProfileUpdate(
                    name: nil,
                    preferences: nil,
                    workInfo: nil,
                    customProfileImage: nil,
                    updatedFields: Set(["profileImage"])
                )

                try await userProfileManager.updateProfile(update)

                // Update UI to show Google account image again
                if let user = authManager.currentUser {
                    routeViewModel.setSDUIValue("user.profileImageURL", value: user.profileImageURL?.absoluteString ?? "")
                }

                await showTemporaryFeedback("Profile photo removed")

            } catch {
                profileError = error.localizedDescription
                showingProfileError = true
            }
        }
    }

    private func retryProfileOperation() {
        // Implement retry logic based on the last operation
        // For now, just retry saving profile changes
        saveProfileChanges()
    }

    private func showTemporaryFeedback(_ message: String) async {
        // In a real implementation, you might show a toast or temporary overlay
        print("Success: \(message)")
    }
}

// MARK: - Navigation Tab

enum NavigationTab: String, CaseIterable {
    case home = "home"
    case route = "route"
    case equipment = "equipment"
    case chemicals = "chemicals"
    case profile = "profile"

    var title: String {
        switch self {
        case .home: return "Home"
        case .route: return "Route"
        case .equipment: return "Equipment"
        case .chemicals: return "Chemicals"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .route: return "map.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .chemicals: return "testtube.2"
        case .profile: return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .home: return .blue
        case .route: return .green
        case .equipment: return .purple
        case .chemicals: return .orange
        case .profile: return .cyan
        }
    }

    var designSystemColor: Color {
        switch self {
        case .home: return PestGenieDesignSystem.Colors.accent
        case .route: return PestGenieDesignSystem.Colors.success
        case .equipment: return PestGenieDesignSystem.Colors.primary
        case .chemicals: return PestGenieDesignSystem.Colors.warning
        case .profile: return PestGenieDesignSystem.Colors.secondary
        }
    }
}

// MARK: - Preview

struct MainDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MainDashboardView()
    }
}