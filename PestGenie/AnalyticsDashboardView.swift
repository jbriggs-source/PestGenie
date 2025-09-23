import SwiftUI

/// Analytics Dashboard for pest control technicians.
/// Provides comprehensive performance metrics, productivity insights, and business analytics.
/// Designed to help technicians track their performance and identify improvement opportunities.
struct AnalyticsDashboardView: View {
    @State private var selectedTimeframe: AnalyticsTimeframe = .thisMonth
    @State private var selectedMetricCategory: MetricCategory = .performance
    @State private var showingDetailView = false
    @State private var selectedMetric: AnalyticsMetric?
    @StateObject private var analyticsManager = AnalyticsManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timeframe selector
                timeframeSelectorView

                // Content
                ScrollView {
                    LazyVStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                        // Key metrics overview
                        keyMetricsOverview

                        // Performance charts
                        performanceChartsSection

                        // Detailed metrics by category
                        categoryMetricsSection

                        // Insights and recommendations
                        insightsSection

                        // Goals and targets
                        goalsTargetsSection
                    }
                    .padding(PestGenieDesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { exportAnalytics() }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { shareReport() }) {
                            Label("Share Report", systemImage: "square.and.arrow.up.on.square")
                        }
                        Button(action: { refreshData() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetailView) {
            if let metric = selectedMetric {
                metricDetailSheet(metric)
            }
        }
        .onAppear {
            loadAnalyticsData()
        }
    }

    // MARK: - Timeframe Selector

