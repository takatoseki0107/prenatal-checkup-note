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
    /// 元に戻せる操作がない（R-60）。
    case nothingToUndo
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
///
/// 元に戻せるのは直前の 1 回だけ（R-60）。どの操作でも保存に成功したら、前の「元に戻す」は消える。
/// 戻すための値はメモリの中にだけ持つので、アプリを終了すると消える。
final class NoteService {
    /// 初めて使うときに入れる持ち物（R-34）。
    static let initialBringItemNames = ["母子健康手帳", "保険証", "受診票"]

    let context: ModelContext
    private let persist: (ModelContext) throws -> Void

    /// 直前の操作を戻すための値。戻せる操作がなければ `nil`。画面は、これがある間だけ「元に戻す」を出す。
    private(set) var pendingUndo: PendingUndo?

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

    /// 質問を一覧のいちばん下に足す（R-01）。書きかけの質問があれば、同じ保存で消す（R-72）。
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
            if let draft = try questionDraft() {
                context.delete(draft)
            }
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

    /// 質問を消す（R-06）。元に戻せる。
    func deleteQuestion(id: UUID) throws {
        let question = try requireQuestion(id: id)
        let snapshot = question.snapshot
        try perform {
            context.delete(question)
        }
        pendingUndo = .deletedQuestion(snapshot)
    }

    // MARK: - 健診後メモ

    /// 健診後メモを保存する（R-12〜R-15）。元に戻せる（R-17）。
    ///
    /// 次をすべて 1 回の保存で行う：メモを作る、丸を付けた質問（外したものを除く）をメモに写して一覧から消す、
    /// 条件が合えば次の健診を空にして持ち物のチェックを外す、同じ ID の書きかけを消す。
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

        // 書き始めたときと同じ予定が残っていて、その日と受診日が同じときだけ空にする（R-15）。
        var nextToClear: NextCheckup?
        if let next = try nextCheckup(), next.id == input.nextCheckupIDAtStart, next.dayNumber == input.visitDay.number {
            nextToClear = next
        }
        var checkedItems: [BringItem] = []
        if nextToClear != nil {
            checkedItems = try bringItems().filter(\.isChecked)
        }
        var draftToDelete: MemoDraft?
        if let draft = try memoDraft(), draft.id == input.id {
            draftToDelete = draft
        }

        let undo = SavedMemoUndo(
            memoID: input.id,
            movedQuestions: included.map(\.snapshot),
            clearedNextCheckup: nextToClear?.snapshot,
            uncheckedBringItemIDs: checkedItems.map(\.id),
            draft: draftToDelete?.snapshot
        )
        let dueDateNumber = try profile()?.dueDateNumber

        let result = try perform { () throws -> MemoSaveResult in
            let memo = CheckupMemo(
                id: input.id,
                visitDayNumber: input.visitDay.number,
                body: body,
                dueDateNumberAtVisit: dueDateNumber,
                createdAt: now
            )
            context.insert(memo)

            for (offset, question) in included.enumerated() {
                let item = MemoItem(questionText: question.text, answer: question.answer, note: question.note, sortOrder: offset)
                context.insert(item)
                item.memo = memo
                context.delete(question)
            }

            if let nextToClear {
                context.delete(nextToClear)
                for item in checkedItems {
                    item.isChecked = false
                }
            }

            if let draftToDelete {
                context.delete(draftToDelete)
            }

            return MemoSaveResult(memoID: memo.id, clearedNextCheckup: nextToClear != nil, wasAlreadySaved: false)
        }
        pendingUndo = .savedMemo(undo)
        return result
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

