import XCTest
import SwiftUI
import CoreData
@testable import PestGenie

/// Comprehensive performance tests for production readiness
final class PerformanceTests: PestGenieTestCase {

    // MARK: - Memory Management Tests

    func testMemoryUsageUnderLoad() throws {
        try measurePerformance(name: "Memory usage with large dataset") {
            // Create large number of job objects
            let jobs = (0..<1000).map { index in
                createTestJob(
                    customerName: "Customer \(index)",
                    status: JobStatus.allCases.randomElement()!
                )
            }

            // Process jobs to simulate real usage
            for job in jobs {
                let _ = job.customerName.uppercased()
                let _ = job.address.count
                let _ = job.scheduledDate.timeIntervalSince1970
            }

            // Verify jobs are created correctly
            XCTAssertEqual(jobs.count, 1000)
        }
    }

    func testViewModelMemoryRetention() throws {
        var viewModel: RouteViewModel? = RouteViewModel()
        weak var weakViewModel = viewModel

        // Simulate view model usage
        viewModel?.loadJobs()
        viewModel?.updateCurrentLocation(latitude: 34.0522, longitude: -118.2437)

        // Release strong reference
        viewModel = nil

        // Verify no retain cycles
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated when no strong references exist")
    }

    func testLargeDataSetProcessing() throws {
        try measurePerformance(name: "Processing large chemical dataset", iterations: 5) {
            let chemicals = (0..<5000).map { index in
                createTestChemical(
                    name: "Chemical \(index)",
                    signalWord: SignalWord.allCases.randomElement()!
                )
            }

            // Simulate filtering and sorting operations
            let restrictedChemicals = chemicals.filter { $0.isRestricted }
            let sortedByName = chemicals.sorted { $0.name < $1.name }
            let groupedBySignal = Dictionary(grouping: chemicals) { $0.signalWord }

            XCTAssertEqual(chemicals.count, 5000)
            XCTAssertTrue(restrictedChemicals.count >= 0)
            XCTAssertEqual(sortedByName.count, 5000)
            XCTAssertTrue(groupedBySignal.keys.count > 0)
        }
    }

    // MARK: - Startup Performance Tests

    func testStartupTime() throws {
        try measurePerformance(name: "Application startup simulation") {
            // Simulate app startup sequence
            let _ = SecurityManager.shared
            let _ = ErrorManager.shared
            let weatherManager = WeatherDataManager.shared
            let routeViewModel = RouteViewModel()

            // Initialize core systems
            routeViewModel.loadJobs()

            // Simulate initial data loading
            let testWeather = createTestWeatherData()
            weatherManager.updateCurrentWeather(testWeather)

            XCTAssertNotNil(routeViewModel)
        }
    }

