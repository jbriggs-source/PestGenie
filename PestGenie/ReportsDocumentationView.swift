import SwiftUI

/// Reports & Documentation Center for pest control technicians.
/// Provides tools for creating, managing, and sharing service reports, documentation, and compliance records.
/// Designed to streamline paperwork and ensure regulatory compliance.
struct ReportsDocumentationView: View {
    @State private var selectedTab: ReportTab = .recentReports
    @State private var showingNewReport = false
    @State private var showingFilters = false
    @State private var searchText = ""
    @StateObject private var reportsManager = ReportsManager()
    @State private var selectedReportType: ReportType = .serviceReport
    @State private var filterDateRange: DateRange = .thisWeek

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selection and filters
                VStack(spacing: 0) {
                    reportTabBar

                    if selectedTab == .recentReports {
                        filtersBar
                    }
                }

                // Content area
                Group {
                    switch selectedTab {
                    case .recentReports:
                        recentReportsView
                    case .templates:
                        templatesView
                    case .compliance:
                        complianceView
                    case .analytics:
                        analyticsView
                    }
                }
            }
            .navigationTitle("Reports & Documentation")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search reports...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingNewReport = true }) {
                            Label("New Report", systemImage: "doc.badge.plus")
                        }
                        Button(action: { exportReports() }) {
                            Label("Export Reports", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { refreshData() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewReport) {
            newReportSheet
        }
        .sheet(isPresented: $showingFilters) {
            filtersSheet
        }
        .onAppear {
            loadReports()
        }
    }

    // MARK: - Report Tab Bar

    private var reportTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ReportTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))

                            Text(tab.title)
                                .font(PestGenieDesignSystem.Typography.labelMedium)

                            if tab.badgeCount > 0 {
                                Text("\(tab.badgeCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PestGenieDesignSystem.Colors.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == tab ? PestGenieDesignSystem.Colors.primary : PestGenieDesignSystem.Colors.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? PestGenieDesignSystem.Colors.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .background(PestGenieDesignSystem.Colors.surface)
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Filters Bar

    private var filtersBar: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Date range filter
            Menu {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Button(action: {
                        filterDateRange = range
                        filterReports()
                    }) {
                        HStack {
                            Text(range.displayName)
                            if filterDateRange == range {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Image(systemName: "calendar")
                    Text(filterDateRange.displayName)
                    Image(systemName: "chevron.down")
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                .background(PestGenieDesignSystem.Colors.surface)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            // Report type filter
            Menu {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedReportType = type
                        filterReports()
                    }) {
                        HStack {
                            Text(type.displayName)
                            if selectedReportType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Image(systemName: selectedReportType.icon)
                    Text(selectedReportType.displayName)
                    Image(systemName: "chevron.down")
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .padding(.horizontal, PestGenieDesignSystem.Spacing.sm)
                .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
                .background(PestGenieDesignSystem.Colors.surface)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
            }

            Spacer()

            // More filters button
            Button(action: {
                showingFilters = true
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18))
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .background(PestGenieDesignSystem.Colors.backgroundSecondary)
    }

    // MARK: - Recent Reports View

    private var recentReportsView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                // Quick stats
                quickStatsSection

                // Reports list
                ForEach(filteredReports) { report in
                    reportCard(report)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var quickStatsSection: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.md) {
            statCard(title: "This Week", value: "\(reportsManager.weeklyReportCount)", icon: "calendar.badge.checkmark", color: PestGenieDesignSystem.Colors.success)

            statCard(title: "Pending", value: "\(reportsManager.pendingReportCount)", icon: "clock.badge.exclamationmark", color: PestGenieDesignSystem.Colors.warning)

            statCard(title: "Overdue", value: "\(reportsManager.overdueReportCount)", icon: "exclamationmark.triangle", color: PestGenieDesignSystem.Colors.error)
        }
        .padding(.bottom, PestGenieDesignSystem.Spacing.md)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(PestGenieDesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
    }

    private func reportCard(_ report: ServiceReport) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(report.customerName)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(report.serviceAddress)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    statusBadge(report.status)

                    Text(report.serviceDate, style: .date)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                }
            }

            // Report details
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                reportDetailItem(icon: report.type.icon, label: report.type.displayName, value: "", color: report.type.color)

                Divider()
                    .frame(height: 30)

                reportDetailItem(icon: "clock", label: "Duration", value: "\(report.duration) min", color: PestGenieDesignSystem.Colors.info)

                Divider()
                    .frame(height: 30)

                reportDetailItem(icon: "dollarsign.circle", label: "Value", value: "$\(String(format: "%.0f", report.serviceValue))", color: PestGenieDesignSystem.Colors.success)
            }

            // Action buttons
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Button(action: { viewReport(report) }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Image(systemName: "eye")
                        Text("View")
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }

                Button(action: { editReport(report) }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
                }

                Button(action: { shareReport(report) }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.info)
                }

                Spacer()

                if report.requiresSignature && !report.isSigned {
                    Text("Signature Required")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.warning)
                }
            }
        }
        .pestGenieCard()
        .onTapGesture {
            viewReport(report)
        }
    }

    private func reportDetailItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            if !value.isEmpty {
                Text(value)
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            }

            Text(label)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Templates View

    private var templatesView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.md) {
                ForEach(reportsManager.reportTemplates) { template in
                    templateCard(template)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private func templateCard(_ template: ReportTemplate) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.md) {
            Image(systemName: template.icon)
                .font(.system(size: 40))
                .foregroundColor(template.color)

            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(template.name)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(template.description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: {
                createFromTemplate(template)
            }) {
                Text("Use Template")
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(template.color.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.md)
                .stroke(template.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Compliance View

    private var complianceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                // Compliance overview
                complianceOverviewSection

                // Required documents
                requiredDocumentsSection

                // Compliance checklist
                complianceChecklistSection
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var complianceOverviewSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Compliance Overview")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                complianceMetric(title: "Compliance Rate", value: "94%", color: PestGenieDesignSystem.Colors.success)
                complianceMetric(title: "Missing Docs", value: "3", color: PestGenieDesignSystem.Colors.warning)
                complianceMetric(title: "Overdue", value: "1", color: PestGenieDesignSystem.Colors.error)
            }
        }
        .pestGenieCard()
    }

    private func complianceMetric(title: String, value: String, color: Color) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
            Text(value)
                .font(PestGenieDesignSystem.Typography.displaySmall)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var requiredDocumentsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Required Documents")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(reportsManager.complianceDocuments) { document in
                complianceDocumentRow(document)
            }
        }
        .pestGenieCard()
    }

    private func complianceDocumentRow(_ document: ComplianceDocument) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: document.isCompliant ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(document.isCompliant ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.error)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                Text(document.name)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(document.description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            if let dueDate = document.dueDate {
                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text("Due")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text(dueDate, style: .date)
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(document.isOverdue ? PestGenieDesignSystem.Colors.error : PestGenieDesignSystem.Colors.textPrimary)
                }
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private var complianceChecklistSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Compliance Checklist")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(reportsManager.complianceChecklist) { item in
                checklistItemRow(item)
            }
        }
        .pestGenieCard()
    }

    private func checklistItemRow(_ item: ComplianceChecklistItem) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Button(action: {
                toggleChecklistItem(item)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isCompleted ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.textSecondary)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                Text(item.title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .strikethrough(item.isCompleted)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    // MARK: - Analytics View

    private var analyticsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                // Analytics overview
                analyticsOverviewSection

                // Performance metrics
                performanceMetricsSection

                // Trends chart placeholder
                trendsChartSection
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var analyticsOverviewSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Performance Analytics")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                analyticsCard(title: "Reports This Month", value: "24", trend: "+12%", trendColor: PestGenieDesignSystem.Colors.success)
                analyticsCard(title: "Avg. Completion Time", value: "18 min", trend: "-5%", trendColor: PestGenieDesignSystem.Colors.success)
                analyticsCard(title: "Customer Satisfaction", value: "4.8", trend: "+0.3", trendColor: PestGenieDesignSystem.Colors.success)
                analyticsCard(title: "Revenue Generated", value: "$2,850", trend: "+8%", trendColor: PestGenieDesignSystem.Colors.success)
            }
        }
        .pestGenieCard()
    }

    private func analyticsCard(title: String, value: String, trend: String, trendColor: Color) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            Text(title)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            Text(value)
                .font(PestGenieDesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                Image(systemName: trend.hasPrefix("+") ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10))
                Text(trend)
                    .font(PestGenieDesignSystem.Typography.caption)
            }
            .foregroundColor(trendColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }

    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Key Performance Indicators")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                performanceMetricRow(title: "Report Completion Rate", value: 0.94, target: 0.95)
                performanceMetricRow(title: "On-Time Delivery", value: 0.88, target: 0.90)
                performanceMetricRow(title: "Documentation Quality", value: 0.92, target: 0.85)
            }
        }
        .pestGenieCard()
    }

    private func performanceMetricRow(title: String, value: Double, target: Double) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            HStack {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(value >= target ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.warning)
            }

            ProgressView(value: value)
                .progressViewStyle(LinearProgressViewStyle(tint: value >= target ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.warning))
                .background(PestGenieDesignSystem.Colors.surface)

            Text("Target: \(Int(target * 100))%")
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
    }

    private var trendsChartSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Report Trends")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            // Placeholder for chart
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.surface)
                .frame(height: 200)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
                .overlay(
                    VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)

                        Text("Chart visualization would appear here")
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                )
        }
        .pestGenieCard()
    }

    // MARK: - Helper Views

    private func statusBadge(_ status: ReportStatus) -> some View {
        Text(status.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(.white)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(status.color)
            .clipShape(Capsule())
    }

    // MARK: - Sheets

    private var newReportSheet: some View {
        NavigationStack {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Create New Report")
                    .font(PestGenieDesignSystem.Typography.headlineLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                // Report type selection would go here
                Text("Report creation form would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNewReport = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        // Create report logic
                        showingNewReport = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var filtersSheet: some View {
        NavigationStack {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Advanced Filters")
                    .font(PestGenieDesignSystem.Typography.headlineLarge)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                // Filter options would go here
                Text("Advanced filter options would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        showingFilters = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredReports: [ServiceReport] {
        var reports = reportsManager.reports

        if !searchText.isEmpty {
            reports = reports.filter { report in
                report.customerName.localizedCaseInsensitiveContains(searchText) ||
                report.serviceAddress.localizedCaseInsensitiveContains(searchText) ||
                report.type.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply date range filter
        let calendar = Calendar.current
        let now = Date()

        switch filterDateRange {
        case .today:
            reports = reports.filter { calendar.isDate($0.serviceDate, inSameDayAs: now) }
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            reports = reports.filter { $0.serviceDate >= startOfWeek }
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            reports = reports.filter { $0.serviceDate >= startOfMonth }
        case .all:
            break
        }

        return reports.sorted { $0.serviceDate > $1.serviceDate }
    }

    // MARK: - Actions

    private func loadReports() {
        reportsManager.loadData()
    }

    private func refreshData() {
        reportsManager.refresh()
    }

    private func filterReports() {
        // Filter logic is handled by computed property
    }

    private func resetFilters() {
        filterDateRange = .thisWeek
        selectedReportType = .serviceReport
        searchText = ""
    }

    private func applyFilters() {
        // Apply custom filters
    }

    private func exportReports() {
        // Export logic
        print("Exporting reports...")
    }

    private func viewReport(_ report: ServiceReport) {
        print("Viewing report for \(report.customerName)")
    }

    private func editReport(_ report: ServiceReport) {
        print("Editing report for \(report.customerName)")
    }

    private func shareReport(_ report: ServiceReport) {
        print("Sharing report for \(report.customerName)")
    }

    private func createFromTemplate(_ template: ReportTemplate) {
        print("Creating report from template: \(template.name)")
    }

    private func toggleChecklistItem(_ item: ComplianceChecklistItem) {
        reportsManager.toggleChecklistItem(item)
    }
}

// MARK: - Supporting Types and Data Models

enum ReportTab: String, CaseIterable {
    case recentReports = "recent"
    case templates = "templates"
    case compliance = "compliance"
    case analytics = "analytics"

    var title: String {
        switch self {
        case .recentReports: return "Recent"
        case .templates: return "Templates"
        case .compliance: return "Compliance"
        case .analytics: return "Analytics"
        }
    }

    var icon: String {
        switch self {
        case .recentReports: return "doc.text.fill"
        case .templates: return "doc.badge.plus"
        case .compliance: return "checkmark.shield.fill"
        case .analytics: return "chart.bar.fill"
        }
    }

    var badgeCount: Int {
        switch self {
        case .recentReports: return 0
        case .templates: return 0
        case .compliance: return 3
        case .analytics: return 0
        }
    }
}

enum ReportType: String, CaseIterable {
    case serviceReport = "service"
    case inspection = "inspection"
    case treatment = "treatment"
    case followUp = "follow_up"
    case incident = "incident"

    var displayName: String {
        switch self {
        case .serviceReport: return "Service Report"
        case .inspection: return "Inspection"
        case .treatment: return "Treatment"
        case .followUp: return "Follow-up"
        case .incident: return "Incident"
        }
    }

    var icon: String {
        switch self {
        case .serviceReport: return "doc.text"
        case .inspection: return "magnifyingglass"
        case .treatment: return "drop.fill"
        case .followUp: return "arrow.clockwise"
        case .incident: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .serviceReport: return PestGenieDesignSystem.Colors.primary
        case .inspection: return PestGenieDesignSystem.Colors.info
        case .treatment: return PestGenieDesignSystem.Colors.success
        case .followUp: return PestGenieDesignSystem.Colors.accent
        case .incident: return PestGenieDesignSystem.Colors.error
        }
    }
}

enum ReportStatus: String, CaseIterable {
    case draft = "draft"
    case completed = "completed"
    case signed = "signed"
    case submitted = "submitted"

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .completed: return "Completed"
        case .signed: return "Signed"
        case .submitted: return "Submitted"
        }
    }

    var color: Color {
        switch self {
        case .draft: return PestGenieDesignSystem.Colors.warning
        case .completed: return PestGenieDesignSystem.Colors.info
        case .signed: return PestGenieDesignSystem.Colors.accent
        case .submitted: return PestGenieDesignSystem.Colors.success
        }
    }
}

enum DateRange: String, CaseIterable {
    case today = "today"
    case thisWeek = "week"
    case thisMonth = "month"
    case all = "all"

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .all: return "All Time"
        }
    }
}

struct ServiceReport: Identifiable {
    let id = UUID()
    let customerName: String
    let serviceAddress: String
    let type: ReportType
    let status: ReportStatus
    let serviceDate: Date
    let duration: Int
    let serviceValue: Double
    let requiresSignature: Bool
    let isSigned: Bool
}

struct ReportTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let type: ReportType
}

struct ComplianceDocument: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let isCompliant: Bool
    let dueDate: Date?

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date()
    }
}

struct ComplianceChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    var isCompleted: Bool
}

