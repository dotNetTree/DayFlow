import SwiftUI

@main
struct DayFlowApp: App {
    var body: some Scene { WindowGroup { ScheduleListView() } }
}

@MainActor @Observable
final class ScheduleStore {
    var schedules: [Schedule] = []
    var error: String?
    private let demo = ProcessInfo.processInfo.arguments.contains("--demo")
    private let errorDemo = ProcessInfo.processInfo.arguments.contains("--error-demo")
    private let repository = ScheduleRepository(url: URL.applicationSupportDirectory.appending(path: "DayFlow/schedules.json"))
    init() {
        if demo {
            let now = Date()
            schedules = [Schedule(title: "오늘의 계획 세우기", note: "가장 중요한 일 세 가지", start: now, end: now.addingTimeInterval(1800))]
        } else {
            do { schedules = try repository.load() }
            catch { self.error = "일정을 불러오지 못했습니다. 원본 파일을 보존합니다. \(error.localizedDescription)"; loadFailed = true }
        }
        if errorDemo { error = "오류 데모: 저장 실패를 재현합니다." }
    }
    private var loadFailed = false
    func commit(_ updated: [Schedule]) {
        guard !loadFailed else { error = "불러오기 실패로 저장을 중단했습니다. 앱을 종료하고 저장 파일을 확인해주세요."; return }
        do {
            if errorDemo { throw CocoaError(.fileWriteNoPermission) }
            if !demo { try repository.save(updated) }
            schedules = updated
        } catch { self.error = "저장하지 못했습니다. 변경 전 상태를 유지합니다. \(error.localizedDescription)" }
    }
    @discardableResult
    func upsert(_ item: Schedule) -> Bool {
        guard item.validationMessage == nil else { error = item.validationMessage; return false }
        var updated = schedules
        if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = item }
        else { updated.append(item) }
        error = nil
        commit(updated)
        return error == nil
    }
}
