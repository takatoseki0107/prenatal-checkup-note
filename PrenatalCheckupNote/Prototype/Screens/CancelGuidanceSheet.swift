import SwiftUI

/// キャンセル案内で選べる操作。
nonisolated enum CancelGuidanceChoice: Hashable, Sendable {
    /// 記録を修正する。診察中の画面で、回答・持ち越しを取り消す（11章#6・#8）。
    case fixRecords
    /// 完了にする（実際に受診した場合）。診察後の画面へ進む。
    case complete
}

/// キャンセル案内に出す、入力済みの記録。
nonisolated struct CancelGuidance: Identifiable, Hashable, Sendable {
    let answered: [PrototypeCheck]
    let carriedOver: [PrototypeCheck]

    var id: [UUID] { (answered + carriedOver).map(\.id) }
}

/// キャンセル案内（ワイヤー10）。回答済み・持ち越しの記録がある健診は、そのままキャンセルしない。要件定義 11章「健診のキャンセル」。
///
/// 回答を入力したことを、実際に受診したこととはみなさないため、「記録を修正する」と「完了にする」を同じ重みで並べる。
struct CancelGuidanceSheet: View {
    /// 健診の日付の表示。例：「Fri, Oct 23」。
    let dateText: String
    let guidance: CancelGuidance
    /// 「記録を修正する」「完了にする」を選んだとき。このシートが閉じてから、呼び出し側で画面を進める。
    let onChoose: (CancelGuidanceChoice) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("入力済みの記録があります")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("\(dateText)の健診をキャンセルする前に、記録の扱いを決めてください。")
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 12) {
                    recordGroup(title: "回答済み", checks: guidance.answered)
                    recordGroup(title: "持ち越し", checks: guidance.carriedOver)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(.fill.tertiary))

                Text("実際に受診した場合は「完了にする」を選んでください。受診していない場合は、回答と持ち越しを取り消すとキャンセルできます。取り消した記録の回答メモは、キャンセルのときに確認のうえ削除されます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // 2つの選択肢は、どちらかを勧めないよう同じ見た目にする。
                choiceButton("記録を修正する", choice: .fixRecords)
                choiceButton("完了にする（受診した場合）", choice: .complete)

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func recordGroup(title: String, checks: [PrototypeCheck]) -> some View {
        if !checks.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(title)　\(checks.count)件")
                    .font(.subheadline.bold())
                ForEach(checks) { check in
                    Text(check.questionText)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// 枠のあるボタン。下の帯の上では `.bordered` の背景がほとんど見えず、文字だけに見えたため、枠を自分で描く。
    private func choiceButton(_ title: String, choice: CancelGuidanceChoice) -> some View {
        Button {
            onChoose(choice)
            dismiss()
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
