import SwiftUI
import PhotosUI

struct EmergencyActionView: View {
    @StateObject private var emergencyManager = EmergencyManager()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: EmergencyCategory = .safety
    @State private var showingIncidentReport = false
    @State private var showingEmergencyProtocol = false
    @State private var selectedIncidentType: EmergencyIncidentType?
    @State private var selectedProtocol: EmergencyProtocol?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Emergency Header
                emergencyHeader

                // Category Selector
                categorySelector

                // Content based on selected category
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if selectedCategory == .communication {
                            emergencyContactsSection
                        } else {
                            emergencyIncidentsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Emergency Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedIncidentType) { incidentType in
            EmergencyReportView(
                incidentType: incidentType,
                emergencyManager: emergencyManager
            )
        }
        .sheet(item: $selectedProtocol) { emergencyProtocol in
            EmergencyProtocolView(emergencyProtocol: emergencyProtocol, emergencyManager: emergencyManager)
        }
        .onAppear {
            emergencyManager.getCurrentLocation()
        }
    }

    // MARK: - Emergency Header

    private var emergencyHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(.red)

                Text("Emergency Response")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                // Quick 911 button
                Button(action: {
                    if let emergency911 = emergencyManager.emergencyContacts.first(where: { $0.type == .emergency911 }) {
                        emergencyManager.callEmergencyContact(emergency911)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                        Text("911")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }

            Text("Select emergency type for immediate assistance or incident reporting")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EmergencyCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        VStack(spacing: 4) {
                            Text(category.displayName)
                                .font(.caption)
                                .fontWeight(selectedCategory == category ? .bold : .medium)

                            Rectangle()
                                .fill(selectedCategory == category ? Color(category.color) : Color.clear)
                                .frame(height: 2)
                        }
                        .foregroundColor(selectedCategory == category ? Color(category.color) : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Emergency Contacts Section

    private var emergencyContactsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emergency Contacts")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ForEach(emergencyManager.emergencyContacts) { contact in
                EmergencyContactCard(
                    contact: contact,
                    onCall: {
                        emergencyManager.callEmergencyContact(contact)
                    }
                )
            }
        }
    }

    // MARK: - Emergency Incidents Section

    private var emergencyIncidentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedCategory.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()
            }
            .padding(.horizontal)

            let incidentTypes = EmergencyIncidentType.allCases.filter { $0.category == selectedCategory }

            ForEach(incidentTypes, id: \.self) { incidentType in
                EmergencyIncidentCard(
                    incidentType: incidentType,
                    onReport: {
                        selectedIncidentType = incidentType
                    },
                    onViewProtocol: {
                        selectedProtocol = emergencyManager.getEmergencyProtocol(for: incidentType)
                    }
                )
            }
        }
    }
}

// MARK: - Emergency Contact Card

struct EmergencyContactCard: View {
    let contact: EmergencyResponseContact
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: contact.type.icon)
                .font(.title2)
                .foregroundColor(Color(contact.type == .emergency911 ? "red" : "blue"))
                .frame(width: 40, height: 40)
                .background(Color(contact.type == .emergency911 ? "red" : "blue").opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(contact.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }

            Spacer()

            Button(action: onCall) {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                    Text("Call")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(contact.type == .emergency911 ? Color.red : Color.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Emergency Incident Card

struct EmergencyIncidentCard: View {
    let incidentType: EmergencyIncidentType
    let onReport: () -> Void
    let onViewProtocol: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: incidentType.icon)
                    .font(.title2)
                    .foregroundColor(Color(incidentType.category.color))
                    .frame(width: 40, height: 40)
                    .background(Color(incidentType.category.color).opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(incidentType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Tap to report incident or view emergency protocol")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: onReport) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Report")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }

                Button(action: onViewProtocol) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard")
                        Text("Protocol")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(incidentType.category.color))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(incidentType.category.color).opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Extensions

extension EmergencyIncidentType: Identifiable {
    public var id: String { self.rawValue }
}


#Preview {
    EmergencyActionView()
}