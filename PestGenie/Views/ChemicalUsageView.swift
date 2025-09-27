import SwiftUI

/// View for recording chemical usage during treatments
struct ChemicalUsageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var routeViewModel: RouteViewModel

    @State private var selectedChemicalId: UUID?
    @State private var quantityUsed: String = ""
    @State private var selectedJobId: UUID?
    @State private var notes: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
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

                Section("Application Details") {
                    Picker("Job Site", selection: $selectedJobId) {
                        ForEach(routeViewModel.jobs) { job in
                            VStack(alignment: .leading) {
                                Text(job.customerName)
                                    .font(.headline)
                                Text(job.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(job.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack {
                        Text("Quantity Used")
                        Spacer()
                        TextField("0.0", text: $quantityUsed)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)

                        if let chemical = selectedChemical {
                            Text(chemical.unitOfMeasure)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Additional Notes") {
                    TextField("Application notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let chemical = selectedChemical {
                    Section("Chemical Information") {
                        HStack {
                            Text("Signal Word")
                            Spacer()
                            Text(chemical.signalWord.rawValue)
                                .foregroundColor(colorForSignalWord(chemical.signalWord))
                                .fontWeight(.semibold)
                        }

                        if chemical.reentryInterval > 0 {
                            HStack {
                                Text("Re-entry Interval")
                                Spacer()
                                Text("\(chemical.reentryInterval) hours")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Current Stock")
                            Spacer()
                            Text(chemical.quantityFormatted)
                                .foregroundColor(chemical.isLowStock ? .red : .secondary)
                        }

                        if let usedQuantity = Double(quantityUsed), usedQuantity > 0 {
                            HStack {
                                Text("Stock After Use")
                                Spacer()
                                let remainingStock = max(0, chemical.quantityInStock - usedQuantity)
                                Text(String(format: "%.2f %@", remainingStock, chemical.unitOfMeasure))
                                    .foregroundColor(remainingStock < 10.0 ? .red : .secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Record Chemical Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Record") {
                        recordUsage()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Usage Recorded", isPresented: $showingAlert) {
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
              selectedJobId != nil,
              let quantity = Double(quantityUsed),
              quantity > 0 else {
            return false
        }
        return true
    }

    private func recordUsage() {
        guard let chemicalId = selectedChemicalId,
              let jobId = selectedJobId,
              let quantity = Double(quantityUsed),
              quantity > 0 else {
            return
        }

        routeViewModel.recordChemicalUsage(
            chemicalId: chemicalId,
            quantityUsed: quantity,
            jobId: jobId,
            notes: notes
        )

        let chemical = routeViewModel.chemicals.first { $0.id == chemicalId }
        alertMessage = "Recorded \(quantity) \(chemical?.unitOfMeasure ?? "units") of \(chemical?.name ?? "chemical") usage"
        showingAlert = true
    }

    private func colorForSignalWord(_ signalWord: SignalWord) -> Color {
        switch signalWord {
        case .danger: return .red
        case .warning: return .orange
        case .caution: return .yellow
        }
    }
}

#Preview {
    ChemicalUsageView(routeViewModel: RouteViewModel())
}