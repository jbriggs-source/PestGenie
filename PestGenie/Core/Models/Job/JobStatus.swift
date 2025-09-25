import Foundation
import SwiftUI

enum JobStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case skipped

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .skipped: return .gray
        }
    }
}