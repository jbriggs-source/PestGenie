import Foundation
import CoreLocation

// MARK: - Health Data Models

/// Represents a health tracking session for a specific job
struct JobHealthSession: Identifiable, Codable {
    let id: UUID
    let jobId: UUID
    let customerName: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0

    // Step tracking
    let initialStepCount: Int
    var finalStepCount: Int = 0
    var currentStepCount: Int = 0
    var totalStepsWalked: Int = 0

    // Distance tracking
    let initialDistance: Double // in meters
    var finalDistance: Double = 0.0
    var currentDistance: Double = 0.0
    var totalDistanceWalked: Double = 0.0 // in meters

    // Additional metrics
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var caloriesBurned: Double = 0.0
    var activeMinutes: Int = 0

    // Environmental context
    var weatherConditions: String?
    var temperature: Double?

    /// Calculate session statistics
    var stepsPerMinute: Double {
        guard duration > 0 else { return 0 }
        return Double(totalStepsWalked) / (duration / 60.0)
    }

    var averageSpeedMetersPerSecond: Double {
        guard duration > 0 else { return 0 }
        return totalDistanceWalked / duration
    }

    var averageSpeedMPH: Double {
        return averageSpeedMetersPerSecond * 2.237 // Convert m/s to mph
    }

    /// Formatted display values
    var formattedDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        let distance = Measurement(value: totalDistanceWalked, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    var formattedAverageSpeed: String {
        return String(format: "%.1f mph", averageSpeedMPH)
    }

    /// Calculate efficiency score (0-100) based on activity level during job
    var efficiencyScore: Int {
        let expectedStepsPerHour = 3000.0 // Reasonable expectation for property inspection
        let actualStepsPerHour = duration > 0 ? Double(totalStepsWalked) / (duration / 3600.0) : 0
        let score = min(100, Int((actualStepsPerHour / expectedStepsPerHour) * 100))
        return max(0, score)
    }
}

/// Daily steps data for weekly statistics
struct DailyStepsData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let steps: Int

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Mon, Tue, etc.
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
}

/// Daily distance data for weekly statistics
struct DailyDistanceData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let distanceMeters: Double

    var distanceMiles: Double {
        return distanceMeters * 0.000621371 // Convert meters to miles
    }

    var formattedDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        let distance = Measurement(value: distanceMeters, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
}

/// Privacy settings for health tracking
struct HealthPrivacySettings: Codable {
    var allowHealthTracking: Bool = true
    var allowDataSharing: Bool = false
    var allowWeeklyReports: Bool = true
    var trackOnlyDuringJobs: Bool = true
    var shareWithAppleHealth: Bool = true

    /// Privacy levels
    enum PrivacyLevel: String, CaseIterable, Codable {
        case minimal = "minimal"
        case standard = "standard"
        case comprehensive = "comprehensive"

        var displayName: String {
            switch self {
            case .minimal: return "Minimal"
            case .standard: return "Standard"
            case .comprehensive: return "Comprehensive"
            }
        }

        var description: String {
            switch self {
            case .minimal:
                return "Track basic steps and distance only during jobs"
            case .standard:
                return "Track activity data and provide daily summaries"
            case .comprehensive:
                return "Full activity tracking with weekly reports and insights"
            }
        }
    }

    var privacyLevel: PrivacyLevel = .standard
}

/// Current activity summary for dashboard display
struct ActivitySummary {
    let currentSteps: Int
    let currentDistance: Double // meters
    let isActivelyWalking: Bool
    let sessionSteps: Int
    let sessionDistance: Double // meters
    let sessionDuration: TimeInterval
    let todaySteps: Int
    let todayDistance: Double // meters
    let weeklyAverage: Int

    /// Formatted display properties
    var formattedCurrentDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        let distance = Measurement(value: currentDistance, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    var formattedSessionDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        let distance = Measurement(value: sessionDistance, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    var formattedTodayDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        let distance = Measurement(value: todayDistance, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    var formattedSessionDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: sessionDuration) ?? "0m"
    }

    var activityStatus: ActivityStatus {
        if sessionSteps > 0 && isActivelyWalking {
            return .activeJob
        } else if sessionSteps > 0 {
            return .jobPaused
        } else if todaySteps > weeklyAverage {
            return .aboveAverage
        } else {
            return .normal
        }
    }
}

enum ActivityStatus {
    case activeJob
    case jobPaused
    case aboveAverage
    case normal

    var statusText: String {
        switch self {
        case .activeJob: return "Active on job"
        case .jobPaused: return "Job in progress"
        case .aboveAverage: return "Above average"
        case .normal: return "Normal activity"
        }
    }

