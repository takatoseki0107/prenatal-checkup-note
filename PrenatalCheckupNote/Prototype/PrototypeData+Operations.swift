import Foundation

// 段階1の画面の操作で、試作用データを書き換える処理。
// 状態遷移の正式な規則（11章）は段階2のServiceで作る。ここでは画面を動かすのに必要な分だけを、簡略に行う。

extension PrototypeAppointment {
    /// 取り下げ以外の確認記録。健診モードで聞く質問。並び順のとおり。
    nonisolated var activeChecks: [PrototypeCheck] {
        checks.filter { $0.status != .withdrawn }
    }
}

extension PrototypeData {
    /// 健診の、取り下げ以外の記録の並び順を変える。引数の意味は SwiftUI の `onMove` と同じ。
    ///
    /// - Parameters:
    ///   - source: 動かす記録の位置（取り下げ以外の記録の中での位置）。
    ///   - destination: 動かす先の位置。動かす前の並びで数える。
    nonisolated mutating func moveActiveChecks(in appointmentID: UUID, fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let index = appointments.firstIndex(where: { $0.id == appointmentID }) else { return }
        let active = appointments[index].activeChecks
        let withdrawn = appointments[index].checks.filter { $0.status == .withdrawn }

        let moving = source.sorted().filter { active.indices.contains($0) }.map { active[$0] }
        var remaining = active.enumerated()
            .filter { !source.contains($0.offset) }
            .map(\.element)
        // 動かす記録を取り除いた分だけ、挿入する位置を前にずらす。
        let insertion = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(max(insertion, 0), remaining.count))

        // 取り下げた記録は健診モードに出さないため、末尾に置く。
        appointments[index].checks = remaining + withdrawn
    }

    /// 新しい質問を作り、健診の末尾に未確認で加える。
    nonisolated mutating func addQuestion(_ text: String, to appointmentID: UUID) {
        guard let index = appointments.firstIndex(where: { $0.id == appointmentID }) else { return }
        let question = PrototypeQuestion(id: UUID(), text: text, withdrawnAt: nil)
        questions.append(question)
        appointments[index].checks.append(
            PrototypeCheck(
                id: UUID(),
                questionID: question.id,
                questionText: question.text,
                status: .unconfirmed,
                answerMemo: "",
                carriedOverToAppointmentID: nil
            )
        )
    }

    /// 質問を健診の末尾に未確認で加える。渡した順番を保つ。
    ///
    /// その健診に同じ質問の記録がすでにあれば、新しく作らない。取り下げ済みの記録なら未確認に戻す（11章#2）。
    nonisolated mutating func assign(questionIDs: [UUID], to appointmentID: UUID) {
        guard let index = appointments.firstIndex(where: { $0.id == appointmentID }) else { return }
        for questionID in questionIDs {
            guard let question = question(id: questionID) else { continue }
            if let checkIndex = appointments[index].checks.firstIndex(where: { $0.questionID == questionID }) {
                if appointments[index].checks[checkIndex].status == .withdrawn {
                    var check = appointments[index].checks.remove(at: checkIndex)
                    check.status = .unconfirmed
                    appointments[index].checks.append(check)
                }
                continue
            }
            appointments[index].checks.append(
                PrototypeCheck(
                    id: UUID(),
                    questionID: question.id,
                    questionText: question.text,
                    status: .unconfirmed,
                    answerMemo: "",
                    carriedOverToAppointmentID: nil
                )
            )
        }
        // 取り下げた記録は末尾に置く（moveActiveChecks と同じ並べ方）。
        let checks = appointments[index].checks
        appointments[index].checks = checks.filter { $0.status != .withdrawn } + checks.filter { $0.status == .withdrawn }
    }

    /// 診察を始める。診察開始日時は、空のときだけ記録する。2回目以降は再開として扱い、値を変えない（11章#4）。
    nonisolated mutating func startExam(of appointmentID: UUID, at date: Date) {
        guard let index = appointments.firstIndex(where: { $0.id == appointmentID }) else { return }
        if appointments[index].examStartedAt == nil {
            appointments[index].examStartedAt = date
        }
    }
}

extension PrototypeData {
    /// 確認記録の状態を変える。診察中の「回答済み」「持ち越し」と、その取り消し（未確認に戻す）に使う（11章#5〜#8）。
    ///
    /// 回答メモは変えない。取り消してもメモは残る（11章#6）。
    nonisolated mutating func setStatus(_ status: CheckStatus, ofCheck checkID: UUID, in appointmentID: UUID) {
        guard let location = checkLocation(checkID, in: appointmentID) else { return }
        appointments[location.appointment].checks[location.check].status = status
    }

    /// 回答メモを保存する。保存に失敗して残っていた入力（未保存のメモ）は、新しい内容で保存できたので消す（11章「未保存の短いメモの回復」）。
    nonisolated mutating func saveMemo(_ text: String, ofCheck checkID: UUID, in appointmentID: UUID) {
        guard let location = checkLocation(checkID, in: appointmentID) else { return }
        appointments[location.appointment].checks[location.check].answerMemo = text
        unsavedMemos[checkID] = nil
    }

    /// 確認記録が、健診の一覧と記録の一覧の何番目にあるか。
    private nonisolated func checkLocation(_ checkID: UUID, in appointmentID: UUID) -> (appointment: Int, check: Int)? {
        guard let appointmentIndex = appointments.firstIndex(where: { $0.id == appointmentID }),
              let checkIndex = appointments[appointmentIndex].checks.firstIndex(where: { $0.id == checkID })
        else { return nil }
        return (appointmentIndex, checkIndex)
    }
}