    private var timeframeSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(AnalyticsTimeframe.allCases, id: \.self) { timeframe in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeframe = timeframe
                            analyticsManager.updateTimeframe(timeframe)
                        }
                    }) {
                        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            Text(timeframe.displayName)
                                .font(PestGenieDesignSystem.Typography.labelMedium)
                                .foregroundColor(selectedTimeframe == timeframe ? PestGenieDesignSystem.Colors.primary : PestGenieDesignSystem.Colors.textSecondary)

                            if let subtitle = timeframe.subtitle {
                                Text(subtitle)
                                    .font(PestGenieDesignSystem.Typography.caption)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                            }

                            Rectangle()
                                .fill(selectedTimeframe == timeframe ? PestGenieDesignSystem.Colors.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(width: 80)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        }
        .background(PestGenieDesignSystem.Colors.surface)
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Key Metrics Overview

    private var keyMetricsOverview: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Performance Overview")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text(selectedTimeframe.displayName)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                keyMetricCard(
                    title: "Jobs Completed",
                    value: "\(analyticsManager.jobsCompleted)",
                    change: analyticsManager.jobsCompletedChange,
                    changeType: analyticsManager.jobsCompletedChangeType,
                    icon: "checkmark.circle.fill",
                    color: PestGenieDesignSystem.Colors.success
                )

                keyMetricCard(
                    title: "Revenue Generated",
                    value: String(format: "$%.0f", analyticsManager.revenueGenerated),
                    change: analyticsManager.revenueChange,
                    changeType: analyticsManager.revenueChangeType,
                    icon: "dollarsign.circle.fill",
                    color: PestGenieDesignSystem.Colors.accent
                )

                keyMetricCard(
                    title: "Customer Satisfaction",
                    value: String(format: "%.1f", analyticsManager.customerSatisfaction),
                    change: analyticsManager.satisfactionChange,
                    changeType: analyticsManager.satisfactionChangeType,
                    icon: "star.fill",
                    color: PestGenieDesignSystem.Colors.warning
                )

                keyMetricCard(
                    title: "Efficiency Score",
                    value: "\(Int(analyticsManager.efficiencyScore * 100))%",
                    change: analyticsManager.efficiencyChange,
                    changeType: analyticsManager.efficiencyChangeType,
                    icon: "speedometer",
                    color: PestGenieDesignSystem.Colors.info
                )
            }
        }
        .pestGenieCard()
    }

    private func keyMetricCard(
        title: String,
        value: String,
        change: Double,
        changeType: ChangeType,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))

                Spacer()

                changeIndicator(change: change, type: changeType)
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(value)
                    .font(PestGenieDesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .onTapGesture {
            // Show detailed view for this metric
        }
    }

    private func changeIndicator(change: Double, type: ChangeType) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Image(systemName: type.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(String(format: "%.1f%%", abs(change)))
                .font(PestGenieDesignSystem.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(type.color)
        .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
        .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
        .background(type.color.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Performance Charts Section

    private var performanceChartsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Performance Trends")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                // Revenue chart
                chartCard(
                    title: "Revenue Trend",
                    subtitle: "Daily revenue over time",
                    chartType: .line,
                    data: analyticsManager.revenueData,
                    color: PestGenieDesignSystem.Colors.success
                )

                // Jobs completion chart
                chartCard(
                    title: "Jobs Completion Rate",
                    subtitle: "Daily job completion metrics",
                    chartType: .bar,
                    data: analyticsManager.jobsData,
                    color: PestGenieDesignSystem.Colors.primary
                )

                // Customer satisfaction chart
                chartCard(
                    title: "Customer Satisfaction",
                    subtitle: "Average rating over time",
                    chartType: .area,
                    data: analyticsManager.satisfactionData,
                    color: PestGenieDesignSystem.Colors.warning
                )
            }
        }
    }

    private func chartCard(
        title: String,
        subtitle: String,
        chartType: ChartType,
        data: [ChartDataPoint],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            // Chart placeholder
            chartPlaceholder(type: chartType, color: color)

            // Chart summary
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text("Average")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text(String(format: "%.1f", data.map { $0.value }.reduce(0, +) / Double(data.count)))
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text("Peak")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    Text(String(format: "%.1f", data.map { $0.value }.max() ?? 0))
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(color)
                }
            }
        }
        .pestGenieCard()
    }

    private func chartPlaceholder(type: ChartType, color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.1))
            .frame(height: 120)
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            .overlay(
                VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Image(systemName: type.icon)
                        .font(.system(size: 32))
                        .foregroundColor(color.opacity(0.6))

                    Text("\(type.displayName) Chart")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            )
    }

    // MARK: - Category Metrics Section

    private var categoryMetricsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Detailed Metrics")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                // Category selector
                Menu {
                    ForEach(MetricCategory.allCases, id: \.self) { category in
                        Button(action: {
                            selectedMetricCategory = category
                        }) {
                            HStack {
                                Text(category.displayName)
                                if selectedMetricCategory == category {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Text(selectedMetricCategory.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }
            }

            ForEach(analyticsManager.getMetrics(for: selectedMetricCategory)) { metric in
                detailedMetricRow(metric)
            }
        }
        .pestGenieCard()
    }

    private func detailedMetricRow(_ metric: AnalyticsMetric) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(metric.name)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(metric.description)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(metric.formattedValue)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    changeIndicator(change: metric.change, type: metric.changeType)
                }
            }

            // Progress bar for target-based metrics
            if let target = metric.target {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    HStack {
                        Text("Progress to Target")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                        Spacer()

                        Text("\(Int((metric.value / target) * 100))%")
                            .font(PestGenieDesignSystem.Typography.captionEmphasis)
                            .foregroundColor(metric.value >= target ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.warning)
                    }

                    ProgressView(value: min(metric.value / target, 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: metric.value >= target ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.primary))
                        .background(PestGenieDesignSystem.Colors.surface)
                }
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .onTapGesture {
            selectedMetric = metric
            showingDetailView = true
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(PestGenieDesignSystem.Colors.warning)
                Text("Insights & Recommendations")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            }

            ForEach(analyticsManager.insights) { insight in
                insightCard(insight)
            }
        }
    }

    private func insightCard(_ insight: AnalyticsInsight) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: insight.type.icon)
                    .foregroundColor(insight.type.color)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(insight.title)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(insight.description)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                priorityBadge(insight.priority)
            }

            if !insight.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Recommendations:")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    ForEach(insight.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: PestGenieDesignSystem.Spacing.xs) {
                            Text("•")
                                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                            Text(recommendation)
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(insight.type.color.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.md)
                .stroke(insight.type.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func priorityBadge(_ priority: InsightPriority) -> some View {
        Text(priority.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(.white)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(priority.color)
            .clipShape(Capsule())
    }

    // MARK: - Goals and Targets Section

    private var goalsTargetsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                Text("Goals & Targets")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button("Set Goals") {
                    setGoals()
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }

            ForEach(analyticsManager.goals) { goal in
                goalCard(goal)
            }
        }
        .pestGenieCard()
    }

    private func goalCard(_ goal: PerformanceGoal) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(goal.name)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text("Target: \(goal.formattedTarget)")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(goal.formattedCurrentValue)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.bold)
                        .foregroundColor(goal.isAchieved ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.textPrimary)

                    if goal.isAchieved {
                        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Achieved")
                        }
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.success)
                    }
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                ProgressView(value: min(goal.progress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: goal.isAchieved ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.primary))
                    .background(PestGenieDesignSystem.Colors.surface)

                HStack {
                    Text("\(Int(goal.progress * 100))% complete")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Spacer()

                    if let deadline = goal.deadline {
                        Text("Due \(deadline, style: .date)")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(goal.isOverdue ? PestGenieDesignSystem.Colors.error : PestGenieDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    // MARK: - Detail Sheet

    private func metricDetailSheet(_ metric: AnalyticsMetric) -> some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Metric header
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                        Text(metric.name)
                            .font(PestGenieDesignSystem.Typography.headlineLarge)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text(metric.description)
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                        HStack {
                            Text("Current Value:")
                                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                            Text(metric.formattedValue)
                                .font(PestGenieDesignSystem.Typography.titleLarge)
                                .fontWeight(.bold)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            Spacer()

                            changeIndicator(change: metric.change, type: metric.changeType)
                        }
                    }

                    // Detailed chart would go here
                    Rectangle()
                        .fill(PestGenieDesignSystem.Colors.surface)
                        .frame(height: 200)
                        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
                        .overlay(
                            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)

                                Text("Detailed chart visualization")
                                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                            }
                        )

                    Spacer()
                }
                .padding(PestGenieDesignSystem.Spacing.md)
            }
            .navigationTitle("Metric Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDetailView = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadAnalyticsData() {
        analyticsManager.loadData()
    }

    private func refreshData() {
        analyticsManager.refresh()
    }

    private func exportAnalytics() {
        print("Exporting analytics data...")
    }

    private func shareReport() {
        print("Sharing analytics report...")
    }

    private func setGoals() {
        print("Setting performance goals...")
    }
}

