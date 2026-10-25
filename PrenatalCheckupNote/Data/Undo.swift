import Foundation

// 元に戻すための値。要件定義 v0.4 R-60〜R-63。
// 戻すための情報は、消したモデルへの参照ではなく、独立した値として持つ（R-63）。
// 消したモデルは保存のあとで使えなくなるため。

nonisolated struct QuestionSnapshot: Equatable, Sendable {
    let id: UUID
    let text: String
    let note: String
    let answer: String
    let isStarred: Bool
    let isAsked: Bool
    let sortOrder: Int
    let createdAt: Date
}

nonisolated struct NextCheckupSnapshot: Equatable, Sendable {
    let id: UUID
    let dayNumber: Int
    let hour: Int
    let minute: Int
    let isReminderOn: Bool
    let reminderHour: Int
    let reminderMinute: Int
}

nonisolated struct MemoDraftSnapshot: Equatable, Sendable {
    let id: UUID
    let visitDayNumber: Int
    let body: String
    let excludedQuestionIDs: [UUID]
    let nextCheckupIDAtStart: UUID?
    let updatedAt: Date
}

/// 戻せる操作（直前の 1 回だけ。R-60）。
nonisolated enum PendingUndo: Equatable, Sendable {
    /// 質問 1 件の削除（R-06）。
    case deletedQuestion(QuestionSnapshot)
    /// 健診後メモの保存（R-17）。戻すと、メモを消し、写した質問・空にした次の健診・外した持ち物のチェック・書きかけを戻す。
    case savedMemo(SavedMemoUndo)
    /// 次の健診の日付を消した（R-33）。
    case clearedNextCheckup(NextCheckupSnapshot)
}

nonisolated struct SavedMemoUndo: Equatable, Sendable {
    let memoID: UUID
    let movedQuestions: [QuestionSnapshot]
    /// 保存で空にした次の健診。空にしなかったら `nil`。
    let clearedNextCheckup: NextCheckupSnapshot?
    /// 保存でチェックを外した持ち物の ID。
    let uncheckedBringItemIDs: [UUID]
    /// 保存で消した書きかけ。戻すと、書いた内容のままシートを開き直せる。
    let draft: MemoDraftSnapshot?
}

extension Question {
    var snapshot: QuestionSnapshot {
        QuestionSnapshot(
            id: id,
            text: text,
            note: note,
            answer: answer,
            isStarred: isStarred,
            isAsked: isAsked,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }
}

extension NextCheckup {
    var snapshot: NextCheckupSnapshot {
        NextCheckupSnapshot(
            id: id,
            dayNumber: dayNumber,
            hour: hour,
            minute: minute,
            isReminderOn: isReminderOn,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }
}

extension MemoDraft {
    var snapshot: MemoDraftSnapshot {
        MemoDraftSnapshot(
            id: id,
            visitDayNumber: visitDayNumber,
            body: body,
            excludedQuestionIDs: excludedQuestionIDs,
            nextCheckupIDAtStart: nextCheckupIDAtStart,
            updatedAt: updatedAt
        )
    }
}
