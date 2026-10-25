import Foundation
import UserNotifications

/// 通知の許可の状態（R-44）。
nonisolated enum ReminderAuthorization: Equatable, Sendable {
    /// まだ聞いていない。
    case notDetermined
    /// 許可されていない（設定アプリで許可できる）。
    case denied
    /// 許可されている。
    case authorized
}

/// お知らせの予約に失敗した。
nonisolated struct ReminderScheduleError: Error, Equatable {}

/// iPhone の通知の仕組みの窓口。テストでは偽物に差し替える（S-08）。
protocol ReminderCenter: AnyObject {
    func authorizationStatus() async -> ReminderAuthorization
    /// 通知の許可を聞く。許可されたら `true`。
    func requestAuthorization() async -> Bool
    /// 予約中のお知らせの名前。
    func pendingIdentifiers() async -> [String]
    func schedule(_ reminder: PlannedReminder) async throws
    /// 取り消す。iPhone の仕組みは失敗を返さないので、取り消せたかは `pendingIdentifiers()` を取り直して確かめる（S-06）。
    func cancel(identifiers: [String])
}

/// 本当の通知の仕組み（`UNUserNotificationCenter`）を使う窓口。
final class SystemReminderCenter: ReminderCenter {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func schedule(_ reminder: PlannedReminder) async throws {
        #if DEBUG
        if DeveloperSettings.shared.failsReminderScheduling {
            throw ReminderScheduleError()
        }
        #endif
        let content = UNMutableNotificationContent()
        content.body = reminder.body
        content.sound = .default

        // 届く日時は日本時間で決める（R-90）。
        var components = Calendar.japan.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        components.calendar = Calendar.japan
        components.timeZone = Calendar.japan.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        try await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
    }

    func cancel(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
