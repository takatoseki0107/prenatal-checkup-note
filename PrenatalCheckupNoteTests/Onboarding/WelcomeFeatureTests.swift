import Testing
@testable import PrenatalCheckupNote

/// はじめにの「ようこそ」（要件定義 5.11 の R-112）で紹介する、3 つのタブでできることを確かめる。
struct WelcomeFeatureTests {
    /// タブの並びと同じ順で、3 つのタブを 1 つずつ紹介する。見出しは画面のタブの名前と同じ。
    @Test func introducesTheThreeTabsInTabOrder() {
        #expect(WelcomeFeature.all.map(\.tab) == [.next, .todo, .past])
        #expect(WelcomeFeature.all.map(\.title) == ["健診予定", "タスク", "健診の記録"])
    }

    /// 見本で開発者と決めた箇条書き（健診予定 3 つ、タスク 2 つ、健診の記録 2 つ）。
    @Test func showsTheBulletsDecidedOnTheMock() {
        #expect(WelcomeFeature.all.map(\.bullets.count) == [3, 2, 2])
        #expect(WelcomeFeature.all[0].bullets.last == "前日の夜に、健診のお知らせが届く")
        #expect(WelcomeFeature.all[2].bullets.last == "ワードで検索して、簡単に見返せる")
    }

    /// 開発者が外すよう指摘した言い方を使っていない。
    @Test func avoidsWordingTheDeveloperAskedToDrop() {
        let text = WelcomeFeature.all.flatMap(\.bullets).joined()
        #expect(!text.contains("質問のお知らせ"))
        #expect(!text.contains("オレンジ"))
    }
}
