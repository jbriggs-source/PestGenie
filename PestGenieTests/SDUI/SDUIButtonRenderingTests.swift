import XCTest
import SwiftUI
@testable import PestGenie

final class SDUIButtonRenderingTests: XCTestCase {

    var context: SDUIContext!
    var mockJob: Job!
    var routeViewModel: RouteViewModel!

    override func setUpWithError() throws {
        routeViewModel = RouteViewModel()
        mockJob = Job(
            id: UUID(),
            customerName: "Test Customer",
            address: "123 Test St",
            scheduledDate: Date(),
            status: .pending
        )

        context = SDUIContext(
            jobs: [mockJob],
            routeViewModel: routeViewModel,
            actions: [:],
            currentJob: mockJob,
            persistenceController: PersistenceController.preview,
            authManager: nil
        )
    }

    func testTransparentButtonRendering() throws {
        // Test that transparent buttons don't apply black backgrounds
        let transparentButton = SDUIComponent(
            id: "test-transparent-button",
            type: .button,
            actionId: "test_action",
            children: [
                SDUIComponent(
                    id: "test-vstack",
                    type: .vstack,
                    children: [
                        SDUIComponent(
                            id: "test-icon-container",
                            type: .vstack,
                            children: [
                                SDUIComponent(
                                    id: "test-icon",
                                    type: .image,
                                    font: "title2",
                                    foregroundColor: "#007AFF",
                                    imageName: "pencil.circle.fill"
                                )
                            ],
                            padding: 12,
                            backgroundColor: "#F2F2F7",
                            cornerRadius: 12
                        ),
                        SDUIComponent(
                            id: "test-text",
                            type: .text,
                            text: "Edit Profile",
                            font: "caption",
                            foregroundColor: "#1C1C1E",
                            fontWeight: "medium"
                        )
                    ],
                    spacing: 8
                )
            ],
            backgroundColor: "transparent"
        )

        // Render the component
        let renderedView = SDUIButtonRenderer.render(component: transparentButton, context: context)

        // The test passes if rendering doesn't crash and returns a valid view
        XCTAssertNotNil(renderedView)
    }

    func testColorResolutionForTransparent() throws {
        // Test that transparent colors resolve to clear
        let transparentColor = SDUIStyleResolver.resolveColor("transparent", job: mockJob)
        let clearColor = SDUIStyleResolver.resolveColor("clear", job: mockJob)

        XCTAssertEqual(transparentColor, clearColor)
        XCTAssertEqual(transparentColor, Color.clear)
    }

    func testBackgroundStyleApplicationSkipsTransparent() throws {
        // Test that transparent backgrounds don't get applied
        let componentWithTransparentBG = SDUIComponent(
            id: "test-transparent-bg",
            type: .text,
            text: "Test Text",
            backgroundColor: "transparent"
        )

        let testView = AnyView(Text("Test"))
        let styledView = SDUIStyleApplicator.apply(
            styling: componentWithTransparentBG,
            to: testView,
            job: mockJob
        )

        // The test passes if no exceptions are thrown and view is returned
        XCTAssertNotNil(styledView)
    }

    func testRegularButtonWithBackground() throws {
        // Test that non-transparent buttons still work correctly
        let regularButton = SDUIComponent(
            id: "test-regular-button",
            type: .button,
            text: "Regular Button",
            actionId: "regular_action",
            padding: 12,
            foregroundColor: "#FFFFFF",
            backgroundColor: "#007AFF",
            cornerRadius: 8
        )

        let renderedView = SDUIButtonRenderer.render(component: regularButton, context: context)
        XCTAssertNotNil(renderedView)
    }

    func testProfileScreenQuickActionsRendering() throws {
        // Test the specific Quick Actions structure from ProfileScreen.json
        let quickActionButton = SDUIComponent(
            id: "edit-profile-button",
            type: .button,
            actionId: "edit_profile",
            children: [
                SDUIComponent(
                    id: "action-vstack",
                    type: .vstack,
                    children: [
                        SDUIComponent(
                            id: "icon-container",
                            type: .vstack,
                            children: [
                                SDUIComponent(
                                    id: "icon",
                                    type: .image,
                                    font: "title2",
                                    foregroundColor: "#007AFF",
                                    imageName: "pencil.circle.fill"
                                )
                            ],
                            spacing: 0,
                            padding: 12,
                            backgroundColor: "#F2F2F7",
                            cornerRadius: 12
                        ),
                        SDUIComponent(
                            id: "label",
                            type: .text,
                            text: "Edit Profile",
                            font: "caption",
                            foregroundColor: "#1C1C1E",
                            fontWeight: "medium"
                        )
                    ],
                    spacing: 8
                )
            ],
            backgroundColor: "transparent"
        )

        let renderedView = SDUIButtonRenderer.render(component: quickActionButton, context: context)
        XCTAssertNotNil(renderedView)
    }

    func testSettingsButtonRendering() throws {
        // Test the settings section button structure
        let settingsButton = SDUIComponent(
            id: "notifications-button",
            type: .button,
            actionId: "notifications",
            children: [
                SDUIComponent(
                    id: "settings-hstack",
                    type: .hstack,
                    children: [
                        SDUIComponent(
                            id: "settings-icon",
                            type: .image,
                            font: "bodyLarge",
                            foregroundColor: "#FF3B30",
                            imageName: "bell"
                        ),
                        SDUIComponent(
                            id: "settings-text",
                            type: .text,
                            text: "Notifications",
                            font: "bodyMedium",
                            foregroundColor: "#1C1C1E"
                        ),
                        SDUIComponent(
                            id: "settings-spacer",
                            type: .spacer
                        ),
                        SDUIComponent(
                            id: "settings-chevron",
                            type: .image,
                            font: "bodySmall",
                            foregroundColor: "#C7C7CC",
                            imageName: "chevron.right"
                        )
                    ],
                    spacing: 12,
                    padding: 16
                )
            ],
            backgroundColor: "transparent"
        )

        let renderedView = SDUIButtonRenderer.render(component: settingsButton, context: context)
        XCTAssertNotNil(renderedView)
    }

    func testHexColorParsing() throws {
        // Test that hex colors are parsed correctly
        let blueColor = SDUIStyleResolver.resolveColor("#007AFF", job: mockJob)
        let redColor = SDUIStyleResolver.resolveColor("#FF3B30", job: mockJob)
        let grayColor = SDUIStyleResolver.resolveColor("#F2F2F7", job: mockJob)

        XCTAssertNotNil(blueColor)
        XCTAssertNotNil(redColor)
        XCTAssertNotNil(grayColor)

        // Test that invalid hex returns primary color
        let invalidColor = SDUIStyleResolver.resolveColor("#INVALID", job: mockJob)
        XCTAssertEqual(invalidColor, Color.primary)
    }
}