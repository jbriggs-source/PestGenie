import XCTest
import Foundation

/// Minimal performance tests that don't depend on app initialization or external dependencies
/// These tests are designed to run reliably in CI environments like GitHub Actions
final class MinimalPerformanceTests: XCTestCase {

    // MARK: - Data Structure Performance Tests

    func testArrayPerformance() throws {
        measure {
            var testArray: [String] = []

            // Test array operations
            for i in 0..<10000 {
                testArray.append("Test Item \(i)")
            }

            // Test array access
            for i in 0..<1000 {
                let _ = testArray[i]
            }

            // Test array filtering
            let _ = testArray.filter { $0.contains("500") }

            testArray.removeAll()
        }
    }

    func testDictionaryPerformance() throws {
        measure {
            var testDict: [String: String] = [:]

            // Test dictionary operations
            for i in 0..<10000 {
                testDict["key-\(i)"] = "value-\(i)"
            }

            // Test dictionary access
            for i in 0..<1000 {
                let _ = testDict["key-\(i)"]
            }

            // Test dictionary enumeration
            for (key, value) in testDict.prefix(100) {
                let _ = key
                let _ = value
            }

            testDict.removeAll()
        }
    }

    // MARK: - JSON Performance Tests

    func testJSONParsingPerformance() throws {
        let jsonString = generateLargeJSON(itemCount: 1000)
        let jsonData = jsonString.data(using: .utf8)!

        measure {
            do {
                let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
            } catch {
                XCTFail("JSON parsing failed: \(error)")
            }
        }
    }

    func testJSONEncodingPerformance() throws {
        let testData = (0..<1000).map { index in
            [
                "id": "\(index)",
                "name": "Test Item \(index)",
                "value": "\(index * 10)",
                "timestamp": "\(Date().timeIntervalSince1970)"
            ]
        }

        measure {
            do {
                let _ = try JSONSerialization.data(withJSONObject: testData, options: [])
            } catch {
                XCTFail("JSON encoding failed: \(error)")
            }
        }
    }

    // MARK: - String Performance Tests

    func testStringOperationsPerformance() throws {
        let baseString = "Performance Test String Base"

        measure {
            var resultStrings: [String] = []

            // Test string concatenation
            for i in 0..<1000 {
                let newString = baseString + " - \(i)"
                resultStrings.append(newString)
            }

            // Test string searching
            for string in resultStrings.prefix(100) {
                let _ = string.contains("Test")
                let _ = string.hasPrefix("Performance")
                let _ = string.hasSuffix("99")
            }

            resultStrings.removeAll()
        }
    }

    // MARK: - Date Performance Tests

    func testDateOperationsPerformance() throws {
        let baseDate = Date()

        measure {
            var dates: [Date] = []

            // Test date creation and manipulation
            for i in 0..<1000 {
                let newDate = baseDate.addingTimeInterval(TimeInterval(i * 60))
                dates.append(newDate)
            }

            // Test date formatting
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            for date in dates.prefix(100) {
                let _ = formatter.string(from: date)
            }

            dates.removeAll()
        }
    }

    // MARK: - Mathematical Operations Performance Tests

    func testMathOperationsPerformance() throws {
        measure {
            var results: [Double] = []

            // Test various mathematical operations
            for i in 0..<10000 {
                let x = Double(i)
                let result = sqrt(x) + sin(x) + cos(x) + log(x + 1)
                results.append(result)
            }

            // Test array operations on results
            let sum = results.reduce(0, +)
            let average = sum / Double(results.count)
            let _ = results.filter { $0 > average }

            results.removeAll()
        }
    }

    // MARK: - Concurrent Operations Performance Tests

    func testConcurrentOperationsPerformance() throws {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10

        measure {
            for i in 0..<10 {
                DispatchQueue.global(qos: .userInitiated).async {
                    // Perform some work on background queue
                    var result = 0
                    for j in 0..<1000 {
                        result += i + j
                    }

                    // Verify result was computed
                    XCTAssertGreaterThan(result, 0)
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Memory Allocation Performance Tests

    func testMemoryAllocationPerformance() throws {
        measure {
            var arrays: [[Int]] = []

            // Test memory allocation and deallocation
            for i in 0..<1000 {
                let array = Array(0..<(i % 100))
                arrays.append(array)
            }

            // Test memory access
            for array in arrays.prefix(100) {
                let _ = array.count
                if !array.isEmpty {
                    let _ = array.first
                    let _ = array.last
                }
            }

            arrays.removeAll()
        }
    }

    // MARK: - Helper Methods

    private func generateLargeJSON(itemCount: Int) -> String {
        let items = (0..<itemCount).map { index in
            """
            {
                "id": "\(index)",
                "name": "Performance Test Item \(index)",
                "value": \(index * 10),
                "timestamp": "\(Date().timeIntervalSince1970)",
                "active": \(index % 2 == 0 ? "true" : "false")
            }
            """
        }.joined(separator: ",")

        return """
        {
            "version": 1,
            "count": \(itemCount),
            "items": [\(items)]
        }
        """
    }
}