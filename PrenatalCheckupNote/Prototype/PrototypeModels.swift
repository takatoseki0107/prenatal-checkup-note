import Foundation

// 段階1（試作A）で画面を動かすための、メモリ上だけのデータ。保存はしない。
// 段階3で、段階2の保存モデル（SwiftData）とServiceに置き換える。要件定義 17章。

/// 試作用の質問。
nonisolated struct PrototypeQuestion: Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    /// 取り下げた日時。空なら取り下げていない。
    var withdrawnAt: Date?
}

/// 試作用の確認記録。1つの健診で、1つの質問を確認した記録。
nonisolated struct PrototypeCheck: Identifiable, Hashable, Sendable {
    let id: UUID
    let questionID: UUID
    /// 質問文の写し（スナップショット）。診察を始めると固定される。要件定義 11章。
    var questionText: String
    var status: CheckStatus
    /// 回答メモ（保存済みの内容）。
    var answerMemo: String
    /// 持ち越しの記録が、どの健診に引き継がれたか。完了した健診の記録でだけ使う。
    var carriedOverToAppointmentID: UUID?
}

/// 試作用の健診。
nonisolated struct PrototypeAppointment: Identifiable, Hashable, Sendable {
    let id: UUID
    var scheduledAt: Date
    var clinicName: String
    var status: AppointmentStatus
    /// 診察を始めた日時。一度記録したら変えない。要件定義 6章・11章。
    var examStartedAt: Date?
    /// 健診メモ（持ち物など）。
    var memo: String
    /// この健診の確認記録。並び順のとおりに並べる（上にあるほど先に聞く）。
    var checks: [PrototypeCheck]
}

/// 試作用のデータ一式。
nonisolated struct PrototypeData: Hashable, Sendable {
    /// 健診。日時の古い順。
    var appointments: [PrototypeAppointment]
    /// すべての質問。
    var questions: [PrototypeQuestion]
    /// 保存に失敗した短いメモ（確認記録のID → 入力内容）。要件定義 11章「未保存の短いメモの回復」。
    var unsavedMemos: [UUID: String]
    /// 試作の中心にする「今回の健診」。
    let currentAppointmentID: UUID

    func appointment(id: UUID) -> PrototypeAppointment? {
        appointments.first { $0.id == id }
    }

    func question(id: UUID) -> PrototypeQuestion? {
        questions.first { $0.id == id }
    }

    /// 取り下げた質問。
    var withdrawnQuestions: [PrototypeQuestion] {
        questions.filter { $0.withdrawnAt != nil }
    }

    /// 未割り当ての質問。取り下げておらず、回答済みでもなく、予定の健診で確認中でもない質問。
    ///
    /// 試作用の簡略な判定。正式な判定（解決根拠と取り下げ日時から導出する）は段階2で作る。要件定義 11章。
    var unassignedQuestions: [PrototypeQuestion] {
        let allChecks = appointments.flatMap(\.checks)
        let answeredIDs = Set(allChecks.filter { $0.status == .answered }.map(\.questionID))
        let inProgressIDs = Set(
            appointments
                .filter { $0.status == .scheduled }
                .flatMap(\.checks)
                .filter { $0.status == .unconfirmed || $0.status == .carriedOver }
                .map(\.questionID)
        )
        return questions.filter { question in
            question.withdrawnAt == nil
                && !answeredIDs.contains(question.id)
                && !inProgressIDs.contains(question.id)
        }
    }
}
