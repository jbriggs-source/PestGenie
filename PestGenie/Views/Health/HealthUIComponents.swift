import SwiftUI

// MARK: - Health Activity Widget (Real-time during active jobs)

struct HealthActivityWidget: View {
    @ObservedObject var healthManager: HealthKitManager
    @State private var isAnimating = false

    var body: some View {
        let summary = healthManager.currentActivitySummary
        if healthManager.activeJobSession != nil {
            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                // Header
                HStack {
                    Image(systemName: "figure.walk.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: isAnimating)

                    Text("Active Job Tracking")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }

                // Metrics
                HStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                    HealthMetricItem(
                        icon: "figure.walk",
                        value: "\(summary.sessionSteps)",
                        label: "Steps",
                        color: .blue
                    )

                    HealthMetricItem(
                        icon: "ruler",
                        value: String(format: "%.0f m", summary.sessionDistance),
                        label: "Distance",
                        color: .green
                    )

                    HealthMetricItem(
                        icon: "clock",
                        value: String(format: "%.0f min", summary.sessionDuration / 60),
                        label: "Active Time",
                        color: .orange
                    )
                }
            }
            .padding()
            .pestGenieCard()
            .onAppear {
                isAnimating = true
            }
        }
    }
}

// MARK: - Health Dashboard Card (Overview and daily goals)

struct HealthDashboardCard: View {
    @ObservedObject var healthManager: HealthKitManager

    var body: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                    .font(.title2)

                Text("Health & Activity")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if healthManager.isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Button("Enable") {
                        Task {
                            await healthManager.requestAuthorization()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            if healthManager.isAuthorized {
                let summary = healthManager.currentActivitySummary

                // Daily Progress
                VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    HealthProgressRow(
                        icon: "figure.walk",
                        title: "Daily Steps",
                        current: summary.todaySteps,
                        goal: 10000,
                        progress: Double(summary.todaySteps) / 10000.0,
                        color: .blue,
                        unit: "steps"
                    )

                    HealthProgressRow(
                        icon: "ruler",
                        title: "Daily Distance",
                        current: Int(summary.todayDistance),
                        goal: 5000,
                        progress: summary.todayDistance / 5000.0,
                        color: .green,
                        unit: "m",
                        formatter: { value in
                            value >= 1000 ? String(format: "%.1f km", Double(value) / 1000) : "\(value) m"
                        }
                    )

                    HealthProgressRow(
                        icon: "clock",
                        title: "Weekly Average",
                        current: summary.weeklyAverage,
                        goal: 10000,
                        progress: Double(summary.weeklyAverage) / 10000.0,
                        color: .orange,
                        unit: "steps",
                        formatter: { value in
                            return "\(value) steps"
                        }
                    )
                }

                // Overall Progress
                let overallProgress = (Double(summary.todaySteps) / 10000.0 + summary.todayDistance / 5000.0) / 2.0
                HStack {
                    Text("Overall Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(Int(overallProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(overallProgress > 0.8 ? .green : .primary)
                }

                ProgressView(value: overallProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: overallProgress > 0.8 ? .green : .blue))
            } else {
                // No data available
                VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Image(systemName: "heart.slash")
                        .font(.title)
                        .foregroundColor(.gray)

                    Text("Health tracking not available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !healthManager.isAuthorized {
                        Button("Enable Health Tracking") {
                            Task {
                                await healthManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                }
                .padding()
            }
        }
        .padding()
        .pestGenieCard()
    }
}

// MARK: - Supporting UI Components

struct HealthMetricItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct HealthProgressRow: View {
    let icon: String
    let title: String
    let current: Int
    let goal: Int
    let progress: Double
    let color: Color
    let unit: String
    var formatter: ((Int) -> String)?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .scaleEffect(y: 0.8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatter?(current) ?? "\(current)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("/ \(formatter?(goal) ?? "\(goal)")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Health Settings View

struct HealthSettingsView: View {
    @ObservedObject var healthManager: HealthKitManager
    @State private var showingPrivacySheet = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Health Tracking")) {
                    Toggle("Enable Health Tracking", isOn: .constant(healthManager.isTrackingEnabled))
                        .disabled(true) // Controlled by privacy settings

                    HStack {
                        Text("Authorization Status")
                        Spacer()
                        Text(healthManager.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(healthManager.isAuthorized ? .green : .orange)
                    }

                    if !healthManager.isAuthorized {
                        Button("Request HealthKit Authorization") {
                            Task {
                                await healthManager.requestAuthorization()
                            }
                        }
                    }
                }

                Section(header: Text("Privacy Settings")) {
                    Button("Manage Privacy Settings") {
                        showingPrivacySheet = true
                    }

                    HStack {
                        Text("Privacy Level")
                        Spacer()
                        Text(healthManager.privacySettings.privacyLevel.displayName)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Apple Health Sharing")
                        Spacer()
                        Text(healthManager.privacySettings.shareWithAppleHealth ? "Enabled" : "Disabled")
                            .foregroundColor(healthManager.privacySettings.shareWithAppleHealth ? .green : .gray)
                    }
                }

                Section(header: Text("Data Management")) {
                    NavigationLink("View Health Sessions") {
                        HealthSessionsListView(healthManager: healthManager)
                    }

                    Button("Export Health Data") {
                        exportHealthData()
                    }

                    Button("Clear All Health Data", role: .destructive) {
                        healthManager.clearAllHealthData()
                    }
                }
            }
            .navigationTitle("Health Settings")
            .sheet(isPresented: $showingPrivacySheet) {
                HealthPrivacySettingsView(healthManager: healthManager)
            }
        }
    }

