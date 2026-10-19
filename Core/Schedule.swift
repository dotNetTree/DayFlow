import Foundation

public struct Schedule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var start: Date
    public var end: Date
    public var isCompleted: Bool
    public var isNotificationEnabled: Bool

    public init(id: UUID = UUID(), title: String, note: String = "", start: Date, end: Date, isCompleted: Bool = false, isNotificationEnabled: Bool = false) {
        self.id = id; self.title = title; self.note = note
        self.start = start; self.end = end; self.isCompleted = isCompleted
        self.isNotificationEnabled = isNotificationEnabled
    }
    private enum CodingKeys: String, CodingKey {
        case id, title, note, start, end, isCompleted, isNotificationEnabled
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        note = try values.decode(String.self, forKey: .note)
        start = try values.decode(Date.self, forKey: .start)
        end = try values.decode(Date.self, forKey: .end)
        isCompleted = try values.decode(Bool.self, forKey: .isCompleted)
        isNotificationEnabled = try values.decodeIfPresent(Bool.self, forKey: .isNotificationEnabled) ?? false
    }
    public var validationMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "제목을 입력해주세요." }
        if end < start { return "종료 시간은 시작 시간 이후여야 합니다." }
        return nil
    }
    // 자정을 넘기는 일정은 해당 날짜와 시간이 겹치면 표시합니다.
    public func overlaps(day: Date, calendar: Calendar = .current) -> Bool {
        let lower = calendar.startOfDay(for: day)
        guard let upper = calendar.date(byAdding: .day, value: 1, to: lower) else { return false }
        return start < upper && (end > lower || start == lower)
    }
}

public struct ScheduleRepository: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> [Schedule] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Schedule].self, from: Data(contentsOf: url))
    }
    public func save(_ schedules: [Schedule]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(schedules).write(to: url, options: .atomic)
    }
}
