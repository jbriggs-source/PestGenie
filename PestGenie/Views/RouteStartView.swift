import SwiftUI

struct RouteStartView: View {
    @ObservedObject var routeViewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDemoOptions = false
    @State private var showingPreServiceChecklist = false
    @State private var showingSafetyChecklist = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Start Your Route")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Ready to begin today's pest control services?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Route Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "map.circle.fill")
                                .foregroundColor(.green)
                            Text("Today's Route Summary")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        VStack(spacing: 12) {
                            RouteMetricRow(
                                icon: "list.bullet.clipboard",
                                title: "Total Jobs",
                                value: "\(routeViewModel.jobs.count)",
                                color: .blue
                            )

                            RouteMetricRow(
                                icon: "clock.circle",
                                title: "Estimated Duration",
                                value: estimatedDuration,
                                color: .orange
                            )

                            RouteMetricRow(
                                icon: "location.north.circle",
                                title: "Total Distance",
                                value: estimatedDistance,
                                color: .green
                            )

                            RouteMetricRow(
                                icon: "thermometer.sun",
                                title: "Weather",
                                value: routeViewModel.weatherConditions,
                                color: .cyan
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Safety Checklist Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(safetyChecklistStatusColor)
                            Text("Safety Checklist")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: safetyChecklistIcon)
                                    .foregroundColor(safetyChecklistStatusColor)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(safetyChecklistStatusText)
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    Text("Required before route start")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }

