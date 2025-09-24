import Foundation

enum ReasonCode: String, CaseIterable, Identifiable, Codable {
    case customerNotHome = "Customer not home"
    case weatherDelay = "Weather delay"
    case rescheduledAtCustomerRequest = "Rescheduled at customer request"
    case routeEfficiency = "Route efficiency"
    case unsafeWeatherConditions = "Unsafe weather conditions"
    case equipmentMalfunction = "Equipment malfunction"
    case chemicalAvailability = "Chemical not available"
    case other = "Other"

    var id: String { rawValue }
}