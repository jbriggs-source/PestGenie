import SwiftUI

/// Main dashboard view that combines the home dashboard content with bottom navigation.
/// This serves as the primary entry point after app launch, providing an engaging
/// overview of the technician's day and quick access to key features.
struct MainDashboardView: View {
    @StateObject private var routeViewModel = RouteViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var selectedTab: NavigationTab = .home
    @State private var showingRouteView = false
    @State private var showingEquipmentView = false
    @State private var showingChemicalView = false
    @State private var showingProfileView = false
    @State private var showingMenu = false
    @State private var selectedMenuItem: MenuItem?

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
        .onAppear {
            setupInitialData()
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
                actionButton(title: "Start Route", icon: "play.circle.fill", color: PestGenieDesignSystem.Colors.success) {
                    selectedTab = .route
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
        VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
            Text("Route Management")
                .font(PestGenieDesignSystem.Typography.displayMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            Text("Today's route and job details")
                .font(PestGenieDesignSystem.Typography.bodyLarge)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            // Enhanced route content would go here
            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.md)
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

    private func setupInitialData() {
        // Defer non-critical operations for better startup performance
        Task {
            // Small delay to let UI render first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Load route data after initial render
            await MainActor.run {
                routeViewModel.loadTodaysRoute()
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