import XCTest

final class GameplayUITests: XCTestCase {
    func testMenuPlaySteerPauseAndReturn() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["playButton"].tap()
        let level = app.buttons["level-moore"]
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        level.tap()
        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["strengthLabel"].exists)
        let stick = app.otherElements["joystick"]
        if stick.exists {
            let center = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let right = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            center.press(forDuration: 0.1, thenDragTo: right)
        }
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
