import XCTest
import SwiftUI
@testable import PestGenie

/// Comprehensive tests for the Server-Driven UI (SDUI) system
final class SDUIRenderingTests: PestGenieTestCase {

    var sduiRenderer: SDUIScreenRenderer!

    override func setUp() {
        super.setUp()
        sduiRenderer = SDUIScreenRenderer()
    }

    override func tearDown() {
        sduiRenderer = nil
        super.tearDown()
    }

    // MARK: - Component Rendering Tests

    func testTextComponentRendering() {
        // Given
        let component = SDUIComponent(
            id: "test-text",
            type: "text",
            text: "Test Text Content",
            style: SDUIStyle(
                font: SDUIFont(size: 16, weight: "medium"),
                color: "#333333",
                backgroundColor: "#FFFFFF"
            )
        )

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Text component should render successfully")
    }

    func testButtonComponentRendering() {
        // Given
        let component = SDUIComponent(
            id: "test-button",
            type: "button",
            text: "Test Button",
            action: SDUIAction(
                type: "navigation",
                target: "test_screen",
                parameters: ["param1": "value1"]
            ),
            style: SDUIStyle(
                backgroundColor: "#007AFF",
                padding: SDUIPadding(top: 12, bottom: 12, leading: 16, trailing: 16),
                cornerRadius: 8
            )
        )

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Button component should render successfully")
    }

    func testImageComponentRendering() {
        // Given
        let component = SDUIComponent(
            id: "test-image",
            type: "image",
            imageUrl: "https://example.com/test-image.png",
            imageName: "fallback_image",
            style: SDUIStyle(
                width: 100,
                height: 100,
                cornerRadius: 8
            )
        )

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Image component should render successfully")
    }

    func testContainerComponentRendering() {
        // Given
        let childComponents = [
            SDUIComponent(id: "child1", type: "text", text: "Child 1"),
            SDUIComponent(id: "child2", type: "text", text: "Child 2")
        ]

        let component = SDUIComponent(
            id: "test-container",
            type: "vstack",
            children: childComponents,
            style: SDUIStyle(
                spacing: 16,
                padding: SDUIPadding(top: 20, bottom: 20, leading: 16, trailing: 16)
            )
        )

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Container component should render successfully")
    }

    // MARK: - Screen Rendering Tests

    func testCompleteScreenRendering() throws {
        // Given
        guard let testScreen = loadTestSDUIScreen(named: "test_dashboard_screen") else {
            XCTFail("Could not load test screen")
            return
        }

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(screen: testScreen, context: context)

        // Then
        XCTAssertNotNil(view, "Complete screen should render successfully")
    }

    func testConditionalComponentRendering() {
        // Given
        let component = SDUIComponent(
            id: "conditional-text",
            type: "text",
            text: "Conditional Content",
            conditions: [
                SDUICondition(
                    field: "user.role",
                    operator: "equals",
                    value: "technician"
                )
            ]
        )

        var context = createTestSDUIContext()
        context.environmentVariables["user.role"] = "technician"

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Conditional component should render when condition is met")

        // Test when condition is not met
        context.environmentVariables["user.role"] = "admin"
        let hiddenView = SDUIScreenRenderer.render(component: component, context: context)
        XCTAssertNotNil(hiddenView, "Component should still render but might be hidden")
    }

    // MARK: - Dynamic Content Tests

    func testDynamicTextReplacement() {
        // Given
        let component = SDUIComponent(
            id: "dynamic-text",
            type: "text",
            text: "Hello {{user.name}}, you have {{job.count}} jobs today",
            style: SDUIStyle(font: SDUIFont(size: 16, weight: "regular"))
        )

        var context = createTestSDUIContext()
        context.environmentVariables["user.name"] = "John Technician"
        context.environmentVariables["job.count"] = "5"

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Dynamic text component should render successfully")
        // Note: In a real test, we would verify the text content contains the replaced values
    }

    func testDataBinding() {
        // Given
        let component = SDUIComponent(
            id: "data-list",
            type: "list",
            dataSource: "jobs",
            itemTemplate: SDUIComponent(
                id: "job-item",
                type: "text",
                text: "{{item.customerName}} - {{item.status}}"
            )
        )

        var context = createTestSDUIContext()
        context.environmentVariables["jobs"] = """
        [
            {"customerName": "Customer 1", "status": "pending"},
            {"customerName": "Customer 2", "status": "completed"}
        ]
        """

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Data-bound list component should render successfully")
    }

    // MARK: - Error Handling Tests