    /// 次の健診の日付を消す（R-33）。元に戻せる。
    func clearNextCheckup() throws {
        guard let next = try nextCheckup() else {
            return
        }
        let snapshot = next.snapshot
        try perform {
            context.delete(next)
        }
        pendingUndo = .clearedNextCheckup(snapshot)
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

    // MARK: - 元に戻す

    /// 直前の操作を元に戻す（R-60〜R-63）。戻した操作を返す。
    ///
    /// 戻すことも 1 回の保存にまとめる。保存に失敗したら、戻す前のデータのままにし、戻すための値も残す（R-63）。
    @discardableResult
    func undo() throws -> PendingUndo {
        guard let undo = pendingUndo else {
            throw NoteServiceError.nothingToUndo
        }
        try perform {
            switch undo {
            case .deletedQuestion(let snapshot):
                context.insert(Question(snapshot))

            case .savedMemo(let saved):
                if let savedMemo = try memo(id: saved.memoID) {
                    context.delete(savedMemo)
                }
                for snapshot in saved.movedQuestions {
                    context.insert(Question(snapshot))
                }
                if let snapshot = saved.clearedNextCheckup {
                    if let current = try nextCheckup() {
                        context.delete(current)
                    }
                    context.insert(NextCheckup(snapshot))
                }
                let uncheckedIDs = Set(saved.uncheckedBringItemIDs)
                for item in try bringItems() where uncheckedIDs.contains(item.id) {
                    item.isChecked = true
                }
                if let snapshot = saved.draft {
                    if let current = try memoDraft() {
                        context.delete(current)
                    }
                    context.insert(MemoDraft(snapshot))
                }

            case .clearedNextCheckup(let snapshot):
                if let current = try nextCheckup() {
                    context.delete(current)
                }
                context.insert(NextCheckup(snapshot))
            }
        }
        return undo
    }

    /// 「元に戻す」をやめる。元に戻すの帯が時間で消えたときに呼ぶ（R-60）。
    ///
    /// 帯が消えたあとは戻せない（削除したものは、ここで戻せなくなる。R-62）。データは何も変えないので、保存もしない。
    func discardUndo() {
        pendingUndo = nil
    }

    // MARK: - 書きかけ

    func memoDraft() throws -> MemoDraft? {
        try context.fetch(FetchDescriptor<MemoDraft>()).first
    }

    /// 健診後メモを書き始める（R-10、R-70）。書きかけがあれば、それを返す（続きから書く）。
    ///
    /// なければ、受診日を次の健診の日（なければ今日）にし、その予定の ID を覚えて作る。
    @discardableResult
    func startMemoDraft(today: CalendarDay, now: Date) throws -> MemoDraft {
        if let draft = try memoDraft() {
            return draft
        }
        return try perform { () throws -> MemoDraft in
            let next = try nextCheckup()
            let draft = MemoDraft(visitDay: next?.day ?? today, nextCheckupIDAtStart: next?.id, updatedAt: now)
            context.insert(draft)
            return draft
        }
    }

    /// 書きかけの健診後メモを保存する。入力中に少しずつ呼ぶ（R-70）。本文は入力のまま残す。
    func updateMemoDraft(visitDay: CalendarDay, body: String, excludedQuestionIDs: Set<UUID>, now: Date) throws {
        try perform {
            guard let draft = try memoDraft() else {
                throw NoteServiceError.notFound
            }
            draft.visitDayNumber = visitDay.number
            draft.body = body
            draft.excludedQuestionIDs = excludedQuestionIDs.sorted { $0.uuidString < $1.uuidString }
            draft.updatedAt = now
        }
    }

    /// 書きかけの健診後メモを捨てる（R-71。確認は画面で行う）。
    func discardMemoDraft() throws {
        try perform {
            if let draft = try memoDraft() {
                context.delete(draft)
            }
        }
    }

    /// 書きかけから、保存する内容を作る。外した質問がもう消されていても、保存のときに無視される。
    func memoInputFromDraft() throws -> MemoInput {
        guard let draft = try memoDraft(), let visitDay = draft.visitDay else {
            throw NoteServiceError.notFound
        }
        return MemoInput(
            id: draft.id,
            visitDay: visitDay,
            body: draft.body,
            excludedQuestionIDs: Set(draft.excludedQuestionIDs),
            nextCheckupIDAtStart: draft.nextCheckupIDAtStart
        )
    }

    func questionDraft() throws -> QuestionDraft? {
        try context.fetch(FetchDescriptor<QuestionDraft>()).first
    }

    /// 書きかけの質問を保存する。なければ作る（R-72）。
    func updateQuestionDraft(text: String, note: String, now: Date) throws {
        try perform {
            if let draft = try questionDraft() {
                draft.text = text
                draft.note = note
                draft.updatedAt = now
            } else {
                context.insert(QuestionDraft(text: text, note: note, updatedAt: now))
            }
        }
    }

    func discardQuestionDraft() throws {
        try perform {
            if let draft = try questionDraft() {
                context.delete(draft)
            }
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
            // 保存できたら、前の「元に戻す」は消える（R-60）。戻せる操作は、呼び出し側でこのあとに入れ直す。
            pendingUndo = nil
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
