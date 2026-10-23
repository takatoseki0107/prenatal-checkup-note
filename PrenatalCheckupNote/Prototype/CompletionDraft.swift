import Foundation

/// 健診の完了で、記録ごとに選ぶ扱い。要件定義 11章#9。
nonisolated enum CompletionChoice: CaseIterable, Hashable, Sendable {
    case answered
    case carriedOver
    case withdrawn

    var title: String {
        switch self {
        case .answered: "回答済み"
        case .carriedOver: "持ち越し"
        case .withdrawn: "取り下げ"
        }
    }
}

/// 健診の完了で選ぶ扱いと行先の仮入力。要件定義 11章「完了確認の仮入力」。
///
/// 最終確定（「完了する」）までは画面の上だけに持ち、保存しない。
/// 戻る・途中退出ではこの値ごと捨てるため、保存済みのデータは変わらない（14章 P-01）。
nonisolated struct CompletionDraft: Hashable, Sendable {
    /// 確認記録のID → 選んだ扱い。まだ選んでいない記録は入っていない。
    private(set) var choices: [UUID: CompletionChoice] = [:]
    /// 確認記録のID → 持ち越し先の健診のID。入っていなければ「未割り当て」（既定）。
    private(set) var destinations: [UUID: UUID] = [:]

    /// 保存済みの状態から、最初の仮入力を作る。
    ///
    /// 診察中に記録した回答済み・持ち越しは、その扱いを選んだ状態から始める。未確認はまだ選んでいない状態にする。
    /// 取り下げ済みの記録は選び直せないため、仮入力に含めない（14章 C-15）。
    init(checks: [PrototypeCheck]) {
        for check in checks {
            switch check.status {
            case .answered: choices[check.id] = .answered
            case .carriedOver: choices[check.id] = .carriedOver
            case .unconfirmed, .withdrawn: break
            }
        }
    }

    func choice(for checkID: UUID) -> CompletionChoice? {
        choices[checkID]
    }

    /// 扱いを選ぶ。持ち越し以外を選んだら、選んでいた行先は消す。
    mutating func setChoice(_ choice: CompletionChoice, for checkID: UUID) {
        choices[checkID] = choice
        if choice != .carriedOver {
            destinations[checkID] = nil
        }
    }

    /// 持ち越し先。`nil` は未割り当て。
    func destination(for checkID: UUID) -> UUID? {
        destinations[checkID]
    }

    /// 持ち越し先を選ぶ。`nil` を渡すと未割り当てに戻す。
    mutating func setDestination(_ appointmentID: UUID?, for checkIDs: [UUID]) {
        for checkID in checkIDs {
            destinations[checkID] = appointmentID
        }
    }

    /// 扱いをまだ選んでいない記録の数。取り下げ済みの記録は数えない。
    func unselectedCount(in checks: [PrototypeCheck]) -> Int {
        checks.filter { $0.status != .withdrawn && choices[$0.id] == nil }.count
    }
}
