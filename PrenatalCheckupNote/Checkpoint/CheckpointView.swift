import SwiftUI

/// 段階 A の確認用の画面。保存の土台（`NoteService`）を、実際に操作して確かめる。
///
/// 見た目は整えない。段階 B で、見本どおりの 2 つのタブに作り直す。B1 からは、開発用ビルドの設定の「開発用」から開く。
/// 健診後メモを書くシートを本番の形で作る B3 までは、ここでメモを書いて確かめる。
/// 確かめること：質問を足す → 丸を付ける → 健診後メモを保存する → 元に戻す、書きかけを残して続きから書く、
/// アプリを終了して開き直しても残る、保存に失敗しても何も消えない。
struct CheckpointView: View {
    @Environment(NoteStore.self) private var store
    @State private var newQuestionText = ""
    @State private var isWritingMemo = false

    var body: some View {
        List {
            Section {
                Text("保存の仕組みを確かめるための、仮の画面です。見た目は段階 B で作り直します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    TextField("聞きたいことを書く", text: $newQuestionText)
                    Button("追加") {
                        addQuestion()
                    }
                    .disabled(InputText.normalized(newQuestionText) == nil)
                }
                ForEach(store.questions) { question in
                    QuestionCheckRow(question: question) {
                        store.perform { try $0.setAsked(!question.isAsked, questionID: question.id) }
                    }
                }
                .onDelete { offsets in
                    deleteQuestions(at: offsets)
                }
            } header: {
                Text("聞きたいこと（\(store.questions.count)件）")
            } footer: {
                Text("丸を押すと「聞いた」になります。左にスワイプすると削除できます。")
            }

            Section("健診後メモ") {
                Button(store.memoDraft == nil ? "健診後メモを書く" : "書きかけを続ける") {
                    startMemo()
                }
            }

            Section("これまでの健診（\(store.memos.count)件）") {
                if store.memos.isEmpty {
                    Text("まだありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.memos) { memo in
                    MemoCheckRow(memo: memo)
                }
            }
        }
        .navigationTitle("確認用")
        .safeAreaInset(edge: .bottom) {
            if store.pendingUndo != nil {
                undoBar
            }
        }
        .sheet(isPresented: $isWritingMemo) {
            MemoCheckSheet()
        }
        .alert("うまくいきませんでした", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    /// 元に戻すの帯。B1 から、`NoteStore` が目安 6 秒で消す。
    private var undoBar: some View {
        HStack {
            Text("元に戻せます")
                .font(.subheadline)
            Spacer()
            Button("元に戻す") {
                undo()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.bar)
    }

    /// この画面で失敗の知らせを出すかどうか。
    ///
    /// メモの画面（シート）を開いている間は、この画面の上に知らせを出せない（シートの後ろに隠れて、出ないまま終わる）。
    /// そのため、シートを開いている間はシートの側で出し、ここでは出さない。
    private var isShowingError: Binding<Bool> {
        Binding {
            store.errorMessage != nil && !isWritingMemo
        } set: { isShowing in
            if !isShowing {
                store.errorMessage = nil
            }
        }
    }

    private func addQuestion() {
        let text = newQuestionText
        if store.perform({ try $0.addQuestion(text: text, now: .now) }) != nil {
            newQuestionText = ""
        }
    }

    private func deleteQuestions(at offsets: IndexSet) {
        let ids = offsets.map { store.questions[$0].id }
        store.perform { service in
            for id in ids {
                try service.deleteQuestion(id: id)
            }
        }
    }

    private func startMemo() {
        if store.perform({ try $0.startMemoDraft(today: CalendarDay(.now), now: .now) }) != nil {
            isWritingMemo = true
        }
    }

    private func undo() {
        let undone = store.perform { try $0.undo() }
        // 健診後メモの保存を戻したら、書いた内容のままメモの画面を開き直す（R-17）。
        if case .savedMemo? = undone {
            isWritingMemo = true
        }
    }
}

/// 質問の 1 行。
private struct QuestionCheckRow: View {
    let question: Question
    let onToggleAsked: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleAsked) {
                Image(systemName: question.isAsked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question.isAsked ? "聞いた。押すと聞く前に戻す" : "聞く前。押すと聞いたにする")

            Text(question.text)
                .foregroundStyle(question.isAsked ? .secondary : .primary)
        }
    }
}

/// 健診後メモの 1 行。
private struct MemoCheckRow: View {
    let memo: CheckupMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(memo.visitDay?.description ?? "日付なし") の健診")
                .font(.headline)
            if let age = memo.gestationalAgeAtVisit {
                Text(age.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !memo.body.isEmpty {
                Text(memo.body)
                    .font(.subheadline)
            }
            ForEach(memo.sortedItems) { item in
                Text("・\(item.questionText)")
                    .font(.caption)
            }
        }
    }
}

/// 健診後メモを書く画面。入力のたびに書きかけを保存する（R-70）。
private struct MemoCheckSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var visitDate = Date.now
    @State private var memoText = ""
    @State private var excludedQuestionIDs: Set<UUID> = []
    @State private var isConfirmingDiscard = false
    /// 画面の文が、まだ書きかけとして保存できていないかどうか。
    /// 保存に失敗している間は、閉じると書いた分が消えるので、閉じさせない。
    @State private var hasUnsavedText = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("受診日", selection: $visitDate, displayedComponents: .date)

                Section("先生から聞いたこと・次までにすること（任意）") {
                    TextEditor(text: $memoText)
                        .frame(minHeight: 120)
                }

                Section("この健診で聞いたこと") {
                    let asked = store.questions.filter(\.isAsked)
                    if asked.isEmpty {
                        Text("丸を付けた質問はありません")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(asked) { question in
                        Toggle(question.text, isOn: inclusion(of: question.id))
                    }
                }

                Section {
                    Button("書きかけを捨てる", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                }
            }
            .navigationTitle("健診後メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        // 書きかけを保存できたときだけ閉じる。失敗したら知らせを出し、画面は開いたままにする。
                        if saveDraft() {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveMemo()
                    }
                }
            }
            .onAppear(perform: loadDraft)
            .onChange(of: memoText) { saveDraft() }
            .onChange(of: visitDate) { saveDraft() }
            .onChange(of: excludedQuestionIDs) { saveDraft() }
            .alert("書きかけを捨てますか？", isPresented: $isConfirmingDiscard) {
                Button("やめる", role: .cancel) {}
                Button("捨てる", role: .destructive) {
                    discardDraft()
                }
            } message: {
                Text("書いた文は消えます。丸を付けた質問は一覧に残ります。")
            }
        }
        // 保存できていない文があるときは、下にスワイプしても閉じないようにする。
        .interactiveDismissDisabled(hasUnsavedText)
        // シートの上で起きた失敗は、シートの上で知らせる（後ろの画面の知らせは、シートに隠れて出ないため）。
        .alert("うまくいきませんでした", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding {
            store.errorMessage != nil
        } set: { isShowing in
            if !isShowing {
                store.errorMessage = nil
            }
        }
    }

