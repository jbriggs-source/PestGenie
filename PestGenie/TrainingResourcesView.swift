import SwiftUI

/// Training & Resources Center for pest control technicians.
/// Provides access to training materials, certification tracking, safety resources, and knowledge base.
/// Designed to support continuous learning and professional development.
struct TrainingResourcesView: View {
    @State private var selectedTab: TrainingTab = .courses
    @State private var showingCourseDetails = false
    @State private var showingCertificationDetails = false
    @State private var selectedCourse: TrainingCourse?
    @State private var selectedCertification: TrainingCertification?
    @State private var searchText = ""
    @StateObject private var trainingManager = TrainingManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress overview banner
                if selectedTab == .courses {
                    progressOverviewBanner
                }

                // Tab selection
                trainingTabBar

                // Content area
                Group {
                    switch selectedTab {
                    case .courses:
                        coursesView
                    case .certifications:
                        certificationsView
                    case .safety:
                        safetyResourcesView
                    case .library:
                        knowledgeLibraryView
                    }
                }
            }
            .navigationTitle("Training & Resources")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search training materials...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { downloadForOffline() }) {
                            Label("Download for Offline", systemImage: "arrow.down.circle")
                        }
                        Button(action: { viewMyProgress() }) {
                            Label("My Progress", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        Button(action: { refreshContent() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCourseDetails) {
            if let course = selectedCourse {
                courseDetailsSheet(course)
            }
        }
        .sheet(isPresented: $showingCertificationDetails) {
            if let certification = selectedCertification {
                certificationDetailsSheet(certification)
            }
        }
        .onAppear {
            loadTrainingData()
        }
    }

    // MARK: - Progress Overview Banner

    private var progressOverviewBanner: some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text("Your Progress")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text("\(trainingManager.completedCoursesCount) of \(trainingManager.totalCoursesCount) courses completed")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                ProgressView(value: trainingManager.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.success))
                    .background(PestGenieDesignSystem.Colors.surface)
            }

            Spacer()

            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Text("\(Int(trainingManager.overallProgress * 100))%")
                    .font(PestGenieDesignSystem.Typography.displaySmall)
                    .fontWeight(.bold)
                    .foregroundColor(PestGenieDesignSystem.Colors.success)

                Text("Complete")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    PestGenieDesignSystem.Colors.success.opacity(0.1),
                    PestGenieDesignSystem.Colors.surface
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Training Tab Bar

    private var trainingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TrainingTab.allCases, id: \.self) { tab in
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

    // MARK: - Courses View

    private var coursesView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Quick access section
                quickAccessSection

                // Featured courses
                featuredCoursesSection

                // All courses
                allCoursesSection
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Quick Access")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                quickAccessButton(
                    title: "Continue Learning",
                    subtitle: "Resume current course",
                    icon: "play.circle.fill",
                    color: PestGenieDesignSystem.Colors.success
                ) {
                    continueCurrentCourse()
                }

                quickAccessButton(
                    title: "Safety Refresher",
                    subtitle: "Quick safety review",
                    icon: "shield.checkered",
                    color: PestGenieDesignSystem.Colors.warning
                ) {
                    startSafetyRefresher()
                }

                quickAccessButton(
                    title: "New Updates",
                    subtitle: "Latest training materials",
                    icon: "star.circle.fill",
                    color: PestGenieDesignSystem.Colors.accent
                ) {
                    viewNewUpdates()
                }

                quickAccessButton(
                    title: "My Certificates",
                    subtitle: "View achievements",
                    icon: "award.fill",
                    color: PestGenieDesignSystem.Colors.primary
                ) {
                    selectedTab = .certifications
                }
            }
        }
        .pestGenieCard()
    }

    private func quickAccessButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(title)
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PestGenieDesignSystem.Spacing.md)
            .background(color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .buttonStyle(.plain)
    }

    private var featuredCoursesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Text("Featured Courses")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button("View All") {
                    // View all featured courses
                }
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    ForEach(trainingManager.featuredCourses) { course in
                        featuredCourseCard(course)
                    }
                }
                .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            }
        }
    }

    private func featuredCourseCard(_ course: TrainingCourse) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            // Course image placeholder
            Rectangle()
                .fill(course.category.color.opacity(0.3))
                .frame(width: 280, height: 140)
                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
                .overlay(
                    VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Image(systemName: course.category.icon)
                            .font(.system(size: 32))
                            .foregroundColor(course.category.color)

                        if course.isNew {
                            Text("NEW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(PestGenieDesignSystem.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }
                )

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(course.title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                Text(course.description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(3)

                HStack {
                    difficultyBadge(course.difficulty)

                    Spacer()

                    Text("\(course.duration) min")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                if course.progress > 0 {
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                        HStack {
                            Text("Progress")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                            Spacer()

                            Text("\(Int(course.progress * 100))%")
                                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                                .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        }

                        ProgressView(value: course.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.primary))
                            .background(PestGenieDesignSystem.Colors.surface)
                    }
                }
            }
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
        }
        .frame(width: 280)
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .shadow(
            color: PestGenieDesignSystem.Shadows.sm.color,
            radius: PestGenieDesignSystem.Shadows.sm.radius,
            x: PestGenieDesignSystem.Shadows.sm.x,
            y: PestGenieDesignSystem.Shadows.sm.y
        )
        .onTapGesture {
            selectedCourse = course
            showingCourseDetails = true
        }
    }

    private var allCoursesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("All Courses")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(filteredCourses) { course in
                courseCard(course)
            }
        }
    }

    private func courseCard(_ course: TrainingCourse) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Course icon
                ZStack {
                    Circle()
                        .fill(course.category.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: course.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(course.category.color)
                }

                // Course details
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    HStack {
                        Text(course.title)
                            .font(PestGenieDesignSystem.Typography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        if course.isNew {
                            Text("NEW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PestGenieDesignSystem.Colors.accent)
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    Text(course.description)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                        difficultyBadge(course.difficulty)

                        Text("•")
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)

                        Text("\(course.duration) min")
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                        Spacer()

                        if course.isCompleted {
                            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(PestGenieDesignSystem.Colors.success)
                                Text("Completed")
                                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                                    .foregroundColor(PestGenieDesignSystem.Colors.success)
                            }
                        } else if course.progress > 0 {
                            Text("\(Int(course.progress * 100))% complete")
                                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                                .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        }
                    }
                }
            }

            if course.progress > 0 && !course.isCompleted {
                ProgressView(value: course.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.primary))
                    .background(PestGenieDesignSystem.Colors.surface)
            }
        }
        .pestGenieCard()
        .onTapGesture {
            selectedCourse = course
            showingCourseDetails = true
        }
    }

    // MARK: - Certifications View

    private var certificationsView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Certification overview
                certificationOverviewSection

                // Active certifications
                activeCertificationsSection

                // Available certifications
                availableCertificationsSection
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var certificationOverviewSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Certification Status")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                certificationStat(title: "Active", value: "\(trainingManager.activeCertificationsCount)", color: PestGenieDesignSystem.Colors.success)
                certificationStat(title: "Expiring Soon", value: "\(trainingManager.expiringSoonCount)", color: PestGenieDesignSystem.Colors.warning)
                certificationStat(title: "Available", value: "\(trainingManager.availableCertificationsCount)", color: PestGenieDesignSystem.Colors.info)
            }
        }
        .pestGenieCard()
    }

    private func certificationStat(title: String, value: String, color: Color) -> some View {
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

    private var activeCertificationsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Your Certifications")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(trainingManager.activeCertifications) { certification in
                certificationCard(certification)
            }
        }
    }

    private var availableCertificationsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Available Certifications")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(trainingManager.availableCertifications) { certification in
                certificationCard(certification)
            }
        }
    }

    private func certificationCard(_ certification: TrainingCertification) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Certification badge
                ZStack {
                    Circle()
                        .fill(certification.isActive ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.surface)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(certification.isActive ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.border, lineWidth: 2)
                        )

                    Image(systemName: certification.isActive ? "checkmark.seal.fill" : "seal")
                        .font(.system(size: 24))
                        .foregroundColor(certification.isActive ? .white : PestGenieDesignSystem.Colors.textSecondary)
                }

                // Certification details
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(certification.name)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(certification.issuingOrganization)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    if certification.isActive {
                        if let expirationDate = certification.expirationDate {
                            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                                Image(systemName: "calendar")
                                    .foregroundColor(certification.isExpiringSoon ? PestGenieDesignSystem.Colors.warning : PestGenieDesignSystem.Colors.textSecondary)
                                Text("Expires \(expirationDate, style: .date)")
                                    .font(PestGenieDesignSystem.Typography.caption)
                                    .foregroundColor(certification.isExpiringSoon ? PestGenieDesignSystem.Colors.warning : PestGenieDesignSystem.Colors.textSecondary)
                            }
                        }
                    } else {
                        Text("Available to earn")
                            .font(PestGenieDesignSystem.Typography.captionEmphasis)
                            .foregroundColor(PestGenieDesignSystem.Colors.accent)
                    }
                }

                Spacer()

                // Action button
                if certification.isActive {
                    if certification.isExpiringSoon {
                        Button("Renew") {
                            renewCertification(certification)
                        }
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.warning)
                    } else {
                        Button("View") {
                            selectedCertification = certification
                            showingCertificationDetails = true
                        }
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                } else {
                    Button("Start") {
                        startCertification(certification)
                    }
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
                }
            }
        }
        .pestGenieCard()
    }

    // MARK: - Safety Resources View

    private var safetyResourcesView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Emergency procedures
                emergencyProceduresSection

                // Safety guidelines
                safetyGuidelinesSection

                // Incident reporting
                incidentReportingSection
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var emergencyProceduresSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(PestGenieDesignSystem.Colors.error)
                Text("Emergency Procedures")
                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                emergencyCard(title: "Chemical Exposure", icon: "drop.triangle", description: "Immediate response steps")
                emergencyCard(title: "Equipment Failure", icon: "wrench.and.screwdriver", description: "Safety protocols")
                emergencyCard(title: "Medical Emergency", icon: "cross.circle", description: "First aid procedures")
                emergencyCard(title: "Evacuation", icon: "figure.run", description: "Emergency exit routes")
            }
        }
        .pestGenieCard()
    }

    private func emergencyCard(title: String, icon: String, description: String) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(PestGenieDesignSystem.Colors.error)

            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(PestGenieDesignSystem.Colors.error.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        .onTapGesture {
            viewEmergencyProcedure(title)
        }
    }

    private var safetyGuidelinesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Safety Guidelines")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(trainingManager.safetyGuidelines) { guideline in
                safetyGuidelineRow(guideline)
            }
        }
        .pestGenieCard()
    }

    private func safetyGuidelineRow(_ guideline: SafetyGuideline) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: guideline.icon)
                .foregroundColor(guideline.priority.color)
                .font(.system(size: 20))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(guideline.title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(guideline.description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            priorityBadge(guideline.priority)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .onTapGesture {
            viewSafetyGuideline(guideline)
        }
    }

    private var incidentReportingSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Incident Reporting")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Button(action: { reportIncident() }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(PestGenieDesignSystem.Colors.error)

                        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                            Text("Report an Incident")
                                .font(PestGenieDesignSystem.Typography.titleSmall)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            Text("Immediate incident reporting")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                    }
                    .padding(PestGenieDesignSystem.Spacing.md)
                    .background(PestGenieDesignSystem.Colors.error.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
                }
                .buttonStyle(.plain)

                Button(action: { viewReportHistory() }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                        Image(systemName: "doc.text")
                            .foregroundColor(PestGenieDesignSystem.Colors.info)

                        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                            Text("View Report History")
                                .font(PestGenieDesignSystem.Typography.titleSmall)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            Text("Previous incident reports")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                    }
                    .padding(PestGenieDesignSystem.Spacing.md)
                    .background(PestGenieDesignSystem.Colors.info.opacity(0.1))
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Knowledge Library View

    private var knowledgeLibraryView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.md) {
                // Search and filter bar
                librarySearchSection

                // Categories
                libraryCategoriesSection

                // Recent resources
                recentResourcesSection
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var librarySearchSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            Text("Knowledge Library")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Text("Access technical guides, pest identification, and treatment protocols")
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pestGenieCard()
    }

    private var libraryCategoriesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Browse by Category")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(trainingManager.libraryCategories) { category in
                    libraryCategoryCard(category)
                }
            }
        }
        .pestGenieCard()
    }

    private func libraryCategoryCard(_ category: LibraryCategory) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundColor(category.color)

            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(category.name)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("\(category.resourceCount) resources")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(category.color.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .onTapGesture {
            browseCategory(category)
        }
    }

    private var recentResourcesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Recently Added")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            ForEach(trainingManager.recentResources) { resource in
                knowledgeResourceRow(resource)
            }
        }
        .pestGenieCard()
    }

    private func knowledgeResourceRow(_ resource: KnowledgeResource) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: resource.type.icon)
                .foregroundColor(resource.type.color)
                .font(.system(size: 20))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(resource.title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Text(resource.type.displayName)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)

                    Text(resource.addedDate, style: .relative)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            if resource.isNew {
                Text("NEW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PestGenieDesignSystem.Colors.accent)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                .font(.system(size: 12))
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .onTapGesture {
            viewResource(resource)
        }
    }

    // MARK: - Helper Views

    private func difficultyBadge(_ difficulty: CourseDifficulty) -> some View {
        Text(difficulty.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(difficulty.color)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(difficulty.color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func priorityBadge(_ priority: SafetyPriority) -> some View {
        Text(priority.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(.white)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(priority.color)
            .clipShape(Capsule())
    }

    // MARK: - Sheets

    private func courseDetailsSheet(_ course: TrainingCourse) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    // Course header
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                        Text(course.title)
                            .font(PestGenieDesignSystem.Typography.headlineLarge)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                        Text(course.description)
                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                        HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                            difficultyBadge(course.difficulty)
                            Text("\(course.duration) minutes")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        }
                    }

                    // Progress section
                    if course.progress > 0 {
                        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                            Text("Your Progress")
                                .font(PestGenieDesignSystem.Typography.headlineSmall)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            ProgressView(value: course.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.primary))
                                .background(PestGenieDesignSystem.Colors.surface)

                            Text("\(Int(course.progress * 100))% complete")
                                .font(PestGenieDesignSystem.Typography.caption)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        }
                        .pestGenieCard()
                    }

                    // Course content would go here
                    Text("Course content and modules would be displayed here")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(PestGenieDesignSystem.Spacing.xl)

                    Spacer()
                }
                .padding(PestGenieDesignSystem.Spacing.md)
            }
            .navigationTitle("Course Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        showingCourseDetails = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(course.progress > 0 ? "Continue" : "Start") {
                        startCourse(course)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func certificationDetailsSheet(_ certification: TrainingCertification) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                    Text("Certification details would be displayed here")
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(PestGenieDesignSystem.Spacing.xl)

                    Spacer()
                }
                .padding(PestGenieDesignSystem.Spacing.md)
            }
            .navigationTitle(certification.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingCertificationDetails = false
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredCourses: [TrainingCourse] {
        if searchText.isEmpty {
            return trainingManager.allCourses
        } else {
            return trainingManager.allCourses.filter { course in
                course.title.localizedCaseInsensitiveContains(searchText) ||
                course.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func loadTrainingData() {
        trainingManager.loadData()
    }

    private func refreshContent() {
        trainingManager.refresh()
    }

    private func downloadForOffline() {
        print("Downloading content for offline access...")
    }

    private func viewMyProgress() {
        print("Viewing training progress...")
    }

    private func continueCurrentCourse() {
        print("Continuing current course...")
    }

    private func startSafetyRefresher() {
        print("Starting safety refresher...")
    }

    private func viewNewUpdates() {
        print("Viewing new training updates...")
    }

    private func startCourse(_ course: TrainingCourse) {
        print("Starting course: \(course.title)")
        showingCourseDetails = false
    }

    private func renewCertification(_ certification: TrainingCertification) {
        print("Renewing certification: \(certification.name)")
    }

    private func startCertification(_ certification: TrainingCertification) {
        print("Starting certification: \(certification.name)")
    }

    private func viewEmergencyProcedure(_ procedure: String) {
        print("Viewing emergency procedure: \(procedure)")
    }

    private func viewSafetyGuideline(_ guideline: SafetyGuideline) {
        print("Viewing safety guideline: \(guideline.title)")
    }

    private func reportIncident() {
        print("Reporting incident...")
    }

    private func viewReportHistory() {
        print("Viewing incident report history...")
    }

    private func browseCategory(_ category: LibraryCategory) {
        print("Browsing category: \(category.name)")
    }

    private func viewResource(_ resource: KnowledgeResource) {
        print("Viewing resource: \(resource.title)")
    }
}

// MARK: - Supporting Types and Enums

enum TrainingTab: String, CaseIterable {
    case courses = "courses"
    case certifications = "certifications"
    case safety = "safety"
    case library = "library"

    var title: String {
        switch self {
        case .courses: return "Courses"
        case .certifications: return "Certificates"
        case .safety: return "Safety"
        case .library: return "Library"
        }
    }

    var icon: String {
        switch self {
        case .courses: return "play.rectangle.fill"
        case .certifications: return "award.fill"
        case .safety: return "shield.checkered"
        case .library: return "books.vertical.fill"
        }
    }

    var badgeCount: Int {
        switch self {
        case .courses: return 2
        case .certifications: return 1
        case .safety: return 0
        case .library: return 3
        }
    }
}

enum CourseDifficulty: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return PestGenieDesignSystem.Colors.success
        case .intermediate: return PestGenieDesignSystem.Colors.warning
        case .advanced: return PestGenieDesignSystem.Colors.error
        }
    }
}