                        // Button to open safety checklist
                        Button(action: {
                            showingSafetyChecklist = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.shield")
                                    .font(.title3)
                                Text(routeViewModel.safetyChecklistCompleted ? "Review Safety Checklist" : "Complete Safety Checklist")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(routeViewModel.safetyChecklistCompleted ? .blue : .red)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(routeViewModel.safetyChecklistCompleted ? Color.blue.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Equipment Check Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(equipmentChecklistStatusColor)
                            Text("Pre-Service Equipment Check")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        RealEquipmentChecklistView(routeViewModel: routeViewModel)

                        // Button to open detailed checklist
                        Button(action: {
                            showingPreServiceChecklist = true
                        }) {
                            HStack {
                                Image(systemName: "list.clipboard")
                                    .font(.title3)
                                Text(routeViewModel.preServiceChecklistCompleted ? "Review Equipment Checklist" : "Complete Equipment Checklist")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(routeViewModel.preServiceChecklistCompleted ? .blue : .orange)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(routeViewModel.preServiceChecklistCompleted ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Start Route Button
                    VStack(spacing: 12) {
                        Button(action: {
                            startRouteAction()
                        }) {
                            HStack {
                                Image(systemName: canStartRoute ? "play.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.title2)
                                Text(startButtonText)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(startButtonColor)
                            .cornerRadius(12)
                        }
                        .disabled(!canStartRoute || routeViewModel.isRouteStarted)

                        if !canStartRoute {
                            VStack(spacing: 4) {
                                if !routeViewModel.safetyChecklistCompleted {
                                    Text("Complete safety checklist before starting route")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                                if !routeViewModel.preServiceChecklistCompleted {
                                    Text("Complete equipment checklist before starting route")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }

                        // Demo Controls
                        Button("Demo Options") {
                            showingDemoOptions = true
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Route Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Demo Options", isPresented: $showingDemoOptions) {
            Button("Load Demo Data") {
                routeViewModel.loadDemoData()
            }
            Button("Emergency Scenario") {
                routeViewModel.loadEmergencyScenario()
                startRouteAction()
            }
            Button("Toggle Demo Mode") {
                routeViewModel.toggleDemoMode()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose a demo scenario to showcase PestGenie's capabilities")
        }
        .sheet(isPresented: $showingPreServiceChecklist) {
            PreServiceChecklistView(routeViewModel: routeViewModel)
        }
        .sheet(isPresented: $showingSafetyChecklist) {
            SafetyChecklistView(technicianId: routeViewModel.currentTechnicianId)
                .onDisappear {
                    // Check if safety checklist was completed
                    routeViewModel.checkSafetyChecklistCompletion()
                }
        }
    }

    private var estimatedDuration: String {
        let hours = max(4, routeViewModel.jobs.count / 2)
        return "\(hours)h estimated"
    }

    private var estimatedDistance: String {
        let miles = max(15, routeViewModel.jobs.count * 3)
        return "\(miles) miles"
    }

    private var canStartRoute: Bool {
        return routeViewModel.safetyChecklistCompleted && routeViewModel.preServiceChecklistCompleted && !routeViewModel.assignedEquipment.isEmpty
    }

    private var startButtonText: String {
        if routeViewModel.isRouteStarted {
            return "Route in Progress"
        } else if !routeViewModel.safetyChecklistCompleted {
            return "Complete Safety Checklist First"
        } else if !routeViewModel.preServiceChecklistCompleted {
            return "Complete Equipment Check First"
        } else {
            return "Start Route"
        }
    }

    private var startButtonColor: Color {
        if routeViewModel.isRouteStarted {
            return .gray
        } else if !routeViewModel.safetyChecklistCompleted {
            return .red
        } else if !canStartRoute {
            return .orange
        } else {
            return .green
        }
    }

    private var safetyChecklistStatusColor: Color {
        if routeViewModel.safetyChecklistCompleted {
            return .green
        } else {
            return .red
        }
    }

    private var safetyChecklistIcon: String {
        if routeViewModel.safetyChecklistCompleted {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    private var safetyChecklistStatusText: String {
        if routeViewModel.safetyChecklistCompleted {
            return "Safety checklist completed"
        } else {
            return "Safety checklist required"
        }
    }

    private var equipmentChecklistStatusColor: Color {
        if routeViewModel.preServiceChecklistCompleted {
            return .green
        } else {
            return .orange
        }
    }

    private func startRouteAction() {
        routeViewModel.startRoute()
        dismiss()
    }
}

struct RouteMetricRow: View {
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

struct RealEquipmentChecklistView: View {
    @ObservedObject var routeViewModel: RouteViewModel

    var body: some View {
        VStack(spacing: 8) {
            if routeViewModel.assignedEquipment.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)

                    Text("No equipment assigned")
                        .font(.body)
                        .foregroundColor(.orange)

                    Spacer()
                }
            } else {
                ForEach(routeViewModel.assignedEquipment.prefix(4)) { equipment in
                    HStack {
                        Image(systemName: equipmentStatusIcon(for: equipment))
                            .foregroundColor(equipmentStatusColor(for: equipment))
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(equipment.name)
                                .font(.body)
                                .foregroundColor(.primary)

                            Text(equipmentStatusText(for: equipment))
                                .font(.caption)
                                .foregroundColor(equipmentStatusColor(for: equipment))
                        }

                        Spacer()
                    }
                }

                if routeViewModel.assignedEquipment.count > 4 {
                    HStack {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                            .font(.title3)

                        Text("+\(routeViewModel.assignedEquipment.count - 4) more items")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }

            // Overall status summary
            Divider()

            HStack {
                Image(systemName: routeViewModel.preServiceChecklistCompleted ? "checkmark.circle.fill" : "clock.circle.fill")
                    .foregroundColor(routeViewModel.preServiceChecklistCompleted ? .green : .orange)
                    .font(.title3)

                Text(overallStatusText)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(routeViewModel.preServiceChecklistCompleted ? .green : .orange)

                Spacer()
            }
        }
    }

    private var overallStatusText: String {
        if routeViewModel.assignedEquipment.isEmpty {
            return "No equipment to check"
        } else if routeViewModel.preServiceChecklistCompleted {
            return "All equipment checked and ready"
        } else {
            let inspected = getInspectedEquipmentCount()
            let total = routeViewModel.assignedEquipment.count
            return "\(inspected)/\(total) equipment checked"
        }
    }

    private func equipmentStatusIcon(for equipment: Equipment) -> String {
        let result = getLastInspectionResult(equipment.id)
        switch result {
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .needsCalibration:
            return "gauge.open.with.lines.needle.33percent.exclamation"
        case .needsMaintenance:
            return "wrench.and.screwdriver.fill"
        case .pending:
            return "clock.circle"
        case .conditionalPass:
            return "checkmark.circle"
        case .none:
            return "circle"
        }
    }

    private func equipmentStatusColor(for equipment: Equipment) -> Color {
        let result = getLastInspectionResult(equipment.id)
        switch result {
        case .passed:
            return .green
        case .failed:
            return .red
        case .needsCalibration, .needsMaintenance:
            return .orange
        case .pending:
            return .blue
        case .conditionalPass:
            return .yellow
        case .none:
            return .gray
        }
    }

    private func equipmentStatusText(for equipment: Equipment) -> String {
        let result = getLastInspectionResult(equipment.id)
        switch result {
        case .passed:
            return "Ready"
        case .failed:
            return "Failed inspection"
        case .needsCalibration:
            return "Needs calibration"
        case .needsMaintenance:
            return "Needs maintenance"
        case .pending:
            return "Inspection pending"
        case .conditionalPass:
            return "Conditional pass"
        case .none:
            return "Not inspected"
        }
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
}

struct ChecklistItem {
    let title: String
    var isChecked: Bool
}

struct RouteStartView_Previews: PreviewProvider {
    static var previews: some View {
        RouteStartView(routeViewModel: RouteViewModel())
    }
}