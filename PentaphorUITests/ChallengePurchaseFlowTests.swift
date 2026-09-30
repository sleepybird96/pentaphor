import XCTest

final class ChallengePurchaseFlowTests: XCTestCase {
    @MainActor func testPurchaseUnlocksStoredGrowth() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-challenge"] + ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.stats"].waitForExistence(timeout: 10))
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["99"].firstMatch.exists)
        app.buttons["settings.open"].tap()
        app.buttons["settings.challenge"].tap()
        XCTAssertTrue(app.buttons["challenge.purchase"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "challenge-purchase-screen"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["challenge.purchase"].tap()
        XCTAssertTrue(app.buttons["challenge.unlocked.done"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["challenge.unlocked.done"].wait(for: \.isEnabled, toEqual: true, timeout: 5))
        app.buttons["challenge.unlocked.done"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.done"].wait(for: \.isHittable, toEqual: true, timeout: 5))
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.staticTexts["140"].firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor func testBelowCapUnlockKeepsActualPoints() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-challenge", "--ui-test-challenge-small"] + ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 10))
        app.buttons["settings.open"].tap()
        app.buttons["settings.challenge"].tap()
        XCTAssertTrue(app.buttons["challenge.purchase"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "challenge-purchase-screen"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["challenge.purchase"].tap()
        XCTAssertTrue(app.buttons["challenge.unlocked.done"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["challenge.unlocked.done"].wait(for: \.isEnabled, toEqual: true, timeout: 5))
        app.buttons["challenge.unlocked.done"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.done"].wait(for: \.isHittable, toEqual: true, timeout: 5))
        app.buttons["settings.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["50"].firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor func testFreeLimitShowsPaywallAndCancelKeepsQuests() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-challenge"] + ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.quests"].waitForExistence(timeout: 10))
        for _ in 0..<5 { if app.buttons["quest.create"].isHittable { break }; app.swipeUp() }
        app.buttons["quest.create"].tap()
        XCTAssertTrue(app.buttons["challenge.close"].waitForExistence(timeout: 5))
        app.buttons["challenge.close"].tap()
        XCTAssertTrue(app.buttons["quest.create"].waitForExistence(timeout: 5))
    }
}