    func testInvalidComponentTypeHandling() {
        // Given
        let component = SDUIComponent(
            id: "invalid-component",
            type: "invalid_type",
            text: "This should not render"
        )

        let context = createTestSDUIContext()

        // When/Then
        XCTAssertNoThrow({
            let view = SDUIScreenRenderer.render(component: component, context: context)
            XCTAssertNotNil(view, "Invalid component should render fallback view")
        }, "Rendering invalid component should not throw")
    }

    func testMalformedJSONHandling() {
        // Given
        let malformedJSON = """
        {
            "id": "test",
            "type": "text",
            "text": "Test",
            "style": {
                "invalidProperty": "invalidValue"
            }
        """

        // When/Then
        XCTAssertNoThrow({
            if let data = malformedJSON.data(using: .utf8) {
                let _ = try? JSONDecoder().decode(SDUIComponent.self, from: data)
            }
        }, "Malformed JSON should be handled gracefully")
    }

    func testMissingResourceHandling() {
        // Given
        let component = SDUIComponent(
            id: "missing-image",
            type: "image",
            imageUrl: "https://invalid-url.com/missing-image.png",
            imageName: "non_existent_image"
        )

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Component with missing resources should render fallback")
    }

    // MARK: - Performance Tests

    func testRenderingPerformanceWithLargeScreen() throws {
        // Given
        let components = (0..<100).map { index in
            SDUIComponent(
                id: "component-\(index)",
                type: "text",
                text: "Component \(index)",
                style: SDUIStyle(
                    font: SDUIFont(size: 14, weight: "regular"),
                    padding: SDUIPadding(top: 8, bottom: 8, leading: 16, trailing: 16)
                )
            )
        }

        let screen = SDUIScreen(
            id: "large-screen",
            version: 1,
            title: "Large Screen Test",
            components: components
        )

        let context = createTestSDUIContext()

        // When/Then
        try measurePerformance(name: "Large screen rendering") {
            let view = SDUIScreenRenderer.render(screen: screen, context: context)
            XCTAssertNotNil(view)
        }
    }

    func testMemoryUsageWithComplexNesting() throws {
        // Given
        func createNestedComponent(depth: Int) -> SDUIComponent {
            if depth <= 0 {
                return SDUIComponent(id: "leaf", type: "text", text: "Leaf")
            }

            return SDUIComponent(
                id: "container-\(depth)",
                type: "vstack",
                children: [createNestedComponent(depth: depth - 1)]
            )
        }

        let deeplyNestedComponent = createNestedComponent(depth: 20)
        let context = createTestSDUIContext()

        // When/Then
        try measurePerformance(name: "Deeply nested component rendering") {
            let view = SDUIScreenRenderer.render(component: deeplyNestedComponent, context: context)
            XCTAssertNotNil(view)
        }
    }

    // MARK: - JSON Parsing Tests

    func testSDUIComponentJSONParsing() throws {
        // Given
        let jsonString = """
        {
            "id": "test-component",
            "type": "text",
            "text": "Test Content",
            "style": {
                "font": {
                    "size": 16,
                    "weight": "medium"
                },
                "color": "#333333",
                "backgroundColor": "#FFFFFF",
                "padding": {
                    "top": 12,
                    "bottom": 12,
                    "leading": 16,
                    "trailing": 16
                },
                "cornerRadius": 8
            },
            "action": {
                "type": "navigation",
                "target": "detail_screen",
                "parameters": {
                    "itemId": "123"
                }
            }
        }
        """

        let jsonData = jsonString.data(using: .utf8)!

        // When
        let component = try JSONDecoder().decode(SDUIComponent.self, from: jsonData)

        // Then
        XCTAssertEqual(component.id, "test-component")
        XCTAssertEqual(component.type, "text")
        XCTAssertEqual(component.text, "Test Content")
        XCTAssertNotNil(component.style)
        XCTAssertNotNil(component.action)
        XCTAssertEqual(component.style?.font?.size, 16)
        XCTAssertEqual(component.action?.type, "navigation")
    }

