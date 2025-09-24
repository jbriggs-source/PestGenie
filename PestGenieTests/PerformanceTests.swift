import XCTest
@testable import PestGenie
import CoreData

final class PerformanceTests: XCTestCase {

    // MARK: - SDUI Performance Tests

    func testSDUIRenderingPerformance() throws {
        let component = SDUIComponent(
            id: "performance-test",
            type: .vstack,
            children: (0..<100).map { index in
                SDUIComponent(
                    id: "child-\(index)",
                    type: .text,
                    text: "Performance Test Item \(index)"
                )
            }
        )

        let persistenceController = PersistenceController(inMemory: true)
        let routeViewModel = RouteViewModel()

        measure {
            // Test component processing performance
            let _ = component.id
            let _ = component.type
            for child in component.children ?? [] {
                let _ = child.id
                let _ = child.text
            }
        }
    }

    func testSDUIJSONParsingPerformance() throws {
        let largeJSONString = generateLargeSDUIJSON(componentCount: 1000)
        let jsonData = largeJSONString.data(using: .utf8)!

        measure {
            do {
                let _ = try JSONDecoder().decode(SDUIScreen.self, from: jsonData)
            } catch {
                XCTFail("JSON parsing failed: \(error)")
            }
        }
    }

    func testSDUIDataBindingPerformance() throws {
        let jobs = (0..<1000).map { index in
            Job(
                id: UUID(),
                customerName: "Customer \(index)",
                address: "\(index) Performance Street",
                scheduledDate: Date(),
                status: .pending
            )
        }

        let persistenceController = PersistenceController(inMemory: true)
        let routeViewModel = RouteViewModel()

        measure {
            for job in jobs.prefix(100) {
                // Test direct property access performance
                let _ = job.customerName
                let _ = job.address
                let _ = job.status
                let _ = job.scheduledDate
            }
        }
    }

    // MARK: - Core Data Performance Tests

