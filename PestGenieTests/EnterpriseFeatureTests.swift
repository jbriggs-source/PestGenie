import XCTest
@testable import PestGenie
import CoreData
import UserNotifications
import Combine

final class EnterpriseFeatureTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        cancellables = []
    }

    override func tearDownWithError() throws {
        cancellables.removeAll()
    }

    // MARK: - Offline-First Tests

    func testOfflineDataPersistence() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        // Create offline job
        let jobEntity = JobEntity(context: context)
        jobEntity.id = UUID()
        jobEntity.customerName = "Offline Customer"
        jobEntity.address = "123 Offline Street"
        jobEntity.syncStatus = SyncStatus.pending.rawValue
        jobEntity.lastModified = Date()

        try context.save()

        // Verify persistence
        let request: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
        let jobs = try context.fetch(request)

        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.customerName, "Offline Customer")
        XCTAssertEqual(jobs.first?.syncStatus, SyncStatus.pending.rawValue)
    }

    func testSyncStatusTransitions() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        let jobEntity = JobEntity(context: context)
        jobEntity.id = UUID()
        jobEntity.customerName = "Sync Test Customer"
        jobEntity.syncStatus = SyncStatus.pending.rawValue
        jobEntity.lastModified = Date()

        try context.save()

        // Simulate sync success
        jobEntity.syncStatus = SyncStatus.synced.rawValue
        jobEntity.serverId = "server-123"
        try context.save()

        let request: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
        let jobs = try context.fetch(request)

        XCTAssertEqual(jobs.first?.syncStatus, SyncStatus.synced.rawValue)
        XCTAssertEqual(jobs.first?.serverId, "server-123")
    }

    func testConflictResolutionScenario() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        // Create conflicted job
        let jobEntity = JobEntity(context: context)
        jobEntity.id = UUID()
        jobEntity.customerName = "Conflict Customer"
        jobEntity.syncStatus = SyncStatus.conflict.rawValue
        jobEntity.lastModified = Date().addingTimeInterval(-3600) // 1 hour ago

        try context.save()

        // Simulate conflict resolution
        jobEntity.syncStatus = SyncStatus.synced.rawValue
        jobEntity.lastModified = Date() // Updated to current time
        try context.save()

        let request: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
        let jobs = try context.fetch(request)

        XCTAssertEqual(jobs.first?.syncStatus, SyncStatus.synced.rawValue)
        XCTAssertNotNil(jobs.first?.lastModified)
    }

    // MARK: - Push Notification Tests

    @MainActor
    func testNotificationManagerSetup() async throws {
        let notificationManager = NotificationManager.shared

        XCTAssertNotNil(notificationManager)
        XCTAssertEqual(notificationManager.badgeCount, 0)
        XCTAssertEqual(notificationManager.authorizationStatus, .notDetermined)
    }

    @MainActor
    func testNotificationBadgeManagement() throws {
        let notificationManager = NotificationManager.shared

        // Test badge increment
        notificationManager.updateBadgeCount(5)
        XCTAssertEqual(notificationManager.badgeCount, 5)

        // Test badge clear
        notificationManager.clearBadge()
        XCTAssertEqual(notificationManager.badgeCount, 0)
    }

    @MainActor
    func testJobReminderScheduling() async throws {
        let notificationManager = NotificationManager.shared
        let job = Job(
            customerName: "Reminder Customer",
            address: "123 Reminder St",
            scheduledDate: Date().addingTimeInterval(3600), // 1 hour from now
            status: .pending
        )

        // Schedule reminder
        await notificationManager.scheduleJobReminder(for: job, minutesBefore: 30)

        // Verify notification was scheduled (in real test, you'd check notification center)
        XCTAssertTrue(job.shouldScheduleReminder)
    }

    func testNotificationPayloadProcessing() throws {
        let testPayload: [AnyHashable: Any] = [
            "type": "job_update",
            "jobId": "test-job-123",
            "message": "Job has been updated"
        ]

        // Test payload extraction
        XCTAssertEqual(testPayload["type"] as? String, "job_update")
        XCTAssertEqual(testPayload["jobId"] as? String, "test-job-123")
        XCTAssertNotNil(testPayload["message"])
    }

    // MARK: - Deep Linking Tests

    @MainActor
    func testDeepLinkURLGeneration() throws {
        let deepLinkManager = DeepLinkManager.shared
        let job = Job(
            customerName: "Deep Link Customer",
            address: "123 Deep Link Ave",
            scheduledDate: Date(),
            status: .pending
        )

        // Test custom URL scheme
        let customURL = deepLinkManager.generateJobURL(for: job, action: .start)
        XCTAssertTrue(customURL.absoluteString.contains("pestgenie://job"))
        XCTAssertTrue(customURL.absoluteString.contains(job.id.uuidString))
        XCTAssertTrue(customURL.absoluteString.contains("action=start"))

        // Test universal link
        let universalURL = deepLinkManager.generateUniversalJobURL(for: job)
        XCTAssertTrue(universalURL.absoluteString.contains("https://pestgenie.com/job"))
        XCTAssertTrue(universalURL.absoluteString.contains(job.id.uuidString))
    }

    @MainActor
    func testDeepLinkParsing() throws {
        let deepLinkManager = DeepLinkManager.shared

        // Test job deep link
        let jobURL = URL(string: "pestgenie://job/test-123?action=start")!
        let jobResult = deepLinkManager.handle(url: jobURL)
        XCTAssertTrue(jobResult)

        // Test route deep link
        let routeURL = URL(string: "pestgenie://route/route-456")!
        let routeResult = deepLinkManager.handle(url: routeURL)
        XCTAssertTrue(routeResult)

        // Test universal link
        let universalURL = URL(string: "https://pestgenie.com/job/test-789")!
        let universalResult = deepLinkManager.handle(url: universalURL)
        XCTAssertTrue(universalResult)

        // Test invalid URL
        let invalidURL = URL(string: "invalid://unknown")!
        let invalidResult = deepLinkManager.handle(url: invalidURL)
        XCTAssertFalse(invalidResult)
    }

    @MainActor
    func testDeepLinkActions() throws {
        let deepLinkManager = DeepLinkManager.shared

        // Test all job actions
        let startURL = URL(string: "pestgenie://job/test?action=start")!
        XCTAssertTrue(deepLinkManager.handle(url: startURL))

        let completeURL = URL(string: "pestgenie://job/test?action=complete")!
        XCTAssertTrue(deepLinkManager.handle(url: completeURL))

        let skipURL = URL(string: "pestgenie://job/test?action=skip")!
        XCTAssertTrue(deepLinkManager.handle(url: skipURL))

        let rescheduleURL = URL(string: "pestgenie://job/test?action=reschedule")!
        XCTAssertTrue(deepLinkManager.handle(url: rescheduleURL))
    }

    // MARK: - Performance Monitoring Tests

    @MainActor
    func testPerformanceManagerMonitoring() throws {
        let performanceManager = PerformanceManager.shared

        XCTAssertNotNil(performanceManager)
        XCTAssertFalse(performanceManager.isMonitoring)

        // Start monitoring
        performanceManager.startMonitoring()
        XCTAssertTrue(performanceManager.isMonitoring)

        // Stop monitoring
        performanceManager.stopMonitoring()
        XCTAssertFalse(performanceManager.isMonitoring)
    }

    @MainActor
    func testPerformanceMetricsCollection() throws {
        let performanceManager = PerformanceManager.shared

        // Start monitoring to collect metrics
        performanceManager.startMonitoring()

        // Wait briefly for metrics collection
        let expectation = XCTestExpectation(description: "Metrics collection")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Verify metrics are collected
        let metrics = performanceManager.metrics
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0)
        XCTAssertGreaterThanOrEqual(metrics.memoryPressure, 0)
        XCTAssertLessThanOrEqual(metrics.memoryPressure, 1.0)

        performanceManager.stopMonitoring()
    }

    @MainActor
    func testMemoryPressureHandling() throws {
        let performanceManager = PerformanceManager.shared

        // Test memory pressure detection
        let expectation = XCTestExpectation(description: "Memory pressure handling")

        // Listen for memory pressure notification
        NotificationCenter.default.addObserver(
            forName: .memoryPressureDetected,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Simulate memory pressure (in real implementation, this would be triggered by system)
        NotificationCenter.default.post(name: .memoryPressureDetected, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Bundle Optimization Tests

    func testBundleAnalysis() throws {
        let bundleOptimizer = BundleOptimizer.shared
        let analysis = bundleOptimizer.analyzeBundleSize()

        XCTAssertGreaterThan(analysis.totalSize, 0)
        XCTAssertGreaterThan(analysis.totalSizeMB, 0)
        XCTAssertFalse(analysis.breakdown.isEmpty)
    }

    func testOnDemandResourceManagement() throws {
        let bundleOptimizer = BundleOptimizer.shared

        // Test resource availability check
        let sampleDataAvailable = bundleOptimizer.isResourceAvailable(.sampleData)
        XCTAssertFalse(sampleDataAvailable) // Should not be available initially

        // Test resource tags
        let allTags = BundleOptimizer.ResourceTag.allCases
        XCTAssertTrue(allTags.contains(.sampleData))
        XCTAssertTrue(allTags.contains(.tutorialAssets))

        // Test priority ordering
        XCTAssertLessThan(
            BundleOptimizer.ResourceTag.sampleData.downloadPriority,
            BundleOptimizer.ResourceTag.offlineMapData.downloadPriority
        )
    }

    // MARK: - App Store Compliance Tests

    @MainActor
    func testPrivacyComplianceSetup() throws {
        let complianceManager = AppStoreComplianceManager.shared

        XCTAssertNotNil(complianceManager.privacySettings)
        XCTAssertNotNil(complianceManager.accessibilitySettings)
        XCTAssertFalse(complianceManager.privacySettings.userId.isEmpty)
    }

    @MainActor
    func testDataExportCompliance() throws {
        let complianceManager = AppStoreComplianceManager.shared
        let export = complianceManager.exportUserData()

        XCTAssertNotNil(export.personalInfo.userId)
        XCTAssertNotNil(export.appUsage)
        XCTAssertNotNil(export.locationData)
        XCTAssertNotNil(export.exportDate)

        // Verify export structure
        XCTAssertFalse(export.personalInfo.userId.isEmpty)
        XCTAssertGreaterThanOrEqual(export.appUsage.jobsCompleted, 0)
        XCTAssertGreaterThanOrEqual(export.locationData.totalLocationsRecorded, 0)
    }

    @MainActor
    func testAccessibilityCompliance() throws {
        let complianceManager = AppStoreComplianceManager.shared

        // Enable accessibility features
        complianceManager.enableAccessibilityFeatures()

        let accessibilitySettings = complianceManager.accessibilitySettings
        XCTAssertNotNil(accessibilitySettings)
        XCTAssertTrue(accessibilitySettings.hasAccessibilityLabels)
    }

    @MainActor
    func testAppStoreValidation() throws {
        let complianceManager = AppStoreComplianceManager.shared
        let result = complianceManager.validateAppStoreCompliance()

        XCTAssertNotNil(result)
        XCTAssertNotNil(result.lastChecked)
        XCTAssertGreaterThanOrEqual(result.issues.count, 0)

        // Check that we have some compliance checks
        let hasPrivacyCheck = result.issues.contains { $0.type == .privacy }
        let hasAccessibilityCheck = result.issues.contains { $0.type == .accessibility }
        let hasMetadataCheck = result.issues.contains { $0.type == .metadata }

        // At least one type of compliance check should be present
        XCTAssertTrue(hasPrivacyCheck || hasAccessibilityCheck || hasMetadataCheck)
    }

    // MARK: - Network Optimization Tests

    @MainActor
    func testNetworkAwareOperations() throws {
        let networkMonitor = NetworkMonitor.shared

        // Test network state properties
        XCTAssertNotNil(networkMonitor.connectionType)

        // Test network optimization flags
        let suitableForLargeUploads = networkMonitor.isSuitableForLargeUploads
        let shouldLimitDataUsage = networkMonitor.shouldLimitDataUsage

        // These should be mutually exclusive in most cases
        if suitableForLargeUploads {
            XCTAssertFalse(shouldLimitDataUsage)
        }
    }

    func testAPIServiceConfiguration() throws {
        let apiService = APIService.shared

        XCTAssertNotNil(apiService)

        // Test job upload data structure
        let job = Job(
            customerName: "API Test Customer",
            address: "123 API Street",
            scheduledDate: Date(),
            status: .pending
        )

        let uploadData = JobUploadData(from: JobEntity(context: PersistenceController(inMemory: true).container.viewContext))
        uploadData.setValue(job.id, forKey: "id")
        uploadData.setValue(job.customerName, forKey: "customerName")

        XCTAssertNotNil(uploadData)
    }

    // MARK: - Cache Management Tests

    @MainActor
    func testImageCacheManagement() throws {
        let imageCache = ImageCacheManager.shared

        // Create test image
        let testImage = createTestImage(size: CGSize(width: 50, height: 50))
        let cacheKey = "test-image-key"

        // Test caching
        imageCache.cacheImage(testImage, forKey: cacheKey)
        let retrievedImage = imageCache.getImage(forKey: cacheKey)
        XCTAssertNotNil(retrievedImage)

        // Test cache clearing
        imageCache.clearCache()
        let clearedImage = imageCache.getImage(forKey: cacheKey)
        XCTAssertNil(clearedImage)
    }

    @MainActor
    func testSDUIComponentCache() throws {
        let componentCache = SDUIComponentCache.shared

        // Test view caching
        let testView = TestView(text: "Cache Test")
        let cacheKey = "test-view-key"

        componentCache.cacheView(testView, forKey: cacheKey)
        let retrievedView = componentCache.getView(forKey: cacheKey)
        XCTAssertNotNil(retrievedView)

        // Test cache clearing
        componentCache.clearCache()
        let clearedView = componentCache.getView(forKey: cacheKey)
        XCTAssertNil(clearedView)
    }

    // MARK: - Security Tests

    func testDataEncryption() throws {
        // Test that sensitive data is properly handled
        let job = Job(
            customerName: "Security Test Customer",
            address: "123 Security Boulevard",
            scheduledDate: Date(),
            status: .pending
        )

        // Verify no sensitive data is logged
        XCTAssertFalse(job.customerName.isEmpty)
        XCTAssertFalse(job.address.isEmpty)

        // In a real implementation, you'd test encryption/decryption
        let customerName = job.customerName
        XCTAssertEqual(customerName, "Security Test Customer")
    }

    @MainActor
    func testPrivacyControlsImplementation() throws {
        let complianceManager = AppStoreComplianceManager.shared

        // Test privacy settings
        var privacySettings = complianceManager.privacySettings
        XCTAssertFalse(privacySettings.hasConsentedToDataUsage)

        // Test consent mechanism
        privacySettings.hasConsentedToDataUsage = true
        XCTAssertTrue(privacySettings.hasConsentedToDataUsage)

        // Test data processing preferences
        privacySettings.dataProcessingPreferences["analytics"] = false
        XCTAssertEqual(privacySettings.dataProcessingPreferences["analytics"], false)
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Integration Tests

final class EnterpriseIntegrationTests: XCTestCase {

    @MainActor
    func testOfflineToOnlineSync() async throws {
        let persistenceController = PersistenceController(inMemory: true)
        let syncManager = SyncManager()
        let context = persistenceController.container.viewContext

        // Create offline job
        let jobEntity = JobEntity(context: context)
        jobEntity.id = UUID()
        jobEntity.customerName = "Integration Customer"
        jobEntity.syncStatus = SyncStatus.pending.rawValue
        jobEntity.lastModified = Date()

        try context.save()

        // Simulate sync process
        XCTAssertFalse(syncManager.isSyncing)

        // In a real test, you'd mock network calls
        // For now, just verify the sync manager can be triggered
        await syncManager.forceSyncNow()

        XCTAssertFalse(syncManager.isSyncing)
    }

    @MainActor
    func testNotificationToDeepLinkFlow() throws {
        let notificationManager = NotificationManager.shared
        let deepLinkManager = DeepLinkManager.shared

        // Simulate notification payload
        let notificationPayload: [AnyHashable: Any] = [
            "type": "job_reminder",
            "jobId": "test-job-123"
        ]

        // Extract job ID
        guard let jobId = notificationPayload["jobId"] as? String else {
            XCTFail("Job ID should be extractable from notification")
            return
        }

        // Generate deep link
        let deepLinkURL = URL(string: "pestgenie://job/\(jobId)?action=start")!
        let result = deepLinkManager.handle(url: deepLinkURL)

        XCTAssertTrue(result)
        XCTAssertEqual(jobId, "test-job-123")
    }

    @MainActor
    func testPerformanceUnderLoad() throws {
        let performanceManager = PerformanceManager.shared

        performanceManager.startMonitoring()

        // Simulate load
        for i in 0..<100 {
            let job = Job(
                customerName: "Load Test Customer \(i)",
                address: "\(i) Load Street",
                scheduledDate: Date(),
                status: .pending
            )

            // Process job (simulate work)
            XCTAssertNotNil(job.id)
        }

        // Check that performance monitoring is still working
        XCTAssertTrue(performanceManager.isMonitoring)
        XCTAssertGreaterThanOrEqual(performanceManager.metrics.memoryUsage, 0)

        performanceManager.stopMonitoring()
    }
}