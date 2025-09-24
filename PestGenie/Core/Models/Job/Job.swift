import Foundation
import CoreLocation

/// Represents a service job that a technician must perform. Conforms to
/// `Identifiable` and `Codable` for easy binding and persistence.
struct Job: Identifiable, Codable, Equatable {
    let id: UUID
    var customerName: String
    var address: String
    var scheduledDate: Date
    var latitude: Double?
    var longitude: Double?
    var notes: String?
    var pinnedNotes: String?
    var status: JobStatus
    var startTime: Date?
    var completionTime: Date?
    var signatureData: Data?
    var weatherAtStart: WeatherSnapshot?
    var weatherAtCompletion: WeatherSnapshot?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}