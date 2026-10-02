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
        app.buttons["Not now"].tap()
        app.buttons["Not now"].firstMatch.tap()
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.staticTexts["Gentle breathing"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStartingFirstExerciseFromOnboardingOpensPlayer() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Not now"].tap()
        app.buttons["Not now"].firstMatch.tap()
        app.buttons["Continue"].tap()
        app.buttons["Start gentle breathing"].tap()

        XCTAssertTrue(app.buttons["End exercise"].waitForExistence(timeout: 5))
        app.buttons["End exercise"].tap()
        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFakeHealthNightShowsEstimateAndDetail() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-fake-health"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Connect Apple Health"].tap()
        app.buttons["Not now"].firstMatch.tap()
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        app.tabBars.buttons["Sleep"].tap()
        let estimate = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Apple Watch estimated")).firstMatch
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        estimate.tap()
        XCTAssertTrue(app.staticTexts["Stages are estimates from your device, not measurements."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFakeSoundSessionSavesEvents() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-fake-sound"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Not now"].tap()                       // health
        app.buttons["Turn on sound detection"].tap()       // microphone (fake grants)
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        let start = app.buttons["Start sleep session"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["Listening for sounds"].waitForExistence(timeout: 5))
        app.buttons["End session"].tap()

        app.tabBars.buttons["Sleep"].tap()
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "2 sounds noted")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
