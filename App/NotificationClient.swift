import Foundation
import UserNotifications

extension ScheduleNotificationClient {
    static func live() -> Self {
        Self(
            authorization: { await notificationAuthorization() },
            requestAuthorization: {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                return await notificationAuthorization()
            },
            pendingIdentifiers: { await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier) },
            deliveredIdentifiers: { await UNUserNotificationCenter.current().deliveredNotifications().map { $0.request.identifier } },
            removePending: { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0) },
            removeDelivered: { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0) },
            add: { item in
                guard item.date > Date() else { throw NotificationDeliveryError.startAlreadyPassed }
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.sound = .default
                // UTC 성분과 UTC 달력을 함께 전달하여 시간대가 바뀌어도 같은 절대 시각을 유지합니다.
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date(timeIntervalSince1970: ceil(item.date.timeIntervalSince1970)))
                components.calendar = calendar
                components.timeZone = calendar.timeZone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
            }
        )
    }
}

private func notificationAuthorization() async -> NotificationAuthorization {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .authorized: return .authorized
    case .provisional: return .provisional
    case .ephemeral: return .ephemeral
    @unknown default: return .unknown
    }
}

// 앱에서 강하게 보관하고 앱 시작 시 center.delegate에 연결합니다.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

private enum NotificationDeliveryError: Error { case startAlreadyPassed }