    /// 質問をメモに入れるかどうか。オフにすると「外す」（R-13）。
    private func inclusion(of questionID: UUID) -> Binding<Bool> {
        Binding {
            !excludedQuestionIDs.contains(questionID)
        } set: { isIncluded in
            if isIncluded {
                excludedQuestionIDs.remove(questionID)
            } else {
                excludedQuestionIDs.insert(questionID)
            }
        }
    }

    private func loadDraft() {
        guard let draft = store.memoDraft else {
            return
        }
        visitDate = draft.visitDay?.date(hour: 12) ?? .now
        memoText = draft.body
        excludedQuestionIDs = Set(draft.excludedQuestionIDs)
    }

    /// 書きかけを保存する。保存できたら `true` を返す。
    @discardableResult
    private func saveDraft() -> Bool {
        let day = CalendarDay(visitDate)
        let text = memoText
        let excluded = excludedQuestionIDs
        // 保存されている書きかけと同じなら、保存し直さない（開いたときに読み込んだだけで保存しないため）。
        if let draft = store.memoDraft,
           draft.visitDay == day,
           draft.body == text,
           Set(draft.excludedQuestionIDs) == excluded {
            hasUnsavedText = false
            return true
        }
        let result: Void? = store.perform {
            try $0.updateMemoDraft(visitDay: day, body: text, excludedQuestionIDs: excluded, now: .now)
        }
        let saved = result != nil
        hasUnsavedText = !saved
        return saved
    }

    private func saveMemo() {
        // 先に、画面の文を書きかけとして保存する。ここで失敗したら、メモの保存には進まない。
        guard saveDraft() else {
            return
        }
        let result = store.perform { (service: NoteService) throws -> MemoSaveResult in
            try service.saveMemo(try service.memoInputFromDraft(), now: .now)
        }
        if result != nil {
            dismiss()
        }
    }

    private func discardDraft() {
        if store.perform({ try $0.discardMemoDraft() }) != nil {
            dismiss()
        }
    }
}
