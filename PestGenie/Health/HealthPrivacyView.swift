import SwiftUI

/// Health privacy and settings management view
struct HealthPrivacyView: View {
    @ObservedObject var healthManager: HealthKitManager
    @ObservedObject var routeViewModel: RouteViewModel
    @State private var showingDataExport = false
    @State private var showingHealthInsights = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Privacy Controls Section
                    PrivacyControlsSection(
                        settings: $healthManager.privacySettings,
                        onUpdate: { newSettings in
                            routeViewModel.updateHealthPrivacySettings(newSettings)
                        }
                    )

                    Divider()

                    // Current Status Section
                    CurrentStatusSection(
                        healthManager: healthManager,
                        routeViewModel: routeViewModel
                    )

                    Divider()

                    // Data Management Section
                    DataManagementSection(
                        healthManager: healthManager,
                        showingDataExport: $showingDataExport
                    )

                    Divider()

                    // Insights Section
                    if healthManager.isAuthorized {
                        InsightsSection(
                            routeViewModel: routeViewModel,
                            showingHealthInsights: $showingHealthInsights
                        )
                    }
                }
                .padding(PestGenieDesignSystem.Spacing.lg)
            }
            .navigationTitle("Health & Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDataExport) {
            HealthDataExportView(healthManager: healthManager)
        }
        .sheet(isPresented: $showingHealthInsights) {
            // Placeholder for health insights view
            Text("Health Insights")
                .navigationTitle("Insights")
        }
    }
}

/// Privacy controls section
struct PrivacyControlsSection: View {
    @Binding var settings: HealthPrivacySettings
    let onUpdate: (HealthPrivacySettings) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Privacy Controls")
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                PrivacyToggleRow(
                    title: "Health Tracking",
                    subtitle: "Track steps and activity during jobs",
                    isOn: $settings.allowHealthTracking
                ) {
                    onUpdate(settings)
                }

                PrivacyToggleRow(
                    title: "Apple Health Integration",
                    subtitle: "Sync data with Apple Health app",
                    isOn: $settings.shareWithAppleHealth
                ) {
                    onUpdate(settings)
                }

                PrivacyToggleRow(
                    title: "Weekly Reports",
                    subtitle: "Generate weekly activity summaries",
                    isOn: $settings.allowWeeklyReports
                ) {
                    onUpdate(settings)
                }

                PrivacyToggleRow(
                    title: "Job-Only Tracking",
                    subtitle: "Track activity only during active jobs",
                    isOn: $settings.trackOnlyDuringJobs
                ) {
                    onUpdate(settings)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(PestGenieDesignSystem.Colors.surface)
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)

            // Privacy Level Selector
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                Text("Privacy Level")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                    ForEach(HealthPrivacySettings.PrivacyLevel.allCases, id: \.rawValue) { level in
                        PrivacyLevelRow(
                            level: level,
                            isSelected: settings.privacyLevel == level
                        ) {
                            settings.privacyLevel = level
                            onUpdate(settings)
                        }
                    }
                }
                .padding(PestGenieDesignSystem.Spacing.md)
                .background(PestGenieDesignSystem.Colors.cardBackground)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
            }
        }
    }
}

/// Privacy toggle row
struct PrivacyToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let onChange: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) {
                    onChange()
                }
        }
    }
}

/// Privacy level selection row
struct PrivacyLevelRow: View {
    let level: HealthPrivacySettings.PrivacyLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(level.rawValue.capitalized)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(PestGenieDesignSystem.Colors.success)
                    }

                    Spacer()
                }

                Text(level.description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "radio.fill")
                    .font(.system(size: 16))
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
            } else {
                Image(systemName: "radio")
                    .font(.system(size: 16))
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

/// Current status section
struct CurrentStatusSection: View {
    @ObservedObject var healthManager: HealthKitManager
    @ObservedObject var routeViewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Current Status")
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                StatusRow(
                    title: "HealthKit Access",
                    value: healthManager.isAuthorized ? "Authorized" : "Not Authorized",
                    color: healthManager.isAuthorized ?
                        PestGenieDesignSystem.Colors.success :
                        PestGenieDesignSystem.Colors.error
                )

                StatusRow(
                    title: "Active Tracking",
                    value: healthManager.activeJobSession != nil ? "On Job" : "Idle",
                    color: healthManager.activeJobSession != nil ?
                        PestGenieDesignSystem.Colors.success :
                        PestGenieDesignSystem.Colors.textSecondary
                )

                StatusRow(
                    title: "Today's Steps",
                    value: "\(healthManager.todaysTotalSteps)",
                    color: PestGenieDesignSystem.Colors.info
                )

                if let session = healthManager.activeJobSession {
                    StatusRow(
                        title: "Current Job",
                        value: session.customerName,
                        color: PestGenieDesignSystem.Colors.accent
                    )

                    StatusRow(
                        title: "Job Steps",
                        value: "\(session.totalStepsWalked)",
                        color: PestGenieDesignSystem.Colors.accent
                    )
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(PestGenieDesignSystem.Colors.surface)
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)

            if !healthManager.isAuthorized {
                Button(action: {
                    Task {
                        await healthManager.requestAuthorization()
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Grant HealthKit Access")
                    }
                    .font(PestGenieDesignSystem.Typography.bodyMedium.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(PestGenieDesignSystem.Spacing.md)
                    .background(PestGenieDesignSystem.Colors.accent)
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
                }
            }
        }
    }
}

/// Status row display
struct StatusRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyMedium.weight(.medium))
                .foregroundColor(color)
        }
    }
}

/// Data management section
struct DataManagementSection: View {
    @ObservedObject var healthManager: HealthKitManager
    @Binding var showingDataExport: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Data Management")
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                DataManagementRow(
                    icon: "square.and.arrow.up",
                    title: "Export Health Data",
                    subtitle: "Download your health data"
                ) {
                    showingDataExport = true
                }

                DataManagementRow(
                    icon: "trash",
                    title: "Clear Local Data",
                    subtitle: "Remove locally stored health sessions"
                ) {
                    // Implement clear data functionality
                    clearLocalHealthData()
                }

                let sessionCount = healthManager.getAllHealthSessions().count
                HStack {
                    VStack(alignment: .leading) {
                        Text("Stored Sessions")
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text("\(sessionCount) job sessions saved locally")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(PestGenieDesignSystem.Colors.surface)
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        }
    }

    private func clearLocalHealthData() {
        // Implementation for clearing local health data
        let sessionIds = UserDefaults.standard.array(forKey: "all_health_sessions") as? [String] ?? []

        for sessionId in sessionIds {
            UserDefaults.standard.removeObject(forKey: "health_session_\(sessionId)")
        }

        UserDefaults.standard.removeObject(forKey: "all_health_sessions")
        UserDefaults.standard.removeObject(forKey: "health_privacy_settings")
    }
}

/// Data management action row
struct DataManagementRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(PestGenieDesignSystem.Colors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

/// Insights section
struct InsightsSection: View {
    @ObservedObject var routeViewModel: RouteViewModel
    @Binding var showingHealthInsights: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Health Insights")
                .font(PestGenieDesignSystem.Typography.headlineMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Button(action: {
                showingHealthInsights = true
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(PestGenieDesignSystem.Colors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("View Weekly Report")
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text("Activity trends and recommendations")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
                .padding(PestGenieDesignSystem.Spacing.md)
                .background(PestGenieDesignSystem.Colors.cardBackground)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Preview

struct HealthPrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        HealthPrivacyView(
            healthManager: HealthKitManager.shared,
            routeViewModel: RouteViewModel()
        )
    }
}