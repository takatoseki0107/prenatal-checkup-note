import SwiftUI

/// 共有プレビュー（ワイヤー12）。要件定義 5章 F-16。
///
/// 送る内容を先に見せ、「共有・印刷する」で共有シートを開く。送信先は共有シートで利用者が選び、アプリは自動で送信しない。
/// 共有シートには印刷用の項目も渡すため、同じボタンから印刷もできる（ADR 0004）。
struct SharePreviewView: View {
    let appointmentID: UUID

    @Environment(PrototypeStore.self) private var store

    var body: some View {
        if let appointment = store.data.appointment(id: appointmentID) {
            content(shareText: shareText(for: appointment))
        } else {
            ContentUnavailableView("健診が見つかりません", systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func content(shareText: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("次の内容を、共有シートで送るか印刷します。送信先はこのあと選びます。")
                    .font(.subheadline)

                Text(shareText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.fill.tertiary))
                    .textSelection(.enabled)

                Text("質問の内容が含まれます。アプリから自動で送信することはありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                ShareSheetPresenter.present(text: shareText)
            } label: {
                Label("共有・印刷する", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .navigationTitle("共有する内容")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shareText(for appointment: PrototypeAppointment) -> String {
        QuestionListShareText.make(
            dateText: appointment.scheduledAt.appointmentDateTimeText,
            questions: appointment.activeChecks.map(\.questionText),
            appointmentMemo: appointment.memo
        )
    }
}

#Preview {
    let store = PrototypeStore()
    NavigationStack {
        SharePreviewView(appointmentID: store.data.currentAppointmentID)
    }
    .environment(store)
}
