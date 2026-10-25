import Foundation
import SwiftData

/// 保存の窓口で起きるエラー。
nonisolated enum NoteServiceError: Error, Equatable {
    /// 文が空（空白と改行だけを含む）。
    case emptyText
    /// 本文も「この健診で聞いたこと」もない健診後メモ（R-12）。
    case emptyMemo
    /// 指定の ID のデータがない。
    case notFound
    /// 保存に失敗した。変更はすべて保存前に戻した（S-01）。
    case saveFailed
}

/// 健診後メモを保存するときに渡す内容。
nonisolated struct MemoInput: Equatable, Sendable {
    /// 保存する健診後メモの ID。書き始めたときに決める。同じ ID で 2 回保存しても、メモは 1 つ（S-02）。
    let id: UUID
    let visitDay: CalendarDay
    let body: String
    /// 「外す」を押した質問の ID。メモに移らず、丸を付けたまま一覧に残る（R-13）。
    let excludedQuestionIDs: Set<UUID>
    /// 書き始めたときの次の健診の ID。保存のときに同じ予定が残っていて、その日と受診日が同じなら、予定を空にする（R-15）。
    let nextCheckupIDAtStart: UUID?
}

/// 健診後メモを保存した結果。
nonisolated struct MemoSaveResult: Equatable, Sendable {
    let memoID: UUID
    /// 次の健診を空にしたか。空にしたら、お知らせも取り消す（段階 C）。
    let clearedNextCheckup: Bool
    /// 前に同じ ID で保存済みだったので、何もしなかったか（S-02）。
    let wasAlreadySaved: Bool
}

/// データを変える操作の窓口。画面はデータを直接変えず、すべてここを通す。要件定義 v0.4 の 7 章。
///
/// 1 つの操作は 1 回の保存にまとめる。失敗したら保存前に戻し、一部だけ保存された状態を残さない（S-01）。
/// 自動保存は止め、ここで保存したときだけ保存されるようにする。
final class NoteService {
    /// 初めて使うときに入れる持ち物（R-34）。
    static let initialBringItemNames = ["母子健康手帳", "保険証", "受診票"]

    let context: ModelContext
    private let persist: (ModelContext) throws -> Void

    /// - Parameter persist: 保存の処理。テストでは、わざと失敗する処理に差し替える（S-08）。
    init(context: ModelContext, persist: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.persist = persist
        context.autosaveEnabled = false
    }

    // MARK: - 読む

