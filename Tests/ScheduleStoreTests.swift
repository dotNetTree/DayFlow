import XCTest
@testable import DayFlowCore

private actor StoreNotificationRecorder {
    var calls = 0
    var added: [ScheduleNotification] = []
    func record() { calls += 1 }
    func record(_ notification: ScheduleNotification) { calls += 1; added.append(notification) }
    nonisolated var client: ScheduleNotificationClient {
        ScheduleNotificationClient(
            authorization: { await self.record(); return .authorized },
            requestAuthorization: { await self.record(); return .authorized },
            pendingIdentifiers: { await self.record(); return [] },
            deliveredIdentifiers: { await self.record(); return [] },
            removePending: { _ in await self.record() },
            removeDelivered: { _ in await self.record() },
            add: { await self.record($0) }
        )
    }
}

final class ScheduleStoreTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func futureSchedule() -> Schedule {
        let start = Date().addingTimeInterval(86400)
        return Schedule(title: "알림 회의", start: start, end: start.addingTimeInterval(3600), isNotificationEnabled: true)
    }

    @MainActor
    func testFailedSaveAndDeletePreserveStateWithoutNotificationCalls() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ScheduleRepository(url: directory.appendingPathComponent("events.json"))
        let original = futureSchedule()
        try repository.save([original])
        let recorder = StoreNotificationRecorder()
        let store = ScheduleStore(repository: repository, notificationClient: recorder.client)
        // 로드 뒤 저장 경로를 디렉터리로 바꿔 실제 파일 저장 실패를 재현합니다.
        try FileManager.default.removeItem(at: repository.url)
        try FileManager.default.createDirectory(at: repository.url, withIntermediateDirectories: true)
        var edited = original
        edited.title = "변경 제목"
        XCTAssertFalse(store.upsert(edited))
        XCTAssertEqual(store.schedules, [original])
        XCTAssertFalse(store.commit([]))
        XCTAssertEqual(store.schedules, [original])
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.isSyncingNotifications)
        for _ in 0..<20 { await Task.yield() }
        let calls = await recorder.calls
        XCTAssertEqual(calls, 0)
    }

    @MainActor
    func testCorruptLoadDoesNotSyncOrOverwriteOriginalFile() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ScheduleRepository(url: directory.appendingPathComponent("events.json"))
        let corrupt = Data("corrupt JSON".utf8)
        try corrupt.write(to: repository.url)
        let recorder = StoreNotificationRecorder()
        let store = ScheduleStore(repository: repository, notificationClient: recorder.client)
        store.syncNotifications()
        XCTAssertFalse(store.upsert(futureSchedule()))
        XCTAssertTrue(store.schedules.isEmpty)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try Data(contentsOf: repository.url), corrupt)
        for _ in 0..<20 { await Task.yield() }
        let calls = await recorder.calls
        XCTAssertEqual(calls, 0)
    }

    @MainActor
    func testSuccessfulCommitPersistsAndEnqueuesNotification() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ScheduleRepository(url: directory.appendingPathComponent("events.json"))
        let recorder = StoreNotificationRecorder()
        let store = ScheduleStore(repository: repository, notificationClient: recorder.client)
        let item = futureSchedule()
        XCTAssertTrue(store.upsert(item))
        XCTAssertEqual(try repository.load(), [item])
        for _ in 0..<1000 {
            if !store.isSyncingNotifications { break }
            await Task.yield()
        }
        XCTAssertFalse(store.isSyncingNotifications)
        let added = await recorder.added
        XCTAssertEqual(added, [ScheduleNotification(schedule: item)])
        XCTAssertEqual(store.authorization, .authorized)
    }

    @MainActor
    func testPermissionGrantCannotBeOverwrittenByOlderSync() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PermissionSyncGate()
        let client = ScheduleNotificationClient(
            authorization: { await gate.status },
            requestAuthorization: { await gate.grant() },
            pendingIdentifiers: { await gate.pending() },
            deliveredIdentifiers: { [] }, removePending: { _ in }, removeDelivered: { _ in }, add: { _ in }
        )
        let store = ScheduleStore(repository: ScheduleRepository(url: directory.appendingPathComponent("events.json")), notificationClient: client)
        store.syncNotifications()
        for _ in 0..<1000 {
            if await gate.blocked { break }
            await Task.yield()
        }
        let blocked = await gate.blocked
        XCTAssertTrue(blocked)
        await store.requestNotificationPermission()
        await gate.release()
        for _ in 0..<1000 {
            if !store.isSyncingNotifications { break }
            await Task.yield()
        }
        XCTAssertFalse(store.isSyncingNotifications)
        XCTAssertEqual(store.authorization, .authorized)
    }

    @MainActor
    func testDemoNeverReadsOrWritesRepository() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ScheduleRepository(url: directory.appendingPathComponent("events.json"))
        let sentinel = Data("실제 파일은 읽거나 변경하지 않음".utf8)
        try sentinel.write(to: repository.url)
        let store = ScheduleStore(repository: repository, notificationClient: .demo(), demo: true)
        XCTAssertNil(store.error)
        let item = futureSchedule()
        XCTAssertTrue(store.commit([item]))
        XCTAssertEqual(store.schedules, [item])
        XCTAssertEqual(try Data(contentsOf: repository.url), sentinel)
        for _ in 0..<1000 {
            if !store.isSyncingNotifications { break }
            await Task.yield()
        }
        XCTAssertFalse(store.isSyncingNotifications)
    }
}

private actor PermissionSyncGate {
    var status: NotificationAuthorization = .notDetermined
    var blocked = false
    private var continuation: CheckedContinuation<[String], Never>?
    func grant() -> NotificationAuthorization { status = .authorized; return status }
    func pending() async -> [String] {
        guard !blocked else { return [] }
        blocked = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func release() { continuation?.resume(returning: []); continuation = nil }
}
