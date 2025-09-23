import SwiftUI

/// Enhanced dashboard card components following PestGenie design system standards.
/// These cards provide consistent visual presentation and improved user experience
/// for pest control technicians.

// MARK: - Job Status Card

struct JobStatusCard: View {
    let totalJobs: Int
    let completedJobs: Int
    let inProgressJobs: Int
    let completionPercentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 20))
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)

                Text("Job Progress")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("\(Int(completionPercentage * 100))%")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundColor(PestGenieDesignSystem.Colors.success)
            }

            // Statistics Row
            HStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                JobStatistic(
                    title: "Total",
                    value: "\(totalJobs)",
                    color: PestGenieDesignSystem.Colors.textPrimary,
                    accessibilityLabel: "\(totalJobs) total jobs"
                )

                Divider()
                    .frame(height: 32)
                    .background(PestGenieDesignSystem.Colors.border)

                JobStatistic(
                    title: "Done",
                    value: "\(completedJobs)",
                    color: PestGenieDesignSystem.Colors.success,
                    accessibilityLabel: "\(completedJobs) completed jobs"
                )

                Divider()
                    .frame(height: 32)
                    .background(PestGenieDesignSystem.Colors.border)

                JobStatistic(
                    title: "Active",
                    value: "\(inProgressJobs)",
                    color: PestGenieDesignSystem.Colors.info,
                    accessibilityLabel: "\(inProgressJobs) jobs in progress"
                )

                Divider()
                    .frame(height: 32)
                    .background(PestGenieDesignSystem.Colors.border)

                JobStatistic(
                    title: "Left",
                    value: "\(totalJobs - completedJobs)",
                    color: PestGenieDesignSystem.Colors.warning,
                    accessibilityLabel: "\(totalJobs - completedJobs) remaining jobs"
                )
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                HStack {
                    Text("Daily Progress")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("\(completedJobs)/\(totalJobs) completed")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                ProgressView(value: completionPercentage)
                    .progressViewStyle(CustomProgressViewStyle())
            }
        }
        .pestGenieCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Job progress card showing \(completedJobs) of \(totalJobs) jobs completed")
    }
}

// MARK: - Weather Status Card

struct WeatherStatusCard: View {
    @StateObject private var weatherManager = WeatherDataManager.shared
    @State private var showingWeatherDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: weatherIcon)
                    .font(.system(size: 20))
                    .foregroundColor(weatherColor)

                Text("Weather Status")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button("Details") {
                    showingWeatherDetails = true
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.accent)
            }

            // Current Conditions
            if let weather = weatherManager.currentWeather {
                HStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Temperature
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                        Text("\(Int(weather.temperature))°F")
                            .font(PestGenieDesignSystem.Typography.displaySmall)
                            .fontWeight(.bold)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text(weather.condition)
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Work Conditions
                    VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                        workConditionIndicator

                        Text("Work Conditions")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }
                }

                // Wind and Additional Info
                HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    WeatherDetail(icon: "wind", label: "Wind", value: "\(Int(weather.windSpeed)) mph")
                    WeatherDetail(icon: "humidity", label: "Humidity", value: "\(Int(weather.humidity))%")
                }
            } else {
                Text("Weather data unavailable")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
        .pestGenieCard()
        .sheet(isPresented: $showingWeatherDetails) {
            WeatherDetailsSheet()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather status card")
    }

    private var weatherIcon: String {
        guard let weather = weatherManager.currentWeather else { return "cloud.fill" }

        switch weather.condition.lowercased() {
        case let condition where condition.contains("sun") || condition.contains("clear"):
            return "sun.max.fill"
        case let condition where condition.contains("rain"):
            return "cloud.rain.fill"
        case let condition where condition.contains("storm"):
            return "cloud.bolt.fill"
        default:
            return "cloud.fill"
        }
    }

    private var weatherColor: Color {
        guard let weather = weatherManager.currentWeather else { return PestGenieDesignSystem.Colors.weatherCloudy }

        switch weather.condition.lowercased() {
        case let condition where condition.contains("sun") || condition.contains("clear"):
            return PestGenieDesignSystem.Colors.weatherSunny
        case let condition where condition.contains("rain"):
            return PestGenieDesignSystem.Colors.weatherRainy
        case let condition where condition.contains("storm"):
            return PestGenieDesignSystem.Colors.weatherStormy
        default:
            return PestGenieDesignSystem.Colors.weatherCloudy
        }
    }

    private var workConditionIndicator: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Circle()
                .pestGenieStatusIndicator(color: workConditionColor)

            Text(workConditionText)
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(workConditionColor)
        }
    }

    private var workConditionColor: Color {
        guard let weather = weatherManager.currentWeather else { return PestGenieDesignSystem.Colors.textSecondary }

        if weather.windSpeed > 15 || weather.condition.lowercased().contains("storm") {
            return PestGenieDesignSystem.Colors.error
        } else if weather.windSpeed > 10 || weather.condition.lowercased().contains("rain") {
            return PestGenieDesignSystem.Colors.warning
        } else {
            return PestGenieDesignSystem.Colors.success
        }
    }

    private var workConditionText: String {
        guard let weather = weatherManager.currentWeather else { return "Unknown" }

        if weather.windSpeed > 15 || weather.condition.lowercased().contains("storm") {
            return "Poor"
        } else if weather.windSpeed > 10 || weather.condition.lowercased().contains("rain") {
            return "Fair"
        } else {
            return "Good"
        }
    }
}