    func questions() throws -> [Question] {
        try context.fetch(FetchDescriptor<Question>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]))
    }

    /// これまでの健診後メモ。受診日の新しい順、同じ日なら作った順の新しい順。
    func memos() throws -> [CheckupMemo] {
        try context.fetch(FetchDescriptor<CheckupMemo>(sortBy: [
            SortDescriptor(\.visitDayNumber, order: .reverse),
            SortDescriptor(\.createdAt, order: .reverse),
        ]))
    }

    func nextCheckup() throws -> NextCheckup? {
        try context.fetch(FetchDescriptor<NextCheckup>()).first
    }

    func bringItems() throws -> [BringItem] {
        try context.fetch(FetchDescriptor<BringItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func profile() throws -> PregnancyProfile? {
        try context.fetch(FetchDescriptor<PregnancyProfile>()).first
    }

    // MARK: - 初めて使うとき

    /// 設定がなければ作り、初めの持ち物を入れる。2 回目以降は何もしない。
    func prepareInitialData(now: Date) throws {
        try perform {
            guard try profile() == nil else {
                return
            }
            context.insert(PregnancyProfile())
            for (offset, name) in Self.initialBringItemNames.enumerated() {
                context.insert(BringItem(name: name, sortOrder: offset))
            }
        }
    }

    // MARK: - 聞きたいこと

    /// 質問を一覧のいちばん下に足す（R-01）。
    @discardableResult
    func addQuestion(text: String, note: String = "", now: Date) throws -> UUID {
        guard let text = InputText.normalized(text) else {
            throw NoteServiceError.emptyText
        }
        return try perform { () throws -> UUID in
            let nextOrder = (try questions().map(\.sortOrder).max() ?? -1) + 1
            let question = Question(
                text: text,
                note: InputText.normalized(note) ?? "",
                sortOrder: nextOrder,
                createdAt: now
            )
            context.insert(question)
            return question.id
        }
    }

    /// 質問の文・補足・先生の答えを直す。
    func updateQuestion(id: UUID, text: String, note: String, answer: String) throws {
        guard let text = InputText.normalized(text) else {
            throw NoteServiceError.emptyText
        }
        try perform {
            let question = try requireQuestion(id: id)
            question.text = text
            question.note = InputText.normalized(note) ?? ""
            question.answer = InputText.normalized(answer) ?? ""
        }
    }

    /// 丸（聞いた）を付ける・外す。並びは変えない（R-02）。
    func setAsked(_ isAsked: Bool, questionID: UUID) throws {
        try perform {
            try requireQuestion(id: questionID).isAsked = isAsked
        }
    }

    /// 星を付ける・外す。並びは変えない（R-03）。
    func setStarred(_ isStarred: Bool, questionID: UUID) throws {
        try perform {
            try requireQuestion(id: questionID).isStarred = isStarred
        }
    }

    /// 質問の並びを変える（R-04）。`List` の `onMove` と同じ数え方（`toOffset` は動かす前の並びでの位置）。
    func moveQuestions(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        try perform {
            let current = try questions()
            let moving = source.sorted().filter { current.indices.contains($0) }.map { current[$0] }
            var remaining = current.enumerated().filter { !source.contains($0.offset) }.map(\.element)
            let insertAt = min(destination - source.filter { $0 < destination }.count, remaining.count)
            remaining.insert(contentsOf: moving, at: max(insertAt, 0))
            for (offset, question) in remaining.enumerated() {
                question.sortOrder = offset
            }
        }
    }

    /// 質問を消す（R-06）。元に戻すは、あとの PR で足す。
    func deleteQuestion(id: UUID) throws {
        try perform {
            context.delete(try requireQuestion(id: id))
        }
    }

    // MARK: - 健診後メモ

    /// 健診後メモを保存する（R-12〜R-15）。
    ///
    /// 次をすべて 1 回の保存で行う：メモを作る、丸を付けた質問（外したものを除く）をメモに写して一覧から消す、
    /// 条件が合えば次の健診を空にして持ち物のチェックを外す。
    @discardableResult
    func saveMemo(_ input: MemoInput, now: Date) throws -> MemoSaveResult {
        if try memo(id: input.id) != nil {
            return MemoSaveResult(memoID: input.id, clearedNextCheckup: false, wasAlreadySaved: true)
        }

        let body = InputText.normalized(input.body) ?? ""
        let included = try questions().filter { $0.isAsked && !input.excludedQuestionIDs.contains($0.id) }
        guard !body.isEmpty || !included.isEmpty else {
            throw NoteServiceError.emptyMemo
        }

        return try perform { () throws -> MemoSaveResult in
            let memo = CheckupMemo(
                id: input.id,
                visitDayNumber: input.visitDay.number,
                body: body,
                dueDateNumberAtVisit: try profile()?.dueDateNumber,
                createdAt: now
            )
            context.insert(memo)

            for (offset, question) in included.enumerated() {
                let item = MemoItem(questionText: question.text, answer: question.answer, note: question.note, sortOrder: offset)
                context.insert(item)
                item.memo = memo
                context.delete(question)
            }

            var cleared = false
            if let next = try nextCheckup(),
               next.id == input.nextCheckupIDAtStart,
               next.dayNumber == input.visitDay.number {
                context.delete(next)
                for item in try bringItems() {
                    item.isChecked = false
                }
                cleared = true
            }

            return MemoSaveResult(memoID: memo.id, clearedNextCheckup: cleared, wasAlreadySaved: false)
        }
    }

    func memo(id: UUID) throws -> CheckupMemo? {
        try context.fetch(FetchDescriptor<CheckupMemo>(predicate: #Predicate<CheckupMemo> { memo in memo.id == id })).first
    }

    // MARK: - 次の健診と持ち物

    /// 次の健診を入れる・直す。すでにあれば、その予定を直す（ID は変えない）。
    ///
    /// お知らせの時刻が過ぎているかの確かめと、お知らせの予約は段階 C で足す。
    @discardableResult
    func setNextCheckup(day: CalendarDay, hour: Int, minute: Int, isReminderOn: Bool, reminderSlot: ReminderTimeRule.Slot) throws -> UUID {
        try perform { () throws -> UUID in
            if let next = try nextCheckup() {
                next.dayNumber = day.number
                next.hour = hour
                next.minute = minute
                next.isReminderOn = isReminderOn
                next.reminderHour = reminderSlot.hour
                next.reminderMinute = reminderSlot.minute
                return next.id
            }
            let next = NextCheckup(day: day, hour: hour, minute: minute, isReminderOn: isReminderOn, reminderSlot: reminderSlot)
            context.insert(next)
            return next.id
        }
    }

    /// 次の健診の日付を消す（R-33）。
    func clearNextCheckup() throws {
        try perform {
            if let next = try nextCheckup() {
                context.delete(next)
            }
        }
    }

    func setBringItemChecked(_ isChecked: Bool, itemID: UUID) throws {
        try perform {
            guard let item = try bringItems().first(where: { $0.id == itemID }) else {
                throw NoteServiceError.notFound
            }
            item.isChecked = isChecked
        }
    }

    // MARK: - 設定

    func setDueDate(_ dueDate: CalendarDay?) throws {
        try perform {
            guard let profile = try profile() else {
                throw NoteServiceError.notFound
            }
            profile.dueDateNumber = dueDate?.number
        }
    }

    // MARK: - 保存のまとめ

    /// 変更をまとめて 1 回で保存する。途中で失敗したら、保存前に戻す（S-01）。
    private func perform<Value>(_ changes: () throws -> Value) throws -> Value {
        // ここを通らない変更はないはずだが、念のため、関係のない未保存の変更を混ぜない。
        if context.hasChanges {
            context.rollback()
        }
        do {
            let result = try changes()
            try persist(context)
            return result
        } catch let error as NoteServiceError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw NoteServiceError.saveFailed
        }
    }

    private func requireQuestion(id: UUID) throws -> Question {
        guard let question = try context.fetch(FetchDescriptor<Question>(predicate: #Predicate<Question> { question in question.id == id })).first else {
            throw NoteServiceError.notFound
        }
        return question
    }
}
