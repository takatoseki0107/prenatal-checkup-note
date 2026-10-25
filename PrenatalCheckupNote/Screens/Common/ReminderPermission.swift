import SwiftUI
import UIKit

/// お知らせをオンにする前に、通知の許可を確かめる（R-44）。許可されていれば `true`。
///
/// まだ聞いていなければ、ここで iPhone の許可の確認を出す。以前に許可しなかった人には確認は出ず、`false` になる。
func ensureReminderPermission(_ reminders: ReminderSync?) async -> Bool {
    guard let reminders else {
        return false
    }
    if reminders.authorization == .authorized {
        return true
    }
    return await reminders.requestAuthorization()
}

extension View {
    /// 通知が許可されていないときの案内。設定アプリで許可できることを伝える（R-44）。
    func notificationPermissionAlert(isPresented: Binding<Bool>) -> some View {
        modifier(NotificationPermissionAlert(isPresented: isPresented))
    }
}

private struct NotificationPermissionAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("通知が許可されていません", isPresented: $isPresented) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("お知らせを受け取るには、設定アプリでこのアプリの通知を許可してください。")
        }
    }
}
