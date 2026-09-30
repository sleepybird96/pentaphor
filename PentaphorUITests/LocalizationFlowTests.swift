import XCTest

final class LocalizationFlowTests: XCTestCase {
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 { if element.isHittable { return }; app.swipeUp() }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testEnglishQuestAndKoreanRelaunchPreserveProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 10))
        capture(app, "i18n-en-introduction")
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["quest.create"].waitForExistence(timeout: 5))
        app.buttons["quest.create"].tap()
        XCTAssertTrue(app.staticTexts["What's your next move?"].waitForExistence(timeout: 5))
        capture(app, "i18n-en-editor")
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("Reading 100%\n")
        app.buttons["quest.save"].tap()
        app.buttons["quest.complete.Reading 100%"].tap()
        XCTAssertTrue(app.buttons["achievement.done"].waitForExistence(timeout: 5))
        capture(app, "i18n-en-achievement")
        reveal(app.buttons["achievement.done"], in: app)
        app.buttons["achievement.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["My parameters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stamina"].firstMatch.exists)
        capture(app, "i18n-en-stats")
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.buttons["settings.challenge"].waitForExistence(timeout: 5))
        capture(app, "i18n-en-settings")
        app.buttons["settings.challenge"].tap()
        XCTAssertTrue(app.buttons["challenge.restore"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["challenge.restore"].label, "Restore purchases")
        capture(app, "i18n-en-paywall")
        app.buttons["challenge.close"].tap()
        reveal(app.buttons["settings.backup"], in: app)
        app.buttons["settings.backup"].tap()
        XCTAssertTrue(app.buttons["backup.import"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["backup.import"].label, "Import a backup")
        capture(app, "i18n-en-backup")
        app.navigationBars.buttons["Settings"].tap()
        app.buttons["settings.done"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.edit.Reading 100%"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["quest.progress.Reading 100%"].label.contains("1 / 3"))
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["나의 파라미터"].waitForExistence(timeout: 5))
        capture(app, "i18n-ko-stats-preserved")
    }
    @MainActor func testEnglishRecapAndLargeTextPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-weekly-recap", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        app.launch()
        XCTAssertTrue(app.staticTexts["recap.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Here's what you built last week"].exists)
        capture(app, "i18n-en-large-recap")
        reveal(app.buttons["recap.done"], in: app)
        app.buttons["recap.done"].tap()
        app.buttons["settings.open"].tap()
        app.buttons["settings.challenge"].tap()
        XCTAssertTrue(app.buttons["challenge.restore"].waitForExistence(timeout: 5))
        reveal(app.buttons["challenge.restore"], in: app)
        XCTAssertTrue(app.buttons["challenge.restore"].isHittable)
        capture(app, "i18n-en-large-paywall")
    }
    @MainActor func testUnsupportedLanguageFallsBackToEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 10))
    }
}
