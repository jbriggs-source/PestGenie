import XCTest
import CoreData
import CoreLocation
@testable import PestGenie

/// Comprehensive testing framework for PestGenie application
class PestGenieTestCase: XCTestCase {

    // MARK: - Test Infrastructure

    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    var mockNetworkManager: MockNetworkManager!
    var mockLocationManager: MockLocationManager!

    override func setUp() {
        super.setUp()
        setupTestInfrastructure()
    }

    override func tearDown() {
        tearDownTestInfrastructure()
        super.tearDown()
    }

    private func setupTestInfrastructure() {
        // Setup in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "PestGenieDataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        testContainer.persistentStoreDescriptions = [description]

        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load test store")
        }

        testContext = testContainer.viewContext

        // Setup mock dependencies
        mockNetworkManager = MockNetworkManager()
        mockLocationManager = MockLocationManager()
    }

    private func tearDownTestInfrastructure() {
        testContext = nil
        testContainer = nil
        mockNetworkManager = nil
        mockLocationManager = nil
    }

    // MARK: - Test Data Factories

    func createTestJob(
        id: UUID = UUID(),
        customerName: String = "Test Customer",
        status: JobStatus = .pending
    ) -> Job {
        return Job(
            id: id,
            customerName: customerName,
            address: "123 Test Street",
            scheduledDate: Date(),
            latitude: 34.0522,
            longitude: -118.2437,
            notes: "Test job notes",
            pinnedNotes: nil,
            status: status,
            startTime: nil,
            completionTime: nil,
            signatureData: nil,
            weatherAtStart: nil,
            weatherAtCompletion: nil
        )
    }

    func createTestWeatherData(
        temperature: Double = 75.0,
        windSpeed: Double = 5.0,
        humidity: Int = 60
    ) -> WeatherData {
        return WeatherData(
            id: UUID(),
            temperature: temperature,
            feelsLike: temperature + 2,
            humidity: humidity,
            pressure: 30.12,
            windSpeed: windSpeed,
            windDirection: 180.0,
            uvIndex: 6.0,
            precipitationProbability: 10,
            visibility: 10.0,
            cloudCover: 20,
            condition: "Clear",
            description: "Clear skies",
            timestamp: Date(),
            location: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        )
    }

    func createTestChemical(
        name: String = "Test Chemical",
        signalWord: SignalWord = .caution
    ) -> Chemical {
        return Chemical(
            id: UUID(),
            name: name,
            epaNumber: "EPA-123-456",
            activeIngredient: "Test Ingredient",
            concentration: 25.0,
            signalWord: signalWord,
            hazardCategories: [.skin],
            applicationMethods: [.spray],
            targetPests: ["Test Pest"],
            dilutionRatio: "1:100",
            reentryInterval: 4,
            phiDays: 7,
            storageInstructions: "Store in cool, dry place",
            firstAidInstructions: "Seek medical attention if exposed",
            isRestricted: false,
            requiresCertification: false,
            currentStock: 10,
            minimumStock: 5,
            expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
            lastInventoryCheck: Date(),
            notes: "Test chemical notes"
        )
    }

    func createTestEquipment(
        name: String = "Test Sprayer",
        type: EquipmentType = .backpackSprayer
    ) -> Equipment {
        return Equipment(
            id: UUID(),
            name: name,
            type: type,
            category: .treatmentApplication,
            model: "Test Model",
            serialNumber: "TEST123",
            status: .available,
            specifications: EquipmentSpecifications(
                manufacturer: "Test Manufacturer",
                modelYear: 2023,
                capacity: "5 gallons",
                weight: "50 lbs",
                powerSource: "Electric",
                operatingPressure: "40-60 PSI",
                flowRate: "2 GPM",
                specialFeatures: ["Test Feature"]
            ),
            location: "Test Location",
            assignedTechnician: nil,
            lastMaintenanceDate: Date(),
            nextMaintenanceDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())!,
            purchaseDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
            warrantyExpiration: Calendar.current.date(byAdding: .year, value: 2, to: Date())!,
            notes: "Test equipment notes"
        )
    }

    // MARK: - Performance Testing Utilities

    func measurePerformance<T>(
        name: String,
        iterations: Int = 1,
        operation: () throws -> T
    ) throws -> T {
        var result: T!

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<iterations {
                do {
                    result = try operation()
                } catch {
                    XCTFail("Performance test '\(name)' failed: \(error)")
                }
            }
        }

        return result
    }

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
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }

        return result
    }

    // MARK: - SDUI Testing Utilities

    func loadTestSDUIScreen(named fileName: String) -> SDUIScreen? {
        guard let url = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load test SDUI screen: \(fileName)")
            return nil
        }

        do {
            return try JSONDecoder().decode(SDUIScreen.self, from: data)
        } catch {
            XCTFail("Could not decode SDUI screen: \(error)")
            return nil
        }
    }

    func createTestSDUIContext() -> SDUIContext {
        return SDUIContext(
            environmentVariables: ["test": "true"],
            userPermissions: ["basic_access"],
            deviceCapabilities: ["camera", "location"],
            connectivityStatus: .connected
        )
    }

    // MARK: - Mock Network Responses

    func mockSuccessfulResponse<T: Codable>(
        for endpoint: String,
        with data: T
    ) {
        let jsonData = try! JSONEncoder().encode(data)
        mockNetworkManager.mockResponse(for: endpoint, data: jsonData, statusCode: 200)
    }

    func mockErrorResponse(
        for endpoint: String,
        statusCode: Int = 500,
        error: Error? = nil
    ) {
        mockNetworkManager.mockResponse(
            for: endpoint,
            data: nil,
            statusCode: statusCode,
            error: error
        )
    }

    // MARK: - Assertion Utilities

    func assertEqualWithTolerance(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 0.001,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            actual, expected, accuracy: tolerance,
            "Expected \(expected) but got \(actual)",
            file: file, line: line
        )
    }

    func assertDateEqual(
        _ actual: Date,
        _ expected: Date,
        tolerance: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let difference = abs(actual.timeIntervalSince(expected))
        XCTAssertLessThanOrEqual(
            difference, tolerance,
            "Date difference of \(difference) seconds exceeds tolerance of \(tolerance)",
            file: file, line: line
        )
    }
}

