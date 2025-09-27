import SwiftUI

/// View for displaying chemical usage reports and analytics
struct ChemicalUsageReportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var routeViewModel: RouteViewModel

    @State private var selectedTimeframe: ChemicalUsageSummary.TimeframePeriod = .weekly
    @State private var showingExportOptions = false

    var usageSummaries: [ChemicalUsageSummary] {
        generateUsageSummaries(for: selectedTimeframe)
    }

    var totalApplications: Int {
        usageSummaries.reduce(0) { $0 + $1.numberOfApplications }
    }

    var totalChemicalsUsed: Double {
        usageSummaries.reduce(0.0) { $0 + $1.totalUsed }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Timeframe Selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(ChemicalUsageSummary.TimeframePeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Summary Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        SummaryCard(
                            title: "Total Applications",
                            value: "\(totalApplications)",
                            icon: "drop.circle.fill",
                            color: .blue
                        )

                        SummaryCard(
                            title: "Chemicals Used",
                            value: String(format: "%.1f L", totalChemicalsUsed),
                            icon: "flask.fill",
                            color: .green
                        )

                        SummaryCard(
                            title: "Active Chemicals",
                            value: "\(usageSummaries.count)",
                            icon: "list.bullet.circle.fill",
                            color: .orange
                        )

                        SummaryCard(
                            title: "Avg per Application",
                            value: totalApplications > 0 ? String(format: "%.2f L", totalChemicalsUsed / Double(totalApplications)) : "0 L",
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)

                    // Usage Details
                    if !usageSummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Chemical Usage Details")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(usageSummaries) { summary in
                                ChemicalUsageCard(summary: summary)
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("No Usage Data")
                                .font(.headline)

                            Text("No chemical usage recorded for \(selectedTimeframe.displayName.lowercased())")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 32)
                    }

                    // Treatment History
                    if !routeViewModel.chemicalTreatments.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Treatments")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(recentTreatments.prefix(5), id: \.id) { treatment in
                                TreatmentHistoryRow(treatment: treatment, routeViewModel: routeViewModel)
                                    .padding(.horizontal)
                            }

                            if recentTreatments.count > 5 {
                                Text("+ \(recentTreatments.count - 5) more treatments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Usage Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        showingExportOptions = true
                    }
                    .disabled(usageSummaries.isEmpty)
                }
            }
            .confirmationDialog("Export Options", isPresented: $showingExportOptions) {
                Button("Export PDF Report") {
                    exportPDFReport()
                }
                Button("Export CSV Data") {
                    exportCSVData()
                }
                Button("Email Report") {
                    emailReport()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var recentTreatments: [ChemicalTreatment] {
        routeViewModel.chemicalTreatments
            .sorted { $0.applicationDate > $1.applicationDate }
    }

    private func generateUsageSummaries(for timeframe: ChemicalUsageSummary.TimeframePeriod) -> [ChemicalUsageSummary] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch timeframe {
        case .daily:
            startDate = calendar.startOfDay(for: now)
        case .weekly:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .monthly:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .quarterly:
            let quarterStart = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
            startDate = quarterStart
        case .yearly:
            startDate = calendar.dateInterval(of: .year, for: now)?.start ?? now
        }

        let filteredTreatments = routeViewModel.chemicalTreatments.filter { treatment in
            treatment.applicationDate >= startDate
        }

        let groupedByChemical = Dictionary(grouping: filteredTreatments) { $0.chemicalId }

        return groupedByChemical.compactMap { (chemicalId, treatments) in
            guard let chemical = routeViewModel.chemicals.first(where: { $0.id == chemicalId }) else {
                return nil
            }

            let totalUsed = treatments.reduce(0.0) { $0 + $1.quantityUsed }
            let numberOfApplications = treatments.count
            let averagePerApplication = numberOfApplications > 0 ? totalUsed / Double(numberOfApplications) : 0.0
            let mostRecentApplication = treatments.max { $0.applicationDate < $1.applicationDate }?.applicationDate

            return ChemicalUsageSummary(
                chemical: chemical,
                totalUsed: totalUsed,
                numberOfApplications: numberOfApplications,
                averagePerApplication: averagePerApplication,
                mostRecentApplication: mostRecentApplication,
                timeframe: timeframe
            )
        }.sorted { $0.totalUsed > $1.totalUsed }
    }

    private func exportPDFReport() {
        // In production, generate PDF report
        print("Exporting PDF report for \(selectedTimeframe.displayName)")
    }

    private func exportCSVData() {
        // In production, generate CSV export
        print("Exporting CSV data for \(selectedTimeframe.displayName)")
    }

    private func emailReport() {
        // In production, compose email with report
        print("Emailing report for \(selectedTimeframe.displayName)")
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ChemicalUsageCard: View {
    let summary: ChemicalUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.chemical.name)
                        .font(.headline)

                    Text(summary.chemical.activeIngredient)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.2f %@", summary.totalUsed, summary.chemical.unitOfMeasure))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("\(summary.numberOfApplications) applications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg per Application")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.2f %@", summary.averagePerApplication, summary.chemical.unitOfMeasure))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                if let lastUse = summary.mostRecentApplication {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last Used")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(lastUse, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct TreatmentHistoryRow: View {
    let treatment: ChemicalTreatment
    let routeViewModel: RouteViewModel

    private var chemical: Chemical? {
        routeViewModel.chemicals.first { $0.id == treatment.chemicalId }
    }

    private var job: Job? {
        routeViewModel.jobs.first { $0.id == treatment.jobId }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chemical?.name ?? "Unknown Chemical")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(job?.customerName ?? "Unknown Customer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", treatment.quantityUsed, chemical?.unitOfMeasure ?? "units"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(treatment.applicationDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    ChemicalUsageReportView(routeViewModel: RouteViewModel())
}