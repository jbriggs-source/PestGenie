import SwiftUI

struct EmergencyProtocolView: View {
    let emergencyProtocol: EmergencyProtocol
    @ObservedObject var emergencyManager: EmergencyManager

    @Environment(\.dismiss) private var dismiss

    @State private var completedSteps: Set<Int> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Protocol Header
                    protocolHeader

                    // Emergency Steps
                    stepsSection

                    // Critical Contacts
                    if !emergencyProtocol.criticalContacts.isEmpty {
                        criticalContactsSection
                    }

                    // Bottom Actions
                    bottomActionsSection
                }
                .padding()
            }
            .navigationTitle("Emergency Protocol")
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

    // MARK: - Protocol Header

    private var protocolHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(emergencyProtocol.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Emergency Response Protocol")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)

                Text("Follow these steps in order. Do not skip steps unless instructed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Protocol Steps")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(Array(emergencyProtocol.steps.enumerated()), id: \.offset) { index, step in
                ProtocolStepRow(
                    stepNumber: index + 1,
                    stepText: step,
                    isCompleted: completedSteps.contains(index),
                    onToggle: {
                        if completedSteps.contains(index) {
                            completedSteps.remove(index)
                        } else {
                            completedSteps.insert(index)
                        }
                    }
                )
            }

            // Progress indicator
            ProgressView(
                value: Double(completedSteps.count),
                total: Double(emergencyProtocol.steps.count)
            ) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(completedSteps.count)/\(emergencyProtocol.steps.count) steps completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.green)
        }
    }

    // MARK: - Critical Contacts Section

    private var criticalContactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Critical Contacts")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(emergencyProtocol.criticalContacts) { contact in
                HStack(spacing: 12) {
                    Image(systemName: contact.type.icon)
                        .font(.title3)
                        .foregroundColor(contact.type == .emergency911 ? .red : .blue)
                        .frame(width: 32, height: 32)
                        .background(Color(contact.type == .emergency911 ? "red" : "blue").opacity(0.1))
                        .cornerRadius(6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(contact.phoneNumber)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Button(action: {
                        emergencyManager.callEmergencyContact(contact)
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(contact.type == .emergency911 ? Color.red : Color.blue)
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Bottom Actions Section

    private var bottomActionsSection: some View {
        VStack(spacing: 12) {
            // Report Incident Button
            Button(action: {
                // This would open the incident report view
                // For now, we'll show an alert
            }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Report This Incident")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }

            // Emergency Location Share
            if let location = emergencyManager.currentLocation {
                Button(action: {
                    shareLocation()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Share Current Location")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            Text("Ensure all steps are completed before considering the emergency response protocol finished.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
    }

    // MARK: - Helper Methods

    private func shareLocation() {
        guard let location = emergencyManager.currentLocation else { return }

        let locationString = "Emergency Location: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        let activityVC = UIActivityViewController(
            activityItems: [locationString],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Protocol Step Row

struct ProtocolStepRow: View {
    let stepNumber: Int
    let stepText: String
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number/checkbox
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color(.systemGray4))
                        .frame(width: 24, height: 24)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(stepNumber)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Step text
            Text(stepText)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .secondary : .primary)
                .strikethrough(isCompleted)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let emergencyManager = EmergencyManager()
    let sampleProtocol = EmergencyProtocol(
        title: "Chemical Exposure Protocol",
        steps: [
            "1. Remove contaminated clothing immediately",
            "2. Flush affected area with water for 15-20 minutes",
            "3. Call Poison Control: 1-800-222-1222",
            "4. Do not induce vomiting unless instructed",
            "5. Seek immediate medical attention",
            "6. Report incident to supervisor immediately"
        ],
        criticalContacts: emergencyManager.emergencyContacts.filter { $0.type == .poisonControl || $0.type == .emergency911 }
    )

    EmergencyProtocolView(emergencyProtocol: sampleProtocol, emergencyManager: emergencyManager)
}