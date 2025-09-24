import XCTest
import CoreData
@testable import PestGenie

/// Integration tests for data synchronization and offline capabilities
final class SyncIntegrationTests: PestGenieTestCase {

    var syncManager: SyncManager!
    var offlineManager: OfflineManager!

    override func setUp() {
        super.setUp()
        syncManager = SyncManager.shared
        offlineManager = OfflineManager.shared
    }

    override func tearDown() {
        syncManager = nil
        offlineManager = nil
        super.tearDown()
    }

    // MARK: - Sync Integration Tests

    func testFullSyncCycle() async throws {
        // Given
        let testJobs = [
            createTestJob(customerName: "Sync Customer 1"),
            createTestJob(customerName: "Sync Customer 2"),
            createTestJob(customerName: "Sync Customer 3")
        ]

        // Mock successful sync response
        mockSuccessfulResponse(for: "/api/sync/jobs", with: testJobs)

        // When
        try await syncManager.syncNow()

        // Then
        let syncStatus = syncManager.lastSyncStatus
        XCTAssertEqual(syncStatus, .completed, "Sync should complete successfully")
        XCTAssertNotNil(syncManager.lastSyncTime, "Last sync time should be recorded")
    }

    func testIncrementalSync() async throws {
        // Given
        let lastSyncTime = Date().addingTimeInterval(-3600) // 1 hour ago
        syncManager.setLastSyncTime(lastSyncTime)

        let deltaJobs = [createTestJob(customerName: "Delta Customer")]
        mockSuccessfulResponse(for: "/api/sync/delta", with: deltaJobs)

        // When
        try await syncManager.performIncrementalSync()

        // Then
        XCTAssertTrue(syncManager.lastSyncTime! > lastSyncTime, "Sync time should be updated")
    }

    func testConflictResolution() async throws {
        // Given
        let localJob = createTestJob(customerName: "Conflict Customer")
        let serverJob = createTestJob(
            id: localJob.id,
            customerName: "Server Modified Customer"
        )

        // Simulate conflict scenario
        mockSuccessfulResponse(for: "/api/sync/conflicts", with: [serverJob])

        // When
        let resolvedJob = try await syncManager.resolveConflict(local: localJob, server: serverJob)

        // Then
        XCTAssertNotNil(resolvedJob, "Conflict should be resolved")
        // In production, this would use business logic to determine resolution strategy
    }

    func testSyncWithNetworkFailure() async throws {
        // Given
        mockErrorResponse(for: "/api/sync/jobs", statusCode: 500)

        // When/Then
        do {
            try await syncManager.syncNow()
            XCTFail("Sync should fail with network error")
        } catch {
            XCTAssertTrue(error is NetworkError, "Should throw network error")
            XCTAssertEqual(syncManager.lastSyncStatus, .failed, "Sync status should be failed")
        }
    }

    // MARK: - Offline Capability Tests

    func testOfflineJobCreation() async throws {
        // Given
        offlineManager.setOfflineMode(true)
        let job = createTestJob(customerName: "Offline Customer")

        // When
        try await offlineManager.saveJobOffline(job)

        // Then
        let pendingJobs = await offlineManager.getPendingJobs()
        XCTAssertEqual(pendingJobs.count, 1, "Should have one pending offline job")
        XCTAssertEqual(pendingJobs.first?.customerName, "Offline Customer")
    }

    func testOfflineJobModification() async throws {
        // Given
        offlineManager.setOfflineMode(true)
        var job = createTestJob(customerName: "Original Customer")
        try await offlineManager.saveJobOffline(job)

        // When
        job.customerName = "Modified Customer"
        job.notes = "Updated offline"
        try await offlineManager.updateJobOffline(job)

        // Then
        let pendingJobs = await offlineManager.getPendingJobs()
        XCTAssertEqual(pendingJobs.first?.customerName, "Modified Customer")
        XCTAssertEqual(pendingJobs.first?.notes, "Updated offline")
    }

    func testOfflineToOnlineSync() async throws {
        // Given - Create offline changes
        offlineManager.setOfflineMode(true)
        let offlineJob = createTestJob(customerName: "Offline Job")
        try await offlineManager.saveJobOffline(offlineJob)

        // Mock successful upload
        mockSuccessfulResponse(for: "/api/jobs", with: offlineJob)

        // When - Go online and sync
        offlineManager.setOfflineMode(false)
        try await syncManager.syncPendingChanges()

        // Then
        let pendingJobs = await offlineManager.getPendingJobs()
        XCTAssertTrue(pendingJobs.isEmpty, "Pending jobs should be cleared after successful sync")
    }

    // MARK: - Data Consistency Tests

    func testDataIntegrityAfterSync() async throws {
        // Given
        let originalJobs = [
            createTestJob(customerName: "Integrity Test 1"),
            createTestJob(customerName: "Integrity Test 2")
        ]

        mockSuccessfulResponse(for: "/api/sync/jobs", with: originalJobs)

        // When
        try await syncManager.syncNow()

        // Then
        let localJobs = await JobDataManager.shared.getAllJobs()
        XCTAssertEqual(localJobs.count, originalJobs.count, "Local job count should match synced data")

        for (index, localJob) in localJobs.enumerated() {
            let originalJob = originalJobs[index]
            XCTAssertEqual(localJob.id, originalJob.id, "Job IDs should match")
            XCTAssertEqual(localJob.customerName, originalJob.customerName, "Customer names should match")
        }
    }

