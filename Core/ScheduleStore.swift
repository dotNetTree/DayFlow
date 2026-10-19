import Foundation
import Observation

@MainActor @Observable
public final class ScheduleStore {
    public private(set) var schedules: [Schedule] = []
    public var error: String?
    public private(set) var authorization: NotificationAuthorization = .notDetermined
    public private(set) var notificationMessage: String?
    public private(set) var isRequestingPermission = false
    public private(set) var isSyncingNotifications = false
    private let repository: ScheduleRepository
    private let coordinator: ScheduleNotificationCoordinator
    private let demo: Bool
    private let errorDemo: Bool
    private var loadFailed = false
    private var syncRevision = 0

    public init(repository: ScheduleRepository, notificationClient: ScheduleNotificationClient, demo: Bool = false, errorDemo: Bool = false, demoStart: Date? = nil) {
        self.repository = repository
        self.coordinator = ScheduleNotificationCoordinator(client: notificationClient)
        self.demo = demo
        self.errorDemo = errorDemo
        if demo {
            let now = demoStart ?? Date()
            schedules = [Schedule(title: "오늘의 계획 세우기", note: "가장 중요한 일 세 가지", start: now, end: now.addingTimeInterval(1800))]
        } else {
            do { schedules = try repository.load() }
            catch { self.error = "일정을 불러오지 못했습니다. 원본 파일을 보존합니다. \(error.localizedDescription)"; loadFailed = true }
        }
        if errorDemo { error = "오류 데모: 저장 실패를 재현합니다." }
    }

    @discardableResult
    public func commit(_ updated: [Schedule]) -> Bool {
        guard !loadFailed else { error = "불러오기 실패로 저장을 중단했습니다. 앱을 종료하고 저장 파일을 확인해주세요."; return false }
        do {
            if errorDemo { throw CocoaError(.fileWriteNoPermission) }
            if !demo { try repository.save(updated) }
            schedules = updated
            error = nil
            syncNotifications()
            return true
        } catch {
            self.error = "저장하지 못했습니다. 변경 전 상태를 유지합니다. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    public func upsert(_ item: Schedule) -> Bool {
        guard item.validationMessage == nil else { error = item.validationMessage; return false }
        var updated = schedules
        if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = item }
        else { updated.append(item) }
        return commit(updated)
    }

    // 앱 활성화와 저장 성공 직후 호출합니다. 권한 요청은 하지 않습니다.
    public func syncNotifications() {
        guard !loadFailed else { return }
        syncRevision += 1
        let revision = syncRevision
        isSyncingNotifications = true
        let task = coordinator.enqueue(schedules)
        Task {
            let report = await task.value
            guard revision == syncRevision else { return }
            authorization = report.authorization
            isSyncingNotifications = false
            if report.failed {
                notificationMessage = "일정은 저장했지만 알림을 예약하지 못했어요. 다시 시도해주세요."
            } else if !report.authorization.allowsScheduling && schedules.contains(where: \.isNotificationEnabled) {
                notificationMessage = report.authorization == .denied ? "알림 권한이 꺼져 있어요. 설정에서 허용해주세요." : "알림 권한을 허용하면 미래 일정의 알림을 예약할 수 있어요."
            } else if report.waitingCount > 0 {
                notificationMessage = "가까운 일정 최대 32개를 우선 예약합니다. \(report.waitingCount)개는 대기 중입니다."
            } else { notificationMessage = nil }
        }
    }

    public func requestNotificationPermission() async {
        guard !isRequestingPermission else { return }
        // 이전 동기화 보고가 권한 요청 결과를 덮어쓰지 않도록 무효화합니다.
        syncRevision += 1
        isSyncingNotifications = false
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        do {
            authorization = try await coordinator.requestPermission()
            // 편집 중인 값이 아니라 저장된 일정만 다시 동기화합니다.
            syncNotifications()
        }
        catch { notificationMessage = "알림 권한 요청에 실패했어요. 토글을 다시 켜 재시도해주세요." }
    }
}
