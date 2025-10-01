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

    // Chemical inventory management views
    @State private var showingChemicalUsageView = false
    @State private var showingInventoryAdjustmentView = false
    @State private var showingReorderView = false
    @State private var showingUsageReportView = false

    // Equipment Management State
    @State private var showingEquipmentInspection = false
    @State private var selectedEquipmentForInspection: Equipment?

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

    // Job card expansion states
    @State private var expandedJobIds: Set<String> = []

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
                        case .messages:
                            messagesView
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
                    selectedMenuItem: $selectedMenuItem
                )
                .environmentObject(routeViewModel)
                .environmentObject(authManager)
                .environmentObject(userProfileManager)
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
            NavigationStack {
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
        .sheet(isPresented: $showingChemicalUsageView) {
            ChemicalUsageView(routeViewModel: routeViewModel)
        }
        .sheet(isPresented: $showingInventoryAdjustmentView) {
            InventoryAdjustmentView(routeViewModel: routeViewModel)
        }
        .sheet(isPresented: $showingReorderView) {
            ReorderManagementView(routeViewModel: routeViewModel)
        }
        .sheet(isPresented: $showingUsageReportView) {
            ChemicalUsageReportView(routeViewModel: routeViewModel)
        }
        .sheet(isPresented: $showingEquipmentInspection) {
            if let equipment = selectedEquipmentForInspection {
                EquipmentInspectionView(equipment: equipment, routeViewModel: routeViewModel)
            }
        }
    }

    // MARK: - Menu Feature View

    @ViewBuilder
    private func menuFeatureView(for menuItem: MenuItem) -> some View {
        Group {
            switch menuItem {
            case .dashboard:
                homeDashboardView
                    .onAppear {
                        selectedMenuItem = nil
                        selectedTab = .home
                    }
            case .route:
                routeView
                    .onAppear {
                        selectedMenuItem = nil
                        selectedTab = .route
                    }
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
            case .emergency:
                menuFeatureWrapper {
                    EmergencyActionView()
                }
            case .safetyChecklist:
                menuFeatureWrapper {
                    SafetyChecklistView(technicianId: routeViewModel.currentTechnicianId)
                }
            case .callDispatch, .equipmentStatus, .weatherConditions, .emergencyProtocols, .performanceMetrics, .notifications, .syncBackup, .sendFeedback, .emergencyContacts:
                placeholderFeatureView(for: menuItem)
            }
        }
    }

    private func menuFeatureWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
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
            }

    private func placeholderFeatureView(for menuItem: MenuItem) -> some View {
        NavigationStack {
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
                    selectedMenuItem = .chemicals
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Route Management Components

    private var routeHeaderCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
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
                .font(PestGenieDesignSystem.Typography.caption)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
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
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            Text("Quick Actions")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .fontWeight(.semibold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                    if !routeViewModel.isRouteStarted {
                        compactRouteActionButton(
                            title: "Start Route",
                            icon: "play.circle.fill",
                            color: PestGenieDesignSystem.Colors.success
                        ) {
                            showingRouteStartView = true
                        }
                    } else {
                        compactRouteActionButton(
                            title: "End Route",
                            icon: "stop.circle.fill",
                            color: PestGenieDesignSystem.Colors.error
                        ) {
                            routeViewModel.endRoute()
                        }
                    }

                    compactRouteActionButton(
                        title: "Navigation",
                        icon: "map.fill",
                        color: .blue
                    ) {
                        // Open navigation to next job
                    }

                    compactRouteActionButton(
                        title: "Weather",
                        icon: "cloud.sun.fill",
                        color: .cyan
                    ) {
                        // Show weather details
                    }

                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
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
            .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
            .background(color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .buttonStyle(.plain)
    }

    private func compactRouteActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.labelSmall)
                    .fontWeight(.medium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func routeMetricItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }

            Text(value)
                .font(PestGenieDesignSystem.Typography.titleSmall)
                .fontWeight(.bold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(PestGenieDesignSystem.Spacing.xs)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }

    private var jobListSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
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

            LazyVStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                ForEach(routeViewModel.jobs, id: \.id) { job in
                    compactJobCard(job)
                }
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

    private func compactJobCard(_ job: Job) -> some View {
        let isExpanded = expandedJobIds.contains(job.id.uuidString)

        return VStack(alignment: .leading, spacing: 0) {
            // Compact header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if isExpanded {
                        expandedJobIds.remove(job.id.uuidString)
                    } else {
                        expandedJobIds.insert(job.id.uuidString)
                    }
                }
            }) {
                HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                        .frame(width: 16, height: 16)

                    // Customer name and key info
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Text(job.customerName)
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Text(job.scheduledDate, style: .time)
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Status badge and quick actions
                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        jobStatusBadge(job.status)

                        if job.status == .pending {
                            Button(action: {
                                routeViewModel.start(job: job)
                            }) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(PestGenieDesignSystem.Colors.success)
                                    .clipShape(Circle())
                            }
                        } else if job.status == .inProgress {
                            Button(action: {
                                let signature = "Demo Signature".data(using: .utf8) ?? Data()
                                routeViewModel.complete(job: job, signature: signature)
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(PestGenieDesignSystem.Colors.primary)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            // Expanded details (conditionally visible)
            if isExpanded {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    // Address
                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                            .frame(width: 16)

                        Text(job.address)
                            .font(PestGenieDesignSystem.Typography.bodySmall)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                        Spacer()

                        Button("Navigate") {
                            // Open navigation to this job
                        }
                        .font(PestGenieDesignSystem.Typography.caption)
                        .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
                    }

                    // Notes (if any)
                    if let notes = job.notes {
                        HStack(alignment: .top, spacing: PestGenieDesignSystem.Spacing.xs) {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                                .frame(width: 16)

                            Text(notes)
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        }
                    }

                    // Pinned notes (if any)
                    if let pinnedNotes = job.pinnedNotes {
                        HStack(alignment: .top, spacing: PestGenieDesignSystem.Spacing.xs) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 14))
                                .foregroundColor(PestGenieDesignSystem.Colors.accent)
                                .frame(width: 16)

                            Text(pinnedNotes)
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.accent)
                        }
                    }

                    // Action buttons
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

                        Spacer()
                    }
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .padding(.bottom, PestGenieDesignSystem.Spacing.sm)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
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
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            Text("Demo Controls")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Button("Load Demo") {
                    routeViewModel.loadDemoData()
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)

                Button("Progress") {
                    routeViewModel.progressDemoJobs()
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
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
        NavigationStack {
            ScrollView {
                VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
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
                .padding(PestGenieDesignSystem.Spacing.sm)
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
        NavigationStack {
            ScrollView {
                VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Header with Live Status
                    equipmentHeaderCard

                    // Today's Progress
                    technicianMetricsGrid

                    // Smart Alerts Section
                    smartAlertsSection

                    // Equipment Fleet Overview
                    equipmentFleetSection

                    // Quick Actions
                    equipmentQuickActions

                    // AI Insights Section
                    aiInsightsSection
                }
                .padding()
            }
            .background(PestGenieDesignSystem.Colors.background)
            .navigationTitle("Equipment Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Demo: Trigger equipment sync
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
    }

    // MARK: - Equipment Center Components

    private var equipmentHeaderCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("My Equipment")
                        .font(PestGenieDesignSystem.Typography.headlineLarge)
                        .fontWeight(.bold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Circle()
                            .fill(equipmentStatusColor)
                            .frame(width: 8, height: 8)
                        Text(equipmentStatusText)
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("\(routeViewModel.assignedEquipment.count)")
                        .font(PestGenieDesignSystem.Typography.displaySmall)
                        .fontWeight(.bold)
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    Text("Items Assigned")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            // Today's Checklist
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                HStack {
                    Text("Pre-Service Checklist")
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text(preServiceChecklistStatus)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(preServiceChecklistColor)
                }

                ProgressView(value: preServiceChecklistProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: preServiceChecklistColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
        }
        .pestGenieCard()
    }

    private var technicianMetricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: PestGenieDesignSystem.Spacing.md) {
            equipmentMetricCard(
                title: "Jobs Today",
                value: "\(routeViewModel.completedJobsCount)/\(routeViewModel.jobs.count)",
                change: "\(routeViewModel.jobs.count - routeViewModel.completedJobsCount) remaining",
                changePositive: routeViewModel.completedJobsCount > 0,
                icon: "list.clipboard",
                color: .blue
            )

            equipmentMetricCard(
                title: "Equipment Check",
                value: "\(getInspectedEquipmentCount())/\(routeViewModel.assignedEquipment.count)",
                change: getInspectedEquipmentCount() == routeViewModel.assignedEquipment.count ? "Complete" : "\(routeViewModel.assignedEquipment.count - getInspectedEquipmentCount()) pending",
                changePositive: getInspectedEquipmentCount() == routeViewModel.assignedEquipment.count,
                icon: "checkmark.circle.fill",
                color: getInspectedEquipmentCount() == routeViewModel.assignedEquipment.count ? .green : .orange
            )

            equipmentMetricCard(
                title: "Customer Updates",
                value: "\(routeViewModel.completedJobsCount) sent",
                change: "All current",
                changePositive: true,
                icon: "message.fill",
                color: .green
            )

            equipmentMetricCard(
                title: "Next Service",
                value: nextJobTime,
                change: nextJobLocation,
                changePositive: true,
                icon: "clock.badge.checkmark",
                color: .purple
            )
        }
    }

    private func equipmentMetricCard(title: String, value: String, change: String, changePositive: Bool, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Image(systemName: changePositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(changePositive ? .green : .red)
                    Text(change)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(changePositive ? .green : .red)
                        .fontWeight(.medium)
                }
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                Text(value)
                    .font(PestGenieDesignSystem.Typography.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .pestGenieCard()
    }

    private var smartAlertsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Smart Alerts")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button("View All") {
                    // Demo: Show all alerts
                }
                .font(PestGenieDesignSystem.Typography.bodySmall)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                smartAlertItem(
                    icon: "exclamationmark.triangle.fill",
                    title: "Calibration Due",
                    subtitle: "Moisture Meter #MT-2041 requires calibration",
                    priority: .medium,
                    action: "Schedule"
                )

                smartAlertItem(
                    icon: "gear.badge.checkmark",
                    title: "Maintenance Complete",
                    subtitle: "Backpack Sprayer #BS-1025 serviced successfully",
                    priority: .low,
                    action: "Review"
                )

                smartAlertItem(
                    icon: "brain.head.profile",
                    title: "AI Recommendation",
                    subtitle: "Optimize sprayer routes for 15% efficiency gain",
                    priority: .high,
                    action: "Apply"
                )
            }
        }
        .pestGenieCard()
    }

    private func smartAlertItem(icon: String, title: String, subtitle: String, priority: EquipmentAlertPriority, action: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(priority.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action) {
                // Demo: Handle alert action
            }
            .font(PestGenieDesignSystem.Typography.bodySmall)
            .fontWeight(.medium)
            .foregroundColor(PestGenieDesignSystem.Colors.primary)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
            .background(PestGenieDesignSystem.Colors.primary.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private var equipmentFleetSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("My Equipment")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: {
                    // Demo: Show equipment scanner
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title3)
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                if routeViewModel.assignedEquipment.isEmpty {
                    VStack(spacing: PestGenieDesignSystem.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 30))
                            .foregroundColor(.orange)

                        Text("No Equipment Assigned")
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text("Contact your supervisor to assign equipment")
                            .font(PestGenieDesignSystem.Typography.bodySmall)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PestGenieDesignSystem.Spacing.lg)
                } else {
                    ForEach(routeViewModel.assignedEquipment) { equipment in
                        realEquipmentRow(equipment: equipment)
                    }
                }
            }
        }
        .pestGenieCard()
    }

    private func technicianEquipmentRow(name: String, model: String, status: EquipmentDemoStatus, lastCheck: String, action: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Status indicator
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Spacer()

                    Text(action)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(status.color)
                }

                HStack {
                    Text(model)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("Last: \(lastCheck)")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            Button(action: {
                // Demo: Equipment details/check-in
            }) {
                Image(systemName: status == .needsAttention ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(status.color)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func realEquipmentRow(equipment: Equipment) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Status indicator
            Circle()
                .fill(equipmentStatusColor(for: equipment))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(equipment.name)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Spacer()

                    Text(equipmentActionText(for: equipment))
                        .font(PestGenieDesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(equipmentStatusColor(for: equipment))
                }

                HStack {
                    Text("\(equipment.brand) \(equipment.model)")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("Last: \(lastInspectionText(for: equipment))")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            Button(action: {
                // Show equipment inspection view
                showingEquipmentInspection = true
                selectedEquipmentForInspection = equipment
            }) {
                Image(systemName: inspectionStatusIcon(for: equipment))
                    .font(.title3)
                    .foregroundColor(equipmentStatusColor(for: equipment))
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    // MARK: - Equipment Computed Properties

    private var equipmentStatusColor: Color {
        let failedEquipment = routeViewModel.assignedEquipment.filter { equipment in
            getLastInspectionResult(equipment.id) == .failed
        }

        let needsAttentionEquipment = routeViewModel.assignedEquipment.filter { equipment in
            let result = getLastInspectionResult(equipment.id)
            return result == .needsCalibration || result == .needsMaintenance
        }

        if !failedEquipment.isEmpty {
            return .red
        } else if !needsAttentionEquipment.isEmpty {
            return .orange
        } else {
            return .green
        }
    }

    private var equipmentStatusText: String {
        let failedEquipment = routeViewModel.assignedEquipment.filter { equipment in
            getLastInspectionResult(equipment.id) == .failed
        }

        let needsAttentionEquipment = routeViewModel.assignedEquipment.filter { equipment in
            let result = getLastInspectionResult(equipment.id)
            return result == .needsCalibration || result == .needsMaintenance
        }

        if !failedEquipment.isEmpty {
            return "Equipment Issues Detected"
        } else if !needsAttentionEquipment.isEmpty {
            return "Attention Required"
        } else {
            return "All Equipment Ready"
        }
    }

    private var preServiceChecklistProgress: Double {
        guard !routeViewModel.assignedEquipment.isEmpty else { return 0 }

        let inspectedCount = getInspectedEquipmentCount()
        return Double(inspectedCount) / Double(routeViewModel.assignedEquipment.count)
    }

    private var preServiceChecklistStatus: String {
        let total = routeViewModel.assignedEquipment.count
        let inspected = getInspectedEquipmentCount()

        if total == 0 {
            return "No Equipment"
        } else if inspected == total {
            return "Complete"
        } else {
            return "\(inspected)/\(total) Complete"
        }
    }

    private var preServiceChecklistColor: Color {
        let total = routeViewModel.assignedEquipment.count
        let inspected = getInspectedEquipmentCount()

        if total == 0 || inspected == total {
            return .green
        } else {
            return .orange
        }
    }

    // MARK: - Helper Functions

    private func equipmentStatusColor(for equipment: Equipment) -> Color {
        let result = getLastInspectionResult(equipment.id)
        switch result {
        case .passed:
            return .green
        case .failed:
            return .red
        case .conditionalPass:
            return .yellow
        case .needsCalibration, .needsMaintenance:
            return .orange
        case .pending:
            return .blue
        case .none:
            return .gray
        }
    }

    private func equipmentActionText(for equipment: Equipment) -> String {
        let result = getLastInspectionResult(equipment.id)
        switch result {
        case .passed:
            return "Ready"
        case .failed:
            return "Failed"
        case .conditionalPass:
            return "Conditional Pass"
        case .needsCalibration:
            return "Calibration"
        case .needsMaintenance:
            return "Maintenance"
        case .pending:
            return "Pending"
        case .none:
            return "Check Required"
        }
    }

    private func inspectionStatusIcon(for equipment: Equipment) -> String {
        let result = getLastInspectionResult(equipment.id)
        switch result {
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .conditionalPass:
            return "checkmark.circle"
        case .needsCalibration:
            return "gauge.open.with.lines.needle.33percent.exclamation"
        case .needsMaintenance:
            return "wrench.and.screwdriver.fill"
        case .pending:
            return "clock.circle"
        case .none:
            return "circle"
        }
    }

    private func lastInspectionText(for equipment: Equipment) -> String {
        let inspections = routeViewModel.equipmentInspections
            .filter { $0.equipmentId == equipment.id }
            .sorted { $0.inspectionDate > $1.inspectionDate }

        guard let lastInspection = inspections.first else {
            return "Never"
        }

        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(lastInspection.inspectionDate) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: lastInspection.inspectionDate))"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: lastInspection.inspectionDate)
        }
    }

    private func getLastInspectionResult(_ equipmentId: UUID) -> InspectionResult? {
        let inspections = routeViewModel.equipmentInspections
            .filter { $0.equipmentId == equipmentId }
            .sorted { $0.inspectionDate > $1.inspectionDate }

        return inspections.first?.result
    }

    private func getInspectedEquipmentCount() -> Int {
        let todayInspections = routeViewModel.equipmentInspections.filter { inspection in
            Calendar.current.isDate(inspection.inspectionDate, inSameDayAs: Date())
        }
        let inspectedEquipmentIds = Set(todayInspections.map { $0.equipmentId })
        return inspectedEquipmentIds.count
    }

    private var nextJobTime: String {
        let pendingJobs = routeViewModel.jobs.filter { $0.status == .pending }
        guard let nextJob = pendingJobs.first else {
            return "No jobs"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Due \(formatter.string(from: nextJob.scheduledDate))"
    }

    private var nextJobLocation: String {
        let pendingJobs = routeViewModel.jobs.filter { $0.status == .pending }
        guard let nextJob = pendingJobs.first else {
            return "Schedule complete"
        }

        return nextJob.customerName
    }

    private func equipmentFleetCard(name: String, model: String, status: EquipmentDemoStatus, efficiency: Double, lastMaintenance: String) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(name)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    Text(model)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                Circle()
                    .fill(status.color)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                HStack {
                    Text("Efficiency")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("\(Int(efficiency * 100))%")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(efficiency > 0.85 ? .green : .orange)
                }

                ProgressView(value: efficiency)
                    .progressViewStyle(LinearProgressViewStyle(tint: efficiency > 0.85 ? .green : .orange))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }

            Text("Last service: \(lastMaintenance)")
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.cardBackground)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.md)
                .stroke(status == .needsAttention ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var equipmentQuickActions: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Quick Actions")
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: PestGenieDesignSystem.Spacing.sm) {
                equipmentQuickActionButton(
                    icon: "camera.fill",
                    title: "Photo Report",
                    color: .blue
                ) {
                    // Demo: Before/after photos
                }

                equipmentQuickActionButton(
                    icon: "message.fill",
                    title: "Customer Update",
                    color: .green
                ) {
                    // Demo: Send completion summary
                }

                equipmentQuickActionButton(
                    icon: "qrcode.viewfinder",
                    title: "Equipment Check",
                    color: .orange
                ) {
                    // Demo: QR Scanner for equipment
                }

                equipmentQuickActionButton(
                    icon: "calendar.badge.checkmark",
                    title: "Schedule Next",
                    color: .purple
                ) {
                    // Demo: Schedule follow-up
                }

                equipmentQuickActionButton(
                    icon: "doc.text.fill",
                    title: "Job Notes",
                    color: .indigo
                ) {
                    // Demo: Service notes
                }

                equipmentQuickActionButton(
                    icon: "phone.fill",
                    title: "Call Customer",
                    color: .teal
                ) {
                    // Demo: Contact customer
                }
            }
        }
        .pestGenieCard()
    }

    private func equipmentQuickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PestGenieDesignSystem.Spacing.md)
            .background(color.opacity(0.05))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.md)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.purple)

                Text("AI Insights")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("Powered by ML")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                aiInsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Optimization Opportunity",
                    description: "Reroute sprayer assignments to reduce travel time by 23 minutes daily",
                    impact: "$340/month savings",
                    confidence: 94
                )

                aiInsightCard(
                    icon: "calendar.badge.clock",
                    title: "Predictive Maintenance",
                    description: "Tank Sprayer TS-2041 shows early wear patterns. Schedule maintenance in 2 weeks",
                    impact: "Prevent $850 repair",
                    confidence: 87
                )

                aiInsightCard(
                    icon: "person.2.badge.gearshape",
                    title: "Training Recommendation",
                    description: "Technician efficiency could improve 18% with calibration refresher training",
                    impact: "15 hrs/month saved",
                    confidence: 91
                )
            }
        }
        .pestGenieCard()
    }

    private func aiInsightCard(icon: String, title: String, description: String, impact: String, confidence: Int) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: PestGenieDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(description)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impact")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text(impact)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confidence")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text("\(confidence)%")
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(confidence > 85 ? .green : .orange)
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(Color.purple.opacity(0.03))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
    }

    private var chemicalView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Safety Status Header
                    chemicalSafetyHeader

                    // Critical Safety Alerts
                    safetyAlertsSection

                    // Technician's Chemical Assignments
                    technicianChemicalsSection

                    // Environmental Intelligence
                    environmentalIntelligenceSection

                    // Regulatory Compliance
                    regulatoryComplianceSection

                    // Smart Insights
                    chemicalInsightsSection

                    // Quick Actions
                    chemicalQuickActions
                }
                .padding()
            }
            .background(PestGenieDesignSystem.Colors.background)
            .navigationTitle("Chemical Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Demo: Emergency protocols
                    }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var messagesView: some View {
        NavigationStack {
            CustomerCommunicationView()
                .navigationTitle("Messages")
                .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Chemical Center Components

    private var chemicalSafetyHeader: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Safety Status")
                        .font(PestGenieDesignSystem.Typography.headlineLarge)
                        .fontWeight(.bold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Image(systemName: "shield.checkered.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("All EPA Protocols Active")
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("127")
                        .font(PestGenieDesignSystem.Typography.displaySmall)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Chemicals Tracked")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            // Risk Assessment Bar
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                HStack {
                    Text("Overall Risk Level")
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("Low Risk")
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                ProgressView(value: 0.23)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
        }
        .pestGenieCard()
    }

    private var safetyAlertsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.red)

                Text("Critical Safety Alerts")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("2 Active")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                chemicalSafetyAlert(
                    icon: "clock.fill",
                    title: "Phantom II - Re-entry Restriction",
                    subtitle: "24-hour re-entry period active at Johnson Property until 3:30 PM",
                    severity: .high,
                    action: "View Details"
                )

                chemicalSafetyAlert(
                    icon: "calendar.badge.exclamationmark",
                    title: "Carbaryl 50WP Expiring Soon",
                    subtitle: "Batch #CB-2024-089 expires in 12 days. Schedule disposal.",
                    severity: .medium,
                    action: "Schedule"
                )

                chemicalSafetyAlert(
                    icon: "checkmark.shield.fill",
                    title: "PPE Compliance Verified",
                    subtitle: "All Category I chemicals have proper protective equipment assigned",
                    severity: .low,
                    action: "Review"
                )
            }
        }
        .pestGenieCard()
    }

    private func chemicalSafetyAlert(icon: String, title: String, subtitle: String, severity: ChemicalAlertSeverity, action: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(severity.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action) {
                // Demo: Handle safety alert action
            }
            .font(PestGenieDesignSystem.Typography.bodySmall)
            .fontWeight(.medium)
            .foregroundColor(severity.color)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
            .background(severity.color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private var technicianChemicalsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("My Chemicals")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button("View All") {
                    // Demo: Show full chemical list
                }
                .font(PestGenieDesignSystem.Typography.bodySmall)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(routeViewModel.chemicals) { chemical in
                    technicianChemicalRow(
                        name: chemical.name,
                        activeIngredient: chemical.activeIngredient,
                        quantity: chemical.quantityFormatted,
                        signalWord: SignalWordDemo(from: chemical.signalWord),
                        needsAttention: chemical.isLowStock || chemical.isNearExpiration
                    )
                }

                if routeViewModel.chemicals.isEmpty {
                    Text("No chemicals loaded")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(PestGenieDesignSystem.Spacing.md)
                }
            }
        }
        .pestGenieCard()
    }

    private func technicianChemicalRow(name: String, activeIngredient: String, quantity: String, signalWord: SignalWordDemo, needsAttention: Bool) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Signal word indicator
            Rectangle()
                .fill(signalWord.color)
                .frame(width: 4, height: 44)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    if needsAttention {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Text(quantity)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                }

                Text(activeIngredient)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Button(action: {
                // Demo: Show chemical details
            }) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private var environmentalIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "cloud.sun.rain.fill")
                    .font(.title3)
                    .foregroundColor(.blue)

                Text("Environmental Intelligence")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("Live Data")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: PestGenieDesignSystem.Spacing.sm) {
                environmentalMetricCard(
                    title: "Wind Speed",
                    value: "3.2 mph",
                    status: "Safe for Application",
                    statusColor: .green,
                    icon: "wind"
                )

                environmentalMetricCard(
                    title: "Temperature",
                    value: "72°F",
                    status: "Optimal Range",
                    statusColor: .green,
                    icon: "thermometer.medium"
                )

                environmentalMetricCard(
                    title: "Humidity",
                    value: "68%",
                    status: "Good Conditions",
                    statusColor: .green,
                    icon: "humidity.fill"
                )

                environmentalMetricCard(
                    title: "Drift Risk",
                    value: "Low",
                    status: "Safe Buffer Zones",
                    statusColor: .green,
                    icon: "location.north.circle.fill"
                )
            }
        }
        .pestGenieCard()
    }

    private func environmentalMetricCard(title: String, value: String, status: String, statusColor: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                Text(value)
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(status)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(statusColor)
                    .fontWeight(.medium)
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(Color.blue.opacity(0.02))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    private var regulatoryComplianceSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.purple)

                Text("Regulatory Compliance")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("EPA Verified")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                complianceStatusRow(
                    title: "EPA Registration Status",
                    value: "127/127 Verified",
                    status: .compliant,
                    icon: "checkmark.circle.fill"
                )

                complianceStatusRow(
                    title: "Label Compliance Check",
                    value: "All Current",
                    status: .compliant,
                    icon: "doc.text.magnifyingglass"
                )

                complianceStatusRow(
                    title: "Re-entry Intervals",
                    value: "2 Active Timers",
                    status: .monitoring,
                    icon: "timer"
                )

                complianceStatusRow(
                    title: "PHI Tracking",
                    value: "5 Sites Monitored",
                    status: .monitoring,
                    icon: "calendar.badge.clock"
                )

                complianceStatusRow(
                    title: "Restricted Use Permits",
                    value: "Valid Until 12/2024",
                    status: .compliant,
                    icon: "key.fill"
                )
            }
        }
        .pestGenieCard()
    }

    private func complianceStatusRow(title: String, value: String, status: ChemicalComplianceStatus, icon: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(value)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            Text(status.displayText)
                .font(PestGenieDesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                .padding(.vertical, 2)
                .background(status.color.opacity(0.1))
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .padding(.vertical, 2)
    }

    private var chemicalInsightsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.indigo)

                Text("Smart Chemical Insights")
                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("AI Powered")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(.indigo)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                chemicalInsightCard(
                    icon: "chart.line.downtrend.xyaxis",
                    title: "Resistance Management Alert",
                    description: "Rotate to different mode of action for aphid control. Current Group 4A usage: 73%",
                    impact: "Prevent resistance",
                    confidence: 92
                )

                chemicalInsightCard(
                    icon: "dollarsign.circle.fill",
                    title: "Cost Optimization",
                    description: "Switch to generic formulation for 2,4-D applications to save $340/month",
                    impact: "$4,080/year savings",
                    confidence: 88
                )

                chemicalInsightCard(
                    icon: "leaf.circle.fill",
                    title: "Environmental Impact",
                    description: "Reduce neonicotinoid usage near pollinator habitats by 40% with targeted timing",
                    impact: "Protect beneficial insects",
                    confidence: 95
                )
            }
        }
        .pestGenieCard()
    }

    private func chemicalInsightCard(icon: String, title: String, description: String, impact: String, confidence: Int) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: PestGenieDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(description)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impact")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text(impact)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confidence")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text("\(confidence)%")
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(confidence > 85 ? .green : .orange)
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(Color.indigo.opacity(0.03))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .stroke(Color.indigo.opacity(0.15), lineWidth: 1)
        )
    }

    private var chemicalQuickActions: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Quick Actions")
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: PestGenieDesignSystem.Spacing.sm) {
                chemicalQuickActionButton(
                    icon: "drop.circle.fill",
                    title: "Record Usage",
                    color: .blue
                ) {
                    showingChemicalUsageView = true
                }

                chemicalQuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Adjust Stock",
                    color: .green
                ) {
                    showingInventoryAdjustmentView = true
                }

                chemicalQuickActionButton(
                    icon: "cart.badge.plus",
                    title: "Reorder Alert",
                    color: .orange
                ) {
                    showingReorderView = true
                }

                chemicalQuickActionButton(
                    icon: "clock.badge.exclamationmark",
                    title: "Expiration Check",
                    color: .red
                ) {
                    // Demo: Check expiring chemicals
                }

                chemicalQuickActionButton(
                    icon: "message.badge.filled.fill",
                    title: "Treatment Report",
                    color: .purple
                ) {
                    // Demo: Send treatment summary to customer
                }

                chemicalQuickActionButton(
                    icon: "chart.bar.fill",
                    title: "Usage Report",
                    color: .cyan
                ) {
                    showingUsageReportView = true
                }
            }
        }
        .pestGenieCard()
    }

    private func chemicalQuickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PestGenieDesignSystem.Spacing.md)
            .background(color.opacity(0.05))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.md)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var profileView: some View {
        ProfileView()
            .environmentObject(routeViewModel)
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
                            selectedMenuItem = nil
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
                    .buttonStyle(.plain)
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
        NavigationStack {
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
            "navigate_messages": { _ in
                selectedTab = .messages
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
                routeViewModel.loadDemoChemicals()
                routeViewModel.loadDemoEquipment()
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
    case messages = "messages"
    case profile = "profile"

    var title: String {
        switch self {
        case .home: return "Home"
        case .route: return "Route"
        case .equipment: return "Equipment"
        case .messages: return "Messages"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .route: return "map.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .messages: return "message.circle.fill"
        case .profile: return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .home: return .blue
        case .route: return .green
        case .equipment: return .purple
        case .messages: return .orange
        case .profile: return .cyan
        }
    }

    var designSystemColor: Color {
        switch self {
        case .home: return PestGenieDesignSystem.Colors.accent
        case .route: return PestGenieDesignSystem.Colors.success
        case .equipment: return PestGenieDesignSystem.Colors.primary
        case .messages: return PestGenieDesignSystem.Colors.warning
        case .profile: return PestGenieDesignSystem.Colors.secondary
        }
    }
}

// MARK: - Equipment Demo Supporting Types

enum EquipmentAlertPriority {
    case low, medium, high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum EquipmentDemoStatus {
    case operational, needsAttention, offline

    var color: Color {
        switch self {
        case .operational: return .green
        case .needsAttention: return .orange
        case .offline: return .red
        }
    }
}

enum ChemicalAlertSeverity {
    case low, medium, high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum ChemicalRiskLevel {
    case low, medium, high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum ChemicalComplianceStatus {
    case compliant, monitoring, warning

    var color: Color {
        switch self {
        case .compliant: return .green
        case .monitoring: return .blue
        case .warning: return .orange
        }
    }

    var displayText: String {
        switch self {
        case .compliant: return "Compliant"
        case .monitoring: return "Monitoring"
        case .warning: return "Warning"
        }
    }
}

enum SignalWordDemo {
    case danger, warning, caution

    var color: Color {
        switch self {
        case .danger: return .red
        case .warning: return .orange
        case .caution: return .yellow
        }
    }

    init(from signalWord: SignalWord) {
        switch signalWord {
        case .danger: self = .danger
        case .warning: self = .warning
        case .caution: self = .caution
        }
    }
}

// MARK: - Preview

struct MainDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MainDashboardView()
    }
}