import SwiftUI

/// 番号付きの確認記録。健診の完了の画面と、そこから開くシートで使う。
nonisolated struct NumberedCheck: Identifiable, Hashable, Sendable {
    /// 健診の中での番号（1から）。
    let number: Int
    let check: PrototypeCheck

    var id: UUID { check.id }
}

/// 健診モード：診察後（ワイヤー4）。健診を完了するために、質問ごとの扱いと行先を選ぶ。要件定義 6章、11章#9。
///
/// 扱いと行先は仮入力（`CompletionDraft`）で、最終確定までは保存しない（11章「完了確認の仮入力」）。
/// 回答メモは、完了とは別の操作としてその場で保存する（11章#18）。
struct AfterExamView: View {
    let appointmentID: UUID

    @Environment(PrototypeStore.self) private var store
    @State private var draft = CompletionDraft(checks: [])
    @State private var hasLoaded = false
    @State private var destinationTarget: NumberedCheck?
    @State private var memoTarget: NumberedCheck?
    @State private var isShowingConfirmationPlaceholder = false

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
        .onAppear {
            // 画面を開いたときに、保存済みの状態から仮入力を作る。戻ると、この仮入力ごと破棄される。
            guard !hasLoaded, let appointment = store.data.appointment(id: appointmentID) else { return }
            hasLoaded = true
            draft = CompletionDraft(checks: appointment.checks)
        }
    }

    private func content(for appointment: PrototypeAppointment) -> some View {
        let items = appointment.checks.enumerated().map { NumberedCheck(number: $0.offset + 1, check: $0.element) }
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
                    isShowingConfirmationPlaceholder = true
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
        .alert("最終確認の画面は、段階1の続きで作ります", isPresented: $isShowingConfirmationPlaceholder) {
            Button("OK", role: .cancel) {}
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
}