// MARK: - Reports Manager

class ReportsManager: ObservableObject {
    @Published var reports: [ServiceReport] = []
    @Published var reportTemplates: [ReportTemplate] = []
    @Published var complianceDocuments: [ComplianceDocument] = []
    @Published var complianceChecklist: [ComplianceChecklistItem] = []

    var weeklyReportCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return reports.filter { $0.serviceDate >= startOfWeek }.count
    }

    var pendingReportCount: Int {
        reports.filter { $0.status == .draft || $0.status == .completed }.count
    }

    var overdueReportCount: Int {
        reports.filter { report in
            let daysSinceService = Calendar.current.dateComponents([.day], from: report.serviceDate, to: Date()).day ?? 0
            return daysSinceService > 2 && (report.status == .draft || report.status == .completed)
        }.count
    }

    func loadData() {
        loadMockData()
    }

    func refresh() {
        loadData()
    }

    func toggleChecklistItem(_ item: ComplianceChecklistItem) {
        if let index = complianceChecklist.firstIndex(where: { $0.id == item.id }) {
            complianceChecklist[index].isCompleted.toggle()
        }
    }

    private func loadMockData() {
        // Mock reports data
        reports = [
            ServiceReport(
                customerName: "Johnson Residence",
                serviceAddress: "123 Oak Street, Springfield",
                type: .serviceReport,
                status: .completed,
                serviceDate: Date().addingTimeInterval(-86400),
                duration: 45,
                serviceValue: 150.0,
                requiresSignature: true,
                isSigned: false
            ),
            ServiceReport(
                customerName: "Chen Family",
                serviceAddress: "456 Pine Avenue, Springfield",
                type: .inspection,
                status: .signed,
                serviceDate: Date().addingTimeInterval(-172800),
                duration: 30,
                serviceValue: 75.0,
                requiresSignature: true,
                isSigned: true
            ),
            ServiceReport(
                customerName: "Davis Property",
                serviceAddress: "789 Maple Drive, Springfield",
                type: .treatment,
                status: .submitted,
                serviceDate: Date().addingTimeInterval(-259200),
                duration: 60,
                serviceValue: 200.0,
                requiresSignature: false,
                isSigned: false
            )
        ]

        // Mock templates
        reportTemplates = [
            ReportTemplate(
                name: "Standard Service",
                description: "Regular pest control service report",
                icon: "doc.text",
                color: PestGenieDesignSystem.Colors.primary,
                type: .serviceReport
            ),
            ReportTemplate(
                name: "Property Inspection",
                description: "Comprehensive property inspection form",
                icon: "magnifyingglass",
                color: PestGenieDesignSystem.Colors.info,
                type: .inspection
            ),
            ReportTemplate(
                name: "Treatment Report",
                description: "Chemical treatment documentation",
                icon: "drop.fill",
                color: PestGenieDesignSystem.Colors.success,
                type: .treatment
            ),
            ReportTemplate(
                name: "Incident Report",
                description: "Safety incident documentation",
                icon: "exclamationmark.triangle",
                color: PestGenieDesignSystem.Colors.error,
                type: .incident
            )
        ]

        // Mock compliance documents
        complianceDocuments = [
            ComplianceDocument(
                name: "Pesticide Application License",
                description: "Valid state pesticide applicator license",
                isCompliant: true,
                dueDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())
            ),
            ComplianceDocument(
                name: "Insurance Certificate",
                description: "General liability insurance certificate",
                isCompliant: true,
                dueDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())
            ),
            ComplianceDocument(
                name: "Safety Training Records",
                description: "Annual safety training completion",
                isCompliant: false,
                dueDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            )
        ]

        // Mock compliance checklist
        complianceChecklist = [
            ComplianceChecklistItem(
                title: "Vehicle inspection completed",
                description: "Daily vehicle and equipment safety check",
                isCompleted: true
            ),
            ComplianceChecklistItem(
                title: "Chemical inventory updated",
                description: "Update chemical usage and inventory logs",
                isCompleted: false
            ),
            ComplianceChecklistItem(
                title: "Safety equipment checked",
                description: "Verify all PPE is in good condition",
                isCompleted: true
            ),
            ComplianceChecklistItem(
                title: "Route documentation complete",
                description: "All service reports filed for today's route",
                isCompleted: false
            )
        ]
    }
}

// MARK: - Preview

#Preview("Reports & Documentation") {
    ReportsDocumentationView()
}

#Preview("Reports Dark Mode") {
    ReportsDocumentationView()
        .preferredColorScheme(.dark)
}