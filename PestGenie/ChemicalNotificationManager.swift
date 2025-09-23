import Foundation
import UserNotifications

/// Extension to NotificationManager for handling chemical-specific notifications
extension NotificationManager {

    // MARK: - Chemical Management Notifications

    /// Schedules chemical expiration reminder notifications
    func scheduleChemicalExpirationReminder(for chemical: Chemical, daysBeforeExpiration: Int = 30) async {
        let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBeforeExpiration, to: chemical.expirationDate)

        guard let reminderDate = reminderDate,
              reminderDate > Date() else {
            // Chemical is already expired or reminder date is in the past
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Chemical Expiration Alert"

        if daysBeforeExpiration == 0 {
            content.body = "⚠️ \(chemical.name) expires today! Replace before use."
        } else {
            content.body = "⚠️ \(chemical.name) expires in \(daysBeforeExpiration) days"
        }

        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "CHEMICAL_EXPIRATION"

        content.userInfo = [
            "type": "chemical_expiration",
            "chemicalId": chemical.id.uuidString,
            "daysUntilExpiration": daysBeforeExpiration,
            "signalWord": chemical.signalWord.rawValue,
            "hazardLevel": chemical.hazardCategory.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "chemical_expiration_\(chemical.id.uuidString)_\(daysBeforeExpiration)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled chemical expiration reminder for \(chemical.name): \(daysBeforeExpiration) days before")
        } catch {
            print("Failed to schedule chemical expiration reminder: \(error)")
        }
    }

    /// Schedules low stock alert for chemicals
    func scheduleChemicalLowStockAlert(for chemical: Chemical, threshold: Double? = nil) async {
        let stockThreshold = threshold ?? 10.0 // Default 10 units

        guard chemical.quantityInStock <= stockThreshold else {
            return // Stock is not low
        }

        let content = UNMutableNotificationContent()
        content.title = "Low Chemical Stock Alert"
        content.body = "📦 \(chemical.name) is running low (\(chemical.quantityFormatted) remaining)"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "CHEMICAL_LOW_STOCK"

        content.userInfo = [
            "type": "chemical_low_stock",
            "chemicalId": chemical.id.uuidString,
            "currentStock": chemical.quantityInStock,
            "threshold": stockThreshold,
            "epaNumber": chemical.epaRegistrationNumber
        ]

        // Schedule immediately for low stock alerts
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "chemical_low_stock_\(chemical.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled low stock alert for \(chemical.name)")
        } catch {
            print("Failed to schedule low stock alert: \(error)")
        }
    }

    /// Schedules safety compliance reminder for chemical treatments
    func scheduleChemicalSafetyReminder(for treatment: ChemicalTreatment, weatherConditions: WeatherConditions) async {
        guard weatherConditions.safetyAnalysis.overallSafety == .unsafe ||
              weatherConditions.safetyAnalysis.overallSafety == .caution else {
            return // Weather is safe for treatment
        }

        let content = UNMutableNotificationContent()
        content.title = "Chemical Treatment Safety Alert"

        if weatherConditions.safetyAnalysis.overallSafety == .unsafe {
            content.body = "🚫 UNSAFE: Do not apply chemicals. Weather conditions are dangerous."
        } else {
            content.body = "⚠️ CAUTION: Weather conditions require extra safety measures for chemical application."
        }

        content.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName("safety_alert.caf"))
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "CHEMICAL_SAFETY"

        content.userInfo = [
            "type": "chemical_safety",
            "treatmentId": treatment.id.uuidString,
            "chemicalId": treatment.chemicalId.uuidString,
            "safetyLevel": weatherConditions.safetyAnalysis.overallSafety.rawValue,
            "warnings": weatherConditions.safetyAnalysis.warnings.map { $0.title }
        ]

        // Schedule immediately for safety alerts
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "chemical_safety_\(treatment.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled chemical safety alert for treatment: \(treatment.id)")
        } catch {
            print("Failed to schedule chemical safety alert: \(error)")
        }
    }

    /// Schedules EPA compliance reminder for chemical applications
    func scheduleEPAComplianceReminder(for chemical: Chemical, violations: [String]) async {
        guard !violations.isEmpty else {
            return // No violations to report
        }

        let content = UNMutableNotificationContent()
        content.title = "EPA Compliance Alert"
        content.body = "📋 EPA compliance issues found for \(chemical.name): \(violations.first ?? "Review required")"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "EPA_COMPLIANCE"

        content.userInfo = [
            "type": "epa_compliance",
            "chemicalId": chemical.id.uuidString,
            "violations": violations,
            "epaNumber": chemical.epaRegistrationNumber
        ]

        // Schedule immediately for compliance alerts
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "epa_compliance_\(chemical.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled EPA compliance alert for \(chemical.name)")
        } catch {
            print("Failed to schedule EPA compliance alert: \(error)")
        }
    }

    /// Bulk schedule expiration reminders for all chemicals
    func scheduleAllChemicalExpirationReminders(for chemicals: [Chemical]) async {
        for chemical in chemicals {
            // Schedule reminders at 30, 14, 7, 3, and 1 days before expiration
            let reminderDays = [30, 14, 7, 3, 1, 0]

            for days in reminderDays {
                await scheduleChemicalExpirationReminder(for: chemical, daysBeforeExpiration: days)
            }
        }
    }

    /// Cancel chemical-related notifications
    func cancelChemicalNotifications(for chemicalId: UUID) {
        let identifiersToCancel = [
            "chemical_expiration_\(chemicalId.uuidString)_30",
            "chemical_expiration_\(chemicalId.uuidString)_14",
            "chemical_expiration_\(chemicalId.uuidString)_7",
            "chemical_expiration_\(chemicalId.uuidString)_3",
            "chemical_expiration_\(chemicalId.uuidString)_1",
            "chemical_expiration_\(chemicalId.uuidString)_0",
            "chemical_low_stock_\(chemicalId.uuidString)",
            "epa_compliance_\(chemicalId.uuidString)"
        ]

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        print("Cancelled chemical notifications for: \(chemicalId)")
    }

    /// Daily check for expired chemicals and schedule alerts
    func performDailyChemicalCheck(chemicals: [Chemical]) async {
        for chemical in chemicals {
            // Check for expiration
            if chemical.isExpired {
                await scheduleChemicalExpirationReminder(for: chemical, daysBeforeExpiration: 0)
            } else if chemical.isNearExpiration {
                let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: chemical.expirationDate).day ?? 0
                await scheduleChemicalExpirationReminder(for: chemical, daysBeforeExpiration: daysUntilExpiration)
            }

            // Check for low stock
            if chemical.isLowStock {
                await scheduleChemicalLowStockAlert(for: chemical)
            }
        }
    }

    /// Create notification categories for chemical management
    func setupChemicalNotificationCategories() {
        let chemicalExpirationCategory = createChemicalExpirationCategory()
        let chemicalLowStockCategory = createChemicalLowStockCategory()
        let chemicalSafetyCategory = createChemicalSafetyCategory()
        let epaComplianceCategory = createEPAComplianceCategory()

        // Add to existing categories
        let existingCategories = UNUserNotificationCenter.current()

        // This would ideally be integrated into the main setupNotificationCategories method
        print("Chemical notification categories created")
    }

    private func createChemicalExpirationCategory() -> UNNotificationCategory {
        let replaceAction = UNNotificationAction(
            identifier: "REPLACE_CHEMICAL",
            title: "Order Replacement",
            options: [.foreground]
        )

        let inspectAction = UNNotificationAction(
            identifier: "INSPECT_CHEMICAL",
            title: "Inspect",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_CHEMICAL_EXPIRATION",
            title: "Remind Tomorrow",
            options: []
        )

        return UNNotificationCategory(
            identifier: "CHEMICAL_EXPIRATION",
            actions: [replaceAction, inspectAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createChemicalLowStockCategory() -> UNNotificationCategory {
        let orderAction = UNNotificationAction(
            identifier: "ORDER_CHEMICAL",
            title: "Order Now",
            options: [.foreground]
        )

        let checkInventoryAction = UNNotificationAction(
            identifier: "CHECK_CHEMICAL_INVENTORY",
            title: "Check Inventory",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "CHEMICAL_LOW_STOCK",
            actions: [orderAction, checkInventoryAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createChemicalSafetyCategory() -> UNNotificationCategory {
        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_TREATMENT",
            title: "Postpone",
            options: [.destructive]
        )

        let checkWeatherAction = UNNotificationAction(
            identifier: "CHECK_WEATHER",
            title: "Check Weather",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "CHEMICAL_SAFETY",
            actions: [postponeAction, checkWeatherAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createEPAComplianceCategory() -> UNNotificationCategory {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_COMPLIANCE",
            title: "Review",
            options: [.foreground]
        )

        let contactEPAAction = UNNotificationAction(
            identifier: "CONTACT_EPA",
            title: "Contact EPA",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "EPA_COMPLIANCE",
            actions: [reviewAction, contactEPAAction],
            intentIdentifiers: [],
            options: []
        )
    }
}

// MARK: - Chemical Notification Action Handlers

extension NotificationManager {

    /// Handle chemical-specific notification actions
    func handleChemicalNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "REPLACE_CHEMICAL":
            await handleReplaceChemicalAction(userInfo)
        case "INSPECT_CHEMICAL":
            await handleInspectChemicalAction(userInfo)
        case "SNOOZE_CHEMICAL_EXPIRATION":
            await handleSnoozeChemicalExpirationAction(userInfo)
        case "ORDER_CHEMICAL":
            await handleOrderChemicalAction(userInfo)
        case "CHECK_CHEMICAL_INVENTORY":
            await handleCheckChemicalInventoryAction(userInfo)
        case "POSTPONE_TREATMENT":
            await handlePostponeTreatmentAction(userInfo)
        case "CHECK_WEATHER":
            await handleCheckWeatherAction(userInfo)
        case "REVIEW_COMPLIANCE":
            await handleReviewComplianceAction(userInfo)
        case "CONTACT_EPA":
            await handleContactEPAAction(userInfo)
        default:
            break
        }
    }

    private func handleReplaceChemicalAction(_ userInfo: [AnyHashable: Any]) async {
        guard let chemicalId = userInfo["chemicalId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToChemicalDetail,
            object: nil,
            userInfo: ["chemicalId": chemicalId, "action": "replace"]
        )
    }

    private func handleInspectChemicalAction(_ userInfo: [AnyHashable: Any]) async {
        guard let chemicalId = userInfo["chemicalId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToChemicalDetail,
            object: nil,
            userInfo: ["chemicalId": chemicalId, "action": "inspect"]
        )
    }

    private func handleSnoozeChemicalExpirationAction(_ userInfo: [AnyHashable: Any]) async {
        guard let chemicalId = userInfo["chemicalId"] as? String,
              let daysUntilExpiration = userInfo["daysUntilExpiration"] as? Int else { return }

        // Reschedule for tomorrow if not yet expired
        if daysUntilExpiration > 0 {
            // Would fetch chemical and reschedule
            print("Snoozing chemical expiration alert for \(chemicalId)")
        }
    }

    private func handleOrderChemicalAction(_ userInfo: [AnyHashable: Any]) async {
        guard let chemicalId = userInfo["chemicalId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToChemicalOrder,
            object: nil,
            userInfo: ["chemicalId": chemicalId]
        )
    }

    private func handleCheckChemicalInventoryAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .navigateToChemicalInventory,
            object: nil,
            userInfo: [:]
        )
    }

    private func handlePostponeTreatmentAction(_ userInfo: [AnyHashable: Any]) async {
        guard let treatmentId = userInfo["treatmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .postponeTreatment,
            object: nil,
            userInfo: ["treatmentId": treatmentId]
        )
    }

    private func handleCheckWeatherAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .navigateToWeatherDashboard,
            object: nil,
            userInfo: [:]
        )
    }

    private func handleReviewComplianceAction(_ userInfo: [AnyHashable: Any]) async {
        guard let chemicalId = userInfo["chemicalId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEPACompliance,
            object: nil,
            userInfo: ["chemicalId": chemicalId]
        )
    }

    private func handleContactEPAAction(_ userInfo: [AnyHashable: Any]) async {
        // Open EPA contact information or website
        NotificationCenter.default.post(
            name: .contactEPA,
            object: nil,
            userInfo: [:]
        )
    }
}

// MARK: - Additional Notification Names for Chemical Management

extension Notification.Name {
    static let navigateToChemicalDetail = Notification.Name("navigateToChemicalDetail")
    static let navigateToChemicalOrder = Notification.Name("navigateToChemicalOrder")
    static let navigateToChemicalInventory = Notification.Name("navigateToChemicalInventory")
    static let navigateToWeatherDashboard = Notification.Name("navigateToWeatherDashboard")
    static let navigateToEPACompliance = Notification.Name("navigateToEPACompliance")
    static let postponeTreatment = Notification.Name("postponeTreatment")
    static let contactEPA = Notification.Name("contactEPA")
}