import Foundation

public enum NotificationAuthorization: String, Sendable {
    case notDetermined, authorized, denied, provisional, ephemeral, unknown
    public var allowsScheduling: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

public struct ScheduleNotification: Equatable, Sendable {
    public static let prefix = "dayflow.schedule."
    public var identifier: String
    public var title: String
    public var date: Date
    public init(schedule: Schedule) {
        identifier = Self.prefix + schedule.id.uuidString
        title = schedule.title
        date = schedule.start
    }
    public static func plan(_ schedules: [Schedule], now: Date, limit: Int = 32) -> (requests: [Self], waiting: Int) {
        let eligible = schedules.filter { $0.isNotificationEnabled && !$0.isCompleted && $0.start > now }
            .sorted { $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start < $1.start }
        let selected = eligible.prefix(max(0, limit)).map(Self.init)
        return (selected, eligible.count - selected.count)
    }
}

// 시스템 API 대신 가짜 구현을 주입할 수 있어 데모와 테스트가 실제 알림을 건드리지 않습니다.
public struct ScheduleNotificationClient: Sendable {
    public var authorization: @Sendable () async -> NotificationAuthorization
    public var requestAuthorization: @Sendable () async throws -> NotificationAuthorization
    public var pendingIdentifiers: @Sendable () async -> [String]
    public var deliveredIdentifiers: @Sendable () async -> [String]
    public var removePending: @Sendable ([String]) async -> Void
    public var removeDelivered: @Sendable ([String]) async -> Void
    public var add: @Sendable (ScheduleNotification) async throws -> Void
    public init(
        authorization: @escaping @Sendable () async -> NotificationAuthorization,
        requestAuthorization: @escaping @Sendable () async throws -> NotificationAuthorization,
        pendingIdentifiers: @escaping @Sendable () async -> [String],
        deliveredIdentifiers: @escaping @Sendable () async -> [String],
        removePending: @escaping @Sendable ([String]) async -> Void,
        removeDelivered: @escaping @Sendable ([String]) async -> Void,
        add: @escaping @Sendable (ScheduleNotification) async throws -> Void
    ) {
        self.authorization = authorization; self.requestAuthorization = requestAuthorization
        self.pendingIdentifiers = pendingIdentifiers; self.deliveredIdentifiers = deliveredIdentifiers
        self.removePending = removePending; self.removeDelivered = removeDelivered; self.add = add
    }
    public static func demo(authorization: NotificationAuthorization = .authorized, failsScheduling: Bool = false) -> Self {
        Self(authorization: { authorization }, requestAuthorization: { authorization },
             pendingIdentifiers: { [] }, deliveredIdentifiers: { [] }, removePending: { _ in }, removeDelivered: { _ in },
             add: { _ in if failsScheduling { throw DemoNotificationError.schedulingFailed } })
    }
}
private enum DemoNotificationError: Error { case schedulingFailed }

public struct NotificationSyncReport: Sendable {
    public var authorization: NotificationAuthorization
    public var scheduledCount: Int
    public var waitingCount: Int
    public var failed: Bool
}

@MainActor
public final class ScheduleNotificationCoordinator {
    private let client: ScheduleNotificationClient
    private let now: @Sendable () -> Date
    private var tail: Task<NotificationSyncReport, Never>?
    private var permissionTask: Task<NotificationAuthorization, Error>?
    public init(client: ScheduleNotificationClient, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client; self.now = now
    }
    // 저장 성공 직후 동기적으로 enqueue하여 Swift Task 시작 순서와 저장 순서가 엇갈리지 않게 합니다.
    public func enqueue(_ schedules: [Schedule]) -> Task<NotificationSyncReport, Never> {
        let previous = tail
        let client = client
        let now = now
        let task = Task {
            _ = await previous?.value
            let authorization = await client.authorization()
            let plan = ScheduleNotification.plan(schedules, now: now())
            let requests = authorization.allowsScheduling ? plan.requests : []
            let desired = Set(requests.map(\.identifier))
            let pending = await client.pendingIdentifiers()
            await client.removePending(pending.filter { $0.hasPrefix(ScheduleNotification.prefix) && !desired.contains($0) })
            // 활성 미래 일정의 전달 알림은 유지하고, 삭제/완료/알림 끄기 항목을 정리합니다.
            let active = Set(schedules.filter { $0.isNotificationEnabled && !$0.isCompleted }.map { ScheduleNotification(schedule: $0).identifier })
            let delivered = await client.deliveredIdentifiers()
            await client.removeDelivered(delivered.filter { $0.hasPrefix(ScheduleNotification.prefix) && !active.contains($0) })
            var count = 0
            var failed = false
            for request in requests {
                do { try await client.add(request); count += 1 }
                catch {
                    failed = true
                    // 이전 제목/시간의 예약이 남아 잘못 전달되는 것을 막고 재시도를 안내합니다.
                    await client.removePending([request.identifier])
                }
            }
            return NotificationSyncReport(authorization: authorization, scheduledCount: count, waitingCount: plan.waiting, failed: failed)
        }
        tail = task
        return task
    }
    public func authorization() async -> NotificationAuthorization { await client.authorization() }
    // UI 토글 조작에서만 호출합니다. 동시에 들어온 요청은 하나의 시스템 요청을 공유합니다.
    public func requestPermission() async throws -> NotificationAuthorization {
        if let permissionTask { return try await permissionTask.value }
        let client = client
        let task = Task {
            let status = await client.authorization()
            return status == .notDetermined ? try await client.requestAuthorization() : status
        }
        permissionTask = task
        defer { permissionTask = nil }
        return try await task.value
    }
}
