import Foundation
import SwiftUI
import CoreData
import Combine
import UserNotifications

/// Comprehensive maintenance scheduling system with notifications and tracking
@MainActor
final class MaintenanceSchedulingManager: ObservableObject {
    static let shared = MaintenanceSchedulingManager()

    @Published var scheduledMaintenance: [MaintenanceSchedule] = []
    @Published var completedMaintenance: [MaintenanceRecord] = []
    @Published var overdueMaintenance: [MaintenanceSchedule] = []
    @Published var upcomingMaintenance: [MaintenanceSchedule] = []
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
        // Defer heavy loading until first access
        // Task {
        //     await loadScheduledMaintenance()
        //     await updateMaintenanceCategories()
        // }
    }

    // MARK: - Maintenance Scheduling

    /// Schedule new maintenance for equipment
    func scheduleMaintenance(_ schedule: MaintenanceSchedule) async {
        scheduledMaintenance.append(schedule)
        await saveMaintenanceSchedule(schedule)
        await scheduleMaintenanceNotifications(schedule)
        await updateMaintenanceCategories()

        NotificationCenter.default.post(
            name: .maintenanceScheduled,
            object: nil,
            userInfo: [
                "scheduleId": schedule.id.uuidString,
                "equipmentId": schedule.equipmentId.uuidString,
                "scheduledDate": schedule.scheduledDate
            ]
        )
    }

    /// Update existing maintenance schedule
    func updateMaintenanceSchedule(_ schedule: MaintenanceSchedule) async {
        if let index = scheduledMaintenance.firstIndex(where: { $0.id == schedule.id }) {
            scheduledMaintenance[index] = schedule
            await saveMaintenanceSchedule(schedule)
            await scheduleMaintenanceNotifications(schedule)
            await updateMaintenanceCategories()
        }
    }

    /// Complete maintenance and create record
    func completeMaintenance(_ schedule: MaintenanceSchedule, details: MaintenanceCompletionDetails) async {
        // Remove from scheduled
        if let index = scheduledMaintenance.firstIndex(where: { $0.id == schedule.id }) {
            scheduledMaintenance.remove(at: index)
        }

        // Create completion record
        let record = MaintenanceRecord(
            equipmentId: schedule.equipmentId,
            type: schedule.type,
            description: schedule.description,
            performedBy: details.performedBy
        )

        var updatedRecord = record
        updatedRecord.performedDate = details.completedDate
        updatedRecord.duration = details.duration
        updatedRecord.cost = details.cost
        updatedRecord.partsReplaced = details.partsReplaced
        updatedRecord.serviceNotes = details.notes
        updatedRecord.nextServiceDate = details.nextServiceDate
        updatedRecord.photos = details.photoUrls

        completedMaintenance.append(updatedRecord)

        // Save to Core Data
        await saveMaintenanceRecord(updatedRecord)
        await deleteMaintenanceSchedule(schedule.id)

        // Schedule next maintenance if recurring
        if schedule.isRecurring {
            await scheduleNextRecurringMaintenance(schedule, lastCompleted: details.completedDate)
        }

        // Cancel notifications for completed maintenance
        await cancelMaintenanceNotifications(schedule.id)

        // Update equipment maintenance date
        await updateEquipmentMaintenanceDate(schedule.equipmentId, date: details.completedDate)

        await updateMaintenanceCategories()

        NotificationCenter.default.post(
            name: .maintenanceCompleted,
            object: nil,
            userInfo: [
                "scheduleId": schedule.id.uuidString,
                "equipmentId": schedule.equipmentId.uuidString,
                "recordId": updatedRecord.id.uuidString
            ]
        )
    }

    /// Cancel scheduled maintenance
    func cancelMaintenance(_ scheduleId: UUID, reason: String) async {
        if let index = scheduledMaintenance.firstIndex(where: { $0.id == scheduleId }) {
            let schedule = scheduledMaintenance[index]
            scheduledMaintenance.remove(at: index)

            await deleteMaintenanceSchedule(scheduleId)
            await cancelMaintenanceNotifications(scheduleId)
            await updateMaintenanceCategories()

            NotificationCenter.default.post(
                name: .maintenanceCancelled,
                object: nil,
                userInfo: [
                    "scheduleId": scheduleId.uuidString,
                    "equipmentId": schedule.equipmentId.uuidString,
                    "reason": reason
                ]
            )
        }
    }

    /// Get scheduled maintenance for specific equipment
    func getScheduledMaintenance(equipmentId: UUID) -> [MaintenanceSchedule] {
        return scheduledMaintenance.filter { $0.equipmentId == equipmentId }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Get maintenance history for equipment
    func getMaintenanceHistory(equipmentId: UUID) -> [MaintenanceRecord] {
        return completedMaintenance.filter { $0.equipmentId == equipmentId }
            .sorted { $0.performedDate > $1.performedDate }
    }

    /// Generate automatic maintenance schedules based on equipment type and usage
    func generateAutomaticMaintenanceSchedule(for equipment: Equipment) async {
        let maintenanceInterval = equipment.type.maintenanceIntervalDays
        let lastMaintenanceDate = equipment.lastInspectionDate ?? equipment.purchaseDate

        // Calculate next maintenance date
        let nextMaintenanceDate = Calendar.current.date(
            byAdding: .day,
            value: maintenanceInterval,
            to: lastMaintenanceDate
        ) ?? Date()

        // Create routine maintenance schedule
        let routineSchedule = MaintenanceSchedule(
            equipmentId: equipment.id,
            type: .routine,
            title: "Routine Maintenance - \(equipment.name)",
            description: "Scheduled routine maintenance for \(equipment.type.displayName)",
            scheduledDate: nextMaintenanceDate,
            priority: .medium,
            estimatedDuration: 60, // 1 hour default
            isRecurring: true,
            recurrenceInterval: .days(maintenanceInterval)
        )

        await scheduleMaintenance(routineSchedule)

        // Schedule calibration if required
        if equipment.type.requiresCalibration {
            let calibrationDate = Calendar.current.date(
                byAdding: .month,
                value: 6, // 6 months for calibration
                to: equipment.lastCalibrationDate ?? equipment.purchaseDate
            ) ?? Date()

            let calibrationSchedule = MaintenanceSchedule(
                equipmentId: equipment.id,
                type: .calibration,
                title: "Equipment Calibration - \(equipment.name)",
                description: "Scheduled calibration for \(equipment.type.displayName)",
                scheduledDate: calibrationDate,
                priority: .high,
                estimatedDuration: 30,
                isRecurring: true,
                recurrenceInterval: .months(6)
            )

            await scheduleMaintenance(calibrationSchedule)
        }
    }

    // MARK: - Notification Management

    private func scheduleMaintenanceNotifications(_ schedule: MaintenanceSchedule) async {
        // Schedule notification 1 week before
        await notificationManager.scheduleEquipmentMaintenanceReminder(
            equipmentId: schedule.equipmentId.uuidString,
            equipmentName: "Equipment", // Would fetch actual name
            dueDate: schedule.scheduledDate,
            maintenanceType: schedule.type.description
        )

        // Schedule notification 1 day before
        await notificationManager.scheduleEquipmentMaintenanceReminder(
            equipmentId: schedule.equipmentId.uuidString,
            equipmentName: "Equipment", // Would fetch actual name
            dueDate: schedule.scheduledDate,
            maintenanceType: schedule.type.description
        )

        // Schedule overdue notification
        await notificationManager.scheduleEquipmentMaintenanceReminder(
            equipmentId: schedule.equipmentId.uuidString,
            equipmentName: "Equipment", // Would fetch actual name
            dueDate: schedule.scheduledDate,
            maintenanceType: schedule.type.description
        )
    }

    private func cancelMaintenanceNotifications(_ scheduleId: UUID) async {
        let identifiers = [
            "\(scheduleId.uuidString)_week",
            "\(scheduleId.uuidString)_day",
            "\(scheduleId.uuidString)_overdue"
        ]

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Recurring Maintenance

    private func scheduleNextRecurringMaintenance(_ originalSchedule: MaintenanceSchedule, lastCompleted: Date) async {
        guard originalSchedule.isRecurring,
              let interval = originalSchedule.recurrenceInterval else { return }

        let nextDate: Date
        switch interval {
        case .days(let days):
            nextDate = Calendar.current.date(byAdding: .day, value: days, to: lastCompleted) ?? lastCompleted
        case .weeks(let weeks):
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: lastCompleted) ?? lastCompleted
        case .months(let months):
            nextDate = Calendar.current.date(byAdding: .month, value: months, to: lastCompleted) ?? lastCompleted
        case .years(let years):
            nextDate = Calendar.current.date(byAdding: .year, value: years, to: lastCompleted) ?? lastCompleted
        }

        var nextSchedule = originalSchedule
        nextSchedule.id = UUID() // New ID for next occurrence
        nextSchedule.scheduledDate = nextDate
        nextSchedule.status = .scheduled

        await scheduleMaintenance(nextSchedule)
    }

    // MARK: - Data Management

    private func loadScheduledMaintenance() async {
        let context = persistenceController.newBackgroundContext()

        await context.perform { [weak self] in
            let fetchRequest: NSFetchRequest<EquipmentMaintenanceEntity> = EquipmentMaintenanceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "status == %@", MaintenanceStatus.scheduled.rawValue)

            do {
                let entities = try context.fetch(fetchRequest)
                let schedules = entities.compactMap { entity -> MaintenanceSchedule? in
                    self?.convertEntityToSchedule(entity)
                }

                DispatchQueue.main.async {
                    self?.scheduledMaintenance = schedules
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to load scheduled maintenance: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveMaintenanceSchedule(_ schedule: MaintenanceSchedule) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentMaintenanceEntity> = EquipmentMaintenanceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", schedule.id as CVarArg)

            let entity: EquipmentMaintenanceEntity
            if let existingEntity = try? context.fetch(fetchRequest).first {
                entity = existingEntity
            } else {
                entity = EquipmentMaintenanceEntity(context: context)
                entity.id = schedule.id
            }

            // Update entity from schedule
            entity.maintenanceType = schedule.type.rawValue
            entity.maintenanceDescription = schedule.description
            entity.scheduledDate = schedule.scheduledDate
            entity.status = schedule.status.rawValue
            entity.priority = schedule.priority.rawValue
            entity.duration = Int32(schedule.estimatedDuration)
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            // Encode recurring information
            if let recurrence = schedule.recurrenceInterval {
                entity.serviceNotes = "recurring:\(recurrence.description)"
            }

            do {
                try context.save()
            } catch {
                print("Failed to save maintenance schedule: \(error)")
            }
        }
    }

    private func saveMaintenanceRecord(_ record: MaintenanceRecord) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let entity = EquipmentMaintenanceEntity(context: context)
            entity.id = record.id
            entity.maintenanceType = record.type.rawValue
            entity.maintenanceDescription = record.description
            entity.performedBy = record.performedBy
            entity.performedDate = record.performedDate
            entity.scheduledDate = record.scheduledDate
            entity.duration = Int32(record.duration)
            entity.cost = NSDecimalNumber(value: record.cost)
            entity.serviceNotes = record.serviceNotes
            entity.nextServiceDate = record.nextServiceDate
            entity.status = record.status.rawValue
            entity.priority = record.priority.rawValue
            entity.createdDate = record.createdDate
            entity.lastModified = Date()
            entity.syncStatus = SyncStatus.pending.rawValue

            // Encode parts replaced
            if let partsData = try? JSONEncoder().encode(record.partsReplaced) {
                entity.partsReplaced = String(data: partsData, encoding: .utf8)
            }

            // Encode photos
            if let photosData = try? JSONEncoder().encode(record.photos) {
                entity.photos = String(data: photosData, encoding: .utf8)
            }

            do {
                try context.save()
            } catch {
                print("Failed to save maintenance record: \(error)")
            }
        }
    }

    private func deleteMaintenanceSchedule(_ scheduleId: UUID) async {
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
                print("Failed to delete maintenance schedule: \(error)")
            }
        }
    }

    private func updateEquipmentMaintenanceDate(_ equipmentId: UUID, date: Date) async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<EquipmentEntity> = EquipmentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", equipmentId as CVarArg)

            do {
                if let equipment = try context.fetch(fetchRequest).first {
                    equipment.lastInspectionDate = date
                    equipment.lastModified = Date()
                    try context.save()
                }
            } catch {
                print("Failed to update equipment maintenance date: \(error)")
            }
        }
    }

    private func updateMaintenanceCategories() async {
        let now = Date()

        // Update overdue maintenance
        overdueMaintenance = scheduledMaintenance.filter { schedule in
            schedule.scheduledDate < now && schedule.status == .scheduled
        }

        // Update upcoming maintenance (next 30 days)
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        upcomingMaintenance = scheduledMaintenance.filter { schedule in
            schedule.scheduledDate >= now && schedule.scheduledDate <= thirtyDaysFromNow && schedule.status == .scheduled
        }
    }

    private func convertEntityToSchedule(_ entity: EquipmentMaintenanceEntity) -> MaintenanceSchedule? {
        guard let id = entity.id,
              let scheduledDate = entity.scheduledDate else { return nil }

        var schedule = MaintenanceSchedule(
            equipmentId: UUID(), // Would need to get from relationship
            type: MaintenanceType(rawValue: entity.maintenanceType ?? "") ?? .routine,
            title: entity.maintenanceDescription ?? "",
            description: entity.maintenanceDescription ?? "",
            scheduledDate: scheduledDate,
            priority: MaintenancePriority(rawValue: entity.priority ?? "") ?? .medium,
            estimatedDuration: Double(entity.duration)
        )

        schedule.id = id
        schedule.status = MaintenanceStatus(rawValue: entity.status ?? "") ?? .scheduled

        return schedule
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .equipmentUsageUpdated)
            .sink { [weak self] notification in
                // Update maintenance schedules based on usage
                Task {
                    await self?.updateMaintenanceBasedOnUsage(notification)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .equipmentFailureReported)
            .sink { [weak self] notification in
                // Schedule emergency maintenance for failures
                Task {
                    await self?.scheduleEmergencyMaintenance(notification)
                }
            }
            .store(in: &cancellables)
    }

    private func updateMaintenanceBasedOnUsage(_ notification: Notification) async {
        // Implementation would analyze usage patterns and adjust maintenance schedules
    }

    private func scheduleEmergencyMaintenance(_ notification: Notification) async {
        // Implementation would create emergency maintenance schedules for equipment failures
    }
}

