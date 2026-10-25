import Foundation

/// 次の健診のカードに出す、お知らせの状態（要件定義 v0.4 の 4 章・5.4）。触れる見本と同じ言葉にする。
nonisolated enum ReminderStatus: Equatable, Sendable {
    /// オフ。
    case off
    /// オンで、前日のその時刻に届く。
    case on(ReminderTimeRule.Slot)
    /// オンだが、その時刻はもう過ぎた（遅れて届かせない、R-41）。
    case passed(ReminderTimeRule.Slot)
    /// オフで、前日の夜がもう過ぎているので、設定できない（R-41）。
    case unavailable
    /// オンにしてあるが、通知が許可されていない。オンに見せない（R-44）。
    case notPermitted

    /// カードの文。
    var text: String {
        switch self {
        case .off:
            "お知らせはオフ"
        case .on(let slot):
            "前日の \(slot) にお知らせ"
        case .passed(let slot):
            "お知らせの時刻（前日の \(slot)）を過ぎました"
        case .unavailable:
            "前日の夜を過ぎたので、お知らせは設定できません"
        case .notPermitted:
            "お知らせはオフ（通知が許可されていません）"
        }
    }

    /// スイッチをオンに見せるか。許可がないときはオンに見せない（R-44）。
    var showsSwitchOn: Bool {
        switch self {
        case .on, .passed:
            true
        case .off, .unavailable, .notPermitted:
            false
        }
    }

    /// スイッチを押せるか。前日の夜が過ぎた日は、オンにできない（R-41）。オンのものをオフにするのはいつでもできる。
    var canToggle: Bool {
        self != .unavailable
    }

    /// いまの状態を決める。
    static func make(input: ReminderInput, authorization: ReminderAuthorization, now: Date) -> ReminderStatus {
        if input.isOn {
            guard authorization == .authorized else {
                return .notPermitted
            }
            let fireDate = ReminderTimeRule.fireDate(for: input.checkupDay, at: input.slot)
            return fireDate > now ? .on(input.slot) : .passed(input.slot)
        }
        let available = ReminderTimeRule.availableSlots(for: input.checkupDay, now: now)
        return available.isEmpty ? .unavailable : .off
    }
}

extension ReminderTimeRule {
    /// 日付を変えて、選んでいた時刻が過ぎたときに出す文（R-42）。
    nonisolated static func movedMessage(from: Slot, to: Slot) -> String {
        "前の時刻（\(from)）はもう過ぎているので、\(to) にしました"
    }

    /// 前日の夜がもう過ぎているときに出す文（R-41）。
    nonisolated static let unavailableMessage = "この日の前日の夜は、もう過ぎています。この日には、お知らせを設定できません。"
}
