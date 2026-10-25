import UIKit
import UserNotifications

/// iPhone からの知らせのうち、SwiftUI だけでは受け取れないものを受け取る。いまは、お知らせのことだけ。
///
/// - お知らせを押された（R-46）：`NotificationTapRelay` に伝え、画面が「次の健診」を開く。
/// - アプリを開いている最中に、お知らせの時刻になった：画面の上にも出す（出さないと、気づかないため）。
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // お知らせを押されて起動したときにも受け取れるよう、起動の終わりまでに受け取り手を決めておく。
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // 知らせの中身は別のスレッドから届くことがあるので、名前（文字）だけを取り出してから、画面のスレッドで渡す。
        let identifier = response.notification.request.identifier
        await MainActor.run {
            NotificationTapRelay.shared.receive(identifier: identifier)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
