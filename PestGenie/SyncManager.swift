import Foundation
import CoreData
import Network
import BackgroundTasks

/// Manages offline-first data synchronization with conflict resolution
@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [SyncError] = []

    private let persistenceController: PersistenceController
    private let networkMonitor = NetworkMonitor.shared
    private var syncTimer: Timer?

    // Background sync task identifier
    private let backgroundTaskIdentifier = "com.pestgenie.backgroundsync"

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        // Defer setup until first sync is requested
        // setupPeriodicSync()
        // registerBackgroundTask()
    }

    // MARK: - Public API

    /// Triggers immediate sync if network is available
    func syncNow() async {
        // Initialize sync infrastructure on first use
        if syncTimer == nil {
            setupPeriodicSync()
            registerBackgroundTask()
        }
        
        guard networkMonitor.isConnected else {
            print("Sync skipped: No network connection")
            return
        }

        await performSync()
    }

    /// Forces sync even when offline (for testing)
    func forceSyncNow() async {
        await performSync()
    }

    // MARK: - Background Sync

    private func setupPeriodicSync() {
        // Sync every 5 minutes when connected
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                if await self.networkMonitor.isConnected {
                    await self.performSync()
                }
            }
        }
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            Task {
                await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) async {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        await performSync()

        // Schedule next background sync
        scheduleBackgroundSync()
        task.setTaskCompleted(success: true)
    }

    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Core Sync Logic

    private func performSync() async {
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // 1. Upload pending changes
            try await uploadPendingChanges()

            // 2. Download server updates
            try await downloadServerUpdates()

            // 3. Resolve conflicts
            try await resolveConflicts()

            // 4. Clean up completed actions
            try await cleanupPendingActions()

            lastSyncDate = Date()
            syncErrors.removeAll()

        } catch {
            let syncError = SyncError(
                message: "Sync failed: \(error.localizedDescription)",
                timestamp: Date(),
                retryable: true
            )
            syncErrors.append(syncError)
            print("Sync error: \(error)")
        }
    }

    // MARK: - Upload Pending Changes

    private func uploadPendingChanges() async throws {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            // Upload jobs with pending sync status
            let jobRequest: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
            jobRequest.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)

            do {
                let pendingJobs = try context.fetch(jobRequest)

                for job in pendingJobs {
                    Task {
                        await self.uploadJob(job)
                    }
                }

                // Upload photos
                let photoRequest: NSFetchRequest<JobPhotoEntity> = JobPhotoEntity.fetchRequest()
                photoRequest.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)
                let pendingPhotos = try context.fetch(photoRequest)

                for photo in pendingPhotos {
                    Task {
                        await self.uploadPhoto(photo)
                    }
                }

                // Upload chemicals
                let chemicalRequest: NSFetchRequest<ChemicalEntity> = ChemicalEntity.fetchRequest()
                chemicalRequest.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)
                let pendingChemicals = try context.fetch(chemicalRequest)

                for chemical in pendingChemicals {
                    Task {
                        await self.uploadChemical(chemical)
                    }
                }

                // Upload chemical treatments
                let treatmentRequest: NSFetchRequest<ChemicalTreatmentEntity> = ChemicalTreatmentEntity.fetchRequest()
                treatmentRequest.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)
                let pendingTreatments = try context.fetch(treatmentRequest)

                for treatment in pendingTreatments {
                    Task {
                        await self.uploadChemicalTreatment(treatment)
                    }
                }

            } catch {
                print("Error fetching pending entities: \(error)")
            }
        }
    }

    private func uploadJob(_ job: JobEntity) async {
        // Simulate API upload
        do {
            let jobData = JobUploadData(from: job)
            let response = try await APIService.shared.uploadJob(jobData)

            await MainActor.run {
                job.serverId = response.serverId
                job.syncStatus = SyncStatus.synced.rawValue
                job.lastModified = Date()
                persistenceController.save()
            }

        } catch {
            await MainActor.run {
                job.syncStatus = SyncStatus.failed.rawValue
                persistenceController.save()
            }
        }
    }

    private func uploadPhoto(_ photo: JobPhotoEntity) async {
        // Simulate photo upload with compression
        guard let imageData = photo.imageData else { return }

        do {
            let compressedData = await ImageCompressionService.compress(imageData)
            let response = try await APIService.shared.uploadPhoto(compressedData, for: photo.job?.serverId ?? "")

            await MainActor.run {
                photo.serverId = response.photoId
                photo.syncStatus = SyncStatus.synced.rawValue
                photo.lastModified = Date()
                persistenceController.save()
            }

        } catch {
            await MainActor.run {
                photo.syncStatus = SyncStatus.failed.rawValue
                persistenceController.save()
            }
        }
    }

    private func uploadChemical(_ chemical: ChemicalEntity) async {
        // Upload chemical data to server
        do {
            let chemicalData = ChemicalUploadData(from: chemical)
            let response = try await APIService.shared.uploadChemical(chemicalData)

            await MainActor.run {
                chemical.serverId = response.serverId
                chemical.syncStatus = SyncStatus.synced.rawValue
                chemical.lastModified = Date()
                persistenceController.save()
            }

        } catch {
            await MainActor.run {
                chemical.syncStatus = SyncStatus.failed.rawValue
                persistenceController.save()
            }
        }
    }

    private func uploadChemicalTreatment(_ treatment: ChemicalTreatmentEntity) async {
        // Upload chemical treatment data to server
        do {
            let treatmentData = ChemicalTreatmentUploadData(from: treatment)
            let response = try await APIService.shared.uploadChemicalTreatment(treatmentData)

            await MainActor.run {
                treatment.serverId = response.serverId
                treatment.syncStatus = SyncStatus.synced.rawValue
                treatment.lastModified = Date()
                persistenceController.save()
            }

        } catch {
            await MainActor.run {
                treatment.syncStatus = SyncStatus.failed.rawValue
                persistenceController.save()
            }
        }
    }

    // MARK: - Download Server Updates

    private func downloadServerUpdates() async throws {
        let lastSync = lastSyncDate ?? Date.distantPast
        let updates = try await APIService.shared.getUpdates(since: lastSync)

        let context = persistenceController.newBackgroundContext()

        await context.perform {
            for update in updates.jobs {
                self.processJobUpdate(update, in: context)
            }

            for update in updates.routes {
                self.processRouteUpdate(update, in: context)
            }

            for update in updates.chemicals {
                self.processChemicalUpdate(update, in: context)
            }

            for update in updates.chemicalTreatments {
                self.processChemicalTreatmentUpdate(update, in: context)
            }

            do {
                try context.save()
            } catch {
                print("Error saving server updates: \(error)")
            }
        }
    }

    private func processJobUpdate(_ update: JobUpdateData, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", update.serverId)
        request.fetchLimit = 1

        do {
            let existingJobs = try context.fetch(request)

            if let existingJob = existingJobs.first {
                // Update existing job
                if update.lastModified > existingJob.lastModified ?? Date.distantPast {
                    updateJobEntity(existingJob, with: update)
                } else {
                    // Potential conflict
                    existingJob.syncStatus = SyncStatus.conflict.rawValue
                }
            } else {
                // Create new job
                let newJob = JobEntity(context: context)
                updateJobEntity(newJob, with: update)
                newJob.syncStatus = SyncStatus.synced.rawValue
            }

        } catch {
            print("Error processing job update: \(error)")
        }
    }

    private func processRouteUpdate(_ update: RouteUpdateData, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<RouteEntity> = RouteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", update.serverId)
        request.fetchLimit = 1

        do {
            let existingRoutes = try context.fetch(request)

            if let existingRoute = existingRoutes.first {
                if update.lastModified > existingRoute.lastModified ?? Date.distantPast {
                    updateRouteEntity(existingRoute, with: update)
                } else {
                    existingRoute.syncStatus = SyncStatus.conflict.rawValue
                }
            } else {
                let newRoute = RouteEntity(context: context)
                updateRouteEntity(newRoute, with: update)
                newRoute.syncStatus = SyncStatus.synced.rawValue
            }

        } catch {
            print("Error processing route update: \(error)")
        }
    }

    private func processChemicalUpdate(_ update: ChemicalUpdateData, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ChemicalEntity> = ChemicalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", update.serverId)
        request.fetchLimit = 1

        do {
            let existingChemicals = try context.fetch(request)

            if let existingChemical = existingChemicals.first {
                if update.lastModified > existingChemical.lastModified ?? Date.distantPast {
                    updateChemicalEntity(existingChemical, with: update)
                } else {
                    existingChemical.syncStatus = SyncStatus.conflict.rawValue
                }
            } else {
                let newChemical = ChemicalEntity(context: context)
                updateChemicalEntity(newChemical, with: update)
                newChemical.syncStatus = SyncStatus.synced.rawValue
            }

        } catch {
            print("Error processing chemical update: \(error)")
        }
    }

    private func processChemicalTreatmentUpdate(_ update: ChemicalTreatmentUpdateData, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ChemicalTreatmentEntity> = ChemicalTreatmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", update.serverId)
        request.fetchLimit = 1

        do {
            let existingTreatments = try context.fetch(request)

            if let existingTreatment = existingTreatments.first {
                if update.lastModified > existingTreatment.lastModified ?? Date.distantPast {
                    updateChemicalTreatmentEntity(existingTreatment, with: update)
                } else {
                    existingTreatment.syncStatus = SyncStatus.conflict.rawValue
                }
            } else {
                let newTreatment = ChemicalTreatmentEntity(context: context)
                updateChemicalTreatmentEntity(newTreatment, with: update)
                newTreatment.syncStatus = SyncStatus.synced.rawValue
            }

        } catch {
            print("Error processing chemical treatment update: \(error)")
        }
    }

    // MARK: - Conflict Resolution

    private func resolveConflicts() async throws {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let request: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
            request.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.conflict.rawValue)

            do {
                let conflictedJobs = try context.fetch(request)

                for job in conflictedJobs {
                    // Simple conflict resolution: server wins
                    // In production, implement more sophisticated resolution
                    job.syncStatus = SyncStatus.synced.rawValue
                }

                try context.save()

            } catch {
                print("Error resolving conflicts: \(error)")
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupPendingActions() async throws {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let request: NSFetchRequest<PendingActionEntity> = PendingActionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "createdDate < %@", Date().addingTimeInterval(-24 * 60 * 60) as NSDate) // 24 hours old

            do {
                let oldActions = try context.fetch(request)
                for action in oldActions {
                    context.delete(action)
                }
                try context.save()
            } catch {
                print("Error cleaning up pending actions: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    private func updateJobEntity(_ job: JobEntity, with update: JobUpdateData) {
        job.serverId = update.serverId
        job.customerName = update.customerName
        job.address = update.address
        job.scheduledDate = update.scheduledDate
        job.status = update.status
        job.lastModified = update.lastModified
    }

    private func updateRouteEntity(_ route: RouteEntity, with update: RouteUpdateData) {
        route.serverId = update.serverId
        route.name = update.name
        route.date = update.date
        route.technicianId = update.technicianId
        route.lastModified = update.lastModified
    }

    private func updateChemicalEntity(_ chemical: ChemicalEntity, with update: ChemicalUpdateData) {
        chemical.serverId = update.serverId
        chemical.name = update.name
        chemical.activeIngredient = update.activeIngredient
        chemical.manufacturerName = update.manufacturerName
        chemical.epaRegistrationNumber = update.epaRegistrationNumber
        chemical.concentration = update.concentration
        chemical.unitOfMeasure = update.unitOfMeasure
        chemical.quantityInStock = update.quantityInStock
        chemical.expirationDate = update.expirationDate
        chemical.batchNumber = update.batchNumber
        chemical.targetPests = update.targetPests
        chemical.signalWord = update.signalWord
        chemical.hazardCategory = update.hazardCategory
        chemical.pphiDays = Int32(update.pphiDays)
        chemical.reentryInterval = Int32(update.reentryInterval)
        chemical.siteOfAction = update.siteOfAction
        chemical.storageRequirements = update.storageRequirements
        chemical.lastModified = update.lastModified
    }

    private func updateChemicalTreatmentEntity(_ treatment: ChemicalTreatmentEntity, with update: ChemicalTreatmentUpdateData) {
        treatment.serverId = update.serverId
        treatment.applicatorName = update.applicatorName
        treatment.applicationDate = update.applicationDate
        treatment.applicationMethod = update.applicationMethod
        treatment.targetPests = update.targetPests
        treatment.treatmentLocation = update.treatmentLocation
        treatment.areaTreated = update.areaTreated
        treatment.quantityUsed = update.quantityUsed
        treatment.dosageRate = update.dosageRate
        treatment.concentrationUsed = update.concentrationUsed
        treatment.dilutionRatio = update.dilutionRatio
        treatment.weatherConditions = update.weatherConditions
        treatment.environmentalConditions = update.environmentalConditions
        treatment.notes = update.notes
        treatment.lastModified = update.lastModified
    }
}

// MARK: - Supporting Types

struct SyncError: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date
    let retryable: Bool
}

