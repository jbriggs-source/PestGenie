import SwiftUI

/// Settings & Preferences Center for pest control technicians.
/// Provides comprehensive app configuration, user preferences, and system settings.
/// Designed to customize the app experience and optimize workflow efficiency.
struct SettingsPreferencesView: View {
    @State private var selectedCategory: SettingsCategory = .general
    @StateObject private var settingsManager = SettingsManager()
    @State private var showingAccountDetails = false
    @State private var showingDataExport = false
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category selector
                categorySelector

                // Settings content
                ScrollView {
                    LazyVStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                        switch selectedCategory {
                        case .general:
                            generalSettingsSection
                        case .notifications:
                            notificationSettingsSection
                        case .appearance:
                            appearanceSettingsSection
                        case .privacy:
                            privacySettingsSection
                        case .sync:
                            syncSettingsSection
                        case .advanced:
                            advancedSettingsSection
                        }
                    }
                    .padding(PestGenieDesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Settings & Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAccountDetails = true }) {
                            Label("Account Details", systemImage: "person.circle")
                        }
                        Button(action: { showingDataExport = true }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { resetToDefaults() }) {
                            Label("Reset to Defaults", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAccountDetails) {
            accountDetailsSheet
        }
        .sheet(isPresented: $showingDataExport) {
            dataExportSheet
        }
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsManager.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .onAppear {
            settingsManager.loadSettings()
        }
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(SettingsCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }) {
                        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 14))
                                Text(category.displayName)
                                    .font(PestGenieDesignSystem.Typography.labelMedium)
                            }
                            .foregroundColor(selectedCategory == category ? PestGenieDesignSystem.Colors.primary : PestGenieDesignSystem.Colors.textSecondary)

                            Rectangle()
                                .fill(selectedCategory == category ? PestGenieDesignSystem.Colors.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(minWidth: 100)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        }
        .background(PestGenieDesignSystem.Colors.surface)
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - General Settings

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // User profile section
            userProfileSection

            // App preferences
            appPreferencesSection

            // Work settings
            workSettingsSection
        }
    }

    private var userProfileSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("User Profile", icon: "person.circle")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    // Profile picture
                    ZStack {
                        Circle()
                            .fill(PestGenieDesignSystem.Colors.primary)
                            .frame(width: 60, height: 60)

                        Text(settingsManager.userInitials)
                            .font(PestGenieDesignSystem.Typography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                        Text(settingsManager.fullName)
                            .font(PestGenieDesignSystem.Typography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text("ID: \(settingsManager.technicianId)")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                        Text(settingsManager.companyName)
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    Button("Edit") {
                        showingAccountDetails = true
                    }
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                settingRow(
                    title: "Email",
                    value: settingsManager.email,
                    action: { editEmail() }
                )

                settingRow(
                    title: "Phone",
                    value: settingsManager.phoneNumber,
                    action: { editPhone() }
                )

                settingRow(
                    title: "Employee ID",
                    value: settingsManager.employeeId,
                    action: nil
                )
            }
        }
        .pestGenieCard()
    }

    private var appPreferencesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("App Preferences", icon: "gearshape")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Show Welcome Screen", isOn: $settingsManager.showWelcomeScreen)
                    .settingsToggleStyle()

                Toggle("Auto-start GPS Tracking", isOn: $settingsManager.autoStartGPS)
                    .settingsToggleStyle()

                Toggle("Offline Mode Available", isOn: $settingsManager.offlineModeEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                pickerRow(
                    title: "Default Map Type",
                    selection: $settingsManager.defaultMapType,
                    options: MapType.self
                )

                pickerRow(
                    title: "Distance Units",
                    selection: $settingsManager.distanceUnits,
                    options: DistanceUnit.self
                )

                pickerRow(
                    title: "Temperature Units",
                    selection: $settingsManager.temperatureUnits,
                    options: TemperatureUnit.self
                )
            }
        }
        .pestGenieCard()
    }

    private var workSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Work Settings", icon: "briefcase")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                pickerRow(
                    title: "Work Day Start Time",
                    selection: $settingsManager.workDayStartTime,
                    options: WorkHour.self
                )

                pickerRow(
                    title: "Work Day End Time",
                    selection: $settingsManager.workDayEndTime,
                    options: WorkHour.self
                )

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Toggle("Break Reminders", isOn: $settingsManager.breakRemindersEnabled)
                    .settingsToggleStyle()

                Toggle("Route Optimization", isOn: $settingsManager.routeOptimizationEnabled)
                    .settingsToggleStyle()

                Toggle("Automatic Check-in", isOn: $settingsManager.automaticCheckin)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                stepperRow(
                    title: "Default Service Duration",
                    value: $settingsManager.defaultServiceDuration,
                    range: 15...120,
                    step: 15,
                    unit: "minutes"
                )

                stepperRow(
                    title: "Travel Buffer Time",
                    value: $settingsManager.travelBufferTime,
                    range: 5...30,
                    step: 5,
                    unit: "minutes"
                )
            }
        }
        .pestGenieCard()
    }

    // MARK: - Notification Settings

    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Push notifications
            pushNotificationsSection

            // Email notifications
            emailNotificationsSection

            // SMS notifications
            smsNotificationsSection

            // Notification schedule
            notificationScheduleSection
        }
    }

    private var pushNotificationsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Push Notifications", icon: "bell")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Push Notifications", isOn: $settingsManager.pushNotificationsEnabled)
                    .settingsToggleStyle()

                if settingsManager.pushNotificationsEnabled {
                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    Toggle("Job Reminders", isOn: $settingsManager.jobRemindersEnabled)
                        .settingsToggleStyle()

                    Toggle("Weather Alerts", isOn: $settingsManager.weatherAlertsEnabled)
                        .settingsToggleStyle()

                    Toggle("Equipment Maintenance", isOn: $settingsManager.equipmentAlertsEnabled)
                        .settingsToggleStyle()

                    Toggle("Customer Messages", isOn: $settingsManager.customerMessageAlertsEnabled)
                        .settingsToggleStyle()

                    Toggle("Supervisor Updates", isOn: $settingsManager.supervisorAlertsEnabled)
                        .settingsToggleStyle()

                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    stepperRow(
                        title: "Job Reminder Time",
                        value: $settingsManager.jobReminderMinutes,
                        range: 5...60,
                        step: 5,
                        unit: "minutes before"
                    )
                }
            }
        }
        .pestGenieCard()
    }

    private var emailNotificationsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Email Notifications", icon: "envelope")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Email Notifications", isOn: $settingsManager.emailNotificationsEnabled)
                    .settingsToggleStyle()

                if settingsManager.emailNotificationsEnabled {
                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    Toggle("Daily Summary", isOn: $settingsManager.dailyEmailSummary)
                        .settingsToggleStyle()

                    Toggle("Weekly Reports", isOn: $settingsManager.weeklyEmailReports)
                        .settingsToggleStyle()

                    Toggle("Training Updates", isOn: $settingsManager.trainingEmailUpdates)
                        .settingsToggleStyle()

                    Toggle("Company Announcements", isOn: $settingsManager.companyAnnouncementsEmail)
                        .settingsToggleStyle()

                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    pickerRow(
                        title: "Summary Delivery Time",
                        selection: $settingsManager.emailSummaryTime,
                        options: EmailTime.self
                    )
                }
            }
        }
        .pestGenieCard()
    }

    private var smsNotificationsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("SMS Notifications", icon: "message")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("SMS Notifications", isOn: $settingsManager.smsNotificationsEnabled)
                    .settingsToggleStyle()

                if settingsManager.smsNotificationsEnabled {
                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    Toggle("Emergency Alerts Only", isOn: $settingsManager.emergencyAlertsOnly)
                        .settingsToggleStyle()

                    Toggle("Route Changes", isOn: $settingsManager.routeChangeSMSEnabled)
                        .settingsToggleStyle()

                    Toggle("Urgent Customer Requests", isOn: $settingsManager.urgentCustomerSMSEnabled)
                        .settingsToggleStyle()
                }
            }
        }
        .pestGenieCard()
    }

    private var notificationScheduleSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Notification Schedule", icon: "clock")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Do Not Disturb", isOn: $settingsManager.doNotDisturbEnabled)
                    .settingsToggleStyle()

                if settingsManager.doNotDisturbEnabled {
                    Divider()
                        .background(PestGenieDesignSystem.Colors.border)

                    pickerRow(
                        title: "DND Start Time",
                        selection: $settingsManager.dndStartTime,
                        options: NotificationTime.self
                    )

                    pickerRow(
                        title: "DND End Time",
                        selection: $settingsManager.dndEndTime,
                        options: NotificationTime.self
                    )

                    Toggle("Weekend DND", isOn: $settingsManager.weekendDNDEnabled)
                        .settingsToggleStyle()
                }
            }
        }
        .pestGenieCard()
    }

    // MARK: - Appearance Settings

    private var appearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Theme settings
            themeSettingsSection

            // Display settings
            displaySettingsSection

            // Accessibility settings
            accessibilitySettingsSection
        }
    }

    private var themeSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Theme & Colors", icon: "paintbrush")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                pickerRow(
                    title: "App Theme",
                    selection: $settingsManager.appTheme,
                    options: AppTheme.self
                )

                pickerRow(
                    title: "Color Accent",
                    selection: $settingsManager.accentColor,
                    options: AccentColor.self
                )

                Toggle("High Contrast Mode", isOn: $settingsManager.highContrastMode)
                    .settingsToggleStyle()

                Toggle("Dark Mode Maps", isOn: $settingsManager.darkModeMaps)
                    .settingsToggleStyle()
            }
        }
        .pestGenieCard()
    }

    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Display Settings", icon: "display")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                stepperRow(
                    title: "Text Size",
                    value: $settingsManager.textSizeScale,
                    range: 0.8...1.4,
                    step: 0.1,
                    unit: "scale",
                    formatter: { String(format: "%.1f", $0) }
                )

                Toggle("Bold Text", isOn: $settingsManager.boldTextEnabled)
                    .settingsToggleStyle()

                Toggle("Reduce Motion", isOn: $settingsManager.reduceMotionEnabled)
                    .settingsToggleStyle()

                Toggle("Show Animations", isOn: $settingsManager.animationsEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                pickerRow(
                    title: "Dashboard Layout",
                    selection: $settingsManager.dashboardLayout,
                    options: DashboardLayout.self
                )

                Toggle("Compact View", isOn: $settingsManager.compactViewEnabled)
                    .settingsToggleStyle()
            }
        }
        .pestGenieCard()
    }

    private var accessibilitySettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Accessibility", icon: "accessibility")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Voice Over Support", isOn: $settingsManager.voiceOverEnabled)
                    .settingsToggleStyle()

                Toggle("Haptic Feedback", isOn: $settingsManager.hapticFeedbackEnabled)
                    .settingsToggleStyle()

                Toggle("Audio Cues", isOn: $settingsManager.audioCuesEnabled)
                    .settingsToggleStyle()

                Toggle("Large Touch Targets", isOn: $settingsManager.largeTouchTargetsEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                stepperRow(
                    title: "Button Size",
                    value: $settingsManager.buttonSizeScale,
                    range: 0.8...1.5,
                    step: 0.1,
                    unit: "scale",
                    formatter: { String(format: "%.1f", $0) }
                )
            }
        }
        .pestGenieCard()
    }

    // MARK: - Privacy Settings

    private var privacySettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Location privacy
            locationPrivacySection

            // Data collection
            dataCollectionSection

            // App permissions
            appPermissionsSection
        }
    }

    private var locationPrivacySection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Location Privacy", icon: "location")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Location Tracking", isOn: $settingsManager.locationTrackingEnabled)
                    .settingsToggleStyle()

                Toggle("Background Location", isOn: $settingsManager.backgroundLocationEnabled)
                    .settingsToggleStyle()

                Toggle("Location History", isOn: $settingsManager.locationHistoryEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                pickerRow(
                    title: "Location Accuracy",
                    selection: $settingsManager.locationAccuracy,
                    options: LocationAccuracy.self
                )

                stepperRow(
                    title: "Data Retention",
                    value: $settingsManager.locationDataRetentionDays,
                    range: 7...365,
                    step: 7,
                    unit: "days"
                )
            }
        }
        .pestGenieCard()
    }

    private var dataCollectionSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Data Collection", icon: "chart.bar")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Analytics Collection", isOn: $settingsManager.analyticsEnabled)
                    .settingsToggleStyle()

                Toggle("Performance Data", isOn: $settingsManager.performanceDataEnabled)
                    .settingsToggleStyle()

                Toggle("Crash Reports", isOn: $settingsManager.crashReportsEnabled)
                    .settingsToggleStyle()

                Toggle("Usage Statistics", isOn: $settingsManager.usageStatisticsEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Button(action: { showingDataExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export My Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }

                Button(action: { deleteUserData() }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(PestGenieDesignSystem.Colors.error)
                }
            }
        }
        .pestGenieCard()
    }

    private var appPermissionsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("App Permissions", icon: "shield")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                permissionRow(
                    title: "Camera",
                    description: "For QR codes and photos",
                    status: settingsManager.cameraPermissionStatus
                )

                permissionRow(
                    title: "Photo Library",
                    description: "For report attachments",
                    status: settingsManager.photoLibraryPermissionStatus
                )

                permissionRow(
                    title: "Microphone",
                    description: "For voice notes",
                    status: settingsManager.microphonePermissionStatus
                )

                permissionRow(
                    title: "Contacts",
                    description: "For customer information",
                    status: settingsManager.contactsPermissionStatus
                )

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Button("Open Settings App") {
                    openSystemSettings()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Sync Settings

    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Sync preferences
            syncPreferencesSection

            // Backup settings
            backupSettingsSection

            // Offline settings
            offlineSettingsSection
        }
    }

    private var syncPreferencesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Sync Preferences", icon: "arrow.clockwise.icloud")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Auto-sync", isOn: $settingsManager.autoSyncEnabled)
                    .settingsToggleStyle()

                Toggle("WiFi Only Sync", isOn: $settingsManager.wifiOnlySyncEnabled)
                    .settingsToggleStyle()

                Toggle("Background Sync", isOn: $settingsManager.backgroundSyncEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                pickerRow(
                    title: "Sync Frequency",
                    selection: $settingsManager.syncFrequency,
                    options: SyncFrequency.self
                )

                stepperRow(
                    title: "Sync Retry Attempts",
                    value: $settingsManager.syncRetryAttempts,
                    range: 1...5,
                    step: 1,
                    unit: "attempts"
                )

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Button("Force Sync Now") {
                    forceSyncNow()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)

                HStack {
                    Text("Last sync:")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Spacer()

                    Text(settingsManager.lastSyncTime, style: .relative)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                }
            }
        }
        .pestGenieCard()
    }

    private var backupSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Backup Settings", icon: "externaldrive")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Automatic Backups", isOn: $settingsManager.automaticBackupsEnabled)
                    .settingsToggleStyle()

                Toggle("Include Photos", isOn: $settingsManager.backupPhotosEnabled)
                    .settingsToggleStyle()

                Toggle("Include Documents", isOn: $settingsManager.backupDocumentsEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                pickerRow(
                    title: "Backup Frequency",
                    selection: $settingsManager.backupFrequency,
                    options: BackupFrequency.self
                )

                stepperRow(
                    title: "Backup Retention",
                    value: $settingsManager.backupRetentionDays,
                    range: 7...90,
                    step: 7,
                    unit: "days"
                )

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Button("Create Backup Now") {
                    createBackupNow()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)

                HStack {
                    Text("Last backup:")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Spacer()

                    Text(settingsManager.lastBackupTime, style: .relative)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                }
            }
        }
        .pestGenieCard()
    }

    private var offlineSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Offline Settings", icon: "wifi.slash")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Offline Mode", isOn: $settingsManager.offlineModeEnabled)
                    .settingsToggleStyle()

                Toggle("Cache Route Data", isOn: $settingsManager.cacheRouteDataEnabled)
                    .settingsToggleStyle()

                Toggle("Cache Customer Data", isOn: $settingsManager.cacheCustomerDataEnabled)
                    .settingsToggleStyle()

                Toggle("Cache Training Materials", isOn: $settingsManager.cacheTrainingMaterialsEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                stepperRow(
                    title: "Cache Size Limit",
                    value: $settingsManager.cacheSizeLimitMB,
                    range: 100...2000,
                    step: 100,
                    unit: "MB"
                )

                Button("Clear Cache") {
                    clearCache()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.error)

                HStack {
                    Text("Cache usage:")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("\(settingsManager.currentCacheUsageMB) MB")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                }
            }
        }
        .pestGenieCard()
    }

    // MARK: - Advanced Settings

    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Developer settings
            developerSettingsSection

            // Debug settings
            debugSettingsSection

            // System information
            systemInformationSection
        }
    }

    private var developerSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Developer Settings", icon: "hammer")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Debug Mode", isOn: $settingsManager.debugModeEnabled)
                    .settingsToggleStyle()

                Toggle("Beta Features", isOn: $settingsManager.betaFeaturesEnabled)
                    .settingsToggleStyle()

                Toggle("Performance Monitoring", isOn: $settingsManager.performanceMonitoringEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                pickerRow(
                    title: "Log Level",
                    selection: $settingsManager.logLevel,
                    options: LogLevel.self
                )

                Button("Export Debug Logs") {
                    exportDebugLogs()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .pestGenieCard()
    }

    private var debugSettingsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Debug Settings", icon: "bug")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Toggle("Show Performance Overlay", isOn: $settingsManager.showPerformanceOverlay)
                    .settingsToggleStyle()

                Toggle("Mock Location Data", isOn: $settingsManager.mockLocationDataEnabled)
                    .settingsToggleStyle()

                Toggle("Simulate Network Issues", isOn: $settingsManager.simulateNetworkIssuesEnabled)
                    .settingsToggleStyle()

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Button("Reset App State") {
                    resetAppState()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.warning)

                Button("Clear All Data") {
                    clearAllData()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.error)
            }
        }
        .pestGenieCard()
    }

    private var systemInformationSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("System Information", icon: "info.circle")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                infoRow("App Version", settingsManager.appVersion)
                infoRow("Build Number", settingsManager.buildNumber)
                infoRow("iOS Version", settingsManager.iosVersion)
                infoRow("Device Model", settingsManager.deviceModel)
                infoRow("Storage Used", "\(settingsManager.storageUsedMB) MB")
                infoRow("Memory Usage", "\(settingsManager.memoryUsageMB) MB")

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                Button("Send Diagnostic Report") {
                    sendDiagnosticReport()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
                .font(.system(size: 18))

            Text(title)
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    private func settingRow(title: String, value: String, action: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            if action != nil {
                Button("Edit") {
                    action?()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func pickerRow<T: CaseIterable & Hashable & RawRepresentable & SettingsDisplayable>(
        title: String,
        selection: Binding<T>,
        options: T.Type
    ) -> some View where T.RawValue == String {
        HStack {
            Text(title)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            Menu {
                ForEach(Array(options.allCases), id: \.self) { (option: T) in
                    Button(action: {
                        selection.wrappedValue = option
                    }) {
                        HStack {
                            Text(option.displayName)
                            if selection.wrappedValue == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(selection.wrappedValue.displayName)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func stepperRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        stepperRow(
            title: title,
            value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            unit: unit,
            formatter: { String(Int($0)) }
        )
    }

    private func stepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        formatter: ((Double) -> String)? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        .frame(width: 32, height: 32)
                        .background(PestGenieDesignSystem.Colors.surface)
                        .clipShape(Circle())
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                let displayValue = formatter?(value.wrappedValue) ?? String(format: "%.0f", value.wrappedValue)
                Text("\(displayValue) \(unit)")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .frame(minWidth: 80)

                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        .frame(width: 32, height: 32)
                        .background(PestGenieDesignSystem.Colors.surface)
                        .clipShape(Circle())
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func permissionRow(title: String, description: String, status: PermissionStatus) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                Text(status.displayName)
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(status.color)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    // MARK: - Sheets

    private var accountDetailsSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Account details editing would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(PestGenieDesignSystem.Spacing.xl)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Account Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAccountDetails = false
                    }
                }
            }
        }
    }

    private var dataExportSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Data export options would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(PestGenieDesignSystem.Spacing.xl)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDataExport = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func resetToDefaults() {
        showingResetConfirmation = true
    }

    private func editEmail() {
        print("Editing email...")
    }

    private func editPhone() {
        print("Editing phone...")
    }

    private func deleteUserData() {
        print("Deleting user data...")
    }

    private func openSystemSettings() {
        print("Opening system settings...")
    }

    private func forceSyncNow() {
        print("Forcing sync now...")
    }

    private func createBackupNow() {
        print("Creating backup now...")
    }

    private func clearCache() {
        print("Clearing cache...")
    }

    private func exportDebugLogs() {
        print("Exporting debug logs...")
    }

    private func resetAppState() {
        print("Resetting app state...")
    }

    private func clearAllData() {
        print("Clearing all data...")
    }

    private func sendDiagnosticReport() {
        print("Sending diagnostic report...")
    }
}

// MARK: - View Modifiers

extension Toggle {
    func settingsToggleStyle() -> some View {
        self
            .tint(PestGenieDesignSystem.Colors.primary)
            .font(PestGenieDesignSystem.Typography.bodyMedium)
            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }
}

// MARK: - Supporting Types and Protocol

protocol SettingsDisplayable {
    var displayName: String { get }
}

enum SettingsCategory: String, CaseIterable {
    case general = "general"
    case notifications = "notifications"
    case appearance = "appearance"
    case privacy = "privacy"
    case sync = "sync"
    case advanced = "advanced"

    var displayName: String {
        switch self {
        case .general: return "General"
        case .notifications: return "Notifications"
        case .appearance: return "Appearance"
        case .privacy: return "Privacy"
        case .sync: return "Sync"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .appearance: return "paintbrush"
        case .privacy: return "shield"
        case .sync: return "arrow.clockwise.icloud"
        case .advanced: return "hammer"
        }
    }
}

// MARK: - Enums with Display Names

enum MapType: String, CaseIterable, SettingsDisplayable {
    case standard = "standard"
    case satellite = "satellite"
    case hybrid = "hybrid"

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        }
    }
}

enum DistanceUnit: String, CaseIterable, SettingsDisplayable {
    case miles = "miles"
    case kilometers = "kilometers"

    var displayName: String {
        switch self {
        case .miles: return "Miles"
        case .kilometers: return "Kilometers"
        }
    }
}

enum TemperatureUnit: String, CaseIterable, SettingsDisplayable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"

    var displayName: String {
        switch self {
        case .fahrenheit: return "Fahrenheit"
        case .celsius: return "Celsius"
        }
    }
}

