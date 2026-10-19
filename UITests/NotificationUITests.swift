import XCTest

@MainActor
final class NotificationUITests: XCTestCase {
    private var app: XCUIApplication!
    private let sampleTitle = "오늘의 계획 세우기"

    private func launch(_ flags: [String] = [], future: Bool = true) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + flags
        if future { app.launchArguments.append("--notification-qa") }
        app.launch()
        XCTAssertTrue(app.buttons["schedule.add"].waitForExistence(timeout: 10))
    }
    private func capture(_ checkpoint: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "DF-002_\(checkpoint)"
        image.lifetime = .keepAlways
        add(image)
    }
    private var sample: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "schedule.edit.", sampleTitle)).firstMatch
    }
    private func openSample() {
        for _ in 0..<5 {
            if sample.exists && sample.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        sample.tap()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 5))
    }
    private var toggle: XCUIElement { app.switches.matching(identifier: "notification.toggle").firstMatch }
    private func enableNotification() {
        for _ in 0..<4 {
            if toggle.exists && toggle.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(toggle.exists)
        if toggle.value as? String != "1" {
            capture("알림토글_조작전")
            // SwiftUI Form은 행 전체를 Switch로 노출하므로 오른쪽 실제 스위치를 누릅니다.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            capture("알림토글_조작후")
        }
        let enabled = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: toggle)
        wait(for: [enabled], timeout: 5)
        XCTAssertEqual(toggle.value as? String, "1")
    }
    private func save() {
        let button = app.buttons["editor.save"]
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
        wait(for: [ready], timeout: 5)
        button.tap()
        XCTAssertTrue(app.textFields["editor.title"].waitForNonExistence(timeout: 5))
    }

    func testNotificationToggleSaveAndCancel() {
        launch()
        defer { app.terminate() }
        openSample()
        XCTAssertEqual(toggle.value as? String, "0")
        enableNotification()
        XCTAssertTrue(app.staticTexts["notification.permission"].label.contains("저장하면"))
        capture("권한허용_알림켜기")
        app.buttons["editor.cancel"].tap()
        openSample()
        XCTAssertEqual(toggle.value as? String, "0", "취소한 설정은 저장하지 않아야 합니다.")
        enableNotification()
        save()
        openSample()
        XCTAssertEqual(toggle.value as? String, "1", "저장한 알림 설정이 유지되어야 합니다.")
        capture("알림설정_저장후재편집")
    }

    func testDeniedPermissionStillAllowsSaving() {
        launch(["--notification-denied"])
        defer { app.terminate() }
        openSample()
        enableNotification()
        XCTAssertTrue(app.staticTexts["notification.permission"].label.contains("꺼져"))
        XCTAssertTrue(app.buttons["notification.settings"].exists)
        capture("권한거부_설정안내")
        save()
        let message = app.staticTexts["notification.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("알림 권한이 꺼져"))
        openSample()
        XCTAssertEqual(toggle.value as? String, "1", "권한 거부와 사용자의 알림 의도를 구분합니다.")
    }

    func testSchedulingFailureKeepsSavedScheduleAndAllowsRetry() {
        launch(["--notification-failure"])
        defer { app.terminate() }
        openSample()
        enableNotification()
        save()
        let message = app.staticTexts["notification.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("일정은 저장했지만"))
        let retry = app.buttons["notification.retry"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(sample.exists)
        capture("예약실패_저장유지_재시도")
        openSample()
        XCTAssertEqual(toggle.value as? String, "1")
    }

    func testPastScheduleExplainsWhyItWillNotNotify() {
        launch(future: false)
        defer { app.terminate() }
        openSample()
        enableNotification()
        XCTAssertTrue(app.staticTexts["notification.past"].exists)
        XCTAssertTrue(app.buttons["editor.save"].isEnabled)
        capture("과거일정_예약제외안내")
        save()
        XCTAssertTrue(sample.exists)
    }
}
