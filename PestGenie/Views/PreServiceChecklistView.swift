import SwiftUI

/// Pre-service checklist view for equipment inspection before route start
struct PreServiceChecklistView: View {
    @ObservedObject var routeViewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentChecklist: PreServiceChecklist?
    @State private var showingEquipmentInspection = false
    @State private var selectedEquipment: Equipment?
    @State private var showingCompletionAlert = false
    @State private var canStartRoute = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)

                        Text("Pre-Service Equipment Check")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Complete all equipment inspections before starting your route")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Equipment List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Assigned Equipment")
                            .font(.headline)
                            .fontWeight(.semibold)

                        ForEach(routeViewModel.assignedEquipment) { equipment in
                            EquipmentCheckRow(
                                equipment: equipment,
                                isInspected: isEquipmentInspectedToday(equipment.id),
                                inspectionResult: getLastInspectionResult(equipment.id)
                            ) {
                                selectedEquipment = equipment
                                showingEquipmentInspection = true
                            }
                        }

                        if routeViewModel.assignedEquipment.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)

                                Text("No Equipment Assigned")
                                    .font(.headline)

                                Text("Please contact your supervisor to assign equipment before starting your route.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    }

                    // Checklist Progress
                    if !routeViewModel.assignedEquipment.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Inspection Progress")
                                .font(.headline)
                                .fontWeight(.semibold)

                            ChecklistProgressCard(
                                totalEquipment: routeViewModel.assignedEquipment.count,
                                inspectedEquipment: getInspectedEquipmentCount(),
                                passedInspections: getPassedInspectionCount(),
                                canStartRoute: $canStartRoute
                            )
                        }
                    }

                    // Safety Reminders
                    SafetyRemindersCard()
                }
                .padding()
            }
            .navigationTitle("Equipment Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Complete") {
                        completeChecklist()
                    }
                    .disabled(!canStartRoute)
                }
            }
            .sheet(isPresented: $showingEquipmentInspection) {
                if let equipment = selectedEquipment {
                    EquipmentInspectionView(
                        equipment: equipment,
                        routeViewModel: routeViewModel
                    )
                }
            }
            .alert("Checklist Complete", isPresented: $showingCompletionAlert) {
                Button("Start Route") {
                    dismiss()
                }
            } message: {
                Text("All equipment has been inspected and is ready for use. You may now start your route.")
            }
            .onAppear {
                updateCanStartRoute()
            }
            .onChange(of: routeViewModel.equipmentInspections) { _ in
                updateCanStartRoute()
            }
        }
    }

    private func isEquipmentInspectedToday(_ equipmentId: UUID) -> Bool {
        let todayInspections = routeViewModel.equipmentInspections.filter { inspection in
            Calendar.current.isDate(inspection.inspectionDate, inSameDayAs: Date()) &&
            inspection.equipmentId == equipmentId
        }
        return !todayInspections.isEmpty
    }

    private func getLastInspectionResult(_ equipmentId: UUID) -> InspectionResult? {
        let inspections = routeViewModel.equipmentInspections
            .filter { $0.equipmentId == equipmentId }
            .sorted { $0.inspectionDate > $1.inspectionDate }

        return inspections.first?.result
    }

    private func getInspectedEquipmentCount() -> Int {
        let todayInspections = routeViewModel.equipmentInspections.filter { inspection in
            Calendar.current.isDate(inspection.inspectionDate, inSameDayAs: Date())
        }
        let inspectedEquipmentIds = Set(todayInspections.map { $0.equipmentId })
        return inspectedEquipmentIds.count
    }

    private func getPassedInspectionCount() -> Int {
        let todayPassedInspections = routeViewModel.equipmentInspections.filter { inspection in
            Calendar.current.isDate(inspection.inspectionDate, inSameDayAs: Date()) &&
            inspection.result == .passed
        }
        let passedEquipmentIds = Set(todayPassedInspections.map { $0.equipmentId })
        return passedEquipmentIds.count
    }

    private func updateCanStartRoute() {
        let inspectedCount = getInspectedEquipmentCount()
        let passedCount = getPassedInspectionCount()

        canStartRoute = !routeViewModel.assignedEquipment.isEmpty &&
                       inspectedCount == routeViewModel.assignedEquipment.count &&
                       passedCount == routeViewModel.assignedEquipment.count
    }

    private func completeChecklist() {
        let success = routeViewModel.completePreServiceChecklist()
        if success {
            showingCompletionAlert = true
        }
    }
}

struct EquipmentCheckRow: View {
    let equipment: Equipment
    let isInspected: Bool
    let inspectionResult: InspectionResult?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Indicator
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 30)

                // Equipment Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(equipment.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(equipment.brand) \(equipment.model)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)
                }

                Spacer()

                // Action Indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusIcon: String {
        if isInspected {
            switch inspectionResult {
            case .passed:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.circle.fill"
            case .needsCalibration:
                return "gauge.open.with.lines.needle.33percent.exclamation"
            case .needsMaintenance:
                return "wrench.and.screwdriver.fill"
            case .pending:
                return "clock.circle.fill"
            case .conditionalPass:
                return "checkmark.circle.badge.questionmark.fill"
            case .none:
                return "questionmark.circle.fill"
            }
        } else {
            return "circle"
        }
    }

    private var statusColor: Color {
        if isInspected {
            switch inspectionResult {
            case .passed:
                return .green
            case .failed:
                return .red
            case .needsCalibration:
                return .orange
            case .needsMaintenance:
                return .yellow
            case .pending:
                return .blue
            case .conditionalPass:
                return .orange
            case .none:
                return .gray
            }
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if isInspected {
            switch inspectionResult {
            case .passed:
                return "✓ Inspection Passed"
            case .failed:
                return "✗ Inspection Failed"
            case .needsCalibration:
                return "⚠ Needs Calibration"
            case .needsMaintenance:
                return "⚠ Needs Maintenance"
            case .pending:
                return "⏱ Inspection Pending"
            case .conditionalPass:
                return "⚠ Conditional Pass"
            case .none:
                return "Unknown Status"
            }
        } else {
            return "Tap to Inspect"
        }
    }
}

struct ChecklistProgressCard: View {
    let totalEquipment: Int
    let inspectedEquipment: Int
    let passedInspections: Int
    @Binding var canStartRoute: Bool

    var progressPercentage: Double {
        guard totalEquipment > 0 else { return 0 }
        return Double(inspectedEquipment) / Double(totalEquipment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)

                Text("Progress Overview")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(Int(progressPercentage * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(progressPercentage == 1.0 ? .green : .blue)
            }

            // Progress Bar
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: progressPercentage == 1.0 ? .green : .blue))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            // Statistics
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inspected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(inspectedEquipment)/\(totalEquipment)")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Passed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(passedInspections)/\(totalEquipment)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(passedInspections == totalEquipment ? .green : .primary)
                }
            }

            // Status Message
            if canStartRoute {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("Ready to start route!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)

                    Text("Complete all inspections to continue")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct SafetyRemindersCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.red)

                Text("Safety Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                SafetyReminderRow(icon: "eye.fill", text: "Inspect all equipment visually before use")
                SafetyReminderRow(icon: "gauge.with.dots.needle.67percent", text: "Verify calibration dates and accuracy")
                SafetyReminderRow(icon: "person.badge.shield.checkmark.fill", text: "Ensure proper PPE is available and functional")
                SafetyReminderRow(icon: "exclamationmark.triangle.fill", text: "Report any defects immediately")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SafetyReminderRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PreServiceChecklistView(routeViewModel: RouteViewModel())
}