enum CourseCategory: String, CaseIterable {
    case pestIdentification = "pest_id"
    case treatmentMethods = "treatment"
    case safety = "safety"
    case regulations = "regulations"
    case equipment = "equipment"

    var displayName: String {
        switch self {
        case .pestIdentification: return "Pest Identification"
        case .treatmentMethods: return "Treatment Methods"
        case .safety: return "Safety"
        case .regulations: return "Regulations"
        case .equipment: return "Equipment"
        }
    }

    var icon: String {
        switch self {
        case .pestIdentification: return "ant.fill"
        case .treatmentMethods: return "drop.fill"
        case .safety: return "shield.checkered"
        case .regulations: return "book.closed"
        case .equipment: return "wrench.and.screwdriver"
        }
    }

    var color: Color {
        switch self {
        case .pestIdentification: return PestGenieDesignSystem.Colors.secondary
        case .treatmentMethods: return PestGenieDesignSystem.Colors.success
        case .safety: return PestGenieDesignSystem.Colors.error
        case .regulations: return PestGenieDesignSystem.Colors.info
        case .equipment: return PestGenieDesignSystem.Colors.primary
        }
    }
}

enum SafetyPriority: String, CaseIterable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .critical: return PestGenieDesignSystem.Colors.error
        case .high: return PestGenieDesignSystem.Colors.warning
        case .medium: return PestGenieDesignSystem.Colors.info
        case .low: return PestGenieDesignSystem.Colors.textSecondary
        }
    }
}