// MARK: - Data Models

/// Maintenance schedule model
struct MaintenanceSchedule: Identifiable, Codable {
    var id: UUID
    let equipmentId: UUID
    var type: MaintenanceType
    var title: String
    var description: String
    var scheduledDate: Date
    var priority: MaintenancePriority
    var estimatedDuration: Double // in minutes
    var assignedTechnician: String?
    var status: MaintenanceStatus
    var isRecurring: Bool
    var recurrenceInterval: RecurrenceInterval?
    var requiredParts: [String]
    var specialInstructions: String?
    var createdDate: Date
    var lastModified: Date

    init(equipmentId: UUID, type: MaintenanceType, title: String, description: String,
         scheduledDate: Date, priority: MaintenancePriority = .medium,
         estimatedDuration: Double = 60, isRecurring: Bool = false,
         recurrenceInterval: RecurrenceInterval? = nil) {
        self.id = UUID()
        self.equipmentId = equipmentId
        self.type = type
        self.title = title
        self.description = description
        self.scheduledDate = scheduledDate
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.status = .scheduled
        self.isRecurring = isRecurring
        self.recurrenceInterval = recurrenceInterval
        self.requiredParts = []
        self.createdDate = Date()
        self.lastModified = Date()
    }

    /// Check if maintenance is overdue
    var isOverdue: Bool {
        return scheduledDate < Date() && status == .scheduled
    }

