import Foundation
import UserNotifications
import CoreLocation

/// Manages weather-based notifications and safety alerts for field technicians
@MainActor
final class WeatherNotificationManager: ObservableObject {
    static let shared = WeatherNotificationManager()

    @Published var activeWeatherAlerts: [WeatherNotificationItem] = []
    @Published var isMonitoringWeather = false

    private let notificationManager = NotificationManager.shared
    private let weatherAPI = WeatherAPI.shared
    private let weatherDataManager = WeatherDataManager.shared

    private var monitoringTimer: Timer?
    private var lastKnownLocation: CLLocationCoordinate2D?

    private init() {
        // Initialize weather monitoring setup
    }

    // MARK: - Weather Monitoring

    func startWeatherMonitoring(for location: CLLocationCoordinate2D) {
        lastKnownLocation = location
        isMonitoringWeather = true

        // Monitor weather every 10 minutes
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            Task { @MainActor in
                await self.checkWeatherConditions()
            }
        }

        // Check immediately
        Task {
            await checkWeatherConditions()
        }
    }

    func stopWeatherMonitoring() {
        isMonitoringWeather = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        activeWeatherAlerts.removeAll()
    }

    private func checkWeatherConditions() async {
        guard let location = lastKnownLocation else { return }

        do {
            let currentWeather = try await weatherAPI.fetchCurrentWeather(for: location)
            let safetyResult = weatherAPI.checkTreatmentSafety(for: currentWeather)

            // Check for critical weather alerts
            if let weatherAlert = weatherAPI.shouldSendWeatherAlert(for: currentWeather) {
                await handleWeatherAlert(weatherAlert, for: location)
            }

            // Check for safety condition changes
            await evaluateSafetyConditions(safetyResult, weather: currentWeather, location: location)

        } catch {
            print("Failed to check weather conditions: \(error)")
        }
    }

    // MARK: - Weather Alert Handling

    private func handleWeatherAlert(_ alert: WeatherAlert, for location: CLLocationCoordinate2D) async {
        // Check if we already have this alert
        let existingAlert = activeWeatherAlerts.first { $0.id == alert.title.hashValue }
        guard existingAlert == nil else { return }

        let notificationItem = WeatherNotificationItem(
            id: alert.title.hashValue,
            title: alert.title,
            message: alert.message,
            priority: alert.priority,
            alertType: alert.type,
            timestamp: Date(),
            location: location,
            isRead: false
        )

        activeWeatherAlerts.append(notificationItem)

        // Send push notification based on priority
        await sendWeatherNotification(notificationItem)

        // Save to Core Data
        await weatherDataManager.saveWeatherAlert(alert, for: location)
    }

    private func evaluateSafetyConditions(_ safetyResult: TreatmentSafetyResult, weather: WeatherData, location: CLLocationCoordinate2D) async {
        // Alert for unsafe conditions
        if !safetyResult.canTreat {
            let alert = WeatherAlert(
                type: .technicianSafety,
                title: "Treatment Conditions Unsafe",
                message: "Current weather conditions are not suitable for chemical treatments. Review safety warnings before proceeding.",
                priority: .high
            )
            await handleWeatherAlert(alert, for: location)
        }

        // Alert for improving conditions
        if safetyResult.canTreat && !safetyResult.warnings.isEmpty {
            let alert = WeatherAlert(
                type: .technicianSafety,
                title: "Treatment Conditions Improving",
                message: "Weather conditions are becoming more suitable for treatments, but some precautions are still needed.",
                priority: .normal
            )
            await handleWeatherAlert(alert, for: location)
        }

        // Specific alerts for dangerous conditions
        for warning in safetyResult.warnings {
            await handleSafetyWarning(warning, location: location)
        }
    }

    private func handleSafetyWarning(_ warning: SafetyWarning, location: CLLocationCoordinate2D) async {
        let (alertType, priority) = classifyWarning(warning)

        let alert = WeatherAlert(
            type: alertType,
            title: warning.title,
            message: warning.description,
            priority: priority
        )

        await handleWeatherAlert(alert, for: location)
    }

    private func classifyWarning(_ warning: SafetyWarning) -> (WeatherAlertType, AlertPriority) {
        switch warning {
        case .highWind(let speed):
            if speed > 20 {
                return (.criticalWind, .critical)
            } else {
                return (.criticalWind, .high)
            }
        case .highTemperature(let temp):
            if temp > 95 {
                return (.extremeHeat, .high)
            } else {
                return (.extremeHeat, .normal)
            }
        case .lowTemperature(let temp):
            if temp < 32 {
                return (.extremeCold, .high)
            } else {
                return (.extremeCold, .normal)
            }
        case .precipitationRisk(let probability):
            if probability > 70 {
                return (.severeWeather, .high)
            } else {
                return (.severeWeather, .normal)
            }
        case .highUVIndex:
            return (.technicianSafety, .normal)
        case .highHumidity:
            return (.technicianSafety, .low)
        }
    }

    // MARK: - Notification Delivery

    private func sendWeatherNotification(_ notificationItem: WeatherNotificationItem) async {
        var content = UNMutableNotificationContent()
        content.title = notificationItem.title
        content.body = notificationItem.message
        content.sound = soundForPriority(notificationItem.priority)
        content.categoryIdentifier = "WEATHER_ALERT"

        // Add emergency alert for critical conditions
        if notificationItem.priority == .critical {
            content.interruptionLevel = .critical
        }

        // Add location and weather data
        content.userInfo = [
            "type": "weather_alert",
            "alertType": String(describing: notificationItem.alertType),
            "priority": String(describing: notificationItem.priority),
            "latitude": notificationItem.location.latitude,
            "longitude": notificationItem.location.longitude,
            "timestamp": notificationItem.timestamp.timeIntervalSince1970
        ]

        // Add action buttons based on alert type
        content = addNotificationActions(to: content, for: notificationItem)

        let request = UNNotificationRequest(
            identifier: "weather_alert_\(notificationItem.id)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Weather notification sent: \(notificationItem.title)")
        } catch {
            print("Failed to send weather notification: \(error)")
        }

        // Post local notification for UI updates
        NotificationCenter.default.post(
            name: .weatherAlertReceived,
            object: notificationItem
        )
    }

    private func soundForPriority(_ priority: AlertPriority) -> UNNotificationSound {
        switch priority {
        case .critical:
            return .default
        case .high:
            return .defaultCritical
        default:
            return .default
        }
    }

    private func addNotificationActions(to content: UNMutableNotificationContent, for item: WeatherNotificationItem) -> UNMutableNotificationContent {
        switch item.alertType {
        case .criticalWind, .severeWeather:
            // Actions for stopping work
            let stopWorkAction = UNNotificationAction(
                identifier: "STOP_WORK",
                title: "Stop Current Treatment",
                options: [.foreground]
            )
            let viewConditionsAction = UNNotificationAction(
                identifier: "VIEW_CONDITIONS",
                title: "View Conditions",
                options: [.foreground]
            )

            let category = UNNotificationCategory(
                identifier: "WEATHER_ALERT",
                actions: [stopWorkAction, viewConditionsAction],
                intentIdentifiers: [],
                options: []
            )

            UNUserNotificationCenter.current().setNotificationCategories([category])

        case .extremeHeat, .technicianSafety:
            // Actions for safety measures
            let takePrecautionsAction = UNNotificationAction(
                identifier: "TAKE_PRECAUTIONS",
                title: "Take Precautions",
                options: []
            )
            let viewSafetyAction = UNNotificationAction(
                identifier: "VIEW_SAFETY",
                title: "View Safety Info",
                options: [.foreground]
            )

            let category = UNNotificationCategory(
                identifier: "WEATHER_ALERT",
                actions: [takePrecautionsAction, viewSafetyAction],
                intentIdentifiers: [],
                options: []
            )

            UNUserNotificationCenter.current().setNotificationCategories([category])

        case .extremeCold:
            // Actions for cold weather
            let adjustEquipmentAction = UNNotificationAction(
                identifier: "ADJUST_EQUIPMENT",
                title: "Adjust Equipment",
                options: []
            )

            let category = UNNotificationCategory(
                identifier: "WEATHER_ALERT",
                actions: [adjustEquipmentAction],
                intentIdentifiers: [],
                options: []
            )

            UNUserNotificationCenter.current().setNotificationCategories([category])
        }

        return content
    }

    // MARK: - Alert Management

    func markAlertAsRead(_ alertId: Int) async {
        if let index = activeWeatherAlerts.firstIndex(where: { $0.id == alertId }) {
            activeWeatherAlerts[index].isRead = true

            // Mark as read in Core Data
            await weatherDataManager.markAlertAsRead(UUID(uuidString: String(alertId)) ?? UUID())
        }
    }

    func dismissAlert(_ alertId: Int) {
        activeWeatherAlerts.removeAll { $0.id == alertId }

        // Remove from notification center
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["weather_alert_\(alertId)"])
    }

    func clearAllAlerts() {
        activeWeatherAlerts.removeAll()

        // Remove all weather notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:
            activeWeatherAlerts.map { "weather_alert_\($0.id)" }
        )
    }

    // MARK: - Location Updates

    func updateLocation(_ location: CLLocationCoordinate2D) {
        lastKnownLocation = location

        if isMonitoringWeather {
            Task {
                await checkWeatherConditions()
            }
        }
    }

    // MARK: - Manual Weather Check

    func performManualWeatherCheck() async {
        guard lastKnownLocation != nil else { return }
        await checkWeatherConditions()
    }

    // MARK: - Treatment Validation

    func validateTreatmentConditions(for treatmentType: ApplicationMethod, at location: CLLocationCoordinate2D) async -> TreatmentValidationResult {
        do {
            let weather = try await weatherAPI.fetchCurrentWeather(for: location)
            let safetyResult = weatherAPI.checkTreatmentSafety(for: weather)

            let canProceed = canPerformTreatment(treatmentType, with: safetyResult)

            return TreatmentValidationResult(
                canProceed: canProceed,
                weatherConditions: weather,
                safetyAnalysis: safetyResult,
                specificWarnings: getSpecificWarnings(for: treatmentType, with: safetyResult),
                recommendations: getSpecificRecommendations(for: treatmentType, with: safetyResult)
            )

        } catch {
            return TreatmentValidationResult(
                canProceed: false,
                weatherConditions: nil,
                safetyAnalysis: nil,
                specificWarnings: ["Unable to validate weather conditions: \(error.localizedDescription)"],
                recommendations: ["Retry weather check before proceeding with treatment"]
            )
        }
    }

    private func canPerformTreatment(_ treatmentType: ApplicationMethod, with safetyResult: TreatmentSafetyResult) -> Bool {
        switch treatmentType {
        case .spray, .aerosol:
            return safetyResult.canTreat && safetyResult.warnings.allSatisfy { warning in
                if case .highWind(let speed) = warning {
                    return speed <= 15
                }
                return true
            }
        case .granular, .dust:
            return safetyResult.canTreat && safetyResult.warnings.allSatisfy { warning in
                if case .highWind(let speed) = warning {
                    return speed <= 20
                }
                if case .precipitationRisk(let prob) = warning {
                    return prob < 30
                }
                return true
            }
        case .bait, .injection:
            // These methods are less weather-dependent
            return safetyResult.warnings.allSatisfy { warning in
                if case .precipitationRisk(let prob) = warning {
                    return prob < 70
                }
                return true
            }
        case .paint, .fogger:
            return safetyResult.canTreat
        }
    }

    private func getSpecificWarnings(for treatmentType: ApplicationMethod, with safetyResult: TreatmentSafetyResult) -> [String] {
        var warnings: [String] = []

        for warning in safetyResult.warnings {
            switch (treatmentType, warning) {
            case (.spray, .highWind(let speed)):
                warnings.append("Wind speed (\(Int(speed)) mph) may cause spray drift")
            case (.granular, .precipitationRisk(let prob)):
                warnings.append("Rain probability (\(prob)%) may reduce granular effectiveness")
            case (_, .highTemperature(let temp)):
                warnings.append("High temperature (\(Int(temp))°F) may affect chemical stability")
            case (_, .highUVIndex(let index)):
                warnings.append("High UV index (\(Int(index))) - ensure technician protection")
            default:
                break
            }
        }

        return warnings
    }

    private func getSpecificRecommendations(for treatmentType: ApplicationMethod, with safetyResult: TreatmentSafetyResult) -> [String] {
        var recommendations: [String] = []

        switch treatmentType {
        case .spray, .aerosol:
            recommendations.append("Use drift-reducing nozzles")
            recommendations.append("Reduce spray pressure if wind increases")
        case .granular:
            recommendations.append("Apply before rain to activate granules")
            recommendations.append("Water in immediately if no rain expected")
        case .bait:
            recommendations.append("Place baits in protected areas")
            recommendations.append("Check bait stations after weather events")
        default:
            break
        }

        recommendations.append(contentsOf: safetyResult.recommendedActions)
        return recommendations
    }
}