enum ResourceType: String, CaseIterable {
    case guide = "guide"
    case video = "video"
    case checklist = "checklist"
    case reference = "reference"

    var displayName: String {
        switch self {
        case .guide: return "Guide"
        case .video: return "Video"
        case .checklist: return "Checklist"
        case .reference: return "Reference"
        }
    }

    var icon: String {
        switch self {
        case .guide: return "doc.text"
        case .video: return "play.rectangle"
        case .checklist: return "checkmark.square"
        case .reference: return "book"
        }
    }

    var color: Color {
        switch self {
        case .guide: return PestGenieDesignSystem.Colors.info
        case .video: return PestGenieDesignSystem.Colors.accent
        case .checklist: return PestGenieDesignSystem.Colors.success
        case .reference: return PestGenieDesignSystem.Colors.secondary
        }
    }
}

// MARK: - Data Models

struct TrainingCourse: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: CourseCategory
    let difficulty: CourseDifficulty
    let duration: Int
    let progress: Double
    let isCompleted: Bool
    let isNew: Bool
}

struct TrainingCertification: Identifiable {
    let id = UUID()
    let name: String
    let issuingOrganization: String
    let isActive: Bool
    let expirationDate: Date?

    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate else { return false }
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expirationDate <= thirtyDaysFromNow
    }
}

