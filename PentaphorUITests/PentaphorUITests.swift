import XCTest

final class PentaphorUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testCreateCompleteUndoAndRelaunchPreservesQuest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.create"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["아직 비어 있는 첫 페이지"].exists)
        app.buttons["quest.create"].tap()
        let name = app.textFields["quest.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Acceptance Quest")
        name.typeText("\n")
        capture(app, "01-create")
        app.buttons["quest.save"].tap()
        let complete = app.buttons["quest.complete.Acceptance Quest"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        capture(app, "02-home")
        complete.tap()
        XCTAssertTrue(app.staticTexts["achievement.title"].waitForExistence(timeout: 5))
        capture(app, "03-achievement")
        reveal(app.buttons["achievement.undo"], in: app)
        app.buttons["achievement.undo"].tap()
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["quest.progress.Acceptance Quest"].label.contains("0 / 3"))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.complete.Acceptance Quest"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["quest.progress.Acceptance Quest"].label.contains("0 / 3"))
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].waitForExistence(timeout: 5))
        capture(app, "05-stats-after-undo")
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["되돌린 기록"].waitForExistence(timeout: 5))
    }

    @MainActor func testArtSelectionPreservesCustomNameAndCanArchiveRestore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        app.buttons["quest.create"].tap()
        let name = app.textFields["quest.name"]
        name.tap()
        name.typeText("My own name")
        app.buttons["quest.art"].tap()
        XCTAssertTrue(app.buttons["art.reading"].waitForExistence(timeout: 5))
        capture(app, "04-art-picker")
        app.buttons["art.reading"].tap()
        XCTAssertEqual(name.value as? String, "My own name")
        app.buttons["quest.save"].tap()
        app.buttons["quest.edit.My own name"].tap()
        reveal(app.buttons["quest.archive"], in: app)
        app.buttons["quest.archive"].tap()
        XCTAssertFalse(app.buttons["quest.complete.My own name"].exists)
        app.buttons["quest.archived"].tap()
        app.buttons["quest.restore.My own name"].tap()
        app.buttons["archive.done"].tap()
        XCTAssertTrue(app.buttons["quest.complete.My own name"].waitForExistence(timeout: 5))
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