// MARK: - Supporting Types and Enums

enum AnalyticsTimeframe: String, CaseIterable {
    case today = "today"
    case thisWeek = "week"
    case thisMonth = "month"
    case thisQuarter = "quarter"
    case thisYear = "year"

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisQuarter: return "This Quarter"
        case .thisYear: return "This Year"
        }
    }

    var subtitle: String? {
        let formatter = DateFormatter()
        let now = Date()

        switch self {
        case .today:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: now)
        case .thisWeek:
            return "Week \(Calendar.current.component(.weekOfYear, from: now))"
        case .thisMonth:
            formatter.dateFormat = "MMMM"
            return formatter.string(from: now)
        case .thisQuarter:
            let quarter = (Calendar.current.component(.month, from: now) - 1) / 3 + 1
            return "Q\(quarter) \(Calendar.current.component(.year, from: now))"
        case .thisYear:
            return "\(Calendar.current.component(.year, from: now))"
        }
    }
}

enum MetricCategory: String, CaseIterable {
    case performance = "performance"
    case productivity = "productivity"
    case customer = "customer"
    case financial = "financial"

    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .productivity: return "Productivity"
        case .customer: return "Customer"
        case .financial: return "Financial"
        }
    }
}

enum ChangeType {
    case increase
    case decrease
    case neutral

