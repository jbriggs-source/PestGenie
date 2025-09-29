import SwiftUI

/// Detailed equipment inspection view for individual equipment items
struct EquipmentInspectionView: View {
    let equipment: Equipment
    @ObservedObject var routeViewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inspectionResult: InspectionResult = .passed
    @State private var inspectionNotes = ""
    @State private var showingCompletionAlert = false
    @State private var checklistItems: [InspectionChecklistItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Equipment Header
                    EquipmentHeaderCard(equipment: equipment)

                    // Inspection Checklist
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Inspection Checklist")
                            .font(.headline)
                            .fontWeight(.semibold)

                        ForEach(checklistItems.indices, id: \.self) { index in
                            InspectionChecklistRow(
                                item: $checklistItems[index]
                            )
                        }
                    }

                    // Overall Result
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overall Result")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Picker("Inspection Result", selection: $inspectionResult) {
                            ForEach(InspectionResult.allCases, id: \.self) { result in
                                Text(result.displayName).tag(result)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Notes Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Inspection Notes")
                            .font(.headline)
                            .fontWeight(.semibold)

                        TextField("Add any observations or issues...", text: $inspectionNotes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Equipment Specifications
                    if shouldShowSpecifications {
                        EquipmentSpecificationsCard(equipment: equipment)
                    }
                }
                .padding()
            }
            .navigationTitle("Equipment Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Complete") {
                        completeInspection()
                    }
                    .disabled(!allRequiredItemsCompleted)
                }
            }
            .alert("Inspection Complete", isPresented: $showingCompletionAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Equipment inspection has been recorded.")
            }
            .onAppear {
                setupChecklistItems()
            }
        }
    }

    private var allRequiredItemsCompleted: Bool {
        let requiredItems = checklistItems.filter { $0.isRequired }
        return requiredItems.allSatisfy { $0.isCompleted }
    }

    private var shouldShowSpecifications: Bool {
        equipment.type == .moistureMeter || equipment.type == .thermometer || equipment.category == .detectionTools
    }

    private func setupChecklistItems() {
        checklistItems = generateChecklistItems(for: equipment)
    }

    private func completeInspection() {
        // Auto-determine result based on checklist
        let failedItems = checklistItems.filter { !$0.isCompleted && $0.isRequired }
        let calibrationIssues = checklistItems.filter { $0.category == .calibration && !$0.isCompleted }
        let maintenanceIssues = checklistItems.filter { $0.category == .maintenance && !$0.isCompleted }

        let finalResult: InspectionResult
        if !failedItems.isEmpty {
            finalResult = .failed
        } else if !calibrationIssues.isEmpty {
            finalResult = .needsCalibration
        } else if !maintenanceIssues.isEmpty {
            finalResult = .needsMaintenance
        } else {
            finalResult = .passed
        }

        // Compile notes from failed items
        let itemNotes = checklistItems
            .filter { !$0.notes.isEmpty }
            .map { "\($0.itemName): \($0.notes)" }
            .joined(separator: "; ")

        let finalNotes = [inspectionNotes, itemNotes]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")

        routeViewModel.recordEquipmentInspection(
            equipmentId: equipment.id,
            inspectionType: .preService,
            result: finalResult,
            notes: finalNotes
        )

        showingCompletionAlert = true
    }

    private func generateChecklistItems(for equipment: Equipment) -> [InspectionChecklistItem] {
        var items: [InspectionChecklistItem] = []

        // Common visual inspection items
        items.append(contentsOf: [
            InspectionChecklistItem(
                itemName: "Physical Condition",
                description: "Check for cracks, damage, or wear",
                category: .visual,
                isRequired: true
            ),
            InspectionChecklistItem(
                itemName: "Cleanliness",
                description: "Equipment is clean and free of debris",
                category: .visual,
                isRequired: true
            ),
            InspectionChecklistItem(
                itemName: "Labels & Markings",
                description: "All labels are legible and intact",
                category: .visual,
                isRequired: true
            )
        ])

        // Equipment-specific items
        switch equipment.type {
        case .backpackSprayer, .tankSprayer, .handSprayer:
            items.append(contentsOf: [
                InspectionChecklistItem(
                    itemName: "Pressure Test",
                    description: "Holds pressure without leaks",
                    category: .functional,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Nozzle Function",
                    description: "Spray pattern is consistent",
                    category: .functional,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Hose Integrity",
                    description: "No cracks or leaks in hoses",
                    category: .safety,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Tank Capacity",
                    description: "Tank holds rated capacity",
                    category: .functional,
                    isRequired: false
                )
            ])

        case .thermometer:
            items.append(contentsOf: [
                InspectionChecklistItem(
                    itemName: "Calibration Check",
                    description: "Accurate to ±0.1g with test weights",
                    category: .calibration,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Level Check",
                    description: "Scale is properly leveled",
                    category: .functional,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Display Function",
                    description: "Display is clear and responsive",
                    category: .functional,
                    isRequired: true
                )
            ])

        case .moistureMeter:
            items.append(contentsOf: [
                InspectionChecklistItem(
                    itemName: "Calibration Verification",
                    description: "Reads correctly with test standards",
                    category: .calibration,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Probe Condition",
                    description: "Probes are clean and undamaged",
                    category: .functional,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Battery Level",
                    description: "Battery charge is adequate",
                    category: .functional,
                    isRequired: true
                )
            ])

        case .borescope:
            items.append(contentsOf: [
                InspectionChecklistItem(
                    itemName: "Image Quality",
                    description: "Images are clear and focused",
                    category: .functional,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Battery Life",
                    description: "Battery holds charge",
                    category: .functional,
                    isRequired: true
                ),
                InspectionChecklistItem(
                    itemName: "Memory Card",
                    description: "Memory card is inserted and functional",
                    category: .functional,
                    isRequired: true
                )
            ])

        default:
            items.append(InspectionChecklistItem(
                itemName: "Functional Test",
                description: "Equipment operates as intended",
                category: .functional,
                isRequired: true
            ))
        }

        // Common maintenance items
        items.append(contentsOf: [
            InspectionChecklistItem(
                itemName: "Maintenance Schedule",
                description: "Maintenance is current and documented",
                category: .maintenance,
                isRequired: false
            ),
            InspectionChecklistItem(
                itemName: "Safety Features",
                description: "All safety mechanisms function properly",
                category: .safety,
                isRequired: true
            )
        ])

        return items
    }
}

