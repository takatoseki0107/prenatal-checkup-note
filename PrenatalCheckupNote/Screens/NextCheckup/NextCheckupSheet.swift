import SwiftUI

/// 次の健診の日付と時刻を入れる・直す・消すシート（要件定義 v0.4 の 4 章「次の健診」、5.3）。
///
/// 初めて入れるときは、目安の日付を入れておき、理由を添える（R-30）。目安は「保存」を押すまで予定にしない（R-31）。
/// 「1 / 2 / 4 週間後」のボタンで日付を入れられる（R-32）。お知らせのスイッチと時刻は段階 C で足す。
struct NextCheckupSheet: View {
    /// 時刻の初期値。触れる見本と同じ 10:30。
    private static let defaultHour = 10
    private static let defaultMinute = 30

    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var time = Date.now
    /// 開いたときの日付と時刻。変えたかどうかを比べる。
    @State private var initialDay: CalendarDay?
    @State private var initialHourMinute: HourMinute?
    /// 初めて入れるときの目安。すでに日付が入っていれば `nil`。
    @State private var suggestion: NextCheckupSuggestion?
    @State private var hasLoaded = false
    /// 保存した・消したあとか。閉じる間に「変更あり」としないため。
    @State private var isClosing = false
    @State private var isConfirmingCancel = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                }
                // 日付と時刻はグレゴリオ暦・日本時間で決める（R-90）。
                .environment(\.calendar, .japan)
                .environment(\.timeZone, Calendar.japan.timeZone)

                Section {
                    HStack(spacing: 8) {
                        weeksButton(1)
                        weeksButton(2)
                        weeksButton(4)
                    }
                } header: {
                    Text(NextCheckupSuggestion.baseLabel(lastVisit: lastVisit, today: today))
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text((suggestion?.reasonText ?? "") + "実際の日付は病院で決まるので、決まった日に直してください。")
                        // 選んでいる日の妊娠週数（R-51）。
                        if let ageText = store.gestationalAgeText(on: selectedDay) {
                            Text("この日は\(ageText)です")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                if store.nextCheckup != nil {
                    Section {
                        Button("次の健診の日付を消す", role: .destructive) {
                            clear()
                        }
                    } footer: {
                        Text("消したあと、画面の下の「元に戻す」で戻せます。")
                    }
                }
            }
            .navigationTitle("次の健診")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        if hasChanges {
                            isConfirmingCancel = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .onAppear(perform: load)
            .alert("変更を破棄しますか？", isPresented: $isConfirmingCancel) {
                Button("編集を続ける", role: .cancel) {}
                Button("破棄", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("保存していない変更は消えます。")
            }
        }
        // 保存していない変更があるときは、下にスワイプしても閉じない。
        .interactiveDismissDisabled(hasChanges)
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    /// 「◯ 週間後」のボタン。前回の健診（なければ今日）から数える（R-32）。
    private func weeksButton(_ weeks: Int) -> some View {
        Button {
            date = (lastVisit ?? today).adding(days: weeks * 7).date(hour: 12)
        } label: {
            Text("\(weeks) 週間後")
                .frame(maxWidth: .infinity)
        }
        // 行の中に複数のボタンを置くので、それぞれが別に押せる形にする。
        .buttonStyle(.bordered)
    }

    // MARK: - 値

    private var today: CalendarDay {
        CalendarDay(.now)
    }

    /// 前回の健診（いちばん新しい健診後メモ）の受診日。
    private var lastVisit: CalendarDay? {
        store.memos.compactMap(\.visitDay).max()
    }

    private var selectedDay: CalendarDay {
        CalendarDay(date)
    }

    private var selectedHourMinute: HourMinute {
        let components = Calendar.japan.dateComponents([.hour, .minute], from: time)
        return HourMinute(hour: components.hour ?? Self.defaultHour, minute: components.minute ?? Self.defaultMinute)
    }

    private var hasChanges: Bool {
        guard hasLoaded, !isClosing else {
            return false
        }
        return selectedDay != initialDay || selectedHourMinute != initialHourMinute
    }

    // MARK: - 操作

    private func load() {
        guard !hasLoaded else {
            return
        }
        let day: CalendarDay
        let hourMinute: HourMinute
        if let next = store.nextCheckup, let nextDay = next.day {
            day = nextDay
            hourMinute = HourMinute(hour: next.hour, minute: next.minute)
        } else {
            // 初めて入れるときは目安の日付を入れておく（R-30）。保存するまで予定にはしない（R-31）。
            let made = NextCheckupSuggestion.make(
                visitDays: store.memos.compactMap(\.visitDay),
                dueDate: store.dueDate,
                today: today
            )
            suggestion = made
            day = made.day
            hourMinute = HourMinute(hour: Self.defaultHour, minute: Self.defaultMinute)
        }
        date = day.date(hour: 12)
        time = day.date(hour: hourMinute.hour, minute: hourMinute.minute)
        initialDay = day
        initialHourMinute = hourMinute
        hasLoaded = true
    }

    private func save() {
        let day = selectedDay
        let hourMinute = selectedHourMinute
        // お知らせの設定は段階 C で画面に出す。それまでは、入っている設定をそのまま残す。
        let isReminderOn = store.nextCheckup?.isReminderOn ?? false
        let reminderSlot = store.nextCheckup?.reminderSlot ?? ReminderTimeRule.defaultSlot
        let result = store.perform {
            try $0.setNextCheckup(
                day: day,
                hour: hourMinute.hour,
                minute: hourMinute.minute,
                isReminderOn: isReminderOn,
                reminderSlot: reminderSlot
            )
        }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }

    private func clear() {
        let result: Void? = store.perform { try $0.clearNextCheckup() }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }
}

/// 時と分。
private struct HourMinute: Equatable {
    let hour: Int
    let minute: Int
}