    var icon: String {
        switch self {
        case .increase: return "arrow.up"
        case .decrease: return "arrow.down"
        case .neutral: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .increase: return PestGenieDesignSystem.Colors.success
        case .decrease: return PestGenieDesignSystem.Colors.error
        case .neutral: return PestGenieDesignSystem.Colors.textSecondary
        }
    }
}

enum ChartType {
    case line
    case bar
    case area

    var displayName: String {
        switch self {
        case .line: return "Line"
        case .bar: return "Bar"
        case .area: return "Area"
        }
    }

    var icon: String {
        switch self {
        case .line: return "chart.line.uptrend.xyaxis"
        case .bar: return "chart.bar"
        case .area: return "chart.area"
        }
    }
}

enum InsightType {
    case opportunity
    case warning
    case achievement
    case suggestion

    var icon: String {
        switch self {
        case .opportunity: return "lightbulb"
        case .warning: return "exclamationmark.triangle"
        case .achievement: return "star"
        case .suggestion: return "arrow.up.right"
        }
    }

    var color: Color {
        switch self {
        case .opportunity: return PestGenieDesignSystem.Colors.info
        case .warning: return PestGenieDesignSystem.Colors.warning
        case .achievement: return PestGenieDesignSystem.Colors.success
        case .suggestion: return PestGenieDesignSystem.Colors.accent
        }
    }
}

enum InsightPriority {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .high: return PestGenieDesignSystem.Colors.error
        case .medium: return PestGenieDesignSystem.Colors.warning
        case .low: return PestGenieDesignSystem.Colors.info
        }
    }
}

// MARK: - Data Models

struct ChartDataPoint {
    let date: Date
    let value: Double
}

struct AnalyticsMetric: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let value: Double
    let change: Double
    let changeType: ChangeType
    let unit: String
    let target: Double?
    let category: MetricCategory

    var formattedValue: String {
        switch unit {
        case "$":
            return String(format: "$%.0f", value)
        case "%":
            return String(format: "%.1f%%", value)
        case "min":
            return "\(Int(value)) min"
        default:
            return String(format: "%.0f", value)
        }
    }
}

struct AnalyticsInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let priority: InsightPriority
    let title: String
    let description: String
    let recommendations: [String]
}

struct PerformanceGoal: Identifiable {
    let id = UUID()
    let name: String
    let currentValue: Double
    let targetValue: Double
    let unit: String
    let deadline: Date?

    var progress: Double {
        return currentValue / targetValue
    }

    var isAchieved: Bool {
        return currentValue >= targetValue
    }

    var isOverdue: Bool {
        guard let deadline = deadline else { return false }
        return deadline < Date() && !isAchieved
    }

    var formattedCurrentValue: String {
        switch unit {
        case "$":
            return String(format: "$%.0f", currentValue)
        case "%":
            return String(format: "%.1f%%", currentValue)
        case "min":
            return "\(Int(currentValue)) min"
        default:
            return String(format: "%.0f", currentValue)
        }
    }

    var formattedTarget: String {
        switch unit {
        case "$":
            return String(format: "$%.0f", targetValue)
        case "%":
            return String(format: "%.1f%%", targetValue)
        case "min":
            return "\(Int(targetValue)) min"
        default:
            return String(format: "%.0f", targetValue)
        }
    }
}

// MARK: - Analytics Manager

class AnalyticsManager: ObservableObject {
    @Published var currentTimeframe: AnalyticsTimeframe = .thisMonth

    // Key metrics
    @Published var jobsCompleted: Int = 0
    @Published var revenueGenerated: Double = 0
    @Published var customerSatisfaction: Double = 0
    @Published var efficiencyScore: Double = 0

