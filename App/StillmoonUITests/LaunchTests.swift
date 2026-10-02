import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testOnboardingReachesTodayAndExercises() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.staticTexts["Gentle breathing"].waitForExistence(timeout: 5))
    }
}
