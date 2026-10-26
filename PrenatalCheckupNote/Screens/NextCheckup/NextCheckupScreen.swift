import SwiftUI

/// タブ 1「健診予定」（要件定義 v0.4 の 4 章。段階 F で「次の健診」から名前を変えた）。
///
/// いちばん上に次の健診のカード、その下に「聞きたいこと」の一覧、画面の下に「＋ 質問を追加」「健診後メモを書く」。
/// 行を押すと質問のシートを開く。出産予定日があれば、いちばん上に今日の妊娠週数を出す（R-51）。
/// カードの 3 行目は、前日の夜のお知らせとスイッチ（段階 C）。
struct NextCheckupScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            if let todayAgeText = store.gestationalAgeText(on: CalendarDay(.now)) {
                Section {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AppColors.pink)
                            .accessibilityHidden(true)
                        Text("今日は \(todayAgeText)")
                    }
                    .font(.maru(.subheadline).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.background))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                // 今日の週数と、すぐ下のカードの間を詰める。
                .listSectionSpacing(.compact)
            }

            NextCheckupCard()

            Section {
                if store.questions.isEmpty {
                    Text("聞きたいことはまだありません。思いついたら「＋ 質問を追加」で書き留めておきましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.questions) { question in
                    QuestionRow(question: question)
                }
                // 長押しして指で動かすと並べ替わる（R-04）。
                .onMove { source, destination in
                    store.perform { try $0.moveQuestions(fromOffsets: source, toOffset: destination) }
                }
                // 左にスワイプすると削除。確認は出さず、元に戻すの帯を出す（R-06）。
                .onDelete { offsets in
                    deleteQuestions(at: offsets)
                }
            } header: {
                Text("聞きたいこと（\(store.questions.count)件）")
            } footer: {
                if !store.questions.isEmpty {
                    Text("丸を押すと「聞いた」になります。星は大事な質問の印です。文を押すと直せます。長押しで並べ替え、左にスワイプで削除できます。")
                }
            }
        }
        .appBackground()
        .navigationTitle("健診予定")
        .toolbar {
            // 聞きたいことの一覧を文章で共有する（段階 D）。質問がなければ押せない。
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.sheet = .shareQuestions
                } label: {
                    Label("共有", systemImage: "square.and.arrow.up")
                }
                .disabled(store.questions.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.sheet = .settings
                } label: {
                    Label("設定", systemImage: "gearshape")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                UndoBar()
                // 「健診後メモを書く」を出さないときは、「＋ 質問を追加」を横いっぱいにする（R-20）。
                HStack(spacing: 10) {
                    Button {
                        router.sheet = .addQuestion
                    } label: {
                        Label("質問を追加", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    if let title = memoEntry.title {
                        Button {
                            startMemo()
                        } label: {
                            Text(title)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                // 押しやすいように大きめにして、左右の余白も詰める（段階 F）。
                .controlSize(.extraLarge)
                .font(.maru(.headline))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(AppColors.background)
            .animation(.default, value: store.pendingUndo)
        }
    }

    /// 健診後メモの入口（R-20）。次の健診の日付・丸を付けた質問・入力途中のメモのどれかがあるときだけ出す。
    private var memoEntry: MemoSheetRules.Entry {
        MemoSheetRules.entry(
            hasNextCheckup: store.nextCheckup != nil,
            hasAskedQuestion: store.questions.contains(where: \.isAsked),
            hasDraft: store.memoDraft != nil
        )
    }

    /// 健診後メモを書き始める。入力途中のメモを作ってから（あれば、それを使って）シートを開く（R-10、R-70）。
    private func startMemo() {
        let started = store.perform(saveFailureMessage: "健診後メモを書き始められませんでした。もう一度試してください。") {
            try $0.startMemoDraft(today: CalendarDay(.now), now: .now)
        }
        if started != nil {
            router.sheet = .writeMemo
        }
    }

    private func deleteQuestions(at offsets: IndexSet) {
        let ids = offsets.map { store.questions[$0].id }
        // 1 件ずつ消す。元に戻せるのは、最後に消した 1 件（R-60）。スワイプでは 1 件ずつしか消えない。
        for id in ids {
            store.perform { try $0.deleteQuestion(id: id) }
        }
    }
}

/// 聞きたいことの 1 行。丸（聞いた）・本文・補足・先生の答え・星。文のところを押すと、質問のシートを開く。
private struct QuestionRow: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    let question: Question

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.perform { try $0.setAsked(!question.isAsked, questionID: question.id) }
            } label: {
                Image(systemName: question.isAsked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(question.isAsked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question.isAsked ? "聞いた" : "聞く前")
            .accessibilityHint(question.isAsked ? "押すと聞く前に戻します" : "押すと聞いたにします")

            Button {
                router.sheet = .editQuestion(question.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    // 丸を付けても、その場に残して薄く出す（R-02）。
                    Text(question.text)
                        .foregroundStyle(question.isAsked ? .secondary : .primary)
                    if !question.note.isEmpty {
                        Text(question.note)
                            .font(.maru(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    if !question.answer.isEmpty {
                        Text("先生の答え：\(question.answer)")
                            .font(.maru(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // 文のない右側の余白を押しても開くようにする。
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("押すと、質問を直す画面を開きます")

            // 星は印だけ。付けても並びは変えない（R-03）。
            Button {
                store.perform { try $0.setStarred(!question.isStarred, questionID: question.id) }
            } label: {
                Image(systemName: question.isStarred ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(question.isStarred ? AppColors.star : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question.isStarred ? "星あり" : "星なし")
            .accessibilityHint(question.isStarred ? "押すと星を外します" : "押すと星を付けます")
        }
    }
}

/// 次の健診のカード（要件定義 v0.4 の 4 章）。
///
/// 日付が入っているときは、日時と「変更」、持ち物 n / m と「見る」。
/// 日付がないときも、同じ空色のカードの形で「まだ日付が入っていません」と［日付を入れる］を出す（段階 F）。
/// 入れる前と後でカードの場所と形が変わらないので、入れたあとに画面ががらっと変わらない。
/// 入れると何ができるか（お知らせ・健診後メモ）もカードの中で伝える（R-20 の入口に日付が要るため）。
private struct NextCheckupCard: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let next = store.nextCheckup, let day = next.day {
            Section {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("日時　\(day.displayText) \(next.hour):\(String(format: "%02d", next.minute))")
                            .font(.maru(.headline))
                        if let ageText = store.gestationalAgeText(on: day) {
                            Text("\(ageText)の健診")
                                .font(.maru(.subheadline))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("変更") {
                        router.sheet = .nextCheckup
                    }
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                }
                HStack(spacing: 8) {
                    Text("持ち物　\(checkedItemCount) / \(store.bringItems.count)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("見る") {
                        router.sheet = .bringItems
                    }
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                }
                if let input = store.reminderInput {
                    ReminderRow(input: input)
                }
            }
            .listRowBackground(AppColors.skyCard)
        } else {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    // 画面の名前（健診予定）と同じ言葉をくり返さず、いまの状態を見出しにする。
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.background))
                            .accessibilityHidden(true)
                        Text("まだ日付が入っていません")
                            .font(.maru(.headline))
                    }
                    Text("入れると、前日の夜にお知らせでき、健診後メモも書けます。")
                        .font(.maru(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        router.sheet = .nextCheckup
                    } label: {
                        Text("日付を入れる")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(AppColors.skyCard)
        }
    }

    private var checkedItemCount: Int {
        store.bringItems.filter(\.isChecked).count
    }
}

/// 次の健診のカードの、お知らせの行（要件定義 v0.4 の 4 章・5.4）。触れる見本と同じく、ベルの印と状態の文とスイッチ。
private struct ReminderRow: View {
    @Environment(NoteStore.self) private var store
    let input: ReminderInput

    @State private var isShowingPermissionAlert = false

    var body: some View {
        let status = ReminderStatus.make(input: input, authorization: authorization, now: .now)
        HStack(spacing: 8) {
            Image(systemName: "bell")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.text)
                    .font(.maru(.subheadline))
                // 予約に失敗したら隠さずに知らせる（R-45）。次に開いたとき・前面に戻ったときに、もう一度予約する（S-06）。
                if isScheduleFailureShown(status) {
                    Text("お知らせを予約できませんでした。アプリを開き直すと、もう一度予約します。")
                        .font(.maru(.caption))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(
                "前日の夜にお知らせ",
                isOn: Binding {
                    status.showsSwitchOn
                } set: { isOn in
                    setReminder(isOn)
                }
            )
            .labelsHidden()
            .disabled(!status.canToggle)
        }
        .notificationPermissionAlert(isPresented: $isShowingPermissionAlert)
    }

    private var authorization: ReminderAuthorization {
        store.reminders?.authorization ?? .notDetermined
    }

    private func isScheduleFailureShown(_ status: ReminderStatus) -> Bool {
        guard store.reminders?.lastScheduleFailed == true, case .on = status else {
            return false
        }
        return true
    }

    /// スイッチを切り替える。オンにするときは、通知の許可を確かめる（R-44）。
    private func setReminder(_ isOn: Bool) {
        guard let next = store.nextCheckup else {
            return
        }
        let hour = next.hour
        let minute = next.minute
        let input = input
        Task {
            var slot = input.slot
            if isOn {
                guard await ensureReminderPermission(store.reminders) else {
                    isShowingPermissionAlert = true
                    return
                }
                // 選んでいた時刻が過ぎていたら、選べるいちばん早い時刻にする。カードの文に新しい時刻が出る。
                switch ReminderTimeRule.adjust(slot, for: input.checkupDay, now: .now) {
                case .unchanged:
                    break
                case .moved(_, let to):
                    slot = to
                case .unavailable:
                    return
                }
            }
            store.perform {
                try $0.setNextCheckup(
                    day: input.checkupDay,
                    hour: hour,
                    minute: minute,
                    isReminderOn: isOn,
                    reminderSlot: slot
                )
            }
        }
    }
}
