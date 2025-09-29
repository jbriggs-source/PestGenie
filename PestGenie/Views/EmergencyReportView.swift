import SwiftUI
import PhotosUI

struct EmergencyReportView: View {
    let incidentType: EmergencyIncidentType
    @ObservedObject var emergencyManager: EmergencyManager

    @Environment(\.dismiss) private var dismiss

    @State private var severity: EmergencySeverity = .medium
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var additionalNotes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []

    @State private var showingPhotoPicker = false
    @State private var showingCompletionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Incident Header
                    incidentHeader

                    // Severity Selector
                    severitySection

                    // Title Field
                    titleSection

                    // Description Field
                    descriptionSection

                    // Photo Attachment
                    photoSection

                    // Additional Notes
                    notesSection

                    // Location Info
                    locationSection
                }
                .padding()
            }
            .navigationTitle("Report Emergency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Report Submitted", isPresented: $showingCompletionAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your emergency report has been submitted and relevant contacts have been notified.")
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotos) {
            loadPhotos(from: selectedPhotos)
        }
        .onAppear {
            setupDefaultValues()
        }
    }

    // MARK: - Incident Header

    private var incidentHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: incidentType.icon)
                    .font(.title)
                    .foregroundColor(Color(incidentType.category.color))

                VStack(alignment: .leading, spacing: 4) {
                    Text(incidentType.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Emergency Incident Report")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text("Please provide details about the incident. This report will be sent to supervisors and relevant emergency contacts.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    // MARK: - Severity Section

    private var severitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Severity Level")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(EmergencySeverity.allCases, id: \.self) { level in
                    Button(action: {
                        severity = level
                    }) {
                        VStack(spacing: 4) {
                            Text(level.displayName)
                                .font(.subheadline)
                                .fontWeight(severity == level ? .bold : .medium)

                            Circle()
                                .fill(Color(level.color))
                                .frame(width: 12, height: 12)
                                .opacity(severity == level ? 1.0 : 0.3)
                        }
                        .foregroundColor(severity == level ? Color(level.color) : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(severity == level ? Color(level.color).opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Incident Title")
                .font(.headline)
                .fontWeight(.semibold)

            TextField("Brief summary of the incident", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
                .fontWeight(.semibold)

            TextField("Detailed description of what happened", text: $description, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    showingPhotoPicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Add Photos")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
            }

            if photos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("No photos added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photos[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()

                                Button(action: {
                                    photos.remove(at: index)
                                    selectedPhotos.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white, in: Circle())
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Notes")
                .font(.headline)
                .fontWeight(.semibold)

            TextField("Any additional information", text: $additionalNotes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)

                if let location = emergencyManager.currentLocation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Location")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Lat: \(location.coordinate.latitude, specifier: "%.6f"), Lon: \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Location not available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Update") {
                    emergencyManager.getCurrentLocation()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func setupDefaultValues() {
        title = "Emergency: \(incidentType.displayName)"

        // Set default severity based on incident type
        switch incidentType.category {
        case .safety:
            severity = .critical
        case .operational:
            severity = .medium
        case .customer:
            severity = .medium
        case .environmental:
            severity = .high
        case .compliance:
            severity = .high
        case .communication:
            severity = .low
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) {
        photos.removeAll()

        for item in items {
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        if let data = data, let image = UIImage(data: data) {
                            photos.append(image)
                        }
                    case .failure(let error):
                        print("Error loading photo: \(error)")
                    }
                }
            }
        }
    }

    private func submitReport() {
        emergencyManager.reportIncident(
            incidentType,
            severity: severity,
            title: title,
            description: description,
            photos: photos,
            additionalNotes: additionalNotes
        )

        showingCompletionAlert = true
    }
}

#Preview {
    EmergencyReportView(
        incidentType: .chemicalExposure,
        emergencyManager: EmergencyManager()
    )
}