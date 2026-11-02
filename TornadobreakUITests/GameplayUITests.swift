import XCTest

final class GameplayUITests: XCTestCase {
    @MainActor
    func testLandscapeUpgradesAreAccessible() async throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launch()
        let upgrades = app.buttons["Upgrades"]
        XCTAssertTrue(upgrades.waitForExistence(timeout: 10))
        XCTAssertTrue(upgrades.isHittable)
        upgrades.tap()
        let suction = app.buttons["upgrade-suction"]
        XCTAssertTrue(suction.waitForExistence(timeout: 5))
        XCTAssertTrue(suction.isHittable)
        XCTAssertTrue(app.buttons["upgrade-stability"].exists)
        XCTAssertTrue(app.buttons["upgrade-speed"].exists)
    }

    @MainActor
    func testMenuPlaySteerPauseAndReturn() async throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["playButton"].isHittable)
        app.buttons["playButton"].tap()
        let level = app.buttons["level-moore"]
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        level.tap()
        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["strengthLabel"].exists)
        let stick = app.otherElements["joystick"]
        XCTAssertTrue(stick.exists)
        if stick.exists {
            let center = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let right = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            center.press(forDuration: 0.1, thenDragTo: right)
        }
        let gameplay = XCTAttachment(screenshot: app.screenshot())
        gameplay.name = "Gameplay"
        gameplay.lifetime = .keepAlways
        add(gameplay)
        pause.tap()
        let resume = app.buttons["resumeButton"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        resume.tap()
        pause.tap()
        app.buttons["Leave run"].tap()
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Level selection"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
