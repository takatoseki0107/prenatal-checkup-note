import SwiftUI

/// 設定（要件定義 v0.4 の 4 章「シート」の設定）。右上の歯車から開く。触れる見本と同じ形にする。
///
/// 出産予定日（直接、またはいまの週数から計算）・「妊娠週数を表示する」・「出産予定日を消す」。
/// 「保存」ボタン式で、書きかけは残さない。開発用ビルドでは、開発用の切り替えもここに置く。
struct SettingsView: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var entry = DueDateEntry()
    @State private var showsGestationalAge = true
    @State private var hasLoaded = false
    /// 保存した・予定日を消したあとか。閉じる間に「変更あり」としないため。
    @State private var isClosing = false
    @State private var isConfirmingCancel = false

    var body: some View {
        NavigationStack {
            Form {
                Section("出産予定日") {
                    DueDateInputRows(entry: $entry)
                }
                Section {
                    Toggle("妊娠週数を表示する", isOn: $showsGestationalAge)
                } footer: {
                    Text("オフにすると、週数はどこにも表示しません。次の健診の日付の目安には使います。予定日は、健診で変わったら直してください。")
                }
                if store.dueDate != nil {
                    Section {
                        Button("出産予定日を消す", role: .destructive) {
                            clearDueDate()
                        }
                    } footer: {
                        Text("消したあと、画面の下の「元に戻す」で戻せます。")
                    }
                }
                #if DEBUG
                DeveloperSection()
                #endif
            }
            .appBackground()
            .navigationTitle("設定")
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
                    .disabled(!hasChanges)
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

    // MARK: - 値

    private var today: CalendarDay {
        CalendarDay(.now)
    }

    /// 保存する出産予定日。入力でまだ決まっていなければ、いまの予定日のまま。
    private var dueDateToSave: CalendarDay? {
        entry.dueDate(today: today) ?? store.dueDate
    }

    private var hasChanges: Bool {
        guard hasLoaded, !isClosing else {
            return false
        }
        return dueDateToSave != store.dueDate || showsGestationalAge != store.showsGestationalAge
    }

    // MARK: - 操作

    private func load() {
        guard !hasLoaded else {
            return
        }
        entry = DueDateEntry(mode: .date, date: store.dueDate)
        showsGestationalAge = store.showsGestationalAge
        hasLoaded = true
    }

    private func save() {
        let dueDate = dueDateToSave
        let shows = showsGestationalAge
        let result: Void? = store.perform {
            try $0.updateSettings(dueDate: dueDate, showsGestationalAge: shows)
        }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }

    /// 出産予定日を消す。触れる見本と同じく、消したら設定を閉じ、画面の下の帯で戻せるようにする。
    private func clearDueDate() {
        let result: Void? = store.perform { try $0.clearDueDate() }
        if result != nil {
            isClosing = true
            dismiss()
        }
    }
}
