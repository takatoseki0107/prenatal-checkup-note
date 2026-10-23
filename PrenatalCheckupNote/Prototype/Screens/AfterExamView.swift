import SwiftUI
import UIKit

/// 番号付きの確認記録。健診の完了の画面と、そこから開くシートで使う。
nonisolated struct NumberedCheck: Identifiable, Hashable, Sendable {
    /// 健診の中での番号（1から）。
    let number: Int
    let check: PrototypeCheck

    var id: UUID { check.id }
}

/// 健診モード：診察後（ワイヤー4・8・9）。健診を完了するために、質問ごとの扱いと行先を選ぶ。要件定義 6章、11章#9。
///
/// 扱いと行先は仮入力（`CompletionDraft`）で、最終確定までは保存しない（11章「完了確認の仮入力」）。
/// 回答メモは、完了とは別の操作としてその場で保存する（11章#18）。
/// - 「戻る」で仮入力を変えていたら、破棄してよいかを確かめる（ワイヤー8、14章 P-01）。
/// - 最終確定は内容の確認（ワイヤー7）で行う。保存に失敗したら、何も変えずに仮入力を残し、再試行できる（ワイヤー9、14章 P-02・C-12）。
struct AfterExamView: View {
    let appointmentID: UUID

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CompletionDraft(checks: [])
    /// 画面を開いたときの仮入力。「戻る」で、変えたかどうかを比べる。
    @State private var initialDraft = CompletionDraft(checks: [])
    @State private var hasLoaded = false
    @State private var destinationTarget: NumberedCheck?
    @State private var memoTarget: NumberedCheck?
    @State private var isShowingConfirmation = false
    @State private var isShowingLeaveConfirmation = false
    /// 完了の保存に失敗した後の画面（ワイヤー9）を出しているか。
    @State private var isShowingSaveFailure = false
    /// 完了した。内容の確認のシートが閉じてから、健診詳細へ戻る。
    @State private var didComplete = false

