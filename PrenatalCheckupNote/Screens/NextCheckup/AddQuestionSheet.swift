import SwiftUI

/// 質問を追加するシート（要件定義 v0.4 の 4 章「質問を追加 / 質問」）。
///
/// 書いている途中の質問は、書きかけとして残す（R-72）。入力が 1 秒ほど止まったら保存し、
/// 「閉じる」でも保存を試す。次に開くと続きから書ける。破棄するのは「入力途中の内容を破棄」を押して確認したときだけ（R-71 と同じ）。
struct AddQuestionSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var note = ""
    /// 書きかけを読み込んだか。読み込む前の空の文で、書きかけを上書きしないため。
    @State private var hasLoaded = false
    /// 追加した・破棄したあとか。閉じる途中に、待っていた保存が書きかけを作り直さないため。
    @State private var isFinished = false
    @State private var isConfirmingDiscard = false
    @FocusState private var isTextFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section("聞きたいこと") {
                        TextField("例：腰が痛いときに気をつけること", text: $text, axis: .vertical)
                            .focused($isTextFocused)
                            // 画面のテストで、この欄を見つけるための名前。
                            .accessibilityIdentifier("questionTextField")
                    }
                    Section("補足（任意）") {
                        TextField("いつから、どんなときに、など", text: $note, axis: .vertical)
                    }
                    if store.questionDraft != nil || !isEmpty {
                        Section {
                            Button("入力途中の内容を破棄", role: .destructive) {
                                isConfirmingDiscard = true
                            }
                        }
                    }
                }
                // 行の地の色（ダークでも背景になじむ色。段階 F）。
                .listRowBackground(AppColors.card)
            }
            .appBackground()
            // キーボードを閉じる「完了」と、引っぱって閉じる動き（段階 F）。
            .keyboardDismissTools()
            .navigationTitle("質問を追加")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        add()
                    }
                    // 本文は必須。空白だけも空とみなす（R-01）。
                    .disabled(InputText.normalized(text) == nil)
                }
            }
            .onAppear(perform: loadDraft)
            // 入力が 1 秒ほど止まったら、書きかけを保存する。文が変わるたびに待ち直す（前の待ちは取り消される）。
            .task(id: DraftInput(text: text, note: note)) {
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
                Text("書いた質問と補足は消えます。")
            }
        }
        // まだ保存できていない文があるときは、下にスワイプしても閉じない。
        .interactiveDismissDisabled(hasUnsavedText)
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    /// 質問も補足も空か（空白だけも空）。
    private var isEmpty: Bool {
        InputText.normalized(text) == nil && InputText.normalized(note) == nil
    }

    /// 画面の文が、まだ書きかけとして保存できていないか。
    private var hasUnsavedText: Bool {
        if let saved = store.questionDraft {
            return saved.text != text || saved.note != note
        }
        return !isEmpty
    }

    private func loadDraft() {
        guard !hasLoaded else {
            return
        }
        if let draft = store.questionDraft {
            text = draft.text
            note = draft.note
        }
        hasLoaded = true
        isTextFocused = true
    }

    /// 書きかけを保存する。保存できたら（保存しなくてよかったときも）`true`。
    @discardableResult
    private func saveDraft() -> Bool {
        guard hasLoaded, !isFinished else {
            return true
        }
        let text = text
        let note = note
        let result: Void? = store.perform { try $0.updateQuestionDraft(text: text, note: note, now: .now) }
        return result != nil
    }

    private func add() {
        let text = text
        let note = note
        // 追加すると、同じ保存で書きかけも消える（R-72）。
        if store.perform({ try $0.addQuestion(text: text, note: note, now: .now) }) != nil {
            isFinished = true
            dismiss()
        }
    }

    private func discardDraft() {
        let result: Void? = store.perform { try $0.discardQuestionDraft() }
        if result != nil {
            isFinished = true
            dismiss()
        }
    }
}

/// 書きかけの保存を待ち直すきっかけ。質問か補足が変わったら、待ち直す。
private struct DraftInput: Equatable {
    let text: String
    let note: String
}
