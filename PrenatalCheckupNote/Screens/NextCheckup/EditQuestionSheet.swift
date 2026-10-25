import SwiftUI

/// すでにある質問を見る・直す・削除するシート（要件定義 v0.4 の 4 章「質問を追加 / 質問」）。質問の行を押すと開く。
///
/// 直すときは「保存」ボタン式で、書きかけは残さない（R-72）。先生の答えは、丸がなくても書ける（R-05）。
/// 削除は確認を出さず、閉じたあとの元に戻すの帯で戻せる（R-06）。
struct EditQuestionSheet: View {
    let questionID: UUID

    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var note = ""
    @State private var answer = ""
    @State private var hasLoaded = false
    /// 削除して閉じる途中か。閉じる間に「見つかりませんでした」を出さないため。
    @State private var isClosing = false
    @State private var isConfirmingCancel = false

    var body: some View {
        NavigationStack {
            Group {
                if question != nil || isClosing {
                    form
                } else {
                    ContentUnavailableView(
                        "この質問は見つかりませんでした",
                        systemImage: "questionmark.circle",
                        description: Text("削除されたか、健診後メモに移った可能性があります。")
                    )
                }
            }
            .navigationTitle("質問")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        if hasChanges {
                            isConfirmingCancel = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(InputText.normalized(text) == nil || !hasChanges)
                }
            }
            .onAppear(perform: load)
            .alert("直した内容を捨てますか？", isPresented: $isConfirmingCancel) {
                Button("直すのを続ける", role: .cancel) {}
                Button("捨てる", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("保存していない変更は消えます。")
            }
        }
        // 保存していない変更があるときは、下にスワイプしても閉じない。
        .interactiveDismissDisabled(hasChanges)
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    private var form: some View {
        Form {
            Section("聞きたいこと") {
                TextField("聞きたいこと", text: $text, axis: .vertical)
            }
            Section("補足（任意）") {
                TextField("いつから、どんなときに、など", text: $note, axis: .vertical)
            }
            Section {
                TextField("先生から聞いたこと", text: $answer, axis: .vertical)
                    .lineLimit(3...)
            } header: {
                Text("先生の答え（任意）")
            } footer: {
                Text("丸を付けていなくても書けます。")
            }
            Section {
                Button("この質問を削除する", role: .destructive) {
                    delete()
                }
            } footer: {
                Text("削除したあと、画面の下の「元に戻す」で戻せます。")
            }
        }
    }

    private var question: Question? {
        store.questions.first { $0.id == questionID }
    }

    /// 保存されている質問と、画面の文が違うか。
    private var hasChanges: Bool {
        guard hasLoaded, !isClosing, let question else {
            return false
        }
        return question.text != text || question.note != note || question.answer != answer
    }

    private func load() {
        guard !hasLoaded, let question else {
            return
        }
        text = question.text
        note = question.note
        answer = question.answer
        hasLoaded = true
    }

    private func save() {
        let text = text
        let note = note
        let answer = answer
        let result: Void? = store.perform {
            try $0.updateQuestion(id: questionID, text: text, note: note, answer: answer)
        }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }

    private func delete() {
        let result: Void? = store.perform { try $0.deleteQuestion(id: questionID) }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }
}
