import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showingProfileEdit = false
    @State private var showingNotificationSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingHelpSupport = false
    @State private var showingAbout = false

    var body: some View {
        VStack(spacing: 8) {
            // Profile Information Card
            profileInfoCard

            // Quick Actions Card
            quickActionsCard

            // Settings Card
            settingsCard

            // Sign Out Button
            signOutButton

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color(hex: "#F8F9FA"))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView()
        }
    }

    // MARK: - Profile Information Card

    private var profileInfoCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                // Profile Image and Basic Info
                HStack(spacing: 16) {
                    // Profile Image
                    AsyncImage(url: authManager.currentUser?.profileImageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(Color(hex: "#0066CC"))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())

                    // Name and Email
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.currentUser?.name ?? routeViewModel.currentUserName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#1A1D29"))

                        Text(authManager.currentUser?.email ?? "john.briggs@pestgenie.com")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#6B7280"))
                    }

                    Spacer()
                }

                // Job Title Badge
                HStack(spacing: 10) {
                    Image(systemName: "briefcase.fill")
                        .foregroundColor(Color(hex: "#0066CC"))
                        .font(.caption)
                        .frame(width: 16, height: 16)

                    Text("Senior Technician")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#0066CC"))

                    Spacer()

                    Text("5 Years Experience")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#6B7280"))
                }
                .padding(8)
                .background(Color(hex: "#EEF7FF"))
                .cornerRadius(8)
            }

            Divider()
                .background(Color(hex: "#F1F5F9"))

            // Stats Section
            HStack(spacing: 0) {
                StatView(
                    value: "\(routeViewModel.completedJobsCount)",
                    label: "Today",
                    color: Color(hex: "#0066CC")
                )

                Spacer()

                StatView(
                    value: "4.9",
                    label: "Rating",
                    color: Color(hex: "#F59E0B")
                )

                Spacer()

                StatView(
                    value: "\(routeViewModel.activeStreak)",
                    label: "Streak",
                    color: Color(hex: "#10B981")
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#1A1D29"))

                Spacer()
            }

            HStack(spacing: 8) {
                ProfileQuickActionButton(
                    title: "Edit Profile",
                    icon: "pencil.circle.fill",
                    backgroundColor: Color(hex: "#EEF7FF"),
                    iconColor: Color(hex: "#0066CC")
                ) {
                    showingProfileEdit = true
                }

                ProfileQuickActionButton(
                    title: "Schedule",
                    icon: "calendar",
                    backgroundColor: Color(hex: "#ECFDF5"),
                    iconColor: Color(hex: "#10B981")
                ) {
                    // Navigate to schedule
                }

                ProfileQuickActionButton(
                    title: "Time Clock",
                    icon: "clock.fill",
                    backgroundColor: Color(hex: "#FEF3C7"),
                    iconColor: Color(hex: "#F59E0B")
                ) {
                    // Navigate to time clock
                }

                ProfileQuickActionButton(
                    title: "Certificates",
                    icon: "rosette",
                    backgroundColor: Color(hex: "#F3F4F6"),
                    iconColor: Color(hex: "#6366F1")
                ) {
                    // Navigate to certificates
                }
            }
            .frame(height: 60)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#1A1D29"))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Settings Items
            VStack(spacing: 0) {
                SettingsRowView(
                    title: "Notifications",
                    icon: "bell",
                    iconColor: Color(hex: "#EF4444"),
                    backgroundColor: Color(hex: "#FEE2E2")
                ) {
                    showingNotificationSettings = true
                }

                Divider()
                    .background(Color(hex: "#F1F5F9"))

                SettingsRowView(
                    title: "Privacy & Security",
                    icon: "lock.shield",
                    iconColor: Color(hex: "#0066CC"),
                    backgroundColor: Color(hex: "#EEF7FF")
                ) {
                    showingPrivacySettings = true
                }

                Divider()
                    .background(Color(hex: "#F1F5F9"))

                SettingsRowView(
                    title: "Help & Support",
                    icon: "questionmark.circle",
                    iconColor: Color(hex: "#10B981"),
                    backgroundColor: Color(hex: "#ECFDF5")
                ) {
                    showingHelpSupport = true
                }

                Divider()
                    .background(Color(hex: "#F1F5F9"))

                SettingsRowView(
                    title: "About",
                    icon: "info.circle",
                    iconColor: Color(hex: "#6B7280"),
                    backgroundColor: Color(hex: "#F3F4F6"),
                    trailingContent: {
                        HStack(spacing: 8) {
                            Text("Version 1.0.0")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "#6B7280"))

                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hex: "#9CA3AF"))
                                .font(.system(size: 14))
                        }
                    }
                ) {
                    showingAbout = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button(action: handleSignOut) {
            Text("Sign Out")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(hex: "#DC2626"))
                .cornerRadius(16)
                .shadow(color: Color(hex: "#DC2626").opacity(0.06), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Actions

    private func handleSignOut() {
        // Handle sign out logic
        print("Sign out tapped")
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#6B7280"))
        }
    }
}

struct ProfileQuickActionButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(.system(size: 10))
                    .fontWeight(.semibold)
                    .foregroundColor(iconColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: iconColor.opacity(0.05), radius: 1, x: 0, y: 0.5)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsRowView<TrailingContent: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let trailingContent: (() -> TrailingContent)?
    let action: () -> Void

    init(
        title: String,
        icon: String,
        iconColor: Color,
        backgroundColor: Color,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.trailingContent = trailingContent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                VStack {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 18))
                        .frame(width: 18, height: 18)
                }
                .padding(6)
                .background(backgroundColor)
                .cornerRadius(8)

                // Title
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "#1A1D29"))

                Spacer()

                // Trailing Content
                if let trailingContent = trailingContent {
                    trailingContent()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "#9CA3AF"))
                        .font(.system(size: 14))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
                .environmentObject(RouteViewModel())
        }
    }
}