// MARK: - Supporting Types

struct WeatherNotificationItem: Identifiable {
    let id: Int
    let title: String
    let message: String
    let priority: AlertPriority
    let alertType: WeatherAlertType
    let timestamp: Date
    let location: CLLocationCoordinate2D
    var isRead: Bool

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct TreatmentValidationResult {
    let canProceed: Bool
    let weatherConditions: WeatherData?
    let safetyAnalysis: TreatmentSafetyResult?
    let specificWarnings: [String]
    let recommendations: [String]

    var validationSummary: String {
        if canProceed {
            return "Treatment conditions are acceptable"
        } else {
            return "Treatment conditions are not recommended"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let weatherAlertReceived = Notification.Name("weatherAlertReceived")
    static let weatherConditionsChanged = Notification.Name("weatherConditionsChanged")
    static let treatmentValidationCompleted = Notification.Name("treatmentValidationCompleted")
}

// MARK: - NotificationManager Extension

extension NotificationManager {
    func setupWeatherNotificationCategories() {
        let criticalWeatherCategory = createCriticalWeatherCategory()
        let safetyAlertCategory = createSafetyAlertCategory()

        UNUserNotificationCenter.current().setNotificationCategories([
            criticalWeatherCategory,
            safetyAlertCategory
        ])
    }

    private func createCriticalWeatherCategory() -> UNNotificationCategory {
        let stopWorkAction = UNNotificationAction(
            identifier: "STOP_WORK",
            title: "Stop Work",
            options: [.destructive, .foreground]
        )

        let viewConditionsAction = UNNotificationAction(
            identifier: "VIEW_CONDITIONS",
            title: "View Conditions",
            options: [.foreground]
        )

        let seekShelterAction = UNNotificationAction(
            identifier: "SEEK_SHELTER",
            title: "Seek Shelter",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "CRITICAL_WEATHER",
            actions: [stopWorkAction, seekShelterAction, viewConditionsAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createSafetyAlertCategory() -> UNNotificationCategory {
        let takePrecautionsAction = UNNotificationAction(
            identifier: "TAKE_PRECAUTIONS",
            title: "Take Precautions",
            options: []
        )

        let adjustEquipmentAction = UNNotificationAction(
            identifier: "ADJUST_EQUIPMENT",
            title: "Adjust Equipment",
            options: []
        )

        let continueWithCautionAction = UNNotificationAction(
            identifier: "CONTINUE_CAUTION",
            title: "Continue with Caution",
            options: []
        )

        return UNNotificationCategory(
            identifier: "SAFETY_ALERT",
            actions: [takePrecautionsAction, adjustEquipmentAction, continueWithCautionAction],
            intentIdentifiers: [],
            options: []
        )
    }

    func handleWeatherNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "STOP_WORK":
            await handleStopWorkAction(userInfo)
        case "VIEW_CONDITIONS":
            await handleViewConditionsAction(userInfo)
        case "SEEK_SHELTER":
            await handleSeekShelterAction(userInfo)
        case "TAKE_PRECAUTIONS":
            await handleTakePrecautionsAction(userInfo)
        case "ADJUST_EQUIPMENT":
            await handleAdjustEquipmentAction(userInfo)
        case "CONTINUE_CAUTION":
            await handleContinueWithCautionAction(userInfo)
        default:
            break
        }
    }

    private func handleStopWorkAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .stopWorkDueToWeather,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleViewConditionsAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .viewWeatherConditions,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleSeekShelterAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .seekShelterAlert,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleTakePrecautionsAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .takeSafetyPrecautions,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleAdjustEquipmentAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .adjustEquipmentForWeather,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleContinueWithCautionAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .continueWorkWithCaution,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let stopWorkDueToWeather = Notification.Name("stopWorkDueToWeather")
    static let viewWeatherConditions = Notification.Name("viewWeatherConditions")
    static let seekShelterAlert = Notification.Name("seekShelterAlert")
    static let takeSafetyPrecautions = Notification.Name("takeSafetyPrecautions")
    static let adjustEquipmentForWeather = Notification.Name("adjustEquipmentForWeather")
    static let continueWorkWithCaution = Notification.Name("continueWorkWithCaution")
}