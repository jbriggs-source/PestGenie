import SwiftUI
import CoreLocation

/// Professional top navigation bar designed for pest control technicians.
/// Provides contextual information, status indicators, and emergency access.
struct TopNavigationBar: View {
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var authManager: AuthenticationManager
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

                // User greeting and route info (give it more space)
                userInfoSection

                Spacer(minLength: 8) // Slightly more spacing to prevent cramping

                // Status indicators (compact)
                statusIndicatorsSection
                    .layoutPriority(0) // Lower priority than user info
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
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // User profile picture
            UserProfilePictureView(
                profileImageURL: authManager.currentUser?.profileImageURL,
                size: 36,
                fallbackColor: PestGenieDesignSystem.Colors.primary
            )

            VStack(alignment: .leading, spacing: 2) {
                // Greeting with first name only (better UX, less truncation)
                Text(greetingText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.90) // Slightly higher scale factor since we use first name only
                    .fixedSize(horizontal: true, vertical: false) // Prevent truncation when possible

                // Route info
                HStack(spacing: PestGenieDesignSystem.Spacing.xxxs) {
                    Image(systemName: "map")
                        .font(.system(size: 11))
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text(routeInfoText)
                        .font(.system(size: 12))
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .layoutPriority(1) // Give text section priority over other elements
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

    // MARK: - Sync Status Indicator (Simplified)

    private var syncStatusIndicator: some View {
        Button(action: {
            Task {
                await syncManager.syncNow()
            }
        }) {
            ZStack {
                // Simple status dot
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)

                if syncManager.isSyncing {
                    Circle()
                        .stroke(syncStatusColor, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(syncRotation))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: syncRotation)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Sync status: \(syncAccessibilityLabel)")
        .accessibilityHint("Tap to sync data")
    }

    // MARK: - Notification Indicator (Primary)

    private var notificationIndicator: some View {
        Button(action: {
            showingNotifications = true
        }) {
            ZStack {
                Image(systemName: notificationManager.unreadCount > 0 ? "bell.badge" : "bell")
                    .font(.system(size: PestGenieDesignSystem.Components.Navigation.iconSize - 2))
                    .foregroundColor(notificationManager.unreadCount > 0 ? PestGenieDesignSystem.Colors.accent : PestGenieDesignSystem.Colors.textSecondary)

                if notificationManager.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(PestGenieDesignSystem.Colors.error)
                            .frame(width: 16, height: 16)

                        Text("\(min(notificationManager.unreadCount, 9))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 10, y: -8)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                    .fill(PestGenieDesignSystem.Colors.surface.opacity(0.8))
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

        // Use authenticated user's name if available, fallback to provided technicianName
        let fullName = authManager.currentUser?.name ?? technicianName

        // Extract first name for better UX and to prevent truncation
        let firstName = extractFirstName(from: fullName)

        return "Good \(timeOfDay), \(firstName)"
    }

    /// Extracts the first name from a full name string
    private func extractFirstName(from fullName: String) -> String {
        let components = fullName.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
        return components.first ?? fullName
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
        if locationManager.currentLocation != nil {
            Task {
                // Weather fetch would be implemented here
            }
        }

        // Update sync rotation animation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if syncManager.isSyncing {
                    withAnimation(.linear(duration: 1)) {
                        syncRotation += 36 // 360 degrees over 1 second
                    }
                }
            }
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
        .environmentObject(LocationManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(AuthenticationManager.shared)
}

#Preview("Top Navigation Dark Mode") {
    TopNavigationBar(technicianName: "Sarah Johnson", showingMenu: .constant(false))
        .environmentObject(RouteViewModel())
        .environmentObject(LocationManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(AuthenticationManager.shared)
        .preferredColorScheme(.dark)
}