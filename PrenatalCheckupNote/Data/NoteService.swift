import Foundation
import SwiftData

/// 保存の窓口で起きるエラー。
nonisolated enum NoteServiceError: Error, Equatable {
    /// 文が空（空白と改行だけを含む）。
    case emptyText
    /// 本文も「この健診で聞いたこと」も写真もない健診後メモ（R-12、段階 E で写真を足した）。
    case emptyMemo
    /// 1 つのメモの写真が多すぎる（R-81、5 枚まで）。
    case tooManyPhotos
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

/// 過去の健診後メモを直すときの、「この健診で聞いたこと」の 1 件。
nonisolated struct MemoItemEdit: Equatable, Sendable {
    let id: UUID
    let questionText: String
    let answer: String
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
    /// 1 つの健診後メモに付けられる写真の数（R-81）。
    /// エラーの文（メインアクターの外）からも読むので、`nonisolated` にする（ただの数なので、どこから読んでも安全）。
    nonisolated static let maxPhotosPerMemo = 5

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
    ///
    /// 「はじめに」を作る前から使っていて、もう記録がある人には「はじめに」を出さない（終えたことにする）。
    func prepareInitialData(now: Date) throws {
        try perform {
            if let profile = try profile() {
                if !profile.hasFinishedOnboarding, try hasAnyRecord() {
                    profile.hasFinishedOnboarding = true
                }
                return
            }
            context.insert(PregnancyProfile())
            for (offset, name) in Self.initialBringItemNames.enumerated() {
                context.insert(BringItem(name: name, sortOrder: offset))
            }
        }
    }

    /// 質問・健診後メモ・次の健診・書きかけのどれかがあるか。
    private func hasAnyRecord() throws -> Bool {
        try !questions().isEmpty
            || !memos().isEmpty
            || nextCheckup() != nil
            || memoDraft() != nil
            || questionDraft() != nil
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
        // 写真は書きかけと同じ ID で持っているので、保存してもそのままこのメモの写真になる（付け替えない）。
        let hasPhotos = try !photos(memoID: input.id).isEmpty
        guard !body.isEmpty || !included.isEmpty || hasPhotos else {
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

    /// 過去の健診後メモを直す（R-18）。元に戻せる。
    ///
    /// 直せるのは、受診日・本文・各質問の文と答え。質問を足したり外したりはしない。
    /// 直しても、いま丸を付けている質問は取り込まない。記録したときの出産予定日もそのまま（週数は記録時の予定日で出す）。
    func updateMemo(id: UUID, visitDay: CalendarDay, body: String, items: [MemoItemEdit], now: Date) throws {
        guard let memo = try memo(id: id) else {
            throw NoteServiceError.notFound
        }
        // 質問の文は必須。空白だけも空とみなす。
        var normalizedItems: [UUID: (text: String, answer: String)] = [:]
        for item in items {
            guard let text = InputText.normalized(item.questionText) else {
                throw NoteServiceError.emptyText
            }
            normalizedItems[item.id] = (text, InputText.normalized(item.answer) ?? "")
        }
        let normalizedBody = InputText.normalized(body) ?? ""
        // 本文も質問も写真もないメモにはしない（R-12）。
        guard try !normalizedBody.isEmpty || !memo.items.isEmpty || !photos(memoID: id).isEmpty else {
            throw NoteServiceError.emptyMemo
        }

        let snapshot = memo.snapshot
        try perform {
            memo.visitDayNumber = visitDay.number
            memo.body = normalizedBody
            memo.updatedAt = now
            for item in memo.items {
                if let edited = normalizedItems[item.id] {
                    item.questionText = edited.text
                    item.answer = edited.answer
                }
            }
        }
        pendingUndo = .editedMemo(snapshot)
    }

    /// 健診後メモを削除する（R-19。確認は画面で行う）。メモの中の質問と答え、写真も一緒に消える。
    /// 元に戻せるのは、元に戻すの帯が出ている間だけ。
    func deleteMemo(id: UUID) throws {
        guard let memo = try memo(id: id) else {
            throw NoteServiceError.notFound
        }
        let snapshot = memo.snapshot
        let memoPhotos = try photos(memoID: id)
        let photoSnapshots = memoPhotos.map(\.snapshot)
        try perform {
            context.delete(memo)
            for photo in memoPhotos {
                context.delete(photo)
            }
        }
        pendingUndo = .deletedMemo(snapshot, photos: photoSnapshots)
    }

    // MARK: - 写真

    /// 健診後メモ（または書きかけ）の写真。並び順。
    func photos(memoID: UUID) throws -> [MemoPhoto] {
        try context.fetch(FetchDescriptor<MemoPhoto>(
            predicate: #Predicate<MemoPhoto> { photo in photo.memoID == memoID },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))
    }

    /// すべての写真。メモごとの枚数を数えるのに使う。
    func allPhotos() throws -> [MemoPhoto] {
        try context.fetch(FetchDescriptor<MemoPhoto>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    /// 写真を足す（R-80〜R-82）。足せるのは、保存したメモか、いまの書きかけ。5 枚までで、いちばん後ろに足す。
    @discardableResult
    func addPhoto(_ photo: PreparedPhoto, memoID: UUID, now: Date) throws -> UUID {
        let isDraft = try memoDraft()?.id == memoID
        guard try isDraft || memo(id: memoID) != nil else {
            throw NoteServiceError.notFound
        }
        let existing = try photos(memoID: memoID)
        guard existing.count < Self.maxPhotosPerMemo else {
            throw NoteServiceError.tooManyPhotos
        }
        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        return try perform { () throws -> UUID in
            let model = MemoPhoto(
                memoID: memoID,
                imageData: photo.imageData,
                thumbnailData: photo.thumbnailData,
                sortOrder: nextOrder,
                createdAt: now
            )
            context.insert(model)
            return model.id
        }
    }

    /// 写真を 1 枚外す（R-84）。元に戻すと、画像も一緒に戻る。
    ///
    /// 保存したメモの最後の中身（本文も質問もなく、写真がこの 1 枚だけ）なら外せない。空のメモを残さないため（R-12）。
    func removePhoto(id: UUID) throws {
        guard let photo = try context.fetch(FetchDescriptor<MemoPhoto>(predicate: #Predicate<MemoPhoto> { photo in photo.id == id })).first else {
            throw NoteServiceError.notFound
        }
        if let memo = try memo(id: photo.memoID), memo.body.isEmpty, memo.items.isEmpty,
           try photos(memoID: photo.memoID).count == 1 {
            throw NoteServiceError.emptyMemo
        }
        let snapshot = photo.snapshot
        try perform {
            context.delete(photo)
        }
        pendingUndo = .removedPhoto(snapshot)
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

    /// 持ち物の品目を足す（いちばん下）。品目は次の健診でも使うので残る（R-34）。
    @discardableResult
    func addBringItem(name: String) throws -> UUID {
        guard let name = InputText.normalized(name) else {
            throw NoteServiceError.emptyText
        }
        return try perform { () throws -> UUID in
            let nextOrder = (try bringItems().map(\.sortOrder).max() ?? -1) + 1
            let item = BringItem(name: name, sortOrder: nextOrder)
            context.insert(item)
            return item.id
        }
    }

    /// 持ち物の品目を外す。元に戻せる（R-34）。
    func removeBringItem(id: UUID) throws {
        guard let item = try bringItems().first(where: { $0.id == id }) else {
            throw NoteServiceError.notFound
        }
        let snapshot = item.snapshot
        try perform {
            context.delete(item)
        }
        pendingUndo = .removedBringItem(snapshot)
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

    /// 「はじめに」を終える。出産予定日を入れたときだけ、それを残す（「あとで入れる」なら `nil`）。
    func finishOnboarding(dueDate: CalendarDay?) throws {
        try perform {
            guard let profile = try profile() else {
                throw NoteServiceError.notFound
            }
            if let dueDate {
                profile.dueDateNumber = dueDate.number
            }
            profile.hasFinishedOnboarding = true
        }
    }

    /// 設定を保存する。出産予定日と「妊娠週数を表示する」を 1 回の保存にまとめる（S-01）。
    ///
    /// 予定日を変えても、これまでの健診後メモの週数は、記録したときの予定日のまま（R-52）。
    func updateSettings(dueDate: CalendarDay?, showsGestationalAge: Bool) throws {
        try perform {
            guard let profile = try profile() else {
                throw NoteServiceError.notFound
            }
            profile.dueDateNumber = dueDate?.number
            profile.showsGestationalAge = showsGestationalAge
        }
    }

    /// 出産予定日を消す。元に戻せる。
    func clearDueDate() throws {
        guard let profile = try profile(), let number = profile.dueDateNumber else {
            return
        }
        try perform {
            profile.dueDateNumber = nil
        }
        pendingUndo = .clearedDueDate(number)
    }

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

            case .removedBringItem(let snapshot):
                context.insert(BringItem(id: snapshot.id, name: snapshot.name, isChecked: snapshot.isChecked, sortOrder: snapshot.sortOrder))

            case .editedMemo(let snapshot):
                // 直したメモを、直す前の値に戻す（同じメモ・同じ質問のまま、中身だけ戻す）。
                guard let memo = try memo(id: snapshot.id) else {
                    throw NoteServiceError.notFound
                }
                memo.visitDayNumber = snapshot.visitDayNumber
                memo.body = snapshot.body
                memo.updatedAt = snapshot.updatedAt
                let itemsByID = Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.id, $0) })
                for item in memo.items {
                    if let before = itemsByID[item.id] {
                        item.questionText = before.questionText
                        item.answer = before.answer
                    }
                }

            case .clearedDueDate(let number):
                guard let profile = try profile() else {
                    throw NoteServiceError.notFound
                }
                profile.dueDateNumber = number

            case .removedPhoto(let snapshot):
                context.insert(MemoPhoto(snapshot))

            case .deletedMemo(let snapshot, let photoSnapshots):
                // 消したメモを、同じ ID のまま作り直す。質問と答え、写真も戻す。
                for photo in photoSnapshots {
                    context.insert(MemoPhoto(photo))
                }
                let memo = CheckupMemo(
                    id: snapshot.id,
                    visitDayNumber: snapshot.visitDayNumber,
                    body: snapshot.body,
                    dueDateNumberAtVisit: snapshot.dueDateNumberAtVisit,
                    createdAt: snapshot.createdAt
                )
                memo.updatedAt = snapshot.updatedAt
                context.insert(memo)
                for itemSnapshot in snapshot.items {
                    let item = MemoItem(
                        id: itemSnapshot.id,
                        questionText: itemSnapshot.questionText,
                        answer: itemSnapshot.answer,
                        note: itemSnapshot.note,
                        sortOrder: itemSnapshot.sortOrder
                    )
                    context.insert(item)
                    item.memo = memo
                }
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
    ///
    /// 保存されている書きかけと同じなら、保存しない（シートを開いただけで、前の操作の「元に戻す」を消さないため）。
    func updateMemoDraft(visitDay: CalendarDay, body: String, excludedQuestionIDs: Set<UUID>, now: Date) throws {
        if let existing = try memoDraft(),
           existing.visitDay == visitDay,
           existing.body == body,
           Set(existing.excludedQuestionIDs) == excludedQuestionIDs {
            return
        }
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

    /// 書きかけの健診後メモを捨てる（R-71。確認は画面で行う）。選んでいた写真も一緒に消す。
    func discardMemoDraft() throws {
        try perform {
            if let draft = try memoDraft() {
                for photo in try photos(memoID: draft.id) {
                    context.delete(photo)
                }
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
    ///
    /// 保存されている書きかけと同じなら、保存しない。シートを開いて読み込んだだけで保存すると、
    /// 前の操作の「元に戻す」が消えてしまうため（保存に成功すると「元に戻す」は消える。R-60）。
    /// 質問も補足も空にしたら、書きかけを消す（空の書きかけを残さない）。
    func updateQuestionDraft(text: String, note: String, now: Date) throws {
        let existing = try questionDraft()
        let isEmpty = InputText.normalized(text) == nil && InputText.normalized(note) == nil
        if let existing, existing.text == text, existing.note == note {
            return
        }
        if existing == nil, isEmpty {
            return
        }
        try perform {
            if let draft = try questionDraft() {
                if isEmpty {
                    context.delete(draft)
                } else {
                    draft.text = text
                    draft.note = note
                    draft.updatedAt = now
                }
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
