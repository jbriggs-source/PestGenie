import SwiftUI

struct EmergencyAlertView: View {
    @ObservedObject var routeViewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    let emergency: EmergencyScenario
    @State private var responseSelected = false
    @State private var supervisorContacted = false
    @State private var emergencyResolved = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Emergency Header
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)

                        Text("EMERGENCY ALERT")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)

                        Text(emergency.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        Text(emergency.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)

                    // Emergency Details
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Emergency Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        VStack(spacing: 12) {
                            EmergencyDetailRow(
                                icon: "location.fill",
                                title: "Location",
                                value: emergency.location,
                                color: .red
                            )

                            EmergencyDetailRow(
                                icon: "clock.fill",
                                title: "Reported At",
                                value: emergency.reportedTime,
                                color: .orange
                            )

                            EmergencyDetailRow(
                                icon: "exclamationmark.circle.fill",
                                title: "Severity",
                                value: emergency.severity.rawValue.capitalized,
                                color: emergency.severity.color
                            )

                            EmergencyDetailRow(
                                icon: "person.fill.questionmark",
                                title: "Risk Level",
                                value: emergency.riskLevel,
                                color: .red
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Response Actions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Required Actions")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        VStack(spacing: 8) {
                            ForEach(emergency.requiredActions, id: \.self) { action in
                                ActionChecklistItem(
                                    action: action,
                                    isCompleted: .constant(false)
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Emergency Response Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            respondToEmergency()
                        }) {
                            HStack {
                                Image(systemName: "phone.fill")
                                    .font(.title3)
                                Text("Contact Emergency Services")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            contactSupervisor()
                        }) {
                            HStack {
                                Image(systemName: supervisorContacted ? "checkmark.circle.fill" : "person.badge.plus")
                                    .font(.title3)
                                Text(supervisorContacted ? "Supervisor Notified" : "Notify Supervisor")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(supervisorContacted ? .green : .orange)
                            .cornerRadius(12)
                        }
                        .disabled(supervisorContacted)

                        if responseSelected && supervisorContacted {
                            Button(action: {
                                resolveEmergency()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                    Text("Mark Emergency Resolved")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Emergency Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(!emergencyResolved)
                }
            }
        }
    }

    private func respondToEmergency() {
        responseSelected = true
        // In real app, this would initiate emergency call
        // For demo, we simulate the response
    }

    private func contactSupervisor() {
        supervisorContacted = true
        // In real app, this would call/text supervisor
        // For demo, we just mark as contacted
    }

    private func resolveEmergency() {
        emergencyResolved = true
        // Return to normal operations
        routeViewModel.demoMode = false
        routeViewModel.hasActiveEmergency = false
        routeViewModel.currentEmergency = nil
        dismiss()
    }
}

struct EmergencyDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ActionChecklistItem: View {
    let action: String
    @Binding var isCompleted: Bool

    var body: some View {
        HStack {
            Button(action: {
                isCompleted.toggle()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
                    .font(.title3)
            }

            Text(action)
                .font(.body)
                .foregroundColor(isCompleted ? .secondary : .primary)
                .strikethrough(isCompleted)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Emergency Scenario Model

struct EmergencyScenario {
    let title: String
    let description: String
    let location: String
    let reportedTime: String
    let severity: EmergencySeverity
    let riskLevel: String
    let requiredActions: [String]

    static let beeSwarm = EmergencyScenario(
        title: "Bee Swarm at Elementary School",
        description: "Large bee swarm has formed near the playground during recess. Children have been evacuated to indoor areas.",
        location: "Westside Elementary School",
        reportedTime: "8:47 AM",
        severity: .critical,
        riskLevel: "HIGH - Multiple children at risk",
        requiredActions: [
            "Secure the area and establish safety perimeter",
            "Contact school administration immediately",
            "Assess swarm behavior and safety risks",
            "Prepare specialized bee removal equipment",
            "Coordinate with emergency services if needed",
            "Document incident for compliance reporting"
        ]
    )

    static let chemicalSpill = EmergencyScenario(
        title: "Chemical Spill in Commercial Kitchen",
        description: "Pesticide container leaked in restaurant kitchen during treatment. Staff evacuated, potential food contamination.",
        location: "Downtown Bistro",
        reportedTime: "10:23 AM",
        severity: .high,
        riskLevel: "MEDIUM - Food safety concern",
        requiredActions: [
            "Contain spill and prevent spread",
            "Contact restaurant manager and health department",
            "Assess contamination extent",
            "Arrange professional cleanup crew",
            "Complete incident documentation",
            "Schedule follow-up inspection"
        ]
    )

    static let equipmentFailure = EmergencyScenario(
        title: "Equipment Malfunction - Gas Leak",
        description: "Sprayer equipment malfunction resulted in chemical gas release. Immediate area evacuation required.",
        location: "Hillside Office Complex",
        reportedTime: "2:15 PM",
        severity: .critical,
        riskLevel: "HIGH - Respiratory hazard",
        requiredActions: [
            "Evacuate immediate area immediately",
            "Don emergency respiratory protection",
            "Shut off all equipment and power sources",
            "Contact hazmat emergency response",
            "Secure area until professionals arrive",
            "File incident report with regulatory agencies"
        ]
    )
}

enum EmergencySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct EmergencyAlertView_Previews: PreviewProvider {
    static var previews: some View {
        EmergencyAlertView(
            routeViewModel: RouteViewModel(),
            emergency: .beeSwarm
        )
    }
}