import SwiftUI

/// 健診一覧。予定の健診と、過去（完了・キャンセル）の健診を分けて並べる。
///
/// 段階1では、健診詳細へ進むための入口として最小限だけ作る。見た目は段階3以降で整える。
struct AppointmentListView: View {
    @Environment(PrototypeStore.self) private var store

    var body: some View {
        List {
            Section("予定") {
                if upcomingAppointments.isEmpty {
                    Text("予定の健診はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcomingAppointments) { appointment in
                        NavigationLink(value: PrototypeRoute.appointment(appointment.id)) {
                            AppointmentRow(appointment: appointment)
                        }
                    }
                }
            }
            if !pastAppointments.isEmpty {
                Section("過去の健診") {
                    ForEach(pastAppointments) { appointment in
                        NavigationLink(value: PrototypeRoute.appointment(appointment.id)) {
                            AppointmentRow(appointment: appointment)
                        }
                    }
                }
            }
        }
        .navigationTitle("健診")
    }

    /// 予定の健診。日時の近い順。
    private var upcomingAppointments: [PrototypeAppointment] {
        store.data.appointments
            .filter { $0.status == .scheduled }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// 完了・キャンセルした健診。新しい順。
    private var pastAppointments: [PrototypeAppointment] {
        store.data.appointments
            .filter { $0.status != .scheduled }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }
}

/// 健診一覧の1行。
private struct AppointmentRow: View {
    let appointment: PrototypeAppointment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appointment.scheduledAt.appointmentDateTimeText)
                .font(.headline)
            Text(appointment.clinicName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(detailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var detailText: String {
        let activeCount = appointment.checks.filter { $0.status != .withdrawn }.count
        return "\(appointment.status.displayName)・質問\(activeCount)件"
    }
}

#Preview {
    NavigationStack {
        AppointmentListView()
    }
    .environment(PrototypeStore())
}
