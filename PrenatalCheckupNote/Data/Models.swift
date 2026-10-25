import Foundation
import SwiftData

// 要件定義 v0.4 の 6 章「データの形」。どのモデルも、作ったときから変わらない ID（UUID）を持つ。
// 書きかけや元に戻すは、この ID で相手を指す。
// 日付だけのもの（受診日、出産予定日）は、`CalendarDay.number`（例：20261105）で持つ（ADR 0006）。
// 書きかけ（MemoDraft、QuestionDraft）と写真（MemoPhoto）は、あとの PR で足す。

/// 聞きたいこと。
@Model
final class Question {
    @Attribute(.unique) var id: UUID
    var text: String
    var note: String
    /// 先生の答え。丸がなくても書ける（R-05）。
    var answer: String
    /// 星（大事の印）。付けても並びは変えない（R-03）。
    var isStarred: Bool
    /// 丸（聞いた）。付けてもその場に残る（R-02）。
    var isAsked: Bool
    /// 一覧の並び。小さいほど上。
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID = UUID(), text: String, note: String = "", answer: String = "", isStarred: Bool = false, isAsked: Bool = false, sortOrder: Int, createdAt: Date) {
        self.id = id
        self.text = text
        self.note = note
        self.answer = answer
        self.isStarred = isStarred
        self.isAsked = isAsked
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

/// 健診後メモ。
@Model
final class CheckupMemo {
    @Attribute(.unique) var id: UUID
    /// 受診日（`CalendarDay.number`）。
    var visitDayNumber: Int
    /// 先生から聞いたこと・次までにすること。空でもよい（R-12）。
    var body: String
    /// 記録したときの出産予定日（`CalendarDay.number`）。週数はここから計算する。予定日がなければ `nil`（R-52）。
    var dueDateNumberAtVisit: Int?
    var createdAt: Date
    var updatedAt: Date
    /// この健診で聞いたこと。メモを消すと一緒に消える。
    @Relationship(deleteRule: .cascade, inverse: \MemoItem.memo)
    var items: [MemoItem] = []

    init(id: UUID, visitDayNumber: Int, body: String, dueDateNumberAtVisit: Int?, createdAt: Date) {
        self.id = id
        self.visitDayNumber = visitDayNumber
        self.body = body
        self.dueDateNumberAtVisit = dueDateNumberAtVisit
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var visitDay: CalendarDay? {
        CalendarDay(number: visitDayNumber)
    }

    /// 記録したときの予定日で計算した週数。予定日がない・範囲の外なら `nil`。
    var gestationalAgeAtVisit: GestationalAge? {
        guard let visitDay, let dueDateNumberAtVisit, let dueDate = CalendarDay(number: dueDateNumberAtVisit) else {
            return nil
        }
        return GestationalAge(on: visitDay, dueDate: dueDate)
    }

    /// 並び順どおりの「この健診で聞いたこと」。
    var sortedItems: [MemoItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }
}

/// 健診後メモの中の「この健診で聞いたこと」の 1 件。保存のときに `Question` から中身を写す。
///
/// 写したあとで質問を直しても、過去のメモは変わらない。
@Model
final class MemoItem {
    @Attribute(.unique) var id: UUID
    var questionText: String
    var answer: String
    var note: String
    var sortOrder: Int
    var memo: CheckupMemo?

    init(id: UUID = UUID(), questionText: String, answer: String, note: String, sortOrder: Int) {
        self.id = id
        self.questionText = questionText
        self.answer = answer
        self.note = note
        self.sortOrder = sortOrder
    }
}

/// 次の健診。0 件か 1 件。
@Model
final class NextCheckup {
    @Attribute(.unique) var id: UUID
    /// 健診の日（`CalendarDay.number`）。
    var dayNumber: Int
    var hour: Int
    var minute: Int
    /// 前日の夜のお知らせ。
    var isReminderOn: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(id: UUID = UUID(), day: CalendarDay, hour: Int, minute: Int, isReminderOn: Bool, reminderSlot: ReminderTimeRule.Slot) {
        self.id = id
        self.dayNumber = day.number
        self.hour = hour
        self.minute = minute
        self.isReminderOn = isReminderOn
        self.reminderHour = reminderSlot.hour
        self.reminderMinute = reminderSlot.minute
    }

    var day: CalendarDay? {
        CalendarDay(number: dayNumber)
    }

    var reminderSlot: ReminderTimeRule.Slot {
        ReminderTimeRule.Slot(hour: reminderHour, minute: reminderMinute)
    }
}

/// 持ち物。品目は次の健診でも使うので残る（R-34）。
@Model
final class BringItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var isChecked: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, isChecked: Bool = false, sortOrder: Int) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
        self.sortOrder = sortOrder
    }
}

/// 設定。1 件。
@Model
final class PregnancyProfile {
    @Attribute(.unique) var id: UUID
    /// 出産予定日（`CalendarDay.number`）。任意。
    var dueDateNumber: Int?
    /// 「妊娠週数を表示する」（R-53）。
    var showsGestationalAge: Bool
    /// 「はじめに」を終えたか。
    var hasFinishedOnboarding: Bool

    init(id: UUID = UUID(), dueDateNumber: Int? = nil, showsGestationalAge: Bool = true, hasFinishedOnboarding: Bool = false) {
        self.id = id
        self.dueDateNumber = dueDateNumber
        self.showsGestationalAge = showsGestationalAge
        self.hasFinishedOnboarding = hasFinishedOnboarding
    }

    var dueDate: CalendarDay? {
        dueDateNumber.flatMap { CalendarDay(number: $0) }
    }
}
