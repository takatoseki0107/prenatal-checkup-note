import SwiftUI

/// 出産予定日を入れる行（はじめに・設定で使う）。触れる見本と同じく、予定日を直接入れるか、いまの週数から計算する。
///
/// `Form` の `Section` の中に置く。
struct DueDateInputRows: View {
    @Binding var entry: DueDateEntry

    var body: some View {
        switch entry.mode {
        case .date:
            if let date = entry.date {
                DatePicker("出産予定日", selection: dateBinding(date), displayedComponents: .date)
                    // 日付はグレゴリオ暦・日本時間で決める（R-90）。
                    .environment(\.calendar, .japan)
                    .environment(\.timeZone, Calendar.japan.timeZone)
            } else {
                Button("出産予定日を選ぶ") {
                    entry.date = DueDateEntry.initialDate(today: today)
                }
            }
            Button("予定日がわからないとき：いまの週数から計算する") {
                entry.mode = .weeks
            }
            .font(.maru(.subheadline))

        case .weeks:
            Picker("いまの妊娠週数", selection: $entry.weeks) {
                Text("選んでください").tag(Int?.none)
                ForEach(0...44, id: \.self) { weeks in
                    Text("\(weeks) 週").tag(Int?.some(weeks))
                }
            }
            Picker("日", selection: $entry.days) {
                ForEach(0...6, id: \.self) { days in
                    Text("\(days) 日").tag(days)
                }
            }
            if let dueDate = entry.dueDate(today: today) {
                Text("出産予定日は \(dueDate.displayText) になります")
                    .font(.maru(.subheadline))
            }
            Button("出産予定日を直接入れる") {
                entry.mode = .date
            }
            .font(.maru(.subheadline))
        }
    }

    private var today: CalendarDay {
        CalendarDay(.now)
    }

    /// 日付の欄と、入力の日付（年・月・日）をつなぐ。
    private func dateBinding(_ current: CalendarDay) -> Binding<Date> {
        Binding {
            current.date(hour: 12)
        } set: { newValue in
            entry.date = CalendarDay(newValue)
        }
    }
}
