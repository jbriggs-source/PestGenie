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

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

enum JobStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case skipped
}

enum ReasonCode: String, CaseIterable, Identifiable, Codable {
    case customerNotHome = "Customer not home"
    case weatherDelay = "Weather delay"
    case rescheduledAtCustomerRequest = "Rescheduled at customer request"
    case routeEfficiency = "Route efficiency"
    case other = "Other"

    var id: String { rawValue }
}