import Foundation

/// 予約したいお知らせ 1 件。
nonisolated struct PlannedReminder: Equatable, Sendable {
    /// お知らせの名前。届く日時を入れるので、日時が変われば名前も変わる。
    let identifier: String
    /// 届く日時。
    let fireDate: Date
    /// 届く文（R-43）。
    let body: String
}

/// 次の健診のお知らせを考えるのに要る値。
nonisolated struct ReminderInput: Equatable, Sendable {
    let checkupDay: CalendarDay
    let slot: ReminderTimeRule.Slot
    let isOn: Bool
}

/// 突き合わせた結果、やること。
nonisolated struct ReminderActions: Equatable, Sendable {
    /// 取り消すお知らせの名前。
    let toCancel: [String]
    /// 新しく予約するお知らせ。予約しなくてよければ `nil`。
    let toSchedule: PlannedReminder?
}

/// 次の健診のお知らせの決まり（要件定義 v0.4 の 5.4、7 章の S-05・S-06）。画面や通知の仕組みから切り離して、テストで確かめる。
///
/// 「次の健診」から“あるべきお知らせ”を決め、予約中のお知らせと突き合わせて、足りなければ予約し、余分なら取り消す。
nonisolated enum ReminderPlan {
    /// このアプリの、次の健診のお知らせの名前の頭。ほかのお知らせと区別する。
    static let identifierPrefix = "next-checkup-reminder-"

    /// 開発用の「1 分後に試しのお知らせ」の名前。頭を `identifierPrefix` と違えておき、突き合わせで取り消されないようにする。
    static let testIdentifier = "next-checkup-test-reminder"

    /// 押されたら「次の健診」を開くお知らせか（R-46）。試しのお知らせも、本物と同じに扱う。
    static func opensNextCheckup(identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix) || identifier == testIdentifier
    }

    /// 届く文（R-43）。ロック画面にも出るので、質問の中身や健康のことは書かない。
    static let body = "明日は健診の日です。聞きたいことを確かめておきましょう"

    /// あるべきお知らせ。お知らせがオフ・通知の許可がない・届く時刻がもう過ぎた（遅れて届かせない、R-41）ときは `nil`。
    static func plannedReminder(input: ReminderInput?, isAuthorized: Bool, now: Date) -> PlannedReminder? {
        guard let input, input.isOn, isAuthorized else {
            return nil
        }
        let fireDate = ReminderTimeRule.fireDate(for: input.checkupDay, at: input.slot)
        guard fireDate > now else {
            return nil
        }
        return PlannedReminder(identifier: identifier(for: fireDate), fireDate: fireDate, body: body)
    }

    /// お知らせの名前。例：「next-checkup-reminder-202611072100」（日本時間の年月日と時分）。
    static func identifier(for fireDate: Date) -> String {
        let components = Calendar.japan.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let stamp = String(
            format: "%04ld%02ld%02ld%02ld%02ld",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0
        )
        return identifierPrefix + stamp
    }

    /// あるべきお知らせと、予約中のお知らせの名前を突き合わせる。
    ///
    /// このアプリのお知らせ（名前の頭が `identifierPrefix`）のうち、あるべきもの以外はすべて取り消す。
    /// あるべきものが予約中になければ予約する。名前に日時が入っているので、日時が変われば古いものは取り消される。
    static func actions(desired: PlannedReminder?, pendingIdentifiers: [String]) -> ReminderActions {
        let ours = pendingIdentifiers.filter { $0.hasPrefix(identifierPrefix) }
        let toCancel = ours.filter { $0 != desired?.identifier }.sorted()
        let alreadyPending = desired.map { ours.contains($0.identifier) } ?? false
        return ReminderActions(toCancel: toCancel, toSchedule: alreadyPending ? nil : desired)
    }
}