    private func exportHealthData() {
        // For now, just log that export was requested
        // In a real implementation, this would export actual health data
        print("Health data export requested")
    }
}

// MARK: - Health Privacy Settings View

struct HealthPrivacySettingsView: View {
    @ObservedObject var healthManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var settings: HealthPrivacySettings

    init(healthManager: HealthKitManager) {
        self.healthManager = healthManager
        self._settings = State(initialValue: healthManager.privacySettings)
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Tracking Preferences")) {
                    Toggle("Allow Health Tracking", isOn: $settings.allowHealthTracking)

                    Toggle("Track Only During Jobs", isOn: $settings.trackOnlyDuringJobs)
                        .disabled(!settings.allowHealthTracking)
                }

                Section(header: Text("Data Sharing")) {
                    Toggle("Share with Apple Health", isOn: $settings.shareWithAppleHealth)
                        .disabled(!settings.allowHealthTracking)

                    Toggle("Allow Weekly Reports", isOn: $settings.allowWeeklyReports)
                        .disabled(!settings.allowHealthTracking)

                    Toggle("Allow Data Sharing", isOn: $settings.allowDataSharing)
                        .disabled(!settings.allowHealthTracking)
                }

                Section(header: Text("Privacy Level"), footer: Text(settings.privacyLevel.description)) {
                    Picker("Privacy Level", selection: $settings.privacyLevel) {
                        ForEach(HealthPrivacySettings.PrivacyLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(!settings.allowHealthTracking)
                }

                Section(header: Text("Features"), footer: Text("Features available at your selected privacy level")) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Basic activity tracking")
                            .font(.subheadline)
                    }

                    if settings.privacyLevel == .comprehensive {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Weekly reports")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        healthManager.updatePrivacySettings(settings)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Health Sessions List View

struct HealthSessionsListView: View {
    @ObservedObject var healthManager: HealthKitManager

    var body: some View {
        List {
            ForEach(healthManager.getAllHealthSessions().sorted { $0.startTime > $1.startTime }) { session in
                HealthSessionRow(session: session)
            }
        }
        .navigationTitle("Health Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HealthSessionRow: View {
    let session: JobHealthSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.customerName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(session.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                HealthSessionMetric(
                    icon: "figure.walk",
                    value: "\(session.totalStepsWalked)",
                    label: "steps"
                )

                HealthSessionMetric(
                    icon: "ruler",
                    value: session.formattedDistance,
                    label: ""
                )

                HealthSessionMetric(
                    icon: "clock",
                    value: session.formattedDuration,
                    label: ""
                )

                Spacer()

                Text("\(session.efficiencyScore)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(session.efficiencyScore >= 80 ? .green : session.efficiencyScore >= 60 ? .orange : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HealthSessionMetric: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)

            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Weekly Health Report View

struct WeeklyHealthReportView: View {
    let report: WeeklyHealthReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Health Report")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(report.weekRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Summary Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: PestGenieDesignSystem.Spacing.md) {
                    WeeklyStatCard(
                        title: "Total Steps",
                        value: "\(report.totalSteps)",
                        subtitle: "Avg: \(report.averageDailySteps)/day",
                        color: .blue,
                        icon: "figure.walk"
                    )

                    WeeklyStatCard(
                        title: "Distance",
                        value: String(format: "%.1f km", report.totalDistance / 1000),
                        subtitle: String(format: "Avg: %.1f km/day", report.averageDailyDistance / 1000),
                        color: .green,
                        icon: "ruler"
                    )

                    WeeklyStatCard(
                        title: "Active Time",
                        value: String(format: "%.1f hrs", report.totalActiveTime / 3600),
                        subtitle: "\(report.jobSessions.count) job sessions",
                        color: .orange,
                        icon: "clock"
                    )

                    if let mostActive = report.jobSessions.max(by: { $0.totalStepsWalked < $1.totalStepsWalked }) {
                        WeeklyStatCard(
                            title: "Most Active",
                            value: "\(mostActive.totalStepsWalked) steps",
                            subtitle: mostActive.customerName,
                            color: .purple,
                            icon: "trophy"
                        )
                    }
                }
                .padding(.horizontal)

                // Insights
                if !report.insights.isEmpty {
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                        Text("Health Insights")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        ForEach(report.insights) { insight in
                            HealthInsightCard(insight: insight)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WeeklyStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)

                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.headline)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .pestGenieCard()
    }
}

struct HealthInsightCard: View {
    let insight: HealthInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .foregroundColor(priorityColor(insight.priority))
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(insight.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(priorityColor(insight.priority).opacity(0.1))
        .cornerRadius(12)
    }

    private func priorityColor(_ priority: HealthInsight.InsightPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}