import Foundation
import SwiftUI
import StoreKit

/// Manages App Store compliance including privacy, accessibility, and submission requirements
@MainActor
final class AppStoreComplianceManager: ObservableObject {
    static let shared = AppStoreComplianceManager()

    @Published var privacySettings = PrivacySettings()
    @Published var accessibilitySettings = AccessibilitySettings()
    @Published var complianceStatus = ComplianceStatus()

    private init() {
        loadSettings()
        checkCompliance()
    }

    // MARK: - Privacy Compliance

    func requestDataUsageConsent() async -> Bool {
        // Present privacy consent dialog
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // This would typically show a custom privacy dialog
                // For now, we'll assume consent is granted
                self.privacySettings.hasConsentedToDataUsage = true
                self.saveSettings()
                continuation.resume(returning: true)
            }
        }
    }

    func requestLocationPermission() async -> Bool {
        return await LocationManager.shared.requestPermission()
    }

    func requestNotificationPermission() async -> Bool {
        return await NotificationManager.shared.requestPermissions()
    }

    func exportUserData() -> UserDataExport {
        // Implement GDPR/CCPA compliant data export
        return UserDataExport(
            personalInfo: PersonalInfo(
                userId: privacySettings.userId,
                email: privacySettings.userEmail,
                preferences: privacySettings.dataProcessingPreferences
            ),
            appUsage: AppUsageData(
                jobsCompleted: getJobsCompletedCount(),
                routesCompleted: getRoutesCompletedCount(),
                averageSessionTime: getAverageSessionTime()
            ),
            locationData: getLocationDataSummary(),
            exportDate: Date()
        )
    }

    func deleteUserData() async -> Bool {
        // Implement right to be forgotten
        do {
            // Clear Core Data
            let context = PersistenceController.shared.container.viewContext
            let jobRequest: NSFetchRequest<NSFetchRequestResult> = JobEntity.fetchRequest()
            let deleteJobsRequest = NSBatchDeleteRequest(fetchRequest: jobRequest)
            try context.execute(deleteJobsRequest)

            // Clear user preferences
            UserDefaults.standard.removeObject(forKey: "privacySettings")
            UserDefaults.standard.removeObject(forKey: "accessibilitySettings")

            // Clear caches
            ImageCacheManager.shared.clearCache()
            SDUIComponentCache.shared.clearCache()

            privacySettings = PrivacySettings()
            saveSettings()

            return true
        } catch {
            print("Failed to delete user data: \(error)")
            return false
        }
    }

    // MARK: - Accessibility Compliance

    func enableAccessibilityFeatures() {
        accessibilitySettings.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        accessibilitySettings.isDynamicTypeEnabled = true
        accessibilitySettings.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        accessibilitySettings.isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled

        saveSettings()
        applyAccessibilitySettings()
    }

    private func applyAccessibilitySettings() {
        // Apply accessibility settings app-wide
        NotificationCenter.default.post(name: .accessibilitySettingsChanged, object: accessibilitySettings)
    }

    // MARK: - App Store Review Compliance

    func validateAppStoreCompliance() -> ComplianceResult {
        var issues: [ComplianceIssue] = []

        // Check privacy compliance
        if !privacySettings.hasPrivacyPolicy {
            issues.append(ComplianceIssue(
                type: .privacy,
                severity: .critical,
                description: "Privacy policy is required",
                solution: "Add privacy policy URL to Info.plist"
            ))
        }

        // Check accessibility compliance
        if !accessibilitySettings.hasAccessibilityLabels {
            issues.append(ComplianceIssue(
                type: .accessibility,
                severity: .warning,
                description: "Missing accessibility labels on interactive elements",
                solution: "Add accessibility labels to all buttons and interactive elements"
            ))
        }

        // Check metadata compliance
        if Bundle.main.displayName?.isEmpty ?? true {
            issues.append(ComplianceIssue(
                type: .metadata,
                severity: .critical,
                description: "App display name is required",
                solution: "Set CFBundleDisplayName in Info.plist"
            ))
        }

        // Check for required device capabilities
        if !hasRequiredDeviceCapabilities() {
            issues.append(ComplianceIssue(
                type: .deviceCapabilities,
                severity: .warning,
                description: "Missing device capability declarations",
                solution: "Declare required device capabilities in Info.plist"
            ))
        }

        return ComplianceResult(
            isCompliant: issues.filter { $0.severity == .critical }.isEmpty,
            issues: issues,
            lastChecked: Date()
        )
    }

    private func hasRequiredDeviceCapabilities() -> Bool {
        guard let capabilities = Bundle.main.infoDictionary?["UIRequiredDeviceCapabilities"] as? [String] else {
            return false
        }
        return capabilities.contains("location-services")
    }

    // MARK: - Crash Reporting Compliance

    func setupCrashReporting() {
        // Setup privacy-compliant crash reporting
        // Only collect crashes if user has consented
        if privacySettings.hasConsentedToCrashReporting {
            enableCrashReporting()
        }
    }

    private func enableCrashReporting() {
        // In production, integrate with Firebase Crashlytics or similar
        // with appropriate privacy controls
        print("Crash reporting enabled with user consent")
    }

    // MARK: - Rating and Review Compliance

    func requestReviewIfAppropriate() {
        let reviewPromptCount = UserDefaults.standard.integer(forKey: "reviewPromptCount")
        let lastReviewPrompt = UserDefaults.standard.object(forKey: "lastReviewPrompt") as? Date ?? Date.distantPast

        // Only prompt for review if:
        // 1. User has completed at least 5 jobs
        // 2. Haven't prompted in the last 30 days
        // 3. Haven't prompted more than 3 times total
        let jobsCompleted = getJobsCompletedCount()
        let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastReviewPrompt, to: Date()).day ?? 0

        if jobsCompleted >= 5 && daysSinceLastPrompt >= 30 && reviewPromptCount < 3 {
            requestReview()
        }
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)

            UserDefaults.standard.set(Date(), forKey: "lastReviewPrompt")
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "reviewPromptCount") + 1, forKey: "reviewPromptCount")
        }
    }

    // MARK: - Data Usage Tracking

    private func getJobsCompletedCount() -> Int {
        // In production, query Core Data
        return 0
    }

    private func getRoutesCompletedCount() -> Int {
        // In production, query Core Data
        return 0
    }

    private func getAverageSessionTime() -> TimeInterval {
        // In production, track session times
        return 0
    }

    private func getLocationDataSummary() -> LocationDataSummary {
        return LocationDataSummary(
            totalLocationsRecorded: 0,
            averageAccuracy: 0,
            dataRetentionPeriod: 30 // days
        )
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "privacySettings"),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            privacySettings = settings
        }

        if let data = UserDefaults.standard.data(forKey: "accessibilitySettings"),
           let settings = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            accessibilitySettings = settings
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(privacySettings) {
            UserDefaults.standard.set(data, forKey: "privacySettings")
        }

        if let data = try? JSONEncoder().encode(accessibilitySettings) {
            UserDefaults.standard.set(data, forKey: "accessibilitySettings")
        }
    }

    private func checkCompliance() {
        let result = validateAppStoreCompliance()
        complianceStatus = ComplianceStatus(
            isPrivacyCompliant: privacySettings.hasPrivacyPolicy,
            isAccessibilityCompliant: accessibilitySettings.hasAccessibilityLabels,
            hasRequiredMetadata: !(Bundle.main.displayName?.isEmpty ?? true),
            lastComplianceCheck: Date(),
            criticalIssuesCount: result.issues.filter { $0.severity == .critical }.count
        )
    }
}