    var body: some View {
        Group {
            if let appointment = store.data.appointment(id: appointmentID) {
                content(for: appointment)
            } else {
                ContentUnavailableView("健診が見つかりません", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .navigationTitle("健診を完了する")
        .navigationBarTitleDisplayMode(.inline)
        // 仮入力を黙って捨てないよう、戻るボタンを置き換える。スワイプで戻る操作も止まる。
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    leave()
                } label: {
                    Label("戻る", systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .alert("入力をやめて戻りますか？", isPresented: $isShowingLeaveConfirmation) {
            // 安全な「入力を続ける」を主ボタンにする（ワイヤー8）。
            Button("入力を続ける", role: .cancel) {}
            Button("破棄して戻る", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("健診の完了で選んだ扱いと行先は、まだ保存されていません。戻ると破棄されます。診察中に記録した内容と、回答メモは保存済みのまま残ります。")
        }
        .onAppear {
            // 画面を開いたときに、保存済みの状態から仮入力を作る。戻ると、この仮入力ごと破棄される。
            guard !hasLoaded, let appointment = store.data.appointment(id: appointmentID) else { return }
            hasLoaded = true
            draft = CompletionDraft(checks: appointment.checks)
            initialDraft = draft
        }
    }

    private func content(for appointment: PrototypeAppointment) -> some View {
        let items = appointment.checks.enumerated().map { NumberedCheck(number: $0.offset + 1, check: $0.element) }

        return Group {
            if isShowingSaveFailure {
                saveFailureContent(for: appointment)
            } else {
                editingContent(for: appointment, items: items)
            }
        }
        .sheet(item: $destinationTarget) { item in
            DestinationPickerSheet(
                appointmentID: appointmentID,
                item: item,
                otherCarriedOverItems: items.filter { $0.id != item.id && draft.choice(for: $0.id) == .carriedOver },
                draft: $draft
            )
        }
        .sheet(item: $memoTarget) { item in
            AnswerMemoEditor(
                appointmentID: appointmentID,
                item: item,
                willBecomeReadOnly: draft.choice(for: item.id) == .withdrawn
            )
        }
        .sheet(isPresented: $isShowingConfirmation, onDismiss: {
            finishIfCompleted()
        }) {
            CompletionConfirmSheet(
                appointmentID: appointmentID,
                items: draft.summaryItems(for: appointment.checks)
            ) {
                complete()
            }
        }
    }

    /// 扱いと行先を選ぶ画面（ワイヤー4）。
    private func editingContent(for appointment: PrototypeAppointment, items: [NumberedCheck]) -> some View {
        let unselectedCount = draft.unselectedCount(in: appointment.checks)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("すべての質問の扱いを選ぶと完了できます。扱いと行先は、最後の確認で「完了する」を押すまで保存されません。回答メモはその場で保存されます。")
                    .font(.footnote)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.1)))

                if items.isEmpty {
                    Text("この健診には質問がありません。質問なしで健診を記録できます。")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }

                ForEach(items) { item in
                    card(for: item)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    isShowingConfirmation = true
                } label: {
                    Text("内容を確認する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                // 扱いを選んでいない質問があると、先へ進めない（11章#9、14章 C-03）。
                .disabled(unselectedCount > 0)

                if unselectedCount > 0 {
                    Text("扱いが未選択の質問が\(unselectedCount)件あります")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    /// 完了の保存に失敗した後の画面（ワイヤー9）。選んだ内容を見せ、もう一度試すか、見直すかを選ぶ。
    private func saveFailureContent(for appointment: PrototypeAppointment) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(draft.summaryItems(for: appointment.checks)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        CompletionSummaryText(item: item)
                        Text(item.choice.title)
                            .font(.subheadline.bold())
                            .accessibilityHidden(true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("質問\(item.number)、\(item.questionText)、\(item.choice.title)")
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("保存できませんでした")
                            .font(.headline)
                        Text("何も変更されていません。選んだ内容はこのまま残っています。")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 1.5)
                )
                .accessibilityElement(children: .combine)

                Button {
                    complete()
                } label: {
                    Text("もう一度試す")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    // 仮入力を残したまま、扱いを選ぶ画面に戻る。
                    isShowingSaveFailure = false
                } label: {
                    Text("選択内容を見直す")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    // MARK: - 質問ごとのカード

    @ViewBuilder
    private func card(for item: NumberedCheck) -> some View {
        let check = item.check
        let choice = draft.choice(for: check.id)
        let needsChoice = check.status != .withdrawn && choice == nil

        VStack(alignment: .leading, spacing: 8) {
            Text("\(item.number)　\(check.questionText)")
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            if check.status == .withdrawn {
                // 取り下げ済みの記録は閲覧のみ。戻すときは質問側の「取り下げを戻す」を使う（14章 C-15）。
                Text("取り下げ済み（ここでは選び直せません）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !check.answerMemo.isEmpty {
                    Text("メモ：\(check.answerMemo)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                CompletionChoiceButtons(number: item.number, selection: choice) { newChoice in
                    draft.setChoice(newChoice, for: check.id)
                }

                if choice == .carriedOver {
                    Button {
                        destinationTarget = item
                    } label: {
                        CardLinkRow(title: "行先", value: destinationText(for: check.id))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    memoTarget = item
                } label: {
                    CardLinkRow(title: memoTitle(for: check), value: "編集", detail: check.answerMemo)
                }
                .buttonStyle(.plain)

                if needsChoice {
                    Text("扱いを選んでください")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(needsChoice ? Color.orange : Color.secondary.opacity(0.3), lineWidth: needsChoice ? 1.5 : 1)
        )
    }

    // MARK: - 操作

    /// 「戻る」。仮入力を変えていたら、破棄してよいかを確かめる。変えていなければ、そのまま戻る。
    private func leave() {
        if draft != initialDraft {
            isShowingLeaveConfirmation = true
        } else {
            dismiss()
        }
    }

    /// 最終確定。内容の確認の「完了する」と、保存失敗の画面の「もう一度試す」から呼ぶ。
    @discardableResult
    private func complete() -> CompletionOutcome {
        let outcome = store.complete(appointmentID, with: draft)
        switch outcome {
        case .completed:
            didComplete = true
            if isShowingConfirmation {
                // シートが閉じてから健診詳細へ戻る（finishIfCompleted）。
                isShowingConfirmation = false
            } else {
                finishIfCompleted()
            }
        case .saveFailed:
            isShowingConfirmation = false
            isShowingSaveFailure = true
            UIAccessibility.post(notification: .announcement, argument: "保存できませんでした。何も変更されていません")
        case .hasUnsavedMemos, .rejected:
            // 内容の確認で、理由と解消の方法を示す。
            if !isShowingConfirmation {
                isShowingSaveFailure = false
                isShowingConfirmation = true
            }
        }
        return outcome
    }

    /// 完了していたら、健診モードの画面を閉じて健診詳細へ戻る。
    private func finishIfCompleted() {
        guard didComplete else { return }
        navigator.popToAppointment(appointmentID)
        UIAccessibility.post(notification: .announcement, argument: "健診を完了しました")
    }

    private func destinationText(for checkID: UUID) -> String {
        guard let destinationID = draft.destination(for: checkID),
              let destination = store.data.appointment(id: destinationID)
        else { return "未割り当て" }
        return destination.scheduledAt.formatted(.dateTime.month().day().weekday(.abbreviated)) + "の健診"
    }

    private func memoTitle(for check: PrototypeCheck) -> String {
        if store.data.unsavedMemos[check.id] != nil {
            return "回答メモ（未保存の入力あり）"
        }
        return check.answerMemo.isEmpty ? "回答メモ（なし）" : "回答メモ（保存済み）"
    }
}

/// 回答済み・持ち越し・取り下げから1つを選ぶボタン。文字が大きいときは縦に並べる。
private struct CompletionChoiceButtons: View {
    let number: Int
    let selection: CompletionChoice?
    let onSelect: (CompletionChoice) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))

        layout {
            ForEach(CompletionChoice.allCases, id: \.self) { choice in
                let isSelected = selection == choice
                Button {
                    onSelect(choice)
                } label: {
                    Text(choice.title)
                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? fillColor(for: choice) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("質問\(number)を\(choice.title)にする")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// 選んだ扱いの色。どの扱いも白い文字が読める濃さにする。
    private func fillColor(for choice: CompletionChoice) -> Color {
        switch choice {
        case .answered: Color.accentColor
        case .carriedOver: Color(red: 0.25, green: 0.25, blue: 0.28)
        case .withdrawn: Color(red: 0.6, green: 0.29, blue: 0)
        }
    }
}

/// カードの中の、別の画面を開く行（行先・回答メモ）。
private struct CardLinkRow: View {
    let title: String
    let value: String
    var detail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value + " ›")
                    .foregroundStyle(.tint)
            }
            if !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 8).fill(.fill.tertiary))
        .contentShape(Rectangle())
    }
}

#Preview("診察中に記録した後") {
    let store = PrototypeStore(scenario: .cancelWithRecords)
    NavigationStack {
        AfterExamView(appointmentID: store.data.currentAppointmentID)
    }
    .environment(store)
    .environment(PrototypeNavigator())
}
