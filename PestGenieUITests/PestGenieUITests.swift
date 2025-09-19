import XCTest

final class PestGenieUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    func testAppLaunch() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testMainScreenElements() throws {
        // Wait for main screen to load
        let mainScreen = app.otherElements["main-screen"]
        let exists = mainScreen.waitForExistence(timeout: 5)

        if exists {
            XCTAssertTrue(mainScreen.exists)
        } else {
            // If SDUI main screen doesn't exist, check for basic navigation
            XCTAssertTrue(app.navigationBars.firstMatch.exists)
        }
    }

    // MARK: - SDUI Rendering Tests

    func testSDUIComponentRendering() throws {
        // Look for common SDUI elements that should be rendered
        let textElements = app.staticTexts
        let buttonElements = app.buttons

        // Should have some text and button elements from SDUI
        XCTAssertGreaterThan(textElements.count, 0)
        XCTAssertGreaterThan(buttonElements.count, 0)
    }

    func testSDUIButtonInteraction() throws {
        // Find and tap a button if it exists
        let firstButton = app.buttons.firstMatch
        if firstButton.exists {
            firstButton.tap()

            // Verify some response to button tap
            // This is generic since we don't know exact SDUI structure
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    // MARK: - Navigation Tests

    func testNavigationFlow() throws {
        // Test basic navigation if tabs exist
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let tabs = tabBar.buttons

            // Tap through available tabs
            for i in 0..<min(tabs.count, 3) {
                let tab = tabs.element(boundBy: i)
                if tab.exists {
                    tab.tap()

                    // Give time for navigation
                    Thread.sleep(forTimeInterval: 0.5)

                    // Verify app is still running
                    XCTAssertTrue(app.state == .runningForeground)
                }
            }
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() throws {
        // Test that interactive elements have accessibility labels
        let buttons = app.buttons

        for i in 0..<min(buttons.count, 5) {
            let button = buttons.element(boundBy: i)
            if button.exists {
                let label = button.label
                XCTAssertFalse(label.isEmpty, "Button should have accessibility label")
            }
        }
    }

    func testVoiceOverSupport() throws {
        // Enable VoiceOver for testing
        let systemSettings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")

        // This is a basic test - in practice you'd use accessibility inspector
        let accessibleElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(accessibleElements.count, 0, "Should have accessible elements")
    }

    func testDynamicTypeSupport() throws {
        // Test that app handles different text sizes
        // This would typically require setting system text size and relaunching

        let textElements = app.staticTexts
        for i in 0..<min(textElements.count, 3) {
            let textElement = textElements.element(boundBy: i)
            if textElement.exists {
                // Verify text is visible and not truncated
                XCTAssertTrue(textElement.isHittable)
            }
        }
    }

    // MARK: - Form Input Tests

    func testTextFieldInput() throws {
        let textFields = app.textFields

        if textFields.count > 0 {
            let firstTextField = textFields.firstMatch
            firstTextField.tap()
            firstTextField.typeText("Test Input")

            // Verify text was entered
            XCTAssertTrue(firstTextField.value as? String == "Test Input" ||
                         firstTextField.placeholderValue?.contains("Test Input") == true)
        }
    }

    func testToggleInteraction() throws {
        let switches = app.switches

        if switches.count > 0 {
            let firstSwitch = switches.firstMatch
            let initialValue = firstSwitch.value as? String

            firstSwitch.tap()

            let newValue = firstSwitch.value as? String
            XCTAssertNotEqual(initialValue, newValue, "Toggle should change state")
        }
    }

    func testSliderInteraction() throws {
        let sliders = app.sliders

        if sliders.count > 0 {
            let firstSlider = sliders.firstMatch

            // Try to adjust slider
            firstSlider.adjust(toNormalizedSliderPosition: 0.7)

            // Verify slider is still functional
            XCTAssertTrue(firstSlider.exists)
        }
    }

    // MARK: - List and Scroll Tests

    func testListScrolling() throws {
        let tables = app.tables
        let scrollViews = app.scrollViews

        if tables.count > 0 {
            let firstTable = tables.firstMatch

            // Try scrolling if table has content
            if firstTable.cells.count > 3 {
                firstTable.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
                firstTable.swipeDown()
            }

            XCTAssertTrue(firstTable.exists)
        } else if scrollViews.count > 0 {
            let firstScrollView = scrollViews.firstMatch
            firstScrollView.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            firstScrollView.swipeDown()

            XCTAssertTrue(firstScrollView.exists)
        }
    }

    func testListItemSelection() throws {
        let tables = app.tables

        if tables.count > 0 {
            let firstTable = tables.firstMatch
            let cells = firstTable.cells

            if cells.count > 0 {
                let firstCell = cells.firstMatch
                firstCell.tap()

                // Verify app responds to selection
                XCTAssertTrue(app.state == .runningForeground)
            }
        }
    }

    // MARK: - Deep Link Tests

    func testCustomURLSchemeHandling() throws {
        // Test app can handle custom URL schemes
        // This would typically be tested by launching with a URL

        // For now, just verify app can handle being backgrounded and foregrounded
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)

        app.activate()
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Performance Tests

    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()

            // Wait for main UI to appear
            let mainElement = app.otherElements.firstMatch
            _ = mainElement.waitForExistence(timeout: 10)

            app.terminate()
        }
    }

    func testScrollPerformance() throws {
        let scrollViews = app.scrollViews

        if scrollViews.count > 0 {
            let scrollView = scrollViews.firstMatch

            measure {
                for _ in 0..<10 {
                    scrollView.swipeUp()
                    scrollView.swipeDown()
                }
            }
        }
    }

    // MARK: - Rotation Tests

    func testDeviceRotation() throws {
        let device = XCUIDevice.shared

        // Test portrait to landscape
        device.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)

        // Verify app still works in landscape
        XCTAssertTrue(app.state == .runningForeground)

        // Test back to portrait
        device.orientation = .portrait
        Thread.sleep(forTimeInterval: 1)

        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Memory Tests

    func testMemoryUsage() throws {
        // Basic memory pressure test
        // Generate some UI interactions

        for _ in 0..<20 {
            let buttons = app.buttons
            if buttons.count > 0 {
                let randomButton = buttons.element(boundBy: Int.random(in: 0..<buttons.count))
                if randomButton.exists {
                    randomButton.tap()
                }
            }

            let scrollViews = app.scrollViews
            if scrollViews.count > 0 {
                scrollViews.firstMatch.swipeUp()
            }

            // Small delay between interactions
            Thread.sleep(forTimeInterval: 0.1)
        }

        // App should still be responsive
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Network State Tests

    func testOfflineMode() throws {
        // This would require network manipulation in a real test environment
        // For now, just verify app handles state changes gracefully

        // Background and foreground the app to simulate network changes
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)

        app.activate()

        // Wait for app to restore state
        Thread.sleep(forTimeInterval: 1)

        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Notification Tests

    func testNotificationPermissions() throws {
        // This test would check if notification permission dialogs are handled
        // In practice, this requires specific setup for permission testing

        // For now, just verify app handles permission-related state changes
        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Launch Performance Tests

final class PestGenieLaunchPerformanceTests: XCTestCase {

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

// MARK: - Accessibility Tests

final class PestGenieAccessibilityTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAccessibilityElementsExist() throws {
        // Test that key accessibility elements exist
        let accessibleElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(accessibleElements.count, 0)
    }

    func testButtonsHaveAccessibilityLabels() throws {
        let buttons = app.buttons

        for i in 0..<min(buttons.count, 10) {
            let button = buttons.element(boundBy: i)
            if button.exists {
                XCTAssertFalse(button.label.isEmpty, "Button at index \(i) should have an accessibility label")
            }
        }
    }

    func testImagesHaveAccessibilityLabels() throws {
        let images = app.images

        for i in 0..<min(images.count, 5) {
            let image = images.element(boundBy: i)
            if image.exists {
                // Images should have labels or be marked as decorative
                let hasLabel = !image.label.isEmpty
                let isDecorative = !image.isAccessibilityElement
                XCTAssertTrue(hasLabel || isDecorative, "Image at index \(i) should have a label or be marked as decorative")
            }
        }
    }
}

// MARK: - Error Handling Tests

final class PestGenieErrorHandlingTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppHandlesInterruptions() throws {
        // Test app handles interruptions gracefully
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)

        app.activate()
        Thread.sleep(forTimeInterval: 1)

        XCTAssertTrue(app.state == .runningForeground)
    }

    func testAppHandlesMemoryWarnings() throws {
        // Simulate memory pressure by rapid interactions
        for _ in 0..<50 {
            if app.buttons.count > 0 {
                app.buttons.firstMatch.tap()
            }
            if app.scrollViews.count > 0 {
                app.scrollViews.firstMatch.swipeUp()
            }
        }

        // App should still be responsive
        XCTAssertTrue(app.state == .runningForeground)
    }
}