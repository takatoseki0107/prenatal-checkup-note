import SwiftUI

/// 質問を追加するシート（要件定義 v0.4 の 4 章「質問を追加 / 質問」）。
///
/// B1 では、質問と補足を書いて追加するだけ。既存の質問を直す・先生の答え・削除・書きかけの保持（R-72）は B2 で足す。
struct AddQuestionSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var note = ""
    @FocusState private var isTextFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("聞きたいこと") {
                    TextField("例：腰が痛いときに気をつけること", text: $text, axis: .vertical)
                        .focused($isTextFocused)
                }
                Section("補足（任意）") {
                    TextField("いつから、どんなときに、など", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("質問を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
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
            .onAppear {
                isTextFocused = true
            }
        }
        // 書いた文があるときは、下にスワイプしても閉じない（書きかけの保持は B2 で足すまで、うっかり消さないため）。
        .interactiveDismissDisabled(InputText.normalized(text) != nil || InputText.normalized(note) != nil)
        // シートの上で起きた失敗は、シートの上で知らせる。
        .noteErrorAlert(store)
    }

    private func add() {
        let text = text
        let note = note
        if store.perform({ try $0.addQuestion(text: text, note: note, now: .now) }) != nil {
            dismiss()
        }
    }
}
