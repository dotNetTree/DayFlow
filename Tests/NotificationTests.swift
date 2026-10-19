import XCTest
@testable import DayFlowCore

private actor RecordingNotifications {
    var status: NotificationAuthorization = .notDetermined
    var requests: [String: ScheduleNotification] = [:]
    var delivered = ["other.feature", ScheduleNotification.prefix + "old"]
    var permissionRequests = 0
    var fails = false
    func client() -> ScheduleNotificationClient {
        ScheduleNotificationClient(authorization: { await self.status }, requestAuthorization: { await self.grant() },
                                   pendingIdentifiers: { await self.identifiers() }, deliveredIdentifiers: { await self.delivered },
                                   removePending: { await self.remove($0) }, removeDelivered: { await self.removeDelivered($0) },
                                   add: { try await self.add($0) })
    }
    func grant() -> NotificationAuthorization { permissionRequests += 1; status = .authorized; return status }
    func identifiers() -> [String] { Array(requests.keys) }
    func remove(_ ids: [String]) { ids.forEach { requests.removeValue(forKey: $0) } }
    func removeDelivered(_ ids: [String]) { delivered.removeAll { ids.contains($0) } }
    func setFailure(_ value: Bool) { fails = value }
    func add(_ item: ScheduleNotification) async throws {
        try await Task.sleep(for: .milliseconds(5))
        if fails { throw CocoaError(.fileWriteUnknown) }
        requests[item.identifier] = item
    }
}