    // Changes
    @Published var jobsCompletedChange: Double = 0
    @Published var revenueChange: Double = 0
    @Published var satisfactionChange: Double = 0
    @Published var efficiencyChange: Double = 0

    // Change types
    @Published var jobsCompletedChangeType: ChangeType = .neutral
    @Published var revenueChangeType: ChangeType = .neutral
    @Published var satisfactionChangeType: ChangeType = .neutral
    @Published var efficiencyChangeType: ChangeType = .neutral

    // Chart data
    @Published var revenueData: [ChartDataPoint] = []
    @Published var jobsData: [ChartDataPoint] = []
    @Published var satisfactionData: [ChartDataPoint] = []

    // Insights and goals
    @Published var insights: [AnalyticsInsight] = []
    @Published var goals: [PerformanceGoal] = []

    func loadData() {
        loadMockData()
    }

    func refresh() {
        loadData()
    }

    func updateTimeframe(_ timeframe: AnalyticsTimeframe) {
        currentTimeframe = timeframe
        loadData() // Reload data for new timeframe
    }

    func getMetrics(for category: MetricCategory) -> [AnalyticsMetric] {
        // Return metrics filtered by category
        return generateMetrics().filter { $0.category == category }
    }

    private func loadMockData() {
        // Mock key metrics based on timeframe
        switch currentTimeframe {
        case .today:
            jobsCompleted = 8
            revenueGenerated = 1200
            customerSatisfaction = 4.7
            efficiencyScore = 0.85
        case .thisWeek:
            jobsCompleted = 45
            revenueGenerated = 6750
            customerSatisfaction = 4.6
            efficiencyScore = 0.82
        case .thisMonth:
            jobsCompleted = 185
            revenueGenerated = 27750
            customerSatisfaction = 4.5
            efficiencyScore = 0.78
        case .thisQuarter:
            jobsCompleted = 520
            revenueGenerated = 78000
            customerSatisfaction = 4.4
            efficiencyScore = 0.75
        case .thisYear:
            jobsCompleted = 1950
            revenueGenerated = 292500
            customerSatisfaction = 4.3
            efficiencyScore = 0.72
        }

        // Mock changes
        jobsCompletedChange = 12.5
        revenueChange = 8.3
        satisfactionChange = 0.2
        efficiencyChange = 5.1

        jobsCompletedChangeType = .increase
        revenueChangeType = .increase
        satisfactionChangeType = .increase
        efficiencyChangeType = .increase

        // Mock chart data
        generateChartData()

        // Mock insights
        generateInsights()

        // Mock goals
        generateGoals()
    }

    private func generateChartData() {
        let calendar = Calendar.current
        let now = Date()

        revenueData = []
        jobsData = []
        satisfactionData = []

        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            revenueData.append(ChartDataPoint(date: date, value: Double.random(in: 800...1500)))
            jobsData.append(ChartDataPoint(date: date, value: Double.random(in: 5...12)))
            satisfactionData.append(ChartDataPoint(date: date, value: Double.random(in: 4.0...5.0)))
        }

