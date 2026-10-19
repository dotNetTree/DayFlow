import Foundation

public enum ScheduleSearch {
    /// 선택 날짜에 겹치는 일정에 제목·메모 검색을 적용합니다.
    public static func filter(
        _ schedules: [Schedule],
        day: Date,
        query: String,
        calendar: Calendar = .current
    ) -> [Schedule] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return schedules.filter { schedule in
            schedule.overlaps(day: day, calendar: calendar)
                && (term.isEmpty
                    || schedule.title.range(of: term, options: .caseInsensitive) != nil
                    || schedule.note.range(of: term, options: .caseInsensitive) != nil)
        }.sorted { $0.start < $1.start }
    }
}
