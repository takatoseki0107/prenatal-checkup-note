import SwiftUI
import UIKit

/// 持ち越し先の選択（ワイヤー5・5b）。要件定義 11章「持ち越し・割り当ての行先の候補」。
///
/// 既定は「未割り当て」で、最も近い健診へ自動では割り当てない。
/// 「ほかの持ち越しにも同じ行先を使う」は初期状態でオフ。オンにして決定したときは、対象のすべての質問で行先を確かめ、
/// 1件でも行先にできなければ1件も変えず、理由と該当する質問を示す（14章 C-13）。
/// 選んだ行先は仮入力で、最終確定まで保存しない。
struct DestinationPickerSheet: View {
    /// いま完了しようとしている健診。
    let appointmentID: UUID
    /// 行先を選ぶ質問。
    let item: NumberedCheck
    /// ほかに「持ち越し」を選んでいる質問。まとめて同じ行先を使うときの対象。
    let otherCarriedOverItems: [NumberedCheck]
    @Binding var draft: CompletionDraft

    @Environment(PrototypeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// 選んだ行先。`nil` は未割り当て。
    @State private var selection: UUID?
    @State private var appliesToOthers = false
    @State private var bulkErrors: [String] = []
    @State private var hasLoaded = false

    var body: some View {
        let options = DestinationRules.options(
            for: item.check.questionID,
            completing: appointmentID,
            in: store.data,
            now: .now
        )

        NavigationStack {
            List {
                Section {
                    Text("質問\(item.number)　\(item.check.questionText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    DestinationRow(
                        title: "未割り当て（既定）",
                        detail: "次の健診が決まってから割り当てます",
                        isSelected: selection == nil
                    ) {
                        select(nil)
                    }
                    ForEach(options.selectable) { appointment in
                        DestinationRow(
                            title: appointmentText(appointment),
                            detail: nil,
                            isSelected: selection == appointment.id
                        ) {
                            select(appointment.id)
                        }
                    }
                } header: {
                    Text("持ち越し先")
                } footer: {
                    if options.selectable.isEmpty && options.unavailable.isEmpty {
                        // 予定の健診がないときは、未割り当てだけを示して案内する（14章 C-14）。
                        Text("予定の健診がありません。")
                    }
                }

                if !options.unavailable.isEmpty {
                    Section {
                        ForEach(options.unavailable, id: \.appointment.id) { unavailable in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appointmentText(unavailable.appointment))
                                    .foregroundStyle(.secondary)
                                Text(unavailable.reason.explanation)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text("選べない健診")
                    } footer: {
                        Text("今回の健診と、完了・キャンセルした健診は表示しません。")
                    }
                }

                if !otherCarriedOverItems.isEmpty {
                    Section {
                        Toggle(isOn: $appliesToOthers) {
                            Text("ほかの持ち越し（\(otherNumbersText)）にも同じ行先を使う")
                        }
                        .onChange(of: appliesToOthers) {
                            bulkErrors = []
                        }
                    }
                }

                if !bulkErrors.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("まとめて適用できませんでした", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                            ForEach(bulkErrors, id: \.self) { message in
                                Text(message)
                                    .font(.subheadline)
                            }
                            Text("どの質問の行先も変更していません。")
                                .font(.subheadline)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("持ち越し先を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        decide()
                    }
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            selection = draft.destination(for: item.id)
        }
    }

    private var otherNumbersText: String {
        otherCarriedOverItems.map { "質問\($0.number)" }.joined(separator: "・")
    }

    private func select(_ appointmentID: UUID?) {
        selection = appointmentID
        bulkErrors = []
    }

    private func appointmentText(_ appointment: PrototypeAppointment) -> String {
        appointment.scheduledAt.formatted(.dateTime.month().day().weekday(.abbreviated)) + "の健診"
    }

    /// 「決定」。まとめて適用するときは、先にすべての質問で行先を確かめる。
    private func decide() {
        var targetIDs = [item.id]

        if appliesToOthers {
            if let selection, let destination = store.data.appointment(id: selection) {
                let errors = otherCarriedOverItems.compactMap { other -> String? in
                    guard let reason = DestinationRules.reasonUnavailable(destination, for: other.check.questionID, now: .now) else {
                        return nil
                    }
                    return "質問\(other.number)：\(reason.shortExplanation)"
                }
                guard errors.isEmpty else {
                    bulkErrors = errors
                    UIAccessibility.post(notification: .announcement, argument: "まとめて適用できませんでした")
                    return
                }
            }
            targetIDs += otherCarriedOverItems.map(\.id)
        }

        draft.setDestination(selection, for: targetIDs)
        dismiss()
    }
}

/// 持ち越し先の1行。1つだけ選べる。
private struct DestinationRow: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