struct SafetyGuideline: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let priority: SafetyPriority
}

struct LibraryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let resourceCount: Int
}

struct KnowledgeResource: Identifiable {
    let id = UUID()
    let title: String
    let type: ResourceType
    let addedDate: Date
    let isNew: Bool
}

// MARK: - Training Manager

class TrainingManager: ObservableObject {
    @Published var allCourses: [TrainingCourse] = []
    @Published var featuredCourses: [TrainingCourse] = []
    @Published var activeCertifications: [TrainingCertification] = []
    @Published var availableCertifications: [TrainingCertification] = []
    @Published var safetyGuidelines: [SafetyGuideline] = []
    @Published var libraryCategories: [LibraryCategory] = []
    @Published var recentResources: [KnowledgeResource] = []

    var overallProgress: Double {
        guard !allCourses.isEmpty else { return 0.0 }
        let totalProgress = allCourses.reduce(0) { $0 + $1.progress }
        return totalProgress / Double(allCourses.count)
    }

    var completedCoursesCount: Int {
        allCourses.filter { $0.isCompleted }.count
    }

    var totalCoursesCount: Int {
        allCourses.count
    }

    var activeCertificationsCount: Int {
        activeCertifications.count
    }

    var expiringSoonCount: Int {
        activeCertifications.filter { $0.isExpiringSoon }.count
    }