    var statusColor: String {
        switch self {
        case .activeJob: return "green"
        case .jobPaused: return "orange"
        case .aboveAverage: return "blue"
        case .normal: return "gray"
        }
    }
}

/// Health insights and recommendations
struct HealthInsight: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let recommendation: String
    let priority: InsightPriority
    let icon: String

    enum InsightPriority {
        case low, medium, high

        var color: String {
            switch self {
            case .low: return "blue"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}

/// Weekly health report
struct WeeklyHealthReport {
    let weekStartDate: Date
    let weekEndDate: Date
    let totalSteps: Int
    let totalDistance: Double // meters
    let totalActiveTime: TimeInterval
    let averageDailySteps: Int
    let averageDailyDistance: Double // meters
    let jobSessions: [JobHealthSession]
    let insights: [HealthInsight]

    var weekRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: weekEndDate))"
    }

    var formattedTotalDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        let distance = Measurement(value: totalDistance, unit: UnitLength.meters)
        return formatter.string(from: distance)
    }

    var formattedTotalActiveTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter.string(from: totalActiveTime) ?? "0 minutes"
    }

    /// Generate insights based on weekly data
    static func generateInsights(from report: WeeklyHealthReport) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        // Step count insights
        if report.averageDailySteps > 10000 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Excellent Activity Level",
                description: "You're averaging \(report.averageDailySteps) steps per day, well above the recommended 10,000 steps.",
                recommendation: "Keep up the great work! This level of activity is excellent for cardiovascular health.",
                priority: .low,
                icon: "figure.walk"
            ))
        } else if report.averageDailySteps < 5000 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Low Activity Alert",
                description: "Your daily average of \(report.averageDailySteps) steps is below recommended levels.",
                recommendation: "Try to take short walks during breaks between jobs to increase daily activity.",
                priority: .high,
                icon: "exclamationmark.triangle"
            ))
        }

        // Distance insights
        let averageDailyMiles = (report.averageDailyDistance * 0.000621371) // Convert to miles
        if averageDailyMiles > 5.0 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "High Mobility Work",
                description: String(format: "You're walking an average of %.1f miles per day during jobs.", averageDailyMiles),
                recommendation: "Ensure you're wearing comfortable, supportive footwear for long walking periods.",
                priority: .medium,
                icon: "location.fill"
            ))
        }

        return insights
    }
}

// MARK: - Core Motion Integration Models

/// Activity recognition data from CoreMotion
struct ActivityRecognitionData {
    let timestamp: Date
    let isWalking: Bool
    let isRunning: Bool
    let isStationary: Bool
    let confidence: ActivityConfidence

    enum ActivityConfidence {
        case low, medium, high

        var description: String {
            switch self {
            case .low: return "Low confidence"
            case .medium: return "Medium confidence"
            case .high: return "High confidence"
            }
        }
    }
}

/// Pedometer data from CoreMotion
struct PedometerData {
    let startDate: Date
    let endDate: Date
    let steps: Int
    let distance: Double // meters
    let averageActivePace: Double? // seconds per meter
    let currentPace: Double? // seconds per meter
    let currentCadence: Double? // steps per second
    let floorsAscended: Int?
    let floorsDescended: Int?

    var formattedPace: String {
        guard let pace = averageActivePace else { return "N/A" }
        let minutesPerMile = pace * 1609.34 / 60.0 // Convert to minutes per mile
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d /mile", minutes, seconds)
    }
}

// MARK: - Health Data Export Models

/// Exportable health data for privacy compliance
struct HealthDataExport: Codable {
    let exportDate: Date
    let userId: String
    let sessions: [JobHealthSession]
    let privacySettings: HealthPrivacySettings
    let weeklyReports: [WeeklyHealthReportSummary]

    struct WeeklyHealthReportSummary: Codable {
        let weekStart: Date
        let totalSteps: Int
        let totalDistanceMeters: Double
        let totalActiveTimeSeconds: Double
    }

    /// Generate CSV export
    func generateCSV() -> String {
        var csv = "Date,Job ID,Customer,Steps,Distance (m),Duration (s),Calories\n"

        for session in sessions {
            let dateFormatter = ISO8601DateFormatter()
            let dateString = dateFormatter.string(from: session.startTime)

            csv += "\(dateString),\(session.jobId.uuidString),\(session.customerName),\(session.totalStepsWalked),\(session.totalDistanceWalked),\(session.duration),\(session.caloriesBurned)\n"
        }

        return csv
    }
}