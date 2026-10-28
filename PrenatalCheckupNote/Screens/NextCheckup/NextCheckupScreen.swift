import SwiftUI

/// タブ 1「健診予定」（要件定義 v0.4 の 4 章。段階 F で「次の健診」から名前を変えた）。
///
/// いちばん上に見出し（`ScreenHeader`）、次の健診のカード、その下に「聞きたいこと」の一覧、画面の下に「＋ 質問を追加」「健診後メモを書く」。
/// 行を押すと質問のシートを開く。出産予定日があれば、見出しの一言に今日の妊娠週数を出す（R-51）。
/// カードの 3 行目は、前日の夜のお知らせとスイッチ（段階 C）。
/// 持ち物とお知らせの間に、次の健診までのやることの数を出す（R-110。0 件なら出さない）。
struct NextCheckupScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 見出しが隠れて、上の帯に題名を出しているか。
    @State private var isShowingInlineTitle = false

    var body: some View {
        List {
            // 見出し（題名・印・一言）。週数を出すときは、一言を「♡ 今日は 妊娠 n 週 n 日」にする（R-51）。
            Section {
                let todayAgeText = store.gestationalAgeText(on: CalendarDay(.now))
                ScreenHeader(
                    kind: .next,
                    title: "健診予定",
                    subtitle: ScreenHeaderText.next(todayAgeText: todayAgeText),
                    showsHeart: todayAgeText != nil
                )
            }
            // 見出しと、すぐ下のカードの間を詰める。
            .listSectionSpacing(.compact)

            NextCheckupCard()

            Section {
                if store.questions.isEmpty {
                    Text("聞きたいことはまだありません。思いついたら「＋ 質問を追加」で書き留めておきましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.questions) { question in
                    QuestionRow(question: question)
                        .listRowSeparator(.hidden)
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
            // 行の地の色（ダークでも背景になじむ色。段階 F）。
            .listRowBackground(AppColors.card)
        }
        // 聞きたいことを 1 件ずつ、間を空けた丸いカードにする（段階 F）。
        // 行ごとに Section を分けると長押しの並べ替え（`onMove`）が使えなくなるので、行の間を空ける形にしている。
        // このため、健診予定のカードは 1 つの行にまとめている（`NextCheckupCard`）。
        .listRowSpacing(10)
        .appBackground()
        .onScrolledPastHeader { isShowingInlineTitle = $0 }
        .screenHeaderTitle("健診予定", isShown: isShowingInlineTitle)
        .toolbar {
            // 使い方（5.12、R-116）。右上のいちばん左に置く。
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.sheet = .help(.next)
                } label: {
                    Label("使い方", systemImage: "questionmark.circle")
                }
            }
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
                buttonLayout {
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
                // ボタンの文字の色。ダークでは明るい青のボタンになるので、白ではなく濃い紺にする（段階 F）。
                .foregroundStyle(AppColors.onAccent)
                // 押しやすいように大きめにして、左右の余白も詰める（段階 F）。
                .controlSize(.extraLarge)
                .font(.maru(.headline))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(AppColors.background)
            // 下の帯は、文字サイズ最大でも画面の多くを占めないよう、大きさに上限を付ける（段階 F2）。
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .animation(.default, value: store.pendingUndo)
        }
    }

    /// 下の 2 つのボタンの並べ方。文字サイズがとても大きいときは、文字が切れないよう縦に並べる（段階 F2）。
    private var buttonLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
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
                    // 文字サイズが大きいとき、丸が大きくなりすぎて文の幅をせばめないよう、上限を付ける（段階 F2）。
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let next = store.nextCheckup, let day = next.day {
            Section {
                // 一覧の行の間を空けているので、カードの中身は 1 つの行にまとめ、区切りは自分で引く。
                // 上に大きな日付と「あと n 日」、真ん中に持ち物とタスクを左右に並べ、下にお知らせ（2026-10-28、見本 `NextCardLight.dc.html`）。
                // 開発者が見せてくれた画面の、使いやすさに効く部分だけを、いまの空色の見た目に取り入れた。
                VStack(spacing: 0) {
                    topLayout {
                        dateTile(day)
                        VStack(alignment: .leading, spacing: 4) {
                            // 「あと n 日」は少し大きめにする（最初は小さくて目立たなかった。開発者の希望）。
                            Text(CheckupCountdown.text(today: CalendarDay(.now), checkupDay: day))
                                .font(.maru(.subheadline))
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(next.hour):\(String(format: "%02d", next.minute))")
                                    .font(.maru(.title))
                                    .fontWeight(.bold)
                                Text("から")
                                    .font(.maru(.subheadline))
                            }
                            if let ageText = store.gestationalAgeText(on: day) {
                                Text(ageText)
                                    .font(.maru(.caption))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.card))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 読み上げでは、日付・時刻・日数・週数を 1 つにまとめて読む。
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityText(day: day, next: next))
                        Button("変更") {
                            router.sheet = .nextCheckup
                        }
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .padding(.vertical, 12)

                    CardLine()
                    shortcutLayout {
                        Button {
                            router.sheet = .bringItems
                        } label: {
                            shortcutLabel(systemImage: "bag", title: "持ち物 \(checkedItemCount) / \(store.bringItems.count)", note: nil, action: "変更")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("持ち物を見る。\(checkedItemCount) / \(store.bringItems.count)")
                        // 次の健診までのタスクの数（R-110）。0 件なら出さない。
                        // 押すと「タスク」のタブに移り、数えたものだけに絞って見せる（R-111）。
                        if let summary = TodoList.nextCheckupSummary(
                            store.todos.map(\.listEntry),
                            today: CalendarDay(.now),
                            nextCheckupDay: day
                        ) {
                            shortcutSeparator
                            Button {
                                router.showsTodosUntilNextCheckup = true
                                router.selectedTab = .todo
                            } label: {
                                shortcutLabel(systemImage: "checklist", title: summary.shortTitle, note: summary.overdueText, action: "見る")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(["タスクを見る", summary.title, summary.overdueText].compactMap { $0 }.joined(separator: "。"))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    if let input = store.reminderInput {
                        CardLine()
                        ReminderRow(input: input)
                            .padding(.vertical, 10)
                    }
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
                            .background(Circle().fill(AppColors.card))
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
                    // ボタンの文字の色。ダークでは明るい青のボタンになるので、白ではなく濃い紺にする（段階 F）。
                    .foregroundStyle(AppColors.onAccent)
                    .controlSize(.large)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(AppColors.skyCard)
        }
    }

    /// カードの上の並べ方。文字サイズがとても大きいときは、日付・時刻・「変更」を横に並べず縦に積む（段階 F2 と同じ考え方）。
    private var topLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
    }

    /// 持ち物とタスクの並べ方。文字サイズがとても大きいときは、左右ではなく上下に並べる。
    private var shortcutLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
    }

    /// 持ち物とタスクの間の線。左右に並べるときは縦の線、上下に並べるときは横の線。
    /// `Divider` は `AnyLayout` の中だと向きが決まらないことがあるので、線を自分で引く。
    private var shortcutSeparator: some View {
        CardLine(isVertical: !typeSize.isAccessibilitySize)
    }

    /// 左の大きな日付（例：「11月」「11」「水曜日」）。
    private func dateTile(_ day: CalendarDay) -> some View {
        VStack(spacing: 0) {
            Text("\(day.month)月")
                .font(.maru(.caption))
            Text("\(day.day)")
                .font(.custom(AppFonts.maruName, size: 34, relativeTo: .largeTitle))
                .fontWeight(.bold)
            Text(day.weekdayName)
                .font(.maru(.caption))
        }
        .foregroundStyle(Color.accentColor)
        .frame(width: 76, height: 90)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppColors.card))
        // 四角の大きさは決まっているので、文字が大きくなりすぎてはみ出さないようにする。
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityHidden(true)
    }

    /// 持ち物・タスクのボタンの中身。上に印と文、その下に小さな注意（期限を過ぎたものの数）、いちばん下に「変更 ›」「見る ›」。
    /// 押せることがわかるよう、日時の「変更」と同じ青い文字を添える（開発者の指摘）。
    /// 最初は右はしに並べたが、半分の幅では文が「持ち物 1 /」「3」のように折り返して崩れた（実機で見つけた）ので、縦に積む。
    private func shortcutLabel(systemImage: String, title: String, note: String?, action: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(.primary)
            }
            .font(.maru(.callout))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            if let note {
                Text(note)
                    .font(.maru(.caption2).weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 2) {
                Text(action)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            .font(.maru(.footnote))
            .fontWeight(.semibold)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    /// 読み上げの文。例：「11月11日（水） 10:30 から。次の健診まで、あと 14 日。妊娠 26 週 3 日」。
    private func accessibilityText(day: CalendarDay, next: NextCheckup) -> String {
        var parts = [
            "\(day.displayText) \(next.hour):\(String(format: "%02d", next.minute)) から",
            CheckupCountdown.text(today: CalendarDay(.now), checkupDay: day),
        ]
        if let ageText = store.gestationalAgeText(on: day) {
            parts.append(ageText)
        }
        return parts.joined(separator: "。")
    }

    private var checkedItemCount: Int {
        store.bringItems.filter(\.isChecked).count
    }
}

/// 健診予定のカードの中の区切りの線。
///
/// 標準の区切り線は、空色のカードの上（特にダークモード）では細く薄くて見えにくかった（開発者の指摘）ので、
/// 文字の色を少し混ぜた、はっきりした線を引く。ライトでは濃い色、ダークでは白っぽい線になる。
private struct CardLine: View {
    var isVertical = false

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
            .accessibilityHidden(true)
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