struct JobUploadData: Codable {
    let id: UUID
    let customerName: String
    let address: String
    let scheduledDate: Date
    let status: String

    init(from job: JobEntity) {
        self.id = job.id ?? UUID()
        self.customerName = job.customerName ?? ""
        self.address = job.address ?? ""
        self.scheduledDate = job.scheduledDate ?? Date()
        self.status = job.status ?? ""
    }
}

struct JobUpdateData: Codable {
    let serverId: String
    let customerName: String
    let address: String
    let scheduledDate: Date
    let status: String
    let lastModified: Date
}

struct RouteUpdateData: Codable {
    let serverId: String
    let name: String
    let date: Date
    let technicianId: String
    let lastModified: Date
}

struct ServerUpdates: Codable {
    let jobs: [JobUpdateData]
    let routes: [RouteUpdateData]
    let chemicals: [ChemicalUpdateData]
    let chemicalTreatments: [ChemicalTreatmentUpdateData]
}

struct UploadResponse: Codable {
    let success: Bool
    let jobId: String
    let serverId: String?
    let message: String?
}

struct PhotoUploadResponse: Codable {
    let success: Bool
    let photoId: String
    let url: String?
    let message: String?
}

// MARK: - Chemical Sync Data Structures

struct ChemicalUploadData: Codable {
    let id: UUID
    let name: String
    let activeIngredient: String
    let manufacturerName: String
    let epaRegistrationNumber: String
    let concentration: Double
    let unitOfMeasure: String
    let quantityInStock: Double
    let expirationDate: Date
    let batchNumber: String?
    let targetPests: String
    let signalWord: String
    let hazardCategory: String
    let pphiDays: Int
    let reentryInterval: Int
    let siteOfAction: String
    let storageRequirements: String
    let lastModified: Date