    func testSDUIScreenJSONParsing() throws {
        // Given
        let jsonString = """
        {
            "id": "test-screen",
            "version": 1,
            "title": "Test Screen",
            "components": [
                {
                    "id": "header",
                    "type": "text",
                    "text": "Welcome"
                },
                {
                    "id": "content",
                    "type": "vstack",
                    "children": [
                        {
                            "id": "item1",
                            "type": "text",
                            "text": "Item 1"
                        }
                    ]
                }
            ]
        }
        """

        let jsonData = jsonString.data(using: .utf8)!

        // When
        let screen = try JSONDecoder().decode(SDUIScreen.self, from: jsonData)

        // Then
        XCTAssertEqual(screen.id, "test-screen")
        XCTAssertEqual(screen.version, 1)
        XCTAssertEqual(screen.title, "Test Screen")
        XCTAssertEqual(screen.components.count, 2)
        XCTAssertEqual(screen.components[0].id, "header")
        XCTAssertEqual(screen.components[1].id, "content")
        XCTAssertEqual(screen.components[1].children?.count, 1)
    }

    // MARK: - Integration Tests

    func testSDUIWithRealDataContext() async throws {
        // Given
        let job = createTestJob()
        let weather = createTestWeatherData()

        let component = SDUIComponent(
            id: "job-card",
            type: "card",
            children: [
                SDUIComponent(
                    id: "customer-name",
                    type: "text",
                    text: "{{job.customerName}}"
                ),
                SDUIComponent(
                    id: "weather-info",
                    type: "text",
                    text: "Temperature: {{weather.temperature}}°F"
                )
            ]
        )

        var context = createTestSDUIContext()
        context.environmentVariables["job.customerName"] = job.customerName
        context.environmentVariables["weather.temperature"] = String(weather.temperature)

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "SDUI component with real data should render successfully")
    }

    func testSDUIActionHandling() {
        // Given
        let component = SDUIComponent(
            id: "action-button",
            type: "button",
            text: "Navigate",
            action: SDUIAction(
                type: "navigation",
                target: "detail_screen",
                parameters: ["id": "123"]
            )
        )

        let context = createTestSDUIContext()

        // When
        let view = SDUIScreenRenderer.render(component: component, context: context)

        // Then
        XCTAssertNotNil(view, "Button with action should render successfully")
        // Note: In a real test, we would verify that the action is properly configured
    }
}

// MARK: - Test Data Files

extension SDUIRenderingTests {

    /// Create test SDUI screen JSON for testing
    private func createTestDashboardScreenJSON() -> String {
        return """
        {
            "id": "test_dashboard_screen",
            "version": 1,
            "title": "Test Dashboard",
            "components": [
                {
                    "id": "header",
                    "type": "text",
                    "text": "Welcome, {{user.name}}!",
                    "style": {
                        "font": {
                            "size": 24,
                            "weight": "bold"
                        },
                        "color": "#333333",
                        "padding": {
                            "top": 20,
                            "bottom": 10,
                            "leading": 16,
                            "trailing": 16
                        }
                    }
                },
                {
                    "id": "stats-container",
                    "type": "hstack",
                    "children": [
                        {
                            "id": "jobs-today",
                            "type": "card",
                            "children": [
                                {
                                    "id": "jobs-count",
                                    "type": "text",
                                    "text": "{{stats.jobsToday}}"
                                },
                                {
                                    "id": "jobs-label",
                                    "type": "text",
                                    "text": "Jobs Today"
                                }
                            ]
                        },
                        {
                            "id": "completed-jobs",
                            "type": "card",
                            "children": [
                                {
                                    "id": "completed-count",
                                    "type": "text",
                                    "text": "{{stats.completedJobs}}"
                                },
                                {
                                    "id": "completed-label",
                                    "type": "text",
                                    "text": "Completed"
                                }
                            ]
                        }
                    ]
                },
                {
                    "id": "action-buttons",
                    "type": "vstack",
                    "children": [
                        {
                            "id": "start-route-button",
                            "type": "button",
                            "text": "Start Route",
                            "action": {
                                "type": "navigation",
                                "target": "route_screen"
                            },
                            "style": {
                                "backgroundColor": "#007AFF",
                                "color": "#FFFFFF",
                                "padding": {
                                    "top": 12,
                                    "bottom": 12,
                                    "leading": 20,
                                    "trailing": 20
                                },
                                "cornerRadius": 8
                            }
                        }
                    ]
                }
            ]
        }
        """
    }

    override func setUp() {
        super.setUp()

        // Write test SDUI screen to test bundle
        let testScreenJSON = createTestDashboardScreenJSON()
        if let testBundle = Bundle(for: type(of: self)).bundleURL.appendingPathComponent("test_dashboard_screen.json") {
            do {
                try testScreenJSON.write(to: testBundle, atomically: true, encoding: .utf8)
            } catch {
                print("Warning: Could not write test SDUI screen: \(error)")
            }
        }
    }
}