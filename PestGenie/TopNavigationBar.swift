import SwiftUI
import CoreLocation

/// Professional top navigation bar designed for pest control technicians.
/// Provides contextual information, status indicators, and emergency access.
struct TopNavigationBar: View {
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @StateObject private var weatherManager = WeatherDataManager.shared
    @StateObject private var syncManager = SyncManager.shared

    @State private var showingWeatherDetails = false
    @State private var showingNotifications = false
    @Binding var showingMenu: Bool

    let technicianName: String

    init(technicianName: String = "Technician", showingMenu: Binding<Bool>) {
        self.technicianName = technicianName
        self._showingMenu = showingMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main navigation content
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                // Hamburger menu button
                menuButton

                // User greeting and route info
                userInfoSection

                Spacer(minLength: 8) // Ensure minimum spacing

                // Status indicators
                statusIndicatorsSection
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
            .frame(height: PestGenieDesignSystem.Components.Navigation.height)
            .background(PestGenieDesignSystem.Colors.background)

            // Bottom border
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: PestGenieDesignSystem.Components.Navigation.borderWidth)
        }
        .sheet(isPresented: $showingWeatherDetails) {
            weatherDetailsSheet
        }
        .sheet(isPresented: $showingNotifications) {
            notificationsSheet
        }
        .onAppear {
            setupWeatherUpdates()
        }
    }

    // MARK: - Menu Button

    private var menuButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingMenu = true
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: PestGenieDesignSystem.Components.Navigation.iconSize, weight: .medium))
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.xs)
                        .fill(PestGenieDesignSystem.Colors.surface)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Menu")
        .accessibilityHint("Open navigation menu")
    }

    // MARK: - User Info Section

    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Greeting - improved to show complete message
            Text(greetingText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85) // Allow text to scale down slightly if needed

            // Route info
            HStack(spacing: PestGenieDesignSystem.Spacing.xxxs) {
                Image(systemName: "map")
                    .font(.system(size: 11))
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                Text(routeInfoText)
                    .font(.system(size: 12))
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Indicators Section

    private var statusIndicatorsSection: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
            // Sync status (simplified)
            syncStatusIndicator

            // Notifications (primary action)
            notificationIndicator
        }
    }

    // MARK: - Weather Status Indicator

    private var weatherStatusIndicator: some View {
        Button(action: {
            showingWeatherDetails = true
        }) {
            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                Image(systemName: weatherIcon)
                    .font(.system(size: PestGenieDesignSystem.Components.Navigation.iconSize - 4))
                    .foregroundColor(weatherColor)

                if let temperature = weatherManager.currentWeather?.temperature {
                    Text("\(Int(temperature))°")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .frame(height: 32) // Standard navigation button height
            .background(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                    .fill(PestGenieDesignSystem.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Weather status: \(weatherAccessibilityLabel)")
        .accessibilityHint("Tap to view detailed weather information")
    }

    // MARK: - Sync Status Indicator

    private var syncStatusIndicator: some View {
        Button(action: {
            Task {
                await syncManager.syncNow()
            }
        }) {
            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                ZStack {
                    Circle()
                        .pestGenieStatusIndicator(color: syncStatusColor)

                    if syncManager.isSyncing {
                        Circle()
                            .stroke(PestGenieDesignSystem.Colors.accent, lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .rotationEffect(.degrees(syncRotation))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: syncRotation)
                    }
                }

                if !syncManager.syncErrors.isEmpty {
                    Text("\(syncManager.syncErrors.count)")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .frame(height: 32) // Standard navigation button height
            .background(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                    .fill(PestGenieDesignSystem.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Sync status: \(syncAccessibilityLabel)")
        .accessibilityHint("Tap to sync data")
    }

    // MARK: - Notification Indicator

    private var notificationIndicator: some View {
        Button(action: {
            showingNotifications = true
        }) {
            ZStack {
                Image(systemName: "bell")
                    .font(.system(size: PestGenieDesignSystem.Components.Navigation.iconSize - 4))
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                if notificationManager.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(PestGenieDesignSystem.Colors.error)
                            .frame(width: PestGenieDesignSystem.Components.Navigation.badgeSize, height: PestGenieDesignSystem.Components.Navigation.badgeSize)

                        Text("\(min(notificationManager.unreadCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -8)
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .frame(height: 32) // Standard navigation button height
            .background(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                    .fill(PestGenieDesignSystem.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Notifications: \(notificationManager.unreadCount) unread")
        .accessibilityHint("Tap to view notifications")
    }


    // MARK: - Computed Properties

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening"
        return "Good \(timeOfDay), \(technicianName)"
    }

    private var routeInfoText: String {
        let totalJobs = routeViewModel.jobs.count
        let completedJobs = routeViewModel.completedJobsCount
        return "\(completedJobs)/\(totalJobs) jobs • Route \(routeViewModel.currentRouteId)"
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
        case let condition where condition.contains("snow"):
            return "cloud.snow.fill"
        case let condition where condition.contains("cloud"):
            return "cloud.fill"
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

    private var weatherAccessibilityLabel: String {
        guard let weather = weatherManager.currentWeather else { return "Weather information unavailable" }
        return "\(weather.condition), \(Int(weather.temperature)) degrees"
    }

    private var syncStatusColor: Color {
        if syncManager.isSyncing {
            return PestGenieDesignSystem.Colors.statusSyncing
        } else if routeViewModel.isOnline {
            return PestGenieDesignSystem.Colors.statusOnline
        } else {
            return PestGenieDesignSystem.Colors.statusOffline
        }
    }

    private var syncAccessibilityLabel: String {
        if syncManager.isSyncing {
            return "Syncing data"
        } else if routeViewModel.isOnline {
            return "Online and synced"
        } else {
            return "Offline mode"
        }
    }

    @State private var syncRotation: Double = 0

    // MARK: - Sheet Views

    private var emergencyOptionsSheet: some View {
        NavigationView {
            VStack(spacing: PestGenieDesignSystem.Spacing.xl) {
                // Emergency header
                VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(PestGenieDesignSystem.Colors.emergency)

                    Text("Emergency Contacts")
                        .font(PestGenieDesignSystem.Typography.headlineLarge)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text("Choose an emergency contact option")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, PestGenieDesignSystem.Spacing.xl)

                // Emergency options
                VStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    emergencyContactButton(
                        title: "911 Emergency",
                        subtitle: "Fire, Medical, Police",
                        icon: "phone.badge.plus",
                        color: PestGenieDesignSystem.Colors.emergency,
                        phoneNumber: "911"
                    )

                    emergencyContactButton(
                        title: "Supervisor",
                        subtitle: "John Smith • Direct Line",
                        icon: "person.badge.shield.checkmark",
                        color: PestGenieDesignSystem.Colors.primary,
                        phoneNumber: "+1-555-0123"
                    )

                    emergencyContactButton(
                        title: "Company Dispatch",
                        subtitle: "24/7 Support Center",
                        icon: "building.2",
                        color: PestGenieDesignSystem.Colors.accent,
                        phoneNumber: "+1-555-0456"
                    )

                    emergencyContactButton(
                        title: "Safety Hotline",
                        subtitle: "Chemical & Equipment Issues",
                        icon: "shield.checkered",
                        color: PestGenieDesignSystem.Colors.warning,
                        phoneNumber: "+1-555-0789"
                    )
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.md)

                Spacer()
            }
            .navigationTitle("Emergency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingEmergencyOptions = false
                    }
                }
            }
        }
    }

    private var weatherDetailsSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Current weather
                    currentWeatherCard

                    // Weather alerts (placeholder - weather alerts system would be implemented here)

                    // Hourly forecast
                    hourlyForecastCard

                    // Work conditions
                    workConditionsCard
                }
                .padding(PestGenieDesignSystem.Spacing.md)
            }
            .navigationTitle("Weather Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingWeatherDetails = false
                    }
                }
            }
        }
    }

    private var notificationsSheet: some View {
        NavigationView {
            List {
                ForEach(notificationManager.recentNotifications) { notification in
                    NotificationRowView(notification: notification)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingNotifications = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func emergencyContactButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        phoneNumber: String
    ) -> some View {
        Button(action: {
            makeEmergencyCall(to: phoneNumber)
        }) {
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                    Text(title)
                        .font(PestGenieDesignSystem.Typography.titleMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(subtitle)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
        .pestGenieCard()
    }

    private var currentWeatherCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Current Conditions")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                Spacer()
                Text("Updated recently")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            if let weather = weatherManager.currentWeather {
                HStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                        Text("\(Int(weather.temperature))°")
                            .font(PestGenieDesignSystem.Typography.displayMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text(weather.condition)
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                        weatherDetailRow("Wind", "\(Int(weather.windSpeed)) mph")
                        weatherDetailRow("Humidity", "\(Int(weather.humidity))%")
                        weatherDetailRow("Pressure", String(format: "%.1f inHg", weather.pressure))
                    }
                }
            }
        }
        .pestGenieCard()
    }

    private func weatherDetailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
            Text(label)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            Text(value)
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
        }
    }

    private func weatherAlertsCard(alerts: [WeatherAlert]) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Weather Alerts")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(PestGenieDesignSystem.Colors.warning)

                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                        Text(alert.title)
                            .font(PestGenieDesignSystem.Typography.labelMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text(alert.message)
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
        .pestGenieCard()
    }

    private var hourlyForecastCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Next 8 Hours")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    ForEach(0..<4, id: \.self) { hour in
                        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            Text("\(hour + 1)PM")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                            Image(systemName: "cloud.fill") // This would be dynamic based on forecast
                                .font(.system(size: 20))
                                .foregroundColor(PestGenieDesignSystem.Colors.weatherCloudy)

                            Text("\(75 + hour)°")
                                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
            }
        }
        .pestGenieCard()
    }

    private var workConditionsCard: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Work Conditions")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                workConditionRow(
                    title: "Spray Conditions",
                    status: workConditionStatus,
                    icon: "drop.fill"
                )

                workConditionRow(
                    title: "Outdoor Work",
                    status: outdoorWorkStatus,
                    icon: "sun.max.fill"
                )

                workConditionRow(
                    title: "Equipment Safety",
                    status: equipmentSafetyStatus,
                    icon: "shield.checkered"
                )
            }
        }
        .pestGenieCard()
    }

    private func workConditionRow(title: String, status: WorkConditionStatus, icon: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(status.color)
                .frame(width: 20)

            Text(title)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            Text(status.label)
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(status.color)
        }
    }

    // MARK: - Helper Methods

    private func setupWeatherUpdates() {
        if let location = locationManager.currentLocation {
            Task {
                // Weather fetch would be implemented here
            }
        }

        // Update sync rotation animation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if syncManager.isSyncing {
                withAnimation(.linear(duration: 1)) {
                    syncRotation += 36 // 360 degrees over 1 second
                }
            }
        }
    }

    private func makeEmergencyCall(to phoneNumber: String) {
        showingEmergencyOptions = false

        // In a real app, this would initiate a phone call
        if let url = URL(string: "tel:\(phoneNumber)") {
            #if canImport(UIKit)
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            #endif
        }
    }

    private func alertSeverityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "severe", "extreme":
            return PestGenieDesignSystem.Colors.error
        case "moderate":
            return PestGenieDesignSystem.Colors.warning
        default:
            return PestGenieDesignSystem.Colors.info
        }
    }

    // MARK: - Computed Status Properties

    private var workConditionStatus: WorkConditionStatus {
        guard let weather = weatherManager.currentWeather else {
            return WorkConditionStatus(label: "Unknown", color: PestGenieDesignSystem.Colors.textSecondary)
        }

        if weather.windSpeed > 15 {
            return WorkConditionStatus(label: "Poor", color: PestGenieDesignSystem.Colors.error)
        } else if weather.windSpeed > 10 || weather.condition.lowercased().contains("rain") {
            return WorkConditionStatus(label: "Fair", color: PestGenieDesignSystem.Colors.warning)
        } else {
            return WorkConditionStatus(label: "Good", color: PestGenieDesignSystem.Colors.success)
        }
    }

    private var outdoorWorkStatus: WorkConditionStatus {
        guard let weather = weatherManager.currentWeather else {
            return WorkConditionStatus(label: "Unknown", color: PestGenieDesignSystem.Colors.textSecondary)
        }

        if weather.temperature < 32 || weather.temperature > 95 {
            return WorkConditionStatus(label: "Caution", color: PestGenieDesignSystem.Colors.warning)
        } else {
            return WorkConditionStatus(label: "Safe", color: PestGenieDesignSystem.Colors.success)
        }
    }

    private var equipmentSafetyStatus: WorkConditionStatus {
        guard let weather = weatherManager.currentWeather else {
            return WorkConditionStatus(label: "Unknown", color: PestGenieDesignSystem.Colors.textSecondary)
        }

        if weather.condition.lowercased().contains("storm") || weather.condition.lowercased().contains("lightning") {
            return WorkConditionStatus(label: "Danger", color: PestGenieDesignSystem.Colors.error)
        } else if weather.condition.lowercased().contains("rain") {
            return WorkConditionStatus(label: "Caution", color: PestGenieDesignSystem.Colors.warning)
        } else {
            return WorkConditionStatus(label: "Safe", color: PestGenieDesignSystem.Colors.success)
        }
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }
}

// MARK: - Supporting Types

struct WorkConditionStatus {
    let label: String
    let color: Color
}

struct NotificationRowView: View {
    let notification: PestGenieNotification

    var body: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: notification.icon)
                .foregroundColor(notification.priority.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxxs) {
                Text(notification.title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(notification.message)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)

                Text(notification.timestamp, style: .relative)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(PestGenieDesignSystem.Colors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
    }
}

// MARK: - Preview

#Preview("Top Navigation Bar") {
    TopNavigationBar(technicianName: "John Smith", showingMenu: .constant(false))
        .environmentObject(RouteViewModel())
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager.shared)
}

#Preview("Top Navigation Dark Mode") {
    TopNavigationBar(technicianName: "Sarah Johnson", showingMenu: .constant(false))
        .environmentObject(RouteViewModel())
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager.shared)
        .preferredColorScheme(.dark)
}