        revenueData.reverse()
        jobsData.reverse()
        satisfactionData.reverse()
    }

    private func generateMetrics() -> [AnalyticsMetric] {
        return [
            // Performance metrics
            AnalyticsMetric(
                name: "Job Completion Rate",
                description: "Percentage of scheduled jobs completed on time",
                value: 94.5,
                change: 2.3,
                changeType: .increase,
                unit: "%",
                target: 95.0,
                category: .performance
            ),
            AnalyticsMetric(
                name: "Average Service Time",
                description: "Average time spent per service call",
                value: 45,
                change: -3.2,
                changeType: .decrease,
                unit: "min",
                target: 40,
                category: .performance
            ),

            // Productivity metrics
            AnalyticsMetric(
                name: "Jobs per Day",
                description: "Average number of jobs completed per day",
                value: 8.5,
                change: 15.2,
                changeType: .increase,
                unit: "",
                target: 10.0,
                category: .productivity
            ),
            AnalyticsMetric(
                name: "Travel Efficiency",
                description: "Percentage of time spent on productive activities",
                value: 78.2,
                change: 4.7,
                changeType: .increase,
                unit: "%",
                target: 80.0,
                category: .productivity
            ),

            // Customer metrics
            AnalyticsMetric(
                name: "Customer Retention",
                description: "Percentage of customers using service repeatedly",
                value: 87.3,
                change: 1.8,
                changeType: .increase,
                unit: "%",
                target: 90.0,
                category: .customer
            ),
            AnalyticsMetric(
                name: "Response Time",
                description: "Average time to respond to customer requests",
                value: 2.3,
                change: -0.7,
                changeType: .decrease,
                unit: "hours",
                target: 2.0,
                category: .customer
            ),

            // Financial metrics
            AnalyticsMetric(
                name: "Revenue per Job",
                description: "Average revenue generated per completed job",
                value: 150,
                change: 7.1,
                changeType: .increase,
                unit: "$",
                target: 160,
                category: .financial
            ),
            AnalyticsMetric(
                name: "Cost Efficiency",
                description: "Ratio of revenue to operational costs",
                value: 3.2,
                change: 0.3,
                changeType: .increase,
                unit: "",
                target: 3.5,
                category: .financial
            )
        ]
    }

    private func generateInsights() {
        insights = [
            AnalyticsInsight(
                type: .achievement,
                priority: .medium,
                title: "Strong Performance This Month",
                description: "You've exceeded your monthly job completion target by 15%.",
                recommendations: [
                    "Consider taking on additional routes",
                    "Share your efficiency techniques with the team"
                ]
            ),
            AnalyticsInsight(
                type: .opportunity,
                priority: .high,
                title: "Revenue Growth Opportunity",
                description: "Your average service time has decreased, allowing for more jobs per day.",
                recommendations: [
                    "Request additional jobs in your area",
                    "Consider offering premium services",
                    "Focus on customer retention strategies"
                ]
            ),
            AnalyticsInsight(
                type: .warning,
                priority: .medium,
                title: "Customer Satisfaction Dip",
                description: "There's been a slight decrease in customer satisfaction ratings this week.",
                recommendations: [
                    "Review recent customer feedback",
                    "Ensure thorough job completion",
                    "Follow up with recent customers"
                ]
            ),
            AnalyticsInsight(
                type: .suggestion,
                priority: .low,
                title: "Travel Route Optimization",
                description: "Your travel efficiency could be improved by 5% with better route planning.",
                recommendations: [
                    "Use route optimization tools",
                    "Group nearby jobs together",
                    "Plan routes the night before"
                ]
            )
        ]
    }

    private func generateGoals() {
        goals = [
            PerformanceGoal(
                name: "Monthly Revenue Target",
                currentValue: 27750,
                targetValue: 30000,
                unit: "$",
                deadline: Calendar.current.date(byAdding: .day, value: 5, to: Date())
            ),
            PerformanceGoal(
                name: "Customer Satisfaction Goal",
                currentValue: 4.5,
                targetValue: 4.7,
                unit: "",
                deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())
            ),
            PerformanceGoal(
                name: "Quarterly Job Completion",
                currentValue: 520,
                targetValue: 600,
                unit: "",
                deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())
            ),
            PerformanceGoal(
                name: "Efficiency Improvement",
                currentValue: 78.0,
                targetValue: 85.0,
                unit: "%",
                deadline: Calendar.current.date(byAdding: .month, value: 2, to: Date())
            )
        ]
    }
}

// MARK: - Preview

#Preview("Analytics Dashboard") {
    AnalyticsDashboardView()
}

#Preview("Analytics Dark Mode") {
    AnalyticsDashboardView()
        .preferredColorScheme(.dark)
}