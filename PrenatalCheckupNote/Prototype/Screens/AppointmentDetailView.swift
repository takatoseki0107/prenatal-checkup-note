import SwiftUI

/// 健診詳細。健診の情報、この健診で聞く質問、健診メモを表示し、健診モードと共有・印刷へ進む。
///
/// ワイヤーはないため、段階1では健診モードへの入口として最小限だけ作る。キャンセルの操作は、段階1の続きで加える。
struct AppointmentDetailView: View {
    let appointmentID: UUID
    @Environment(PrototypeStore.self) private var store

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
            }
        }
        .navigationTitle(appointment.scheduledAt.formatted(.dateTime.month().day()) + "の健診")
        .navigationBarTitleDisplayMode(.inline)
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
}
