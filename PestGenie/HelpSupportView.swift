import SwiftUI

/// Help & Support Center for pest control technicians.
/// Provides comprehensive assistance, documentation, troubleshooting, and contact options.
/// Designed to help technicians resolve issues quickly and efficiently.
struct HelpSupportView: View {
    @State private var selectedCategory: HelpCategory = .gettingStarted
    @State private var searchText = ""
    @State private var showingContactForm = false
    @State private var showingFeedbackForm = false
    @State private var showingChatSupport = false
    @StateObject private var helpManager = HelpSupportManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick actions header
                quickActionsHeader

                // Category tabs
                categoryTabsView

                // Content area
                ScrollView {
                    LazyVStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                        switch selectedCategory {
                        case .gettingStarted:
                            gettingStartedContent
                        case .features:
                            featuresContent
                        case .troubleshooting:
                            troubleshootingContent
                        case .account:
                            accountContent
                        case .contact:
                            contactContent
                        }
                    }
                    .padding(PestGenieDesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search help articles...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingContactForm = true }) {
                            Label("Contact Support", systemImage: "envelope")
                        }
                        Button(action: { showingFeedbackForm = true }) {
                            Label("Send Feedback", systemImage: "star")
                        }
                        Button(action: { showingChatSupport = true }) {
                            Label("Live Chat", systemImage: "message")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingContactForm) {
            contactFormSheet
        }
        .sheet(isPresented: $showingFeedbackForm) {
            feedbackFormSheet
        }
        .sheet(isPresented: $showingChatSupport) {
            chatSupportSheet
        }
        .onAppear {
            helpManager.loadHelpData()
        }
    }

    // MARK: - Quick Actions Header

    private var quickActionsHeader: some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Need Help?")
                        .font(PestGenieDesignSystem.Typography.headlineSmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text("Find answers or get in touch with our support team")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(PestGenieDesignSystem.Colors.info)
            }

            // Quick action buttons
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                quickActionButton(
                    title: "Chat",
                    icon: "message.fill",
                    color: PestGenieDesignSystem.Colors.success
                ) {
                    showingChatSupport = true
                }

                quickActionButton(
                    title: "Call",
                    icon: "phone.fill",
                    color: PestGenieDesignSystem.Colors.accent
                ) {
                    makePhoneCall()
                }

                quickActionButton(
                    title: "Email",
                    icon: "envelope.fill",
                    color: PestGenieDesignSystem.Colors.warning
                ) {
                    showingContactForm = true
                }

                quickActionButton(
                    title: "FAQ",
                    icon: "questionmark.app.fill",
                    color: PestGenieDesignSystem.Colors.info
                ) {
                    selectedCategory = .troubleshooting
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    PestGenieDesignSystem.Colors.info.opacity(0.1),
                    PestGenieDesignSystem.Colors.surface
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(Circle())

                Text(title)
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Tabs

    private var categoryTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(HelpCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }) {
                        VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 14))
                                Text(category.displayName)
                                    .font(PestGenieDesignSystem.Typography.labelMedium)
                            }
                            .foregroundColor(selectedCategory == category ? PestGenieDesignSystem.Colors.primary : PestGenieDesignSystem.Colors.textSecondary)

                            Rectangle()
                                .fill(selectedCategory == category ? PestGenieDesignSystem.Colors.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(minWidth: 100)
                        .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
                    }
                    .buttonStyle(.plain)
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

    // MARK: - Getting Started Content

    private var gettingStartedContent: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Welcome section
            welcomeSection

            // Quick setup guides
            quickSetupSection

            // Essential features
            essentialFeaturesSection
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Welcome to PestGenie", icon: "hand.wave.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Text("PestGenie is designed to streamline your pest control operations and help you provide exceptional service to your customers.")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text("Whether you're new to the platform or need a refresher, these guides will help you get started quickly.")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                // Getting started video
                videoCard(
                    title: "PestGenie Overview",
                    duration: "5 min",
                    description: "Complete introduction to the app and its key features"
                )
            }
        }
        .pestGenieCard()
    }

    private var quickSetupSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Quick Setup Guides", icon: "gearshape.2.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                setupGuideCard(
                    title: "Profile Setup",
                    description: "Complete your technician profile",
                    icon: "person.circle",
                    estimatedTime: "2 min",
                    progress: 1.0
                )

                setupGuideCard(
                    title: "Route Configuration",
                    description: "Set up your daily routes",
                    icon: "map",
                    estimatedTime: "5 min",
                    progress: 0.6
                )

                setupGuideCard(
                    title: "Equipment Registration",
                    description: "Register your equipment",
                    icon: "wrench.and.screwdriver",
                    estimatedTime: "3 min",
                    progress: 0.3
                )

                setupGuideCard(
                    title: "App Preferences",
                    description: "Customize your settings",
                    icon: "slider.horizontal.3",
                    estimatedTime: "4 min",
                    progress: 0.0
                )
            }
        }
        .pestGenieCard()
    }

    private var essentialFeaturesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Essential Features", icon: "star.fill")

            ForEach(helpManager.essentialFeatures) { feature in
                featureRow(feature)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Features Content

    private var featuresContent: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Feature categories
            featureCategoriesSection

            // Popular features
            popularFeaturesSection

            // How-to guides
            howToGuidesSection
        }
    }

    private var featureCategoriesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Feature Categories", icon: "square.grid.2x2.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.md) {
                ForEach(helpManager.featureCategories) { category in
                    featureCategoryCard(category)
                }
            }
        }
    }

    private var popularFeaturesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Popular Features", icon: "flame.fill")

            ForEach(helpManager.popularFeatures) { feature in
                popularFeatureRow(feature)
            }
        }
        .pestGenieCard()
    }

    private var howToGuidesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("How-To Guides", icon: "book.fill")

            ForEach(helpManager.howToGuides) { guide in
                guideRow(guide)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Troubleshooting Content

    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Common issues
            commonIssuesSection

            // FAQ section
            faqSection

            // System status
            systemStatusSection
        }
    }

    private var commonIssuesSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Common Issues", icon: "exclamationmark.triangle.fill")

            ForEach(helpManager.commonIssues) { issue in
                troubleshootingCard(issue)
            }
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Frequently Asked Questions", icon: "questionmark.circle.fill")

            ForEach(helpManager.faqItems) { faq in
                faqCard(faq)
            }
        }
    }

    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("System Status", icon: "checkmark.shield.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                statusRow("App Services", status: .operational)
                statusRow("Sync Services", status: .operational)
                statusRow("Weather API", status: .maintenance)
                statusRow("Notification System", status: .operational)

                Button("View Detailed Status") {
                    openSystemStatus()
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, PestGenieDesignSystem.Spacing.sm)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Account Content

    private var accountContent: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Account information
            accountInfoSection

            // Security settings
            securitySection

            // Data management
            dataManagementSection
        }
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Account Information", icon: "person.circle.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                accountInfoRow("Full Name", "John Smith")
                accountInfoRow("Employee ID", "T-12345")
                accountInfoRow("Company", "PestControl Pro")
                accountInfoRow("Account Type", "Professional")
                accountInfoRow("Member Since", "January 2023")

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                actionButton("Update Profile", icon: "pencil") {
                    updateProfile()
                }

                actionButton("Change Password", icon: "key") {
                    changePassword()
                }
            }
        }
        .pestGenieCard()
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Security & Privacy", icon: "shield.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                securityRow("Two-Factor Authentication", isEnabled: true)
                securityRow("Biometric Login", isEnabled: false)
                securityRow("Session Timeout", isEnabled: true)

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                actionButton("Privacy Settings", icon: "eye.slash") {
                    openPrivacySettings()
                }

                actionButton("Security Checkup", icon: "checkmark.shield") {
                    runSecurityCheckup()
                }
            }
        }
        .pestGenieCard()
    }

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Data Management", icon: "externaldrive.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                dataRow("Storage Used", "1.2 GB of 5 GB")
                dataRow("Last Backup", "2 hours ago")
                dataRow("Sync Status", "Up to date")

                Divider()
                    .background(PestGenieDesignSystem.Colors.border)

                actionButton("Export Data", icon: "square.and.arrow.up") {
                    exportData()
                }

                actionButton("Delete Account", icon: "trash", color: PestGenieDesignSystem.Colors.error) {
                    deleteAccount()
                }
            }
        }
        .pestGenieCard()
    }

    // MARK: - Contact Content

    private var contactContent: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
            // Contact options
            contactOptionsSection

            // Office hours
            officeHoursSection

            // Emergency contacts
            emergencyContactsSection
        }
    }

    private var contactOptionsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Contact Support", icon: "headphones")

            VStack(spacing: PestGenieDesignSystem.Spacing.md) {
                contactOptionCard(
                    title: "Live Chat",
                    description: "Get instant help from our support team",
                    icon: "message.fill",
                    color: PestGenieDesignSystem.Colors.success,
                    availability: "Available now"
                ) {
                    showingChatSupport = true
                }

                contactOptionCard(
                    title: "Phone Support",
                    description: "Call us for immediate assistance",
                    icon: "phone.fill",
                    color: PestGenieDesignSystem.Colors.accent,
                    availability: "Mon-Fri 8AM-6PM EST"
                ) {
                    makePhoneCall()
                }

                contactOptionCard(
                    title: "Email Support",
                    description: "Send us a detailed message",
                    icon: "envelope.fill",
                    color: PestGenieDesignSystem.Colors.warning,
                    availability: "Response within 4 hours"
                ) {
                    showingContactForm = true
                }

                contactOptionCard(
                    title: "Submit Feedback",
                    description: "Share your thoughts and suggestions",
                    icon: "star.fill",
                    color: PestGenieDesignSystem.Colors.info,
                    availability: "Always open"
                ) {
                    showingFeedbackForm = true
                }
            }
        }
    }

    private var officeHoursSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Support Hours", icon: "clock.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                hourRow("Monday - Friday", "8:00 AM - 6:00 PM EST")
                hourRow("Saturday", "9:00 AM - 3:00 PM EST")
                hourRow("Sunday", "Closed")
                hourRow("Emergency Support", "24/7 Available")

                Text("We typically respond to emails within 4 hours during business hours.")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .padding(.top, PestGenieDesignSystem.Spacing.xs)
            }
        }
        .pestGenieCard()
    }

    private var emergencyContactsSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            sectionHeader("Emergency Contacts", icon: "exclamationmark.triangle.fill")

            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                emergencyContactRow(
                    title: "Emergency Hotline",
                    number: "1-800-PEST-911",
                    description: "24/7 emergency technical support"
                )

                emergencyContactRow(
                    title: "Safety Support",
                    number: "1-800-SAFE-123",
                    description: "Chemical incidents and safety concerns"
                )

                emergencyContactRow(
                    title: "IT Help Desk",
                    number: "1-800-TECH-456",
                    description: "Critical system failures"
                )

                Text("Emergency contacts are available 24/7 for urgent technical issues and safety concerns.")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .padding(.top, PestGenieDesignSystem.Spacing.xs)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
                .font(.system(size: 18))

            Text(title)
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    private func videoCard(title: String, duration: String, description: String) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.md) {
            // Video thumbnail
            ZStack {
                Rectangle()
                    .fill(PestGenieDesignSystem.Colors.primary.opacity(0.2))
                    .frame(width: 80, height: 60)
                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)

                VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        .font(.system(size: 24))

                    Text(duration)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                .font(.system(size: 12))
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        .onTapGesture {
            playVideo(title)
        }
    }

    private func setupGuideCard(
        title: String,
        description: String,
        icon: String,
        estimatedTime: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    .font(.system(size: 20))

                Spacer()

                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PestGenieDesignSystem.Colors.success)
                }
            }

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(2)

                Text(estimatedTime)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }

            if progress > 0 && progress < 1.0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: PestGenieDesignSystem.Colors.primary))
                    .background(PestGenieDesignSystem.Colors.surface)
            }
        }
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .onTapGesture {
            openSetupGuide(title)
        }
    }

    private func featureRow(_ feature: EssentialFeature) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: feature.icon)
                .foregroundColor(PestGenieDesignSystem.Colors.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(feature.name)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text(feature.description)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            if feature.isNew {
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
            openFeature(feature)
        }
    }

    private func featureCategoryCard(_ category: FeatureCategory) -> some View {
        VStack(spacing: PestGenieDesignSystem.Spacing.md) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundColor(category.color)

            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(category.name)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("\(category.articleCount) articles")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(category.color.opacity(0.1))
        .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        .onTapGesture {
            openFeatureCategory(category)
        }
    }

    private func popularFeatureRow(_ feature: PopularFeature) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: feature.icon)
                .foregroundColor(PestGenieDesignSystem.Colors.warning)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(feature.name)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Text("\(feature.viewCount) views this month")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                .font(.system(size: 12))
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .onTapGesture {
            openPopularFeature(feature)
        }
    }

    private func guideRow(_ guide: HowToGuide) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            Image(systemName: guide.type.icon)
                .foregroundColor(guide.type.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                Text(guide.title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                    Text(guide.type.displayName)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)

                    Text("\(guide.estimatedTime) min")
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            difficultyBadge(guide.difficulty)

            Image(systemName: "chevron.right")
                .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                .font(.system(size: 12))
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .onTapGesture {
            openGuide(guide)
        }
    }

    private func troubleshootingCard(_ issue: CommonIssue) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: issue.severity.icon)
                    .foregroundColor(issue.severity.color)

                Text(issue.title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                severityBadge(issue.severity)
            }

            Text(issue.description)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            if !issue.quickFix.isEmpty {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Quick Fix:")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text(issue.quickFix)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        .padding(PestGenieDesignSystem.Spacing.sm)
                        .background(PestGenieDesignSystem.Colors.surface)
                        .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
                }
            }

            Button("View Solution") {
                openTroubleshootingSolution(issue)
            }
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(PestGenieDesignSystem.Colors.primary)
        }
        .pestGenieCard()
    }

    private func faqCard(_ faq: FAQItem) -> some View {
        DisclosureGroup(
            content: {
                Text(faq.answer)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .padding(.top, PestGenieDesignSystem.Spacing.sm)
            },
            label: {
                HStack {
                    Text(faq.question)
                        .font(PestGenieDesignSystem.Typography.bodyMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }
        )
        .padding(PestGenieDesignSystem.Spacing.md)
        .background(PestGenieDesignSystem.Colors.surface)
        .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
    }

    private func statusRow(_ service: String, status: ServiceStatus) -> some View {
        HStack {
            Text(service)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)

                Text(status.displayName)
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(status.color)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func accountInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func securityRow(_ feature: String, isEnabled: Bool) -> some View {
        HStack {
            Text(feature)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isEnabled ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.error)

                Text(isEnabled ? "Enabled" : "Disabled")
                    .font(PestGenieDesignSystem.Typography.captionEmphasis)
                    .foregroundColor(isEnabled ? PestGenieDesignSystem.Colors.success : PestGenieDesignSystem.Colors.error)
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func dataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func actionButton(_ title: String, icon: String, color: Color = PestGenieDesignSystem.Colors.primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(color)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func contactOptionCard(
        title: String,
        description: String,
        icon: String,
        color: Color,
        availability: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(description)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text(availability)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .background(color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.md)
        }
        .buttonStyle(.plain)
    }

    private func hourRow(_ day: String, _ hours: String) -> some View {
        HStack {
            Text(day)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            Spacer()

            Text(hours)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func emergencyContactRow(title: String, number: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
            HStack {
                Text(title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Button(number) {
                    callEmergencyNumber(number)
                }
                .font(PestGenieDesignSystem.Typography.captionEmphasis)
                .foregroundColor(PestGenieDesignSystem.Colors.error)
            }

            Text(description)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
    }

    private func difficultyBadge(_ difficulty: GuideDifficulty) -> some View {
        Text(difficulty.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(difficulty.color)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(difficulty.color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func severityBadge(_ severity: IssueSeverity) -> some View {
        Text(severity.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(.white)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(severity.color)
            .clipShape(Capsule())
    }

    // MARK: - Sheets

    private var contactFormSheet: some View {
        NavigationStack {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Contact support form would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(PestGenieDesignSystem.Spacing.xl)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingContactForm = false
                    }
                }
            }
        }
    }

    private var feedbackFormSheet: some View {
        NavigationStack {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Feedback form would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(PestGenieDesignSystem.Spacing.xl)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFeedbackForm = false
                    }
                }
            }
        }
    }

    private var chatSupportSheet: some View {
        NavigationStack {
            VStack(spacing: PestGenieDesignSystem.Spacing.lg) {
                Text("Live chat interface would appear here")
                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(PestGenieDesignSystem.Spacing.xl)

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Live Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingChatSupport = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func makePhoneCall() {
        print("Making phone call to support...")
    }

    private func playVideo(_ title: String) {
        print("Playing video: \(title)")
    }

    private func openSetupGuide(_ guide: String) {
        print("Opening setup guide: \(guide)")
    }

    private func openFeature(_ feature: EssentialFeature) {
        print("Opening feature: \(feature.name)")
    }

    private func openFeatureCategory(_ category: FeatureCategory) {
        print("Opening feature category: \(category.name)")
    }

    private func openPopularFeature(_ feature: PopularFeature) {
        print("Opening popular feature: \(feature.name)")
    }

    private func openGuide(_ guide: HowToGuide) {
        print("Opening guide: \(guide.title)")
    }

    private func openTroubleshootingSolution(_ issue: CommonIssue) {
        print("Opening troubleshooting solution for: \(issue.title)")
    }

    private func openSystemStatus() {
        print("Opening system status page...")
    }

    private func updateProfile() {
        print("Updating profile...")
    }

    private func changePassword() {
        print("Changing password...")
    }

    private func openPrivacySettings() {
        print("Opening privacy settings...")
    }

    private func runSecurityCheckup() {
        print("Running security checkup...")
    }

    private func exportData() {
        print("Exporting data...")
    }

    private func deleteAccount() {
        print("Deleting account...")
    }

    private func callEmergencyNumber(_ number: String) {
        print("Calling emergency number: \(number)")
    }
}

// MARK: - Supporting Types and Enums

enum HelpCategory: String, CaseIterable {
    case gettingStarted = "getting_started"
    case features = "features"
    case troubleshooting = "troubleshooting"
    case account = "account"
    case contact = "contact"

    var displayName: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .features: return "Features"
        case .troubleshooting: return "Troubleshooting"
        case .account: return "Account"
        case .contact: return "Contact"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted: return "play.circle"
        case .features: return "star.circle"
        case .troubleshooting: return "wrench.and.screwdriver"
        case .account: return "person.circle"
        case .contact: return "phone.circle"
        }
    }
}

enum ServiceStatus {
    case operational
    case maintenance
    case degraded
    case outage

    var displayName: String {
        switch self {
        case .operational: return "Operational"
        case .maintenance: return "Maintenance"
        case .degraded: return "Degraded"
        case .outage: return "Outage"
        }
    }

    var color: Color {
        switch self {
        case .operational: return PestGenieDesignSystem.Colors.success
        case .maintenance: return PestGenieDesignSystem.Colors.warning
        case .degraded: return PestGenieDesignSystem.Colors.warning
        case .outage: return PestGenieDesignSystem.Colors.error
        }
    }
}

enum GuideDifficulty {
    case beginner
    case intermediate
    case advanced

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

enum GuideType {
    case article
    case video
    case interactive

    var displayName: String {
        switch self {
        case .article: return "Article"
        case .video: return "Video"
        case .interactive: return "Interactive"
        }
    }

    var icon: String {
        switch self {
        case .article: return "doc.text"
        case .video: return "play.rectangle"
        case .interactive: return "hand.tap"
        }
    }

    var color: Color {
        switch self {
        case .article: return PestGenieDesignSystem.Colors.info
        case .video: return PestGenieDesignSystem.Colors.accent
        case .interactive: return PestGenieDesignSystem.Colors.success
        }
    }
}

enum IssueSeverity {
    case low
    case medium
    case high
    case critical

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.circle"
        case .high: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .low: return PestGenieDesignSystem.Colors.info
        case .medium: return PestGenieDesignSystem.Colors.warning
        case .high: return PestGenieDesignSystem.Colors.error
        case .critical: return PestGenieDesignSystem.Colors.error
        }
    }
}

// MARK: - Data Models

struct EssentialFeature: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let isNew: Bool
}

struct FeatureCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let articleCount: Int
}

struct PopularFeature: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let viewCount: Int
}

struct HowToGuide: Identifiable {
    let id = UUID()
    let title: String
    let type: GuideType
    let difficulty: GuideDifficulty
    let estimatedTime: Int
}

struct CommonIssue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let severity: IssueSeverity
    let quickFix: String
}

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Help Support Manager

