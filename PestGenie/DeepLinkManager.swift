import Foundation
import SwiftUI

/// Manages deep linking, URL schemes, and universal links for navigation
@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingDeepLink: DeepLink?
    @Published var currentTab: AppTab = .routes

    private let routeViewModel: RouteViewModel

    enum AppTab: String, CaseIterable {
        case routes = "routes"
        case jobs = "jobs"
        case settings = "settings"
        case profile = "profile"

        var title: String {
            switch self {
            case .routes: return "Routes"
            case .jobs: return "Jobs"
            case .settings: return "Settings"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .routes: return "map"
            case .jobs: return "list.bullet"
            case .settings: return "gear"
            case .profile: return "person"
            }
        }
    }

    init(routeViewModel: RouteViewModel = RouteViewModel.shared) {
        self.routeViewModel = routeViewModel
        setupNotificationObservers()
    }

    // MARK: - Deep Link Types

    enum DeepLink: Equatable {
        case job(id: String, action: JobAction?)
        case route(id: String)
        case customer(id: String)
        case settings(section: SettingsSection?)
        case emergency(type: EmergencyType)

        enum JobAction: String {
            case start = "start"
            case complete = "complete"
            case skip = "skip"
            case reschedule = "reschedule"
        }

        enum SettingsSection: String {
            case notifications = "notifications"
            case sync = "sync"
            case account = "account"
            case privacy = "privacy"
        }

        enum EmergencyType: String {
            case pestOutbreak = "pest_outbreak"
            case equipmentFailure = "equipment_failure"
            case customerComplaint = "customer_complaint"
        }
    }

    // MARK: - URL Scheme Handling

    func handle(url: URL) -> Bool {
        print("Handling deep link URL: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }

        // Handle different URL schemes
        switch components.scheme {
        case "pestgenie":
            return handleCustomScheme(components)
        case "https":
            return handleUniversalLink(components)
        default:
            return false
        }
    }

    private func handleCustomScheme(_ components: URLComponents) -> Bool {
        guard let host = components.host else { return false }

        switch host {
        case "job":
            return handleJobLink(components)
        case "route":
            return handleRouteLink(components)
        case "customer":
            return handleCustomerLink(components)
        case "settings":
            return handleSettingsLink(components)
        case "emergency":
            return handleEmergencyLink(components)
        default:
            return false
        }
    }

    private func handleUniversalLink(_ components: URLComponents) -> Bool {
        // Handle universal links like https://pestgenie.com/job/123
        guard components.host == "pestgenie.com" || components.host == "www.pestgenie.com" else {
            return false
        }

        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard !pathComponents.isEmpty else { return false }

        switch pathComponents[0] {
        case "job":
            return handleJobUniversalLink(pathComponents, queryItems: components.queryItems)
        case "route":
            return handleRouteUniversalLink(pathComponents, queryItems: components.queryItems)
        case "share":
            return handleShareLink(pathComponents, queryItems: components.queryItems)
        default:
            return false
        }
    }

    // MARK: - Specific Link Handlers

    private func handleJobLink(_ components: URLComponents) -> Bool {
        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let jobId = pathComponents.first else { return false }

        let action = components.queryItems?.first(where: { $0.name == "action" })?.value
        let jobAction = action.flatMap { DeepLink.JobAction(rawValue: $0) }

        let deepLink = DeepLink.job(id: jobId, action: jobAction)
        navigate(to: deepLink)
        return true
    }

    private func handleRouteLink(_ components: URLComponents) -> Bool {
        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let routeId = pathComponents.first else { return false }

        let deepLink = DeepLink.route(id: routeId)
        navigate(to: deepLink)
        return true
    }

    private func handleCustomerLink(_ components: URLComponents) -> Bool {
        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let customerId = pathComponents.first else { return false }

        let deepLink = DeepLink.customer(id: customerId)
        navigate(to: deepLink)
        return true
    }

    private func handleSettingsLink(_ components: URLComponents) -> Bool {
        let section = components.queryItems?.first(where: { $0.name == "section" })?.value
        let settingsSection = section.flatMap { DeepLink.SettingsSection(rawValue: $0) }

        let deepLink = DeepLink.settings(section: settingsSection)
        navigate(to: deepLink)
        return true
    }

    private func handleEmergencyLink(_ components: URLComponents) -> Bool {
        let typeString = components.queryItems?.first(where: { $0.name == "type" })?.value ?? "pest_outbreak"
        guard let emergencyType = DeepLink.EmergencyType(rawValue: typeString) else { return false }

        let deepLink = DeepLink.emergency(type: emergencyType)
        navigate(to: deepLink)
        return true
    }

    private func handleJobUniversalLink(_ pathComponents: [String], queryItems: [URLQueryItem]?) -> Bool {
        guard pathComponents.count >= 2 else { return false }
        let jobId = pathComponents[1]

        let action = queryItems?.first(where: { $0.name == "action" })?.value
        let jobAction = action.flatMap { DeepLink.JobAction(rawValue: $0) }

        let deepLink = DeepLink.job(id: jobId, action: jobAction)
        navigate(to: deepLink)
        return true
    }

    private func handleRouteUniversalLink(_ pathComponents: [String], queryItems: [URLQueryItem]?) -> Bool {
        guard pathComponents.count >= 2 else { return false }
        let routeId = pathComponents[1]

        let deepLink = DeepLink.route(id: routeId)
        navigate(to: deepLink)
        return true
    }

    private func handleShareLink(_ pathComponents: [String], queryItems: [URLQueryItem]?) -> Bool {
        // Handle shared links from other users
        guard pathComponents.count >= 2 else { return false }

        switch pathComponents[1] {
        case "job":
            guard pathComponents.count >= 3 else { return false }
            let deepLink = DeepLink.job(id: pathComponents[2], action: nil)
            navigate(to: deepLink)
            return true
        case "route":
            guard pathComponents.count >= 3 else { return false }
            let deepLink = DeepLink.route(id: pathComponents[2])
            navigate(to: deepLink)
            return true
        default:
            return false
        }
    }

    // MARK: - Navigation

    private func navigate(to deepLink: DeepLink) {
        pendingDeepLink = deepLink
        executeNavigation(deepLink)
    }

    private func executeNavigation(_ deepLink: DeepLink) {
        switch deepLink {
        case .job(let id, let action):
            navigateToJob(id: id, action: action)
        case .route(let id):
            navigateToRoute(id: id)
        case .customer(let id):
            navigateToCustomer(id: id)
        case .settings(let section):
            navigateToSettings(section: section)
        case .emergency(let type):
            handleEmergency(type: type)
        }
    }

    private func navigateToJob(id: String, action: DeepLink.JobAction?) {
        currentTab = .jobs

        // Find the job
        guard let job = routeViewModel.jobs.first(where: { $0.id.uuidString == id }) else {
            print("Job not found: \(id)")
            return
        }

        // Execute action if specified
        if let action = action {
            switch action {
            case .start:
                routeViewModel.startJob(job)
            case .complete:
                routeViewModel.completeJob(job, reasonCode: nil)
            case .skip:
                routeViewModel.skipJob(job, reasonCode: ReasonCode.customerNotHome)
            case .reschedule:
                // Open reschedule dialog
                break
            }
        }

        // Post navigation notification
        NotificationCenter.default.post(
            name: .navigateToJobDetail,
            object: nil,
            userInfo: ["jobId": id]
        )
    }

    private func navigateToRoute(id: String) {
        currentTab = .routes

        NotificationCenter.default.post(
            name: .navigateToRouteDetail,
            object: nil,
            userInfo: ["routeId": id]
        )
    }

    private func navigateToCustomer(id: String) {
        currentTab = .jobs

        NotificationCenter.default.post(
            name: .navigateToCustomerDetail,
            object: nil,
            userInfo: ["customerId": id]
        )
    }

    private func navigateToSettings(section: DeepLink.SettingsSection?) {
        currentTab = .settings

        if let section = section {
            NotificationCenter.default.post(
                name: .navigateToSettingsSection,
                object: nil,
                userInfo: ["section": section.rawValue]
            )
        }
    }

    private func handleEmergency(type: DeepLink.EmergencyType) {
        NotificationCenter.default.post(
            name: .handleEmergencyAlert,
            object: nil,
            userInfo: ["type": type.rawValue]
        )
    }

    // MARK: - URL Generation

    func generateJobURL(for job: Job, action: DeepLink.JobAction? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "pestgenie"
        components.host = "job"
        components.path = "/\(job.id.uuidString)"

        if let action = action {
            components.queryItems = [URLQueryItem(name: "action", value: action.rawValue)]
        }

        return components.url!
    }

    func generateUniversalJobURL(for job: Job, action: DeepLink.JobAction? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "pestgenie.com"
        components.path = "/job/\(job.id.uuidString)"

        if let action = action {
            components.queryItems = [URLQueryItem(name: "action", value: action.rawValue)]
        }

        return components.url!
    }

    func generateRouteURL(for route: Route) -> URL {
        var components = URLComponents()
        components.scheme = "pestgenie"
        components.host = "route"
        components.path = "/\(route.id.uuidString)"

        return components.url!
    }

    func generateShareURL(for job: Job) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "pestgenie.com"
        components.path = "/share/job/\(job.id.uuidString)"

        return components.url!
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .navigateToJob,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let jobId = notification.userInfo?["jobId"] as? String else { return }
            let action = (notification.userInfo?["action"] as? String).flatMap { DeepLink.JobAction(rawValue: $0) }
            self?.navigateToJob(id: jobId, action: action)
        }

        NotificationCenter.default.addObserver(
            forName: .navigateToRoute,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let routeId = notification.userInfo?["routeId"] as? String else { return }
            self?.navigateToRoute(id: routeId)
        }
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let navigateToJobDetail = Notification.Name("navigateToJobDetail")
    static let navigateToRouteDetail = Notification.Name("navigateToRouteDetail")
    static let navigateToCustomerDetail = Notification.Name("navigateToCustomerDetail")
    static let navigateToSettingsSection = Notification.Name("navigateToSettingsSection")
    static let handleEmergencyAlert = Notification.Name("handleEmergencyAlert")
}

// MARK: - SwiftUI Integration

struct DeepLinkHandler: ViewModifier {
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                _ = deepLinkManager.handle(url: url)
            }
            .onChange(of: deepLinkManager.pendingDeepLink) { deepLink in
                if let deepLink = deepLink {
                    // Handle deep link in UI
                    handleDeepLinkInUI(deepLink)
                    deepLinkManager.pendingDeepLink = nil
                }
            }
    }

    private func handleDeepLinkInUI(_ deepLink: DeepLinkManager.DeepLink) {
        // This will be implemented in your main app view
        print("Handling deep link in UI: \(deepLink)")
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}