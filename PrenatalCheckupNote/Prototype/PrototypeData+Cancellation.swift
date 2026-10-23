import Foundation

// 健診のキャンセルで、試作用データを書き換える処理。要件定義 11章#15・「健診のキャンセル」。
// 状態遷移の正式な規則とトランザクションは段階2のServiceで作る。ここでは画面を動かすのに必要な分だけを、簡略に行う。

/// キャンセルの確認（ワイヤー11）に出す内容。
nonisolated struct CancellationSummary: Hashable, Sendable {
    /// 未割り当てに戻る質問の数（未確認の記録の数）。
    let returningQuestionCount: Int
    /// 削除される記録のうち、回答メモがある記録の数。
    ///
    /// 保存済みのメモに加えて、保存に失敗して残っている入力（未保存のメモ）がある記録も数える。
    /// キャンセルすると、その入力も一緒に消えるため。
    let deletedMemoCount: Int
}

/// 「キャンセル」を押したときに、どう扱うか。11章「健診のキャンセル」の表。
nonisolated enum CancellationEligibility: Hashable, Sendable {
    /// キャンセルできる。確認ダイアログを出す（ワイヤー11）。
    case cancellable(CancellationSummary)
    /// 回答済み・持ち越しの記録があるため、そのままキャンセルしない。記録の一覧と選択肢を出す（ワイヤー10）。
    /// 記録は並び順のとおり。
    case hasRecordedChecks(answered: [PrototypeCheck], carriedOver: [PrototypeCheck])
    /// 予定の健診ではない（完了・キャンセル済み）。キャンセルは表示しない。
    case notScheduled
}

extension PrototypeData {
    /// 健診をキャンセルできるかを確かめる。
    nonisolated func cancellationEligibility(of appointmentID: UUID) -> CancellationEligibility {
        guard let appointment = appointment(id: appointmentID), appointment.status == .scheduled else {
            return .notScheduled
        }

        let answered = appointment.checks.filter { $0.status == .answered }
        let carriedOver = appointment.checks.filter { $0.status == .carriedOver }
        // 回答を入力したことを、実際に受診したこととはみなさない。キャンセルせず、案内する。
        guard answered.isEmpty && carriedOver.isEmpty else {
            return .hasRecordedChecks(answered: answered, carriedOver: carriedOver)
        }

        let memoCount = appointment.checks.filter { check in
            let unsaved = unsavedMemos[check.id] ?? ""
            return !check.answerMemo.isEmpty || !unsaved.isEmpty
        }.count
        return .cancellable(
            CancellationSummary(
                returningQuestionCount: appointment.checks.filter { $0.status == .unconfirmed }.count,
                deletedMemoCount: memoCount
            )
        )
    }

    /// 健診をキャンセルする（11章#15）。キャンセルできないときは何も変えない。
    ///
    /// - 未確認・取り下げ済みの記録をすべて削除する。未確認だった質問は未割り当てに戻り、取り下げの質問はそのまま。
    /// - 削除した記録の未保存のメモも消す。
    /// - ほかの健診の持ち越しの記録が、この健診を行先にしていたら、行先を外す（行先の記録を削除したため）。
    /// - Returns: キャンセルしたら `true`。
    @discardableResult
    nonisolated mutating func cancel(_ appointmentID: UUID) -> Bool {
        guard case .cancellable = cancellationEligibility(of: appointmentID),
              let index = appointments.firstIndex(where: { $0.id == appointmentID })
        else { return false }

        for check in appointments[index].checks {
            unsavedMemos[check.id] = nil
        }
        appointments[index].checks = []
        appointments[index].status = .cancelled

        for appointmentIndex in appointments.indices {
            for checkIndex in appointments[appointmentIndex].checks.indices
            where appointments[appointmentIndex].checks[checkIndex].carriedOverToAppointmentID == appointmentID {
                appointments[appointmentIndex].checks[checkIndex].carriedOverToAppointmentID = nil
            }
        }
        return true
    }
}
