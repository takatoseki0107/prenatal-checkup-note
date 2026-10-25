import Testing
@testable import PrenatalCheckupNote

/// 文章で共有するときの文（段階 D）を確かめる。
struct ShareTextTests {
    // MARK: - 聞きたいことの一覧

    @Test func listsQuestionsWithNumbersStarsNotesAndAnswers() {
        let text = ShareText.questionList(
            nextCheckup: "11月8日（日） 10:30（妊娠 24 週 0 日）",
            questions: [
                .init(text: "腰が痛いときに気をつけること", note: "夜に痛む", isStarred: true),
                .init(text: "鉄分のとり方", answer: "レバーかサプリ"),
            ]
        )

        #expect(text == """
            次の健診で聞きたいこと
            次の健診：11月8日（日） 10:30（妊娠 24 週 0 日）
            （★は大事な質問）

            1. ★腰が痛いときに気をつけること
               補足：夜に痛む
            2. 鉄分のとり方
               先生の答え：レバーかサプリ
            """)
    }

    @Test func leavesOutWhatIsMissing() {
        // 次の健診の日付がない・星がない・補足と答えが空なら、その行を作らない。
        let text = ShareText.questionList(nextCheckup: nil, questions: [.init(text: "鉄分のとり方", note: "  \n")])

        #expect(text == """
            次の健診で聞きたいこと

            1. 鉄分のとり方
            """)
    }

    @Test func saysWhenThereAreNoQuestions() {
        let text = ShareText.questionList(nextCheckup: nil, questions: [])
        #expect(text.hasSuffix("（聞きたいことはまだありません）"))
    }

    @Test func indentsEveryLineOfALongNote() {
        // 補足が何行あっても、どの質問のものか分かるように字下げする。質問の文は 1 行にする。
        let text = ShareText.questionList(
            nextCheckup: nil,
            questions: [.init(text: "腰の痛み\nについて", note: "夜に痛む\n朝は平気")]
        )
        #expect(text.hasSuffix("""
            1. 腰の痛み について
               補足：夜に痛む
               朝は平気
            """))
    }

    // MARK: - 健診後メモ

    @Test func writesAMemo() {
        let text = ShareText.memo(
            title: "10月26日（月）の健診（妊娠 20 週 1 日）",
            body: "むくみは夕方に強くなる。\n足を高くして休む。\n",
            items: [
                .init(question: "足のむくみが気になる", answer: "塩分を控える"),
                .init(question: "運動してよいか"),
            ]
        )

        #expect(text == """
            10月26日（月）の健診（妊娠 20 週 1 日）

            先生から聞いたこと・次までにすること
            むくみは夕方に強くなる。
            足を高くして休む。

            この健診で聞いたこと
            1. 足のむくみが気になる
               先生の答え：塩分を控える
            2. 運動してよいか
               答えのメモなし
            """)
    }

    @Test func leavesOutAnEmptyBodyOrNoQuestions() {
        let onlyBody = ShareText.memo(title: "10月26日（月）の健診", body: "次は血液検査", items: [])
        #expect(!onlyBody.contains("この健診で聞いたこと"))

        let onlyItems = ShareText.memo(title: "10月26日（月）の健診", body: " ", items: [.init(question: "体重")])
        #expect(!onlyItems.contains("先生から聞いたこと"))
    }

    @Test func saysWhenTheMemoIsEmpty() {
        let text = ShareText.memo(title: "10月26日（月）の健診", body: "", items: [])
        #expect(text == """
            10月26日（月）の健診

            （メモの中身はありません）
            """)
    }
}
