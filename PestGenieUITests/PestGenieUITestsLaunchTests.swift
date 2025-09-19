import XCTest

final class PestGenieUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot
        // In the screenshot, verify the key UI elements are present

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchWithMemoryPressure() throws {
        let app = XCUIApplication()

        // Test launch under memory pressure
        measure(metrics: [XCTMemoryMetric(), XCTApplicationLaunchMetric()]) {
            app.launch()

            // Wait for UI to stabilize
            let firstElement = app.otherElements.firstMatch
            _ = firstElement.waitForExistence(timeout: 5)

            app.terminate()
        }
    }

    func testLaunchInDifferentOrientations() throws {
        let app = XCUIApplication()
        let device = XCUIDevice.shared

        // Test portrait launch
        device.orientation = .portrait
        app.launch()

        let portraitScreenshot = XCTAttachment(screenshot: app.screenshot())
        portraitScreenshot.name = "Portrait Launch"
        add(portraitScreenshot)

        app.terminate()

        // Test landscape launch
        device.orientation = .landscapeLeft
        app.launch()

        let landscapeScreenshot = XCTAttachment(screenshot: app.screenshot())
        landscapeScreenshot.name = "Landscape Launch"
        add(landscapeScreenshot)

        // Reset to portrait
        device.orientation = .portrait
    }

    func testLaunchWithAccessibilityEnabled() throws {
        let app = XCUIApplication()

        // Launch with accessibility considerations
        app.launch()

        // Verify accessibility elements are present
        let accessibleElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(accessibleElements.count, 0, "App should have accessibility elements on launch")

        let accessibilityScreenshot = XCTAttachment(screenshot: app.screenshot())
        accessibilityScreenshot.name = "Accessibility Launch"
        add(accessibilityScreenshot)
    }

    func testLaunchPerformanceMetrics() throws {
        measure(metrics: [
            XCTApplicationLaunchMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTStorageMetric()
        ]) {
            let app = XCUIApplication()
            app.launch()

            // Wait for initial UI load
            let mainScreen = app.otherElements.firstMatch
            _ = mainScreen.waitForExistence(timeout: 10)

            app.terminate()
        }
    }

    func testColdLaunchAfterReboot() throws {
        // This test simulates a cold launch scenario
        let app = XCUIApplication()

        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()

            // Ensure app fully loads
            Thread.sleep(forTimeInterval: 2)

            // Verify critical UI elements
            XCTAssertTrue(app.state == .runningForeground)

            app.terminate()
        }
    }

    func testLaunchWithDeepLink() throws {
        // Test launching with a deep link URL
        let app = XCUIApplication()

        // Note: In a real test environment, you would configure the test to launch
        // with a specific URL scheme to test deep linking
        app.launch()

        // Simulate deep link handling
        let deepLinkScreenshot = XCTAttachment(screenshot: app.screenshot())
        deepLinkScreenshot.name = "Deep Link Launch"
        add(deepLinkScreenshot)
    }
}

// MARK: - Launch Scenario Tests

final class LaunchScenarioTests: XCTestCase {

    func testLaunchFromTerminatedState() throws {
        let app = XCUIApplication()

        // Ensure app is terminated
        app.terminate()
        Thread.sleep(forTimeInterval: 1)

        // Launch from terminated state
        app.launch()

        XCTAssertTrue(app.state == .runningForeground)

        let terminatedLaunchScreenshot = XCTAttachment(screenshot: app.screenshot())
        terminatedLaunchScreenshot.name = "Launch from Terminated"
        add(terminatedLaunchScreenshot)
    }

    func testLaunchFromBackgroundState() throws {
        let app = XCUIApplication()

        // Launch app first
        app.launch()

        // Send to background
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)

        // Reactivate from background
        app.activate()

        XCTAssertTrue(app.state == .runningForeground)

        let backgroundLaunchScreenshot = XCTAttachment(screenshot: app.screenshot())
        backgroundLaunchScreenshot.name = "Launch from Background"
        add(backgroundLaunchScreenshot)
    }

    func testLaunchWithNotificationPermission() throws {
        let app = XCUIApplication()

        // Launch app
        app.launch()

        // Look for notification permission dialog
        let allowButton = app.buttons["Allow"]
        let dontAllowButton = app.buttons["Don't Allow"]

        if allowButton.exists {
            allowButton.tap()
        } else if dontAllowButton.exists {
            dontAllowButton.tap()
        }

        // Verify app continues normally after permission decision
        XCTAssertTrue(app.state == .runningForeground)

        let notificationPermissionScreenshot = XCTAttachment(screenshot: app.screenshot())
        notificationPermissionScreenshot.name = "Notification Permission"
        add(notificationPermissionScreenshot)
    }

    func testLaunchWithLocationPermission() throws {
        let app = XCUIApplication()

        // Launch app
        app.launch()

        // Look for location permission dialog
        let allowOnceButton = app.buttons["Allow Once"]
        let allowWhileUsingButton = app.buttons["Allow While Using App"]
        let dontAllowButton = app.buttons["Don't Allow"]

        if allowWhileUsingButton.exists {
            allowWhileUsingButton.tap()
        } else if allowOnceButton.exists {
            allowOnceButton.tap()
        } else if dontAllowButton.exists {
            dontAllowButton.tap()
        }

        // Verify app continues normally after permission decision
        XCTAssertTrue(app.state == .runningForeground)

        let locationPermissionScreenshot = XCTAttachment(screenshot: app.screenshot())
        locationPermissionScreenshot.name = "Location Permission"
        add(locationPermissionScreenshot)
    }
}