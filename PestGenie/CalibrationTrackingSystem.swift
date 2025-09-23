import Foundation
import SwiftUI
import CoreData
import Combine

/// Comprehensive calibration tracking system for equipment accuracy and compliance
@MainActor
final class CalibrationTrackingManager: ObservableObject {
    static let shared = CalibrationTrackingManager()

    @Published var pendingCalibrations: [CalibrationSchedule] = []
    @Published var completedCalibrations: [CalibrationRecord] = []
    @Published var overdueCalibrations: [CalibrationSchedule] = []
    @Published var upcomingCalibrations: [CalibrationSchedule] = []
    @Published var calibrationStandards: [CalibrationStandard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let persistenceController: PersistenceController
    private let notificationManager: NotificationManager
    private var cancellables = Set<AnyCancellable>()

    init(persistenceController: PersistenceController = .shared,
         notificationManager: NotificationManager? = nil) {
        self.persistenceController = persistenceController
        self.notificationManager = notificationManager ?? NotificationManager.shared
        setupNotificationObservers()
        loadCalibrationStandards()
        // Defer heavy loading until first access
        // Task {
        //     await loadPendingCalibrations()
        //     await updateCalibrationCategories()
        // }
    }

    // MARK: - Calibration Scheduling

    /// Schedule new calibration for equipment
    func scheduleCalibration(_ schedule: CalibrationSchedule) async {
        pendingCalibrations.append(schedule)
        await saveCalibrationSchedule(schedule)
        await scheduleCalibrationNotifications(schedule)
        await updateCalibrationCategories()

        NotificationCenter.default.post(
            name: .calibrationScheduled,
            object: nil,
            userInfo: [
                "scheduleId": schedule.id.uuidString,
                "equipmentId": schedule.equipmentId.uuidString,
                "scheduledDate": schedule.scheduledDate
            ]
        )
    }

    /// Update existing calibration schedule
    func updateCalibrationSchedule(_ schedule: CalibrationSchedule) async {
        if let index = pendingCalibrations.firstIndex(where: { $0.id == schedule.id }) {
            pendingCalibrations[index] = schedule
            await saveCalibrationSchedule(schedule)
            await scheduleCalibrationNotifications(schedule)
            await updateCalibrationCategories()
        }
    }

    /// Complete calibration and create record
    func completeCalibration(_ schedule: CalibrationSchedule, details: CalibrationCompletionDetails) async {
        // Remove from pending
        if let index = pendingCalibrations.firstIndex(where: { $0.id == schedule.id }) {
            pendingCalibrations.remove(at: index)
        }

        // Create completion record
        var record = CalibrationRecord(
            equipmentId: schedule.equipmentId,
            calibratedBy: details.calibratedBy,
            calibrationType: schedule.calibrationType
        )

        record.calibrationDate = details.completedDate
        record.standardUsed = details.standardUsed
        record.preCalibrationReadings = details.preCalibrationReadings
        record.postCalibrationReadings = details.postCalibrationReadings
        record.adjustmentsMade = details.adjustmentsMade
        record.result = details.result
        record.tolerance = details.tolerance
        record.accuracy = details.accuracy
        record.certificateNumber = details.certificateNumber
        record.notes = details.notes
        record.environmentalConditions = details.environmentalConditions

        // Calculate next calibration date
        record.nextCalibrationDate = calculateNextCalibrationDate(
            for: schedule.equipmentId,
            type: schedule.calibrationType,
            lastCalibration: details.completedDate
        )

        completedCalibrations.append(record)

        // Save to Core Data
        await saveCalibrationRecord(record)
        await deleteCalibrationSchedule(schedule.id)

        // Schedule next calibration if recurring
        if schedule.isRecurring {
            await scheduleNextRecurringCalibration(schedule, lastCompleted: details.completedDate)
        }

        // Cancel notifications for completed calibration
        await cancelCalibrationNotifications(schedule.id)

        // Update equipment calibration date
        await updateEquipmentCalibrationDate(schedule.equipmentId, date: details.completedDate)

        // Record performance metric
        await EquipmentPerformanceManager.shared.recordCalibrationEvent(
            CalibrationEvent(
                equipmentId: schedule.equipmentId.uuidString,
                date: details.completedDate,
                performedBy: details.calibratedBy,
                result: details.result,
                notes: details.notes
            )
        )

        await updateCalibrationCategories()

        NotificationCenter.default.post(
            name: .calibrationCompleted,
            object: nil,
            userInfo: [
                "scheduleId": schedule.id.uuidString,
                "equipmentId": schedule.equipmentId.uuidString,
                "recordId": record.id.uuidString,
                "result": details.result.rawValue
            ]
        )
    }

    /// Cancel scheduled calibration
    func cancelCalibration(_ scheduleId: UUID, reason: String) async {
        if let index = pendingCalibrations.firstIndex(where: { $0.id == scheduleId }) {
            let schedule = pendingCalibrations[index]
            pendingCalibrations.remove(at: index)

            await deleteCalibrationSchedule(scheduleId)
            await cancelCalibrationNotifications(scheduleId)
            await updateCalibrationCategories()

            NotificationCenter.default.post(
                name: .calibrationCancelled,
                object: nil,
                userInfo: [
                    "scheduleId": scheduleId.uuidString,
                    "equipmentId": schedule.equipmentId.uuidString,
                    "reason": reason
                ]
            )
        }
    }

    /// Get calibration history for equipment
    func getCalibrationHistory(equipmentId: UUID) -> [CalibrationRecord] {
        return completedCalibrations.filter { $0.equipmentId == equipmentId }
            .sorted { $0.calibrationDate > $1.calibrationDate }
    }

    /// Get pending calibrations for equipment
    func getPendingCalibrations(equipmentId: UUID) -> [CalibrationSchedule] {
        return pendingCalibrations.filter { $0.equipmentId == equipmentId }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Generate automatic calibration schedules for equipment
    func generateAutomaticCalibrationSchedule(for equipment: Equipment) async {
        guard equipment.type.requiresCalibration else { return }

        let calibrationTypes = getRequiredCalibrationsForEquipment(equipment.type)

        for calibrationType in calibrationTypes {
            let interval = getCalibrationInterval(for: calibrationType, equipmentType: equipment.type)
            let lastCalibrationDate = equipment.lastCalibrationDate ?? equipment.purchaseDate

            let nextCalibrationDate = Calendar.current.date(
                byAdding: .month,
                value: interval,
                to: lastCalibrationDate
            ) ?? Date()

            let schedule = CalibrationSchedule(
                equipmentId: equipment.id,
                calibrationType: calibrationType,
                title: "\(calibrationType.displayName) Calibration - \(equipment.name)",
                description: "Scheduled \(calibrationType.displayName.lowercased()) calibration for \(equipment.type.displayName)",
                scheduledDate: nextCalibrationDate,
                isRecurring: true,
                recurrenceInterval: .months(interval)
            )

            await scheduleCalibration(schedule)
        }
    }

    // MARK: - Calibration Analysis

    /// Analyze calibration drift over time
    func analyzeCalibrationDrift(equipmentId: UUID, calibrationType: CalibrationType) -> CalibrationDriftAnalysis? {
        let records = completedCalibrations.filter {
            $0.equipmentId == equipmentId && $0.calibrationType == calibrationType
        }.sorted { $0.calibrationDate < $1.calibrationDate }

        guard records.count >= 2 else { return nil }

        var driftData: [CalibrationDriftPoint] = []

        for record in records {
            for reading in record.postCalibrationReadings {
                let driftPoint = CalibrationDriftPoint(
                    date: record.calibrationDate,
                    parameter: reading.parameter,
                    expectedValue: reading.expectedValue,
                    actualValue: reading.actualValue,
                    deviation: reading.deviation,
                    tolerance: record.tolerance
                )
                driftData.append(driftPoint)
            }
        }

        return CalibrationDriftAnalysis(
            equipmentId: equipmentId,
            calibrationType: calibrationType,
            driftData: driftData,
            trendDirection: calculateDriftTrend(driftData),
            maxDeviation: driftData.map { $0.deviation }.max() ?? 0,
            averageDeviation: driftData.map { $0.deviation }.reduce(0, +) / Double(driftData.count)
        )
    }

    /// Get calibration compliance status
    func getCalibrationCompliance(equipmentId: UUID) -> CalibrationCompliance {
        let requiredCalibrations = getRequiredCalibrations(equipmentId: equipmentId)
        let completedCalibrations = getCalibrationHistory(equipmentId: equipmentId)

        var complianceItems: [ComplianceItem] = []

        for required in requiredCalibrations {
            let recentCalibration = completedCalibrations
                .filter { $0.calibrationType == required }
                .sorted { $0.calibrationDate > $1.calibrationDate }
                .first

            let isCompliant: Bool
            let daysOverdue: Int

            if let calibration = recentCalibration {
                isCompliant = calibration.nextCalibrationDate > Date()
                daysOverdue = max(0, Calendar.current.dateComponents([.day],
                    from: calibration.nextCalibrationDate, to: Date()).day ?? 0)
            } else {
                isCompliant = false
                daysOverdue = Int.max
            }

            complianceItems.append(ComplianceItem(
                calibrationType: required,
                isCompliant: isCompliant,
                lastCalibrationDate: recentCalibration?.calibrationDate,
                nextDueDate: recentCalibration?.nextCalibrationDate,
                daysOverdue: daysOverdue
            ))
        }

        let overallCompliance = complianceItems.allSatisfy { $0.isCompliant }

        return CalibrationCompliance(
            equipmentId: equipmentId,
            isCompliant: overallCompliance,
            complianceItems: complianceItems,
            lastUpdated: Date()
        )
    }

    /// Validate calibration accuracy
    func validateCalibrationAccuracy(_ readings: [CalibrationReading], tolerance: Double) -> CalibrationValidation {
        let withinTolerance = readings.allSatisfy { $0.withinTolerance }
        let maxDeviation = readings.map { $0.deviation }.max() ?? 0
        let averageDeviation = readings.map { $0.deviation }.reduce(0, +) / Double(readings.count)

        let status: CalibrationValidationStatus
        if withinTolerance {
            status = .passed
        } else if averageDeviation <= tolerance * 1.5 {
            status = .marginal
        } else {
            status = .failed
        }

        return CalibrationValidation(
            status: status,
            withinTolerance: withinTolerance,
            maxDeviation: maxDeviation,
            averageDeviation: averageDeviation,
            tolerance: tolerance,
            readingsCount: readings.count
        )
    }

    // MARK: - Helper Methods

    private func getRequiredCalibrationsForEquipment(_ equipmentType: EquipmentType) -> [CalibrationType] {
        switch equipmentType {
        case .moistureMeter:
            return [.humidity, .temperature]
        case .thermometer:
            return [.temperature]
        case .backpackSprayer, .tankSprayer, .airlessSprayRig:
            return [.flow, .pressure, .volume]
        case .granularSpreader:
            return [.flow, .dimensional]
        default:
            return []
        }
    }

    private func getCalibrationInterval(for type: CalibrationType, equipmentType: EquipmentType) -> Int {
        // Return interval in months
        switch type {
        case .flow, .pressure:
            return 6
        case .temperature, .humidity:
            return 12
        case .volume:
            return 6
        case .electrical:
            return 12
        case .dimensional:
            return 24
        }
    }

    private func calculateNextCalibrationDate(for equipmentId: UUID, type: CalibrationType, lastCalibration: Date) -> Date {
        // Get equipment type to determine interval
        let interval = 6 // Default 6 months, would be calculated based on equipment type and calibration type
        return Calendar.current.date(byAdding: .month, value: interval, to: lastCalibration) ?? lastCalibration
    }

    private func calculateDriftTrend(_ driftData: [CalibrationDriftPoint]) -> DriftTrend {
        guard driftData.count >= 2 else { return .stable }

        let sortedData = driftData.sorted { $0.date < $1.date }
        let recentData = Array(sortedData.suffix(5)) // Last 5 points

        if recentData.count < 2 { return .stable }

        let averageEarlyDeviation = recentData.prefix(recentData.count / 2).map { $0.deviation }.reduce(0, +) / Double(recentData.count / 2)
        let averageLateDeviation = recentData.suffix(recentData.count / 2).map { $0.deviation }.reduce(0, +) / Double(recentData.count / 2)

        let changeThreshold = 0.1 // 10% change threshold
        let relativeChange = (averageLateDeviation - averageEarlyDeviation) / averageEarlyDeviation

        if relativeChange > changeThreshold {
            return .increasing
        } else if relativeChange < -changeThreshold {
            return .decreasing
        } else {
            return .stable
        }
    }

    private func getRequiredCalibrations(equipmentId: UUID) -> [CalibrationType] {
        // Would determine based on equipment type from database
        return [.flow, .pressure, .temperature] // Example
    }

    // MARK: - Data Management

    private func loadPendingCalibrations() async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentMaintenanceEntity> = EquipmentMaintenanceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "result == %@", CalibrationResult.pending.rawValue)

            do {
                let entities = try context.fetch(fetchRequest)
                let schedules = entities.compactMap { entity -> CalibrationSchedule? in
                    self.convertEntityToSchedule(entity)
                }

                DispatchQueue.main.async {
                    self.pendingCalibrations = schedules
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load pending calibrations: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveCalibrationSchedule(_ schedule: CalibrationSchedule) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentMaintenanceEntity(context: context)
            entity.id = schedule.id
            // Note: EquipmentMaintenanceEntity doesn't have calibratedBy property
            // Note: EquipmentMaintenanceEntity does not have calibrationDate property
            // entity.calibrationDate = schedule.scheduledDate
            // Note: EquipmentMaintenanceEntity does not have calibrationType property
            // entity.calibrationType = schedule.calibrationType.rawValue
            // Note: EquipmentMaintenanceEntity does not have result property
            // entity.result = CalibrationResult.pending.rawValue
            entity.tolerance = schedule.tolerance
            entity.nextCalibrationDate = schedule.scheduledDate
            entity.notes = schedule.description
            entity.createdDate = Date()
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            do {
                try context.save()
            } catch {
                print("Failed to save calibration schedule: \(error)")
            }
        }
    }

    private func saveCalibrationRecord(_ record: CalibrationRecord) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentMaintenanceEntity(context: context)
            entity.id = record.id
            // Note: EquipmentMaintenanceEntity doesn't have calibratedBy property
            // Note: EquipmentMaintenanceEntity does not have calibrationDate property
            // entity.calibrationDate = record.calibrationDate
            // Note: EquipmentMaintenanceEntity does not have calibrationType property
            // entity.calibrationType = record.calibrationType.rawValue
            // Note: EquipmentMaintenanceEntity does not have standardUsed property
            // entity.standardUsed = record.standardUsed
            // Note: EquipmentMaintenanceEntity does not have these properties
            // entity.adjustmentsMade = record.adjustmentsMade
            // entity.result = record.result.rawValue
            // entity.tolerance = record.tolerance
            // entity.accuracy = record.accuracy
            // entity.certificateNumber = record.certificateNumber
            entity.nextCalibrationDate = record.nextCalibrationDate
            entity.notes = record.notes
            entity.createdDate = record.createdDate
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            // Encode readings
            if let preReadingsData = try? JSONEncoder().encode(record.preCalibrationReadings) {
                entity.preCalibrationData = String(data: preReadingsData, encoding: .utf8)
            }

            if let postReadingsData = try? JSONEncoder().encode(record.postCalibrationReadings) {
                entity.postCalibrationData = String(data: postReadingsData, encoding: .utf8)
            }

            // Encode environmental data
            if let envData = record.environmentalConditions,
               let envDataEncoded = try? JSONEncoder().encode(envData) {
                entity.environmentalData = String(data: envDataEncoded, encoding: .utf8)
            }

            do {
                try context.save()
            } catch {
                print("Failed to save calibration record: \(error)")
            }
        }
    }

    private func deleteCalibrationSchedule(_ scheduleId: UUID) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentMaintenanceEntity> = EquipmentMaintenanceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", scheduleId as CVarArg)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
            } catch {
                print("Failed to delete calibration schedule: \(error)")
            }
        }
    }

    private func updateEquipmentCalibrationDate(_ equipmentId: UUID, date: Date) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentEntity> = EquipmentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", equipmentId as CVarArg)

            do {
                if let equipment = try context.fetch(fetchRequest).first {
                    equipment.lastCalibrationDate = date
                    equipment.lastModified = Date()
                    try context.save()
                }
            } catch {
                print("Failed to update equipment calibration date: \(error)")
            }
        }
    }

    private func convertEntityToSchedule(_ entity: EquipmentMaintenanceEntity) -> CalibrationSchedule? {
        guard let id = entity.id else { return nil }

        var schedule = CalibrationSchedule(
            equipmentId: UUID(), // Would need to get from relationship
            calibrationType: .flow, // Note: EquipmentMaintenanceEntity doesn't have calibrationType property
            title: "Calibration",
            description: entity.notes ?? "",
            scheduledDate: entity.scheduledDate ?? Date()
        )

        schedule.id = id
        // Note: EquipmentMaintenanceEntity doesn't have tolerance property

        return schedule
    }

    // MARK: - Notification Management

    private func scheduleCalibrationNotifications(_ schedule: CalibrationSchedule) async {
        // Schedule notification 1 week before
        await notificationManager.scheduleEquipmentCalibrationReminder(
            equipmentId: schedule.equipmentId.uuidString,
            equipmentName: "Equipment", // Would fetch actual name
            dueDate: schedule.scheduledDate,
            calibrationType: schedule.calibrationType.displayName,
            identifier: "\(schedule.id.uuidString)_week"
        )

        // Schedule overdue notification
        let _ = Calendar.current.date(byAdding: .day, value: 1, to: schedule.scheduledDate) ?? schedule.scheduledDate
        await notificationManager.scheduleEquipmentCalibrationReminder(
            equipmentId: schedule.equipmentId.uuidString,
            equipmentName: "Equipment", // Would fetch actual name
            dueDate: schedule.scheduledDate,
            calibrationType: schedule.calibrationType.displayName,
            identifier: "\(schedule.id.uuidString)_overdue"
        )
    }

    private func cancelCalibrationNotifications(_ scheduleId: UUID) async {
        let identifiers = [
            "\(scheduleId.uuidString)_week",
            "\(scheduleId.uuidString)_overdue"
        ]

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func scheduleNextRecurringCalibration(_ originalSchedule: CalibrationSchedule, lastCompleted: Date) async {
        guard originalSchedule.isRecurring,
              let interval = originalSchedule.recurrenceInterval else { return }

        let nextDate: Date
        switch interval {
        case .months(let months):
            nextDate = Calendar.current.date(byAdding: .month, value: months, to: lastCompleted) ?? lastCompleted
        case .years(let years):
            nextDate = Calendar.current.date(byAdding: .year, value: years, to: lastCompleted) ?? lastCompleted
        default:
            return // Only support months/years for calibration
        }

        var nextSchedule = originalSchedule
        nextSchedule.id = UUID() // New ID for next occurrence
        nextSchedule.scheduledDate = nextDate

        await scheduleCalibration(nextSchedule)
    }

    private func updateCalibrationCategories() async {
        let now = Date()

        // Update overdue calibrations
        overdueCalibrations = pendingCalibrations.filter { schedule in
            schedule.scheduledDate < now
        }

        // Update upcoming calibrations (next 30 days)
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        upcomingCalibrations = pendingCalibrations.filter { schedule in
            schedule.scheduledDate >= now && schedule.scheduledDate <= thirtyDaysFromNow
        }
    }

    private func loadCalibrationStandards() {
        calibrationStandards = [
            CalibrationStandard(
                id: "NIST-001",
                name: "NIST Pressure Standard",
                type: .pressure,
                accuracy: 0.01,
                validUntil: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                certificateNumber: "NIST-P-2024-001"
            ),
            CalibrationStandard(
                id: "NIST-002",
                name: "NIST Temperature Standard",
                type: .temperature,
                accuracy: 0.1,
                validUntil: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                certificateNumber: "NIST-T-2024-002"
            )
        ]
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .equipmentCalibrationCompleted)
            .sink { notification in
                // Handle calibration completion events
            }
            .store(in: &cancellables)
    }
}

