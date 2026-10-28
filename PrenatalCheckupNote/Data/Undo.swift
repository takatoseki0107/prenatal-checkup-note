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

nonisolated struct BringItemSnapshot: Equatable, Sendable {
    let id: UUID
    let name: String
    let isChecked: Bool
    let sortOrder: Int
}

nonisolated struct MemoItemSnapshot: Equatable, Sendable {
    let id: UUID
    let questionText: String
    let answer: String
    let note: String
    let sortOrder: Int
}

nonisolated struct CheckupMemoSnapshot: Equatable, Sendable {
    let id: UUID
    let visitDayNumber: Int
    let body: String
    let dueDateNumberAtVisit: Int?
    let createdAt: Date
    let updatedAt: Date
    let items: [MemoItemSnapshot]
}

/// 写真 1 枚の値。元に戻すとき、画像も一緒に戻すために、画像のデータごと持つ（R-84）。
nonisolated struct PhotoSnapshot: Equatable, Sendable {
    let id: UUID
    let memoID: UUID
    let imageData: Data
    let thumbnailData: Data
    let sortOrder: Int
    let createdAt: Date
}

/// やること 1 件の値（R-105、R-109）。
nonisolated struct TodoSnapshot: Equatable, Sendable {
    let id: UUID
    let title: String
    let note: String
    let dueDayNumber: Int?
    let isStarred: Bool
    let isChecked: Bool
    let completedAt: Date?
    let originVisitDayNumber: Int?
    let originMemoID: UUID?
    let createdAt: Date
}

/// 戻せる操作（直前の 1 回だけ。R-60）。
nonisolated enum PendingUndo: Equatable, Sendable {
    /// 質問 1 件の削除（R-06）。
    case deletedQuestion(QuestionSnapshot)
    /// 健診後メモの保存（R-17）。戻すと、メモを消し、写した質問・空にした次の健診・外した持ち物のチェック・書きかけを戻す。
    case savedMemo(SavedMemoUndo)
    /// 次の健診の日付を消した（R-33）。
    case clearedNextCheckup(NextCheckupSnapshot)
    /// 持ち物の品目を外した（R-34）。
    case removedBringItem(BringItemSnapshot)
    /// 過去の健診後メモを直した（R-18）。直す前の値を持つ。
    case editedMemo(CheckupMemoSnapshot)
    /// 健診後メモを削除した（R-19）。帯が出ている間だけ戻せる。写真も一緒に戻す。
    case deletedMemo(CheckupMemoSnapshot, photos: [PhotoSnapshot])
    /// 写真を 1 枚外した（R-84）。画像ごと戻す。
    case removedPhoto(PhotoSnapshot)
    /// 出産予定日を消した。消す前の予定日（`CalendarDay.number`）を持つ。
    case clearedDueDate(Int)
    /// やることを 1 件削除した（R-105）。
    case deletedTodo(TodoSnapshot)
    /// チェックしたやることを完了にした（R-104）。戻すと、完了を取り消して、緑のチェックを付けた状態に戻す。
    case completedTodos(ids: [UUID])
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

extension MemoPhoto {
    var snapshot: PhotoSnapshot {
        PhotoSnapshot(
            id: id,
            memoID: memoID,
            imageData: imageData,
            thumbnailData: thumbnailData,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }
}

extension TodoItem {
    var snapshot: TodoSnapshot {
        TodoSnapshot(
            id: id,
            title: title,
            note: note,
            dueDayNumber: dueDayNumber,
            isStarred: isStarred,
            isChecked: isChecked,
            completedAt: completedAt,
            originVisitDayNumber: originVisitDayNumber,
            originMemoID: originMemoID,
            createdAt: createdAt
        )
    }
}

extension BringItem {
    var snapshot: BringItemSnapshot {
        BringItemSnapshot(id: id, name: name, isChecked: isChecked, sortOrder: sortOrder)
    }
}

extension CheckupMemo {
    var snapshot: CheckupMemoSnapshot {
        CheckupMemoSnapshot(
            id: id,
            visitDayNumber: visitDayNumber,
            body: body,
            dueDateNumberAtVisit: dueDateNumberAtVisit,
            createdAt: createdAt,
            updatedAt: updatedAt,
            items: sortedItems.map {
                MemoItemSnapshot(id: $0.id, questionText: $0.questionText, answer: $0.answer, note: $0.note, sortOrder: $0.sortOrder)
            }
        )
    }
}
