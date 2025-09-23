import Foundation
import UserNotifications
import UIKit
import SwiftUI

// MARK: - PestGenie Notification Model

struct PestGenieNotification: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let timestamp: Date
    let priority: NotificationPriority
    let category: NotificationCategory
    let isRead: Bool

    init(title: String, message: String, timestamp: Date, priority: NotificationPriority, category: NotificationCategory, isRead: Bool) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.priority = priority
        self.category = category
        self.isRead = isRead
    }

    var icon: String {
        switch category {
        case .weather:
            return "cloud.fill"
        case .equipment:
            return "wrench.and.screwdriver"
        case .safety:
            return "shield.checkered"
        case .route:
            return "map"
        case .system:
            return "gear"
        case .emergency:
            return "exclamationmark.triangle.fill"
        }
    }
}

enum NotificationPriority: String, Codable {
    case low
    case normal
    case high
    case critical

    var color: Color {
        switch self {
        case .low:
            return PestGenieDesignSystem.Colors.textSecondary
        case .normal:
            return PestGenieDesignSystem.Colors.info
        case .high:
            return PestGenieDesignSystem.Colors.warning
        case .critical:
            return PestGenieDesignSystem.Colors.error
        }
    }
}

enum NotificationCategory: String, Codable, CaseIterable {
    case weather
    case equipment
    case safety
    case route
    case system
    case emergency
}