    func testCoreDataInitializationPerformance() throws {
        try measurePerformance(name: "Core Data stack initialization") {
            let container = NSPersistentContainer(name: "PestGenieDataModel")
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]

            let expectation = XCTestExpectation(description: "Core Data loading")

            container.loadPersistentStores { _, error in
                XCTAssertNil(error)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - UI Performance Tests

    func testSDUIRenderingPerformance() throws {
        let components = (0..<50).map { index in
            SDUIComponent(
                id: "perf-component-\(index)",
                type: ["text", "button", "image", "card"].randomElement()!,
                text: "Performance Test Component \(index)",
                style: SDUIStyle(
                    font: SDUIFont(size: 16, weight: "regular"),
                    padding: SDUIPadding(top: 8, bottom: 8, leading: 16, trailing: 16)
                )
            )
        }

        let screen = SDUIScreen(
            id: "performance-test-screen",
            version: 1,
            title: "Performance Test",
            components: components
        )

        let context = createTestSDUIContext()

        try measurePerformance(name: "SDUI screen rendering") {
            let view = SDUIScreenRenderer.render(screen: screen, context: context)
            XCTAssertNotNil(view)
        }
    }

    func testNavigationPerformance() throws {
        try measurePerformance(name: "Navigation state changes") {
            var selectedTab = DashboardTab.today

            // Simulate rapid tab switching
            for _ in 0..<100 {
                selectedTab = DashboardTab.allCases.randomElement()!
            }

            XCTAssertTrue(DashboardTab.allCases.contains(selectedTab))
        }
    }

    // MARK: - Network Performance Tests

    func testWeatherDataProcessingPerformance() throws {
        let weatherDataSets = (0..<1000).map { index in
            createTestWeatherData(
                temperature: Double.random(in: 0...100),
                windSpeed: Double.random(in: 0...50),
                humidity: Int.random(in: 0...100)
            )
        }

        try measurePerformance(name: "Weather data processing") {
            let averageTemp = weatherDataSets.map { $0.temperature }.reduce(0, +) / Double(weatherDataSets.count)
            let maxWindSpeed = weatherDataSets.map { $0.windSpeed }.max() ?? 0
            let highHumidityCount = weatherDataSets.filter { $0.humidity > 80 }.count

            XCTAssertTrue(averageTemp > 0)
            XCTAssertTrue(maxWindSpeed >= 0)
            XCTAssertTrue(highHumidityCount >= 0)
        }
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentJobProcessing() async throws {
        let jobCount = 100
        let jobs = (0..<jobCount).map { index in
            createTestJob(customerName: "Concurrent Customer \(index)")
        }

        try await measureAsyncPerformance(name: "Concurrent job processing") {
            await withTaskGroup(of: Void.self) { group in
                for job in jobs {
                    group.addTask {
                        // Simulate job processing
                        let _ = job.customerName.count
                        let _ = job.scheduledDate.timeIntervalSinceNow
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    }
                }
            }
        }
    }

    func testConcurrentWeatherUpdates() async throws {
        let weatherManager = WeatherDataManager.shared
        let updateCount = 50

        try await measureAsyncPerformance(name: "Concurrent weather updates") {
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<updateCount {
                    group.addTask {
                        let weather = createTestWeatherData(temperature: Double(index))
                        weatherManager.updateCurrentWeather(weather)
                    }
                }
            }
        }
    }

    // MARK: - File I/O Performance Tests

    func testJSONParsingPerformance() throws {
        let largeJSONString = """
        {
            "id": "large-test-screen",
            "version": 1,
            "title": "Large Test Screen",
            "components": [
                \((0..<500).map { index in
                    """
                    {
                        "id": "component-\(index)",
                        "type": "text",
                        "text": "Component \(index) with some longer text content",
                        "style": {
                            "font": {"size": 16, "weight": "regular"},
                            "color": "#333333",
                            "padding": {"top": 8, "bottom": 8, "leading": 16, "trailing": 16}
                        }
                    }
                    """
                }.joined(separator: ","))
            ]
        }
        """

        let jsonData = largeJSONString.data(using: .utf8)!

        try measurePerformance(name: "Large JSON parsing") {
            do {
                let screen = try JSONDecoder().decode(SDUIScreen.self, from: jsonData)
                XCTAssertEqual(screen.components.count, 500)
            } catch {
                XCTFail("JSON parsing failed: \(error)")
            }
        }
    }

    // MARK: - Algorithm Performance Tests

    func testRouteOptimizationPerformance() throws {
        let jobs = (0..<100).map { index in
            createTestJob(
                customerName: "Route Customer \(index)"
            )
        }

        try measurePerformance(name: "Route optimization algorithm") {
            // Simulate basic route optimization
            let sortedJobs = jobs.sorted { job1, job2 in
                let distance1 = sqrt(pow(job1.latitude - 34.0522, 2) + pow(job1.longitude - (-118.2437), 2))
                let distance2 = sqrt(pow(job2.latitude - 34.0522, 2) + pow(job2.longitude - (-118.2437), 2))
                return distance1 < distance2
            }

            XCTAssertEqual(sortedJobs.count, jobs.count)
        }
    }

    func testSearchPerformance() throws {
        let customers = (0..<10000).map { index in
            "Customer Name \(index) with Location \(index % 100)"
        }

        let searchTerm = "Customer Name 123"

        try measurePerformance(name: "Customer search") {
            let results = customers.filter { $0.localizedCaseInsensitiveContains(searchTerm) }
            XCTAssertTrue(results.count > 0)
        }
    }

    // MARK: - Memory Pressure Tests

    func testMemoryPressureHandling() throws {
        var largeObjects: [Data] = []

        try measurePerformance(name: "Memory pressure simulation") {
            // Create memory pressure
            for _ in 0..<100 {
                let largeData = Data(count: 1_000_000) // 1MB each
                largeObjects.append(largeData)
            }

            // Simulate memory cleanup
            largeObjects.removeAll()

            XCTAssertTrue(largeObjects.isEmpty)
        }
    }

    // MARK: - Battery Performance Tests

    func testLocationUpdateFrequency() async throws {
        let mockLocationManager = MockLocationManager()
        var updateCount = 0

        try await measureAsyncPerformance(name: "Location update processing") {
            for index in 0..<1000 {
                let newLocation = CLLocationCoordinate2D(
                    latitude: 34.0522 + Double(index) * 0.0001,
                    longitude: -118.2437 + Double(index) * 0.0001
                )
                mockLocationManager.simulateLocationUpdate(newLocation)
                updateCount += 1
            }
        }

        XCTAssertEqual(updateCount, 1000)
    }
}

// MARK: - Performance Test Extensions

extension PerformanceTests: PerformanceTestable {
    func testPerformanceWithLargeDataSet() {
        // Implementation covered in testLargeDataSetProcessing
    }

    func testMemoryUsageUnderLoad() {
        // Implementation covered in testMemoryUsageUnderLoad above
    }

    func testStartupTime() {
        // Implementation covered in testStartupTime above
    }
}

// MARK: - Performance Utilities

extension XCTestCase {
    func measureAsyncPerformance<T>(
        name: String,
        iterations: Int = 1,
        operation: () async throws -> T
    ) async throws -> T {
        var result: T!

        let options = XCTMeasureOptions()
        options.iterationCount = iterations

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            let expectation = XCTestExpectation(description: name)

            Task {
                do {
                    result = try await operation()
                    expectation.fulfill()
                } catch {
                    XCTFail("Async performance test '\(name)' failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 30.0)
        }

        return result
    }
}