import XCTest

final class PentaphorUITests: XCTestCase {
    @MainActor func testEditedTargetFourteenAppliesImmediatelyAfterCompletionAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("Fourteen\n")
        app.buttons["quest.save"].tap()
        app.buttons["quest.complete.Fourteen"].tap()
        reveal(app.buttons["achievement.done"], in: app)
        app.buttons["achievement.done"].tap()
        app.buttons["quest.edit.Fourteen"].tap()
        let target = app.steppers["quest.target"]
        reveal(target, in: app)
        for _ in 0..<11 { target.buttons.element(boundBy: 1).tap() }
        app.buttons["quest.save"].tap()
        XCTAssertTrue(app.staticTexts["quest.progress.Fourteen"].label.contains("1 / 14"))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["quest.progress.Fourteen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["quest.progress.Fourteen"].label.contains("1 / 14"))
    }

    @MainActor func testBackupPageProvidesFileExportAndImport() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["settings.open"].tap()
        reveal(app.buttons["settings.backup"], in: app)
        app.buttons["settings.backup"].tap()
        XCTAssertTrue(app.buttons["backup.export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["backup.import"].exists)
        app.buttons["backup.export"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 8))
        capture(app, "31-backup-file-export")
        let exportName = try XCTUnwrap(app.textFields["DOCPicker.filenameTextField"].value as? String)
        app.buttons["저장"].tap()
        XCTAssertTrue(app.staticTexts["backup.notice"].waitForExistence(timeout: 8))
        app.navigationBars.buttons["설정"].tap()
        app.buttons["settings.done"].tap()
        app.buttons["quest.create"].tap()
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("After Backup\n")
        app.buttons["quest.save"].tap()
        app.buttons["quest.complete.After Backup"].tap()
        reveal(app.buttons["achievement.done"], in: app)
        app.buttons["achievement.done"].tap()
        app.buttons["settings.open"].tap()
        reveal(app.buttons["settings.backup"], in: app)
        app.buttons["settings.backup"].tap()
        app.buttons["backup.import"].tap()
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", exportName)).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        file.tap()
        XCTAssertTrue(app.staticTexts["backup.preview"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["backup.preview.summary"].label.contains("퀘스트 0개"))
        capture(app, "32-backup-restore-preview")
        app.buttons["backup.cancel"].tap()
        XCTAssertTrue(app.staticTexts["backup.summary"].label.contains("퀘스트 1개"))
        app.buttons["backup.import"].tap()
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        file.tap()
        XCTAssertTrue(app.buttons["backup.restore"].waitForExistence(timeout: 8))
        app.buttons["backup.restore"].tap()
        XCTAssertTrue(app.buttons["backup.recovery"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["backup.summary"].label.contains("퀘스트 0개"))
        capture(app, "33-backup-restored-recovery")
        reveal(app.buttons["backup.recovery"], in: app)
        app.buttons["backup.recovery"].tap()
        XCTAssertTrue(app.staticTexts["backup.preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["backup.preview.summary"].label.contains("완료 기록 1개"))
        app.buttons["backup.restore"].tap()
        app.navigationBars.buttons["설정"].tap()
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["quest.edit.After Backup"].waitForExistence(timeout: 5))
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["2 P"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.edit.After Backup"].waitForExistence(timeout: 8))
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["2 P"].exists)
    }

    @MainActor func testWeeklyRecapColdLaunchAcknowledgementAndHistoryReplayPreservePoints() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-weekly-recap"]
        app.launch()
        XCTAssertTrue(app.staticTexts["recap.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["recap.actions"].label.contains("5"))
        capture(app, "28-weekly-recap-hero")
        reveal(app.buttons["recap.done"], in: app)
        capture(app, "29-weekly-recap-growth")
        let gains = app.descendants(matching: .any)["recap.gains"]
        reveal(gains, in: app)
        XCTAssertTrue(gains.label.contains("지식 +4"))
        XCTAssertTrue(gains.label.contains("끈기 +1"))
        app.swipeUp()
        capture(app, "30-weekly-recap-activities")
        app.buttons["recap.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["15 P"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing", "--ui-test-weekly-recap"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.history"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["recap.title"].exists)
        app.buttons["tab.history"].tap()
        app.buttons["history.weekly-recap"].tap()
        XCTAssertTrue(app.staticTexts["recap.title"].waitForExistence(timeout: 5))
        reveal(app.buttons["recap.done"], in: app)
        app.buttons["recap.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["15 P"].exists)
    }

    @MainActor func testWeeklyRecapForegroundAfterCutoffWaitsForEditorDismissal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-weekly-recap", "--ui-test-recap-on-foreground"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.edit.달리기"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["recap.title"].exists)
        app.buttons["quest.edit.달리기"].tap()
        XCTAssertTrue(app.textFields["quest.name"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.textFields["quest.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["recap.title"].exists)
        app.buttons["취소"].tap()
        XCTAssertTrue(app.staticTexts["recap.title"].waitForExistence(timeout: 5))
        reveal(app.buttons["recap.done"], in: app)
        app.buttons["recap.done"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["tab.stats"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["recap.title"].exists)
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["15 P"].exists)
    }

    @MainActor func testWeeklyRecapForegroundWaitsForHistoryUndoDialog() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--ui-test-weekly-recap", "--ui-test-recap-on-foreground"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.history"].waitForExistence(timeout: 10))
        app.buttons["tab.history"].tap()
        app.buttons["화장실 청소 기록 되돌리기"].tap()
        XCTAssertTrue(app.buttons["기록 되돌리기"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["기록 되돌리기"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["recap.title"].exists)
        // Tap the popover's dimming background; underlying accessibility elements are not hittable.
        let header = app.staticTexts["쌓아온 기록"].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: header.midX, dy: header.midY)).tap()
        XCTAssertTrue(app.staticTexts["recap.title"].waitForExistence(timeout: 5))
        app.buttons["recap.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["15 P"].exists)
    }

    @MainActor func testNotificationMasterTogglePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["settings.open"].tap()
        let toggle = app.switches["settings.reminder.enabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        reveal(toggle, in: app)
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "허용"])).firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        if toggle.value as? String == "0" {
            toggle.tap()
            app.navigationBars.firstMatch.tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")
        capture(app, "27-reminder-master-on")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["settings.reminder.test"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["settings.open"].tap()
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertTrue(app.buttons["settings.reminder.test"].exists)
        app.buttons["settings.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].exists)
    }

    @MainActor func testSettingsDeliversRealTestNotificationWithoutAwardingPoints() throws {
        // A missing OS adapter or foreground presentation delegate breaks this test.
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["settings.open"].tap()
        let status = app.staticTexts["settings.reminder.authorization"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        reveal(status, in: app)
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "허용"])).firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        let allow = app.switches["settings.reminder.enabled"]
        if allow.value as? String == "0" {
            reveal(allow, in: app)
            allow.tap()
            app.navigationBars.firstMatch.tap()
        }
        let allowed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "허용됨"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [allowed], timeout: 5), .completed)
        let test = app.buttons["settings.reminder.test"]
        reveal(test, in: app)
        capture(app, "25-reminder-settings")
        test.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notification = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "알림이 잘 도착했습니다.")).firstMatch
        XCTAssertTrue(notification.waitForExistence(timeout: 10), "The real five-second notification must appear in iOS, beyond the in-app success message.")
        XCTAssertTrue(springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "PENTAPHOR")).firstMatch.exists)
        capture(springboard, "26-real-test-notification")
        notification.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5), "A test notification must not open a quest editor.")
        app.buttons["settings.done"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].waitForExistence(timeout: 5), "Receiving and opening a test notification must not award points.")
    }

    @MainActor func testReminderSelectionPersistsAndCancelledChangesStayUnsaved() throws {
        // Missing reminder persistence or saving a cancelled draft breaks this flow.
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        app.buttons["quest.create"].tap()
        app.textFields["quest.name"].tap()
        app.textFields["quest.name"].typeText("Evening Practice\n")
        let enabled = app.switches["quest.reminder.enabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 5))
        reveal(enabled, in: app)
        XCTAssertEqual(enabled.value as? String, "0")
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "허용"])).firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        enabled.tap()
        app.navigationBars.firstMatch.tap() // Handles the prompt without changing a draft control.
        let tuesday = app.buttons["quest.reminder.weekday.3"]
        reveal(tuesday, in: app)
        XCTAssertEqual(app.buttons["quest.reminder.weekday.2"].value as? String, "선택됨")
        XCTAssertEqual(tuesday.value as? String, "선택 안 됨")
        tuesday.tap()
        XCTAssertEqual(tuesday.value as? String, "선택됨")
        XCTAssertEqual(app.staticTexts["quest.reminder.time.summary"].label, "20:00")
        capture(app, "24-reminder-editor")
        app.buttons["quest.save"].tap()
        XCTAssertTrue(app.buttons["quest.edit.Evening Practice"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["quest.edit.Evening Practice"].tap()
        reveal(enabled, in: app)
        XCTAssertEqual(enabled.value as? String, "1")
        reveal(tuesday, in: app)
        XCTAssertEqual(tuesday.value as? String, "선택됨")
        XCTAssertEqual(app.staticTexts["quest.reminder.time.summary"].label, "20:00")
        for day in [2, 3, 4, 6] { app.buttons["quest.reminder.weekday.\(day)"].tap() }
        XCTAssertFalse(app.buttons["quest.save"].isEnabled, "An enabled reminder must have at least one weekday.")
        app.buttons["취소"].tap()
        app.buttons["quest.edit.Evening Practice"].tap()
        reveal(tuesday, in: app)
        XCTAssertEqual(tuesday.value as? String, "선택됨")
        XCTAssertTrue(app.buttons["quest.save"].isEnabled)
        app.buttons["취소"].tap()
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].exists, "Editing reminders must never award points.")
    }

    @MainActor func testUnifiedListAndOneTimeCompletionUndoAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        skipIntroduction(app)
        for (name, cadence) in [("Monthly", "매월"), ("Weekly", "매주"), ("One Time", "한 번")] {
            reveal(app.buttons["quest.create"], in: app)
            app.buttons["quest.create"].tap()
            app.textFields["quest.name"].tap()
            app.textFields["quest.name"].typeText(name + "\n")
            let picker = app.segmentedControls.firstMatch
            reveal(picker, in: app)
            XCTAssertTrue(picker.buttons[cadence].exists)
            guard picker.buttons[cadence].exists else { return }
            picker.buttons[cadence].tap()
            if cadence == "한 번" {
                XCTAssertFalse(app.steppers["quest.target"].exists)
                capture(app, "24-one-time-editor")
            }
            app.buttons["quest.save"].tap()
            XCTAssertTrue(app.buttons["quest.edit." + name].waitForExistence(timeout: 5))
        }
        XCTAssertFalse(app.staticTexts["이번 주"].exists)
        XCTAssertFalse(app.staticTexts["이번 달"].exists)
        XCTAssertLessThan(app.buttons["quest.edit.Monthly"].frame.minY, app.buttons["quest.edit.Weekly"].frame.minY)
        XCTAssertLessThan(app.buttons["quest.edit.Weekly"].frame.minY, app.buttons["quest.edit.One Time"].frame.minY)
        XCTAssertEqual(app.staticTexts["quest.progress.One Time"].label, "한 번")
        capture(app, "25-unified-quests")
        app.buttons["quest.complete.One Time"].tap()
        XCTAssertTrue(app.staticTexts["achievement.title"].waitForExistence(timeout: 5))
        reveal(app.buttons["achievement.done"], in: app)
        XCTAssertTrue(app.staticTexts["완료한 퀘스트는 기록에 남겨뒀어."].exists)
        capture(app, "26-one-time-achievement")
        app.buttons["achievement.done"].tap()
        XCTAssertFalse(app.buttons["quest.complete.One Time"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["quest.complete.Weekly"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["quest.complete.One Time"].exists)
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["2 P"].exists)
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["한 번 · 완료"].exists)
        capture(app, "27-one-time-history")
        app.buttons["One Time 기록 되돌리기"].tap()
        app.buttons["기록 되돌리기"].tap()
        app.buttons["tab.quests"].tap()
        XCTAssertTrue(app.buttons["quest.complete.One Time"].waitForExistence(timeout: 5))
        app.buttons["tab.stats"].tap()
        XCTAssertTrue(app.staticTexts["0 P"].exists)
        app.buttons["tab.quests"].tap()
        app.buttons["quest.complete.One Time"].tap()
        XCTAssertTrue(app.staticTexts["achievement.title"].waitForExistence(timeout: 5))
        reveal(app.buttons["achievement.undo"], in: app)
        app.buttons["achievement.undo"].tap()
        XCTAssertTrue(app.buttons["quest.complete.One Time"].waitForExistence(timeout: 5))
    }

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
        XCTAssertTrue(app.staticTexts["다음 걸음을 기다리는 중"].waitForExistence(timeout: 5))
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
