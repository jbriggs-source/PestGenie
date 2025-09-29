import SwiftUI

/// Enhanced privacy consent view with trust indicators and compliance features
struct PrivacyConsentView: View {
    @StateObject private var complianceManager = AppStoreComplianceManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var hasReadPrivacyPolicy = false
    @State private var hasReadTermsOfService = false
    @State private var consentToDataCollection = false
    @State private var consentToAnalytics = false
    @State private var isProcessingConsent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .symbolEffect(.pulse)

                        Text("Privacy & Security")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Your privacy is our priority. We're committed to protecting your data with industry-leading security measures.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Trust Indicators Section
                    VStack(spacing: 20) {
                        Text("Security & Compliance")
                            .font(.headline)
                            .fontWeight(.semibold)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            TrustBadgeView(
                                icon: "lock.shield.fill",
                                title: "SOC 2 Type II",
                                subtitle: "Certified",
                                color: .blue
                            )

                            TrustBadgeView(
                                icon: "checkmark.seal.fill",
                                title: "GDPR",
                                subtitle: "Compliant",
                                color: .green
                            )

                            TrustBadgeView(
                                icon: "building.2.fill",
                                title: "Enterprise",
                                subtitle: "Security",
                                color: .purple
                            )

                            TrustBadgeView(
                                icon: "globe.americas.fill",
                                title: "Privacy",
                                subtitle: "by Design",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Privacy Controls
                    VStack(spacing: 20) {
                        Text("Your Privacy Choices")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(spacing: 16) {
                            ConsentToggleRow(
                                icon: "doc.text.fill",
                                title: "Privacy Policy",
                                description: "I have read and agree to the Privacy Policy",
                                isOn: $hasReadPrivacyPolicy,
                                isRequired: true,
                                action: { showPrivacyPolicy() }
                            )

                            ConsentToggleRow(
                                icon: "doc.badge.gearshape.fill",
                                title: "Terms of Service",
                                description: "I have read and agree to the Terms of Service",
                                isOn: $hasReadTermsOfService,
                                isRequired: true,
                                action: { showTermsOfService() }
                            )

                            ConsentToggleRow(
                                icon: "tray.and.arrow.up.fill",
                                title: "Data Collection",
                                description: "Allow collection of necessary data for app functionality",
                                isOn: $consentToDataCollection,
                                isRequired: true
                            )

                            ConsentToggleRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Analytics & Improvement",
                                description: "Help us improve the app with anonymous usage data",
                                isOn: $consentToAnalytics,
                                isRequired: false
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            Task { await handleConsentSubmission() }
                        } label: {
                            HStack {
                                if isProcessingConsent {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                }
                                Text(isProcessingConsent ? "Processing..." : "Accept & Continue")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canProceed ? .blue : .secondary)
                            .foregroundColor(.white)
                            .font(.system(.body, weight: .semibold))
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .disabled(!canProceed || isProcessingConsent)

                        Button("Decline") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                        .frame(height: 44)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Privacy & Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var canProceed: Bool {
        hasReadPrivacyPolicy && hasReadTermsOfService && consentToDataCollection
    }

    // MARK: - Actions

    private func showPrivacyPolicy() {
        hasReadPrivacyPolicy = true
    }

    private func showTermsOfService() {
        hasReadTermsOfService = true
    }

    private func handleConsentSubmission() async {
        isProcessingConsent = true

        var privacySettings = complianceManager.privacySettings
        privacySettings.hasConsentedToDataUsage = true
        privacySettings.hasConsentedToAnalytics = consentToAnalytics
        privacySettings.consentDate = Date()

        privacySettings.dataProcessingPreferences = [
            "dataCollection": consentToDataCollection,
            "analytics": consentToAnalytics,
            "locationTracking": true,
            "crashReporting": consentToAnalytics
        ]

        complianceManager.privacySettings = privacySettings
        SecurityLogger.shared.logSecurityEvent(.dataEncryptionEnabled)

        isProcessingConsent = false
        dismiss()
    }
}

// MARK: - Supporting Views

struct TrustBadgeView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ConsentToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let isRequired: Bool
    let action: (() -> Void)?

    init(icon: String, title: String, description: String, isOn: Binding<Bool>, isRequired: Bool, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self._isOn = isOn
        self.isRequired = isRequired
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }

            if let action = action, !isOn {
                Button("Read \(title)") {
                    action()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isRequired && !isOn ? .red.opacity(0.5) : .clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    PrivacyConsentView()
}