final class NotificationTests: XCTestCase {
    func testLegacyJSONDefaultsToDisabled() throws {
        let item = Schedule(title: "기존", start: Date(), end: Date())
        let data = try JSONEncoder().encode(item)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "isNotificationEnabled")
        let restored = try JSONDecoder().decode(Schedule.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(item, restored)
        XCTAssertFalse(restored.isNotificationEnabled)
    }
    func testEligibilityAndNearest32() {
        let now = Date(timeIntervalSince1970: 1000)
        var items = (1...35).reversed().map { Schedule(title: "\($0)", start: now.addingTimeInterval(Double($0)), end: now.addingTimeInterval(100), isNotificationEnabled: true) }
        items += [Schedule(title: "현재", start: now, end: now, isNotificationEnabled: true),
                  Schedule(title: "과거", start: now.addingTimeInterval(-1), end: now, isNotificationEnabled: true),
                  Schedule(title: "완료", start: now.addingTimeInterval(1), end: now, isCompleted: true, isNotificationEnabled: true),
                  Schedule(title: "끔", start: now.addingTimeInterval(1), end: now)]
        let plan = ScheduleNotification.plan(items, now: now)
        XCTAssertEqual(plan.requests.count, 32)
        XCTAssertEqual(plan.waiting, 3)
        XCTAssertEqual(plan.requests.first?.title, "1")
        XCTAssertEqual(plan.requests.last?.title, "32")
    }
    @MainActor func testPermissionIsExplicitAndOnlyRequestedOnce() async throws {
        let recorder = RecordingNotifications()
        let coordinator = ScheduleNotificationCoordinator(client: await recorder.client())
        let report = await coordinator.enqueue([]).value
        XCTAssertEqual(report.authorization, .notDetermined)
        let initial = await recorder.permissionRequests
        XCTAssertEqual(initial, 0)
        _ = try await coordinator.requestPermission()
        _ = try await coordinator.requestPermission()
        let count = await recorder.permissionRequests
        XCTAssertEqual(count, 1)
    }
    @MainActor func testQueuedEditAndDeleteLeaveLatestStateAndPreserveForeignNotifications() async throws {
        let recorder = RecordingNotifications()
        let coordinator = ScheduleNotificationCoordinator(client: await recorder.client())
        _ = try await coordinator.requestPermission()
        var item = Schedule(title: "원래", start: Date().addingTimeInterval(500), end: Date().addingTimeInterval(600), isNotificationEnabled: true)
        let first = coordinator.enqueue([item])
        item.title = "수정"
        let second = coordinator.enqueue([item])
        let last = coordinator.enqueue([])
        _ = await first.value; _ = await second.value; _ = await last.value
        let pending = await recorder.identifiers()
        let delivered = await recorder.delivered
        XCTAssertTrue(pending.isEmpty)
        XCTAssertEqual(delivered, ["other.feature"])
    }
    @MainActor func testScheduleFailureAndRetry() async throws {
        let recorder = RecordingNotifications()
        let coordinator = ScheduleNotificationCoordinator(client: await recorder.client())
        _ = try await coordinator.requestPermission()
        let item = Schedule(title: "회의", start: Date().addingTimeInterval(500), end: Date().addingTimeInterval(600), isNotificationEnabled: true)
        await recorder.setFailure(true)
        let failed = await coordinator.enqueue([item]).value
        XCTAssertTrue(failed.failed)
        await recorder.setFailure(false)
        let retried = await coordinator.enqueue([item]).value
        XCTAssertFalse(retried.failed)
        XCTAssertEqual(retried.scheduledCount, 1)
    }
    @MainActor func testFailedUpdateRemovesOldRequestAndCompletionClearsDelivered() async throws {
        let recorder = RecordingNotifications()
        let coordinator = ScheduleNotificationCoordinator(client: await recorder.client())
        _ = try await coordinator.requestPermission()
        var item = Schedule(title: "원래", start: Date().addingTimeInterval(500), end: Date().addingTimeInterval(600), isNotificationEnabled: true)
        _ = await coordinator.enqueue([item]).value
        await recorder.setFailure(true)
        item.title = "새 제목"
        let failed = await coordinator.enqueue([item]).value
        let pending = await recorder.identifiers()
        XCTAssertTrue(failed.failed)
        XCTAssertTrue(pending.isEmpty)
        await recorder.setFailure(false)
        _ = await coordinator.enqueue([item]).value
        item.isCompleted = true
        _ = await coordinator.enqueue([item]).value
        let completedPending = await recorder.identifiers()
        XCTAssertTrue(completedPending.isEmpty)
        item.isCompleted = false
        let restored = await coordinator.enqueue([item]).value
        XCTAssertEqual(restored.scheduledCount, 1)
        item.isNotificationEnabled = false
        _ = await coordinator.enqueue([item]).value
        let disabledPending = await recorder.identifiers()
        XCTAssertTrue(disabledPending.isEmpty)
    }
    @MainActor func testPermissionFailureDoesNotPreventExplicitRetry() async throws {
        let failingClient = ScheduleNotificationClient(
            authorization: { .notDetermined }, requestAuthorization: { throw CocoaError(.userCancelled) },
            pendingIdentifiers: { [] }, deliveredIdentifiers: { [] }, removePending: { _ in },
            removeDelivered: { _ in }, add: { _ in })
        let coordinator = ScheduleNotificationCoordinator(client: failingClient)
        do { _ = try await coordinator.requestPermission(); XCTFail("권한 요청 오류를 전달해야 합니다") }
        catch { }
        do { _ = try await coordinator.requestPermission(); XCTFail("재요청 오류를 전달해야 합니다") }
        catch { }
        let report = await coordinator.enqueue([]).value
        XCTAssertEqual(report.authorization, .notDetermined)
        XCTAssertFalse(report.failed)
    }
    @MainActor func testDeniedAndDemoFailure() async {
        let item = Schedule(title: "회의", start: Date().addingTimeInterval(500), end: Date().addingTimeInterval(600), isNotificationEnabled: true)
        let denied = ScheduleNotificationCoordinator(client: .demo(authorization: .denied))
        let deniedReport = await denied.enqueue([item]).value
        XCTAssertEqual(deniedReport.scheduledCount, 0)
        let failure = ScheduleNotificationCoordinator(client: .demo(failsScheduling: true))
        let failureReport = await failure.enqueue([item]).value
        XCTAssertTrue(failureReport.failed)
    }
}