enum WorkHour: String, CaseIterable, SettingsDisplayable {
    case hour6 = "06:00"
    case hour7 = "07:00"
    case hour8 = "08:00"
    case hour9 = "09:00"
    case hour17 = "17:00"
    case hour18 = "18:00"
    case hour19 = "19:00"
    case hour20 = "20:00"

    var displayName: String {
        return self.rawValue
    }
}

enum EmailTime: String, CaseIterable, SettingsDisplayable {
    case morning6 = "06:00"
    case morning8 = "08:00"
    case evening17 = "17:00"
    case evening19 = "19:00"

    var displayName: String {
        return self.rawValue
    }
}

enum NotificationTime: String, CaseIterable, SettingsDisplayable {
    case time20 = "20:00"
    case time21 = "21:00"
    case time22 = "22:00"
    case time6 = "06:00"
    case time7 = "07:00"
    case time8 = "08:00"

    var displayName: String {
        return self.rawValue
    }
}

enum AppTheme: String, CaseIterable, SettingsDisplayable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum AccentColor: String, CaseIterable, SettingsDisplayable {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case purple = "purple"

    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .purple: return "Purple"
        }
    }
}

enum DashboardLayout: String, CaseIterable, SettingsDisplayable {
    case standard = "standard"
    case compact = "compact"
    case detailed = "detailed"

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .compact: return "Compact"
        case .detailed: return "Detailed"
        }
    }
}

