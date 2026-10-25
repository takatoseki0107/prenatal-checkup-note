import Foundation

/// 文章で共有するときの文（要件定義 v0.4 の段階 D の決まり、R-86）。画面から切り離して、テストで確かめる。
///
/// - 「次の健診」の聞きたいことの一覧：次の健診の日時、質問に番号、星の印、補足と先生の答え。
/// - 健診後メモ 1 件：受診日、本文、この健診で聞いたことと先生の答え。
/// - 週数は呼び出し側が「妊娠週数を表示する」に従って渡す（オフなら渡さない）。写真は入れない（R-86）。
nonisolated enum ShareText {
    /// 一覧の質問 1 件。
    nonisolated struct Question: Equatable, Sendable {
        let text: String
        var note: String = ""
        var answer: String = ""
        var isStarred: Bool = false
    }

    /// 健診後メモの「この健診で聞いたこと」1 件。
    nonisolated struct MemoItem: Equatable, Sendable {
        let question: String
        var note: String = ""
        var answer: String = ""
    }

    /// 質問の下に書く行の字下げ。番号（「1. 」）の幅にそろえる。
    private static let indent = "   "

    /// 「次の健診」の聞きたいことの一覧。
    /// - Parameter nextCheckup: 次の健診の日時（例：「11月8日（日） 10:30（妊娠 24 週 0 日）」）。入っていなければ `nil`。
    static func questionList(nextCheckup: String?, questions: [Question]) -> String {
        var lines = ["次の健診で聞きたいこと"]
        if let nextCheckup {
            lines.append("次の健診：\(nextCheckup)")
        }
        if questions.contains(where: \.isStarred) {
            lines.append("（★は大事な質問）")
        }
        lines.append("")

        if questions.isEmpty {
            lines.append("（聞きたいことはまだありません）")
        }
        for (offset, question) in questions.enumerated() {
            let star = question.isStarred ? "★" : ""
            lines.append("\(offset + 1). \(star)\(oneLine(question.text))")
            lines += labeled("補足", question.note)
            lines += labeled("先生の答え", question.answer)
        }
        return lines.joined(separator: "\n")
    }

    /// 健診後メモ 1 件。
    /// - Parameters:
    ///   - title: 例：「10月26日（月）の健診（妊娠 20 週 1 日）」。
    static func memo(title: String, body: String, items: [MemoItem]) -> String {
        var lines = [title]

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBody.isEmpty {
            lines += ["", "先生から聞いたこと・次までにすること", trimmedBody]
        }
        if !items.isEmpty {
            lines += ["", "この健診で聞いたこと"]
            for (offset, item) in items.enumerated() {
                lines.append("\(offset + 1). \(oneLine(item.question))")
                lines += labeled("補足", item.note)
                let answer = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                lines += answer.isEmpty ? ["\(indent)答えのメモなし"] : labeled("先生の答え", answer)
            }
        }
        if trimmedBody.isEmpty, items.isEmpty {
            lines += ["", "（メモの中身はありません）"]
        }
        return lines.joined(separator: "\n")
    }

    /// 「補足：…」のような行。空なら行を作らない。2 行目からも字下げして、どの質問のものか分かるようにする。
    private static func labeled(_ label: String, _ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        let textLines = trimmed.components(separatedBy: .newlines)
        var result = ["\(indent)\(label)：\(textLines[0])"]
        for line in textLines.dropFirst() {
            result.append("\(indent)\(line)")
        }
        return result
    }

    /// 質問の文は 1 行にする（番号の行が崩れないように）。
    private static func oneLine(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
