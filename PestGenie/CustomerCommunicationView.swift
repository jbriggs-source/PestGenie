import SwiftUI

/// Customer Communication Center for pest control technicians.
/// Provides tools for messaging, notifications, feedback collection, and service updates.
/// Designed to enhance customer satisfaction and streamline communication workflows.
struct CustomerCommunicationView: View {
    @State private var selectedTab: CommunicationTab = .messages
    @State private var showingNewMessage = false
    @State private var showingNotificationComposer = false
    @State private var searchText = ""
    @State private var selectedMessage: CustomerMessage?
    @State private var selectedFeedback: CustomerFeedback?
    @State private var showingMessageDetails = false
    @State private var showingFeedbackResponse = false
    @State private var showingCallConfirmation = false
    @State private var customerToCall: CustomerMessage?
    @StateObject private var communicationManager = CustomerCommunicationManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selection
                communicationTabBar

                // Content area
                Group {
                    switch selectedTab {
                    case .messages:
                        messagesView
                    case .notifications:
                        notificationsView
                    case .feedback:
                        feedbackView
                    case .serviceUpdates:
                        serviceUpdatesView
                    }
                }
            }
            .navigationTitle("Communications")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search \(selectedTab.title.lowercased())...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingNewMessage = true }) {
                            Label("New Message", systemImage: "message.badge.plus")
                        }
                        Button(action: { showingNotificationComposer = true }) {
                            Label("Send Notification", systemImage: "bell.badge.plus")
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
        .sheet(isPresented: $showingNewMessage) {
            newMessageSheet
        }
        .sheet(isPresented: $showingNotificationComposer) {
            notificationComposerSheet
        }
        .sheet(isPresented: $showingMessageDetails) {
            messageDetailsSheet
        }
        .sheet(isPresented: $showingFeedbackResponse) {
            feedbackResponseSheet
        }
        .confirmationDialog("Call Customer", isPresented: $showingCallConfirmation, presenting: customerToCall) { customer in
            Button("Call \(customer.customerName)") {
                initiateCall(to: customer)
            }
            Button("Cancel", role: .cancel) { }
        } message: { customer in
            Text("Would you like to call \(customer.customerName)?")
        }
        .onAppear {
            loadCommunications()
        }
    }

    // MARK: - Communication Tab Bar

    private var communicationTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CommunicationTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))

                            Text(tab.shortTitle)
                                .font(PestGenieDesignSystem.Typography.labelMedium)
                                .lineLimit(1)

                            if tab.unreadCount > 0 {
                                Text("\(tab.unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(PestGenieDesignSystem.Colors.error)
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
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(PestGenieDesignSystem.Colors.surface)
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(filteredMessages) { message in
                    messageCard(message)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private func messageCard(_ message: CustomerMessage) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(message.customerName)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(message.address)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    statusBadge(message.status)

                    Text(message.timestamp, style: .relative)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                }
            }

            // Message content
            Text(message.content)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                .lineLimit(3)

            // Action buttons
            HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                Button(action: { replyToMessage(message) }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Image(systemName: "arrowshape.turn.up.left")
                        Text("Reply")
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }

                Button(action: { callCustomer(message) }) {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Image(systemName: "phone")
                        Text("Call")
                    }
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
                }

                Spacer()

                priorityIndicator(message.priority)
            }
        }
        .pestGenieCard()
        .onTapGesture {
            viewMessageDetails(message)
        }
    }

    // MARK: - Notifications View

    private var notificationsView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                // Quick send section
                quickNotificationSection

                // Sent notifications
                ForEach(communicationManager.sentNotifications) { notification in
                    notificationCard(notification)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private var quickNotificationSection: some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            Text("Quick Notifications")
                .font(PestGenieDesignSystem.Typography.headlineSmall)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: PestGenieDesignSystem.Spacing.sm) {
                quickNotificationButton(
                    title: "Arrival",
                    subtitle: "On my way",
                    icon: "car.fill",
                    color: PestGenieDesignSystem.Colors.info
                )

                quickNotificationButton(
                    title: "Completed",
                    subtitle: "Service done",
                    icon: "checkmark.circle.fill",
                    color: PestGenieDesignSystem.Colors.success
                )

                quickNotificationButton(
                    title: "Delayed",
                    subtitle: "Running late",
                    icon: "clock.fill",
                    color: PestGenieDesignSystem.Colors.warning
                )

                quickNotificationButton(
                    title: "Rescheduled",
                    subtitle: "Need to reschedule",
                    icon: "calendar.badge.exclamationmark",
                    color: PestGenieDesignSystem.Colors.error
                )
            }
        }
        .pestGenieCard()
    }

    private func quickNotificationButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        Button(action: {
            sendQuickNotification(type: title)
        }) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(title)
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(subtitle)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PestGenieDesignSystem.Spacing.md)
            .background(color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func notificationCard(_ notification: CustomerNotification) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Text(notification.title)
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Text(notification.sentAt, style: .relative)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }

            Text(notification.message)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

            HStack {
                Text("\(notification.recipientCount) recipients")
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                Spacer()

                deliveryStatusBadge(notification.deliveryStatus)
            }
        }
        .pestGenieCard()
    }

    // MARK: - Feedback View

    private var feedbackView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(communicationManager.customerFeedback) { feedback in
                    feedbackCard(feedback)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private func feedbackCard(_ feedback: CustomerFeedback) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(feedback.customerName)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(feedback.serviceDate, style: .date)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                ratingView(feedback.rating)
            }

            Text(feedback.comments)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            if !feedback.responseText.isEmpty {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Your Response:")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                    Text(feedback.responseText)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .padding(PestGenieDesignSystem.Spacing.sm)
                        .background(PestGenieDesignSystem.Colors.surface)
                        .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
                }
            } else {
                Button(action: { respondToFeedback(feedback) }) {
                    Text("Respond to Feedback")
                        .font(PestGenieDesignSystem.Typography.labelMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.primary)
                }
            }
        }
        .pestGenieCard()
    }

    // MARK: - Service Updates View

    private var serviceUpdatesView: some View {
        ScrollView {
            LazyVStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                ForEach(communicationManager.serviceUpdates) { update in
                    serviceUpdateCard(update)
                }
            }
            .padding(PestGenieDesignSystem.Spacing.md)
        }
    }

    private func serviceUpdateCard(_ update: ServiceUpdate) -> some View {
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: update.type.icon)
                    .foregroundColor(update.type.color)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(update.title)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Text(update.customerName)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }

                Spacer()

                Text(update.timestamp, style: .relative)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
            }

            Text(update.description)
                .font(PestGenieDesignSystem.Typography.bodyMedium)
                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

            if let nextAction = update.nextAction {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(PestGenieDesignSystem.Colors.accent)
                    Text("Next: \(nextAction)")
                        .font(PestGenieDesignSystem.Typography.captionEmphasis)
                        .foregroundColor(PestGenieDesignSystem.Colors.accent)
                }
            }
        }
        .pestGenieCard()
    }

    // MARK: - Helper Views

    private func statusBadge(_ status: MessageStatus) -> some View {
        Text(status.displayName)
            .font(PestGenieDesignSystem.Typography.captionEmphasis)
            .foregroundColor(.white)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xxs)
            .background(status.color)
            .clipShape(Capsule())
    }

    private func priorityIndicator(_ priority: MessagePriority) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
            Text(priority.displayName)
                .font(PestGenieDesignSystem.Typography.caption)
                .foregroundColor(priority.color)
        }
    }

    private func ratingView(_ rating: Int) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? PestGenieDesignSystem.Colors.warning : PestGenieDesignSystem.Colors.textTertiary)
                    .font(.system(size: 14))
            }
        }
    }

    private func deliveryStatusBadge(_ status: DeliveryStatus) -> some View {
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            Image(systemName: status.icon)
            Text(status.displayName)
        }
        .font(PestGenieDesignSystem.Typography.caption)
        .foregroundColor(status.color)
    }

    // MARK: - Sheets

    private var newMessageSheet: some View {
        NavigationView {
            Text("New Message Composer")
                .navigationTitle("New Message")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingNewMessage = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Send") {
                            // Send message logic
                            showingNewMessage = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }

    private var notificationComposerSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Title")
                        .font(PestGenieDesignSystem.Typography.labelMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    TextField("Notification title", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                    Text("Message")
                        .font(PestGenieDesignSystem.Typography.labelMedium)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    TextField("Your message", text: .constant(""), axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Spacer()
            }
            .padding(PestGenieDesignSystem.Spacing.md)
            .navigationTitle("Send Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNotificationComposer = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        // Send notification logic
                        showingNotificationComposer = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var messageDetailsSheet: some View {
        NavigationView {
            Group {
                if let message = selectedMessage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.lg) {
                            // Customer Info
                            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                                Text("Customer Information")
                                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                                    HStack {
                                        Text("Name:")
                                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                                        Text(message.customerName)
                                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                                    }

                                    HStack {
                                        Text("Address:")
                                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                                            .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                                        Text(message.address)
                                            .font(PestGenieDesignSystem.Typography.bodyMedium)
                                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                                    }
                                }
                            }
                            .pestGenieCard()

                            // Message Content
                            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                                Text("Message")
                                    .font(PestGenieDesignSystem.Typography.headlineSmall)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                                Text(message.content)
                                    .font(PestGenieDesignSystem.Typography.bodyMedium)
                                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                            }
                            .pestGenieCard()

                            // Actions
                            VStack(spacing: PestGenieDesignSystem.Spacing.sm) {
                                Button(action: {
                                    replyToMessage(message)
                                    showingMessageDetails = false
                                }) {
                                    HStack {
                                        Image(systemName: "arrowshape.turn.up.left")
                                        Text("Reply to Message")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(PestGenieDesignSystem.Colors.primary)
                                    .foregroundColor(.white)
                                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
                                }

                                Button(action: {
                                    callCustomer(message)
                                    showingMessageDetails = false
                                }) {
                                    HStack {
                                        Image(systemName: "phone")
                                        Text("Call Customer")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(PestGenieDesignSystem.Colors.accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
                                }
                            }
                        }
                        .padding(PestGenieDesignSystem.Spacing.md)
                    }
                } else {
                    Text("No message selected")
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingMessageDetails = false
                    }
                }
            }
        }
    }

    private var feedbackResponseSheet: some View {
        NavigationView {
            Group {
                if let feedback = selectedFeedback {
                    VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.md) {
                        // Original feedback
                        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
                            Text("Customer Feedback")
                                .font(PestGenieDesignSystem.Typography.headlineSmall)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            Text(feedback.comments)
                                .font(PestGenieDesignSystem.Typography.bodyMedium)
                                .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                                .padding()
                                .background(PestGenieDesignSystem.Colors.surface)
                                .cornerRadius(PestGenieDesignSystem.BorderRadius.sm)
                        }

                        // Response field
                        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                            Text("Your Response")
                                .font(PestGenieDesignSystem.Typography.labelMedium)
                                .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                            TextField("Write your response...", text: .constant(""), axis: .vertical)
                                .lineLimit(4...8)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        Spacer()
                    }
                    .padding(PestGenieDesignSystem.Spacing.md)
                } else {
                    Text("No feedback selected")
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                }
            }
            .navigationTitle("Respond to Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingFeedbackResponse = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        // Send response logic
                        showingFeedbackResponse = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredMessages: [CustomerMessage] {
        if searchText.isEmpty {
            return communicationManager.messages
        } else {
            return communicationManager.messages.filter { message in
                message.customerName.localizedCaseInsensitiveContains(searchText) ||
                message.content.localizedCaseInsensitiveContains(searchText) ||
                message.address.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func loadCommunications() {
        communicationManager.loadData()
    }

    private func refreshData() {
        communicationManager.refresh()
    }

    private func replyToMessage(_ message: CustomerMessage) {
        selectedMessage = message
        showingNewMessage = true
    }

    private func callCustomer(_ message: CustomerMessage) {
        customerToCall = message
        showingCallConfirmation = true
    }

    private func viewMessageDetails(_ message: CustomerMessage) {
        selectedMessage = message
        showingMessageDetails = true
    }

    private func sendQuickNotification(type: String) {
        // Create and show quick notification
        let notification = CustomerNotification(
            title: "\(type) Update",
            message: "This is a \(type.lowercased()) notification",
            recipientCount: 1,
            sentAt: Date(),
            deliveryStatus: .sent
        )
        communicationManager.addNotification(notification)
    }

    private func respondToFeedback(_ feedback: CustomerFeedback) {
        selectedFeedback = feedback
        showingFeedbackResponse = true
    }

    private func initiateCall(to message: CustomerMessage) {
        // In a real app, this would trigger a phone call
        // For demo purposes, we'll show a toast or update the message status
        print("Calling \(message.customerName) at their contact number")
    }
}

// MARK: - Supporting Types

enum CommunicationTab: String, CaseIterable {
    case messages = "messages"
    case notifications = "notifications"
    case feedback = "feedback"
    case serviceUpdates = "service_updates"

    var title: String {
        switch self {
        case .messages: return "Messages"
        case .notifications: return "Notifications"
        case .feedback: return "Feedback"
        case .serviceUpdates: return "Updates"
        }
    }

    var shortTitle: String {
        switch self {
        case .messages: return "Messages"
        case .notifications: return "Alerts"
        case .feedback: return "Reviews"
        case .serviceUpdates: return "Updates"
        }
    }

    var icon: String {
        switch self {
        case .messages: return "message.fill"
        case .notifications: return "bell.fill"
        case .feedback: return "star.fill"
        case .serviceUpdates: return "info.circle.fill"
        }
    }

    var unreadCount: Int {
        switch self {
        case .messages: return 3
        case .notifications: return 0
        case .feedback: return 2
        case .serviceUpdates: return 1
        }
    }
}

enum MessageStatus: String, CaseIterable {
    case unread = "unread"
    case read = "read"
    case replied = "replied"
    case resolved = "resolved"

    var displayName: String {
        switch self {
        case .unread: return "New"
        case .read: return "Read"
        case .replied: return "Replied"
        case .resolved: return "Resolved"
        }
    }

    var color: Color {
        switch self {
        case .unread: return PestGenieDesignSystem.Colors.warning
        case .read: return PestGenieDesignSystem.Colors.info
        case .replied: return PestGenieDesignSystem.Colors.accent
        case .resolved: return PestGenieDesignSystem.Colors.success
        }
    }
}

enum MessagePriority: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var color: Color {
        switch self {
        case .low: return PestGenieDesignSystem.Colors.textTertiary
        case .normal: return PestGenieDesignSystem.Colors.textSecondary
        case .high: return PestGenieDesignSystem.Colors.warning
        case .urgent: return PestGenieDesignSystem.Colors.error
        }
    }
}

enum DeliveryStatus: String, CaseIterable {
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .sent: return "paperplane"
        case .delivered: return "checkmark"
        case .read: return "eye"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .sent: return PestGenieDesignSystem.Colors.info
        case .delivered: return PestGenieDesignSystem.Colors.success
        case .read: return PestGenieDesignSystem.Colors.accent
        case .failed: return PestGenieDesignSystem.Colors.error
        }
    }
}

