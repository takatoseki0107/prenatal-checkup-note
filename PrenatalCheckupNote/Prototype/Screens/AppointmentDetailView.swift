import SwiftUI
import UIKit

/// 健診詳細。健診の情報、この健診で聞く質問、健診メモを表示し、健診モードと共有・印刷へ進む。
///
/// ワイヤーはないため、段階1では健診モードへの入口として最小限だけ作る。
/// 予定の健診では「キャンセル」を常に表示し、押したときに記録の状況に応じて、確認（ワイヤー11）か案内（ワイヤー10）を出す。
/// 要件定義 11章「健診のキャンセル」。
struct AppointmentDetailView: View {
    let appointmentID: UUID
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeNavigator.self) private var navigator
    /// キャンセルの確認（ワイヤー11）に出す内容。
    @State private var cancellationSummary: CancellationSummary?
    /// キャンセル案内（ワイヤー10）に出す記録。
    @State private var cancelGuidance: CancelGuidance?
    /// キャンセル案内で選んだ操作。案内のシートが閉じてから画面を進める。
    @State private var pendingGuidanceChoice: CancelGuidanceChoice?

    var body: some View {
        if let appointment = store.data.appointment(id: appointmentID) {
            content(for: appointment)
        } else {
            ContentUnavailableView("健診が見つかりません", systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func content(for appointment: PrototypeAppointment) -> some View {
        List {
            Section {
                LabeledContent("日時", value: appointment.scheduledAt.appointmentDateTimeText)
                LabeledContent("医療機関", value: appointment.clinicName)
                LabeledContent("状態", value: appointment.status.displayName)
                if let examStartedAt = appointment.examStartedAt {
                    LabeledContent("診察開始", value: examStartedAt.formatted(date: .omitted, time: .shortened))
                }
            }

            Section {
                if appointment.checks.isEmpty {
                    Text("この健診で聞く質問はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appointment.checks) { check in
                        CheckRow(check: check, destinationText: destinationText(for: check))
                    }
                }
            } header: {
                Text("聞くこと（\(appointment.checks.count)件）")
            }

            if !appointment.memo.isEmpty {
                Section("健診メモ") {
                    Text(appointment.memo)
                }
            }

            if appointment.status == .scheduled {
                Section {
                    NavigationLink(value: PrototypeRoute.beforeExam(appointment.id)) {
                        Label(
                            appointment.examStartedAt == nil ? "健診モードを開く" : "健診モードを再開する",
                            systemImage: "list.bullet.clipboard"
                        )
                    }
                    NavigationLink(value: PrototypeRoute.sharePreview(appointment.id)) {
                        Label("質問リストを共有・印刷する", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        requestCancel()
                    } label: {
                        Text("この健診をキャンセルする")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle(appointment.scheduledAt.formatted(.dateTime.month().day()) + "の健診")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "\(dateText(appointment))の健診をキャンセルしますか？",
            isPresented: isShowingCancelConfirmation,
            presenting: cancellationSummary
        ) { _ in
            // 安全な「やめる」を先に置く（ワイヤー11）。
            Button("やめる", role: .cancel) {}
            Button("キャンセルする", role: .destructive) {
                cancel()
            }
        } message: { summary in
            Text(cancelMessage(summary))
        }
        .sheet(item: $cancelGuidance, onDismiss: {
            continueAfterGuidance()
        }) { guidance in
            CancelGuidanceSheet(dateText: dateText(appointment), guidance: guidance) { choice in
                pendingGuidanceChoice = choice
            }
        }
    }

    // MARK: - キャンセル

    private func dateText(_ appointment: PrototypeAppointment) -> String {
        appointment.scheduledAt.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    /// 「この健診をキャンセルする」。記録の状況に応じて、確認か案内を出す。
    private func requestCancel() {
        switch store.data.cancellationEligibility(of: appointmentID) {
        case .cancellable(let summary):
            cancellationSummary = summary
        case .hasRecordedChecks(let answered, let carriedOver):
            cancelGuidance = CancelGuidance(answered: answered, carriedOver: carriedOver)
        case .notScheduled:
            break
        }
    }

    /// キャンセルの確認に出す説明。未割り当てに戻る質問と、削除される回答メモの件数を示す（14章 X-03・X-06）。
    private func cancelMessage(_ summary: CancellationSummary) -> String {
        var lines: [String] = []
        if summary.returningQuestionCount > 0 {
            lines.append("割り当てた質問\(summary.returningQuestionCount)件は、未割り当てに戻ります。")
        }
        if summary.deletedMemoCount > 0 {
            lines.append("回答メモ\(summary.deletedMemoCount)件が削除されます。")
        }
        lines.append("この健診の通知も取り消されます。キャンセルした健診は履歴に残ります。")
        return lines.joined(separator: "\n")
    }

    private var isShowingCancelConfirmation: Binding<Bool> {
        Binding {
            cancellationSummary != nil
        } set: { isPresented in
            if !isPresented {
                cancellationSummary = nil
            }
        }
    }

    private func cancel() {
        if store.cancel(appointmentID) {
            UIAccessibility.post(notification: .announcement, argument: "健診をキャンセルしました")
        }
    }

    /// キャンセル案内で選んだ画面へ進む。
    private func continueAfterGuidance() {
        guard let choice = pendingGuidanceChoice else { return }
        pendingGuidanceChoice = nil
        switch choice {
        case .fixRecords:
            // 診察中の画面で、記録済みの質問を開くと取り消せる（ワイヤー3）。
            navigator.push(.duringExam(appointmentID))
        case .complete:
            navigator.push(.afterExam(appointmentID))
        }
    }

    /// 持ち越しの記録の行先。完了した健診で、行先の健診が決まっているときだけ返す。
    private func destinationText(for check: PrototypeCheck) -> String? {
        guard check.status == .carriedOver,
              let destinationID = check.carriedOverToAppointmentID,
              let destination = store.data.appointment(id: destinationID)
        else { return nil }
        return "行先：" + destination.scheduledAt.formatted(.dateTime.month().day()) + "の健診"
    }
}

/// この健診で聞く質問の1行。質問文の写し、確認の状態、回答メモを出す。
private struct CheckRow: View {
    let check: PrototypeCheck
    let destinationText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(check.questionText)
            Text(check.status.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let destinationText {
                Text(destinationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !check.answerMemo.isEmpty {
                Text("メモ：\(check.answerMemo)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        // VoiceOverで1行を1つのまとまりとして読み上げる。
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let store = PrototypeStore()
    NavigationStack {
        AppointmentDetailView(appointmentID: store.data.currentAppointmentID)
    }
    .environment(store)
    .environment(PrototypeNavigator())
}
