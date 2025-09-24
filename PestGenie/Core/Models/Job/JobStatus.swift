import Foundation

enum JobStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case skipped
}