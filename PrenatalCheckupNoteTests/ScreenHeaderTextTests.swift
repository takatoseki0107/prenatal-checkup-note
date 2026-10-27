import Testing
@testable import PrenatalCheckupNote

/// 各タブの見出しの下に出す一言（段階 F）を確かめる。
struct ScreenHeaderTextTests {
    @Test func showsTodaysWeeksOrWhatTheScreenIsFor() {
        #expect(ScreenHeaderText.next(todayAgeText: "妊娠 20 週 2 日") == "今日は 妊娠 20 週 2 日")
        #expect(ScreenHeaderText.next(todayAgeText: nil) == "次の健診の予定と、聞きたいこと")
    }

    @Test func countsTodosUntilTheNextCheckupFirst() {
        #expect(ScreenHeaderText.todo(untilNextCheckupCount: 3, openCount: 4) == "次の健診までに 3 件")
        #expect(ScreenHeaderText.todo(untilNextCheckupCount: nil, openCount: 2) == "やること 2 件")
        #expect(ScreenHeaderText.todo(untilNextCheckupCount: 0, openCount: 1) == "やること 1 件")
        #expect(ScreenHeaderText.todo(untilNextCheckupCount: nil, openCount: 0) == "健診と健診の間にすること")
    }

    @Test func countsMemosOrSaysWhatTheScreenIsFor() {
        #expect(ScreenHeaderText.past(memoCount: 3) == "これまでのメモ 3 件")
        #expect(ScreenHeaderText.past(memoCount: 0) == "健診のあとに書いたメモ")
    }
}
