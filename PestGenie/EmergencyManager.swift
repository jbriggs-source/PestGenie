import Foundation
import CoreLocation
import UIKit

class EmergencyManager: NSObject, ObservableObject {
    @Published var emergencyContacts: [EmergencyResponseContact] = []
    @Published var recentIncidents: [EmergencyIncident] = []
    @Published var currentLocation: CLLocation?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        setupEmergencyContacts()
        setupLocationServices()
    }

    // MARK: - Emergency Contacts

    private func setupEmergencyContacts() {
        emergencyContacts = [
            EmergencyResponseContact(
                id: UUID(),
                name: "911 Emergency",
                phoneNumber: "911",
                type: .emergency911,
                description: "Police, Fire, Medical Emergency"
            ),
            EmergencyResponseContact(
                id: UUID(),
                name: "Poison Control",
                phoneNumber: "1-800-222-1222",
                type: .poisonControl,
                description: "Chemical exposure assistance"
            ),
            EmergencyResponseContact(
                id: UUID(),
                name: "Company Dispatch",
                phoneNumber: "1-800-PESTPRO",
                type: .companyDispatch,
                description: "PestGenie emergency dispatch"
            ),
            EmergencyResponseContact(
                id: UUID(),
                name: "Safety Supervisor",
                phoneNumber: "1-555-SAFETY1",
                type: .supervisor,
                description: "Field safety supervisor"
            ),
            EmergencyResponseContact(
                id: UUID(),
                name: "Environmental Hotline",
                phoneNumber: "1-800-EPA-SPILL",
                type: .environmental,
                description: "Chemical spill reporting"
            ),
            EmergencyResponseContact(
                id: UUID(),
                name: "Roadside Assistance",
                phoneNumber: "1-800-ROADHELP",
                type: .roadside,
                description: "Vehicle breakdown assistance"
            )
        ]
    }

    // MARK: - Location Services

    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func getCurrentLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }

        locationManager.requestLocation()
    }

    // MARK: - Emergency Actions

    func callEmergencyContact(_ contact: EmergencyResponseContact) {
        guard let phoneURL = URL(string: "tel://\(contact.phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") else {
            return
        }

        if UIApplication.shared.canOpenURL(phoneURL) {
            UIApplication.shared.open(phoneURL)

            // Log the emergency call
            let incident = EmergencyIncident(
                id: UUID(),
                type: EmergencyIncidentType.emergencyCall,
                severity: EmergencySeverity.high,
                title: "Emergency Call Made",
                description: "Called \(contact.name) at \(contact.phoneNumber)",
                location: currentLocation,
                timestamp: Date(),
                status: EmergencyIncidentStatus.active,
                contactCalled: contact,
                photos: [],
                additionalNotes: ""
            )

            recordIncident(incident)
        }
    }

    func reportIncident(_ type: EmergencyIncidentType, severity: EmergencySeverity, title: String, description: String, photos: [UIImage] = [], additionalNotes: String = "") {
        getCurrentLocation()

        let incident = EmergencyIncident(
            id: UUID(),
            type: type,
            severity: severity,
            title: title,
            description: description,
            location: currentLocation,
            timestamp: Date(),
            status: EmergencyIncidentStatus.active,
            contactCalled: nil,
            photos: photos,
            additionalNotes: additionalNotes
        )

        recordIncident(incident)

        // Auto-notify appropriate contacts based on incident type
        notifyRelevantContacts(for: incident)
    }

    private func recordIncident(_ incident: EmergencyIncident) {
        recentIncidents.insert(incident, at: 0)

        // Keep only the last 50 incidents
        if recentIncidents.count > 50 {
            recentIncidents = Array(recentIncidents.prefix(50))
        }

        // Save to persistent storage (Core Data, UserDefaults, etc.)
        saveIncidentToPersistentStorage(incident)
    }

    private func notifyRelevantContacts(for incident: EmergencyIncident) {
        let relevantContacts = getRelevantContacts(for: incident.type)

        // In a real implementation, this would send notifications
        // to supervisors, dispatch, etc. via push notifications or SMS
        print("Notifying relevant contacts for \(incident.type): \(relevantContacts.map { $0.name })")
    }

    private func getRelevantContacts(for incidentType: EmergencyIncidentType) -> [EmergencyResponseContact] {
        switch incidentType {
        case .chemicalExposure, .chemicalSpill:
            return emergencyContacts.filter { $0.type == .poisonControl || $0.type == .environmental || $0.type == .supervisor }
        case .medicalEmergency, .technicianInjury:
            return emergencyContacts.filter { $0.type == .emergency911 || $0.type == .supervisor }
        case .equipmentMalfunction, .vehicleBreakdown:
            return emergencyContacts.filter { $0.type == .companyDispatch || $0.type == .roadside }
        case .propertyDamage, .customerSafety:
            return emergencyContacts.filter { $0.type == .supervisor || $0.type == .companyDispatch }
        case .severeInfestation:
            return emergencyContacts.filter { $0.type == .supervisor || $0.type == .companyDispatch }
        case .weatherDelay, .accessIssue:
            return emergencyContacts.filter { $0.type == .companyDispatch }
        case .epaViolation, .complianceIssue:
            return emergencyContacts.filter { $0.type == .environmental || $0.type == .supervisor }
        case .emergencyCall:
            return []
        }
    }

    private func saveIncidentToPersistentStorage(_ incident: EmergencyIncident) {
        // In a real implementation, save to Core Data or other persistent storage
        // For now, we'll use UserDefaults as a simple example
        do {
            let data = try JSONEncoder().encode(incident)
            let key = "emergency_incident_\(incident.id.uuidString)"
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save incident: \(error)")
        }
    }

    // MARK: - Emergency Protocols

    func getEmergencyProtocol(for type: EmergencyIncidentType) -> EmergencyProtocol {
        switch type {
        case .chemicalExposure:
            return EmergencyProtocol(
                title: "Chemical Exposure Protocol",
                steps: [
                    "1. Remove contaminated clothing immediately",
                    "2. Flush affected area with water for 15-20 minutes",
                    "3. Call Poison Control: 1-800-222-1222",
                    "4. Do not induce vomiting unless instructed",
                    "5. Seek immediate medical attention",
                    "6. Report incident to supervisor immediately"
                ],
                criticalContacts: emergencyContacts.filter { $0.type == .poisonControl || $0.type == .emergency911 }
            )
        case .chemicalSpill:
            return EmergencyProtocol(
                title: "Chemical Spill Protocol",
                steps: [
                    "1. Evacuate area immediately",
                    "2. Prevent further spread - do not clean up alone",
                    "3. Call Environmental Hotline: 1-800-EPA-SPILL",
                    "4. Alert nearby personnel",
                    "5. Take photos from safe distance",
                    "6. Contact supervisor and dispatch immediately"
                ],
                criticalContacts: emergencyContacts.filter { $0.type == .environmental || $0.type == .supervisor }
            )
        case .medicalEmergency:
            return EmergencyProtocol(
                title: "Medical Emergency Protocol",
                steps: [
                    "1. Call 911 immediately",
                    "2. Do not move injured person unless in immediate danger",
                    "3. Apply first aid if trained",
                    "4. Stay with person until help arrives",
                    "5. Contact supervisor immediately",
                    "6. Document incident details"
                ],
                criticalContacts: emergencyContacts.filter { $0.type == .emergency911 || $0.type == .supervisor }
            )
        case .equipmentMalfunction:
            return EmergencyProtocol(
                title: "Equipment Malfunction Protocol",
                steps: [
                    "1. Stop using equipment immediately",
                    "2. Secure area if chemical leak present",
                    "3. Take photos of malfunction",
                    "4. Report to dispatch immediately",
                    "5. Do not attempt repairs in field",
                    "6. Request replacement equipment"
                ],
                criticalContacts: emergencyContacts.filter { $0.type == .companyDispatch }
            )
        default:
            return EmergencyProtocol(
                title: "General Emergency Protocol",
                steps: [
                    "1. Ensure personal safety first",
                    "2. Call appropriate emergency contacts",
                    "3. Document incident with photos",
                    "4. Report to supervisor immediately",
                    "5. Follow company emergency procedures"
                ],
                criticalContacts: [emergencyContacts.first { $0.type == .supervisor }].compactMap { $0 }
            )
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension EmergencyManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            getCurrentLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            requestLocationPermission()
        @unknown default:
            break
        }
    }
}