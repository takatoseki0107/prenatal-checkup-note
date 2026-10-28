import Testing
@testable import PrenatalCheckupNote

/// 「使い方」のシート（要件定義 5.12）に出す文を確かめる。
struct HelpContentTests {
    /// 上の切り替えは、タブの並びと同じ順に 3 つのタブ、最後に困ったとき（R-117）。
    @Test func switchesBetweenTheThreeTabsAndTrouble() {
        #expect(HelpTopic.allCases.map(\.title) == ["健診予定", "タスク", "健診の記録", "困ったとき"])
    }

    /// 3 つのタブには、番号つきの手順が 4 つずつと、ひとことのコツがある（R-118）。
    @Test func eachTabHasFourStepsAndATip() {
        for topic in [HelpTopic.next, .todo, .past] {
            #expect(HelpContent.steps(for: topic).count == 4)
            #expect(HelpContent.tip(for: topic) != nil)
        }
    }

    /// 健診予定の手順は、見本で開発者と決めた順（書き留める → 次の健診 → 丸 → メモ）。
    @Test func nextCheckupStepsFollowTheMock() {
        #expect(HelpContent.steps(for: .next).map(\.title) == [
            "質問を書き留める",
            "次の健診を入れる",
            "診察中は丸を付ける",
            "診察のあとにメモを書く",
        ])
    }

    /// 困ったときは、手順ではなく問いと答えが 5 つ（R-119）。
    @Test func troubleShowsFiveQuestions() {
        #expect(HelpContent.steps(for: .trouble).isEmpty)
        #expect(HelpContent.tip(for: .trouble) == nil)
        #expect(HelpContent.questions.count == 5)
        #expect(HelpContent.questions.contains { $0.answer.contains("アプリを消すと、記録も消えます") })
    }
}
