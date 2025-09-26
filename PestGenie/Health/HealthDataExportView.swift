import SwiftUI
import UniformTypeIdentifiers

/// Health data export view for privacy compliance
struct HealthDataExportView: View {
    @ObservedObject var healthManager: HealthKitManager
    @State private var exportFormat: ExportFormat = .csv
    @State private var dateRange: DateRange = .allTime
    @State private var isExporting = false
    @State private var exportedData: HealthDataExport?
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            }
        }

        var contentType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .json: return .json
            }
        }
    }

    enum DateRange: String, CaseIterable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastThreeMonths = "Last 3 Months"
        case allTime = "All Time"

        var days: Int? {
            switch self {
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .lastThreeMonths: return 90
            case .allTime: return nil
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Header Section
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(PestGenieDesignSystem.Colors.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export Health Data")
                                    .font(PestGenieDesignSystem.Typography.headlineMedium)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                                Text("Download your activity data for your records")
                                    .font(PestGenieDesignSystem.Typography.body)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                            }

                            Spacer()
                        }
                    }

                    // Data Summary
                    DataSummarySection(healthManager: healthManager)

                    // Export Options
                    ExportOptionsSection(
                        exportFormat: $exportFormat,
                        dateRange: $dateRange
                    )

                    // Privacy Notice
                    PrivacyNoticeSection()

                    // Export Button
                    ExportButtonSection(
                        isExporting: isExporting,
                        onExport: exportData
                    )

                    if let exportedData = exportedData {
                        ExportPreviewSection(
                            data: exportedData,
                            format: exportFormat,
                            showingShareSheet: $showingShareSheet
                        )
                    }
                }
                .padding(PestGenieDesignSystem.Spacing.lg)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportedData = exportedData {
                ShareSheet(
                    data: exportedData,
                    format: exportFormat
                )
            }
        }
    }

    private func exportData() {
        isExporting = true

        Task {
            let sessions = healthManager.getAllHealthSessions()
            let filteredSessions = filterSessions(sessions, by: dateRange)

            let export = HealthDataExport(
                exportDate: Date(),
                userId: "anonymous", // Don't export actual user ID for privacy
                sessions: filteredSessions,
                privacySettings: healthManager.privacySettings,
                weeklyReports: generateWeeklyReportSummaries(from: filteredSessions)
            )

            DispatchQueue.main.async {
                self.exportedData = export
                self.isExporting = false
            }
        }
    }

    private func filterSessions(_ sessions: [JobHealthSession], by range: DateRange) -> [JobHealthSession] {
        guard let days = range.days else { return sessions }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessions.filter { $0.startTime >= cutoffDate }
    }

    private func generateWeeklyReportSummaries(from sessions: [JobHealthSession]) -> [HealthDataExport.WeeklyHealthReportSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
        }

        return grouped.map { weekStart, weekSessions in
            let totalSteps = weekSessions.reduce(0) { $0 + $1.totalStepsWalked }
            let totalDistance = weekSessions.reduce(0.0) { $0 + $1.totalDistanceWalked }
            let totalTime = weekSessions.reduce(0.0) { $0 + $1.duration }

            return HealthDataExport.WeeklyHealthReportSummary(
                weekStart: weekStart,
                totalSteps: totalSteps,
                totalDistanceMeters: totalDistance,
                totalActiveTimeSeconds: totalTime
            )
        }.sorted { $0.weekStart < $1.weekStart }
    }
}

// MARK: - Section Views

struct DataSummarySection: View {
    @ObservedObject var healthManager: HealthKitManager

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Data Summary")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            let sessions = healthManager.getAllHealthSessions()

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                SummaryRow(
                    title: "Total Job Sessions",
                    value: "\(sessions.count)"
                )

                SummaryRow(
                    title: "Total Steps Tracked",
                    value: "\(sessions.reduce(0) { $0 + $1.totalStepsWalked })"
                )

                let totalDistance = sessions.reduce(0.0) { $0 + $1.totalDistanceWalked }
                SummaryRow(
                    title: "Total Distance",
                    value: healthManager.formatDistance(totalDistance)
                )

                let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
                SummaryRow(
                    title: "Total Active Time",
                    value: healthManager.formatDuration(totalDuration)
                )