/// Manages push notifications, local notifications, and notification permissions
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var badgeCount: Int = 0
    @Published var unreadCount: Int = 0
    @Published var recentNotifications: [PestGenieNotification] = []

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        loadRecentNotifications()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Permission Management

    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [
                .alert,
                .badge,
                .sound,
                .provisional,
                .criticalAlert // For urgent pest control situations
            ])

            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Failed to request notification permissions: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Device Token Registration

    func registerForRemoteNotifications() {
        guard authorizationStatus == .authorized else {
            print("Notifications not authorized")
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceTokenRegistration(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device token: \(tokenString)")

        // Store token locally
        UserDefaults.standard.set(tokenString, forKey: "deviceToken")

        // Register with server
        Task {
            do {
                try await APIService.shared.registerDeviceToken(deviceToken)
                print("Device token registered with server")
            } catch {
                print("Failed to register device token: \(error)")
            }
        }
    }

    func handleDeviceTokenError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - Local Notifications

    func scheduleJobReminder(for job: Job, minutesBefore: Int = 30) async {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Service"
        content.body = "Job at \(job.customerName) starts in \(minutesBefore) minutes"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)

        // Add job-specific data for deep linking
        content.userInfo = [
            "type": "job_reminder",
            "jobId": job.id.uuidString,
            "customerId": job.customerName
        ]

        let triggerDate = job.scheduledDate.addingTimeInterval(-Double(minutesBefore * 60))
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "job_reminder_\(job.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled reminder for job: \(job.id)")
        } catch {
            print("Failed to schedule job reminder: \(error)")
        }
    }

    func scheduleRouteStartReminder(for route: Route, at time: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Start Your Route"
        content.body = "Your route '\(route.name)' is ready to begin"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)

        content.userInfo = [
            "type": "route_start",
            "routeId": route.id.uuidString
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "route_start_\(route.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled route start reminder: \(route.id)")
        } catch {
            print("Failed to schedule route reminder: \(error)")
        }
    }

    // MARK: - Equipment Notifications

    func scheduleEquipmentMaintenanceReminder(equipmentId: String, equipmentName: String, dueDate: Date, maintenanceType: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Maintenance Due"
        content.body = "\(maintenanceType) required for \(equipmentName)"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "EQUIPMENT_MAINTENANCE"

        content.userInfo = [
            "type": "equipment_maintenance",
            "equipmentId": equipmentId,
            "maintenanceType": maintenanceType
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "equipment_maintenance_\(equipmentId)_\(maintenanceType)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled maintenance reminder for equipment: \(equipmentId)")
        } catch {
            print("Failed to schedule equipment maintenance reminder: \(error)")
        }
    }

    func scheduleEquipmentCalibrationReminder(equipmentId: String, equipmentName: String, dueDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Calibration Due"
        content.body = "Calibration required for \(equipmentName)"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "EQUIPMENT_CALIBRATION"

        content.userInfo = [
            "type": "equipment_calibration",
            "equipmentId": equipmentId
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "equipment_calibration_\(equipmentId)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled calibration reminder for equipment: \(equipmentId)")
        } catch {
            print("Failed to schedule equipment calibration reminder: \(error)")
        }
    }

    func scheduleEquipmentInspectionReminder(equipmentId: String, equipmentName: String, dueDate: Date, inspectionType: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Inspection Due"
        content.body = "\(inspectionType) inspection required for \(equipmentName)"
        content.sound = .default
        content.badge = NSNumber(value: badgeCount + 1)
        content.categoryIdentifier = "EQUIPMENT_INSPECTION"

        content.userInfo = [
            "type": "equipment_inspection",
            "equipmentId": equipmentId,
            "inspectionType": inspectionType
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "equipment_inspection_\(equipmentId)_\(inspectionType)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled inspection reminder for equipment: \(equipmentId)")
        } catch {
            print("Failed to schedule equipment inspection reminder: \(error)")
        }
    }

    func cancelEquipmentNotifications(for equipmentId: String) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()

        let equipmentNotificationIds = pendingRequests
            .filter { $0.identifier.contains("equipment") && $0.identifier.contains(equipmentId) }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: equipmentNotificationIds)
        print("Cancelled \(equipmentNotificationIds.count) notifications for equipment: \(equipmentId)")
    }

    // MARK: - Enhanced Equipment Notifications

    /// Schedule equipment assignment notification
    func scheduleEquipmentAssignmentNotification(equipmentId: String, equipmentName: String, technicianName: String, jobId: String?) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Assigned"
        content.body = "\(equipmentName) has been assigned to \(technicianName)"
        if let jobId = jobId {
            content.body += " for job \(jobId)"
        }
        content.sound = .default
        content.categoryIdentifier = "EQUIPMENT_ASSIGNMENT"
        content.userInfo = [
            "type": "equipment_assignment",
            "equipmentId": equipmentId,
            "technicianName": technicianName,
            "jobId": jobId ?? ""
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "equipment_assignment_\(equipmentId)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment failure notification
    func scheduleEquipmentFailureNotification(equipmentId: String, equipmentName: String, severity: String, description: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Failure Reported"
        content.body = "\(severity) failure reported for \(equipmentName): \(description)"
        content.sound = severity == "Critical" ? .defaultCritical : .default
        content.categoryIdentifier = "EQUIPMENT_FAILURE"
        content.userInfo = [
            "type": "equipment_failure",
            "equipmentId": equipmentId,
            "severity": severity,
            "description": description
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "equipment_failure_\(equipmentId)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment return reminder
    func scheduleEquipmentReturnReminder(equipmentId: String, equipmentName: String, dueDate: Date, technicianName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Return Due"
        content.body = "\(equipmentName) should be returned by \(technicianName)"
        content.sound = .default
        content.categoryIdentifier = "EQUIPMENT_RETURN"
        content.userInfo = [
            "type": "equipment_return",
            "equipmentId": equipmentId,
            "technicianName": technicianName
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: "equipment_return_\(equipmentId)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment overdue notification
    func scheduleEquipmentOverdueNotification(equipmentId: String, equipmentName: String, daysPastDue: Int, technicianName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Overdue"
        content.body = "\(equipmentName) is \(daysPastDue) days overdue from \(technicianName)"
        content.sound = .defaultCritical
        content.categoryIdentifier = "EQUIPMENT_OVERDUE"
        content.userInfo = [
            "type": "equipment_overdue",
            "equipmentId": equipmentId,
            "daysPastDue": daysPastDue,
            "technicianName": technicianName
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "equipment_overdue_\(equipmentId)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment low usage notification
    func scheduleEquipmentLowUsageNotification(equipmentId: String, equipmentName: String, lastUsedDays: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Low Usage"
        content.body = "\(equipmentName) hasn't been used in \(lastUsedDays) days"
        content.sound = .default
        content.categoryIdentifier = "EQUIPMENT_USAGE"
        content.userInfo = [
            "type": "equipment_low_usage",
            "equipmentId": equipmentId,
            "lastUsedDays": lastUsedDays
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "equipment_low_usage_\(equipmentId)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule bulk equipment notification for multiple items
    func scheduleBulkEquipmentNotification(title: String, message: String, equipmentIds: [String], notificationType: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "EQUIPMENT_BULK"
        content.userInfo = [
            "type": notificationType,
            "equipmentIds": equipmentIds,
            "count": equipmentIds.count
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "equipment_bulk_\(notificationType)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment maintenance completed notification
    func scheduleMaintenanceCompletedNotification(equipmentId: String, equipmentName: String, maintenanceType: String, performedBy: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Maintenance Completed"
        content.body = "\(maintenanceType) completed for \(equipmentName) by \(performedBy)"
        content.sound = .default
        content.categoryIdentifier = "MAINTENANCE_COMPLETED"
        content.userInfo = [
            "type": "maintenance_completed",
            "equipmentId": equipmentId,
            "maintenanceType": maintenanceType,
            "performedBy": performedBy
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "maintenance_completed_\(equipmentId)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment inspection completed notification
    func scheduleInspectionCompletedNotification(equipmentId: String, equipmentName: String, inspectionResult: String, score: Double) async {
        let content = UNMutableNotificationContent()
        content.title = "Inspection Completed"
        content.body = "\(equipmentName) inspection \(inspectionResult) with score \(Int(score))%"
        content.sound = .default
        content.categoryIdentifier = "INSPECTION_COMPLETED"
        content.userInfo = [
            "type": "inspection_completed",
            "equipmentId": equipmentId,
            "result": inspectionResult,
            "score": score
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "inspection_completed_\(equipmentId)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule equipment calibration completed notification
    func scheduleCalibrationCompletedNotification(equipmentId: String, equipmentName: String, calibrationType: String, result: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Calibration Completed"
        content.body = "\(calibrationType) calibration for \(equipmentName): \(result)"
        content.sound = .default
        content.categoryIdentifier = "CALIBRATION_COMPLETED"
        content.userInfo = [
            "type": "calibration_completed",
            "equipmentId": equipmentId,
            "calibrationType": calibrationType,
            "result": result
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "calibration_completed_\(equipmentId)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) {
        badgeCount = count
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(count) { error in
                    if let error = error {
                        print("Failed to set badge count: \(error)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }

    // MARK: - Notification Categories and Actions

    func setupNotificationCategories() {
        let jobReminderCategory = createJobReminderCategory()
        let routeUpdateCategory = createRouteUpdateCategory()
        let emergencyCategory = createEmergencyCategory()
        let equipmentMaintenanceCategory = createEquipmentMaintenanceCategory()
        let equipmentCalibrationCategory = createEquipmentCalibrationCategory()
        let equipmentInspectionCategory = createEquipmentInspectionCategory()
        let equipmentAssignmentCategory = createEquipmentAssignmentCategory()
        let equipmentFailureCategory = createEquipmentFailureCategory()
        let equipmentReturnCategory = createEquipmentReturnCategory()
        let equipmentOverdueCategory = createEquipmentOverdueCategory()
        let equipmentUsageCategory = createEquipmentUsageCategory()
        let equipmentBulkCategory = createEquipmentBulkCategory()
        let maintenanceCompletedCategory = createMaintenanceCompletedCategory()
        let inspectionCompletedCategory = createInspectionCompletedCategory()
        let calibrationCompletedCategory = createCalibrationCompletedCategory()

        UNUserNotificationCenter.current().setNotificationCategories([
            jobReminderCategory,
            routeUpdateCategory,
            emergencyCategory,
            equipmentMaintenanceCategory,
            equipmentCalibrationCategory,
            equipmentInspectionCategory,
            equipmentAssignmentCategory,
            equipmentFailureCategory,
            equipmentReturnCategory,
            equipmentOverdueCategory,
            equipmentUsageCategory,
            equipmentBulkCategory,
            maintenanceCompletedCategory,
            inspectionCompletedCategory,
            calibrationCompletedCategory
        ])
    }

    private func createJobReminderCategory() -> UNNotificationCategory {
        let startAction = UNNotificationAction(
            identifier: "START_JOB",
            title: "Start Job",
            options: [.foreground]
        )

        let skipAction = UNNotificationAction(
            identifier: "SKIP_JOB",
            title: "Skip",
            options: [.destructive]
        )

        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_JOB",
            title: "Postpone 15min",
            options: []
        )

        return UNNotificationCategory(
            identifier: "JOB_REMINDER",
            actions: [startAction, postponeAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createRouteUpdateCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ROUTE",
            title: "View Route",
            options: [.foreground]
        )

        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_UPDATE",
            title: "Accept",
            options: []
        )

        return UNNotificationCategory(
            identifier: "ROUTE_UPDATE",
            actions: [viewAction, acceptAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createEmergencyCategory() -> UNNotificationCategory {
        let respondAction = UNNotificationAction(
            identifier: "EMERGENCY_RESPOND",
            title: "Respond",
            options: [.foreground]
        )

        let callAction = UNNotificationAction(
            identifier: "EMERGENCY_CALL",
            title: "Call Customer",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "EMERGENCY",
            actions: [respondAction, callAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createEquipmentMaintenanceCategory() -> UNNotificationCategory {
        let performAction = UNNotificationAction(
            identifier: "PERFORM_MAINTENANCE",
            title: "Perform Now",
            options: [.foreground]
        )

        let scheduleAction = UNNotificationAction(
            identifier: "SCHEDULE_MAINTENANCE",
            title: "Schedule",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_MAINTENANCE",
            title: "Remind Tomorrow",
            options: []
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_MAINTENANCE",
            actions: [performAction, scheduleAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createEquipmentCalibrationCategory() -> UNNotificationCategory {
        let calibrateAction = UNNotificationAction(
            identifier: "CALIBRATE_EQUIPMENT",
            title: "Calibrate Now",
            options: [.foreground]
        )

        let scheduleAction = UNNotificationAction(
            identifier: "SCHEDULE_CALIBRATION",
            title: "Schedule",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_CALIBRATION",
            title: "Remind Later",
            options: []
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_CALIBRATION",
            actions: [calibrateAction, scheduleAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createEquipmentInspectionCategory() -> UNNotificationCategory {
        let inspectAction = UNNotificationAction(
            identifier: "INSPECT_EQUIPMENT",
            title: "Inspect Now",
            options: [.foreground]
        )

        let scheduleAction = UNNotificationAction(
            identifier: "SCHEDULE_INSPECTION",
            title: "Schedule",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_INSPECTION",
            title: "Remind Later",
            options: []
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_INSPECTION",
            actions: [inspectAction, scheduleAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
    }

    // MARK: - Push Notification Handling

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> UNNotificationPresentationOptions {
        print("Received remote notification: \(userInfo)")

        guard let type = userInfo["type"] as? String else {
            return [.badge, .sound, .banner]
        }

        switch type {
        case "job_update":
            await handleJobUpdateNotification(userInfo)
        case "route_change":
            await handleRouteChangeNotification(userInfo)
        case "emergency":
            await handleEmergencyNotification(userInfo)
        case "message":
            await handleMessageNotification(userInfo)
        default:
            print("Unknown notification type: \(type)")
        }

        return [.badge, .sound, .banner]
    }

    private func handleJobUpdateNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let jobId = userInfo["jobId"] as? String else { return }

        // Trigger sync to get updated job data
        await SyncManager.shared.syncNow()

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .jobUpdated,
            object: nil,
            userInfo: ["jobId": jobId]
        )
    }

    private func handleRouteChangeNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let routeId = userInfo["routeId"] as? String else { return }

        // Sync route changes
        await SyncManager.shared.syncNow()

        NotificationCenter.default.post(
            name: .routeUpdated,
            object: nil,
            userInfo: ["routeId": routeId]
        )
    }

    private func handleEmergencyNotification(_ userInfo: [AnyHashable: Any]) async {
        // Handle emergency notifications with high priority
        updateBadgeCount(badgeCount + 1)

        NotificationCenter.default.post(
            name: .emergencyReceived,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleMessageNotification(_ userInfo: [AnyHashable: Any]) async {
        // Handle general messages
        updateBadgeCount(badgeCount + 1)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            let options = await handleRemoteNotification(notification.request.content.userInfo)
            completionHandler(options)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await handleNotificationResponse(response)
            completionHandler()
        }
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "START_JOB":
            await handleStartJobAction(userInfo)
        case "SKIP_JOB":
            await handleSkipJobAction(userInfo)
        case "POSTPONE_JOB":
            await handlePostponeJobAction(userInfo)
        case "VIEW_ROUTE":
            await handleViewRouteAction(userInfo)
        case "EMERGENCY_RESPOND":
            await handleEmergencyResponseAction(userInfo)
        case "PERFORM_MAINTENANCE":
            await handlePerformMaintenanceAction(userInfo)
        case "SCHEDULE_MAINTENANCE":
            await handleScheduleMaintenanceAction(userInfo)
        case "SNOOZE_MAINTENANCE":
            await handleSnoozeMaintenanceAction(userInfo)
        case "CALIBRATE_EQUIPMENT":
            await handleCalibrateEquipmentAction(userInfo)
        case "SCHEDULE_CALIBRATION":
            await handleScheduleCalibrationAction(userInfo)
        case "SNOOZE_CALIBRATION":
            await handleSnoozeCalibrationAction(userInfo)
        case "INSPECT_EQUIPMENT":
            await handleInspectEquipmentAction(userInfo)
        case "SCHEDULE_INSPECTION":
            await handleScheduleInspectionAction(userInfo)
        case "SNOOZE_INSPECTION":
            await handleSnoozeInspectionAction(userInfo)
        case UNNotificationDefaultActionIdentifier:
            await handleDefaultAction(userInfo)
        default:
            break
        }
    }

    private func handleStartJobAction(_ userInfo: [AnyHashable: Any]) async {
        guard let jobId = userInfo["jobId"] as? String else { return }

        // Navigate to job and start it
        NotificationCenter.default.post(
            name: .navigateToJob,
            object: nil,
            userInfo: ["jobId": jobId, "action": "start"]
        )
    }

    private func handleSkipJobAction(_ userInfo: [AnyHashable: Any]) async {
        guard let jobId = userInfo["jobId"] as? String else { return }

        NotificationCenter.default.post(
            name: .skipJob,
            object: nil,
            userInfo: ["jobId": jobId]
        )
    }

    private func handlePostponeJobAction(_ userInfo: [AnyHashable: Any]) async {
        guard let jobId = userInfo["jobId"] as? String else { return }

        // Reschedule notification for 15 minutes later
        if let job = await getJob(withId: jobId) {
            await scheduleJobReminder(for: job, minutesBefore: 0)
        }
    }

    private func handleViewRouteAction(_ userInfo: [AnyHashable: Any]) async {
        guard let routeId = userInfo["routeId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToRoute,
            object: nil,
            userInfo: ["routeId": routeId]
        )
    }

    private func handleEmergencyResponseAction(_ userInfo: [AnyHashable: Any]) async {
        NotificationCenter.default.post(
            name: .handleEmergency,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleDefaultAction(_ userInfo: [AnyHashable: Any]) async {
        // Handle tapping notification without action buttons
        if let type = userInfo["type"] as? String {
            switch type {
            case "job_reminder":
                if let jobId = userInfo["jobId"] as? String {
                    NotificationCenter.default.post(
                        name: .navigateToJob,
                        object: nil,
                        userInfo: ["jobId": jobId]
                    )
                }
            case "route_start":
                if let routeId = userInfo["routeId"] as? String {
                    NotificationCenter.default.post(
                        name: .navigateToRoute,
                        object: nil,
                        userInfo: ["routeId": routeId]
                    )
                }
            default:
                break
            }
        }
    }

    // MARK: - Equipment Action Handlers

    private func handlePerformMaintenanceAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEquipmentDetail,
            object: nil,
            userInfo: ["equipmentId": equipmentId, "action": "maintain"]
        )
    }

    private func handleScheduleMaintenanceAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEquipmentDetail,
            object: nil,
            userInfo: ["equipmentId": equipmentId, "action": "schedule_maintenance"]
        )
    }

    private func handleSnoozeMaintenanceAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String,
              let maintenanceType = userInfo["maintenanceType"] as? String else { return }

        // Reschedule maintenance reminder for tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        await scheduleEquipmentMaintenanceReminder(
            equipmentId: equipmentId,
            equipmentName: "Equipment", // Would get actual name
            dueDate: tomorrow,
            maintenanceType: maintenanceType
        )
    }

    private func handleCalibrateEquipmentAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEquipmentDetail,
            object: nil,
            userInfo: ["equipmentId": equipmentId, "action": "calibrate"]
        )
    }

    private func handleScheduleCalibrationAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEquipmentDetail,
            object: nil,
            userInfo: ["equipmentId": equipmentId, "action": "schedule_calibration"]
        )
    }

    private func handleSnoozeCalibrationAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        // Reschedule calibration reminder for next week
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        await scheduleEquipmentCalibrationReminder(
            equipmentId: equipmentId,
            equipmentName: "Equipment", // Would get actual name
            dueDate: nextWeek
        )
    }

    private func handleInspectEquipmentAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEquipmentDetail,
            object: nil,
            userInfo: ["equipmentId": equipmentId, "action": "inspect"]
        )
    }

    private func handleScheduleInspectionAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String else { return }

        NotificationCenter.default.post(
            name: .navigateToEquipmentDetail,
            object: nil,
            userInfo: ["equipmentId": equipmentId, "action": "schedule_inspection"]
        )
    }

    private func handleSnoozeInspectionAction(_ userInfo: [AnyHashable: Any]) async {
        guard let equipmentId = userInfo["equipmentId"] as? String,
              let inspectionType = userInfo["inspectionType"] as? String else { return }

        // Reschedule inspection reminder for tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        await scheduleEquipmentInspectionReminder(
            equipmentId: equipmentId,
            equipmentName: "Equipment", // Would get actual name
            dueDate: tomorrow,
            inspectionType: inspectionType
        )
    }

    private func getJob(withId jobId: String) async -> Job? {
        // This would fetch from your data source
        // For now, return nil as placeholder
        return nil
    }

    // MARK: - Recent Notifications Management

    private func loadRecentNotifications() {
        // Load sample notifications for demo purposes
        recentNotifications = [
            PestGenieNotification(
                title: "Equipment Maintenance Due",
                message: "Sprayer Unit A requires scheduled maintenance",
                timestamp: Date().addingTimeInterval(-300), // 5 minutes ago
                priority: .high,
                category: .equipment,
                isRead: false
            ),
            PestGenieNotification(
                title: "Weather Advisory",
                message: "Rain expected 2-4 PM, plan indoor tasks",
                timestamp: Date().addingTimeInterval(-600), // 10 minutes ago
                priority: .normal,
                category: .weather,
                isRead: false
            ),
            PestGenieNotification(
                title: "Route Updated",
                message: "Your route for today has been modified",
                timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
                priority: .normal,
                category: .route,
                isRead: true
            )
        ]
        updateUnreadCount()
    }

    private func updateUnreadCount() {
        unreadCount = recentNotifications.filter { !$0.isRead }.count
    }

    func markNotificationAsRead(_ notificationId: UUID) {
        if let index = recentNotifications.firstIndex(where: { $0.id == notificationId }) {
            recentNotifications[index] = PestGenieNotification(
                title: recentNotifications[index].title,
                message: recentNotifications[index].message,
                timestamp: recentNotifications[index].timestamp,
                priority: recentNotifications[index].priority,
                category: recentNotifications[index].category,
                isRead: true
            )
            updateUnreadCount()
        }
    }

    func addNotification(_ notification: PestGenieNotification) {
        recentNotifications.insert(notification, at: 0)
        if recentNotifications.count > 50 {
            recentNotifications.removeLast()
        }
        updateUnreadCount()
    }

    func clearAllNotifications() {
        recentNotifications.removeAll()
        unreadCount = 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let jobUpdated = Notification.Name("jobUpdated")
    static let routeUpdated = Notification.Name("routeUpdated")
    static let emergencyReceived = Notification.Name("emergencyReceived")
    static let navigateToJob = Notification.Name("navigateToJob")
    static let navigateToRoute = Notification.Name("navigateToRoute")
    static let skipJob = Notification.Name("skipJob")
    static let handleEmergency = Notification.Name("handleEmergency")
    static let navigateToEquipmentDetail = Notification.Name("navigateToEquipmentDetail")
}

// MARK: - Equipment Notification Categories Extension

extension NotificationManager {
    // MARK: - New Equipment Notification Categories

    private func createEquipmentAssignmentCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ASSIGNMENT",
            title: "View Assignment",
            options: [.foreground]
        )

        let acknowledgeAction = UNNotificationAction(
            identifier: "ACKNOWLEDGE_ASSIGNMENT",
            title: "Acknowledge",
            options: []
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_ASSIGNMENT",
            actions: [viewAction, acknowledgeAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Equipment assignment notification",
            options: .customDismissAction
        )
    }

    private func createEquipmentFailureCategory() -> UNNotificationCategory {
        let reportAction = UNNotificationAction(
            identifier: "REPORT_FAILURE",
            title: "Create Report",
            options: [.foreground]
        )

        let scheduleRepairAction = UNNotificationAction(
            identifier: "SCHEDULE_REPAIR",
            title: "Schedule Repair",
            options: [.foreground]
        )

        let notifyManagerAction = UNNotificationAction(
            identifier: "NOTIFY_MANAGER",
            title: "Notify Manager",
            options: []
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_FAILURE",
            actions: [reportAction, scheduleRepairAction, notifyManagerAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Equipment failure notification",
            options: .customDismissAction
        )
    }

    private func createEquipmentReturnCategory() -> UNNotificationCategory {
        let returnAction = UNNotificationAction(
            identifier: "MARK_RETURNED",
            title: "Mark Returned",
            options: [.foreground]
        )

        let extendAction = UNNotificationAction(
            identifier: "EXTEND_ASSIGNMENT",
            title: "Extend Assignment",
            options: [.foreground]
        )

        let contactTechnicianAction = UNNotificationAction(
            identifier: "CONTACT_TECHNICIAN",
            title: "Contact Technician",
            options: []
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_RETURN",
            actions: [returnAction, extendAction, contactTechnicianAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Equipment return reminder",
            options: .customDismissAction
        )
    }

    private func createEquipmentOverdueCategory() -> UNNotificationCategory {
        let escalateAction = UNNotificationAction(
            identifier: "ESCALATE_OVERDUE",
            title: "Escalate",
            options: [.foreground]
        )

        let contactAction = UNNotificationAction(
            identifier: "CONTACT_OVERDUE",
            title: "Contact Now",
            options: []
        )

        let reportLostAction = UNNotificationAction(
            identifier: "REPORT_LOST",
            title: "Report Lost",
            options: [.foreground, .destructive]
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_OVERDUE",
            actions: [escalateAction, contactAction, reportLostAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Equipment overdue notification",
            options: .customDismissAction
        )
    }

    private func createEquipmentUsageCategory() -> UNNotificationCategory {
        let scheduleUsageAction = UNNotificationAction(
            identifier: "SCHEDULE_USAGE",
            title: "Schedule Usage",
            options: [.foreground]
        )

        let retireAction = UNNotificationAction(
            identifier: "CONSIDER_RETIREMENT",
            title: "Consider Retirement",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_USAGE",
            actions: [scheduleUsageAction, retireAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Equipment usage notification",
            options: .customDismissAction
        )
    }

    private func createEquipmentBulkCategory() -> UNNotificationCategory {
        let viewAllAction = UNNotificationAction(
            identifier: "VIEW_ALL_EQUIPMENT",
            title: "View All",
            options: [.foreground]
        )

        let prioritizeAction = UNNotificationAction(
            identifier: "PRIORITIZE_EQUIPMENT",
            title: "Prioritize",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "EQUIPMENT_BULK",
            actions: [viewAllAction, prioritizeAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Bulk equipment notification",
            options: .customDismissAction
        )
    }

    private func createMaintenanceCompletedCategory() -> UNNotificationCategory {
        let viewReportAction = UNNotificationAction(
            identifier: "VIEW_MAINTENANCE_REPORT",
            title: "View Report",
            options: [.foreground]
        )

        let scheduleNextAction = UNNotificationAction(
            identifier: "SCHEDULE_NEXT_MAINTENANCE",
            title: "Schedule Next",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "MAINTENANCE_COMPLETED",
            actions: [viewReportAction, scheduleNextAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Maintenance completed notification",
            options: .customDismissAction
        )
    }

    private func createInspectionCompletedCategory() -> UNNotificationCategory {
        let viewResultsAction = UNNotificationAction(
            identifier: "VIEW_INSPECTION_RESULTS",
            title: "View Results",
            options: [.foreground]
        )

        let scheduleFollowUpAction = UNNotificationAction(
            identifier: "SCHEDULE_FOLLOWUP",
            title: "Schedule Follow-up",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "INSPECTION_COMPLETED",
            actions: [viewResultsAction, scheduleFollowUpAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Inspection completed notification",
            options: .customDismissAction
        )
    }

    private func createCalibrationCompletedCategory() -> UNNotificationCategory {
        let viewCertificateAction = UNNotificationAction(
            identifier: "VIEW_CALIBRATION_CERTIFICATE",
            title: "View Certificate",
            options: [.foreground]
        )

        let scheduleNextCalibrationAction = UNNotificationAction(
            identifier: "SCHEDULE_NEXT_CALIBRATION",
            title: "Schedule Next",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "CALIBRATION_COMPLETED",
            actions: [viewCertificateAction, scheduleNextCalibrationAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Calibration completed notification",
            options: .customDismissAction
        )
    }
}

// MARK: - Supporting Types

extension Job {
    // Helper for notification scheduling
    var shouldScheduleReminder: Bool {
        return status == .pending && scheduledDate > Date()
    }
}

struct Route {
    let id: UUID
    let name: String
    let date: Date
    let jobs: [Job]
}