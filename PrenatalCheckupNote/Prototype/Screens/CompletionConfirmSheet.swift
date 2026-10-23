import SwiftUI
import UIKit

/// 健診の完了：内容の確認（ワイヤー7）。最終確定の「完了する」は、この画面にだけ置く。要件定義 11章#9。
///
/// 未保存のメモがある健診では、完了の前に止め、質問ごとに「再試行」か「破棄（保存済みのメモに戻す）」を選んでもらう。
/// すべて解消するまで完了できない（14章 M-10）。
struct CompletionConfirmSheet: View {
    let appointmentID: UUID
    /// 仮入力の内容。記録の並び順のとおり。
    let items: [CompletionSummaryItem]
    /// 「完了する」を押したときの処理。完了・保存失敗のときは、呼び出し側がこのシートを閉じる。
    let onComplete: () -> CompletionOutcome

    @Environment(PrototypeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// 直前に「完了する」を押して、完了しなかった結果。
    @State private var lastOutcome: CompletionOutcome?
    /// 再試行して、また保存に失敗したメモ。
    @State private var failedRetryCheckIDs: Set<UUID> = []
    @State private var discardTarget: UnsavedMemoItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("この内容で健診を完了しますか？")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                summary

                if !unsavedItems.isEmpty {
                    unsavedSection
                }

                Text("完了すると、この健診の質問の扱いは変更できません。回答メモの編集と削除は、あとからでもできます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // 完了しなかった理由は、ボタンのすぐ上に出す。一覧をスクロールしなくても見えるようにするため。
                if let message = outcomeMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    complete()
                } label: {
                    Text("完了する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    dismiss()
                } label: {
                    Text("戻って直す")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        // 画面の中央に出し、後ろを暗くする。iOS 26 の confirmationDialog はボタンの近くに吹き出しで出て、
        // 後ろの未保存のメモの枠と重なって読みにくく、「やめる」も表示されないため。
        .alert(
            "保存されていない入力を破棄しますか？",
            isPresented: isShowingDiscardDialog,
            presenting: discardTarget
        ) { item in
            Button("破棄して保存済みのメモに戻す", role: .destructive) {
                store.discardUnsavedMemo(checkID: item.id)
                failedRetryCheckIDs.remove(item.id)
            }
            Button("やめる", role: .cancel) {}
        } message: { item in
            Text("質問\(item.number)の保存されていない入力は、元に戻せません。")
        }
    }

    // MARK: - 扱いの一覧

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text("この健診には質問がありません。質問なしで健診を記録します。")
                    .font(.subheadline)
            }
            ForEach(CompletionChoice.allCases, id: \.self) { choice in
                let group = items.filter { $0.choice == choice }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(choice.title)　\(group.count)件")
                            .font(.subheadline.bold())
                        ForEach(group) { item in
                            CompletionSummaryText(item: item)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.fill.tertiary))
    }

    // MARK: - 未保存のメモ（M-10）

    /// 保存されていない入力が残っている記録。
    private var unsavedItems: [UnsavedMemoItem] {
        guard let appointment = store.data.appointment(id: appointmentID) else { return [] }
        return appointment.checks.enumerated().compactMap { offset, check in
            guard let unsavedText = store.data.unsavedMemos[check.id] else { return nil }
            return UnsavedMemoItem(number: offset + 1, check: check, unsavedText: unsavedText)
        }
    }

    private var unsavedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("保存されていないメモがあります", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text("完了する前に、質問ごとに「再試行」か「破棄」を選んでください。破棄すると、保存済みのメモに戻ります。")
                .font(.subheadline)

            ForEach(unsavedItems) { item in
                unsavedRow(for: item)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 1.5)
        )
    }

    private func unsavedRow(for item: UnsavedMemoItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("質問\(item.number)　\(item.check.questionText)")
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("保存されていない入力：\(item.unsavedText)")
                .font(.footnote)
            Text("保存済みのメモ：\(item.check.answerMemo.isEmpty ? "なし" : item.check.answerMemo)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if failedRetryCheckIDs.contains(item.id) {
                Text("保存できませんでした。もう一度「再試行」を押すか、「破棄」を選んでください。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }

            // 文字が大きいときは、ボタンを縦に並べる。
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    unsavedButtons(for: item)
                }
                VStack(spacing: 8) {
                    unsavedButtons(for: item)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func unsavedButtons(for item: UnsavedMemoItem) -> some View {
        Button {
            retry(item)
        } label: {
            Text("再試行")
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("質問\(item.number)のメモの保存を再試行する")

        Button(role: .destructive) {
            discardTarget = item
        } label: {
            Text("破棄")
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("質問\(item.number)の保存されていない入力を破棄する")
    }

    private var isShowingDiscardDialog: Binding<Bool> {
        Binding {
            discardTarget != nil
        } set: { isPresented in
            if !isPresented {
                discardTarget = nil
            }
        }
    }

    // MARK: - 操作

    /// 完了しなかった理由。未保存のメモを解消したら、その案内は消す。
    private var outcomeMessage: String? {
        switch lastOutcome {
        case .hasUnsavedMemos:
            unsavedItems.isEmpty ? nil : "保存されていないメモがあるため、まだ完了していません。"
        case .rejected(let problems):
            problems.map(\.message).joined(separator: "\n")
        case .completed, .saveFailed, nil:
            nil
        }
    }

    private func complete() {
        let outcome = onComplete()
        switch outcome {
        case .hasUnsavedMemos, .rejected:
            lastOutcome = outcome
            UIAccessibility.post(notification: .announcement, argument: "まだ完了していません。\(outcomeMessage ?? "")")
        case .completed, .saveFailed:
            // 呼び出し側がシートを閉じる。
            lastOutcome = nil
        }
    }

    private func retry(_ item: UnsavedMemoItem) {
        if store.retryUnsavedMemo(checkID: item.id, in: appointmentID) {
            failedRetryCheckIDs.remove(item.id)
            UIAccessibility.post(notification: .announcement, argument: "質問\(item.number)のメモを保存しました")
        } else {
            failedRetryCheckIDs.insert(item.id)
            UIAccessibility.post(notification: .announcement, argument: "質問\(item.number)のメモを保存できませんでした")
        }
    }
}

/// 保存されていない入力が残っている記録。
private nonisolated struct UnsavedMemoItem: Identifiable, Hashable, Sendable {
    /// 健診の中での番号（1から）。
    let number: Int
    let check: PrototypeCheck
    let unsavedText: String

    var id: UUID { check.id }
}

/// 扱いの一覧の、記録1件分の文。内容の確認と、保存失敗の画面で使う。
struct CompletionSummaryText: View {
    let item: CompletionSummaryItem

    @Environment(PrototypeStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(item.number)　\(item.questionText)")
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        // VoiceOverで1件を1つのまとまりとして読み上げる。
        .accessibilityElement(children: .combine)
    }

    private var detail: String? {
        if item.wasAlreadyWithdrawn {
            return "前から取り下げ済み（変更なし）"
        }
        guard item.choice == .carriedOver else { return nil }
        guard let destinationID = item.destinationID, let destination = store.data.appointment(id: destinationID) else {
            return "→ 未割り当て"
        }
        return "→ " + destination.scheduledAt.formatted(.dateTime.month().day().weekday(.abbreviated)) + "の健診"
    }
}