enum ServiceUpdateType: String, CaseIterable {
    case appointment = "appointment"
    case treatment = "treatment"
    case inspection = "inspection"
    case followUp = "follow_up"

    var icon: String {
        switch self {
        case .appointment: return "calendar"
        case .treatment: return "drop.fill"
        case .inspection: return "magnifyingglass"
        case .followUp: return "arrow.clockwise"
        }
    }

    var color: Color {
        switch self {
        case .appointment: return PestGenieDesignSystem.Colors.accent
        case .treatment: return PestGenieDesignSystem.Colors.success
        case .inspection: return PestGenieDesignSystem.Colors.warning
        case .followUp: return PestGenieDesignSystem.Colors.info
        }
    }
}

// MARK: - Data Models

struct CustomerMessage: Identifiable {
    let id = UUID()
    let customerName: String
    let address: String
    let content: String
    let timestamp: Date
    let status: MessageStatus
    let priority: MessagePriority
}

struct CustomerNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recipientCount: Int
    let sentAt: Date
    let deliveryStatus: DeliveryStatus
}

struct CustomerFeedback: Identifiable {
    let id = UUID()
    let customerName: String
    let serviceDate: Date
    let rating: Int
    let comments: String
    let responseText: String
}

struct ServiceUpdate: Identifiable {
    let id = UUID()
    let type: ServiceUpdateType
    let title: String
    let customerName: String
    let description: String
    let timestamp: Date
    let nextAction: String?
}