    func testConcurrentSyncOperations() async throws {
        // Given
        let job1 = createTestJob(customerName: "Concurrent 1")
        let job2 = createTestJob(customerName: "Concurrent 2")

        mockSuccessfulResponse(for: "/api/jobs/1", with: job1)
        mockSuccessfulResponse(for: "/api/jobs/2", with: job2)

        // When - Perform concurrent sync operations
        async let sync1 = syncManager.syncJob(job1)
        async let sync2 = syncManager.syncJob(job2)

        let results = try await [sync1, sync2]

        // Then
        XCTAssertEqual(results.count, 2, "Both sync operations should complete")
        results.forEach { result in
            XCTAssertTrue(result, "Each sync operation should succeed")
        }
    }

    // MARK: - Error Recovery Tests

    func testSyncRetryAfterFailure() async throws {
        // Given
        let job = createTestJob(customerName: "Retry Test")
        var attemptCount = 0

        // Mock first attempt to fail, second to succeed
        mockNetworkManager.mockResponse(for: "/api/jobs", data: nil, statusCode: 500)

        // When
        do {
            try await syncManager.syncJob(job)
        } catch {
            attemptCount += 1
            XCTAssertEqual(attemptCount, 1, "First attempt should fail")
        }

        // Mock success for retry
        mockSuccessfulResponse(for: "/api/jobs", with: job)

        // Retry
        try await syncManager.syncJob(job)
        XCTAssertTrue(true, "Retry should succeed")
    }

    func testPartialSyncRecovery() async throws {
        // Given
        let jobs = [
            createTestJob(customerName: "Success Job"),
            createTestJob(customerName: "Failure Job")
        ]

        // Mock partial failure
        mockSuccessfulResponse(for: "/api/jobs/success", with: jobs[0])
        mockErrorResponse(for: "/api/jobs/failure", statusCode: 400)

        // When
        let results = await syncManager.syncJobsBatch(jobs)

        // Then
        XCTAssertEqual(results.successCount, 1, "One job should sync successfully")
        XCTAssertEqual(results.failureCount, 1, "One job should fail to sync")
        XCTAssertEqual(results.failedJobs.count, 1, "Failed jobs should be tracked")
    }

    // MARK: - Performance Integration Tests

    func testLargeBatchSync() async throws {
        // Given
        let largeJobBatch = (0..<500).map { index in
            createTestJob(customerName: "Batch Customer \(index)")
        }

        mockSuccessfulResponse(for: "/api/sync/batch", with: largeJobBatch)

        // When/Then
        try await measureAsyncPerformance(name: "Large batch sync") {
            try await syncManager.syncJobsBatch(largeJobBatch)
        }

        XCTAssertEqual(syncManager.lastSyncStatus, .completed, "Large batch sync should complete")
    }

    func testHighFrequencySync() async throws {
        // Given
        let job = createTestJob(customerName: "High Frequency Test")
        mockSuccessfulResponse(for: "/api/jobs/frequent", with: job)

        // When - Perform rapid sync operations
        try await measureAsyncPerformance(name: "High frequency sync", iterations: 10) {
            for _ in 0..<10 {
                try await syncManager.syncJob(job)
            }
        }

        XCTAssertTrue(true, "High frequency sync should handle load")
    }

    // MARK: - Real-world Scenario Tests

    func testTypicalDayScenario() async throws {
        // Given - Simulate a typical technician day
        let morningJobs = (0..<5).map { index in
            createTestJob(customerName: "Morning Customer \(index)")
        }

        let afternoonJobs = (0..<3).map { index in
            createTestJob(customerName: "Afternoon Customer \(index)")
        }

        // When - Morning sync
        mockSuccessfulResponse(for: "/api/sync/morning", with: morningJobs)
        try await syncManager.syncNow()

        // Simulate some offline work
        offlineManager.setOfflineMode(true)
        let completedJob = morningJobs[0]
        // Mark job as completed offline
        try await offlineManager.updateJobOffline(completedJob)

        // Afternoon sync when back online
        offlineManager.setOfflineMode(false)
        mockSuccessfulResponse(for: "/api/sync/afternoon", with: afternoonJobs)
        try await syncManager.syncNow()

        // Then
        let allJobs = await JobDataManager.shared.getAllJobs()
        XCTAssertEqual(allJobs.count, morningJobs.count + afternoonJobs.count,
                      "Should have all morning and afternoon jobs")
    }

    func testNetworkTransitionScenario() async throws {
        // Given - Start online
        offlineManager.setOfflineMode(false)
        let onlineJob = createTestJob(customerName: "Online Job")
        mockSuccessfulResponse(for: "/api/jobs/online", with: onlineJob)

        // When - Sync while online
        try await syncManager.syncJob(onlineJob)

        // Go offline
        offlineManager.setOfflineMode(true)
        let offlineJob = createTestJob(customerName: "Offline Job")
        try await offlineManager.saveJobOffline(offlineJob)

        // Return online
        offlineManager.setOfflineMode(false)
        mockSuccessfulResponse(for: "/api/jobs/return", with: offlineJob)
        try await syncManager.syncPendingChanges()

        // Then
        let pendingJobs = await offlineManager.getPendingJobs()
        XCTAssertTrue(pendingJobs.isEmpty, "No pending jobs should remain after sync")
    }
}

// MARK: - Mock Sync Components

extension SyncIntegrationTests {

    struct SyncResult {
        let successCount: Int
        let failureCount: Int
        let failedJobs: [Job]
    }

    struct MockSyncManager {
        var lastSyncTime: Date?
        var lastSyncStatus: SyncStatus = .idle

        func setLastSyncTime(_ time: Date) {
            lastSyncTime = time
        }

        func syncNow() async throws {
            // Simulate sync operation
            lastSyncStatus = .inProgress
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            lastSyncStatus = .completed
            lastSyncTime = Date()
        }
    }

    enum SyncStatus {
        case idle
        case inProgress
        case completed
        case failed
    }

    enum NetworkError: Error {
        case connectionFailed
        case serverError
        case timeout
    }
}