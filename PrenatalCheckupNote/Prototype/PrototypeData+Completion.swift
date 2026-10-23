import Foundation

// 健診の完了（最終確定）で、仮入力をまとめて試作用データに反映する処理。要件定義 11章#9。
// 状態遷移の正式な規則とトランザクションは段階2のServiceで作る。ここでは画面を動かすのに必要な分だけを、簡略に行う。

/// 健診の完了を、保存の前に止める理由。
nonisolated enum CompletionProblem: Hashable, Sendable {
    /// 健診が見つからない、または予定の健診ではない。
    case appointmentNotScheduled
    /// 扱いを選んでいない記録がある。
    case unselected(count: Int)
    /// 選んだ持ち越し先が、いまは行先にできない。
    case destinationUnavailable(checkID: UUID)

    /// 画面に出す説明。
    var message: String {
        switch self {
        case .appointmentNotScheduled:
            "この健診は、もう完了できません。"
        case .unselected(let count):
            "扱いが未選択の質問が\(count)件あります。"
        case .destinationUnavailable:
            "選んだ持ち越し先の健診が、いまは選べません。持ち越し先を選び直してください。"
        }
    }
}

/// 「完了する」を押した結果。
nonisolated enum CompletionOutcome: Hashable, Sendable {
    /// 完了した。
    case completed
    /// 未保存のメモがあるため、完了していない。何も変えていない（14章 M-10）。
    case hasUnsavedMemos
    /// 保存の前に止めた。何も変えていない。
    case rejected([CompletionProblem])
    /// 保存に失敗した。何も変えていない（14章 P-02・C-12）。
    case saveFailed
}

/// 内容の確認に並べる、記録1件分の扱い。
nonisolated struct CompletionSummaryItem: Identifiable, Hashable, Sendable {
    /// 健診の中での番号（1から）。
    let number: Int
    let checkID: UUID
    let questionText: String
    let choice: CompletionChoice
    /// 持ち越し先の健診。持ち越しで未割り当てなら `nil`。
    let destinationID: UUID?
    /// 完了の前から取り下げ済みだった記録か。扱いは変わらない。
    let wasAlreadyWithdrawn: Bool

    var id: UUID { checkID }
}

extension CompletionDraft {
    /// 内容の確認に並べる扱いの一覧。記録の並び順のとおり。扱いを選んでいない記録は含めない。
    nonisolated func summaryItems(for checks: [PrototypeCheck]) -> [CompletionSummaryItem] {
        checks.enumerated().compactMap { offset, check in
            let wasAlreadyWithdrawn = check.status == .withdrawn
            let selected: CompletionChoice? = wasAlreadyWithdrawn ? .withdrawn : self.choice(for: check.id)
            guard let selected else { return nil }
            return CompletionSummaryItem(
                number: offset + 1,
                checkID: check.id,
                questionText: check.questionText,
                choice: selected,
                destinationID: selected == .carriedOver ? self.destination(for: check.id) : nil,
                wasAlreadyWithdrawn: wasAlreadyWithdrawn
            )
        }
    }
}

extension PrototypeData {
    /// 健診の記録のうち、保存に失敗したメモが残っている記録のID。記録の並び順のとおり。
    nonisolated func unsavedMemoCheckIDs(in appointmentID: UUID) -> [UUID] {
        guard let appointment = appointment(id: appointmentID) else { return [] }
        return appointment.checks.map(\.id).filter { unsavedMemos[$0] != nil }
    }

    /// 健診を完了する前に、仮入力で完了できるかを確かめる。完了できるなら空。
    ///
    /// 持ち越し先は、いまのデータで改めて候補の規則に照らす。仮入力を作った後に、行先の健診が変わっていることがあるため。
    nonisolated func completionProblems(of appointmentID: UUID, with draft: CompletionDraft, now: Date) -> [CompletionProblem] {
        guard let appointment = appointment(id: appointmentID), appointment.status == .scheduled else {
            return [.appointmentNotScheduled]
        }

        var problems: [CompletionProblem] = []
        let unselectedCount = draft.unselectedCount(in: appointment.checks)
        if unselectedCount > 0 {
            problems.append(.unselected(count: unselectedCount))
        }

        for check in appointment.checks where check.status != .withdrawn && draft.choice(for: check.id) == .carriedOver {
            // 未割り当ては、いつでも選べる。
            guard let destinationID = draft.destination(for: check.id) else { continue }
            let isAvailable = self.appointment(id: destinationID).map { destination in
                destination.id != appointmentID
                    && destination.status == .scheduled
                    && DestinationRules.reasonUnavailable(destination, for: check.questionID, now: now) == nil
            } ?? false
            if !isAvailable {
                problems.append(.destinationUnavailable(checkID: check.id))
            }
        }
        return problems
    }

    /// 仮入力のとおりに健診を完了する。先に `completionProblems` で確かめてから呼ぶ。
    ///
    /// - 回答済み：記録を回答済みにする（11章#9a）。
    /// - 持ち越し：記録は持ち越しのまま、行先を記録する。行先に健診を選んだら、その健診の末尾に未確認の記録を作る（#9b・#9c）。
    /// - 取り下げ：記録と質問を取り下げにする（#9d）。
    /// - すでに取り下げ済みの記録は変えない（14章 C-15）。
    /// 回答メモは変えない。健診は完了にする。
    nonisolated mutating func complete(_ appointmentID: UUID, with draft: CompletionDraft, now: Date) {
        guard let index = appointments.firstIndex(where: { $0.id == appointmentID }) else { return }

        var carryOvers: [(questionID: UUID, destinationID: UUID)] = []
        var withdrawnQuestionIDs: [UUID] = []

        for checkIndex in appointments[index].checks.indices {
            var check = appointments[index].checks[checkIndex]
            guard check.status != .withdrawn, let choice = draft.choice(for: check.id) else { continue }
            switch choice {
            case .answered:
                check.status = .answered
                check.carriedOverToAppointmentID = nil
            case .carriedOver:
                check.status = .carriedOver
                check.carriedOverToAppointmentID = draft.destination(for: check.id)
                if let destinationID = check.carriedOverToAppointmentID {
                    carryOvers.append((check.questionID, destinationID))
                }
            case .withdrawn:
                check.status = .withdrawn
                check.carriedOverToAppointmentID = nil
                withdrawnQuestionIDs.append(check.questionID)
            }
            appointments[index].checks[checkIndex] = check
        }
        appointments[index].status = .completed

        for questionIndex in questions.indices where withdrawnQuestionIDs.contains(questions[questionIndex].id) {
            questions[questionIndex].withdrawnAt = now
        }
        // 行先の記録は、質問の今の文言で作る（14章 C-10）。
        for carryOver in carryOvers {
            assign(questionIDs: [carryOver.questionID], to: carryOver.destinationID)
        }
    }
}
