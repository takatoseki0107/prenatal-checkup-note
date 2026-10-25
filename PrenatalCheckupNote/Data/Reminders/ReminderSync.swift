import Foundation
import Observation

/// 次の健診のお知らせを、データに合わせる（要件定義 v0.4 の 7 章 S-05・S-06・S-09）。
///
/// データを保存したあと・アプリを開いたとき・前面に戻ったときに `requestSync()` を呼ぶ。
/// そのたびに「次の健診」から“あるべきお知らせ”を決め、予約中のお知らせと突き合わせて直す。
/// 予約や取り消しに一度失敗しても、次に合わせるときに直る。
///
/// 処理は 1 つずつ順に行う。処理中にまた呼ばれたら、終わってから最新のデータでもう一度合わせる。
/// 予定の変更と削除を続けて行っても、古い予約が遅れて終わって戻ることがないようにするため。
@Observable
final class ReminderSync {
    /// 通知の許可の状態。画面は、許可がないときスイッチをオンに見せない（R-44）。
    private(set) var authorization: ReminderAuthorization = .notDetermined
    /// 直近の予約に失敗したか。画面のカードで「お知らせを予約できませんでした」と出す（R-45）。
    private(set) var lastScheduleFailed = false

    @ObservationIgnored private let center: ReminderCenter
    @ObservationIgnored private let now: () -> Date
    /// いまの「次の健診」から、お知らせを考えるのに要る値を取り出す。予定がなければ `nil`。
    @ObservationIgnored private let currentInput: () -> ReminderInput?
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var needsRerun = false

    init(center: ReminderCenter, now: @escaping () -> Date = { .now }, currentInput: @escaping () -> ReminderInput?) {
        self.center = center
        self.now = now
        self.currentInput = currentInput
    }

    /// データに合わせるよう頼む。処理中なら、終わってからもう一度合わせる。
    func requestSync() {
        needsRerun = true
        guard running == nil else {
            return
        }
        running = Task { [weak self] in
            await self?.runUntilSettled()
        }
    }

    /// 頼まれた処理がすべて終わるまで待つ。テストで使う。
    func waitUntilIdle() async {
        while let task = running {
            await task.value
        }
    }

    /// 通知の許可を聞く（初めてお知らせをオンにしたとき。R-44）。聞いたあと、データに合わせ直す。
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = await center.requestAuthorization()
        authorization = await center.authorizationStatus()
        requestSync()
        return granted
    }

    private func runUntilSettled() async {
        while needsRerun {
            needsRerun = false
            await syncOnce()
        }
        running = nil
    }

    private func syncOnce() async {
        authorization = await center.authorizationStatus()
        let desired = ReminderPlan.plannedReminder(
            input: currentInput(),
            isAuthorized: authorization == .authorized,
            now: now()
        )
        // 取り消しが本当に済んだかは、毎回一覧を取り直して確かめる（S-06）。
        let pending = await center.pendingIdentifiers()
        let actions = ReminderPlan.actions(desired: desired, pendingIdentifiers: pending)
        if !actions.toCancel.isEmpty {
            center.cancel(identifiers: actions.toCancel)
        }
        guard let reminder = actions.toSchedule else {
            lastScheduleFailed = false
            return
        }
        do {
            try await center.schedule(reminder)
            lastScheduleFailed = false
        } catch {
            lastScheduleFailed = true
        }
    }
}
