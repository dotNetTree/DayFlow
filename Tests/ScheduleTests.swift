import XCTest
@testable import DayFlowCore

final class ScheduleTests: XCTestCase {
    func testValidation() {
        let now = Date()
        XCTAssertNotNil(Schedule(title: "  ", start: now, end: now).validationMessage)
        XCTAssertNotNil(Schedule(title: "일정", start: now, end: now.addingTimeInterval(-1)).validationMessage)
        XCTAssertNil(Schedule(title: "일정", start: now, end: now).validationMessage)
    }
    func testMidnightOverlapAndExclusiveEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 86400)
        let overnight = Schedule(title: "야간 작업", start: day.addingTimeInterval(-3600), end: day.addingTimeInterval(3600))
        XCTAssertTrue(overnight.overlaps(day: day, calendar: calendar))
        let ending = Schedule(title: "종료", start: day.addingTimeInterval(-3600), end: day)
        XCTAssertFalse(ending.overlaps(day: day, calendar: calendar))
        let next = Schedule(title: "다음 날", start: day.addingTimeInterval(86400), end: day.addingTimeInterval(90000))
        XCTAssertFalse(next.overlaps(day: day, calendar: calendar))
    }
    func testPersistenceRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ScheduleRepository(url: directory.appendingPathComponent("events.json"))
        XCTAssertEqual(try repository.load(), [])
        let item = Schedule(title: "회의", start: Date(), end: Date())
        try repository.save([item])
        XCTAssertEqual(try repository.load(), [item])
        try repository.save([])
        XCTAssertEqual(try repository.load(), [])
    }
    func testCorruptDataThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("invalid".utf8).write(to: url)
        XCTAssertThrowsError(try ScheduleRepository(url: url).load())
    }
}