    /// Days until scheduled maintenance
    var daysUntilDue: Int {
        return Calendar.current.dateComponents([.day], from: Date(), to: scheduledDate).day ?? 0
    }

    /// Formatted duration string
    var formattedDuration: String {
        let hours = Int(estimatedDuration / 60)
        let minutes = Int(estimatedDuration.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Recurrence interval for recurring maintenance
enum RecurrenceInterval: Codable, Equatable {
    case days(Int)
    case weeks(Int)
    case months(Int)
    case years(Int)

    var description: String {
        switch self {
        case .days(let count):
            return "\(count) day\(count > 1 ? "s" : "")"
        case .weeks(let count):
            return "\(count) week\(count > 1 ? "s" : "")"
        case .months(let count):
            return "\(count) month\(count > 1 ? "s" : "")"
        case .years(let count):
            return "\(count) year\(count > 1 ? "s" : "")"
        }
    }
}

/// Maintenance completion details
struct MaintenanceCompletionDetails {
    let performedBy: String
    let completedDate: Date
    let duration: Double // actual duration in hours
    let cost: Double
    let partsReplaced: [String]
    let notes: String?
    let nextServiceDate: Date?
    let photoUrls: [String]

    init(performedBy: String, completedDate: Date = Date()) {
        self.performedBy = performedBy
        self.completedDate = completedDate
        self.duration = 0
        self.cost = 0
        self.partsReplaced = []
        self.notes = nil
        self.nextServiceDate = nil
        self.photoUrls = []
    }
}

// MARK: - Maintenance Views

/// Maintenance schedule list view
struct MaintenanceScheduleView: View {
    @StateObject private var maintenanceManager = MaintenanceSchedulingManager.shared
    @State private var selectedFilter: MaintenanceFilter = .all
    @State private var showingNewMaintenance = false

    var body: some View {
        NavigationView {
            VStack {
                // Filter buttons
                filterButtons

                // Maintenance list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Overdue section
                        if !maintenanceManager.overdueMaintenance.isEmpty {
                            maintenanceSection(
                                title: "Overdue (\(maintenanceManager.overdueMaintenance.count))",
                                items: maintenanceManager.overdueMaintenance,
                                color: .red
                            )
                        }

                        // Upcoming section
                        if !maintenanceManager.upcomingMaintenance.isEmpty {
                            maintenanceSection(
                                title: "Upcoming (\(maintenanceManager.upcomingMaintenance.count))",
                                items: maintenanceManager.upcomingMaintenance,
                                color: .orange
                            )
                        }

                        // All scheduled section
                        let otherScheduled = maintenanceManager.scheduledMaintenance.filter { schedule in
                            !maintenanceManager.overdueMaintenance.contains { $0.id == schedule.id } &&
                            !maintenanceManager.upcomingMaintenance.contains { $0.id == schedule.id }
                        }

                        if !otherScheduled.isEmpty {
                            maintenanceSection(
                                title: "Scheduled (\(otherScheduled.count))",
                                items: otherScheduled,
                                color: .blue
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewMaintenance = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewMaintenance) {
                NewMaintenanceScheduleView()
            }
        }
    }

    private var filterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MaintenanceFilter.allCases, id: \.self) { filter in
                    Button(filter.title) {
                        selectedFilter = filter
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(selectedFilter == filter ? .white : .blue)
                    .background(selectedFilter == filter ? Color.blue : Color.clear)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }

    private func maintenanceSection(title: String, items: [MaintenanceSchedule], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)

            ForEach(items) { schedule in
                MaintenanceScheduleRowView(schedule: schedule)
            }
        }
    }
}

/// Individual maintenance schedule row
struct MaintenanceScheduleRowView: View {
    let schedule: MaintenanceSchedule
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(schedule.priority.color))
                .frame(width: 4, height: 60)

            // Maintenance info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(schedule.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(schedule.scheduledDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(schedule.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(schedule.type.description, systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if schedule.isOverdue {
                        Text("Overdue")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    } else if schedule.daysUntilDue <= 7 {
                        Text("\(schedule.daysUntilDue) days")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            MaintenanceDetailView(schedule: schedule)
        }
    }
}

