import SwiftUI

/// View for manually adjusting chemical inventory
struct InventoryAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var routeViewModel: RouteViewModel

    @State private var selectedChemicalId: UUID?
    @State private var adjustmentAmount: String = ""
    @State private var selectedReason: InventoryAdjustmentReason = .restock
    @State private var notes: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Chemical Selection") {
                    Picker("Chemical", selection: $selectedChemicalId) {
                        ForEach(routeViewModel.chemicals) { chemical in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(chemical.name)
                                        .font(.headline)
                                    Text(chemical.activeIngredient)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(chemical.quantityFormatted)
                                    .font(.caption)
                                    .foregroundColor(chemical.isLowStock ? .red : .secondary)
                            }
                            .tag(chemical.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Adjustment Details") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(InventoryAdjustmentReason.allCases, id: \.self) { reason in
                            HStack {
                                Text(reason.displayName)
                                Spacer()
                                Image(systemName: reason.isPositiveAdjustment ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundColor(reason.isPositiveAdjustment ? .green : .red)
                            }
                            .tag(reason)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack {
                        Text(selectedReason.isPositiveAdjustment ? "Add Quantity" : "Subtract Quantity")
                        Spacer()
                        TextField("0.0", text: $adjustmentAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)

                        if let chemical = selectedChemical {
                            Text(chemical.unitOfMeasure)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Adjustment notes (required)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let chemical = selectedChemical {
                    Section("Current Inventory") {
                        HStack {
                            Text("Current Stock")
                            Spacer()
                            Text(chemical.quantityFormatted)
                                .foregroundColor(chemical.isLowStock ? .red : .secondary)
                        }

                        if let adjustmentValue = Double(adjustmentAmount), adjustmentValue > 0 {
                            HStack {
                                Text("Stock After Adjustment")
                                Spacer()
                                let finalAmount = selectedReason.isPositiveAdjustment ?
                                    adjustmentValue : -adjustmentValue
                                let newStock = max(0, chemical.quantityInStock + finalAmount)
                                Text(String(format: "%.2f %@", newStock, chemical.unitOfMeasure))
                                    .foregroundColor(newStock < 10.0 ? .red : .green)
                            }
                        }

                        HStack {
                            Text("Last Modified")
                            Spacer()
                            Text(chemical.lastModified, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Adjustment Summary") {
                    HStack {
                        Text("Action")
                        Spacer()
                        Text(selectedReason.displayName)
                            .foregroundColor(.secondary)
                    }

                    if let adjustmentValue = Double(adjustmentAmount), adjustmentValue > 0 {
                        HStack {
                            Text("Amount")
                            Spacer()
                            let finalAmount = selectedReason.isPositiveAdjustment ?
                                adjustmentValue : -adjustmentValue
                            Text(String(format: "%+.2f %@", finalAmount, selectedChemical?.unitOfMeasure ?? "units"))
                                .foregroundColor(finalAmount > 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("Adjust Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyAdjustment()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Adjustment Applied", isPresented: $showingAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var selectedChemical: Chemical? {
        guard let id = selectedChemicalId else { return nil }
        return routeViewModel.chemicals.first { $0.id == id }
    }

    private var isFormValid: Bool {
        guard selectedChemicalId != nil,
              let adjustment = Double(adjustmentAmount),
              adjustment > 0,
              !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    private func applyAdjustment() {
        guard let chemicalId = selectedChemicalId,
              let adjustment = Double(adjustmentAmount),
              adjustment > 0 else {
            return
        }

        let finalAdjustment = selectedReason.isPositiveAdjustment ? adjustment : -adjustment

        routeViewModel.adjustChemicalInventory(
            chemicalId: chemicalId,
            adjustment: finalAdjustment,
            reason: selectedReason,
            notes: notes
        )

        let chemical = routeViewModel.chemicals.first { $0.id == chemicalId }
        let action = selectedReason.isPositiveAdjustment ? "Added" : "Removed"
        alertMessage = "\(action) \(adjustment) \(chemical?.unitOfMeasure ?? "units") of \(chemical?.name ?? "chemical")"
        showingAlert = true
    }
}

#Preview {
    InventoryAdjustmentView(routeViewModel: RouteViewModel())
}