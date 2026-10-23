#if DEBUG
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// 無料の個人チームで実機に入れたときに、段階1・2で使う機能が動くかを確かめる開発用の画面。
///
/// 確かめること：データの保存（SwiftData）、ローカル通知、共有シートと印刷（TV-04）。
/// 開発用ビルドだけに含め、リリースビルドには入れない。
/// 本番の機能では、データの変更をServiceにまとめる方針。この画面は確認用のため、Viewから直接保存する。
struct DeviceCheckView: View {
    var body: some View {
        List {
            DataStoreCheckSection()
            NotificationCheckSection()
            ShareCheckSection()
        }
        .navigationTitle("実機での動作確認")
        .modelContainer(DeviceCheckStore.container)
    }
}

// MARK: - 1. データの保存

/// 確認用の記録。本番のデータとは別の保存場所に保存する。
@Model
final class DeviceCheckEntry {
    var createdAt: Date

    init(createdAt: Date) {
        self.createdAt = createdAt
    }
}

private enum DeviceCheckStore {
    /// 本番のデータと混ざらないよう、名前を付けた別の保存場所（DeviceCheck.store）を使う。iCloudとは同期しない。
    static let container: ModelContainer = {
        let configuration = ModelConfiguration("DeviceCheck", cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: DeviceCheckEntry.self, configurations: configuration)
        } catch {
            fatalError("確認用の保存場所を作れませんでした：\(error)")
        }
    }()
}

private struct DataStoreCheckSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DeviceCheckEntry.createdAt, order: .reverse) private var entries: [DeviceCheckEntry]
    @State private var errorMessage: String?

    var body: some View {
        Section {
            LabeledContent("保存されている件数", value: "\(entries.count)件")
            if let latest = entries.first {
                LabeledContent("最後に追加した日時") {
                    Text(latest.createdAt, format: .dateTime.month().day().hour().minute().second())
                }
            }
            Button("記録を1件追加して保存する") {
                addEntry()
            }
            Button("確認用の記録をすべて消す", role: .destructive) {
                deleteAllEntries()
            }
            .disabled(entries.isEmpty)
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("1. データの保存（SwiftData）")
        } footer: {
            Text("追加したら、アプリを完全に終了してから開き直します。件数と日時が残っていれば、保存できています。")
        }
    }

    private func addEntry() {
        modelContext.insert(DeviceCheckEntry(createdAt: .now))
        save()
    }

    private func deleteAllEntries() {
        for entry in entries {
            modelContext.delete(entry)
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "保存に失敗しました：\(error.localizedDescription)"
        }
    }
}

// MARK: - 2. ローカル通知

private struct NotificationCheckSection: View {
    @State private var authorizationStatus: UNAuthorizationStatus?
    @State private var message: String?

    var body: some View {
        Section {
            LabeledContent("通知の許可", value: authorizationText)
            Button("通知の許可を求める") {
                Task { await requestAuthorization() }
            }
            Button("10秒後に確認用の通知を予約する") {
                Task { await scheduleTestNotification() }
            }
            if let message {
                Text(message)
            }
        } header: {
            Text("2. ローカル通知")
        } footer: {
            Text("予約したら、すぐにホーム画面に戻って待ちます。アプリを開いたままだと、通知は画面に出ません。")
        }
        .task {
            await refreshAuthorizationStatus()
        }
    }

    private var authorizationText: String {
        guard let authorizationStatus else { return "確認中" }
        switch authorizationStatus {
        case .notDetermined: return "まだ聞いていない"
        case .denied: return "許可されていない"
        case .authorized: return "許可されている"
        case .provisional: return "仮の許可"
        case .ephemeral: return "一時的な許可"
        @unknown default: return "不明"
        }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            message = granted ? "通知が許可されました。" : "通知は許可されませんでした。"
        } catch {
            message = "許可を求められませんでした：\(error.localizedDescription)"
        }
        await refreshAuthorizationStatus()
    }

    private func scheduleTestNotification() async {
        guard authorizationStatus == .authorized else {
            message = "先に通知を許可してください。"
            return
        }

        // 要件定義のとおり、通知の文に健康に関する情報を含めない。
        let content = UNMutableNotificationContent()
        content.title = "動作確認"
        content.body = "確認用の通知です。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "device-check", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            message = "10秒後に通知を予約しました。ホーム画面に戻って待ってください。"
        } catch {
            message = "通知を予約できませんでした：\(error.localizedDescription)"
        }
    }
}

// MARK: - 3. 共有シートと印刷（TV-04）

private struct ShareCheckSection: View {
    var body: some View {
        Section {
            Text(DeviceCheckSample.questionList)
                .font(.callout)
            ShareLink(item: DeviceCheckSample.questionList) {
                Label("A. 共有シートを開く（標準）", systemImage: "square.and.arrow.up")
            }
            Button {
                presentPrintPanel()
            } label: {
                Label("B. 印刷の画面を直接開く", systemImage: "printer")
            }
            .disabled(!UIPrintInteractionController.isPrintingAvailable)
            Button {
                presentShareSheetWithPrint()
            } label: {
                Label("C. 共有シートを開く（印刷つき）", systemImage: "square.and.arrow.up.on.square")
            }
        } header: {
            Text("3. 共有シートと印刷（TV-04）")
        } footer: {
            Text("A・Cでは共有シートに「プリント」が出るかを、B・Cでは印刷のプレビューで文字が切れずに表示されるかを見ます。プリンタがなくても、プレビューまでは確認できます。")
        }
    }

    /// 共有シートに、文章と一緒に印刷用の項目も渡す。1つのボタンで、共有と印刷のどちらも選べるかを確かめる。
    private func presentShareSheetWithPrint() {
        let formatter = UISimpleTextPrintFormatter(text: DeviceCheckSample.questionList)
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)

        let activityController = UIActivityViewController(
            activityItems: [DeviceCheckSample.questionList, formatter],
            applicationActivities: nil
        )
        topViewController()?.present(activityController, animated: true)
    }

    /// いま一番手前に表示されている画面を探す。SwiftUIの画面の上に、UIKitの共有シートを重ねて表示するために使う。
    private func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = windowScene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// 共有シートだけでは印刷できなかった場合に備えて、専用の印刷処理で印刷の画面を開けるかも比べる。
    private func presentPrintPanel() {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "健診で聞くこと"

        let formatter = UISimpleTextPrintFormatter(text: DeviceCheckSample.questionList)
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)

        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printFormatter = formatter
        _ = controller.present(animated: true, completionHandler: nil)
    }
}

/// 共有と印刷の確認に使う文章。内容はすべて架空。
/// ワイヤー（共有プレビュー）の例文をもとに、最後の質問を長くして折り返しも確かめる。
private enum DeviceCheckSample {
    static let questionList = """
        11月5日（木）10:30 の健診で聞くこと

        ・腰の痛みについて相談する
        ・仕事を続ける上で気をつけることを聞く
        ・次回の検査の内容を確認する
        ・里帰り出産の転院手続きの時期と、紹介状をいつまでに用意してもらえばよいかを聞く

        健診メモ
        持ち物：母子健康手帳、保険証
        """
}

#Preview {
    NavigationStack {
        DeviceCheckView()
    }
}
#endif
