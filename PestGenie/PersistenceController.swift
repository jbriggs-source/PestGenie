import CoreData
import Foundation

/// Manages Core Data stack for offline-first data persistence
/// Provides both in-memory (testing) and persistent (production) configurations
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    /// Preview instance for SwiftUI previews with sample data
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Create sample data for previews
        let sampleJob = JobEntity(context: context)
        sampleJob.id = UUID()
        sampleJob.customerName = "Sample Customer"
        sampleJob.address = "123 Main St"
        sampleJob.scheduledDate = Date()
        sampleJob.status = JobStatus.pending.rawValue
        sampleJob.createdDate = Date()
        sampleJob.lastModified = Date()
        sampleJob.syncStatus = SyncStatus.synced.rawValue

        try? context.save()
        return controller
    }()

    let container: NSPersistentContainer

    private var isStoreLoaded = false
    private let loadingQueue = DispatchQueue(label: "com.pestgenie.persistence", qos: .background)

    /// Initializes persistence controller with optional in-memory store
    /// - Parameter inMemory: If true, uses in-memory store for testing
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PestGenieDataModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit sync if needed
            configureCloudKitStore()
        }

        // Load stores asynchronously in background
        loadingQueue.async { [weak self] in
            self?.container.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    // In production, handle this error appropriately
                    print("Core Data error: \(error), \(error.userInfo)")
                }
                self?.isStoreLoaded = true
            }
        }

        // Configure automatic merging for concurrent operations
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Configures CloudKit store for automatic sync
    private func configureCloudKitStore() {
        guard let description = container.persistentStoreDescriptions.first else { return }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Uncomment when ready for CloudKit integration
        // description.setOption("iCloud.com.yourteam.PestGenie" as NSString, forKey: NSPersistentStoreCloudKitContainerIdentifierKey)
    }

    /// Saves the view context with error handling
    func save() {
        let context = container.viewContext

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Save error: \(error)")
        }
    }

    /// Creates a background context for data operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}

// Note: SyncStatus enum is defined in Models.swift

/// Protocol for entities that support offline sync
protocol SyncableEntity {
    var syncStatus: String { get set }
    var lastModified: Date { get set }
    var serverId: String? { get set }
}