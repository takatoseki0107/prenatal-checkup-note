import Foundation
import SwiftData

// 要件定義 v0.4 の 6 章「データの形」。どのモデルも、作ったときから変わらない ID（UUID）を持つ。
// 書きかけや元に戻すは、この ID で相手を指す。
// 日付だけのもの（受診日、出産予定日）は、`CalendarDay.number`（例：20261105）で持つ（ADR 0006）。
// 写真（MemoPhoto）は、段階 E の前に足す。

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

    /// 元に戻すときに、消す前の値から作り直す（同じ ID）。
    init(_ snapshot: QuestionSnapshot) {
        self.id = snapshot.id
        self.text = snapshot.text
        self.note = snapshot.note
        self.answer = snapshot.answer
        self.isStarred = snapshot.isStarred
        self.isAsked = snapshot.isAsked
        self.sortOrder = snapshot.sortOrder
        self.createdAt = snapshot.createdAt
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

/// 健診後メモの写真（段階 E、R-80〜R-85）。1 つのメモに 5 枚まで。
///
/// 写真は、メモではなく「メモの ID」で持ち主を指す。書きかけの健診後メモ（`MemoDraft`）の ID は、保存したメモの ID と同じなので、
/// 書きかけに足した写真は、保存してもそのままメモの写真になる（付け替えが要らない）。
/// 書きかけを捨てたとき・メモを削除したときは、同じ ID の写真を窓口で一緒に消す。
@Model
final class MemoPhoto {
    @Attribute(.unique) var id: UUID
    /// 持ち主の健診後メモ（または書きかけ）の ID。
    var memoID: UUID
    /// 大きく見るための画像（JPEG、長い辺 2,400 ピクセルまで）。大きいので、データベースの外のファイルに置く。
    @Attribute(.externalStorage) var imageData: Data
    /// 一覧に並べる小さい画像（JPEG、長い辺 300 ピクセルほど）。
    var thumbnailData: Data
    /// 並び。小さいほど前。
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID = UUID(), memoID: UUID, imageData: Data, thumbnailData: Data, sortOrder: Int, createdAt: Date) {
        self.id = id
        self.memoID = memoID
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    /// 元に戻すときに、消す前の値から作り直す（同じ ID）。
    init(_ snapshot: PhotoSnapshot) {
        self.id = snapshot.id
        self.memoID = snapshot.memoID
        self.imageData = snapshot.imageData
        self.thumbnailData = snapshot.thumbnailData
        self.sortOrder = snapshot.sortOrder
        self.createdAt = snapshot.createdAt
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

    /// 元に戻すときに、消す前の値から作り直す（同じ ID）。
    init(_ snapshot: NextCheckupSnapshot) {
        self.id = snapshot.id
        self.dayNumber = snapshot.dayNumber
        self.hour = snapshot.hour
        self.minute = snapshot.minute
        self.isReminderOn = snapshot.isReminderOn
        self.reminderHour = snapshot.reminderHour
        self.reminderMinute = snapshot.reminderMinute
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

/// 書きかけの健診後メモ。0 件か 1 件。要件定義 v0.4 R-70。
///
/// 入力中に少しずつ保存し、閉じても、アプリが終了しても残す。健診後メモを保存すると、同じ保存で消える。
@Model
final class MemoDraft {
    /// 保存する健診後メモの ID にもなる（同じ ID で 2 回保存しても 1 つ。S-02）。
    @Attribute(.unique) var id: UUID
    var visitDayNumber: Int
    var body: String
    /// 「外す」を押した質問の ID。その質問が消されていたら無視する。
    var excludedQuestionIDs: [UUID]
    /// 書き始めたときの次の健診の ID（R-15）。
    var nextCheckupIDAtStart: UUID?
    var updatedAt: Date

    init(id: UUID = UUID(), visitDay: CalendarDay, body: String = "", excludedQuestionIDs: [UUID] = [], nextCheckupIDAtStart: UUID?, updatedAt: Date) {
        self.id = id
        self.visitDayNumber = visitDay.number
        self.body = body
        self.excludedQuestionIDs = excludedQuestionIDs
        self.nextCheckupIDAtStart = nextCheckupIDAtStart
        self.updatedAt = updatedAt
    }

    /// 元に戻すときに、消す前の値から作り直す（同じ ID）。
    init(_ snapshot: MemoDraftSnapshot) {
        self.id = snapshot.id
        self.visitDayNumber = snapshot.visitDayNumber
        self.body = snapshot.body
        self.excludedQuestionIDs = snapshot.excludedQuestionIDs
        self.nextCheckupIDAtStart = snapshot.nextCheckupIDAtStart
        self.updatedAt = snapshot.updatedAt
    }

    var visitDay: CalendarDay? {
        CalendarDay(number: visitDayNumber)
    }
}

/// やること（要件定義 v0.4 の 5.10、R-100〜R-110）。先生に言われた申請や、産院への連絡など、健診と健診の間にすること。何件でも。
///
/// 期限は、選んだときの日付をそのまま `CalendarDay.number` で持つ（R-102、ADR 0012）。あとで次の健診の日付を変えても動かさない。
/// 完了は 2 段階（R-104）：丸を押すと `isChecked`（緑のチェック、その場に残る）→「完了にする」で `completedAt` に日時を入れる。
@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    /// 補足。空でもよい。
    var note: String
    /// 期限の日（`CalendarDay.number`）。期限なしなら `nil`。
    var dueDayNumber: Int?
    /// 大事な印（星）。同じ見出しの中で先に並ぶ（R-103）。
    var isStarred: Bool
    /// 緑のチェック（完了の 1 段階目）。完了にするまで、一覧のその場に残る。
    var isChecked: Bool
    /// 完了にした日時。完了していなければ `nil`。
    var completedAt: Date?
    /// 健診後メモから足したとき、そのメモの受診日（`CalendarDay.number`）。「◯月◯日の健診で」と出す（R-107）。
    var originVisitDayNumber: Int?
    /// 足した日時。同じ見出しの中の並び（足した順）に使う。
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        dueDay: CalendarDay? = nil,
        isStarred: Bool = false,
        isChecked: Bool = false,
        completedAt: Date? = nil,
        originVisitDay: CalendarDay? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.dueDayNumber = dueDay?.number
        self.isStarred = isStarred
        self.isChecked = isChecked
        self.completedAt = completedAt
        self.originVisitDayNumber = originVisitDay?.number
        self.createdAt = createdAt
    }

    /// 元に戻すときに、消す前の値から作り直す（同じ ID）。
    init(_ snapshot: TodoSnapshot) {
        self.id = snapshot.id
        self.title = snapshot.title
        self.note = snapshot.note
        self.dueDayNumber = snapshot.dueDayNumber
        self.isStarred = snapshot.isStarred
        self.isChecked = snapshot.isChecked
        self.completedAt = snapshot.completedAt
        self.originVisitDayNumber = snapshot.originVisitDayNumber
        self.createdAt = snapshot.createdAt
    }

    var dueDay: CalendarDay? {
        dueDayNumber.flatMap { CalendarDay(number: $0) }
    }

    var originVisitDay: CalendarDay? {
        originVisitDayNumber.flatMap { CalendarDay(number: $0) }
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    /// 並べ方や数え方の決まり（`TodoList`）に渡す値。
    var listEntry: TodoList.Entry {
        TodoList.Entry(
            id: id,
            title: title,
            note: note,
            dueDay: dueDay,
            isStarred: isStarred,
            isChecked: isChecked,
            completedAt: completedAt,
            originVisitDay: originVisitDay,
            createdAt: createdAt
        )
    }
}

/// 書きかけの質問（新しく足す質問だけ）。0 件か 1 件。要件定義 v0.4 R-72。
@Model
final class QuestionDraft {
    @Attribute(.unique) var id: UUID
    var text: String
    var note: String
    var updatedAt: Date

    init(id: UUID = UUID(), text: String = "", note: String = "", updatedAt: Date) {
        self.id = id
        self.text = text
        self.note = note
        self.updatedAt = updatedAt
    }
}
