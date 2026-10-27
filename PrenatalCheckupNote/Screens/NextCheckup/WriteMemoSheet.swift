import SwiftUI

/// 健診後メモを書くシート（要件定義 v0.4 の 4 章「健診後メモを書く」、5.2）。
///
/// 受診日・本文・「この健診で聞いたこと」を書いて保存する。保存すると、メモに入れた質問は「聞きたいこと」から外れる。
/// 書いている途中の内容は、入力途中のメモとして残す（R-70）。入力が 1 秒ほど止まったら保存し、「閉じる」でも保存を試す。
/// 破棄するのは「入力途中の内容を破棄」を押して確認したときだけ（R-71）。
/// 写真（段階 E）は、選んだらすぐアプリの中に写して入力途中のメモに残す。閉じても、起動し直しても残る。
struct WriteMemoSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var visitDate = Date.now
    @State private var memoBody = ""
    /// 「外す」を押した質問の ID（R-13）。
    @State private var excludedQuestionIDs: Set<UUID> = []
    /// 入力途中のメモを読み込んだか。読み込む前の空の内容で上書きしないため。
    @State private var hasLoaded = false
    /// 保存した・破棄したあとか。閉じる途中に、待っていた保存が入力途中のメモを作り直さないため。
    @State private var isFinished = false
    @State private var isConfirmingDiscard = false
    /// 読み込んでいる写真の数。0 でなければ保存できない（段階 E の決まり）。
    @State private var loadingPhotoCount = 0
    /// キーボードが出ているか。出ている間は、下の保存の帯を隠す。
    @State private var isKeyboardShown = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    visitDaySection
                    Section("先生から聞いたこと・次までにすること（任意）") {
                        TextField("先生の説明や、次の健診までにすること", text: $memoBody, axis: .vertical)
                            .lineLimit(4...)
                            // 画面のテストで、この欄を見つけるための名前。
                            .accessibilityIdentifier("memoBodyField")
                    }
                    MemoPhotosSection(
                        memoID: store.memoDraft?.id,
                        photos: store.memoDraftPhotos,
                        loadingCount: $loadingPhotoCount,
                        footer: "エコー写真などを付けられます。アプリの中に写しを保存するので、写真アプリで消してもメモの写真は残ります。文章で共有するときは入りません。"
                    )
                    askedQuestionsSection
                    Section {
                        Button("入力途中の内容を破棄", role: .destructive) {
                            isConfirmingDiscard = true
                        }
                    }
                }
                // 行の地の色（ダークでも背景になじむ色。段階 F）。
                .listRowBackground(AppColors.card)
            }
            .appBackground()
            // キーボードを閉じる「完了」と、引っぱって閉じる動き（段階 F）。
            .keyboardDismissTools()
            .navigationTitle("健診後メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // 書いた内容を残して閉じる（R-71）。保存できたときだけ閉じる。
                    Button("閉じる") {
                        if saveDraft() {
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // 入力中は保存の帯を隠し、入力欄を広く使う。キーボードを閉じると出てくる。
                if !isKeyboardShown {
                    saveBar
                }
            }
            .onKeyboardVisibilityChange { shown in
                withAnimation(.easeOut(duration: 0.2)) {
                    isKeyboardShown = shown
                }
            }
            .onAppear(perform: loadDraft)
            // 入力が 1 秒ほど止まったら、入力途中のメモを保存する（R-70）。変わるたびに待ち直す。
            .task(id: MemoDraftInput(visitDay: visitDay, body: memoBody, excludedQuestionIDs: excludedQuestionIDs)) {
                guard hasLoaded else {
                    return
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                saveDraft()
            }
            .alert("入力途中の内容を破棄しますか？", isPresented: $isConfirmingDiscard) {
                Button("編集を続ける", role: .cancel) {}
                Button("破棄", role: .destructive) {
                    discardDraft()
                }
            } message: {
                Text(store.memoDraftPhotos.isEmpty
                    ? "書いた文は消えます。丸を付けた質問は「聞きたいこと」に残ります。"
                    : "書いた文と選んだ写真は消えます。丸を付けた質問は「聞きたいこと」に残ります。")
            }
        }
        // まだ保存できていない入力があるとき・写真を読み込んでいるときは、下にスワイプしても閉じない。
        .interactiveDismissDisabled(hasUnsavedInput || loadingPhotoCount > 0)
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    // MARK: - 部品

    /// 受診日と、その下の案内（R-10、R-11）。
    private var visitDaySection: some View {
        Section {
            DatePicker("受診日", selection: $visitDate, displayedComponents: .date)
                // 日付はグレゴリオ暦・日本時間で決める（R-90）。iPhone の設定によらず同じ日になるように。
                .environment(\.calendar, .japan)
                .environment(\.timeZone, Calendar.japan.timeZone)
            if let message = visitDayGuide.message {
                Text(message)
                    .font(.maru(.footnote))
                    .foregroundStyle(.secondary)
                if case .future(_, _) = visitDayGuide {
                    Button("今日にする") {
                        visitDate = today.date(hour: 12)
                    }
                }
            }
        }
    }

    /// 「この健診で聞いたこと」（R-13）。丸を付けた質問が並び、「外す」「戻す」で切り替える。
    private var askedQuestionsSection: some View {
        Section {
            if askedQuestions.isEmpty {
                Text("丸を付けた質問はありません。")
                    .foregroundStyle(.secondary)
            }
            ForEach(askedQuestions) { question in
                AskedQuestionRow(
                    question: question,
                    isIncluded: !excludedQuestionIDs.contains(question.id)
                ) {
                    if excludedQuestionIDs.contains(question.id) {
                        excludedQuestionIDs.remove(question.id)
                    } else {
                        excludedQuestionIDs.insert(question.id)
                    }
                }
            }
        } header: {
            Text("この健診で聞いたこと")
        } footer: {
            if !askedQuestions.isEmpty {
                Text("「外す」を押した質問はメモに入らず、丸を付けたまま「聞きたいこと」に残ります。")
            }
        }
    }

    /// 画面の下の、写真を外したときの元に戻すの帯、次の健診がどうなるかの 1 行（R-16）と保存ボタン（R-14）。
    private var saveBar: some View {
        VStack(spacing: 8) {
            // 写真を外したときだけ、ここに帯を出す（ほかの操作の帯は、後ろの画面で出す）。
            if case .removedPhoto? = store.pendingUndo {
                UndoBar()
            }
            if let message = nextCheckupOutcome.message {
                Text(message)
                    .font(.maru(.footnote))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                save()
            } label: {
                Text(MemoSheetRules.saveButtonTitle(includedQuestionCount: includedQuestionCount))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            // ボタンの文字の色。ダークでは明るい青のボタンになるので、白ではなく濃い紺にする（段階 F）。
            .foregroundStyle(AppColors.onAccent)
            .controlSize(.large)
            // 本文も「この健診で聞いたこと」も写真もないときは保存できない（R-12）。写真を読み込んでいる間も保存できない。
            .disabled(
                !MemoSheetRules.canSave(body: memoBody, includedQuestionCount: includedQuestionCount, photoCount: store.memoDraftPhotos.count)
                    || loadingPhotoCount > 0
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppColors.background)
        // 下の帯は、文字サイズ最大でも画面の多くを占めないよう、大きさに上限を付ける（段階 F2）。
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // MARK: - 決まり

    private var visitDay: CalendarDay {
        CalendarDay(visitDate)
    }

    private var today: CalendarDay {
        CalendarDay(.now)
    }

    private var askedQuestions: [Question] {
        store.questions.filter(\.isAsked)
    }

    private var includedQuestionCount: Int {
        askedQuestions.filter { !excludedQuestionIDs.contains($0.id) }.count
    }

    private var visitDayGuide: MemoSheetRules.VisitDayGuide {
        MemoSheetRules.visitDayGuide(visitDay: visitDay, nextCheckupDay: store.nextCheckup?.day, today: today)
    }

    private var nextCheckupOutcome: MemoSheetRules.NextCheckupOutcome {
        MemoSheetRules.nextCheckupOutcome(
            visitDay: visitDay,
            nextCheckupIDAtStart: store.memoDraft?.nextCheckupIDAtStart,
            currentNextCheckupID: store.nextCheckup?.id,
            currentNextCheckupDay: store.nextCheckup?.day
        )
    }

    /// 画面の内容が、まだ入力途中のメモとして保存できていないか。
    private var hasUnsavedInput: Bool {
        guard hasLoaded, !isFinished, let draft = store.memoDraft else {
            return false
        }
        return draft.visitDay != visitDay
            || draft.body != memoBody
            || Set(draft.excludedQuestionIDs) != excludedQuestionIDs
    }

    // MARK: - 操作

    private func loadDraft() {
        guard !hasLoaded else {
            return
        }
        // ふつうは開く前に入力途中のメモができている。念のため、なければここで作る。
        if store.memoDraft == nil {
            store.perform(saveFailureMessage: "健診後メモを書き始められませんでした。もう一度試してください。") {
                try $0.startMemoDraft(today: CalendarDay(.now), now: .now)
            }
        }
        if let draft = store.memoDraft {
            visitDate = (draft.visitDay ?? today).date(hour: 12)
            memoBody = draft.body
            excludedQuestionIDs = Set(draft.excludedQuestionIDs)
        }
        hasLoaded = true
    }

    /// 入力途中のメモを保存する。保存できたら（保存しなくてよかったときも）`true`。
    @discardableResult
    private func saveDraft() -> Bool {
        guard hasLoaded, !isFinished, store.memoDraft != nil else {
            return true
        }
        let day = visitDay
        let body = memoBody
        let excluded = excludedQuestionIDs
        let result: Void? = store.perform {
            try $0.updateMemoDraft(visitDay: day, body: body, excludedQuestionIDs: excluded, now: .now)
        }
        return result != nil
    }

    private func save() {
        // 先に、画面の内容を入力途中のメモとして保存する。ここで失敗したら、メモの保存には進まない。
        guard saveDraft() else {
            return
        }
        let result = store.perform { (service: NoteService) throws -> MemoSaveResult in
            try service.saveMemo(try service.memoInputFromDraft(), now: .now)
        }
        if result != nil {
            isFinished = true
            dismiss()
        }
    }

    private func discardDraft() {
        let result: Void? = store.perform { try $0.discardMemoDraft() }
        if result != nil {
            isFinished = true
            dismiss()
        }
    }
}

/// 「この健診で聞いたこと」の 1 行。外した質問は薄く出し、「戻す」で戻せる。
private struct AskedQuestionRow: View {
    let question: Question
    let isIncluded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.text)
                    .foregroundStyle(isIncluded ? .primary : .secondary)
                    .strikethrough(!isIncluded)
                if !question.answer.isEmpty {
                    Text("先生の答え：\(question.answer)")
                        .font(.maru(.footnote))
                        .foregroundStyle(.secondary)
                }
                if !isIncluded {
                    Text("メモに入れず、「聞きたいこと」に残します")
                        .font(.maru(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(isIncluded ? "外す" : "戻す", action: onToggle)
                .buttonStyle(.bordered)
        }
    }
}

/// 入力途中のメモの保存を待ち直すきっかけ。受診日・本文・外した質問のどれかが変わったら、待ち直す。
private struct MemoDraftInput: Equatable {
    let visitDay: CalendarDay
    let body: String
    let excludedQuestionIDs: Set<UUID>
}
