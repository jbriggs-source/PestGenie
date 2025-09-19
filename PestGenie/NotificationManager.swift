import Foundation
import UserNotifications
import UIKit

/// Manages push notifications, local notifications, and notification permissions
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var badgeCount: Int = 0

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
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

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) {
        badgeCount = count
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
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

        UNUserNotificationCenter.current().setNotificationCategories([
            jobReminderCategory,
            routeUpdateCategory,
            emergencyCategory
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
            options: [.criticalAlert]
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
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task {
            let options = await handleRemoteNotification(notification.request.content.userInfo)
            completionHandler(options)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
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
            let newTime = Date().addingTimeInterval(15 * 60)
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

    private func getJob(withId jobId: String) async -> Job? {
        // This would fetch from your data source
        // For now, return nil as placeholder
        return nil
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