struct InspectionChecklistItem: Identifiable {
    let id = UUID()
    let itemName: String
    let description: String
    let category: PreServiceChecklistItem.ChecklistCategory
    let isRequired: Bool
    var isCompleted: Bool = false
    var notes: String = ""
}

struct EquipmentHeaderCard: View {
    let equipment: Equipment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: equipment.type.icon)
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(equipment.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(equipment.brand) \(equipment.model)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusBadge(status: equipment.status)
            }

            Divider()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                InfoItem(label: "Serial", value: equipment.serialNumber)
                InfoItem(label: "Type", value: equipment.type.displayName)
                InfoItem(label: "Category", value: equipment.category.displayName)
                if let lastInspection = equipment.lastInspectionDate {
                    InfoItem(label: "Last Inspection", value: lastInspection, isDate: true)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InspectionChecklistRow: View {
    @Binding var item: InspectionChecklistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    item.isCompleted.toggle()
                }) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(item.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.itemName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if item.isRequired {
                            Text("REQUIRED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }

                        Spacer()

                        CategoryBadge(category: item.category)
                    }

                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if item.isCompleted && !item.notes.isEmpty || !item.isCompleted {
                TextField("Notes (optional)", text: $item.notes)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isCompleted ? Color.green.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct CategoryBadge: View {
    let category: PreServiceChecklistItem.ChecklistCategory

    var body: some View {
        Text(category.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(category.color))
            .cornerRadius(4)
    }
}

struct StatusBadge: View {
    let status: EquipmentStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(6)
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    let isDate: Bool

    init(label: String, value: String, isDate: Bool = false) {
        self.label = label
        self.value = value
        self.isDate = isDate
    }

    init(label: String, value: Date, isDate: Bool = true) {
        self.label = label
        self.isDate = isDate

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        self.value = formatter.string(from: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct EquipmentSpecificationsCard: View {
    let equipment: Equipment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specifications")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                if let capacity = equipment.specifications.tankCapacity, capacity > 0 {
                    InfoItem(label: "Capacity", value: String(format: "%.1f gallons", capacity))
                }

                if let accuracy = equipment.specifications.accuracy {
                    InfoItem(label: "Accuracy", value: accuracy)
                }

                if let weight = equipment.specifications.weight {
                    InfoItem(label: "Weight", value: String(format: "%.1f lbs", weight))
                }

                if let powerSource = equipment.specifications.powerSource {
                    InfoItem(label: "Power", value: powerSource)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


#Preview {
    EquipmentInspectionView(
        equipment: Equipment(
            name: "Backpack Sprayer",
            brand: "Solo",
            model: "BS-1025",
            serialNumber: "BSP-2024-001",
            type: .backpackSprayer
        ),
        routeViewModel: RouteViewModel()
    )
}