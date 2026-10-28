import Foundation

/// 各タブの見出しの下に出す一言（段階 F、題名の見た目の案 A＋C）。画面から切り離して、テストで確かめる。
///
/// その画面に何があるかを短く伝える。中身がまだないときは、その画面で何をするかを伝える。
nonisolated enum ScreenHeaderText {
    /// 健診予定。週数を出すときは「今日は 妊娠 20 週 2 日」（前にハートを付ける）。出さないときは画面の説明。
    static func next(todayAgeText: String?) -> String {
        todayAgeText.map { "今日は \($0)" } ?? "次の健診の予定と、聞きたいこと"
    }

    /// タスク。次の健診までのものがあればその数、なければ残っている数、何もなければ画面の説明。
    static func todo(untilNextCheckupCount: Int?, openCount: Int) -> String {
        if let untilNextCheckupCount, untilNextCheckupCount > 0 {
            return "次の健診までに \(untilNextCheckupCount) 件"
        }
        if openCount > 0 {
            return "タスク \(openCount) 件"
        }
        return "健診と健診の間にすること"
    }

    /// 健診の記録。メモがあればその数、なければ画面の説明。
    static func past(memoCount: Int) -> String {
        memoCount > 0 ? "これまでのメモ \(memoCount) 件" : "健診のあとに書いたメモ"
    }
}
