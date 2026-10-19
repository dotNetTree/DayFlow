import SwiftUI
import UserNotifications

@main
struct DayFlowApp: App {
    private let foregroundDelegate = ForegroundNotificationDelegate()
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if !arguments.contains("--demo") && !arguments.contains("--error-demo") {
            UNUserNotificationCenter.current().delegate = foregroundDelegate
        }
    }
    var body: some Scene { WindowGroup { ScheduleListView() } }
}

extension ScheduleStore {
    static func makeAppStore() -> ScheduleStore {
        let arguments = ProcessInfo.processInfo.arguments
        let demo = arguments.contains("--demo")
        let errorDemo = arguments.contains("--error-demo")
        let client: ScheduleNotificationClient
        if demo || errorDemo {
            let status: NotificationAuthorization = arguments.contains("--notification-denied") ? .denied : .authorized
            client = .demo(authorization: status, failsScheduling: arguments.contains("--notification-failure"))
        } else { client = .live() }
        return ScheduleStore(
            repository: ScheduleRepository(url: URL.applicationSupportDirectory.appending(path: "DayFlow/schedules.json")),
            notificationClient: client, demo: demo, errorDemo: errorDemo,
            demoStart: demo && arguments.contains("--notification-qa") ? Date().addingTimeInterval(3600) : nil
        )
    }
}
