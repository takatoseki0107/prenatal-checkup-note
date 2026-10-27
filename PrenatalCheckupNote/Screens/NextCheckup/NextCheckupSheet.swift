import SwiftUI

/// 次の健診の日付と時刻を入れる・直す・消すシート（要件定義 v0.4 の 4 章「次の健診」、5.3）。
///
/// 初めて入れるときは、目安の日付を入れておき、理由を添える（R-30）。目安は「保存」を押すまで予定にしない（R-31）。
/// 「1 / 2 / 4 週間後」のボタンで日付を入れられる（R-32）。
/// 前日の夜のお知らせのスイッチと時刻（R-40〜R-44）。時刻は触れる見本と同じくボタンを並べ、もう過ぎた時刻は出さない。
struct NextCheckupSheet: View {
    /// 時刻の初期値。触れる見本と同じ 10:30。
    private static let defaultHour = 10
    private static let defaultMinute = 30

    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

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
    /// 前日の夜にお知らせするか。
    @State private var isReminderOn = false
    /// お知らせの時刻（前日の何時何分か）。
    @State private var reminderSlot = ReminderTimeRule.defaultSlot
    @State private var initialIsReminderOn = false
    @State private var initialReminderSlot = ReminderTimeRule.defaultSlot
    /// 選んでいた時刻が過ぎて直したときの知らせ（R-42）。
    @State private var reminderNotice: String?
    @State private var isShowingPermissionAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        DatePicker("日付", selection: $date, displayedComponents: .date)
                        DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                    }
                    // 日付と時刻はグレゴリオ暦・日本時間で決める（R-90）。
                    .environment(\.calendar, .japan)
                    .environment(\.timeZone, Calendar.japan.timeZone)

                    Section {
                        weeksLayout {
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

                    reminderSection

                    if store.nextCheckup != nil {
                        Section {
                            Button("次の健診の日付を消す（お知らせも取り消す）", role: .destructive) {
                                clear()
                            }
                        } footer: {
                            Text("消したあと、画面の下の「元に戻す」で戻せます。")
                        }
                    }
                }
                // 行の地の色（ダークでも背景になじむ色。段階 F）。
                .listRowBackground(AppColors.card)
            }
            .appBackground()
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
            // 日付を変えて、選んでいた時刻が過ぎたら直す（R-42）。直すのは、このシートを開いているときだけ。
            .onChange(of: selectedDay) { _, day in
                adjustReminderSlot(for: day)
            }
            .notificationPermissionAlert(isPresented: $isShowingPermissionAlert)
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

    /// 前日の夜のお知らせ（R-40〜R-44）。触れる見本と同じ形にする。
    private var reminderSection: some View {
        Section {
            Toggle(
                "前日の夜にお知らせ",
                isOn: Binding {
                    showsReminderOn
                } set: { isOn in
                    setReminder(isOn)
                }
            )
            // 選べる時刻が 1 つもない日は、オフに見せて押せなくする（R-41）。
            // 「設定できません」と出ているのにオンに見えると、紛らわしいため（段階 C の確認で見つかった）。
            .disabled(availableSlots.isEmpty)

            if availableSlots.isEmpty {
                Text(ReminderTimeRule.unavailableMessage)
                    .font(.maru(.footnote))
            } else if isReminderOn {
                VStack(alignment: .leading, spacing: 8) {
                    Text("お知らせの時刻（前日）")
                        .font(.maru(.subheadline).weight(.semibold))
                    // 文字サイズがとても大きいときは 2 列にする（4 列のままだと「18:00」が 1 文字ずつ縦に折り返した。段階 F2）。
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 6) {
                        ForEach(availableSlots, id: \.self) { slot in
                            SlotButton(slot: slot, isSelected: slot == reminderSlot) {
                                reminderSlot = slot
                                reminderNotice = nil
                            }
                        }
                    }
                    if let reminderNotice {
                        Text(reminderNotice)
                            .font(.maru(.footnote).weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.vertical, 4)
            }
        } footer: {
            if isReminderOn, !availableSlots.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("選べるのは前日の 18:00〜23:30 です。もう過ぎた時刻は出しません。")
                    Text("届く文：「\(ReminderPlan.body)」")
                    Text("ロック画面にも出るので、質問の中身や健康のことは書きません。")
                }
            }
        }
    }

    /// 「◯ 週間後」のボタンの並べ方。文字サイズがとても大きいときは、3 つを縦に並べる（段階 F2）。
    /// 横のままだと「1」「週」「間」「後」と 1 文字ずつ折り返した。
    private var weeksLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
    }

    /// 「◯ 週間後」のボタン。前回の健診（なければ今日）から数える（R-32）。
    private func weeksButton(_ weeks: Int) -> some View {
        Button {
            date = (lastVisit ?? today).adding(days: weeks * 7).date(hour: 12)
        } label: {
            Text("\(weeks) 週間後")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    /// 選んでいる日の、まだ過ぎていないお知らせの時刻（R-41）。
    private var availableSlots: [ReminderTimeRule.Slot] {
        ReminderTimeRule.availableSlots(for: selectedDay, now: .now)
    }

    /// スイッチをオンに見せるか。オンにしてあっても、選べる時刻がない日はオフに見せる（R-41）。
    /// オンにしてあったことは覚えておき、別の日に選び直すとオンに戻る。保存するのも、この見えている状態。
    private var showsReminderOn: Bool {
        isReminderOn && !availableSlots.isEmpty
    }

    private var hasChanges: Bool {
        guard hasLoaded, !isClosing else {
            return false
        }
        return selectedDay != initialDay
            || selectedHourMinute != initialHourMinute
            || showsReminderOn != initialIsReminderOn
            || (showsReminderOn && reminderSlot != initialReminderSlot)
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

        // お知らせ。許可がないときはオンに見せない（R-44）。初めて入れるときは、許可があればオンにしておく（触れる見本と同じ）。
        let isAuthorized = store.reminders?.authorization == .authorized
        if let next = store.nextCheckup {
            isReminderOn = next.isReminderOn && isAuthorized
            reminderSlot = next.reminderSlot
        } else {
            isReminderOn = isAuthorized
            reminderSlot = ReminderTimeRule.defaultSlot
        }
        if isReminderOn, case .moved(_, let to) = ReminderTimeRule.adjust(reminderSlot, for: day, now: .now) {
            reminderSlot = to
        }
        // 開いたときに見えている状態を、変えたかどうかを比べる元にする。
        initialIsReminderOn = isReminderOn && !ReminderTimeRule.availableSlots(for: day, now: .now).isEmpty
        initialReminderSlot = reminderSlot
        hasLoaded = true
    }

    /// お知らせのスイッチを切り替える。オンにするときは、通知の許可を確かめる（R-44）。
    private func setReminder(_ isOn: Bool) {
        guard isOn else {
            isReminderOn = false
            reminderNotice = nil
            return
        }
        Task {
            guard await ensureReminderPermission(store.reminders) else {
                isShowingPermissionAlert = true
                return
            }
            isReminderOn = true
            adjustReminderSlot(for: selectedDay)
        }
    }

    /// 選んでいた時刻が過ぎていたら、選べるいちばん早い時刻に直し、そのことを伝える（R-42）。
    private func adjustReminderSlot(for day: CalendarDay) {
        guard isReminderOn else {
            return
        }
        switch ReminderTimeRule.adjust(reminderSlot, for: day, now: .now) {
        case .unchanged:
            break
        case .moved(let from, let to):
            reminderSlot = to
            reminderNotice = ReminderTimeRule.movedMessage(from: from, to: to)
        case .unavailable:
            reminderNotice = nil
        }
    }

    private func save() {
        let day = selectedDay
        let hourMinute = selectedHourMinute
        // 画面を開いたまま時刻が過ぎることがあるので、保存の直前にも確かめる（R-41）。
        // 過ぎていたら、直したことを画面に出して保存せずに止まる。確かめてから、もう一度「保存」を押してもらう。
        let slot = reminderSlot
        var turnsReminderOn = isReminderOn
        if turnsReminderOn {
            switch ReminderTimeRule.adjust(slot, for: day, now: .now) {
            case .unchanged:
                break
            case .moved(let from, let to):
                reminderSlot = to
                reminderNotice = ReminderTimeRule.movedMessage(from: from, to: to) + "。よければ、もう一度「保存」を押してください。"
                return
            case .unavailable:
                // 前日の夜がもう過ぎた。予定だけ保存し、今回はお知らせしない（シートに案内が出ている）。
                turnsReminderOn = false
            }
        }
        let isOnToSave = turnsReminderOn
        let result = store.perform {
            try $0.setNextCheckup(
                day: day,
                hour: hourMinute.hour,
                minute: hourMinute.minute,
                isReminderOn: isOnToSave,
                reminderSlot: slot
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

/// お知らせの時刻のボタン 1 つ。選んでいるものは塗りのあるボタンにする。
private struct SlotButton: View {
    let slot: ReminderTimeRule.Slot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            Button(action: action) {
                Text(slot.description)
                    // 時刻は途中で折り返すと読めないので 1 行に収め、入らなければ少しだけ縮める（段階 F2）。
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: action) {
                Text(slot.description)
                    // 時刻は途中で折り返すと読めないので 1 行に収め、入らなければ少しだけ縮める（段階 F2）。
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
