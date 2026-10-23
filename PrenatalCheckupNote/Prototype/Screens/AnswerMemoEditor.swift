import SwiftUI

/// 回答メモの編集（ワイヤー6）。要件定義 11章#18。
///
/// 「保存」を押すまでは仮入力で、「キャンセル」で破棄する。保存は健診の完了とは別に行い、記録の状態は変えない。
/// - 保存に失敗したら、入力を画面に残したまま再試行できる（14章 M-05）。
/// - 診察中の短いメモに保存できなかった入力があれば、入力欄に引き継ぐ（14章 M-08）。
///   この画面で「キャンセル」しても、引き継いだ未保存のメモはそのまま残る（14章 M-11）。
struct AnswerMemoEditor: View {
    let appointmentID: UUID
    let item: NumberedCheck
    /// 完了の仮入力で「取り下げ」を選んでいるか。完了するとメモは閲覧のみになることを伝える（14章 M-07）。
    let willBecomeReadOnly: Bool

    @Environment(PrototypeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var initialText = ""
    @State private var hasInheritedUnsavedMemo = false
    @State private var didFailToSave = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("質問\(item.number)　\(item.check.questionText)（\(item.check.status.displayName)）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if hasInheritedUnsavedMemo || didFailToSave || willBecomeReadOnly {
                    Section {
                        if hasInheritedUnsavedMemo {
                            Label("保存されていないメモがあります。入力欄に引き継いでいます。", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        if didFailToSave {
                            Label("保存できませんでした。入力した内容は残っています。もう一度「保存」を押してください。", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        if willBecomeReadOnly {
                            Label("完了すると、このメモは閲覧のみになります。", systemImage: "info.circle")
                        }
                    }
                    .font(.subheadline)
                }

                Section {
                    TextField("先生の説明や、次にすること", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                } header: {
                    Text("先生の説明や、次にすること")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("「保存」を押すまで保存されません。保存しても回答の状態は変わらず、健診の完了とは別に保存されます。")
                        Text("メモはご自身で入力した内容です。アプリが医学的な内容を確認・判断することはありません。")
                    }
                }
            }
            .navigationTitle("回答メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
        // 入力を変えたまま、下へのスワイプで閉じて内容が消えないようにする。
        .interactiveDismissDisabled(text != initialText)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            if let unsavedMemo = store.data.unsavedMemos[item.id] {
                text = unsavedMemo
                hasInheritedUnsavedMemo = true
            } else {
                text = savedMemo
            }
            initialText = text
        }
    }

    /// 保存済みのメモ。
    private var savedMemo: String {
        store.data.appointment(id: appointmentID)?.checks.first { $0.id == item.id }?.answerMemo ?? item.check.answerMemo
    }

    private func save() {
        // 失敗しても「未保存のメモ」にはせず、入力はこの画面に残す。キャンセルでこの画面の変更を破棄できるようにするため。
        if store.saveMemo(text, checkID: item.id, in: appointmentID, keepsUnsavedOnFailure: false) {
            dismiss()
        } else {
            didFailToSave = true
        }
    }
}