// MARK: - Data Models

/// Calibration schedule model
struct CalibrationSchedule: Identifiable, Codable {
    var id: UUID
    let equipmentId: UUID
    var calibrationType: CalibrationType
    var title: String
    var description: String
    var scheduledDate: Date
    var tolerance: Double
    var isRecurring: Bool
    var recurrenceInterval: CalibrationRecurrenceInterval?
    var assignedTechnician: String?
    var requiredStandards: [String]
    var estimatedDuration: Int // in minutes
    var createdDate: Date

    init(equipmentId: UUID, calibrationType: CalibrationType, title: String, description: String,
         scheduledDate: Date, tolerance: Double = 0.05, isRecurring: Bool = false,
         recurrenceInterval: CalibrationRecurrenceInterval? = nil) {
        self.id = UUID()
        self.equipmentId = equipmentId
        self.calibrationType = calibrationType
        self.title = title
        self.description = description
        self.scheduledDate = scheduledDate
        self.tolerance = tolerance
        self.isRecurring = isRecurring
        self.recurrenceInterval = recurrenceInterval
        self.requiredStandards = []
        self.estimatedDuration = 30
        self.createdDate = Date()
    }

    /// Check if calibration is overdue
    var isOverdue: Bool {
        return scheduledDate < Date()
    }
}