// MARK: - Mock Classes

class MockNetworkManager {
    private var mockedResponses: [String: MockResponse] = [:]

    struct MockResponse {
        let data: Data?
        let statusCode: Int
        let error: Error?
    }

    func mockResponse(
        for endpoint: String,
        data: Data?,
        statusCode: Int = 200,
        error: Error? = nil
    ) {
        mockedResponses[endpoint] = MockResponse(
            data: data,
            statusCode: statusCode,
            error: error
        )
    }

    func getResponse(for endpoint: String) -> MockResponse? {
        return mockedResponses[endpoint]
    }

    func clearMocks() {
        mockedResponses.removeAll()
    }
}

class MockLocationManager: ObservableObject {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    func simulateLocationUpdate(_ location: CLLocationCoordinate2D) {
        currentLocation = location
    }

    func simulateAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}

class MockWeatherManager: ObservableObject {
    @Published var currentWeather: WeatherData?

    private var mockWeatherData: [WeatherData] = []

    func setMockWeather(_ weather: WeatherData) {
        currentWeather = weather
        mockWeatherData.append(weather)
    }

    func clearMockData() {
        currentWeather = nil
        mockWeatherData.removeAll()
    }
}

// MARK: - Test Categories

protocol PerformanceTestable {
    func testPerformanceWithLargeDataSet()
    func testMemoryUsageUnderLoad()
    func testStartupTime()
}

protocol SecurityTestable {
    func testDataEncryption()
    func testKeychainSecurity()
    func testNetworkSecurity()
}

protocol AccessibilityTestable {
    func testVoiceOverSupport()
    func testDynamicTypeSupport()
    func testColorContrastCompliance()
}