    var availableCertificationsCount: Int {
        availableCertifications.count
    }

    func loadData() {
        loadMockData()
    }

    func refresh() {
        loadData()
    }

    private func loadMockData() {
        // Mock courses
        allCourses = [
            TrainingCourse(
                title: "Residential Pest Identification",
                description: "Learn to identify common household pests and their signs",
                category: .pestIdentification,
                difficulty: .beginner,
                duration: 30,
                progress: 0.75,
                isCompleted: false,
                isNew: false
            ),
            TrainingCourse(
                title: "Safe Chemical Application",
                description: "Proper techniques for pesticide application and safety",
                category: .safety,
                difficulty: .intermediate,
                duration: 45,
                progress: 1.0,
                isCompleted: true,
                isNew: false
            ),
            TrainingCourse(
                title: "Integrated Pest Management",
                description: "Advanced IPM strategies for commercial properties",
                category: .treatmentMethods,
                difficulty: .advanced,
                duration: 60,
                progress: 0.0,
                isCompleted: false,
                isNew: true
            ),
            TrainingCourse(
                title: "Equipment Maintenance",
                description: "Proper care and maintenance of pest control equipment",
                category: .equipment,
                difficulty: .beginner,
                duration: 25,
                progress: 0.5,
                isCompleted: false,
                isNew: false
            )
        ]

        featuredCourses = Array(allCourses.prefix(3))

        // Mock certifications
        activeCertifications = [
            TrainingCertification(
                name: "Certified Pest Control Technician",
                issuingOrganization: "National Pest Management Association",
                isActive: true,
                expirationDate: Calendar.current.date(byAdding: .month, value: 8, to: Date())
            ),
            TrainingCertification(
                name: "Commercial Pesticide Applicator",
                issuingOrganization: "State Department of Agriculture",
                isActive: true,
                expirationDate: Calendar.current.date(byAdding: .day, value: 25, to: Date())
            )
        ]

        availableCertifications = [
            TrainingCertification(
                name: "Structural Fumigation License",
                issuingOrganization: "State Structural Pest Control Board",
                isActive: false,
                expirationDate: nil
            ),
            TrainingCertification(
                name: "Integrated Pest Management Specialist",
                issuingOrganization: "IPM Institute of North America",
                isActive: false,
                expirationDate: nil
            )
        ]

        // Mock safety guidelines
        safetyGuidelines = [
            SafetyGuideline(
                title: "Personal Protective Equipment",
                description: "Always wear appropriate PPE when handling chemicals",
                icon: "shield.fill",
                priority: .critical
            ),
            SafetyGuideline(
                title: "Chemical Storage Guidelines",
                description: "Proper storage and handling of pesticide chemicals",
                icon: "cube.box",
                priority: .high
            ),
            SafetyGuideline(
                title: "Vehicle Safety Inspection",
                description: "Daily vehicle and equipment safety checks",
                icon: "car.fill",
                priority: .medium
            ),
            SafetyGuideline(
                title: "Customer Communication",
                description: "Inform customers about treatment procedures and safety",
                icon: "person.2.fill",
                priority: .medium
            )
        ]

        // Mock library categories
        libraryCategories = [
            LibraryCategory(
                name: "Pest Identification",
                icon: "ant.fill",
                color: PestGenieDesignSystem.Colors.secondary,
                resourceCount: 45
            ),
            LibraryCategory(
                name: "Treatment Protocols",
                icon: "drop.fill",
                color: PestGenieDesignSystem.Colors.success,
                resourceCount: 32
            ),
            LibraryCategory(
                name: "Safety Procedures",
                icon: "shield.checkered",
                color: PestGenieDesignSystem.Colors.error,
                resourceCount: 28
            ),
            LibraryCategory(
                name: "Equipment Guides",
                icon: "wrench.and.screwdriver",
                color: PestGenieDesignSystem.Colors.primary,
                resourceCount: 19
            ),
            LibraryCategory(
                name: "Regulations & Compliance",
                icon: "book.closed",
                color: PestGenieDesignSystem.Colors.info,
                resourceCount: 36
            ),
            LibraryCategory(
                name: "Customer Relations",
                icon: "person.2.fill",
                color: PestGenieDesignSystem.Colors.accent,
                resourceCount: 23
            )
        ]

        // Mock recent resources
        recentResources = [
            KnowledgeResource(
                title: "Updated Termite Treatment Protocols",
                type: .guide,
                addedDate: Date().addingTimeInterval(-86400),
                isNew: true
            ),
            KnowledgeResource(
                title: "Rodent Control Best Practices Video",
                type: .video,
                addedDate: Date().addingTimeInterval(-172800),
                isNew: true
            ),
            KnowledgeResource(
                title: "Chemical Safety Checklist 2024",
                type: .checklist,
                addedDate: Date().addingTimeInterval(-259200),
                isNew: true
            ),
            KnowledgeResource(
                title: "State Regulation Updates",
                type: .reference,
                addedDate: Date().addingTimeInterval(-345600),
                isNew: false
            )
        ]
    }
}

// MARK: - Preview

#Preview("Training & Resources") {
    TrainingResourcesView()
}

#Preview("Training Dark Mode") {
    TrainingResourcesView()
        .preferredColorScheme(.dark)
}