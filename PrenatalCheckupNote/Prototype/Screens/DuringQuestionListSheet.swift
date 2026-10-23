import SwiftUI

/// 診察中の質問一覧（ワイヤー2b）。要件定義 6章、11章「未保存の短いメモの回復」。
///
/// 質問が多いときや文字が大きいときの、質問を移るための正式な入口。
/// 各質問の状態と「メモ未保存」を表示し、未保存のメモはここから再試行できる（14章 M-06）。
struct DuringQuestionListSheet: View {
    let appointmentID: UUID
    /// 診察中の画面で表示している質問の位置。
    let currentIndex: Int
    /// 質問を選んだときに呼ぶ。選んだ質問の位置を渡す。
    let onSelect: (Int) -> Void

    @Environment(PrototypeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let checks = store.data.appointment(id: appointmentID)?.activeChecks ?? []

        NavigationStack {
            List {
                Section {
                    ForEach(Array(checks.enumerated()), id: \.element.id) { offset, check in
                        row(number: offset + 1, check: check, isCurrent: offset == currentIndex) {
                            onSelect(offset)
                            dismiss()
                        }
                    }
                } header: {
                    Text(summary(of: checks))
                        .textCase(nil)
                }
            }
            .navigationTitle("質問一覧（\(checks.count)件）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func row(number: Int, check: PrototypeCheck, isCurrent: Bool, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onTap) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(number)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(check.questionText)
                        .fontWeight(isCurrent ? .bold : .regular)
                        .foregroundStyle(.primary)
                        // ボタンの中の文章は中央にそろうため、左にそろえ直す。
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isCurrent {
                        Text("表示中")
                            .font(.caption.bold())
                            .foregroundStyle(.tint)
                    } else {
                        StatusTag(status: check.status)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            // 1行に2つのボタン（移動と再試行）を置くため、行全体ではなくボタンごとに反応させる。
            // `.borderless` では文字がすべてボタンの色（青）になるため、色を変えない `.plain` を使う。
            .buttonStyle(.plain)

            if store.data.unsavedMemos[check.id] != nil {
                HStack {
                    Label("メモ未保存", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("再試行") {
                        store.retryUnsavedMemo(checkID: check.id, in: appointmentID)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.leading, 28)
            }
        }
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.12) : nil)
    }

    private func summary(of checks: [PrototypeCheck]) -> String {
        let answered = checks.filter { $0.status == .answered }.count
        let carriedOver = checks.filter { $0.status == .carriedOver }.count
        let unconfirmed = checks.filter { $0.status == .unconfirmed }.count
        return "回答済み \(answered)・持ち越し \(carriedOver)・未確認 \(unconfirmed)"
    }
}

#Preview {
    let store = PrototypeStore(scenario: .unsavedMemoAtConfirm)
    Text("")
        .sheet(isPresented: .constant(true)) {
            DuringQuestionListSheet(appointmentID: store.data.currentAppointmentID, currentIndex: 0) { _ in }
        }
        .environment(store)
}
