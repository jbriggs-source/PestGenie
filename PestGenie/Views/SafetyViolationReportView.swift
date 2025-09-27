import SwiftUI
import PhotosUI

struct SafetyViolationReportView: View {
    @StateObject private var emergencyManager = EmergencyManager()
    @StateObject private var checklistManager = SafetyChecklistManager()
    @Environment(\.dismiss) private var dismiss

    let violation: SafetyViolationReport

    @State private var actionPlan: String = ""
    @State private var correctiveActions: [String] = []
    @State private var newCorrectiveAction: String = ""
    @State private var timeToResolve: TimeInterval = 3600 // 1 hour default
    @State private var supervisorNotified: Bool = false
    @State private var emergencyResponseRequired: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var evidencePhotos: [Data] = []
    @State private var showingEmergencyAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Violation Header
                    violationHeader

                    // Severity Assessment
                    severityAssessment

                    // Action Plan Section
                    actionPlanSection

                    // Corrective Actions
                    correctiveActionsSection

                    // Evidence Collection
                    evidenceSection

                    // Emergency Response
                    emergencyResponseSection

                    // Submit Section
                    submitSection
                }
                .padding()
            }
            .navigationTitle("Violation Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Emergency Response Required", isPresented: $showingEmergencyAlert) {
            Button("Contact Emergency Services") {
                contactEmergencyServices()
            }
            Button("Notify Supervisor Only") {
                notifySupervisor()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This violation may require immediate emergency response. Choose appropriate action.")
        }
        .onAppear {
            loadViolationDetails()
        }
    }

    // MARK: - Violation Header

    private var violationHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(Color(violation.severity.color))

                VStack(alignment: .leading, spacing: 4) {
                    Text(violation.title)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(violation.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Reported: \(violation.reportedAt.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(violation.severity.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(violation.severity.color))
                        .cornerRadius(6)

                    if violation.isResolved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
            }

            Text(violation.description)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color(violation.severity.color).opacity(0.1))
                .cornerRadius(8)
        }
    }

    // MARK: - Severity Assessment

    private var severityAssessment: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk Assessment")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                RiskFactorRow(
                    title: "Immediate Danger",
                    isPresent: violation.severity == .critical,
                    color: .red
                )

                RiskFactorRow(
                    title: "Personnel Safety Risk",
                    isPresent: violation.category == .personalProtectiveEquipment || violation.category == .healthMedical,
                    color: .orange
                )

                RiskFactorRow(
                    title: "Environmental Risk",
                    isPresent: violation.category == .chemicalSafety,
                    color: .yellow
                )

                RiskFactorRow(
                    title: "Regulatory Compliance",
                    isPresent: violation.category == .regulatoryCompliance,
                    color: .blue
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Action Plan Section

    private var actionPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Plan")
                .font(.headline)
                .fontWeight(.bold)

            TextField("Describe immediate actions taken and planned resolution...", text: $actionPlan, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(4...8)

            HStack {
                Text("Estimated Resolution Time:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Picker("Time to Resolve", selection: $timeToResolve) {
                    Text("Immediate").tag(TimeInterval(0))
                    Text("1 Hour").tag(TimeInterval(3600))
                    Text("4 Hours").tag(TimeInterval(14400))
                    Text("24 Hours").tag(TimeInterval(86400))
                    Text("Next Service").tag(TimeInterval(604800))
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }

    // MARK: - Corrective Actions

    private var correctiveActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Corrective Actions")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(Array(correctiveActions.enumerated()), id: \.offset) { index, action in
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)

                    Text(action)
                        .font(.subheadline)

                    Spacer()

                    Button(action: {
                        correctiveActions.remove(at: index)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                TextField("Add corrective action...", text: $newCorrectiveAction)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    if !newCorrectiveAction.isEmpty {
                        correctiveActions.append(newCorrectiveAction)
                        newCorrectiveAction = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .disabled(newCorrectiveAction.isEmpty)
            }

            // Suggested actions based on violation type
            if !suggestedActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Actions:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(suggestedActions, id: \.self) { suggestion in
                        Button(action: {
                            if !correctiveActions.contains(suggestion) {
                                correctiveActions.append(suggestion)
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)

                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.blue)

                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Evidence Section

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evidence Collection")
                .font(.headline)
                .fontWeight(.bold)

            HStack {
                Text("Additional Photos:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Add Evidence")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }

            if !evidencePhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<evidencePhotos.count, id: \.self) { index in
                            if let uiImage = UIImage(data: evidencePhotos[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                                    .overlay(
                                        Button(action: {
                                            evidencePhotos.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 6, y: -6),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onChange(of: selectedPhotos) { _ in
            Task {
                evidencePhotos = []
                for item in selectedPhotos {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        evidencePhotos.append(data)
                    }
                }
            }
        }
    }

    // MARK: - Emergency Response Section

    private var emergencyResponseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emergency Response")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                Toggle("Supervisor Notification Required", isOn: $supervisorNotified)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))

                Toggle("Emergency Response Required", isOn: $emergencyResponseRequired)
                    .toggleStyle(SwitchToggleStyle(tint: .red))
                    .onChange(of: emergencyResponseRequired) { newValue in
                        if newValue {
                            showingEmergencyAlert = true
                        }
                    }

                if supervisorNotified || emergencyResponseRequired {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Contacts Available:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(relevantEmergencyContacts) { contact in
                            HStack {
                                Image(systemName: contact.type.icon)
                                    .foregroundColor(contact.type == .emergency911 ? .red : .blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

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
                                        .padding(8)
                                        .background(contact.type == .emergency911 ? Color.red : Color.blue)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Submit Section

    private var submitSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                submitViolationReport()
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Violation Report")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSubmitReport ? Color.blue : Color.gray)
                .cornerRadius(10)
            }
            .disabled(!canSubmitReport)

            if emergencyResponseRequired {
                Button(action: {
                    submitAndTriggerEmergency()
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Submit & Trigger Emergency Response")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                }
            }

            Text("Report will be automatically submitted to safety management system and relevant personnel will be notified.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Computed Properties

    private var suggestedActions: [String] {
        switch violation.category {
        case .personalProtectiveEquipment:
            return [
                "Replace damaged PPE immediately",
                "Verify PPE certification and compliance",
                "Document PPE inspection results",
                "Schedule refresher PPE training"
            ]
        case .chemicalSafety:
            return [
                "Secure chemical storage area",
                "Verify SDS sheet availability",
                "Check spill containment equipment",
                "Review chemical handling procedures"
            ]
        case .equipmentSafety:
            return [
                "Remove equipment from service",
                "Schedule immediate maintenance",
                "Document equipment condition",
                "Provide alternative equipment"
            ]
        case .siteSafetyAssessment:
            return [
                "Re-evaluate site conditions",
                "Implement additional safety measures",
                "Document site hazards",
                "Adjust treatment protocols"
            ]
        case .healthMedical:
            return [
                "Seek immediate medical attention",
                "Document symptoms and exposure",
                "Report to occupational health",
                "Review medical monitoring protocols"
            ]
        case .regulatoryCompliance:
            return [
                "Review regulatory requirements",
                "Update compliance documentation",
                "Schedule regulatory training",
                "Notify regulatory authorities if required"
            ]
        case .communicationDocumentation:
            return [
                "Test communication equipment",
                "Update emergency contact list",
                "Verify notification procedures",
                "Schedule communication protocol review"
            ]
        case .vehicleTransportation:
            return [
                "Inspect vehicle safety systems",
                "Secure equipment and chemicals",
                "Document vehicle condition",
                "Schedule maintenance if needed"
            ]
        }
    }

    private var relevantEmergencyContacts: [EmergencyResponseContact] {
        return emergencyManager.emergencyContacts.filter { contact in
            switch violation.category {
            case .chemicalSafety:
                return contact.type == .poisonControl || contact.type == .environmental || contact.type == .supervisor
            case .healthMedical:
                return contact.type == .emergency911 || contact.type == .supervisor
            case .equipmentSafety:
                return contact.type == .companyDispatch || contact.type == .supervisor
            default:
                return contact.type == .supervisor || contact.type == .companyDispatch
            }
        }
    }

    private var canSubmitReport: Bool {
        return !actionPlan.isEmpty && !correctiveActions.isEmpty
    }

    // MARK: - Helper Methods

    private func loadViolationDetails() {
        // Pre-populate fields based on violation details
        actionPlan = violation.notes.isEmpty ? "" : "Previous notes: \(violation.notes)"
        supervisorNotified = violation.supervisorNotified
        emergencyResponseRequired = violation.severity == .critical
    }

    private func contactEmergencyServices() {
        if let emergency911 = emergencyManager.emergencyContacts.first(where: { $0.type == .emergency911 }) {
            emergencyManager.callEmergencyContact(emergency911)
        }
    }

    private func notifySupervisor() {
        if let supervisor = emergencyManager.emergencyContacts.first(where: { $0.type == .supervisor }) {
            emergencyManager.callEmergencyContact(supervisor)
        }
        supervisorNotified = true
    }

    private func submitViolationReport() {
        // Create updated violation report
        var updatedViolation = violation
        updatedViolation.notes += "\n\nAction Plan: \(actionPlan)"
        updatedViolation.notes += "\nCorrectiveActions: \(correctiveActions.joined(separator: "; "))"
        updatedViolation.photos.append(contentsOf: evidencePhotos)

        // Submit to safety management system
        checklistManager.resolveViolation(violation.id, notes: actionPlan)

        // Notify relevant personnel
        if supervisorNotified {
            notifySupervisor()
        }

        dismiss()
    }

    private func submitAndTriggerEmergency() {
        submitViolationReport()

        // Create emergency incident
        emergencyManager.reportIncident(
            .customerSafety,
            severity: .high,
            title: "Safety Violation Emergency: \(violation.title)",
            description: "Critical safety violation requiring immediate response: \(violation.description)",
            photos: evidencePhotos.map { UIImage(data: $0) }.compactMap { $0 },
            additionalNotes: "Action Plan: \(actionPlan)"
        )

        // Contact emergency services if critical
        if violation.severity == .critical {
            contactEmergencyServices()
        }
    }
}

// MARK: - Risk Factor Row

struct RiskFactorRow: View {
    let title: String
    let isPresent: Bool
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isPresent ? color : .gray)

            Text(title)
                .font(.subheadline)
                .foregroundColor(isPresent ? .primary : .secondary)

            Spacer()

            if isPresent {
                Text("PRESENT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .cornerRadius(4)
            }
        }
    }
}

#Preview {
    SafetyViolationReportView(
        violation: SafetyViolationReport(
            id: UUID(),
            checklistId: UUID(),
            itemId: UUID(),
            category: .chemicalSafety,
            severity: .high,
            title: "Chemical Storage Violation",
            description: "Chemicals not properly secured in vehicle storage compartment",
            reportedAt: Date(),
            photos: [],
            notes: "Found during routine inspection",
            isResolved: false,
            resolvedAt: nil,
            supervisorNotified: false
        )
    )
}