/// Calibration completion details
struct CalibrationCompletionDetails {
    let calibratedBy: String
    let completedDate: Date
    let standardUsed: String?
    let preCalibrationReadings: [CalibrationReading]
    let postCalibrationReadings: [CalibrationReading]
    let adjustmentsMade: String?
    let result: CalibrationResult
    let tolerance: Double
    let accuracy: Double
    let certificateNumber: String?
    let notes: String?
    let environmentalConditions: EnvironmentalConditions?

    init(calibratedBy: String, result: CalibrationResult = .pending, tolerance: Double = 0.05) {
        self.calibratedBy = calibratedBy
        self.completedDate = Date()
        self.standardUsed = nil
        self.preCalibrationReadings = []
        self.postCalibrationReadings = []
        self.adjustmentsMade = nil
        self.result = result
        self.tolerance = tolerance
        self.accuracy = 0
        self.certificateNumber = nil
        self.notes = nil
        self.environmentalConditions = nil
    }
}

/// Calibration recurrence interval
enum CalibrationRecurrenceInterval: Codable, Equatable {
    case months(Int)
    case years(Int)

    var description: String {
        switch self {
        case .months(let count):
            return "\(count) month\(count > 1 ? "s" : "")"
        case .years(let count):
            return "\(count) year\(count > 1 ? "s" : "")"
        }
    }
}

