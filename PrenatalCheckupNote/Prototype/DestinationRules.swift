import Foundation

/// 持ち越し先にできない理由。
nonisolated enum DestinationUnavailableReason: Hashable, Sendable {
    /// その健診に、この質問の記録（取り下げ済み以外）がすでにある。
    case alreadyHasQuestion
    /// 予定の日時を過ぎていて、診察も始めていない。
    case pastAndNotStarted

    /// 「選べない健診」に添える説明。
    var explanation: String {
        switch self {
        case .alreadyHasQuestion: "この質問がすでに割り当てられています"
        case .pastAndNotStarted: "日時を過ぎています（日時を変更すると選べます）"
        }
    }

    /// まとめて適用できなかったときの説明。
    var shortExplanation: String {
        switch self {
        case .alreadyHasQuestion: "すでに同じ質問があります"
        case .pastAndNotStarted: "日時を過ぎています"
        }
    }
}

/// 持ち越し・割り当ての行先の候補の規則。要件定義 11章「持ち越し・割り当ての行先の候補」。
///
/// 試作用の版。段階2では同じ規則を保存モデルとServiceで作り、#2の割り当てと#9bの持ち越しの両方で使う。
nonisolated enum DestinationRules {
    /// 行先の候補。
    nonisolated struct Options: Hashable, Sendable {
        /// 選べる健診。日時の近い順。
        var selectable: [PrototypeAppointment]
        /// 選べない健診と、その理由。日時の近い順。
        var unavailable: [Unavailable]
    }

    nonisolated struct Unavailable: Hashable, Sendable {
        let appointment: PrototypeAppointment
        let reason: DestinationUnavailableReason
    }

    /// 質問の行先の候補を作る。
    ///
    /// 予定の健診だけを対象にし、いま完了しようとしている健診と、完了・キャンセルの健診は表示しない。
    /// - Parameters:
    ///   - questionID: 行先を選ぶ質問。
    ///   - currentAppointmentID: いま完了しようとしている健診。
    ///   - data: 試作用データ。
    ///   - now: 現在日時。日時を過ぎたかの判定に使う。
    static func options(
        for questionID: UUID,
        completing currentAppointmentID: UUID,
        in data: PrototypeData,
        now: Date
    ) -> Options {
        var options = Options(selectable: [], unavailable: [])
        let targets = data.appointments
            .filter { $0.status == .scheduled && $0.id != currentAppointmentID }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        for appointment in targets {
            if let reason = reasonUnavailable(appointment, for: questionID, now: now) {
                options.unavailable.append(Unavailable(appointment: appointment, reason: reason))
            } else {
                options.selectable.append(appointment)
            }
        }
        return options
    }

    /// 健診を、質問の行先にできない理由。行先にできるなら `nil`。
    ///
    /// その質問の取り下げ済みの記録だけを持つ健診は、行先にできる（選ばれたらその記録を未確認に戻す。11章#2）。
    static func reasonUnavailable(
        _ appointment: PrototypeAppointment,
        for questionID: UUID,
        now: Date
    ) -> DestinationUnavailableReason? {
        if appointment.checks.contains(where: { $0.questionID == questionID && $0.status != .withdrawn }) {
            return .alreadyHasQuestion
        }
        if appointment.scheduledAt < now && appointment.examStartedAt == nil {
            return .pastAndNotStarted
        }
        return nil
    }
}