// MARK: - Equipment Status Card

struct EquipmentStatusCard: View {
    let equipmentItems: [EquipmentItem]
    let onEquipmentTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 20))
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)

                Text("Equipment Status")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button("View All") {
                    onEquipmentTap()
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.accent)
            }

            // Equipment Summary
            HStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                EquipmentStatistic(
                    title: "Ready",
                    count: equipmentItems.filter { $0.status == .available }.count,
                    total: equipmentItems.count,
                    color: PestGenieDesignSystem.Colors.success
                )

                EquipmentStatistic(
                    title: "Maintenance",
                    count: equipmentItems.filter { $0.status == .maintenance }.count,
                    total: equipmentItems.count,
                    color: PestGenieDesignSystem.Colors.warning
                )

                EquipmentStatistic(
                    title: "Issues",
                    count: equipmentItems.filter { $0.status == .retired }.count,
                    total: equipmentItems.count,
                    color: PestGenieDesignSystem.Colors.error
                )
            }

            // Critical Equipment Alerts
            if let criticalItem = equipmentItems.first(where: { $0.status == .retired }) {
                CriticalEquipmentAlert(item: criticalItem)
            } else if let maintenanceItem = equipmentItems.first(where: { $0.status == .maintenance }) {
                MaintenanceEquipmentAlert(item: maintenanceItem)
            }
        }
        .pestGenieCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Equipment status card")
    }
}

// MARK: - Notifications Card

struct NotificationsCard: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var showingNotifications = false

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "bell.badge")
                    .font(.system(size: 20))
                    .foregroundColor(PestGenieDesignSystem.Colors.warning)

                Text("Notifications")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                if notificationManager.unreadCount > 0 {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Circle()
                            .fill(PestGenieDesignSystem.Colors.error)
                            .frame(width: 8, height: 8)

                        Text("\(notificationManager.unreadCount) new")
                            .font(PestGenieDesignSystem.Typography.captionEmphasis)
                            .foregroundColor(PestGenieDesignSystem.Colors.error)
                    }
                }

                Button("View All") {
                    showingNotifications = true
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.accent)
            }

            // Recent Notifications
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(notificationManager.recentNotifications.prefix(3)) { notification in
                    NotificationRow(notification: notification)
                }

                if notificationManager.recentNotifications.isEmpty {
                    Text("No recent notifications")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.md)
                }
            }
        }
        .pestGenieCard()
        .sheet(isPresented: $showingNotifications) {
            NotificationsSheet()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notifications card with \(notificationManager.unreadCount) unread notifications")
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    let onStartRoute: () -> Void
    let onEmergencyCall: () -> Void
    let onQRScanner: () -> Void
    let onEquipmentCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "bolt.circle")
                    .font(.system(size: 20))
                    .foregroundColor(PestGenieDesignSystem.Colors.secondary)

                Text("Quick Actions")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()
            }

            // Action Buttons Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                QuickActionButton(
                    title: "Start Route",
                    icon: "play.circle.fill",
                    color: PestGenieDesignSystem.Colors.success,
                    action: onStartRoute
                )

                QuickActionButton(
                    title: "QR Scanner",
                    icon: "qrcode.viewfinder",
                    color: PestGenieDesignSystem.Colors.accent,
                    action: onQRScanner
                )

                QuickActionButton(
                    title: "Equipment",
                    icon: "wrench.and.screwdriver.fill",
                    color: PestGenieDesignSystem.Colors.primary,
                    action: onEquipmentCheck
                )

                QuickActionButton(
                    title: "Emergency",
                    icon: "phone.fill",
                    color: PestGenieDesignSystem.Colors.emergency,
                    action: onEmergencyCall
                )
            }
        }
        .pestGenieCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quick actions card")
    }
}