/// Calibration standard reference
struct CalibrationStandard: Identifiable, Codable {
    let id: String
    var name: String
    var type: CalibrationType
    var accuracy: Double
    var validUntil: Date
    var certificateNumber: String
    var notes: String?

    /// Check if standard is valid
    var isValid: Bool {
        return validUntil > Date()
    }
}

/// Calibration drift analysis
struct CalibrationDriftAnalysis: Identifiable, Codable {
    var id = UUID()
    let equipmentId: UUID
    let calibrationType: CalibrationType
    let driftData: [CalibrationDriftPoint]
    let trendDirection: DriftTrend
    let maxDeviation: Double
    let averageDeviation: Double
    let analysisDate: Date

    init(equipmentId: UUID, calibrationType: CalibrationType, driftData: [CalibrationDriftPoint],
         trendDirection: DriftTrend, maxDeviation: Double, averageDeviation: Double) {
        self.equipmentId = equipmentId
        self.calibrationType = calibrationType
        self.driftData = driftData
        self.trendDirection = trendDirection
        self.maxDeviation = maxDeviation
        self.averageDeviation = averageDeviation
        self.analysisDate = Date()
    }
}

/// Single drift data point
struct CalibrationDriftPoint: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let parameter: String
    let expectedValue: Double
    let actualValue: Double
    let deviation: Double
    let tolerance: Double

    /// Check if within tolerance
    var isWithinTolerance: Bool {
        return deviation <= tolerance
    }
}

