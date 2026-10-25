import Foundation
import Testing
@testable import PrenatalCheckupNote

/// これまでの健診の検索の決まり（段階 D）を確かめる。
struct MemoSearchTests {
    private let firstID = UUID()
    private let secondID = UUID()

    private func document(
        id: UUID,
        body: String = "",
        items: [MemoSearch.Document.Item] = []
    ) -> MemoSearch.Document {
        MemoSearch.Document(id: id, body: body, items: items)
    }

    private func item(_ question: String, note: String = "", answer: String = "") -> MemoSearch.Document.Item {
        MemoSearch.Document.Item(question: question, note: note, answer: answer)
    }

    // MARK: - 言葉の分け方

    @Test func splitsTheQueryBySpaces() {
        #expect(MemoSearch.terms(from: "むくみ 足") == ["むくみ", "足"])
        // 全角の空白・続いた空白・前後の空白も区切りとして扱う。
        #expect(MemoSearch.terms(from: "　むくみ　　足 ") == ["むくみ", "足"])
    }

    @Test func doesNotSearchWithoutWords() {
        let documents = [document(id: firstID, body: "腰が痛い")]
        #expect(MemoSearch.search("", in: documents) == nil)
        #expect(MemoSearch.search("　 ", in: documents) == nil)
    }

    // MARK: - 当たり方

    @Test func findsPartOfTheText() {
        let documents = [
            document(id: firstID, body: "腰が痛いときは横向きで休む"),
            document(id: secondID, body: "鉄分のとり方"),
        ]
        let results = MemoSearch.search("横向き", in: documents)
        #expect(results?.map(\.id) == [firstID])
    }

    @Test func ignoresHiraganaKatakanaWidthAndCase() {
        let documents = [document(id: firstID, body: "ムクミが出たら、ＮＳＴで確認。Ｃ型")]

        #expect(MemoSearch.search("むくみ", in: documents)?.count == 1)
        #expect(MemoSearch.search("nst", in: documents)?.count == 1)
        #expect(MemoSearch.search("c型", in: documents)?.count == 1)
        #expect(MemoSearch.search("ﾑｸﾐ", in: documents)?.count == 1)
    }

    @Test func doesNotMixKanjiAndKana() {
        // 漢字と読みがなは別の文字なので、「こし」では「腰」は探せない（決まりのとおり）。
        let documents = [document(id: firstID, body: "腰が痛い")]
        #expect(MemoSearch.search("こし", in: documents)?.isEmpty == true)
    }

    @Test func needsAllWords() {
        let documents = [
            document(id: firstID, body: "足のむくみ"),
            document(id: secondID, body: "顔のむくみ"),
        ]
        #expect(MemoSearch.search("むくみ 足", in: documents)?.map(\.id) == [firstID])
    }

    @Test func wordsMayBeInDifferentPlaces() {
        // 言葉ごとに、別の場所（本文と先生の答え）に含まれていてもよい。
        let documents = [
            document(id: firstID, body: "足がつる", items: [item("夜中に起きる", answer: "マグネシウムを多めに")]),
        ]
        #expect(MemoSearch.search("足 マグネシウム", in: documents)?.map(\.id) == [firstID])
    }

    @Test func searchesQuestionsNotesAndAnswers() {
        let documents = [
            document(id: firstID, items: [item("運動してよいか", note: "ヨガ教室", answer: "散歩から始める")]),
        ]
        #expect(MemoSearch.search("運動", in: documents)?.first?.snippet.label == "質問")
        #expect(MemoSearch.search("ヨガ", in: documents)?.first?.snippet.label == "補足")
        #expect(MemoSearch.search("散歩", in: documents)?.first?.snippet.label == "先生の答え")
    }

    @Test func keepsTheListOrder() {
        // 結果は、渡した順（新しい順）のまま。
        let documents = [
            document(id: firstID, body: "体重の話"),
            document(id: secondID, body: "体重が増えた"),
        ]
        #expect(MemoSearch.search("体重", in: documents)?.map(\.id) == [firstID, secondID])
    }

    // MARK: - 抜き出し

    @Test func marksTheMatchedWords() throws {
        let documents = [document(id: firstID, body: "次は血液検査。血液の結果は次回")]
        let snippet = try #require(MemoSearch.search("血液", in: documents)?.first?.snippet)

        #expect(snippet.label == nil)
        #expect(snippet.plainText == "次は血液検査。血液の結果は次回")
        #expect(snippet.pieces.filter(\.isMatch).map(\.text) == ["血液", "血液"])
    }

    @Test func marksTheOriginalLettersEvenWhenFolded() throws {
        // ひらがなで探しても、印はメモに書いてあるとおりのカタカナに付く。
        let documents = [document(id: firstID, body: "ムクミが強い")]
        let snippet = try #require(MemoSearch.search("むくみ", in: documents)?.first?.snippet)
        #expect(snippet.pieces.first == .init(text: "ムクミ", isMatch: true))
    }

    @Test func cutsLongTextAroundTheMatch() throws {
        let before = String(repeating: "あ", count: 30)
        let after = String(repeating: "い", count: 40)
        let documents = [document(id: firstID, body: before + "貧血" + after)]
        let snippet = try #require(MemoSearch.search("貧血", in: documents)?.first?.snippet)

        let expected = "…" + String(repeating: "あ", count: MemoSearch.leadingContext) + "貧血"
            + String(repeating: "い", count: MemoSearch.trailingContext) + "…"
        #expect(snippet.plainText == expected)
    }

    @Test func showsNewlinesAsSpaces() throws {
        let documents = [document(id: firstID, body: "体重\n増えすぎ注意")]
        let snippet = try #require(MemoSearch.search("注意", in: documents)?.first?.snippet)
        #expect(snippet.plainText == "体重 増えすぎ注意")
    }

    @Test func mergesOverlappingMarks() throws {
        // 「血液」と「液検」のように重なった言葉は、1 つの印にまとめる。
        let documents = [document(id: firstID, body: "血液検査")]
        let snippet = try #require(MemoSearch.search("血液 液検", in: documents)?.first?.snippet)
        #expect(snippet.pieces == [.init(text: "血液検", isMatch: true), .init(text: "査", isMatch: false)])
    }
}