// MARK: - Supporting Components

struct JobStatistic: View {
    let title: String
    let value: String
    let color: Color
    let accessibilityLabel: String

    var body: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xxxs) {
            Text(value)
                .font(PestGenieDesignSystem.Typography.displaySmall)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct WeatherDetail: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                Text(value)
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(label)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
    }
}

struct EquipmentStatistic: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xxxs) {
            Text("\(count)")
                .font(PestGenieDesignSystem.Typography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .accessibilityLabel("\(count) equipment items \(title.lowercased())")
    }
}

struct CriticalEquipmentAlert: View {
    let item: EquipmentItem

    var body: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(PestGenieDesignSystem.Colors.error)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                Text("Critical: \(item.name)")
                    .font(PestGenieDesignSystem.Typography.labelMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.error)

                Text("Out of service - Requires immediate attention")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.error.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }
}

struct MaintenanceEquipmentAlert: View {
    let item: EquipmentItem

    var body: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: "wrench.fill")
                .foregroundColor(PestGenieDesignSystem.Colors.warning)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                Text("Maintenance: \(item.name)")
                    .font(PestGenieDesignSystem.Typography.labelMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.warning)

                Text("Scheduled maintenance required")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.warning.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }
}

struct NotificationRow: View {
    let notification: PestGenieNotification

    var body: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: notification.icon)
                .foregroundColor(notification.priority.color)
                .font(.system(size: 16))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                Text(notification.title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Text(notification.message)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(PestGenieDesignSystem.Colors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xxxs)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
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
}

// MARK: - Custom Progress View Style

struct CustomProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.surfaceSecondary)
                .frame(height: 8)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)

            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            PestGenieDesignSystem.Colors.success,
                            PestGenieDesignSystem.Colors.success.opacity(0.8)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: (configuration.fractionCompleted ?? 0) * 200, height: 8)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
                .animation(.easeInOut(duration: 0.3), value: configuration.fractionCompleted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Data Models

struct EquipmentItem: Identifiable {
    let id = UUID()
    let name: String
    let status: EquipmentStatus
    let lastMaintenance: Date?
    let nextMaintenance: Date?
}


// MARK: - Sheet Views

struct WeatherDetailsSheet: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Text("Detailed Weather Information")
                .navigationTitle("Weather Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
}

struct NotificationsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var notificationManager: NotificationManager

    var body: some View {
        NavigationView {
            List {
                ForEach(notificationManager.recentNotifications) { notification in
                    NotificationRow(notification: notification)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.xxxs)
                }
            }
            .navigationTitle("All Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview Support

#Preview("Job Status Card") {
    JobStatusCard(
        totalJobs: 8,
        completedJobs: 5,
        inProgressJobs: 1,
        completionPercentage: 0.625
    )
    .padding()
}

#Preview("Weather Status Card") {
    WeatherStatusCard()
        .padding()
}

#Preview("Equipment Status Card") {
    EquipmentStatusCard(
        equipmentItems: [
            EquipmentItem(name: "Sprayer A", status: .available, lastMaintenance: Date(), nextMaintenance: Date()),
            EquipmentItem(name: "Sprayer B", status: .maintenance, lastMaintenance: Date(), nextMaintenance: Date()),
            EquipmentItem(name: "Tank C", status: .repair, lastMaintenance: Date(), nextMaintenance: Date())
        ],
        onEquipmentTap: {}
    )
    .padding()
}

#Preview("Quick Actions Card") {
    QuickActionsCard(
        onStartRoute: {},
        onEmergencyCall: {},
        onQRScanner: {},
        onEquipmentCheck: {}
    )
    .padding()
}