enum LocationAccuracy: String, CaseIterable, SettingsDisplayable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

enum SyncFrequency: String, CaseIterable, SettingsDisplayable {
    case realtime = "realtime"
    case minutes5 = "5min"
    case minutes15 = "15min"
    case hourly = "hourly"

    var displayName: String {
        switch self {
        case .realtime: return "Real-time"
        case .minutes5: return "Every 5 minutes"
        case .minutes15: return "Every 15 minutes"
        case .hourly: return "Hourly"
        }
    }
}

enum BackupFrequency: String, CaseIterable, SettingsDisplayable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum LogLevel: String, CaseIterable, SettingsDisplayable {
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"

    var displayName: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined

    var displayName: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        }
    }

    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .granted: return PestGenieDesignSystem.Colors.success
        case .denied: return PestGenieDesignSystem.Colors.error
        case .notDetermined: return PestGenieDesignSystem.Colors.warning
        }
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    // User profile
    @Published var fullName = "John Smith"
    @Published var technicianId = "T-12345"
    @Published var companyName = "PestControl Pro"
    @Published var email = "john.smith@pestcontrolpro.com"
    @Published var phoneNumber = "+1 (555) 123-4567"
    @Published var employeeId = "EMP001"

    var userInitials: String {
        let components = fullName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first?.uppercased() }
        return String(initials.prefix(2).joined())
    }

    // App preferences
    @Published var showWelcomeScreen = true
    @Published var autoStartGPS = true
    @Published var offlineModeEnabled = true
    @Published var defaultMapType: MapType = .standard
    @Published var distanceUnits: DistanceUnit = .miles
    @Published var temperatureUnits: TemperatureUnit = .fahrenheit

    // Work settings
    @Published var workDayStartTime: WorkHour = .hour8
    @Published var workDayEndTime: WorkHour = .hour17
    @Published var breakRemindersEnabled = true
    @Published var routeOptimizationEnabled = true
    @Published var automaticCheckin = false
    @Published var defaultServiceDuration = 45
    @Published var travelBufferTime = 15

    // Notification settings
    @Published var pushNotificationsEnabled = true
    @Published var jobRemindersEnabled = true
    @Published var weatherAlertsEnabled = true
    @Published var equipmentAlertsEnabled = true
    @Published var customerMessageAlertsEnabled = true
    @Published var supervisorAlertsEnabled = true
    @Published var jobReminderMinutes = 15

    @Published var emailNotificationsEnabled = true
    @Published var dailyEmailSummary = true
    @Published var weeklyEmailReports = true
    @Published var trainingEmailUpdates = true
    @Published var companyAnnouncementsEmail = true
    @Published var emailSummaryTime: EmailTime = .evening17

    @Published var smsNotificationsEnabled = false
    @Published var emergencyAlertsOnly = true
    @Published var routeChangeSMSEnabled = false
    @Published var urgentCustomerSMSEnabled = true

    @Published var doNotDisturbEnabled = true
    @Published var dndStartTime: NotificationTime = .time20
    @Published var dndEndTime: NotificationTime = .time7
    @Published var weekendDNDEnabled = true

    // Appearance settings
    @Published var appTheme: AppTheme = .system
    @Published var accentColor: AccentColor = .blue
    @Published var highContrastMode = false
    @Published var darkModeMaps = false
    @Published var textSizeScale = 1.0
    @Published var boldTextEnabled = false
    @Published var reduceMotionEnabled = false
    @Published var animationsEnabled = true
    @Published var dashboardLayout: DashboardLayout = .standard
    @Published var compactViewEnabled = false

    // Accessibility settings
    @Published var voiceOverEnabled = false
    @Published var hapticFeedbackEnabled = true
    @Published var audioCuesEnabled = false
    @Published var largeTouchTargetsEnabled = false
    @Published var buttonSizeScale = 1.0

    // Privacy settings
    @Published var locationTrackingEnabled = true
    @Published var backgroundLocationEnabled = true
    @Published var locationHistoryEnabled = true
    @Published var locationAccuracy: LocationAccuracy = .high
    @Published var locationDataRetentionDays = 90

    @Published var analyticsEnabled = true
    @Published var performanceDataEnabled = true
    @Published var crashReportsEnabled = true
    @Published var usageStatisticsEnabled = true

    // Permission statuses
    @Published var cameraPermissionStatus: PermissionStatus = .granted
    @Published var photoLibraryPermissionStatus: PermissionStatus = .granted
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined
    @Published var contactsPermissionStatus: PermissionStatus = .denied

    // Sync settings
    @Published var autoSyncEnabled = true
    @Published var wifiOnlySyncEnabled = false
    @Published var backgroundSyncEnabled = true
    @Published var syncFrequency: SyncFrequency = .minutes15
    @Published var syncRetryAttempts = 3
    @Published var lastSyncTime = Date().addingTimeInterval(-1800)

    // Backup settings
    @Published var automaticBackupsEnabled = true
    @Published var backupPhotosEnabled = true
    @Published var backupDocumentsEnabled = true
    @Published var backupFrequency: BackupFrequency = .daily
    @Published var backupRetentionDays = 30
    @Published var lastBackupTime = Date().addingTimeInterval(-86400)

    // Offline settings
    @Published var cacheRouteDataEnabled = true
    @Published var cacheCustomerDataEnabled = true
    @Published var cacheTrainingMaterialsEnabled = false
    @Published var cacheSizeLimitMB = 500
    @Published var currentCacheUsageMB = 125

    // Advanced settings
    @Published var debugModeEnabled = false
    @Published var betaFeaturesEnabled = false
    @Published var performanceMonitoringEnabled = false
    @Published var logLevel: LogLevel = .info
    @Published var showPerformanceOverlay = false
    @Published var mockLocationDataEnabled = false
    @Published var simulateNetworkIssuesEnabled = false

    // System information
    let appVersion = "2.1.0"
    let buildNumber = "105"
    let iosVersion = "17.5"
    let deviceModel = "iPhone 15 Pro"
    let storageUsedMB = 847
    let memoryUsageMB = 128

    func loadSettings() {
        // Load settings from UserDefaults or other persistence
        print("Loading settings...")
    }

    func resetToDefaults() {
        // Reset all settings to default values
        print("Resetting settings to defaults...")
    }
}

// MARK: - Preview

#Preview("Settings & Preferences") {
    SettingsPreferencesView()
}

#Preview("Settings Dark Mode") {
    SettingsPreferencesView()
        .preferredColorScheme(.dark)
}