// MARK: - Communication Manager

class CustomerCommunicationManager: ObservableObject {
    @Published var messages: [CustomerMessage] = []
    @Published var sentNotifications: [CustomerNotification] = []
    @Published var customerFeedback: [CustomerFeedback] = []
    @Published var serviceUpdates: [ServiceUpdate] = []

    func loadData() {
        // Mock data - in a real app, this would load from API/database
        loadMockData()
    }

    func refresh() {
        loadData()
    }

    func addNotification(_ notification: CustomerNotification) {
        sentNotifications.insert(notification, at: 0)
    }

    private func loadMockData() {
        messages = [
            CustomerMessage(
                customerName: "Sarah Johnson",
                address: "123 Oak Street, Springfield",
                content: "Hi, I noticed some ants in my kitchen again. Could you please schedule a follow-up visit?",
                timestamp: Date().addingTimeInterval(-3600),
                status: .unread,
                priority: .normal
            ),
            CustomerMessage(
                customerName: "Mike Chen",
                address: "456 Pine Avenue, Springfield",
                content: "Thank you for the great service yesterday! The technician was very professional.",
                timestamp: Date().addingTimeInterval(-7200),
                status: .read,
                priority: .low
            ),
            CustomerMessage(
                customerName: "Emily Davis",
                address: "789 Maple Drive, Springfield",
                content: "URGENT: I'm seeing multiple wasps around my back patio. Please help ASAP!",
                timestamp: Date().addingTimeInterval(-1800),
                status: .unread,
                priority: .urgent
            )
        ]

        sentNotifications = [
            CustomerNotification(
                title: "Service Reminder",
                message: "Your quarterly pest control service is scheduled for tomorrow at 2:00 PM.",
                recipientCount: 15,
                sentAt: Date().addingTimeInterval(-86400),
                deliveryStatus: .delivered
            ),
            CustomerNotification(
                title: "Arrival Notification",
                message: "Your technician is on the way and will arrive in approximately 15 minutes.",
                recipientCount: 3,
                sentAt: Date().addingTimeInterval(-3600),
                deliveryStatus: .read
            )
        ]

        customerFeedback = [
            CustomerFeedback(
                customerName: "Robert Wilson",
                serviceDate: Date().addingTimeInterval(-172800),
                rating: 5,
                comments: "Excellent service! The technician was on time, professional, and explained everything clearly.",
                responseText: "Thank you for the wonderful feedback, Robert! We're thrilled you're happy with our service."
            ),
            CustomerFeedback(
                customerName: "Lisa Thompson",
                serviceDate: Date().addingTimeInterval(-259200),
                rating: 4,
                comments: "Good service overall, but the technician arrived about 30 minutes late.",
                responseText: ""
            )
        ]

        serviceUpdates = [
            ServiceUpdate(
                type: .treatment,
                title: "Treatment Completed",
                customerName: "David Brown",
                description: "Applied perimeter treatment and interior spray. All entry points sealed.",
                timestamp: Date().addingTimeInterval(-1800),
                nextAction: "Schedule follow-up in 30 days"
            ),
            ServiceUpdate(
                type: .inspection,
                title: "Property Inspection",
                customerName: "Jennifer Lee",
                description: "Completed comprehensive inspection. Found minor ant activity in kitchen area.",
                timestamp: Date().addingTimeInterval(-5400),
                nextAction: "Treatment scheduled for next week"
            )
        ]
    }
}

// MARK: - Preview

#Preview("Customer Communication") {
    CustomerCommunicationView()
}

#Preview("Customer Communication Dark Mode") {
    CustomerCommunicationView()
        .preferredColorScheme(.dark)
}