#if DEBUG
import SwiftUI
import UserNotifications

/// 設定の中の、開発用の欄。開発用ビルドだけに含め、リリースビルドには入れない。
///
/// 保存の失敗の切り替え、試しのお知らせ、実機での動作確認への入口をまとめる。サンプルデータは段階 D でここに置く。
/// 段階 A の確認用の画面は、本番の健診後メモのシートができた B3 で外した。
struct DeveloperSection: View {
    @Environment(NoteStore.self) private var store
    /// 試しのお知らせを予約したあとの案内。
    @State private var testReminderMessage: String?
    @State private var isShowingPermissionAlert = false

    var body: some View {
        @Bindable var settings = DeveloperSettings.shared

        Section {
            Toggle("サンプルデータを表示する", isOn: $settings.showsSampleData)
            Toggle("保存を失敗させる", isOn: $settings.failsSaving)
            Toggle("お知らせの予約を失敗させる", isOn: $settings.failsReminderScheduling)
            // 前日の夜まで待たずに、お知らせが届くこと・押したときの動き（R-46）を確かめる。
            Button("1 分後に試しのお知らせ") {
                Task {
                    await scheduleTestReminder()
                }
            }
            if let testReminderMessage {
                Text(testReminderMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            NavigationLink("実機での動作確認") {
                DeviceCheckView()
            }
        } header: {
            Text("開発用")
        } footer: {
            Text("「サンプルデータを表示する」をオンにすると、本当のデータとは別の場所に例のデータを入れて表示します。本当のデータとお知らせはそのままで、オフにすると戻ります。「保存を失敗させる」をオンにすると、保存がすべて失敗します。失敗しても、入力した内容や保存済みのデータが消えないことを確かめるために使います。「お知らせの予約を失敗させる」をオンにすると、お知らせの予約が失敗します。どれも、アプリを終了するとオフに戻ります。「1 分後に試しのお知らせ」は、本物と同じ文のお知らせを 1 分後に 1 回だけ届けます。次の健診のお知らせには影響しません。")
        }
        .notificationPermissionAlert(isPresented: $isShowingPermissionAlert)
    }

    /// 本物と同じ文のお知らせを、1 分後に 1 回だけ届ける。
    private func scheduleTestReminder() async {
        guard await ensureReminderPermission(store.reminders) else {
            isShowingPermissionAlert = true
            return
        }
        let content = UNMutableNotificationContent()
        content.body = ReminderPlan.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(identifier: ReminderPlan.testIdentifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            testReminderMessage = "1 分後に届きます。ホーム画面に戻って待ち、届いたら押してください。"
        } catch {
            testReminderMessage = "試しのお知らせを予約できませんでした。"
        }
    }
}
#endif
