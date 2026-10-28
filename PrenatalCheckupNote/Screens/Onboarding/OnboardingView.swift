import SwiftUI

/// はじめに（要件定義 v0.4 の 4 章、5.11）。初めて開いたときだけ、画面いっぱいに出す。
///
/// 2 枚に分ける（5.11、キャンバスの見本の案 C）。1 枚目は「ようこそ」（`WelcomePage`）、2 枚目は出産予定日（`DueDatePage`）。
/// 1 枚の画面に文字と入力欄だけが並んでいて殺風景だった（開発者の意見）ので、見本の 3 案から開発者が選んだ。
/// 「つぎへ」と戻るボタンのほか、横のスワイプでも行き来できる（R-114）。
/// 出産予定日は入れなくてもよく、「あとで入れる」で飛ばせる。そのときは週数を出さない。
struct OnboardingView: View {
    @Environment(NoteStore.self) private var store

    @State private var page = 0
    @State private var entry = DueDateEntry()

    var body: some View {
        TabView(selection: $page) {
            WelcomePage(buttonTitle: "つぎへ") {
                withAnimation { page = 1 }
            }
            .tag(0)

            DueDatePage(entry: $entry) {
                withAnimation { page = 0 }
            } finish: { dueDate in
                finish(dueDate: dueDate)
            }
            .tag(1)
        }
        // 横のスワイプで移れる形。下の点は自分で描くので、標準の点は出さない。
        .tabViewStyle(.page(indexDisplayMode: .never))
        // 画面のいちばん上（時刻の帯の後ろ）といちばん下（ホームのバーの後ろ）の色。
        // 横にめくる形の中身は、上下のはしまで届かないので、ここで塗る。上は 1 枚目なら空色、下はいつも地の色にする
        // （1 枚目の上が地の色の帯になっていた。シミュレーターで見つけた）。
        .background {
            VStack(spacing: 0) {
                page == 0 ? AppColors.welcomeSky : AppColors.background
                AppColors.background
            }
            .ignoresSafeArea()
        }
        // はじめにの上で起きた失敗は、はじめにの上で知らせる（ADR 0009）。
        .noteErrorAlert(store)
    }

    /// 「はじめに」を終える。終えると、一番下の画面がこの画面を閉じる。
    private func finish(dueDate: CalendarDay?) {
        store.perform { try $0.finishOnboarding(dueDate: dueDate) }
    }
}
