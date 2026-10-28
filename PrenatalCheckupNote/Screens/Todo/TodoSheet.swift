import SwiftUI

/// タスクを追加・直すシート（要件定義 v0.4 の 5.10、R-101、R-102、R-105）。
///
/// 「＋ タスクを追加」で「タスクを追加」、各行の「直す」で「タスクを直す」として開く。
/// 期限はボタン（期限なし・今日・明日・次の健診まで・1 週間後・日付を選ぶ）で選び、選んだ期限をすぐ下に文で見せる。
/// 期限には選んだときの日付をそのまま入れる（ADR 0012）。直すときは、削除もここからできる（確認なし、元に戻すの帯で戻せる）。
/// 書きかけは残さない（「追加」「保存」を押したときだけ保存する）。
/// 健診後メモの画面の「＋ タスクを追加」からは、そのメモの受診日と ID を持って開く（R-107）。
struct TodoSheet: View {
    nonisolated enum Mode: Equatable {
        case add
        case edit(UUID)
        /// 健診後メモ（または書きかけ）から足す。足したやることには「◯月◯日の健診で」と出る。
        case addFromMemo(memoID: UUID, visitDay: CalendarDay)
    }

    let mode: Mode

    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var isStarred = false
    @State private var choice: TodoDueChoice = .noDue
    /// 「日付を選ぶ」で選んだ日。
    @State private var pickedDay: CalendarDay?
    /// シートを開いたときの今日。開いている間に日付が変わっても、ボタンの意味が変わらないように固定する。
    @State private var today = CalendarDay(.now)
    @State private var hasLoaded = false
    /// 保存・削除して閉じる途中か。閉じる間に「見つかりませんでした」を出さないため。
    @State private var isClosing = false
    @State private var isConfirmingCancel = false

    var body: some View {
        NavigationStack {
            Group {
                if !isEditing || todo != nil || isClosing {
                    form
                } else {
                    ContentUnavailableView(
                        "このタスクは見つかりませんでした",
                        systemImage: "checklist",
                        description: Text("削除された可能性があります。")
                    )
                }
            }
            .navigationTitle(isEditing ? "タスクを直す" : "タスクを追加")
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
                    Button(isEditing ? "保存" : "追加") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .alert(isEditing ? "変更を破棄しますか？" : "入力した内容を破棄しますか？", isPresented: $isConfirmingCancel) {
                Button("編集を続ける", role: .cancel) {}
                Button("破棄", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text(isEditing ? "保存していない変更は消えます。" : "追加していない内容は消えます。")
            }
        }
        // 入力した内容があるときは、下にスワイプしても閉じない。
        .interactiveDismissDisabled(hasChanges)
        // シートの上で起きた失敗は、シートの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    private var form: some View {
        Form {
            Group {
                Section {
                    TextField("例：母親学級の申し込み", text: $title, axis: .vertical)
                        .accessibilityIdentifier("todoTitleField")
                } header: {
                    VStack(alignment: .leading, spacing: 10) {
                        // 健診後メモから開いたときは、どの健診で言われたこととして足すかを先に見せる（R-107）。
                        if let memoVisitDay {
                            Text("\(memoVisitDay.month)月\(memoVisitDay.day)日の健診で言われたこととして追加します")
                                .font(.maru(.footnote))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                .textCase(nil)
                        }
                        Text("タスク")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chipRows, id: \.self) { row in
                            chipRow(row)
                        }
                    }
                    .padding(.vertical, 4)
                    // 選んだ期限を文で見せる（R-102）。
                    Text(choice.summary(today: today, nextCheckupDay: nextCheckupDay, pickedDay: pickedDay))
                        .font(.maru(.subheadline).weight(.semibold))
                        .foregroundStyle(choice.isWaitingForDate(pickedDay: pickedDay) ? Color.orange : Color.accentColor)
                    if choice == .pickDate {
                        DatePicker("期限の日", selection: pickedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            // 日付はグレゴリオ暦・日本時間で決める（R-90）。
                            .environment(\.calendar, .japan)
                            .environment(\.timeZone, Calendar.japan.timeZone)
                    }
                } header: {
                    Text("期限")
                } footer: {
                    Text("期限には、選んだ日付が入ります。あとで次の健診の日付を変えても、期限は変わりません。")
                }

                Section("補足（任意）") {
                    TextField("例：平日 14 時〜16 時に電話", text: $note, axis: .vertical)
                }

                Section {
                    Button {
                        isStarred.toggle()
                    } label: {
                        Label {
                            Text(isStarred ? "大事な印を付けました" : "大事な印を付ける")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: isStarred ? "star.fill" : "star")
                                .foregroundStyle(isStarred ? AppColors.star : .secondary)
                        }
                    }
                    .accessibilityAddTraits(isStarred ? .isSelected : [])
                }

                if isEditing {
                    Section {
                        Button("このタスクを削除する", role: .destructive) {
                            delete()
                        }
                    } footer: {
                        Text("削除したあと、画面の下の「元に戻す」で戻せます。")
                    }
                }
            }
            // 行の地の色（ダークでも背景になじむ色。段階 F）。
            .listRowBackground(AppColors.card)
        }
        .appBackground()
        // キーボードを閉じる「完了」と、引っぱって閉じる動き（段階 F）。
        .keyboardDismissTools()
    }

