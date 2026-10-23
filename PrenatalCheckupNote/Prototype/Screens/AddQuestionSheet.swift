import SwiftUI

/// 健診に質問を追加するシート。追加した質問は、その健診の最後に入る（上から順に聞くため）。
struct AddQuestionSheet: View {
    /// 「追加」を押したときに呼ぶ。前後の空白を除いた質問文を渡す。
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("聞きたいこと", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($isFocused)
                } footer: {
                    Text("この健診の質問の最後に追加します。")
                }
            }
            .navigationTitle("質問を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onAdd(trimmedText)
                        dismiss()
                    }
                    // 空白だけの質問は追加できない。
                    .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        // 入力中に下へのスワイプで閉じて、内容が消えないようにする（要件定義 5章 P0共通の品質要件）。
        .interactiveDismissDisabled(!trimmedText.isEmpty)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    Text("")
        .sheet(isPresented: .constant(true)) {
            AddQuestionSheet { _ in }
        }
}
