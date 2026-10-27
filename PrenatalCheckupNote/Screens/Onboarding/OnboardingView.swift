import SwiftUI

/// はじめに（要件定義 v0.4 の 4 章）。初めて開いたときだけ、画面いっぱいに出す。触れる見本と同じ形にする。
///
/// 出産予定日を入れる（わからなければ、いまの週数から計算する）。「あとで入れる」で飛ばせ、そのときは週数を出さない。
struct OnboardingView: View {
    @Environment(NoteStore.self) private var store

    @State private var entry = DueDateEntry()

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        Text("出産予定日を入れると、妊娠週数を表示し、次の健診の日付の目安を、時期に合った間隔で入れます。")
                    }
                    Section {
                        DueDateInputRows(entry: $entry)
                    } header: {
                        Text("出産予定日")
                    } footer: {
                        Text("入れなくても、すべての機能を使えます。あとから右上の設定で入れたり、直したりできます。記録はこの iPhone の中だけに保存します。")
                    }
                }
                // 行の地の色（ダークでも背景になじむ色。段階 F）。
                .listRowBackground(AppColors.card)
            }
            .appBackground()
            .navigationTitle("はじめに")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        finish(dueDate: entry.dueDate(today: CalendarDay(.now)))
                    } label: {
                        Text("はじめる")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    // 出産予定日が決まるまでは押せない（「あとで入れる」なら入れずに始められる）。
                    .disabled(entry.dueDate(today: CalendarDay(.now)) == nil)

                    Button("あとで入れる") {
                        finish(dueDate: nil)
                    }
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(AppColors.background)
                // 下の帯は、文字サイズ最大でも画面の多くを占めないよう、大きさに上限を付ける（段階 F2）。
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        // はじめにの上で起きた失敗は、はじめにの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    /// 「はじめに」を終える。終えると、一番下の画面がこの画面を閉じる。
    private func finish(dueDate: CalendarDay?) {
        store.perform { try $0.finishOnboarding(dueDate: dueDate) }
    }
}