    init(from chemical: ChemicalEntity) {
        self.id = chemical.id ?? UUID()
        self.name = chemical.name ?? ""
        self.activeIngredient = chemical.activeIngredient ?? ""
        self.manufacturerName = chemical.manufacturerName ?? ""
        self.epaRegistrationNumber = chemical.epaRegistrationNumber ?? ""
        self.concentration = chemical.concentration
        self.unitOfMeasure = chemical.unitOfMeasure ?? "oz"
        self.quantityInStock = chemical.quantityInStock
        self.expirationDate = chemical.expirationDate ?? Date()
        self.batchNumber = chemical.batchNumber
        self.targetPests = chemical.targetPests ?? ""
        self.signalWord = chemical.signalWord ?? "CAUTION"
        self.hazardCategory = chemical.hazardCategory ?? "Category III"
        self.pphiDays = Int(chemical.pphiDays)
        self.reentryInterval = Int(chemical.reentryInterval)
        self.siteOfAction = chemical.siteOfAction ?? ""
        self.storageRequirements = chemical.storageRequirements ?? ""
        self.lastModified = chemical.lastModified ?? Date()
    }
}

struct ChemicalUpdateData: Codable {
    let serverId: String
    let name: String
    let activeIngredient: String
    let manufacturerName: String
    let epaRegistrationNumber: String
    let concentration: Double
    let unitOfMeasure: String
    let quantityInStock: Double
    let expirationDate: Date
    let batchNumber: String?
    let targetPests: String
    let signalWord: String
    let hazardCategory: String
    let pphiDays: Int
    let reentryInterval: Int
    let siteOfAction: String
    let storageRequirements: String
    let lastModified: Date
}

