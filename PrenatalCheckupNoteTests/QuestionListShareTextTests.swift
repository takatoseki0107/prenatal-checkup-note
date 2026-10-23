import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 共有・印刷する質問リストの文章（F-16）を確かめる。
struct QuestionListShareTextTests {
    @Test func numbersQuestionsInOrderAndAddsTheMemo() {
        let text = QuestionListShareText.make(
            dateText: "11月5日(木) 10:30",
            questions: ["腰の痛みについて相談する", "次回の検査の内容を確認する"],
            appointmentMemo: "持ち物：母子健康手帳\n"
        )

        #expect(text == """
            11月5日(木) 10:30 の健診で聞くこと

            1. 腰の痛みについて相談する
            2. 次回の検査の内容を確認する

            健診メモ
            持ち物：母子健康手帳
            """)
    }

    @Test func leavesOutAnEmptyMemo() {
        let text = QuestionListShareText.make(dateText: "11月5日(木) 10:30", questions: ["質問"], appointmentMemo: "  \n ")

        #expect(!text.contains("健診メモ"))
        #expect(text.hasSuffix("1. 質問"))
    }

    @Test func saysSoWhenThereAreNoQuestions() {
        let text = QuestionListShareText.make(dateText: "11月5日(木) 10:30", questions: [], appointmentMemo: "")

        #expect(text.contains("（聞くことはまだありません）"))
    }
}
