import XCTest

@MainActor
final class DayFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["schedule.add"].waitForExistence(timeout: 10))
    }

    override func tearDownWithError() throws {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
    }

    private func editor(for title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "schedule.edit.", title)).firstMatch
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func enterTitle(_ title: String) {
        let field = app.textFields["editor.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
    }

    private func save() {
        let button = app.buttons["editor.save"]
        XCTAssertTrue(button.isEnabled)
        button.tap()
        XCTAssertTrue(app.textFields["editor.title"].waitForNonExistence(timeout: 5))
    }

    func testCreateEditCompleteAndDeleteSchedule() {
        app.buttons["schedule.add"].tap()
        enterTitle("UI 자동화 일정")
        save()
        let created = editor(for: "UI 자동화 일정")
        reveal(created)
        let id = created.identifier.replacingOccurrences(of: "schedule.edit.", with: "")
        created.tap()
        let field = app.textFields["editor.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        // 전체 문자열 삭제로 커서 위치나 시스템 메뉴 언어에 의존하지 않습니다.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "UI 자동화 일정".count))
        field.typeText("UI 수정된 일정")
        save()
        let edited = editor(for: "UI 수정된 일정")
        reveal(edited)
        XCTAssertFalse(editor(for: "UI 자동화 일정").exists)
        let complete = app.buttons["schedule.complete.\(id)"]
        complete.tap()
        XCTAssertEqual(complete.value as? String, "completed")
        complete.tap()
        XCTAssertEqual(complete.value as? String, "pending")
        edited.swipeLeft()
        app.buttons["schedule.delete.\(id)"].tap()
        let confirmation = app.buttons["schedule.delete.confirm"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(edited.waitForNonExistence(timeout: 5))
    }

    func testInvalidTitleCannotSaveAndCancelDoesNotCreateSchedule() {
        app.buttons["schedule.add"].tap()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["editor.save"].isEnabled)
        enterTitle("   ")
        XCTAssertFalse(app.buttons["editor.save"].isEnabled)
        app.buttons["editor.cancel"].tap()
        XCTAssertTrue(app.textFields["editor.title"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(editor(for: "   ").exists)
    }

    func testDemoRelaunchResetsCreatedSchedule() {
        app.buttons["schedule.add"].tap()
        enterTitle("재실행 초기화 확인")
        save()
        reveal(editor(for: "재실행 초기화 확인"))
        app.terminate()
        app.launch()
        let sample = editor(for: "오늘의 계획 세우기")
        reveal(sample)
        XCTAssertFalse(editor(for: "재실행 초기화 확인").exists)
    }
}