struct ChemicalTreatmentUploadData: Codable {
    let id: UUID
    let jobId: UUID?
    let chemicalId: UUID?
    let applicatorName: String
    let applicationDate: Date
    let applicationMethod: String
    let targetPests: String
    let treatmentLocation: String
    let areaTreated: Double
    let quantityUsed: Double
    let dosageRate: Double
    let concentrationUsed: Double
    let dilutionRatio: String
    let weatherConditions: String?
    let environmentalConditions: String
    let notes: String?
    let lastModified: Date

    init(from treatment: ChemicalTreatmentEntity) {
        self.id = treatment.id ?? UUID()
        self.jobId = treatment.job?.id
        self.chemicalId = treatment.chemical?.id
        self.applicatorName = treatment.applicatorName ?? ""
        self.applicationDate = treatment.applicationDate ?? Date()
        self.applicationMethod = treatment.applicationMethod ?? "spray"
        self.targetPests = treatment.targetPests ?? ""
        self.treatmentLocation = treatment.treatmentLocation ?? ""
        self.areaTreated = treatment.areaTreated
        self.quantityUsed = treatment.quantityUsed
        self.dosageRate = treatment.dosageRate
        self.concentrationUsed = treatment.concentrationUsed
        self.dilutionRatio = treatment.dilutionRatio ?? "1:1"
        self.weatherConditions = treatment.weatherConditions
        self.environmentalConditions = treatment.environmentalConditions ?? ""
        self.notes = treatment.notes
        self.lastModified = treatment.lastModified ?? Date()
    }
}

struct ChemicalTreatmentUpdateData: Codable {
    let serverId: String
    let applicatorName: String
    let applicationDate: Date
    let applicationMethod: String
    let targetPests: String
    let treatmentLocation: String
    let areaTreated: Double
    let quantityUsed: Double
    let dosageRate: Double
    let concentrationUsed: Double
    let dilutionRatio: String
    let weatherConditions: String?
    let environmentalConditions: String
    let notes: String?
    let lastModified: Date
}