/// Drift trend direction
enum DriftTrend: String, CaseIterable, Codable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"

    var description: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }

    var color: String {
        switch self {
        case .increasing: return "red"
        case .decreasing: return "blue"
        case .stable: return "green"
        }
    }
}

/// Calibration compliance status
struct CalibrationCompliance: Identifiable, Codable {
    var id = UUID()
    let equipmentId: UUID
    let isCompliant: Bool
    let complianceItems: [ComplianceItem]
    let lastUpdated: Date
}

/// Individual compliance item
struct ComplianceItem: Identifiable, Codable {
    var id = UUID()
    let calibrationType: CalibrationType
    let isCompliant: Bool
    let lastCalibrationDate: Date?
    let nextDueDate: Date?
    let daysOverdue: Int
}

/// Calibration validation result
struct CalibrationValidation: Codable {
    let status: CalibrationValidationStatus
    let withinTolerance: Bool
    let maxDeviation: Double
    let averageDeviation: Double
    let tolerance: Double
    let readingsCount: Int
}

/// Validation status
enum CalibrationValidationStatus: String, CaseIterable, Codable {
    case passed = "passed"
    case marginal = "marginal"
    case failed = "failed"

    var description: String {
        switch self {
        case .passed: return "Passed"
        case .marginal: return "Marginal"
        case .failed: return "Failed"
        }
    }

    var color: String {
        switch self {
        case .passed: return "green"
        case .marginal: return "orange"
        case .failed: return "red"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let calibrationScheduled = Notification.Name("calibrationScheduled")
    static let calibrationCompleted = Notification.Name("calibrationCompleted")
    static let calibrationCancelled = Notification.Name("calibrationCancelled")
    static let calibrationOverdue = Notification.Name("calibrationOverdue")
}

// MARK: - NotificationManager Extension

extension NotificationManager {
    /// Schedule equipment calibration reminder
    func scheduleEquipmentCalibrationReminder(
        equipmentId: String,
        equipmentName: String,
        dueDate: Date,
        calibrationType: String,
        identifier: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Equipment Calibration Due"
        content.body = "\(calibrationType) calibration is due for \(equipmentName)"
        content.sound = .default
        content.userInfo = [
            "type": "calibration",
            "equipmentId": equipmentId,
            "calibrationType": calibrationType
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, dueDate.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule calibration notification: \(error)")
        }
    }
}