/// New maintenance schedule creation view
struct NewMaintenanceScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEquipment: Equipment?
    @State private var maintenanceType: MaintenanceType = .routine
    @State private var title = ""
    @State private var description = ""
    @State private var scheduledDate = Date()
    @State private var priority: MaintenancePriority = .medium
    @State private var estimatedDuration: Double = 60
    @State private var isRecurring = false
    @State private var recurrenceType: RecurrenceType = .monthly

    var body: some View {
        NavigationView {
            Form {
                Section("Equipment") {
                    if let equipment = selectedEquipment {
                        Text(equipment.name)
                            .foregroundColor(.blue)
                    } else {
                        Button("Select Equipment") {
                            // Show equipment selector
                        }
                    }
                }

                Section("Maintenance Details") {
                    Picker("Type", selection: $maintenanceType) {
                        ForEach(MaintenanceType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }

                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Scheduling") {
                    DatePicker("Scheduled Date", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])

                    Picker("Priority", selection: $priority) {
                        ForEach(MaintenancePriority.allCases, id: \.self) { priority in
                            Text(priority.description).tag(priority)
                        }
                    }

                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        TextField("Minutes", value: $estimatedDuration, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("min")
                    }
                }

                Section("Recurrence") {
                    Toggle("Recurring Maintenance", isOn: $isRecurring)

                    if isRecurring {
                        Picker("Repeat", selection: $recurrenceType) {
                            ForEach(RecurrenceType.allCases, id: \.self) { type in
                                Text(type.description).tag(type)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMaintenance()
                    }
                    .disabled(selectedEquipment == nil || title.isEmpty)
                }
            }
        }
    }

    private func saveMaintenance() {
        guard let equipment = selectedEquipment else { return }

        let interval: RecurrenceInterval? = isRecurring ? recurrenceType.interval : nil

        let schedule = MaintenanceSchedule(
            equipmentId: equipment.id,
            type: maintenanceType,
            title: title,
            description: description,
            scheduledDate: scheduledDate,
            priority: priority,
            estimatedDuration: estimatedDuration,
            isRecurring: isRecurring,
            recurrenceInterval: interval
        )

        Task {
            await MaintenanceSchedulingManager.shared.scheduleMaintenance(schedule)
            dismiss()
        }
    }
}

/// Maintenance detail view
struct MaintenanceDetailView: View {
    let schedule: MaintenanceSchedule
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(schedule.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(schedule.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Details
                    VStack(spacing: 12) {
                        DetailRow(title: "Type", value: schedule.type.description)
                        DetailRow(title: "Scheduled", value: schedule.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        DetailRow(title: "Priority", value: schedule.priority.description)
                        DetailRow(title: "Duration", value: schedule.formattedDuration)
                        DetailRow(title: "Status", value: schedule.status.displayName)

                        if schedule.isRecurring, let interval = schedule.recurrenceInterval {
                            DetailRow(title: "Recurs", value: "Every \(interval.description)")
                        }
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button("Mark as Completed") {
                            // Show completion form
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Reschedule") {
                            // Show reschedule form
                        }
                        .buttonStyle(.bordered)

                        Button("Cancel Maintenance") {
                            // Show cancellation confirmation
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Maintenance Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types

enum MaintenanceFilter: CaseIterable {
    case all
    case overdue
    case upcoming
    case completed

    var title: String {
        switch self {
        case .all: return "All"
        case .overdue: return "Overdue"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        }
    }
}

enum RecurrenceType: CaseIterable {
    case weekly
    case monthly
    case quarterly
    case annually

    var description: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .annually: return "Annually"
        }
    }

    var interval: RecurrenceInterval {
        switch self {
        case .weekly: return .weeks(1)
        case .monthly: return .months(1)
        case .quarterly: return .months(3)
        case .annually: return .years(1)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let maintenanceScheduled = Notification.Name("maintenanceScheduled")
    static let maintenanceCompleted = Notification.Name("maintenanceCompleted")
    static let maintenanceCancelled = Notification.Name("maintenanceCancelled")
    static let maintenanceOverdue = Notification.Name("maintenanceOverdue")
}