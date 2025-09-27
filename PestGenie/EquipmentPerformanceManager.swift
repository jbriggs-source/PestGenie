import Foundation
import SwiftUI
import CoreData
import Combine

/// Equipment performance tracking and analytics manager
@MainActor
final class EquipmentPerformanceManager: ObservableObject {
    static let shared = EquipmentPerformanceManager()

    @Published var performanceMetrics: [EquipmentPerformanceMetric] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupNotificationObservers()
    }

    // MARK: - Performance Metrics Collection

    /// Record equipment usage for performance tracking
    func recordEquipmentUsage(_ usage: EquipmentUsage) async {
        await saveUsageRecord(usage)
        await updatePerformanceMetrics(for: usage.equipmentId)
        await checkMaintenanceThresholds(for: usage.equipmentId)
    }

    /// Record equipment maintenance event
    func recordMaintenanceEvent(_ maintenance: MaintenanceEvent) async {
        await saveMaintenanceRecord(maintenance)
        await updatePerformanceMetrics(for: maintenance.equipmentId)
        await updateEquipmentMaintenanceStatus(for: maintenance.equipmentId, maintenance: maintenance)
    }

    /// Record equipment calibration event
    func recordCalibrationEvent(_ calibration: CalibrationEvent) async {
        await saveCalibrationRecord(calibration)
        await updatePerformanceMetrics(for: calibration.equipmentId)
        await updateEquipmentCalibrationStatus(for: calibration.equipmentId, calibration: calibration)
    }

    /// Record equipment failure or issue
    func recordFailureEvent(_ failure: FailureEvent) async {
        await saveFailureRecord(failure)
        await updatePerformanceMetrics(for: failure.equipmentId)
        await scheduleMaintenanceIfNeeded(for: failure.equipmentId, failure: failure)
        await updateEquipmentReliabilityMetrics(for: failure.equipmentId, failure: failure)
    }

    /// Record inspection event
    func recordInspectionEvent(inspectionId: UUID) async {
        // TODO: Re-implement inspection tracking
        // Load inspection from digital inspection system
        // if let inspection = await DigitalInspectionManager.shared.completedInspections.first(where: { $0.id == inspectionId }) {
        //     let inspectionMetric = EquipmentPerformanceMetric(
        //         id: UUID(),
        //         equipmentId: inspection.equipmentId,
        //         metricType: .inspection,
        //         value: inspection.passed ? 100.0 : 0.0,
        //         unit: "score",
        //         timestamp: inspection.completedAt ?? inspection.scheduledDate
        //     )

        //     performanceMetrics.append(inspectionMetric)
        //     await updatePerformanceMetrics(for: inspection.equipmentId)

        //     // Update equipment inspection date
        //     await updateEquipmentInspectionDate(for: inspection.equipmentId, date: inspection.completedAt ?? inspection.scheduledDate)
        // }
    }

    /// Record equipment assignment/usage start
    func recordEquipmentAssignment(equipmentId: String, technicianId: String, jobId: String?) async {
        let usageStart = EquipmentUsage(
            equipmentId: equipmentId,
            hours: 0, // Will be updated when usage ends
            date: Date(),
            jobId: jobId,
            operatorId: technicianId,
            conditions: nil
        )

        await recordEquipmentUsage(usageStart)

        // Update equipment status to in-use
        await updateEquipmentStatus(equipmentId: equipmentId, status: EquipmentStatus.inUse, technicianId: technicianId)
    }

    /// Record equipment return/usage end
    func recordEquipmentReturn(equipmentId: String, totalHours: Double, condition: String? = nil) async {
        let usageEnd = EquipmentUsage(
            equipmentId: equipmentId,
            hours: totalHours,
            date: Date(),
            jobId: nil,
            operatorId: nil,
            conditions: nil
        )

        await recordEquipmentUsage(usageEnd)

        // Update equipment status back to available
        await updateEquipmentStatus(equipmentId: equipmentId, status: EquipmentStatus.available, technicianId: nil as String?)

        // Check if maintenance is needed based on usage
        await checkMaintenanceThresholds(for: equipmentId)
    }

    // MARK: - Performance Analytics

    /// Get performance summary for equipment
    func getPerformanceSummary(for equipmentId: String) async -> EquipmentPerformanceSummary? {
        return await calculatePerformanceSummary(equipmentId: equipmentId)
    }

    /// Get performance trends over time
    func getPerformanceTrends(for equipmentId: String, period: TimePeriod) async -> [PerformanceTrend] {
        return await calculatePerformanceTrends(equipmentId: equipmentId, period: period)
    }

    /// Get equipment efficiency metrics
    func getEfficiencyMetrics(for equipmentId: String) async -> EquipmentEfficiencyMetrics? {
        return await calculateEfficiencyMetrics(equipmentId: equipmentId)
    }

    /// Get maintenance effectiveness analytics
    func getMaintenanceEffectiveness(for equipmentId: String) async -> MaintenanceEffectiveness? {
        return await analyzeMaintenanceEffectiveness(equipmentId: equipmentId)
    }

    // MARK: - Predictive Analytics

    /// Predict next maintenance date based on usage patterns
    func predictNextMaintenanceDate(for equipmentId: String) async -> Date? {
        guard let summary = await getPerformanceSummary(for: equipmentId) else { return nil }

        let averageUsageHours = summary.totalUsageHours / max(Double(summary.usageDays), 1.0)
        let hoursUntilMaintenance = summary.maintenanceIntervalHours - summary.hoursSinceLastMaintenance

        if hoursUntilMaintenance <= 0 {
            return Date() // Maintenance overdue
        }

        let daysUntilMaintenance = hoursUntilMaintenance / max(averageUsageHours, 1.0)
        return Calendar.current.date(byAdding: .day, value: Int(daysUntilMaintenance), to: Date())
    }

    /// Predict equipment failure risk
    func predictFailureRisk(for equipmentId: String) async -> FailureRisk {
        guard let summary = await getPerformanceSummary(for: equipmentId) else {
            return FailureRisk.unknown
        }

        let metrics = await getEfficiencyMetrics(for: equipmentId)
        let maintenanceData = await getMaintenanceEffectiveness(for: equipmentId)

        return calculateFailureRisk(
            summary: summary,
            efficiency: metrics,
            maintenance: maintenanceData
        )
    }

    /// Generate maintenance recommendations
    func generateMaintenanceRecommendations(for equipmentId: String) async -> [MaintenanceRecommendation] {
        var recommendations: [MaintenanceRecommendation] = []

        let summary = await getPerformanceSummary(for: equipmentId)
        let efficiency = await getEfficiencyMetrics(for: equipmentId)
        let failureRisk = await predictFailureRisk(for: equipmentId)

        // Overdue maintenance check
        if let summary = summary, summary.hoursSinceLastMaintenance >= summary.maintenanceIntervalHours {
            recommendations.append(MaintenanceRecommendation(
                id: UUID(),
                type: .routine,
                priority: .high,
                description: "Routine maintenance is overdue",
                recommendedDate: Date()
            ))
        }

        // Efficiency degradation check
        if let efficiency = efficiency, efficiency.currentEfficiency < 0.8 {
            recommendations.append(MaintenanceRecommendation(
                id: UUID(),
                type: .corrective,
                priority: .medium,
                description: "Equipment efficiency has degraded to \(Int(efficiency.currentEfficiency * 100))%",
                recommendedDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            ))
        }

        // High failure risk check
        if failureRisk == .high || failureRisk == .critical {
            recommendations.append(MaintenanceRecommendation(
                id: UUID(),
                type: .preventive,
                priority: .high,
                description: "High failure risk detected - preventive maintenance recommended",
                recommendedDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            ))
        }

        return recommendations
    }

    // MARK: - Data Management

    private func saveUsageRecord(_ usage: EquipmentUsage) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentPerformanceEntity(context: context)
            entity.id = UUID()
            entity.equipment = nil // Would link to EquipmentEntity
            entity.metricName = "usage_hours"
            entity.metricValue = usage.hours
            entity.recordedDate = usage.date
            entity.createdDate = Date()
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            do {
                try context.save()
            } catch {
                print("Failed to save usage record: \(error)")
            }
        }
    }

    private func saveMaintenanceRecord(_ maintenance: MaintenanceEvent) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentMaintenanceEntity(context: context)
            entity.id = UUID()
            entity.equipment = nil // Would link to EquipmentEntity
            entity.maintenanceType = maintenance.type.rawValue
            entity.maintenanceDescription = maintenance.description
            entity.completedDate = maintenance.date
            entity.performedBy = maintenance.performedBy
            entity.cost = NSDecimalNumber(value: maintenance.cost)
            entity.notes = maintenance.notes
            entity.createdDate = Date()
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue
            entity.status = "completed"

            do {
                try context.save()
            } catch {
                print("Failed to save maintenance record: \(error)")
            }
        }
    }

    private func saveCalibrationRecord(_ calibration: CalibrationEvent) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentPerformanceEntity(context: context)
            entity.id = UUID()
            entity.equipment = nil // Would link to EquipmentEntity
            entity.metricName = "calibration"
            entity.metricValue = 1.0 // Calibration completed
            entity.recordedDate = calibration.date
            entity.createdDate = Date()
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            do {
                try context.save()
            } catch {
                print("Failed to save calibration record: \(error)")
            }
        }
    }

    private func saveFailureRecord(_ failure: FailureEvent) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentPerformanceEntity(context: context)
            entity.id = UUID()
            entity.equipment = nil // Would link to EquipmentEntity
            entity.metricName = "failure"
            entity.metricValue = Double(failure.severity.rawValue)
            entity.recordedDate = failure.date
            entity.createdDate = Date()
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            do {
                try context.save()
            } catch {
                print("Failed to save failure record: \(error)")
            }
        }
    }

    private func updatePerformanceMetrics(for equipmentId: String) async {
        // Recalculate and update performance metrics
        // This would involve complex analytics calculations
        print("Updating performance metrics for equipment: \(equipmentId)")
    }

    private func scheduleMaintenanceIfNeeded(for equipmentId: String, failure: FailureEvent) async {
        if failure.severity == .critical {
            // Schedule immediate maintenance
            let notificationManager = NotificationManager.shared
            await notificationManager.scheduleEquipmentMaintenanceReminder(
                equipmentId: equipmentId,
                equipmentName: "Critical Equipment", // Would get actual name
                dueDate: Date(),
                maintenanceType: "Emergency Repair"
            )
        }
    }

    // MARK: - Equipment Integration Methods

    private func checkMaintenanceThresholds(for equipmentId: String) async {
        guard let summary = await getPerformanceSummary(for: equipmentId) else { return }

        // Check if maintenance is due based on usage hours
        if summary.hoursSinceLastMaintenance >= summary.maintenanceIntervalHours {
            // Trigger maintenance notification
            let notificationManager = NotificationManager.shared
            await notificationManager.scheduleEquipmentMaintenanceReminder(
                equipmentId: equipmentId,
                equipmentName: "Equipment \(equipmentId)",
                dueDate: Date(),
                maintenanceType: "Routine Maintenance"
            )

            // Update equipment status
            await updateEquipmentStatus(equipmentId: equipmentId, status: EquipmentStatus.maintenance, technicianId: nil as String?)
        }
    }

    private func updateEquipmentMaintenanceStatus(for equipmentId: String, maintenance: MaintenanceEvent) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentEntity> = EquipmentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", equipmentId)

            do {
                if let equipment = try context.fetch(fetchRequest).first {
                    equipment.lastInspectionDate = maintenance.date
                    equipment.nextMaintenanceDate = Calendar.current.date(
                        byAdding: .day,
                        value: 30, // Default 30 days
                        to: maintenance.date
                    )
                    equipment.lastModified = Date()
                    equipment.syncStatus = SyncStatus.pending.rawValue

                    try context.save()
                }
            } catch {
                print("Failed to update equipment maintenance status: \(error)")
            }
        }
    }

    private func updateEquipmentCalibrationStatus(for equipmentId: String, calibration: CalibrationEvent) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentEntity> = EquipmentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", equipmentId)

            do {
                if let equipment = try context.fetch(fetchRequest).first {
                    equipment.lastCalibrationDate = calibration.date
                    equipment.nextCalibrationDate = Calendar.current.date(
                        byAdding: .month,
                        value: 6, // Default 6 months
                        to: calibration.date
                    )
                    equipment.lastModified = Date()
                    equipment.syncStatus = SyncStatus.pending.rawValue

                    try context.save()
                }
            } catch {
                print("Failed to update equipment calibration status: \(error)")
            }
        }
    }

    private func updateEquipmentReliabilityMetrics(for equipmentId: String, failure: FailureEvent) async {
        // Record failure metric
        let failureMetric = EquipmentPerformanceMetric(
            id: UUID(),
            equipmentId: equipmentId,
            metricType: .reliability,
            value: Double(failure.severity.rawValue),
            unit: "severity",
            timestamp: failure.date
        )

        performanceMetrics.append(failureMetric)

        // Calculate Mean Time Between Failures (MTBF)
        let recentFailures = performanceMetrics.filter {
            $0.equipmentId == equipmentId &&
            $0.metricType == .reliability &&
            $0.timestamp > Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        }

        if recentFailures.count > 1 {
            let mtbf = calculateMTBF(failures: recentFailures)
            let mtbfMetric = EquipmentPerformanceMetric(
                id: UUID(),
                equipmentId: equipmentId,
                metricType: .mtbf,
                value: mtbf,
                unit: "hours",
                timestamp: Date()
            )

            performanceMetrics.append(mtbfMetric)
        }
    }

    private func updateEquipmentStatus(equipmentId: String, status: EquipmentStatus, technicianId: String?) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentEntity> = EquipmentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", equipmentId)

            do {
                if let equipment = try context.fetch(fetchRequest).first {
                    equipment.status = status.rawValue
                    // Note: EquipmentEntity doesn't have assignedTechnicianId property
                    equipment.lastModified = Date()
                    equipment.syncStatus = SyncStatus.pending.rawValue

                    try context.save()
                }
            } catch {
                print("Failed to update equipment status: \(error)")
            }
        }
    }

    private func updateEquipmentInspectionDate(for equipmentId: String, date: Date) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentEntity> = EquipmentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", equipmentId)

            do {
                if let equipment = try context.fetch(fetchRequest).first {
                    equipment.lastInspectionDate = date
                    equipment.lastModified = Date()
                    equipment.syncStatus = SyncStatus.pending.rawValue

                    try context.save()
                }
            } catch {
                print("Failed to update equipment inspection date: \(error)")
            }
        }
    }

    private func calculateMTBF(failures: [EquipmentPerformanceMetric]) -> Double {
        guard failures.count > 1 else { return 0 }

        let sortedFailures = failures.sorted { $0.timestamp < $1.timestamp }
        var totalTimeBetweenFailures: TimeInterval = 0

        for i in 1..<sortedFailures.count {
            let timeBetween = sortedFailures[i].timestamp.timeIntervalSince(sortedFailures[i-1].timestamp)
            totalTimeBetweenFailures += timeBetween
        }

        let averageTimeBetweenFailures = totalTimeBetweenFailures / Double(failures.count - 1)
        return averageTimeBetweenFailures / 3600 // Convert to hours
    }

    // MARK: - Analytics Calculations

    private func calculatePerformanceSummary(equipmentId: String) async -> EquipmentPerformanceSummary? {
        // This would fetch data from Core Data and calculate summary metrics
        // For now, return sample data
        return EquipmentPerformanceSummary(
            equipmentId: equipmentId,
            totalUsageHours: 1240.5,
            usageDays: 89,
            maintenanceIntervalHours: 100.0,
            hoursSinceLastMaintenance: 45.2,
            numberOfFailures: 2,
            averageRepairTime: 3.5,
            efficiency: 0.92,
            availability: 0.98
        )
    }

    private func calculatePerformanceTrends(equipmentId: String, period: TimePeriod) async -> [PerformanceTrend] {
        // Calculate trends over specified time period
        var trends: [PerformanceTrend] = []

        let endDate = Date()
        let startDate = period.startDate(from: endDate)

        // Sample trend data
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            trends.append(PerformanceTrend(
                id: UUID(),
                date: currentDate,
                efficiency: Double.random(in: 0.85...0.95),
                usageHours: Double.random(in: 6...12),
                failures: Int.random(in: 0...1)
            ))

            currentDate = calendar.date(byAdding: period.calendarComponent, value: 1, to: currentDate) ?? endDate
        }

        return trends
    }

    private func calculateEfficiencyMetrics(equipmentId: String) async -> EquipmentEfficiencyMetrics? {
        // Calculate efficiency metrics based on usage and performance data
        return EquipmentEfficiencyMetrics(
            currentEfficiency: 0.89,
            averageEfficiency: 0.92,
            peakEfficiency: 0.98,
            efficiencyTrend: -0.03, // 3% decline
            targetEfficiency: 0.95
        )
    }

    private func analyzeMaintenanceEffectiveness(equipmentId: String) async -> MaintenanceEffectiveness? {
        return MaintenanceEffectiveness(
            scheduledMaintenanceCompliance: 0.95,
            averageMaintenanceTime: 2.5,
            maintenanceFrequency: 30, // days
            preventiveVsReactiveRatio: 0.8,
            costEffectiveness: 0.85
        )
    }

    private func calculateFailureRisk(
        summary: EquipmentPerformanceSummary,
        efficiency: EquipmentEfficiencyMetrics?,
        maintenance: MaintenanceEffectiveness?
    ) -> FailureRisk {
        var riskScore = 0.0

        // Usage-based risk
        if summary.hoursSinceLastMaintenance >= summary.maintenanceIntervalHours {
            riskScore += 0.3
        }

        // Efficiency-based risk
        if let efficiency = efficiency {
            if efficiency.currentEfficiency < 0.8 {
                riskScore += 0.3
            }
            if efficiency.efficiencyTrend < -0.05 {
                riskScore += 0.2
            }
        }

        // Failure history risk
        if summary.numberOfFailures > 5 {
            riskScore += 0.2
        }

        // Maintenance compliance risk
        if let maintenance = maintenance {
            if maintenance.scheduledMaintenanceCompliance < 0.8 {
                riskScore += 0.2
            }
        }

        switch riskScore {
        case 0.0..<0.2: return .low
        case 0.2..<0.4: return .medium
        case 0.4..<0.7: return .high
        case 0.7...: return .critical
        default: return .unknown
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .equipmentUsageUpdated)
            .sink { [weak self] notification in
                if let usage = notification.object as? EquipmentUsage {
                    Task {
                        await self?.recordEquipmentUsage(usage)
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .equipmentMaintenanceCompleted)
            .sink { [weak self] notification in
                if let maintenance = notification.object as? MaintenanceEvent {
                    Task {
                        await self?.recordMaintenanceEvent(maintenance)
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Data Models

/// Equipment usage tracking model
struct EquipmentUsage: Codable {
    let equipmentId: String
    let hours: Double
    let date: Date
    let jobId: String?
    let operatorId: String?
    let conditions: UsageConditions?
}

// Note: UsageConditions and WorkloadLevel are now defined in Models.swift

/// Maintenance event tracking
struct MaintenanceEvent: Codable {
    let equipmentId: String
    let type: MaintenanceType
    let description: String
    let date: Date
    let performedBy: String
    let cost: Double
    let notes: String?
}

// Note: MaintenanceType is now defined in Models.swift

/// Equipment calibration event
struct CalibrationEvent: Codable {
    let equipmentId: String
    let date: Date
    let performedBy: String
    let result: CalibrationResult
    let notes: String?
}

// Note: CalibrationResult is defined in Models.swift

/// Equipment failure event
struct FailureEvent: Codable {
    let equipmentId: String
    let date: Date
    let description: String
    let severity: FailureSeverity
    let cause: String?
    let resolution: String?
}

/// Failure severity levels
enum FailureSeverity: Int, CaseIterable, Codable {
    case minor = 1
    case moderate = 2
    case major = 3
    case critical = 4

    var description: String {
        switch self {
        case .minor: return "Minor"
        case .moderate: return "Moderate"
        case .major: return "Major"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .minor: return "yellow"
        case .moderate: return "orange"
        case .major: return "red"
        case .critical: return "purple"
        }
    }
}

/// Performance metric data point
struct EquipmentPerformanceMetric: Identifiable, Codable {
    let id: UUID
    let equipmentId: String
    let metricType: PerformanceMetricType
    let value: Double
    let unit: String
    let timestamp: Date
}

/// Types of performance metrics
enum PerformanceMetricType: String, CaseIterable, Codable {
    case efficiency = "efficiency"
    case uptime = "uptime"
    case throughput = "throughput"
    case energyConsumption = "energy_consumption"
    case errorRate = "error_rate"
    case temperature = "temperature"
    case vibration = "vibration"
    case pressure = "pressure"
    case reliability = "reliability"
    case mtbf = "mtbf" // Mean Time Between Failures
    case inspection = "inspection"
    case maintenance = "maintenance"
    case calibration = "calibration"
}

/// Equipment performance summary
struct EquipmentPerformanceSummary: Codable {
    let equipmentId: String
    let totalUsageHours: Double
    let usageDays: Int
    let maintenanceIntervalHours: Double
    let hoursSinceLastMaintenance: Double
    let numberOfFailures: Int
    let averageRepairTime: Double
    let efficiency: Double
    let availability: Double
}

/// Performance trend data point
struct PerformanceTrend: Identifiable, Codable {
    let id: UUID
    let date: Date
    let efficiency: Double
    let usageHours: Double
    let failures: Int
}

/// Equipment efficiency metrics
struct EquipmentEfficiencyMetrics: Codable {
    let currentEfficiency: Double
    let averageEfficiency: Double
    let peakEfficiency: Double
    let efficiencyTrend: Double // Rate of change
    let targetEfficiency: Double
}

/// Maintenance effectiveness analytics
struct MaintenanceEffectiveness: Codable {
    let scheduledMaintenanceCompliance: Double
    let averageMaintenanceTime: Double
    let maintenanceFrequency: Double // Days between maintenance
    let preventiveVsReactiveRatio: Double
    let costEffectiveness: Double
}

/// Equipment failure risk assessment
enum FailureRisk: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    case unknown = "unknown"

    var description: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .critical: return "Critical Risk"
        case .unknown: return "Unknown"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        case .unknown: return "gray"
        }
    }
}

/// Maintenance recommendation
struct MaintenanceRecommendation: Identifiable, Codable {
    let id: UUID
    let type: MaintenanceType
    let priority: MaintenancePriority
    let description: String
    let recommendedDate: Date
}

// Note: MaintenancePriority is now defined in Models.swift

/// Time period for analytics
enum TimePeriod: CaseIterable {
    case week
    case month
    case quarter
    case year

    var description: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .day
        case .quarter: return .weekOfYear
        case .year: return .month
        }
    }

    func startDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: date) ?? date
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: date) ?? date
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: date) ?? date
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let equipmentUsageUpdated = Notification.Name("equipmentUsageUpdated")
    static let equipmentMaintenanceCompleted = Notification.Name("equipmentMaintenanceCompleted")
    static let equipmentCalibrationCompleted = Notification.Name("equipmentCalibrationCompleted")
    static let equipmentFailureReported = Notification.Name("equipmentFailureReported")
}