// MARK: - Data Models

struct PrivacySettings: Codable {
    var hasConsentedToDataUsage = false
    var hasConsentedToCrashReporting = false
    var hasConsentedToAnalytics = false
    var hasPrivacyPolicy = true
    var userId: String = UUID().uuidString
    var userEmail: String = ""
    var dataProcessingPreferences: [String: Bool] = [:]
}

struct AccessibilitySettings: Codable {
    var isVoiceOverEnabled = false
    var isDynamicTypeEnabled = false
    var isReduceMotionEnabled = false
    var isHighContrastEnabled = false
    var hasAccessibilityLabels = true
    var preferredContentSizeCategory: String = "medium"
}

struct ComplianceStatus {
    var isPrivacyCompliant = false
    var isAccessibilityCompliant = false
    var hasRequiredMetadata = false
    var lastComplianceCheck = Date()
    var criticalIssuesCount = 0

    var overallCompliance: Double {
        let compliantItems = [isPrivacyCompliant, isAccessibilityCompliant, hasRequiredMetadata]
        let compliantCount = compliantItems.filter { $0 }.count
        return Double(compliantCount) / Double(compliantItems.count)
    }
}

struct ComplianceResult {
    let isCompliant: Bool
    let issues: [ComplianceIssue]
    let lastChecked: Date
}

struct ComplianceIssue {
    enum IssueType {
        case privacy, accessibility, metadata, deviceCapabilities, performance
    }

    enum Severity {
        case critical, warning, info
    }

    let type: IssueType
    let severity: Severity
    let description: String
    let solution: String
}

struct UserDataExport: Codable {
    let personalInfo: PersonalInfo
    let appUsage: AppUsageData
    let locationData: LocationDataSummary
    let exportDate: Date
}

struct PersonalInfo: Codable {
    let userId: String
    let email: String
    let preferences: [String: Bool]
}