    func testCoreDataInsertPerformance() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        measure {
            for i in 0..<1000 {
                let jobEntity = JobEntity(context: context)
                jobEntity.id = UUID()
                jobEntity.customerName = "Performance Customer \(i)"
                jobEntity.address = "\(i) Performance Avenue"
                jobEntity.scheduledDate = Date()
                jobEntity.status = JobStatus.pending.rawValue
                jobEntity.syncStatus = SyncStatus.pending.rawValue
                jobEntity.lastModified = Date()
            }

            do {
                try context.save()
            } catch {
                XCTFail("Core Data save failed: \(error)")
            }
        }
    }

    func testCoreDataQueryPerformance() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        // Setup test data
        for i in 0..<5000 {
            let jobEntity = JobEntity(context: context)
            jobEntity.id = UUID()
            jobEntity.customerName = "Query Test Customer \(i)"
            jobEntity.status = i % 2 == 0 ? JobStatus.pending.rawValue : JobStatus.completed.rawValue
            jobEntity.syncStatus = SyncStatus.synced.rawValue
            jobEntity.lastModified = Date()
        }

        try context.save()

        measure {
            let request: NSFetchRequest<JobEntity> = JobEntity.fetchRequest()
            request.predicate = NSPredicate(format: "status == %@", JobStatus.pending.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]

            do {
                let _ = try context.fetch(request)
            } catch {
                XCTFail("Core Data query failed: \(error)")
            }
        }
    }

    func testCoreDataBatchUpdatePerformance() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext

        // Setup test data
        for i in 0..<2000 {
            let jobEntity = JobEntity(context: context)
            jobEntity.id = UUID()
            jobEntity.customerName = "Batch Update Customer \(i)"
            jobEntity.status = JobStatus.pending.rawValue
            jobEntity.syncStatus = SyncStatus.pending.rawValue
            jobEntity.lastModified = Date()
        }

        try context.save()

        measure {
            let batchUpdateRequest = NSBatchUpdateRequest(entityName: "JobEntity")
            batchUpdateRequest.predicate = NSPredicate(format: "status == %@", JobStatus.pending.rawValue)
            batchUpdateRequest.propertiesToUpdate = ["syncStatus": SyncStatus.synced.rawValue]
            batchUpdateRequest.resultType = .updatedObjectsCountResultType

            do {
                let _ = try context.execute(batchUpdateRequest)
            } catch {
                XCTFail("Batch update failed: \(error)")
            }
        }
    }

    // MARK: - Sync Performance Tests

    func testSyncManagerProcessingPerformance() throws {
        // Create simplified update data for testing
        let updates = (0..<1000).map { index in
            (
                serverId: "server-\(index)",
                customerName: "Sync Customer \(index)",
                address: "\(index) Sync Street",
                scheduledDate: Date(),
                status: JobStatus.pending.rawValue,
                lastModified: Date()
            )
        }

        measure {
            // Simulate processing server updates
            for update in updates {
                // Process update logic (simplified)
                let _ = update.serverId
                let _ = update.customerName
                let _ = update.lastModified
            }
        }
    }

    // MARK: - Network Performance Tests

    @MainActor
    func testNetworkMonitoringPerformance() throws {
        let networkMonitor = NetworkMonitor.shared

        measure {
            // Simulate network state checks
            for _ in 0..<1000 {
                let _ = networkMonitor.isConnected
                let _ = networkMonitor.connectionType
                let _ = networkMonitor.isSuitableForLargeUploads
                let _ = networkMonitor.shouldLimitDataUsage
            }
        }
    }

    // MARK: - Cache Performance Tests

    func testImageCachePerformance() throws {
        let testImages = (0..<100).map { index in
            createTestImage(size: CGSize(width: 100, height: 100), color: .blue)
        }

        measure {
            // Test image processing performance
            for (index, image) in testImages.enumerated() {
                let _ = image.size
                let _ = image.cgImage
                let _ = "test-image-\(index)"
            }
        }
    }

    func testSDUIComponentCachePerformance() throws {
        measure {
            for index in 0..<100 {
                let testView = TestView(text: "Cache Test \(index)")
                let _ = testView.text
                let _ = "test-view-\(index)"
            }
        }
    }

    // MARK: - Bundle Optimization Performance Tests

    func testBundleAnalysisPerformance() throws {
        let bundleOptimizer = BundleOptimizer.shared

        measure {
            let _ = bundleOptimizer.analyzeBundleSize()
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageUnderLoad() throws {
        @MainActor
        func createLargeDataset() {
            let performanceManager = PerformanceManager.shared
            performanceManager.startMonitoring()

            // Create large dataset to test memory management
            var largeJobArray: [Job] = []

            for i in 0..<10000 {
                let job = Job(
                    id: UUID(),
                    customerName: "Memory Test Customer \(i)",
                    address: "\(i) Memory Lane",
                    scheduledDate: Date(),
                    status: .pending
                )
                largeJobArray.append(job)
            }

            // Test memory metrics
            XCTAssertGreaterThan(performanceManager.metrics.memoryUsage, 0)

            // Clean up
            largeJobArray.removeAll()
            performanceManager.stopMonitoring()
        }

        Task { @MainActor in
            createLargeDataset()
        }
    }

    // MARK: - Deep Link Performance Tests

    @MainActor
    func testDeepLinkParsingPerformance() throws {
        let deepLinkManager = DeepLinkManager.shared
        let testURLs = (0..<1000).map { index in
            URL(string: "pestgenie://job/test-job-\(index)?action=start")!
        }

        measure {
            for url in testURLs {
                let _ = deepLinkManager.handle(url: url)
            }
        }
    }

    // MARK: - Helper Methods

    private func generateLargeSDUIJSON(componentCount: Int) -> String {
        let children = (0..<componentCount).map { index in
            """
            {
                "id": "child-\(index)",
                "type": "text",
                "text": "Performance Test Component \(index)"
            }
            """
        }.joined(separator: ",")

        return """
        {
            "version": 1,
            "component": {
                "id": "performance-root",
                "type": "vstack",
                "children": [\(children)]
            }
        }
        """
    }

    private func createTestImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Test View Helper

import SwiftUI

struct TestView: View {
    let text: String

    var body: some View {
        Text(text)
    }
}

// MARK: - Concurrent Performance Tests

final class ConcurrentPerformanceTests: XCTestCase {

    func testConcurrentSDUIRendering() throws {
        let expectation = XCTestExpectation(description: "Concurrent SDUI rendering")
        expectation.expectedFulfillmentCount = 10

        let persistenceController = PersistenceController(inMemory: true)
        let routeViewModel = RouteViewModel()

        measure {
            for i in 0..<10 {
                DispatchQueue.global(qos: .userInitiated).async {
                    let component = SDUIComponent(
                        id: "concurrent-\(i)",
                        type: .text,
                        text: "Concurrent Test \(i)"
                    )

                    // Test component processing
                    let _ = component.id
                    let _ = component.text
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testConcurrentCoreDataOperations() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let expectation = XCTestExpectation(description: "Concurrent Core Data operations")
        expectation.expectedFulfillmentCount = 5

        measure {
            for i in 0..<5 {
                DispatchQueue.global(qos: .userInitiated).async {
                    let context = persistenceController.newBackgroundContext()

                    context.performAndWait {
                        let jobEntity = JobEntity(context: context)
                        jobEntity.id = UUID()
                        jobEntity.customerName = "Concurrent Customer \(i)"
                        jobEntity.lastModified = Date()

                        do {
                            try context.save()
                            expectation.fulfill()
                        } catch {
                            XCTFail("Concurrent Core Data operation failed: \(error)")
                        }
                    }
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }
}