class HelpSupportManager: ObservableObject {
    @Published var essentialFeatures: [EssentialFeature] = []
    @Published var featureCategories: [FeatureCategory] = []
    @Published var popularFeatures: [PopularFeature] = []
    @Published var howToGuides: [HowToGuide] = []
    @Published var commonIssues: [CommonIssue] = []
    @Published var faqItems: [FAQItem] = []

    func loadHelpData() {
        loadMockData()
    }

    private func loadMockData() {
        // Essential features
        essentialFeatures = [
            EssentialFeature(
                name: "Route Management",
                description: "Plan and optimize your daily routes",
                icon: "map",
                isNew: false
            ),
            EssentialFeature(
                name: "Customer Communication",
                description: "Communicate with customers efficiently",
                icon: "message",
                isNew: true
            ),
            EssentialFeature(
                name: "Equipment Tracking",
                description: "Monitor equipment status and maintenance",
                icon: "wrench.and.screwdriver",
                isNew: false
            ),
            EssentialFeature(
                name: "Chemical Inventory",
                description: "Track chemical usage and safety",
                icon: "testtube.2",
                isNew: false
            ),
            EssentialFeature(
                name: "Report Generation",
                description: "Create detailed service reports",
                icon: "doc.text",
                isNew: false
            )
        ]

        // Feature categories
        featureCategories = [
            FeatureCategory(
                name: "Route Planning",
                icon: "map",
                color: PestGenieDesignSystem.Colors.primary,
                articleCount: 12
            ),
            FeatureCategory(
                name: "Customer Management",
                icon: "person.2",
                color: PestGenieDesignSystem.Colors.accent,
                articleCount: 8
            ),
            FeatureCategory(
                name: "Equipment & Tools",
                icon: "wrench.and.screwdriver",
                color: PestGenieDesignSystem.Colors.secondary,
                articleCount: 15
            ),
            FeatureCategory(
                name: "Reporting",
                icon: "chart.bar",
                color: PestGenieDesignSystem.Colors.success,
                articleCount: 10
            ),
            FeatureCategory(
                name: "Safety & Compliance",
                icon: "shield.checkered",
                color: PestGenieDesignSystem.Colors.error,
                articleCount: 9
            ),
            FeatureCategory(
                name: "Mobile Features",
                icon: "iphone",
                color: PestGenieDesignSystem.Colors.info,
                articleCount: 6
            )
        ]

        // Popular features
        popularFeatures = [
            PopularFeature(name: "GPS Navigation", icon: "location", viewCount: 1250),
            PopularFeature(name: "Weather Integration", icon: "cloud.sun", viewCount: 980),
            PopularFeature(name: "QR Code Scanner", icon: "qrcode.viewfinder", viewCount: 875),
            PopularFeature(name: "Offline Mode", icon: "wifi.slash", viewCount: 720),
            PopularFeature(name: "Voice Notes", icon: "mic", viewCount: 650)
        ]

        // How-to guides
        howToGuides = [
            HowToGuide(
                title: "Setting Up Your First Route",
                type: .video,
                difficulty: .beginner,
                estimatedTime: 5
            ),
            HowToGuide(
                title: "Using the QR Code Scanner",
                type: .interactive,
                difficulty: .beginner,
                estimatedTime: 3
            ),
            HowToGuide(
                title: "Advanced Report Customization",
                type: .article,
                difficulty: .advanced,
                estimatedTime: 12
            ),
            HowToGuide(
                title: "Chemical Safety Protocols",
                type: .video,
                difficulty: .intermediate,
                estimatedTime: 8
            ),
            HowToGuide(
                title: "Troubleshooting GPS Issues",
                type: .article,
                difficulty: .intermediate,
                estimatedTime: 6
            )
        ]

        // Common issues
        commonIssues = [
            CommonIssue(
                title: "GPS Not Working",
                description: "Location services are not functioning properly",
                severity: .high,
                quickFix: "Check location permissions in Settings > Privacy & Security > Location Services"
            ),
            CommonIssue(
                title: "Sync Failures",
                description: "Data is not syncing between device and server",
                severity: .medium,
                quickFix: "Pull down on the main screen to force refresh data"
            ),
            CommonIssue(
                title: "App Crashes on Startup",
                description: "Application fails to load properly",
                severity: .critical,
                quickFix: "Force close the app and restart. If problem persists, reinstall the app."
            ),
            CommonIssue(
                title: "Reports Not Saving",
                description: "Service reports are not being saved",
                severity: .high,
                quickFix: "Ensure you have internet connection and try saving again"
            ),
            CommonIssue(
                title: "Camera Not Working",
                description: "Unable to take photos for reports",
                severity: .medium,
                quickFix: "Check camera permissions in Settings > Privacy & Security > Camera"
            )
        ]

        // FAQ items
        faqItems = [
            FAQItem(
                question: "How do I reset my password?",
                answer: "You can reset your password by tapping 'Forgot Password' on the login screen, or by contacting your supervisor."
            ),
            FAQItem(
                question: "Can I use the app offline?",
                answer: "Yes, the app supports offline mode for essential features. Your data will sync when you're back online."
            ),
            FAQItem(
                question: "How do I report a safety issue?",
                answer: "Use the Emergency button in the top navigation bar, or call the safety hotline at 1-800-SAFE-123."
            ),
            FAQItem(
                question: "Where can I find my completed reports?",
                answer: "All completed reports are available in the Reports & Documentation section of the main menu."
            ),
            FAQItem(
                question: "How do I update my profile information?",
                answer: "Go to Settings & Preferences > General > User Profile to update your information."
            ),
            FAQItem(
                question: "What should I do if a customer is not home?",
                answer: "Mark the job as 'Customer Not Home' in the route screen and follow your company's rescheduling protocol."
            ),
            FAQItem(
                question: "How do I add equipment to my inventory?",
                answer: "Go to the Equipment section and tap the '+' button to add new equipment to your inventory."
            ),
            FAQItem(
                question: "Can I customize the dashboard?",
                answer: "Yes, you can customize the dashboard layout in Settings & Preferences > Appearance > Dashboard Layout."
            )
        ]
    }
}

// MARK: - Preview

#Preview("Help & Support") {
    HelpSupportView()
}

#Preview("Help Dark Mode") {
    HelpSupportView()
        .preferredColorScheme(.dark)
}