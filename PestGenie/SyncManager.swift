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
        setupPeriodicSync()
        registerBackgroundTask()
    }

    // MARK: - Public API

    /// Triggers immediate sync if network is available
    func syncNow() async {
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
                if self.networkMonitor.isConnected {
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
                let context = persistenceController.container.viewContext
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
}

// MARK: - Supporting Types

struct SyncError: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date
    let retryable: Bool
}

struct JobUploadData {
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

struct JobUpdateData {
    let serverId: String
    let customerName: String
    let address: String
    let scheduledDate: Date
    let status: String
    let lastModified: Date
}

struct RouteUpdateData {
    let serverId: String
    let name: String
    let date: Date
    let technicianId: String
    let lastModified: Date
}

struct ServerUpdates {
    let jobs: [JobUpdateData]
    let routes: [RouteUpdateData]
}

struct UploadResponse {
    let serverId: String
}

struct PhotoUploadResponse {
    let photoId: String
}