import SwiftUI

/// タブ「やること」（要件定義 v0.4 の 5.10、R-100〜R-106）。触れる見本 `Todo.dc.html` と同じ並びにする。
///
/// 一覧は見出しごと：いちばん上に「期限なし」、次に「期限を過ぎた」、そのあと期限の日ごと（並べ方は `TodoList`）。
/// 丸を押すと緑のチェックが付いてその場に残り、下の「チェックした n 件を完了にする」で「完了したこと」に移る（2 段階、R-104）。
/// 各行の星の下の「直す」で、足すときと同じシートを開く。左にスワイプで削除し、元に戻すの帯で戻せる（R-105）。
/// 健診予定のカードの「見る」から開いたときは、次の健診までのやることだけに絞り、上の帯のボタン（「ほかのやること（n 件）も表示」）で戻す（R-111）。
struct TodoScreen: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    /// 「完了したこと」を開いているか。最初はたたんでおく（R-104）。
    @State private var showsCompleted = false
    /// 見出しが隠れて、上の帯に題名を出しているか。
    @State private var isShowingInlineTitle = false

    var body: some View {
        let today = CalendarDay(.now)
        let nextCheckupDay = store.nextCheckup?.day
        let entries = store.todos.map(\.listEntry)
        // 絞り込むのは、次の健診の日付があるときだけ（R-111）。
        let narrowingDay = router.showsTodosUntilNextCheckup ? nextCheckupDay : nil
        let shown = narrowingDay.map { TodoList.untilNextCheckup(entries, nextCheckupDay: $0) } ?? entries
        let sections = TodoList.sections(shown, today: today, nextCheckupDay: nextCheckupDay)
        let completed = TodoList.completed(entries)
        let checkedCount = TodoList.checkedCount(entries)

        List {
            Section {
                ScreenHeader(
                    kind: .todo,
                    title: "やること",
                    subtitle: ScreenHeaderText.todo(
                        untilNextCheckupCount: TodoList.nextCheckupSummary(entries, today: today, nextCheckupDay: nextCheckupDay)?.count,
                        openCount: entries.filter { !$0.isCompleted }.count
                    )
                )
            }
            .listSectionSpacing(.compact)

            if let narrowingDay {
                narrowingBanner(
                    day: narrowingDay,
                    count: shown.count,
                    buttonTitle: TodoList.showOthersButtonTitle(entries, nextCheckupDay: narrowingDay)
                )
            } else if entries.isEmpty {
                Section {
                    Text("やることはまだありません。先生に言われた申請や、産院への連絡などを「＋ やることを足す」で書いておきましょう。")
                        .foregroundStyle(.secondary)
                }
                // 行の地の色（ダークでも背景になじむ色。段階 F）。
                .listRowBackground(AppColors.card)
            }

            ForEach(sections, id: \.kind) { section in
                sectionView(section, today: today)
            }

            // 絞り込んでいる間は、完了したことは出さない（次の健診までのやることだけを見せるため）。
            if narrowingDay == nil, !completed.isEmpty {
                completedSection(completed)
            }

            if narrowingDay == nil, !entries.isEmpty {
                Section {
                } footer: {
                    Text("丸を押すと緑のチェックが付きます。下の「完了にする」で「完了したこと」に移ります。「直す」で期限などを直せます。左にスワイプで削除できます。")
                }
            }
        }
        // 1 件ずつを、間を空けた丸いカードにする（ほかの画面と同じ。段階 F）。
        .listRowSpacing(10)
        .appBackground()
        .onScrolledPastHeader { isShowingInlineTitle = $0 }
        .screenHeaderTitle("やること", isShown: isShowingInlineTitle)
        .toolbar {
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
                VStack(spacing: 8) {
                    // チェックが 1 つ以上あるときだけ出す（R-104）。
                    if checkedCount > 0 {
                        Button {
                            store.perform { try $0.completeCheckedTodos(now: .now) }
                        } label: {
                            Label(TodoList.completeButtonTitle(checkedCount: checkedCount), systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(AppColors.check)
                    }
                    Button {
                        router.sheet = .addTodo
                    } label: {
                        Label("やることを足す", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                // ボタンの文字の色。ダークでは明るい青のボタンになるので、白ではなく濃い紺にする（段階 F）。
                .foregroundStyle(AppColors.onAccent)
                // 押しやすいように大きめにする（健診予定の下のボタンと同じ。段階 F）。
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
            .animation(.default, value: checkedCount)
        }
        // ほかのタブに移ったら、絞り込みをやめる。次にタブから開いたときは、すべてを出す。
        .onChange(of: router.selectedTab) { _, tab in
            if tab != .todo {
                router.showsTodosUntilNextCheckup = false
            }
        }
    }

    /// 絞り込んでいるときに一覧の上に出す帯（R-111）。何に絞っているかと数、絞り込みをやめるボタン。
    private func narrowingBanner(day: CalendarDay, count: Int, buttonTitle: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // 数だけが次の行に回って読みにくくならないよう、数は文と分けて右に大きく出す。
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(TodoList.untilNextCheckupTitle(nextCheckupDay: day))
                        .font(.maru(.headline))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(count) 件")
                        .font(.maru(.title3).weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .fixedSize()
                }
                .accessibilityElement(children: .combine)
                if count == 0 {
                    Text("次の健診までのやることは、もうありません。")
                        .font(.maru(.subheadline))
                        .foregroundStyle(.secondary)
                }
                Button {
                    withAnimation {
                        router.showsTodosUntilNextCheckup = false
                    }
                } label: {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppColors.skyCard)
    }

    /// 見出し 1 つ分。次の健診の線は、見出しのない 1 行にする。
    @ViewBuilder
    private func sectionView(_ section: TodoList.Section, today: CalendarDay) -> some View {
        if case .nextCheckupLine = section.kind {
            Section {
                NextCheckupLine(title: section.title)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .listSectionSpacing(.compact)
        } else {
            Section {
                ForEach(section.entries) { entry in
                    TodoRow(entry: entry, today: today)
                        .listRowSeparator(.hidden)
                        // 左にスワイプで削除。大きくスワイプすると、そのまま削除する（R-105）。確認は出さず、元に戻すの帯で戻せる。
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("削除", role: .destructive) {
                                store.perform { try $0.deleteTodo(id: entry.id) }
                            }
                        }
                }
            } header: {
                SectionHeader(section: section, today: today)
            }
            // 行の地の色（ダークでも背景になじむ色。段階 F）。
            .listRowBackground(AppColors.card)
        }
    }

    /// 「完了したこと（n 件）」。見出しを押すと開く・たたむ（R-104）。
    private func completedSection(_ completed: [TodoList.Entry]) -> some View {
        Section {
            if showsCompleted {
                ForEach(completed) { entry in
                    CompletedRow(entry: entry)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("削除", role: .destructive) {
                                store.perform { try $0.deleteTodo(id: entry.id) }
                            }
                        }
                }
            }
        } header: {
            Button {
                withAnimation {
                    showsCompleted.toggle()
                }
            } label: {
                HStack {
                    Text(TodoList.completedTitle(count: completed.count))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showsCompleted ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .font(.maru(.subheadline).weight(.semibold))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .textCase(nil)
            .accessibilityHint(showsCompleted ? "押すと、完了したことをたたみます" : "押すと、完了したことを開きます")
        }
        // 行の地の色（ダークでも背景になじむ色。段階 F）。
        .listRowBackground(AppColors.card)
    }
}

/// 見出し。「期限を過ぎた」はオレンジ、今日と次の健診の日は強調の色で出す。日付などを横に添える。
private struct SectionHeader: View {
    let section: TodoList.Section
    let today: CalendarDay

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(section.title)
                .font(.maru(.subheadline).weight(.semibold))
                .foregroundStyle(titleColor)
            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(.maru(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var titleColor: Color {
        switch section.kind {
        case .overdue:
            .orange
        case .day(let day, let isNextCheckupDay):
            isNextCheckupDay || day == today ? Color.accentColor : .primary
        case .noDue, .nextCheckupLine:
            .secondary
        }
    }
}

/// 「── 11月9日（月）は次の健診 ──」の線。その日のやることがないときだけ出す（R-103）。
private struct NextCheckupLine: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            line
            // 文は 1 行のまま出し、線のほうを短くする（両側の線に幅を取られて、文が 2 行に折り返していた）。
            Text(title)
                .font(.maru(.footnote).weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            line
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.35))
            .frame(minWidth: 12, maxWidth: .infinity)
            .frame(height: 1)
    }
}

/// やることの 1 行。左の丸（緑のチェック）・文・補足・期限を過ぎた日・どの健診から足したか・右に星と「直す」。
private struct TodoRow: View {
    @Environment(NoteStore.self) private var store
    @Environment(AppRouter.self) private var router
    let entry: TodoList.Entry
    let today: CalendarDay

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 押すと緑のチェックが付く・外れる。その場に残る（完了の 1 段階目、R-104）。
            Button {
                store.perform { try $0.setTodoChecked(!entry.isChecked, todoID: entry.id) }
            } label: {
                Image(systemName: entry.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    // 文字サイズが大きいとき、丸が大きくなりすぎて文の幅をせばめないよう、上限を付ける（段階 F2）。
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(entry.isChecked ? AppColors.check : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isChecked ? "チェックあり" : "チェックなし")
            .accessibilityHint(entry.isChecked ? "押すとチェックを外します" : "押すとチェックを付けます。下のボタンで完了にできます")

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.maru(.footnote))
                        .foregroundStyle(.secondary)
                }
                // 期限の日は見出しにあるので、行には出さない。期限を過ぎたものだけ出す（R-103）。
                if let dueText = TodoList.rowDueText(entry, today: today) {
                    Text(dueText)
                        .font(.maru(.footnote).weight(.semibold))
                        .foregroundStyle(.orange)
                }
                if let originText = TodoList.originText(entry) {
                    Text(originText)
                        .font(.maru(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                Button {
                    store.perform { try $0.setTodoStarred(!entry.isStarred, todoID: entry.id) }
                } label: {
                    Image(systemName: entry.isStarred ? "star.fill" : "star")
                        .font(.title3)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(entry.isStarred ? AppColors.star : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.isStarred ? "星あり" : "星なし")
                .accessibilityHint(entry.isStarred ? "押すと星を外します" : "押すと星を付けます")

                // 文・期限・補足・印を直す。削除もここからできる（R-101、R-105）。
                // 文字だけだと押しにくい（開発者の指摘）ので、枠のある丸いボタンにして、押せる範囲も広げる。
                // 印と文の間を詰め、ボタンの幅を小さくして、やることの文の幅をせばめないようにする。
                Button {
                    router.sheet = .editTodo(entry.id)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "pencil")
                        Text("直す")
                    }
                    .font(.maru(.caption).weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    // 見た目より少し広い範囲で押せるようにする。
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(-4)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel("「\(entry.title)」を直す")
            }
        }
    }
}

/// 「完了したこと」の 1 行。丸を押すと完了を取り消して一覧に戻す（R-104）。
private struct CompletedRow: View {
    @Environment(NoteStore.self) private var store
    let entry: TodoList.Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.perform { try $0.reopenTodo(id: entry.id) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完了")
            .accessibilityHint("押すと完了を取り消して、一覧に戻します")

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                if let originText = TodoList.originText(entry) {
                    Text(originText)
                        .font(.maru(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