    // MARK: - 期限のボタン

    /// ボタンの並び。1 行目に短いもの、2 行目に「次の健診まで（◯月◯日）」と「日付を選ぶ」。
    private var chipRows: [[TodoDueChoice]] {
        let available = TodoDueChoice.available(today: today, nextCheckupDay: nextCheckupDay)
        let first: [TodoDueChoice] = [.noDue, .today, .tomorrow, .oneWeek]
        return [
            available.filter { first.contains($0) },
            available.filter { !first.contains($0) },
        ]
    }

    /// 1 行に並べる。入りきらないとき（文字が大きいときなど）は縦に積む。
    private func chipRow(_ row: [TodoDueChoice]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(row, id: \.self) { chip($0) }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(row, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ item: TodoDueChoice) -> some View {
        let isSelected = choice == item
        return Button {
            select(item)
        } label: {
            Text(item.label(nextCheckupDay: nextCheckupDay))
                .font(.maru(.subheadline))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? AppColors.onAccent : Color.accentColor)
                .background(Capsule().fill(isSelected ? Color.accentColor : Color.clear))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.accentColor.opacity(0.45)))
                .contentShape(Capsule())
        }
        // 1 つの行に並べたボタンが、それぞれ別に押せるようにする（行全体が 1 つのボタンにならないように）。
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ item: TodoDueChoice) {
        choice = item
        // 「日付を選ぶ」を押したら、カレンダーは今日を選んだ状態で開く（SwiftUI のカレンダーは、選んだ日なしでは出せないため）。
        if item == .pickDate, pickedDay == nil {
            pickedDay = today
        }
    }

    /// カレンダーで選んだ日。日本時間の正午として渡し、受け取るときに日付だけにする。
    private var pickedDate: Binding<Date> {
        Binding {
            (pickedDay ?? today).date(hour: 12)
        } set: { newDate in
            pickedDay = CalendarDay(newDate)
        }
    }

    // MARK: - 状態

    private var isEditing: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    /// 健診後メモから開いたときの、そのメモの受診日。ほかから開いたときは `nil`。
    private var memoVisitDay: CalendarDay? {
        if case .addFromMemo(_, let visitDay) = mode {
            return visitDay
        }
        return nil
    }

    private var todo: TodoItem? {
        guard case .edit(let id) = mode else {
            return nil
        }
        return store.todos.first { $0.id == id }
    }

    /// 「次の健診まで」に使う日。健診後メモから開いたときは、いま書いている健診の日なら使わない（R-107）。
    private var nextCheckupDay: CalendarDay? {
        let day = store.nextCheckup?.day
        guard let memoVisitDay else {
            return day
        }
        return TodoDueChoice.offeredNextCheckupDay(day, memoVisitDay: memoVisitDay)
    }

    /// いま選んでいる期限の日。
    private var dueDay: CalendarDay? {
        choice.dueDay(today: today, nextCheckupDay: nextCheckupDay, pickedDay: pickedDay)
    }

    private var canSave: Bool {
        guard choice.canSave(title: title, pickedDay: pickedDay) else {
            return false
        }
        return !isEditing || hasChanges
    }

    /// 保存していない入力があるか。足すときは何か入れたか、直すときは保存されている内容と違うか。
    private var hasChanges: Bool {
        guard hasLoaded, !isClosing else {
            return false
        }
        if isEditing {
            guard let todo else {
                return false
            }
            return todo.title != title || todo.note != note || todo.isStarred != isStarred || todo.dueDay != dueDay
        }
        return InputText.normalized(title) != nil || InputText.normalized(note) != nil || isStarred || choice != .noDue
    }

    // MARK: - 操作

    private func load() {
        guard !hasLoaded else {
            return
        }
        if let todo {
            title = todo.title
            note = todo.note
            isStarred = todo.isStarred
            choice = TodoDueChoice.initial(for: todo.dueDay, today: today, nextCheckupDay: nextCheckupDay)
            pickedDay = choice == .pickDate ? todo.dueDay : nil
        }
        hasLoaded = true
    }

    private func save() {
        let title = title
        let note = note
        let dueDay = dueDay
        let isStarred = isStarred
        let result: Void?
        switch mode {
        case .add:
            result = store.perform { try $0.addTodo(title: title, note: note, dueDay: dueDay, isStarred: isStarred, now: .now) }
                .map { _ in () }
        case .edit(let id):
            result = store.perform { try $0.updateTodo(id: id, title: title, note: note, dueDay: dueDay, isStarred: isStarred) }
        case .addFromMemo(let memoID, let visitDay):
            result = store.perform {
                try $0.addTodo(
                    title: title,
                    note: note,
                    dueDay: dueDay,
                    isStarred: isStarred,
                    originVisitDay: visitDay,
                    originMemoID: memoID,
                    now: .now
                )
            }
            .map { _ in () }
        }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }

    private func delete() {
        guard case .edit(let id) = mode else {
            return
        }
        let result: Void? = store.perform { try $0.deleteTodo(id: id) }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }
}