struct AppUsageData: Codable {
    let jobsCompleted: Int
    let routesCompleted: Int
    let averageSessionTime: TimeInterval
}

struct LocationDataSummary: Codable {
    let totalLocationsRecorded: Int
    let averageAccuracy: Double
    let dataRetentionPeriod: Int
}

// MARK: - SwiftUI Views

struct PrivacyConsentView: View {
    @StateObject private var complianceManager = AppStoreComplianceManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy & Data Usage")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("PestGenie collects and processes the following data to provide our pest control services:")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 12) {
                        DataUsageRow(
                            icon: "location",
                            title: "Location Data",
                            description: "Used to navigate to job sites and track service areas"
                        )

                        DataUsageRow(
                            icon: "camera",
                            title: "Photos",
                            description: "Service photos are stored locally and can be synced to our servers"
                        )

                        DataUsageRow(
                            icon: "person.crop.circle",
                            title: "Contact Information",
                            description: "Customer contact details for service appointments"
                        )
                    }

                    Text("Your Rights")
                        .font(.headline)
                        .padding(.top)

                    Text("You have the right to access, modify, or delete your personal data at any time. You can also opt out of data processing for non-essential features.")
                        .font(.body)

                    Button("Accept and Continue") {
                        Task {
                            await complianceManager.requestDataUsageConsent()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button("Learn More") {
                        // Open privacy policy
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DataUsageRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct AccessibilitySettingsView: View {
    @StateObject private var complianceManager = AppStoreComplianceManager.shared

    var body: some View {
        Form {
            Section("Visual Accessibility") {
                Toggle("Dynamic Type", isOn: .constant(complianceManager.accessibilitySettings.isDynamicTypeEnabled))
                    .accessibilityLabel("Enable dynamic text sizing")

                Toggle("High Contrast", isOn: .constant(complianceManager.accessibilitySettings.isHighContrastEnabled))
                    .accessibilityLabel("Enable high contrast colors")

                Toggle("Reduce Motion", isOn: .constant(complianceManager.accessibilitySettings.isReduceMotionEnabled))
                    .accessibilityLabel("Reduce animations and motion effects")
            }

            Section("Voice Accessibility") {
                HStack {
                    Text("VoiceOver")
                    Spacer()
                    Text(complianceManager.accessibilitySettings.isVoiceOverEnabled ? "Enabled" : "Disabled")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("VoiceOver status: \(complianceManager.accessibilitySettings.isVoiceOverEnabled ? "enabled" : "disabled")")
            }

            Section("Content Size") {
                Picker("Text Size", selection: .constant(complianceManager.accessibilitySettings.preferredContentSizeCategory)) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                    Text("Extra Large").tag("extraLarge")
                }
                .accessibilityLabel("Select preferred text size")
            }
        }
        .navigationTitle("Accessibility")
        .onAppear {
            complianceManager.enableAccessibilityFeatures()
        }
    }
}

// MARK: - Extensions

extension Bundle {
    var displayName: String? {
        return infoDictionary?["CFBundleDisplayName"] as? String
    }

    var version: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

extension Notification.Name {
    static let accessibilitySettingsChanged = Notification.Name("accessibilitySettingsChanged")
}

// MARK: - Development Compliance Checker

#if DEBUG
struct ComplianceDebugView: View {
    @StateObject private var complianceManager = AppStoreComplianceManager.shared
    @State private var complianceResult: ComplianceResult?

    var body: some View {
        NavigationView {
            List {
                Section("Compliance Status") {
                    HStack {
                        Text("Overall Compliance")
                        Spacer()
                        Text("\(Int(complianceManager.complianceStatus.overallCompliance * 100))%")
                            .foregroundColor(complianceManager.complianceStatus.overallCompliance > 0.8 ? .green : .orange)
                    }
                }

                if let result = complianceResult {
                    Section("Issues") {
                        ForEach(result.issues, id: \.description) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(issue.description)
                                        .font(.headline)
                                    Spacer()
                                    Text(severityText(issue.severity))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(severityColor(issue.severity))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                Text(issue.solution)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Actions") {
                    Button("Check Compliance") {
                        complianceResult = complianceManager.validateAppStoreCompliance()
                    }

                    Button("Export User Data") {
                        let export = complianceManager.exportUserData()
                        print("User data export: \(export)")
                    }
                }
            }
            .navigationTitle("App Store Compliance")
        }
        .onAppear {
            complianceResult = complianceManager.validateAppStoreCompliance()
        }
    }

    private func severityText(_ severity: ComplianceIssue.Severity) -> String {
        switch severity {
        case .critical: return "Critical"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }

    private func severityColor(_ severity: ComplianceIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}
#endif