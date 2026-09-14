import XCTest

final class PentaphorUITests: XCTestCase {
    @MainActor func testLaunchPresentationWaitsForLoadingThenShowsIntroduction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-slow-load"]
        app.launch()
        XCTAssertTrue(app.otherElements["launch.presentation"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["onboarding.start"].exists)
        capture(app, "21-launch-growth")
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["launch.presentation"].exists)
        skipIntroduction(app)
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].exists, "Launch growth is decorative and must not award points.")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["0 P"].exists)
        XCTAssertFalse(app.otherElements["launch.presentation"].exists)
    }

    @MainActor func testFailedLaunchReachesRecoverableErrorAndRetryLoadsNormally() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-load-failure"]
        app.launch()
        XCTAssertTrue(app.buttons["launch.retry"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["기록을 열지 못했어"].exists)
        capture(app, "22-launch-recovery")
        app.buttons["launch.retry"].tap()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["launch.retry"].exists)
    }

    @MainActor func testIntroductionCreatesFirstQuestWithoutAwardingPreviewPoints() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 8))
        XCTAssertLessThan(app.buttons["onboarding.start"].frame.maxY, app.frame.maxY - 20, "The first action must be fully visible without scrolling.")
        capture(app, "16-introduction-welcome")
        reveal(app.buttons["onboarding.start"], in: app)
        app.buttons["onboarding.start"].tap()
        let nickname = app.textFields["onboarding.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("Mina\n")
        capture(app, "20-introduction-nickname")
        app.buttons["onboarding.next"].tap()
        capture(app, "17-introduction-how-it-works")
        reveal(app.buttons["onboarding.create"], in: app)
        app.buttons["onboarding.create"].tap()
        let name = app.textFields["quest.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["quest.first-help"].exists)
        name.tap()
        name.typeText("First Step\n")
        let decrease = app.buttons["체력 포인트 줄이기"]
        reveal(decrease, in: app)
        decrease.tap()
        app.buttons["지식 포인트 늘리기"].tap()
        let preview = app.descendants(matching: .any).matching(identifier: "quest.reward-preview").firstMatch
        reveal(preview, in: app)
        XCTAssertTrue(preview.label.contains("지식 1"))
        capture(app, "18-guided-reward-preview")
        app.buttons["quest.save"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["Mina의 파라미터"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 P"].exists, "Introduction and reward previews must never award actual growth.")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.edit.First Step"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.start"].exists)
        app.buttons["quest.create"].tap()
        XCTAssertFalse(app.staticTexts["quest.first-help"].exists, "Guidance ends after saving the first quest.")
        app.buttons["취소"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["Mina의 파라미터"].exists)
    }

    @MainActor func testOptionalNameSettingsAndReplayPreserveRecordedGrowth() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 8))
        reveal(app.buttons["onboarding.start"], in: app)
        app.buttons["onboarding.start"].tap()
        app.buttons["onboarding.no-name"].tap()
        reveal(app.buttons["onboarding.explore"], in: app)
        app.buttons["onboarding.explore"].tap()
        app.buttons["quest.create"].tap()
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("Keep Progress\n")
        app.buttons["quest.save"].tap()
        app.buttons["quest.complete.Keep Progress"].tap()
        reveal(app.buttons["achievement.done"], in: app)
        app.buttons["achievement.done"].tap()
        app.buttons["settings.open"].tap()
        let nickname = app.textFields["settings.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("Nova")
        app.buttons["settings.nickname.save"].tap()
        let haptics = app.switches["settings.haptics"]
        let effects = app.switches["settings.simple-effects"]
        haptics.tap()
        effects.tap()
        XCTAssertEqual(haptics.value as? String, "0")
        XCTAssertEqual(effects.value as? String, "1")
        capture(app, "19-settings")
        reveal(app.buttons["settings.replay"], in: app)
        app.buttons["settings.replay"].tap()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 5))
        reveal(app.buttons["onboarding.start"], in: app)
        app.buttons["onboarding.start"].tap()
        XCTAssertFalse(app.textFields["onboarding.nickname"].exists)
        reveal(app.buttons["onboarding.done"], in: app)
        app.buttons["onboarding.done"].tap()
        app.buttons["settings.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["Nova의 파라미터"].exists)
        XCTAssertTrue(app.staticTexts["2 P"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-test-slow-load"]
        app.launch()
        let launchAnimation = app.descendants(matching: .any).matching(identifier: "launch.animation").firstMatch
        XCTAssertTrue(launchAnimation.waitForExistence(timeout: 3))
        XCTAssertEqual(launchAnimation.value as? String, "성장 연출", "Achievement simplification must not simplify the launch animation.")
        capture(app, "23-launch-with-achievement-simplification")
        XCTAssertTrue(app.buttons["quest.edit.Keep Progress"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.start"].exists)
        app.buttons["settings.open"].tap()
        XCTAssertEqual(nickname.value as? String, "Nova")
        XCTAssertEqual(haptics.value as? String, "0")
        XCTAssertEqual(effects.value as? String, "1")
        app.buttons["settings.nickname.clear"].tap()
        app.buttons["settings.nickname.save"].tap()
        app.buttons["settings.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["나의 파라미터"].exists)
        XCTAssertTrue(app.staticTexts["2 P"].exists)
    }

    @MainActor func testSkippedIntroductionStaysDismissedAndCancelledQuestKeepsGuidance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        XCTAssertTrue(app.staticTexts["quest.first-help"].exists)
        app.buttons["취소"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.create"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.start"].exists)
        app.buttons["quest.create"].tap()
        XCTAssertTrue(app.staticTexts["quest.first-help"].exists)
        app.buttons["취소"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].exists)
    }

    @MainActor private func skipIntroduction(_ app: XCUIApplication) {
        let skip = app.buttons["onboarding.skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        XCTAssertTrue(app.buttons["quest.create"].waitForExistence(timeout: 5))
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testDeleteCanBeCancelledAndPreservesRecordedGrowthAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("Keep my growth\n")
        XCTAssertFalse(app.buttons["quest.delete"].exists)
        app.buttons["quest.save"].tap()
        app.buttons["quest.complete.Keep my growth"].tap()
        reveal(app.buttons["achievement.done"], in: app)
        app.buttons["achievement.done"].tap()
        app.buttons["quest.edit.Keep my growth"].tap()
        let delete = app.buttons["quest.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        reveal(delete, in: app)
        XCTAssertGreaterThan(delete.frame.minY, app.buttons["quest.archive"].frame.minY)
        capture(app, "10-quest-delete-entry")
        delete.tap()
        let alert = app.alerts["퀘스트를 삭제할까?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        capture(app, "11-quest-delete-confirmation")
        alert.buttons["취소"].tap()
        XCTAssertTrue(delete.exists)
        delete.tap()
        alert.buttons["삭제하기"].tap()
        XCTAssertTrue(app.staticTexts["아직 비어 있는 첫 페이지"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertFalse(app.buttons["quest.edit.Keep my growth"].exists)
        app.buttons["quest.archived"].tap()
        XCTAssertTrue(app.staticTexts["보관한 퀘스트가 없어"].waitForExistence(timeout: 5))
        app.buttons["archive.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["2 P"].waitForExistence(timeout: 5))
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["Keep my growth"].waitForExistence(timeout: 5))
    }

    @MainActor func testNotesPersistAsMultilineTextAndCancelPreservesSavedNotes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("Swimming\n")
        let notes = app.textViews["quest.notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        reveal(notes, in: app)
        notes.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Tapping the memo must focus the actual editor and show the keyboard.")
        let original = "Bring goggles\nEasy pace"
        notes.typeText(original)
        capture(app, "08-quest-notes-editor")
        app.buttons["quest.save"].tap()
        let preview = app.staticTexts["quest.notes.preview.Swimming"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertEqual(preview.label, original)
        capture(app, "09-quest-notes-preview")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["quest.edit.Swimming"].tap()
        XCTAssertEqual(notes.value as? String, original)
        reveal(notes, in: app)
        notes.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        clearNotesUsingEditMenu(notes, in: app)
        notes.typeText("Unsaved draft")
        XCTAssertEqual(notes.value as? String, "Unsaved draft")
        app.buttons["취소"].tap()
        XCTAssertEqual(preview.label, original)
        app.buttons["quest.edit.Swimming"].tap()
        XCTAssertEqual(notes.value as? String, original)
        reveal(notes, in: app)
        notes.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        clearNotesUsingEditMenu(notes, in: app)
        XCTAssertEqual(notes.value as? String, "")
        app.buttons["quest.save"].tap()
        XCTAssertFalse(preview.exists)
        XCTAssertTrue(app.staticTexts["quest.progress.Swimming"].label.contains("0 / 3"))
        app.terminate()
        app.launch()
        XCTAssertFalse(preview.exists)
        app.buttons["quest.edit.Swimming"].tap()
        XCTAssertEqual(notes.value as? String, "")
    }

    @MainActor func testVisibleEditEntryUpdatesExistingQuestAndSurvivesRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        let name = app.textFields["quest.name"]
        name.tap()
        name.typeText("Reading")
        app.buttons["quest.save"].tap()

        let edit = app.buttons["quest.edit.Reading"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(edit.staticTexts["수정"].exists, "The edit entry must be visibly labelled, not discoverable only by tapping artwork.")
        XCTAssertTrue(edit.isHittable)
        capture(app, "06-visible-edit-entry")
        edit.tap()
        XCTAssertEqual(name.value as? String, "Reading")
        XCTAssertTrue(app.staticTexts["퀘스트 수정"].exists)
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Reading".count))
        name.typeText("Evening Reading")
        app.buttons["quest.save"].tap()
        XCTAssertTrue(app.buttons["quest.edit.Evening Reading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["quest.edit.Reading"].exists)
        XCTAssertTrue(app.staticTexts["quest.progress.Evening Reading"].label.contains("0 / 3"), "Editing must not complete the quest.")

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["quest.edit.Evening Reading"].tap()
        XCTAssertEqual(name.value as? String, "Evening Reading")
        XCTAssertTrue(app.staticTexts["퀘스트 수정"].exists)
        capture(app, "07-edit-existing-quest")
    }

    @MainActor func testCreateCompleteUndoAndRelaunchPreservesQuest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
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
        XCTAssertFalse(app.staticTexts["운동"].exists, "Artwork must not assign a category to the completed quest.")
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
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        let name = app.textFields["quest.name"]
        XCTAssertFalse(app.buttons["quest.art"].staticTexts["운동"].exists)
        XCTAssertEqual(name.placeholderValue, "퀘스트 이름")
        app.buttons["quest.art"].tap()
        XCTAssertTrue(app.buttons["배움"].waitForExistence(timeout: 5))
        app.buttons["배움"].tap()
        app.buttons["art.reading"].tap()
        XCTAssertEqual(name.placeholderValue, "퀘스트 이름")
        XCTAssertEqual(name.value as? String, "퀘스트 이름", "Choosing art must leave an unnamed quest empty.")
        XCTAssertFalse(app.buttons["quest.art"].staticTexts["배움"].exists)
        name.tap()
        name.typeText("My own name")
        app.buttons["quest.art"].tap()
        XCTAssertTrue(app.buttons["art.climbing"].waitForExistence(timeout: 5))
        capture(app, "04-art-picker")
        app.buttons["art.climbing"].tap()
        XCTAssertEqual(name.value as? String, "My own name")
        XCTAssertEqual(name.placeholderValue, "퀘스트 이름")
        XCTAssertFalse(app.buttons["quest.art"].staticTexts["운동"].exists)
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
    @MainActor private func clearNotesUsingEditMenu(_ notes: XCUIElement, in app: XCUIApplication) {
        // Long-press the first line, not the editor's blank center. Use the
        // iOS edit menu instead of assuming Cmd-A worked or the keyboard stayed visible.
        notes.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12)).press(forDuration: 1.2)
        let selectAll = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["전체 선택", "Select All"])).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 3))
        capture(app, "13-memo-select-all")
        selectAll.tap()
        let cut = app.menuItems.matching(NSPredicate(format: "label IN %@", ["잘라내기", "오려두기", "Cut"])).firstMatch
        XCTAssertTrue(cut.waitForExistence(timeout: 3))
        cut.tap()
        XCTAssertEqual(notes.value as? String, "")
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
