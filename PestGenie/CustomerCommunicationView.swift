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
                // Tab selection - positioned optimally below navigation/search
                VStack(spacing: 0) {
                    // Small spacing from search bar for better positioning
                    Spacer()
                        .frame(height: PestGenieDesignSystem.Spacing.xs)

                    communicationTabBar
                }

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
        HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
            ForEach(CommunicationTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        // Icon with properly positioned badge
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? PestGenieDesignSystem.Colors.primary : PestGenieDesignSystem.Colors.textSecondary)
                            .overlay(
                                // iOS-style badge positioning
                                Group {
                                    if tab.unreadCount > 0 {
                                        Text("\(tab.unreadCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, tab.unreadCount > 9 ? 4 : 5)
                                            .padding(.vertical, 2)
                                            .background(tab.badgeColor)
                                            .clipShape(Capsule())
                                            .offset(x: 12, y: -10)
                                            .shadow(
                                                color: PestGenieDesignSystem.Shadows.sm.color,
                                                radius: PestGenieDesignSystem.Shadows.sm.radius,
                                                x: PestGenieDesignSystem.Shadows.sm.x,
                                                y: PestGenieDesignSystem.Shadows.sm.y
                                            )
                                    }
                                },
                                alignment: .topTrailing
                            )

                        // Enhanced selection indicator
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.xs)
                                .fill(PestGenieDesignSystem.Colors.primary)
                                .frame(width: 24, height: 3)
                        } else {
                            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.xs)
                                .fill(Color.clear)
                                .frame(width: 24, height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PestGenieDesignSystem.Spacing.sm)
                    .padding(.horizontal, PestGenieDesignSystem.Spacing.xs)
                    .background(
                        // Enhanced active state background with elevated appearance
                        Group {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                                    .fill(PestGenieDesignSystem.Colors.primary.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                                            .stroke(PestGenieDesignSystem.Colors.primary.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: PestGenieDesignSystem.Colors.primary.opacity(0.15),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                                    .fill(Color.clear)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .scaleEffect(selectedTab == tab ? 1.02 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, PestGenieDesignSystem.Spacing.md)
        .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
        .background(
            // Tab bar background with subtle shadow
            RoundedRectangle(cornerRadius: 0)
                .fill(PestGenieDesignSystem.Colors.background)
                .shadow(
                    color: PestGenieDesignSystem.Shadows.sm.color,
                    radius: PestGenieDesignSystem.Shadows.sm.radius,
                    x: 0,
                    y: 1
                )
        )
        .overlay(
            Rectangle()
                .fill(PestGenieDesignSystem.Colors.border.opacity(0.3))
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
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Priority/Status indicator strip
            Rectangle()
                .fill(message.priority.color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                // Header row with customer info and status
                HStack {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Text(message.customerName)
                            .font(PestGenieDesignSystem.Typography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        statusBadge(message.status)
                    }

                    Spacer()

                    Text(message.timestamp, style: .relative)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                }

                // Address and message preview
                VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xxs) {
                    Text(message.address)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    Text(message.content)
                        .font(PestGenieDesignSystem.Typography.bodySmall)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                }

                // Compact action row
                HStack(spacing: PestGenieDesignSystem.Spacing.md) {
                    Button(action: { replyToMessage(message) }) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 16))
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { callCustomer(message) }) {
                        Image(systemName: "phone")
                            .font(.system(size: 16))
                            .foregroundColor(PestGenieDesignSystem.Colors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Priority indicator
                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        Circle()
                            .fill(message.priority.color)
                            .frame(width: 6, height: 6)
                        Text(message.priority.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(message.priority.color)
                    }
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .fill(message.status == .unread ?
                      PestGenieDesignSystem.Colors.surface.opacity(0.8) :
                      PestGenieDesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                        .stroke(message.status == .unread ?
                               PestGenieDesignSystem.Colors.warning.opacity(0.3) :
                               PestGenieDesignSystem.Colors.border.opacity(0.3),
                               lineWidth: message.status == .unread ? 1 : 0.5)
                )
        )
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
        VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.sm) {
            HStack {
                Text("Quick Send")
                    .font(PestGenieDesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundColor(PestGenieDesignSystem.Colors.accent)
            }

            HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                quickNotificationButton(
                    title: "Arrival",
                    icon: "car.fill",
                    color: PestGenieDesignSystem.Colors.info
                )

                quickNotificationButton(
                    title: "Completed",
                    icon: "checkmark.circle.fill",
                    color: PestGenieDesignSystem.Colors.success
                )

                quickNotificationButton(
                    title: "Delayed",
                    icon: "clock.fill",
                    color: PestGenieDesignSystem.Colors.warning
                )

                quickNotificationButton(
                    title: "Rescheduled",
                    icon: "calendar.badge.exclamationmark",
                    color: PestGenieDesignSystem.Colors.error
                )
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .fill(PestGenieDesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                        .stroke(PestGenieDesignSystem.Colors.border.opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    private func quickNotificationButton(
        title: String,
        icon: String,
        color: Color
    ) -> some View {
        Button(action: {
            sendQuickNotification(type: title)
        }) {
            VStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PestGenieDesignSystem.Spacing.xs)
            .padding(.horizontal, PestGenieDesignSystem.Spacing.xxs)
            .background(color.opacity(0.1))
            .cornerRadius(PestGenieDesignSystem.BorderRadius.xs)
            .overlay(
                RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.xs)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
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
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Rating indicator strip
            Rectangle()
                .fill(ratingColor(feedback.rating))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                // Header with customer and rating
                HStack {
                    Text(feedback.customerName)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Spacer()

                    HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                        ratingView(feedback.rating)
                        Text(feedback.serviceDate, style: .date)
                            .font(PestGenieDesignSystem.Typography.caption)
                            .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                    }
                }

                // Comments
                Text(feedback.comments)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(3)

                // Response status or action
                HStack {
                    if !feedback.responseText.isEmpty {
                        HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(PestGenieDesignSystem.Colors.success)
                            Text("Responded")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(PestGenieDesignSystem.Colors.success)
                        }
                    } else {
                        Button(action: { respondToFeedback(feedback) }) {
                            HStack(spacing: PestGenieDesignSystem.Spacing.xxs) {
                                Image(systemName: "arrowshape.turn.up.left")
                                Text("Respond")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(PestGenieDesignSystem.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .fill(PestGenieDesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                        .stroke(PestGenieDesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
                )
        )
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
        HStack(spacing: PestGenieDesignSystem.Spacing.sm) {
            // Type indicator
            Circle()
                .fill(update.type.color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: update.type.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(update.type.color)
                )

            VStack(alignment: .leading, spacing: PestGenieDesignSystem.Spacing.xs) {
                // Header
                HStack {
                    Text(update.title)
                        .font(PestGenieDesignSystem.Typography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)

                    Spacer()

                    Text(update.timestamp, style: .relative)
                        .font(PestGenieDesignSystem.Typography.caption)
                        .foregroundColor(PestGenieDesignSystem.Colors.textTertiary)
                }

                // Customer and description
                Text(update.customerName)
                    .font(PestGenieDesignSystem.Typography.caption)
                    .foregroundColor(PestGenieDesignSystem.Colors.textSecondary)

                Text(update.description)
                    .font(PestGenieDesignSystem.Typography.bodySmall)
                    .foregroundColor(PestGenieDesignSystem.Colors.textPrimary)
                    .lineLimit(2)

                // Next action
                if let nextAction = update.nextAction {
                    HStack(spacing: PestGenieDesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(PestGenieDesignSystem.Colors.accent)
                        Text(nextAction)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(PestGenieDesignSystem.Colors.accent)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(PestGenieDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                .fill(PestGenieDesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PestGenieDesignSystem.BorderRadius.sm)
                        .stroke(update.type.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Views

    private func statusBadge(_ status: MessageStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
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
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? PestGenieDesignSystem.Colors.warning : PestGenieDesignSystem.Colors.textTertiary)
                    .font(.system(size: 10))
            }
        }
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 5:
            return PestGenieDesignSystem.Colors.success
        case 4:
            return PestGenieDesignSystem.Colors.info
        case 3:
            return PestGenieDesignSystem.Colors.warning
        case 1...2:
            return PestGenieDesignSystem.Colors.error
        default:
            return PestGenieDesignSystem.Colors.textTertiary
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
        case .messages: return "bubble.left.and.text.bubble.right.fill"
        case .notifications: return "bell.badge.fill"
        case .feedback: return "star.bubble.fill"
        case .serviceUpdates: return "checkmark.seal.fill"
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

    var badgeColor: Color {
        switch self {
        case .messages: return PestGenieDesignSystem.Colors.primary
        case .notifications: return PestGenieDesignSystem.Colors.info
        case .feedback: return PestGenieDesignSystem.Colors.warning
        case .serviceUpdates: return PestGenieDesignSystem.Colors.accent
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