                if let oldest = sessions.min(by: { $0.startTime < $1.startTime }) {
                    SummaryRow(
                        title: "Data Since",
                        value: {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            return formatter.string(from: oldest.startTime)
                        }()
                    )
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(PestGenieDesignSystem.Colors.cardBackground)
            .cornerRadius(PestGenieDesignSystem.CornerRadius.medium)
        }
    }
}

struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PestGenieDesignSystem.Typography.body)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
        }
    }
}

struct ExportOptionsSection: View {
    @Binding var exportFormat: HealthDataExportView.ExportFormat
    @Binding var dateRange: HealthDataExportView.DateRange

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Export Options")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                // Format Selection
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("File Format")
                        .font(PestGenieDesignSystem.Typography.bodyEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Picker("Format", selection: $exportFormat) {
                        ForEach(HealthDataExportView.ExportFormat.allCases, id: \.rawValue) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // Date Range Selection
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Date Range")
                        .font(PestGenieDesignSystem.Typography.bodyEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Picker("Date Range", selection: $dateRange) {
                        ForEach(HealthDataExportView.DateRange.allCases, id: \.rawValue) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(PestGenieDesignSystem.Colors.cardBackground)
            .cornerRadius(PestGenieDesignSystem.CornerRadius.medium)
        }
    }
}

struct PrivacyNoticeSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(PestGenieDesignSystem.Colors.info)

                Text("Privacy Notice")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            }

            Text("Your exported data contains only activity metrics from job sessions. No personal identifying information, exact locations, or customer details are included in the export.")
                .font(PestGenieDesignSystem.Typography.body)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("• Job sessions are identified by UUID only\n• Customer names are replaced with generic identifiers\n• Location data is not exported\n• Only aggregated health metrics are included")
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(PestGenieDesignSystem.Colors.info.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.CornerRadius.medium)
                .stroke(PestGenieDesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(PestGenieDesignSystem.CornerRadius.medium)
    }
}

struct ExportButtonSection: View {
    let isExporting: Bool
    let onExport: () -> Void

    var body: some View {
        Button(action: onExport) {
            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.doc")
                }

                Text(isExporting ? "Preparing Export..." : "Export Data")
            }
            .font(PestGenieDesignSystem.Typography.buttonText)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(
                isExporting ?
                    PestGenieDesignSystem.Colors.accent.opacity(0.6) :
                    PestGenieDesignSystem.Colors.accent
            )
            .cornerRadius(PestGenieDesignSystem.CornerRadius.medium)
        }
        .disabled(isExporting)
    }
}

struct ExportPreviewSection: View {
    let data: HealthDataExport
    let format: HealthDataExportView.ExportFormat
    @Binding var showingShareSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Export Ready")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(PestGenieDesignSystem.Colors.success)
            }

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                SummaryRow(
                    title: "Sessions Exported",
                    value: "\(data.sessions.count)"
                )

                SummaryRow(
                    title: "File Format",
                    value: format.rawValue
                )

                SummaryRow(
                    title: "Export Date",
                    value: {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        return formatter.string(from: data.exportDate)
                    }()
                )
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(PestGenieDesignSystem.Colors.cardBackground)
            .cornerRadius(PestGenieDesignSystem.CornerRadius.medium)

            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Export")
                }
                .font(PestGenieDesignSystem.Typography.buttonText)
                .foregroundColor(PestGenieDesignSystem.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(PestGenieDesignSystem.Spacing.md)
                .background(PestGenieDesignSystem.Colors.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: PestGenieDesignSystem.CornerRadius.medium)
                        .stroke(PestGenieDesignSystem.Colors.accent, lineWidth: 1)
                )
                .cornerRadius(PestGenieDesignSystem.CornerRadius.medium)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let data: HealthDataExport
    let format: HealthDataExportView.ExportFormat

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let exportContent: String
        let fileName: String

        switch format {
        case .csv:
            exportContent = data.generateCSV()
            fileName = "health_data_export_\(Int(data.exportDate.timeIntervalSince1970)).csv"
        case .json:
            exportContent = String(data: try! JSONEncoder().encode(data), encoding: .utf8) ?? ""
            fileName = "health_data_export_\(Int(data.exportDate.timeIntervalSince1970)).json"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? exportContent.write(to: tempURL, atomically: true, encoding: .utf8)

        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )

        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct HealthDataExportView_Previews: PreviewProvider {
    static var previews: some View {
        HealthDataExportView(healthManager: HealthKitManager.shared)
    }
}