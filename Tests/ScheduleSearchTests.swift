import XCTest
@testable import DayFlowCore

final class ScheduleSearchTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return result
    }
    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 19))!
    }
    private func item(_ title: String, note: String = "", hour: Double = 9, completed: Bool = false) -> Schedule {
        Schedule(title: title, note: note, start: day.addingTimeInterval(hour * 3600),
                 end: day.addingTimeInterval((hour + 1) * 3600), isCompleted: completed)
    }
    private func search(_ schedules: [Schedule], _ query: String, day selectedDay: Date? = nil) -> [Schedule] {
        ScheduleSearch.filter(schedules, day: selectedDay ?? day, query: query, calendar: calendar)
    }

    func testTitleAndNoteMatchIndependentlyIgnoringEnglishCase() {
        let titleMatch = item("Team Meeting")
        let noteMatch = item("점검", note: "MEETING room B")
        let unrelated = item("운동", note: "공원")
        XCTAssertEqual(search([titleMatch, noteMatch, unrelated], "mEeTiNg").map(\.id), [titleMatch.id, noteMatch.id])
        XCTAssertEqual(search([titleMatch, unrelated], "없는 검색어"), [])
    }

    func testKoreanSubstringAndPreservedInnerWhitespace() {
        let match = item("팀 회의", note: "회의실 B")
        XCTAssertEqual(search([match], "의실"), [match])
        XCTAssertEqual(search([match], "팀 회의"), [match])
        XCTAssertEqual(search([match], "팀  회의"), [])
    }

    func testTrimmedAndEmptyQueriesRestoreAllDaySchedules() {
        let match = item("Team Meeting")
        let other = item("운동", hour: 10)
        XCTAssertEqual(search([match, other], " \nmeeting\t "), [match])
        for query in ["", " \n\t "] {
            XCTAssertEqual(search([other, match], query), [match, other])
        }
    }

    func testCalendarBoundariesAndChangingDayWithSameQuery() {
        let overnight = item("회의", hour: -0.5)
        let endingAtMidnight = item("회의", hour: -1)
        let beginningAtNextMidnight = item("회의", hour: 24)
        XCTAssertEqual(search([overnight, endingAtMidnight, beginningAtNextMidnight], "회의"), [overnight])
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        XCTAssertEqual(search([overnight, beginningAtNextMidnight], "회의", day: tomorrow), [beginningAtNextMidnight])
    }

    func testCompletedSchedulesIncludedAndSortedByStart() {
        let later = item("회의", hour: 16)
        let earlier = item("회의", hour: 8, completed: true)
        XCTAssertEqual(search([later, earlier], "회의"), [earlier, later])
    }
}
