import UIKit
import UserNotifications

/// iPhone からの知らせのうち、SwiftUI だけでは受け取れないものを受け取る。お知らせのことと、起動の準備ができたときの設定。
///
/// - 起動の準備ができた：画面の上の題名を丸い字体にする（段階 F）。
/// - お知らせを押された（R-46）：`NotificationTapRelay` に伝え、画面が「健診予定」を開く。
/// - アプリを開いている最中に、お知らせの時刻になった：画面の上にも出す（出さないと、気づかないため）。
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // お知らせを押されて起動したときにも受け取れるよう、起動の終わりまでに受け取り手を決めておく。
        UNUserNotificationCenter.current().delegate = self
        // 画面の上の題名を丸い字体にする。画面ができる前の、ここで決める。
        // App の init で決めると、UIKit の準備の前に触ることになり、アプリの強調の色（AccentColor）が読み込まれず、
        // ダークモードでボタンが iPhone 標準の青になった（段階 F の画面の確認で見つかった）。
        AppFonts.applyToNavigationBars()
        return true
    }

    // iPhone は、この 2 つを画面のスレッドで呼び、終わりの合図（completionHandler）も画面のスレッドで受け取る決まり。
    // `async` の書き方にすると、合図が別のスレッドから返り、「Call must be made on main thread」で止まる（段階 C の確認で見つかった）。
    // そこで、合図はその場ですぐ返し、画面に伝える分だけを画面のスレッドに頼む。

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 知らせの中身はスレッドをまたいで渡せないので、名前（文字）だけを取り出して渡す。
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            NotificationTapRelay.shared.receive(identifier: identifier)
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
